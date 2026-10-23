/*
  Standalone check of the per-channel pitch, of the range and of the occlusion. Includes pa3d_steam.c whole so the
  static pull_samples, dist_gain and process_block are reachable, feeds it a ramp and asserts the read head advances
  pitch percent as fast, then exercises the exports' clamping and where a source falls silent, then renders a low and a
  high tone from behind a wall. No audio device is opened. Links phonon like the dll does (the included file
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
            for (k = 0; k < FRAME; k++) e[pass] += (double)g_mixL[k] * g_mixL[k] + (double)g_mixR[k] * g_mixR[k];
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

int main(void) {
    static float ramp[FRAME * 8];
    static float out[FRAME];
    Channel c;
    int i;
    for (i = 0; i < FRAME * 8; i++) ramp[i] = (float)i;
    memset(&c, 0, sizeof(c));
    c.used = 1; c.pcm = ramp; c.count = FRAME * 8; c.step = 1.0; c.playing = 1;

    c.pitch100 = 100; c.head = 0.0;
    pull_samples(&c, out);
    expect("at 100 the recording plays as it is", out[FRAME - 1], (double)(FRAME - 1));
    expect("and the head advanced one frame", c.head, (double)FRAME);

    c.pitch100 = 200; c.head = 0.0;
    pull_samples(&c, out);
    expect("at 200 every output sample skips one source sample", out[10], 20.0);
    expect("so the head runs twice as far", c.head, (double)(2 * FRAME));

    c.pitch100 = 50; c.head = 0.0;
    pull_samples(&c, out);
    expect("at 50 the odd samples are interpolated halfway", out[1], 0.5);
    expect("and the head covers half a frame", c.head, (double)FRAME / 2.0);

    c.step = 44100.0 / 48000.0; c.pitch100 = 200; c.head = 0.0;
    pull_samples(&c, out);
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
    }

    if (failures) printf("RESULT: FAIL (%d)\n", failures);
    else printf("RESULT: OK\n");
    return failures ? 1 : 0;
}
