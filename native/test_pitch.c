/*
  Standalone check of the per-channel pitch, of the range, of the occlusion and of the speaker layouts. Includes
  pa3d_steam.c whole so the static pull_samples, dist_gain and process_block are reachable, feeds it a ramp and asserts
  the read head advances pitch percent as fast, then exercises the exports' clamping and where a source falls silent,
  checks each layout's speaker weights, then renders a low and a high tone from behind a wall, then a tone in each
  output from around the listener for its panning and its pitch. No audio device is opened. Links phonon like the dll does (the included file
  references it), so phonon.dll of the matching architecture must sit beside the executable to start.
*/
#include "pa3d_steam.c"

#define TONE_RATE 48000

static int failures = 0;

static void expect(const char* label, double got, double want) {
    double d = got - want;
    if (d < 0) d = -d;
    if (d > 1e-4) { printf("FAIL %s: got %.5f want %.5f\n", label, got, want); failures++; }
    else printf("ok   %s\n", label);
}

/* Passes when got lies within [lo, hi]. */
static void expect_within(const char* label, double got, double lo, double hi) {
    if (got < lo || got > hi) { printf("FAIL %s: got %.2f want %.2f..%.2f\n", label, got, lo, hi); failures++; }
    else printf("ok   %s (%.2f)\n", label, got);
}

/* Sets up Steam Audio as PA3D_Init does, without the device: the context, the HRTF and the mix buffers at 48 kHz. */
static int init_steam(void) {
    IPLContextSettings cs;
    IPLHRTFSettings hs;
    memset(&cs, 0, sizeof(cs));
    cs.version = STEAMAUDIO_VERSION;
    if (iplContextCreate(&cs, &g_ctx) != IPL_STATUS_SUCCESS) return 0;
    g_rate = TONE_RATE;
    g_audio.samplingRate = g_rate;
    g_audio.frameSize = FRAME;
    memset(&hs, 0, sizeof(hs));
    hs.type = IPL_HRTFTYPE_DEFAULT; hs.volume = 1.0f; hs.normType = IPL_HRTFNORMTYPE_NONE;
    if (iplHRTFCreate(g_ctx, &g_audio, &hs, &g_hrtf) != IPL_STATUS_SUCCESS) return 0;
    if (iplAudioBufferAllocate(g_ctx, 1, FRAME, &g_in) != IPL_STATUS_SUCCESS) return 0;
    if (iplAudioBufferAllocate(g_ctx, 2, FRAME, &g_out) != IPL_STATUS_SUCCESS) return 0;
    g_ready = 1;
    return 1;
}

/* Makes channel 0 a looping tone of hz, one second long, playing three tiles ahead of the listener. */
static int tone_channel(float* pcm, double hz) {
    Channel* c = &g_ch[0];
    IPLBinauralEffectSettings es;
    IPLDirectEffectSettings ds;
    int i;
    for (i = 0; i < TONE_RATE; i++) pcm[i] = 0.3f * (float)sin(2.0 * 3.14159265358979 * hz * i / TONE_RATE);
    memset(g_ch, 0, sizeof(g_ch));
    memset(&es, 0, sizeof(es)); es.hrtf = g_hrtf;
    memset(&ds, 0, sizeof(ds)); ds.numChannels = 1;
    if (iplBinauralEffectCreate(g_ctx, &g_audio, &es, &c->effect) != IPL_STATUS_SUCCESS) return 0;
    if (iplDirectEffectCreate(g_ctx, &g_audio, &ds, &c->direct) != IPL_STATUS_SUCCESS) return 0;
    c->pcm = pcm; c->count = TONE_RATE; c->step = 1.0; c->loop = 1; c->used = 1; c->playing = 1;
    c->vol100 = 100; c->pitch100 = 100; c->x100 = 0; c->y100 = -300;
    return 1;
}

/* The level, in dB against the tone heard clear, of channel 0 muffled by occ100, once the filters settled. */
static double muffled_db(int occ100) {
    double e[2];
    int pass, b, k;
    for (pass = 0; pass < 2; pass++) {
        Channel* c = &g_ch[0];
        iplBinauralEffectReset(c->effect);
        iplDirectEffectReset(c->direct);
        c->head = 0.0;
        c->occ100 = pass ? occ100 : 0;
        e[pass] = 0.0;
        for (b = 0; b < 32; b++) {
            process_block();
            if (b < 16) continue;
            for (k = 0; k < FRAME; k++) e[pass] += (double)g_mix[0][k] * g_mix[0][k] + (double)g_mix[1][k] * g_mix[1][k];
        }
    }
    return 10.0 * log10(e[1] / e[0]);
}

/* Releases channel 0's effects. */
static void drop_channel(void) {
    iplBinauralEffectRelease(&g_ch[0].effect);
    iplDirectEffectRelease(&g_ch[0].direct);
    memset(g_ch, 0, sizeof(g_ch));
}

/* Plays channel 0 at (x100, y100) for eight blocks: the left channel's level over the right's in dB once the pan's
   ramp settled, the energy of both channels in total and the playback rate the read head ran at in rate. */
static double stereo_db(int x100, int y100, double* total, double* rate) {
    Channel* c = &g_ch[0];
    double el = 0.0, er = 0.0;
    int b, k;
    c->x100 = x100; c->y100 = y100; c->head = 0.0;
    for (b = 0; b < 8; b++) {
        process_block();
        if (b < 2) continue;
        for (k = 0; k < FRAME; k++) { el += (double)g_mix[0][k] * g_mix[0][k]; er += (double)g_mix[1][k] * g_mix[1][k]; }
    }
    *total = el + er;
    *rate = c->head / (8.0 * FRAME);
    return 10.0 * log10(el / er);
}

/* The loudest sample of a speaker in the last block. */
static double speaker_peak(int speaker) {
    double peak = 0.0;
    int k;
    for (k = 0; k < FRAME; k++) {
        double s = g_mix[speaker][k] < 0.0f ? -(double)g_mix[speaker][k] : (double)g_mix[speaker][k];
        if (s > peak) peak = s;
    }
    return peak;
}

/* The weights of an output toward an azimuth in degrees, turning left from straight ahead. */
static void weights_at(int output, double degrees, float* w) {
    IPLVector3 dir;
    double a = degrees * 3.14159265358979 / 180.0;
    dir.x = (float)-sin(a);
    dir.y = 0.0f;
    dir.z = (float)-cos(a);
    speaker_weights(output, &dir, w);
}

/* The farthest an output's total power strays from its expected value around the circle, degree by degree. */
static double power_stray(int output, double expected) {
    float w[MAXSPK];
    double worst = 0.0;
    int deg, i;
    for (deg = 0; deg < 360; deg++) {
        double power = 0.0, d;
        weights_at(output, deg, w);
        for (i = 0; i < MAXSPK; i++) power += (double)w[i] * w[i];
        d = power > expected ? power - expected : expected - power;
        if (d > worst) worst = d;
    }
    return worst;
}

/* The highest weight the low-frequency channel gets around the circle. */
static double lfe_peak(int output) {
    float w[MAXSPK];
    double peak = 0.0;
    int deg;
    for (deg = 0; deg < 360; deg++) {
        weights_at(output, deg, w);
        if (w[3] > peak) peak = w[3];
    }
    return peak;
}

/* What the channel of a speaker at an azimuth must be called on the device. */
static ma_channel channel_at(float azimuth) {
    if (azimuth == 0.0f) return MA_CHANNEL_FRONT_CENTER;
    if (azimuth == 45.0f) return MA_CHANNEL_FRONT_LEFT;
    if (azimuth == 90.0f) return MA_CHANNEL_SIDE_LEFT;
    if (azimuth == 135.0f) return MA_CHANNEL_BACK_LEFT;
    if (azimuth == 225.0f) return MA_CHANNEL_BACK_RIGHT;
    if (azimuth == 270.0f) return MA_CHANNEL_SIDE_RIGHT;
    if (azimuth == 315.0f) return MA_CHANNEL_FRONT_RIGHT;
    return MA_CHANNEL_NONE;
}

/* That each speaker of a layout's ring plays on the device channel at its azimuth. */
static void check_map(int output, const char* name) {
    const Layout* layout = &k_layouts[output];
    int i, wrong = 0;
    for (i = 0; i < layout->speakers; i++) {
        if (layout->map[layout->ring[i].channel] != channel_at(layout->ring[i].azimuth)) wrong++;
    }
    printf("     %s channel map:\n", name);
    expect("each speaker on the channel at its azimuth", wrong, 0.0);
}

/* Each layout's speakers: a source on a speaker plays there alone, one between two shares them. */
static void check_layouts(void) {
    float w[MAXSPK];
    const double half = 0.70710678;
    weights_at(OUT_MONO, 120.0, w);
    expect("mono has one speaker, at stereo's centre level", w[0], half);
    expect("and no other", w[1], 0.0);
    weights_at(OUT_STEREO, 90.0, w);
    expect("stereo: a source to the left is all on the left", w[0], 1.0);
    expect("and none on the right", w[1], 0.0);
    weights_at(OUT_QUAD, 0.0, w);
    expect("quad: ahead shares the front pair", w[0], half);
    expect("evenly", w[1], half);
    weights_at(OUT_QUAD, 135.0, w);
    expect("on the rear left speaker it plays there", w[2], 1.0);
    expect("and not in the front left", w[0], 0.0);
    weights_at(OUT_QUAD, 180.0, w);
    expect("behind shares the rear pair", w[2], half);
    expect("evenly", w[3], half);
    weights_at(OUT_51, 0.0, w);
    expect("5.1: ahead is the centre speaker", w[2], 1.0);
    weights_at(OUT_51, 45.0, w);
    expect("front left is its speaker", w[0], 1.0);
    weights_at(OUT_51, 90.0, w);
    expect("the left shares front left", w[0], half);
    expect("and rear left", w[4], half);
    weights_at(OUT_51, 225.0, w);
    expect("rear right is its speaker", w[5], 1.0);
    weights_at(OUT_51, 315.0, w);
    expect("front right is its speaker", w[1], 1.0);
    weights_at(OUT_71, 90.0, w);
    expect("7.1: the left is the side left speaker", w[6], 1.0);
    weights_at(OUT_71, 270.0, w);
    expect("the right is the side right speaker", w[7], 1.0);
    weights_at(OUT_71, 135.0, w);
    expect("rear left is its speaker", w[4], 1.0);
    weights_at(OUT_71, 337.5, w);
    expect("halfway from front right to the centre shares them", w[1], half);
    expect("evenly", w[2], half);
    expect("mono keeps its power all around", power_stray(OUT_MONO, 0.5), 0.0);
    expect("stereo keeps its power all around", power_stray(OUT_STEREO, 1.0), 0.0);
    expect("quad keeps its power all around", power_stray(OUT_QUAD, 1.0), 0.0);
    expect("5.1 keeps its power all around", power_stray(OUT_51, 1.0), 0.0);
    expect("7.1 keeps its power all around", power_stray(OUT_71, 1.0), 0.0);
    expect("5.1 leaves the low-frequency channel silent", lfe_peak(OUT_51), 0.0);
    expect("7.1 leaves the low-frequency channel silent", lfe_peak(OUT_71), 0.0);
    expect("mono opens one channel", k_layouts[OUT_MONO].channels, 1.0);
    expect("binaural two", k_layouts[OUT_BINAURAL].channels, 2.0);
    expect("stereo two", k_layouts[OUT_STEREO].channels, 2.0);
    expect("quad four", k_layouts[OUT_QUAD].channels, 4.0);
    expect("5.1 six", k_layouts[OUT_51].channels, 6.0);
    expect("7.1 eight", k_layouts[OUT_71].channels, 8.0);
    check_map(OUT_QUAD, "quad");
    check_map(OUT_51, "5.1");
    check_map(OUT_71, "7.1");
    {
        const ma_channel side51[] = { MA_CHANNEL_FRONT_LEFT, MA_CHANNEL_FRONT_RIGHT, MA_CHANNEL_FRONT_CENTER, MA_CHANNEL_LFE,
                                      MA_CHANNEL_SIDE_LEFT, MA_CHANNEL_SIDE_RIGHT };
        const ma_channel surround4[] = { MA_CHANNEL_FRONT_LEFT, MA_CHANNEL_FRONT_RIGHT, MA_CHANNEL_FRONT_CENTER,
                                         MA_CHANNEL_BACK_CENTER };
        expect("on a 5.1 device with its surround pair at the sides, 5.1's rear pair goes there",
               rear_on_sides(&k_layouts[OUT_51], side51, 6), 1.0);
        expect("as does quad's", rear_on_sides(&k_layouts[OUT_QUAD], side51, 6), 1.0);
        expect("on a 7.1 device, with a back pair, 5.1's stays at the back",
               rear_on_sides(&k_layouts[OUT_51], k_map_71, 8), 0.0);
        expect("and 7.1 keeps both pairs", rear_on_sides(&k_layouts[OUT_71], k_map_71, 8), 0.0);
        expect("a quad device keeps quad's", rear_on_sides(&k_layouts[OUT_QUAD], k_map_quad, 4), 0.0);
        expect("a device with no pair to take it converts", rear_on_sides(&k_layouts[OUT_QUAD], surround4, 4), 0.0);
        expect("stereo has no rear pair", rear_on_sides(&k_layouts[OUT_STEREO], side51, 6), 0.0);
    }
}

int main(void) {
    static float ramp[FRAME * 8];
    static float out[FRAME];
    Channel c;
    int i;
    for (i = 0; i < FRAME * 8; i++) ramp[i] = (float)i;
    memset(&c, 0, sizeof(c));
    c.used = 1; c.pcm = ramp; c.count = FRAME * 8; c.step = 1.0; c.playing = 1;

    c.pitch100 = 100; c.head = 0.0;
    pull_samples(&c, out, 1.0);
    expect("at 100 the recording plays as it is", out[FRAME - 1], (double)(FRAME - 1));
    expect("and the head advanced one frame", c.head, (double)FRAME);

    c.head = 0.0;
    pull_samples(&c, out, 1.2);
    expect("a tilt is one more factor on the rate", c.head, FRAME * 1.2);

    c.pitch100 = 200; c.head = 0.0;
    pull_samples(&c, out, 1.0);
    expect("at 200 every output sample skips one source sample", out[10], 20.0);
    expect("so the head runs twice as far", c.head, (double)(2 * FRAME));

    c.pitch100 = 50; c.head = 0.0;
    pull_samples(&c, out, 1.0);
    expect("at 50 the odd samples are interpolated halfway", out[1], 0.5);
    expect("and the head covers half a frame", c.head, (double)FRAME / 2.0);

    c.step = 44100.0 / 48000.0; c.pitch100 = 200; c.head = 0.0;
    pull_samples(&c, out, 1.0);
    expect("the pitch multiplies the device-rate step instead of replacing it", c.head, FRAME * 2.0 * 44100.0 / 48000.0);

    memset(g_ch, 0, sizeof(g_ch));
    g_ch[3].used = 1; g_ch[3].pitch100 = 100;
    PA3D_Pitch(3, 5);   expect("below 25 clamps to 25", g_ch[3].pitch100, 25.0);
    PA3D_Pitch(3, 900); expect("above 400 clamps to 400", g_ch[3].pitch100, 400.0);
    PA3D_Pitch(3, 141); expect("a value in range is kept", g_ch[3].pitch100, 141.0);
    PA3D_Pitch(4, 200); expect("an unused channel is left alone", g_ch[4].pitch100, 0.0);
    PA3D_Pitch(-1, 200); PA3D_Pitch(MAXCH, 200);
    expect("out-of-range channels are ignored", g_ch[3].pitch100, 141.0);

    expect("until a range is set a source falls silent at 14 tiles", dist_gain(14.0f), 0.0);
    expect("and is a thirteenth of full one tile short of it", dist_gain(13.0f), 1.0 - 12.0 / 13.0);
    PA3D_Range(30);
    expect("a wider range keeps a far source audible", dist_gain(29.0f), 1.0 - 28.0 / 29.0);
    expect("and silences it at the range", dist_gain(30.0f), 0.0);
    PA3D_Range(0);
    expect("a range under 2 tiles is taken as 2", dist_gain(1.5f), 0.5);
    expect("the reference distance still plays in full", dist_gain(1.0f), 1.0);
    PA3D_Range(14);

    memset(g_ch, 0, sizeof(g_ch));
    g_ch[3].used = 1;
    PA3D_Occl(3, 150); expect("an occlusion above 100 clamps to 100", g_ch[3].occ100, 100.0);
    PA3D_Occl(3, -5);  expect("one below 0 clamps to 0", g_ch[3].occ100, 0.0);
    PA3D_Occl(3, 80);  expect("one in range is kept", g_ch[3].occ100, 80.0);

    check_layouts();
    expect("7.1 plays on a device of eight channels", fitting_output(OUT_71, 8), OUT_71);
    expect("as 5.1 on six", fitting_output(OUT_71, 6), OUT_51);
    expect("as quad on four", fitting_output(OUT_71, 4), OUT_QUAD);
    expect("as stereo on two", fitting_output(OUT_71, 2), OUT_STEREO);
    expect("5.1 keeps on seven", fitting_output(OUT_51, 7), OUT_51);
    expect("quad plays as stereo on two", fitting_output(OUT_QUAD, 2), OUT_STEREO);
    expect("binaural keeps on two", fitting_output(OUT_BINAURAL, 2), OUT_BINAURAL);
    expect("and plays as mono on one", fitting_output(OUT_BINAURAL, 1), OUT_MONO);
    expect("as does stereo", fitting_output(OUT_STEREO, 1), OUT_MONO);
    expect("mono keeps on any device", fitting_output(OUT_MONO, 8), OUT_MONO);
    expect("an output past the last is refused", PA3D_Output(OUT_COUNT), -1.0);
    expect("as is one below the first", PA3D_Output(-1), -1.0);
    expect("and the output stays binaural", g_output, (double)OUT_BINAURAL);
    expect("before init an output is only noted", PA3D_Output(OUT_71), OUT_71);
    expect("and is the one set", g_output, (double)OUT_71);
    expect("with no device open it has no channels", PA3D_DeviceChannels(), 0.0);
    PA3D_Output(OUT_BINAURAL);

    if (!init_steam()) { printf("FAIL steam audio setup\n"); failures++; }
    else {
        static float pcm[TONE_RATE];
        double low80, low100, high80, high100;
        if (!tone_channel(pcm, 300.0)) { printf("FAIL low tone channel\n"); failures++; }
        else {
            expect_within("a clear source keeps its level", muffled_db(0), -0.01, 0.01);
            low80 = muffled_db(80);
            low100 = muffled_db(100);
            drop_channel();
            if (!tone_channel(pcm, 12000.0)) { printf("FAIL high tone channel\n"); failures++; }
            else {
                high80 = muffled_db(80);
                high100 = muffled_db(100);
                drop_channel();
                expect_within("at 80 a low tone behind a wall loses a little (dB)", low80, -6.0, -2.0);
                expect_within("and a high one far more (dB)", high80, -20.0, -9.0);
                expect_within("so the highs lose 6 dB more than the lows at least", low80 - high80, 6.0, 20.0);
                expect_within("at 100 the low tone is muffled further (dB)", low100, -8.0, low80 - 0.3);
                expect_within("and the high one too, still audible (dB)", high100, -40.0, high80 - 3.0);
            }
        }
        if (!tone_channel(pcm, 440.0)) { printf("FAIL stereo tone channel\n"); failures++; }
        else {
            double total, rate, ahead, left;
            g_output = OUT_STEREO;
            expect_within("in stereo a source 45 degrees left ahead is louder on the left (dB)",
                          stereo_db(-300, -300, &left, &rate), 12.3, 12.9);
            expect("and plays faster by the tilt's share ahead", rate, 1.0 + PITCH_TILT * 0.70710678);
            expect_within("one 45 degrees right ahead is louder on the right (dB)", stereo_db(300, -300, &total, &rate),
                          -12.9, -12.3);
            expect_within("one straight ahead is centred (dB)", stereo_db(0, -300, &ahead, &rate), -0.01, 0.01);
            expect("and plays faster by the whole tilt", rate, 1.0 + PITCH_TILT);
            expect_within("one straight behind is centred too (dB)", stereo_db(0, 300, &total, &rate), -0.01, 0.01);
            expect("and plays slower by the whole tilt", rate, 1.0 - PITCH_TILT);
            stereo_db(-300, 0, &total, &rate);
            expect("one to the side keeps its pitch", rate, 1.0);
            expect_within("one on the listener is centred (dB)", stereo_db(0, 0, &total, &rate), -0.01, 0.01);
            expect("and keeps its pitch", rate, 1.0);
            g_output = OUT_BINAURAL;
            stereo_db(0, -300, &total, &rate);
            expect("through the HRTF one ahead keeps its pitch", rate, 1.0);
            printf("info HRTF over stereo, ahead: %.2f dB\n", 10.0 * log10(total / ahead));
            stereo_db(-300, -300, &total, &rate);
            printf("info HRTF over stereo, 45 degrees left: %.2f dB\n", 10.0 * log10(total / left));
            g_output = OUT_MONO;
            stereo_db(0, -300, &total, &rate);
            expect("in mono one ahead plays faster by the whole tilt", rate, 1.0 + PITCH_TILT);
            stereo_db(0, 300, &total, &rate);
            expect("and one behind slower by it", rate, 1.0 - PITCH_TILT);
            expect("with nothing on a second channel", g_mix[1][FRAME / 2], 0.0);
            stereo_db(0, 0, &total, &rate);
            expect("and one on the listener keeps its pitch", rate, 1.0);
            g_output = OUT_QUAD;
            stereo_db(0, -300, &total, &rate);
            expect("with speakers behind, quad leaves the pitch alone", rate, 1.0);
            g_output = OUT_51;
            stereo_db(0, 300, &total, &rate);
            expect("as does 5.1", rate, 1.0);
            g_output = OUT_71;
            stereo_db(-300, 300, &total, &rate);
            expect("and 7.1", rate, 1.0);
            expect("where a source behind on the left plays only in rear left", speaker_peak(4) > 0.0 ? 1.0 : 0.0, 1.0);
            expect("and not in front left", speaker_peak(0), 0.0);
            g_output = OUT_BINAURAL;
            drop_channel();
        }
    }

    if (failures) printf("RESULT: FAIL (%d)\n", failures);
    else printf("RESULT: OK\n");
    return failures ? 1 : 0;
}
