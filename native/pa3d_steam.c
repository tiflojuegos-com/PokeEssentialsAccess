/*
  PA3D (Steam Audio / phonon build) - positional audio backend for the PokeAccess mod.
  Tiny integer/string ABI so the Ruby side stays unchanged. HRTF spatialization is done per
  source with Steam Audio's binaural effect; device output and mixing use miniaudio. PA3D_Output swaps it for a
  speaker layout: a source pans between its speakers, and with none behind (mono, stereo) its pitch tells ahead from
  behind.
  Coordinates are tile units times 100; the listener faces north (-z), map x->x, map y->z.
  Distance attenuation is linear, clamped between the reference distance (1 tile) and the distance at which a
  source falls silent (PA3D_Range, 14 tiles until set).
  Each channel has a playback rate in percent (PA3D_Pitch): the mixer already resamples to the device
  rate with linear interpolation, so a tone, like the pitch tilt, is one more factor on that step and costs
  nothing extra.
*/
#include <windows.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#define MA_NO_DECODING
#define MA_NO_ENCODING
#define MA_NO_GENERATION
#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"

#include "phonon.h"

#define MAXCH 32
#define MAXSPK 8
#define FRAME 256
#define RATE  44100
#define REF_DIST 1.0f
#define PITCH_TILT 0.2f  /* with no speakers behind, how much faster a source straight ahead plays, and slower one behind */
#define EXPORT __declspec(dllexport)

enum { OUT_BINAURAL, OUT_MONO, OUT_STEREO, OUT_QUAD, OUT_51, OUT_71, OUT_COUNT };

typedef struct {
    int    used;
    int    loop;
    float* pcm;        /* mono float samples */
    int    count;      /* number of samples */
    double step;       /* source samples advanced per output sample (rate / RATE) */
    volatile double head;
    volatile int   playing;
    volatile int   vol100;
    volatile int   pitch100;   /* playback rate percent: 100 = the recording, 50 an octave down, 200 up */
    volatile int   x100;
    volatile int   y100;
    volatile int   occ100;
    IPLBinauralEffect effect;
    IPLDirectEffect   direct;
    float  pan[MAXSPK];  /* speaker weights of the last block, where the next block's ramp starts */
} Channel;

/* a speaker: its channel on the device and its azimuth in degrees, turning left from straight ahead. */
typedef struct {
    int   channel;
    float azimuth;
} Speaker;

/* an output: the channels it opens on the device and, for a layout that surrounds the listener, its speakers by azimuth
   and what each channel is. */
typedef struct {
    int channels;
    int speakers;
    const Speaker* ring;
    const ma_channel* map;
} Layout;

/* Steam Audio's layouts, in its channel order; the low-frequency channel stays silent. */
static const Speaker k_quad[] = { {0, 45.0f}, {2, 135.0f}, {3, 225.0f}, {1, 315.0f} };
static const Speaker k_51[] = { {2, 0.0f}, {0, 45.0f}, {4, 135.0f}, {5, 225.0f}, {1, 315.0f} };
static const Speaker k_71[] = { {2, 0.0f}, {0, 45.0f}, {6, 90.0f}, {4, 135.0f}, {5, 225.0f}, {7, 270.0f}, {1, 315.0f} };
static const ma_channel k_map_quad[] = { MA_CHANNEL_FRONT_LEFT, MA_CHANNEL_FRONT_RIGHT, MA_CHANNEL_BACK_LEFT,
                                         MA_CHANNEL_BACK_RIGHT };
static const ma_channel k_map_51[] = { MA_CHANNEL_FRONT_LEFT, MA_CHANNEL_FRONT_RIGHT, MA_CHANNEL_FRONT_CENTER, MA_CHANNEL_LFE,
                                       MA_CHANNEL_BACK_LEFT, MA_CHANNEL_BACK_RIGHT };
static const ma_channel k_map_71[] = { MA_CHANNEL_FRONT_LEFT, MA_CHANNEL_FRONT_RIGHT, MA_CHANNEL_FRONT_CENTER, MA_CHANNEL_LFE,
                                       MA_CHANNEL_BACK_LEFT, MA_CHANNEL_BACK_RIGHT, MA_CHANNEL_SIDE_LEFT, MA_CHANNEL_SIDE_RIGHT };
static const Layout k_layouts[OUT_COUNT] = {
    {2, 0, NULL, NULL}, {1, 0, NULL, NULL}, {2, 0, NULL, NULL},
    {4, 4, k_quad, k_map_quad}, {6, 5, k_51, k_map_51}, {8, 7, k_71, k_map_71}
};

static int g_ready = 0;
static IPLContext g_ctx = NULL;
static IPLHRTF g_hrtf = NULL;
static IPLAudioSettings g_audio;
static IPLAudioBuffer g_in;   /* 1 x FRAME */
static IPLAudioBuffer g_out;  /* 2 x FRAME */
static ma_device g_device;
static int g_devopen = 0;
static int g_devstarted = 0;
static int g_rate = RATE;       /* actual device sample rate (native), set at init */
static int g_latency_ms = 0;    /* output buffer latency in ms (period size x periods / rate) */
static Channel g_ch[MAXCH];
static volatile int g_lx100 = 0;
static volatile int g_ly100 = 0;
static volatile int g_master100 = 100;
static volatile int g_air = 0;       /* global air-absorption toggle (distant sources lose treble) */
static volatile int g_output = OUT_BINAURAL;  /* how sources reach the speakers (PA3D_Output) */
static volatile float g_max_dist = 14.0f;  /* tiles at which a source falls silent (PA3D_Range) */
/* what a wall lets through of a fully occluded source, by band (low, mid, high): the lows pass and the highs are cut,
   so a source behind a wall sounds muffled but stays audible. PA3D_Occl's amount blends from clear toward these. */
static const float k_wall_transmission[IPL_NUM_BANDS] = { 0.6f, 0.2f, 0.05f };
static float g_mix[MAXSPK][FRAME];  /* one processed FRAME-block per speaker, drained across device callbacks */
static int g_fifo_read = FRAME;  /* read cursor into the block; == FRAME means "refill next" */

/* loads a 16-bit mono PCM wav as float samples; returns malloc'd array (caller frees) or NULL. */
static float* load_wav_f32(const char* path, int* outCount, int* outRate) {
    FILE* f = fopen(path, "rb");
    long sz; unsigned char* buf; long p; int rate = RATE, dataSize = 0, i, n; short s; float* out = NULL;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); sz = ftell(f); fseek(f, 0, SEEK_SET);
    if (sz < 44) { fclose(f); return NULL; }
    buf = (unsigned char*)malloc(sz);
    if (!buf || fread(buf, 1, sz, f) != (size_t)sz) { free(buf); fclose(f); return NULL; }
    fclose(f);
    p = 12;
    while (p + 8 <= sz) {
        unsigned int cs; memcpy(&cs, buf + p + 4, 4);
        if (memcmp(buf + p, "fmt ", 4) == 0) { memcpy(&rate, buf + p + 8 + 4, 4); }
        else if (memcmp(buf + p, "data", 4) == 0) {
            dataSize = (int)cs;
            if (p + 8 + (long)cs > sz) dataSize = (int)(sz - p - 8);
            break;
        }
        p += 8 + cs + (cs & 1);
    }
    if (dataSize <= 0) { free(buf); return NULL; }
    n = dataSize / 2;
    out = (float*)malloc(sizeof(float) * (n > 0 ? n : 1));
    if (out) {
        for (i = 0; i < n; i++) { memcpy(&s, buf + p + 8 + i * 2, 2); out[i] = s / 32768.0f; }
    }
    free(buf);
    *outCount = n; *outRate = rate;
    return out;
}

/* linear distance gain, clamped between the reference distance and the one a source falls silent at. */
static float dist_gain(float dist) {
    float max = g_max_dist;
    if (dist <= REF_DIST) return 1.0f;
    if (dist >= max) return 0.0f;
    return 1.0f - (dist - REF_DIST) / (max - REF_DIST);
}

/* pulls up to FRAME mono samples from a channel into dst, zero-padding the tail; handles loop/stop.
   uses linear interpolation between source samples so playing at a sample rate other than the wav's
   (e.g. a 44100 wav on a 48000 device) stays clean -- nearest-neighbour here aliased badly ("old
   telephone" sound). tilt is one more factor on the playback rate. */
static void pull_samples(Channel* c, float* dst, double tilt) {
    int k; double h = c->head; int playing = c->playing;
    double step = c->step * (c->pitch100 / 100.0) * tilt;
    for (k = 0; k < FRAME; k++) {
        int idx; double frac; float a, b;
        if (!playing || c->count <= 0) { dst[k] = 0.0f; continue; }
        if (h >= (double)c->count) {
            if (c->loop) { h -= (double)c->count; }
            else { playing = 0; dst[k] = 0.0f; continue; }
        }
        idx = (int)h; frac = h - (double)idx;
        a = c->pcm[idx];
        b = (idx + 1 < c->count) ? c->pcm[idx + 1] : (c->loop ? c->pcm[0] : a);
        dst[k] = (float)(a + ((double)b - (double)a) * frac);
        h += step;
    }
    c->head = h;
    if (!playing) c->playing = 0;
}

/* each speaker's weight for a direction, at constant power: mono's one speaker at stereo's centre level, stereo by the
   left-right component and a ring by the two speakers either side of the azimuth, both as Steam Audio does. */
static void speaker_weights(int output, const IPLVector3* dir, float* w) {
    const Layout* layout = &k_layouts[output];
    float phi;
    int i;
    memset(w, 0, sizeof(float) * MAXSPK);
    if (!layout->ring) {
        double q = (dir->x + 1.0) * 0.78539816339745;
        if (layout->channels == 1) { w[0] = 0.70710678f; return; }
        w[0] = (float)cos(q);
        w[1] = (float)sin(q);
        return;
    }
    phi = (float)(atan2(-(double)dir->x, -(double)dir->z) * 180.0 / 3.14159265358979);
    if (phi < 0.0f) phi += 360.0f;
    if (phi < layout->ring[0].azimuth) phi += 360.0f;
    for (i = 0; i < layout->speakers; i++) {
        int last = i + 1 == layout->speakers;
        const Speaker* from = &layout->ring[i];
        const Speaker* to = &layout->ring[last ? 0 : i + 1];
        float next = last ? to->azimuth + 360.0f : to->azimuth;
        if (phi < next || last) {
            double t = (phi - from->azimuth) / (next - from->azimuth) * 1.5707963267949;
            w[from->channel] = (float)cos(t);
            w[to->channel] = (float)sin(t);
            return;
        }
    }
}

/* mixes a channel's block into its speakers, each ramped across the block from the last block's weight so a moving
   source does not click. */
static void pan_channel(Channel* c, int output, const IPLVector3* dir, float gain) {
    float w[MAXSPK];
    int i, k, channels = k_layouts[output].channels;
    speaker_weights(output, dir, w);
    for (i = 0; i < channels; i++) {
        float from = c->pan[i], step = (w[i] - from) / FRAME;
        for (k = 0; k < FRAME; k++) g_mix[i][k] += g_in.data[0][k] * gain * (from + step * k);
        c->pan[i] = w[i];
    }
}

/* renders one channel's block into the mix: through the HRTF, or panned between the layout's speakers. With no speakers
   behind, the ahead-behind component of its direction pitches it; a source on the listener keeps its pitch. */
static void mix_channel(Channel* c) {
    IPLBinauralEffectParams params;
    IPLVector3 dir;
    float gx, gz, dist, gain;
    int k, output = g_output;
    int tilted = output != OUT_BINAURAL && !k_layouts[output].ring;
    gx = (c->x100 - g_lx100) / 100.0f;
    gz = (c->y100 - g_ly100) / 100.0f;
    dist = (float)sqrt((double)(gx * gx + gz * gz));
    if (dist < 1e-4f) { dir.x = 0.0f; dir.y = 0.0f; dir.z = -1.0f; }
    else { dir.x = gx / dist; dir.y = 0.0f; dir.z = gz / dist; }
    pull_samples(c, g_in.data[0], (tilted && dist >= 1e-4f) ? 1.0 - PITCH_TILT * dir.z : 1.0);
    gain = (c->vol100 / 100.0f) * (g_master100 / 100.0f) * dist_gain(dist);
    if (gain <= 1e-4f) return;
    if (c->direct && (c->occ100 > 0 || g_air)) {
        IPLDirectEffectParams dp;
        memset(&dp, 0, sizeof(dp));
        dp.flags = 0;
        if (c->occ100 > 0) {
            dp.flags |= IPL_DIRECTEFFECTFLAGS_APPLYOCCLUSION | IPL_DIRECTEFFECTFLAGS_APPLYTRANSMISSION;
            dp.transmissionType = IPL_TRANSMISSIONTYPE_FREQDEPENDENT;
            dp.occlusion = 1.0f - c->occ100 / 100.0f;
            memcpy(dp.transmission, k_wall_transmission, sizeof(dp.transmission));
        }
        if (g_air) {
            dp.flags |= IPL_DIRECTEFFECTFLAGS_APPLYAIRABSORPTION;
            dp.airAbsorption[0] = 1.0f;
            dp.airAbsorption[1] = (float)exp(-0.04 * (double)dist);
            dp.airAbsorption[2] = (float)exp(-0.11 * (double)dist);
        }
        if (dp.flags) iplDirectEffectApply(c->direct, &dp, &g_in, &g_in);
    }
    if (output != OUT_BINAURAL) {
        pan_channel(c, output, &dir, gain);
        return;
    }
    params.direction = dir;
    params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
    params.spatialBlend = 1.0f;
    params.hrtf = g_hrtf;
    params.peakDelays = NULL;
    iplBinauralEffectApply(c->effect, &params, &g_in, &g_out);
    for (k = 0; k < FRAME; k++) {
        g_mix[0][k] += g_out.data[0][k] * gain;
        g_mix[1][k] += g_out.data[1][k] * gain;
    }
}

/* renders exactly one FRAME-sample block: zeroes the mix and sums every audible channel into it.
   each block is processed once, no matter how the device chunks its reads. */
static void process_block(void) {
    int i;
    memset(g_mix, 0, sizeof(g_mix));
    if (g_ready) {
        for (i = 0; i < MAXCH; i++) if (g_ch[i].used && g_ch[i].playing) mix_channel(&g_ch[i]);
    }
}

/* drains processed FRAME-blocks into the device output, refilling a block whenever exhausted. this
   decouples the device's (native-rate) callback size from our fixed FRAME, so any device period or
   sample rate is handled without dropping or reprocessing samples. */
static void data_callback(ma_device* dev, void* output, const void* input, ma_uint32 frameCount) {
    float* out = (float*)output;
    ma_uint32 n;
    int i, channels = (int)dev->playback.channels;
    (void)input;
    for (n = 0; n < frameCount; n++) {
        if (g_fifo_read >= FRAME) { process_block(); g_fifo_read = 0; }
        for (i = 0; i < channels; i++) {
            float s = g_mix[i][g_fifo_read];
            if (s > 1.0f) s = 1.0f; else if (s < -1.0f) s = -1.0f;
            *out++ = s;
        }
        g_fifo_read++;
    }
}

/* whether a channel map has a channel. */
static int has_channel(const ma_channel* map, int channels, ma_channel channel) {
    int i;
    for (i = 0; i < channels; i++) if (map[i] == channel) return 1;
    return 0;
}

/* whether a layout's rear pair belongs on a device's side speakers: it has those and none at the back, and the layout
   has no side speakers of its own. */
static int rear_on_sides(const Layout* layout, const ma_channel* device, int device_channels) {
    return layout->map && !has_channel(layout->map, layout->channels, MA_CHANNEL_SIDE_LEFT) &&
           has_channel(layout->map, layout->channels, MA_CHANNEL_BACK_LEFT) &&
           has_channel(device, device_channels, MA_CHANNEL_SIDE_LEFT) &&
           !has_channel(device, device_channels, MA_CHANNEL_BACK_LEFT);
}

/* opens the device for an output at a rate (0 for its own). A device whose surround pair is at the sides is reopened
   with the layout's rear pair there, so nothing blends across speakers. */
static int open_device(int output, int rate) {
    const Layout* layout = &k_layouts[output];
    ma_device_config cfg;
    ma_channel map[MA_MAX_CHANNELS];
    unsigned int frames;
    int i;
    cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format = ma_format_f32;
    cfg.playback.channels = (ma_uint32)layout->channels;
    cfg.sampleRate = (ma_uint32)rate;
    cfg.dataCallback = data_callback;
    cfg.performanceProfile = ma_performance_profile_low_latency;
    cfg.periodSizeInMilliseconds = 10;
    cfg.periods = 2;
    if (layout->map) {
        memcpy(map, layout->map, sizeof(ma_channel) * layout->channels);
        cfg.playback.pChannelMap = map;
    }
    if (ma_device_init(NULL, &cfg, &g_device) != MA_SUCCESS) return 0;
    if (rear_on_sides(layout, g_device.playback.internalChannelMap, (int)g_device.playback.internalChannels)) {
        for (i = 0; i < layout->channels; i++) {
            if (map[i] == MA_CHANNEL_BACK_LEFT) map[i] = MA_CHANNEL_SIDE_LEFT;
            if (map[i] == MA_CHANNEL_BACK_RIGHT) map[i] = MA_CHANNEL_SIDE_RIGHT;
        }
        ma_device_uninit(&g_device);
        if (ma_device_init(NULL, &cfg, &g_device) != MA_SUCCESS) return 0;
    }
    g_devopen = 1;
    g_rate = (g_device.sampleRate > 0) ? (int)g_device.sampleRate : RATE;
    frames = g_device.playback.internalPeriodSizeInFrames * g_device.playback.internalPeriods;
    g_latency_ms = (g_rate > 0) ? (int)((frames * 1000) / (unsigned int)g_rate) : 0;
    return 1;
}

/* stops and closes the device, if open. */
static void close_device(void) {
    if (g_devstarted) { ma_device_stop(&g_device); g_devstarted = 0; }
    if (g_devopen) { ma_device_uninit(&g_device); g_devopen = 0; }
}

/* the output a device of that many channels plays instead of mixing its speakers down: the one asked for if they fit,
   else the largest layout that does. */
static int fitting_output(int output, int channels) {
    if (k_layouts[output].channels <= channels) return output;
    if (channels >= 6) return OUT_51;
    if (channels >= 4) return OUT_QUAD;
    return channels >= 2 ? OUT_STEREO : OUT_MONO;
}

/* opens the device for an output, or the one that fits it; the output left open, -1 if none. */
static int open_fitting(int output, int rate) {
    int fit;
    if (!open_device(output, rate)) return -1;
    fit = fitting_output(output, (int)g_device.playback.internalChannels);
    if (fit == output) return output;
    close_device();
    return open_device(fit, rate) ? fit : -1;
}

EXPORT int PA3D_Init(void) {
    IPLContextSettings cs;
    IPLHRTFSettings hs;
    int fit;
    if (g_ready) return 1;
    memset(g_ch, 0, sizeof(g_ch));
    g_fifo_read = FRAME;

    fit = open_fitting(g_output, 0);
    if (fit < 0) return 0;
    g_output = fit;

    memset(&cs, 0, sizeof(cs));
    cs.version = STEAMAUDIO_VERSION;
    if (iplContextCreate(&cs, &g_ctx) != IPL_STATUS_SUCCESS || !g_ctx) {
        close_device(); return 0;
    }

    g_audio.samplingRate = g_rate;
    g_audio.frameSize = FRAME;

    memset(&hs, 0, sizeof(hs));
    hs.type = IPL_HRTFTYPE_DEFAULT;
    hs.volume = 1.0f;
    hs.normType = IPL_HRTFNORMTYPE_NONE;
    if (iplHRTFCreate(g_ctx, &g_audio, &hs, &g_hrtf) != IPL_STATUS_SUCCESS || !g_hrtf) {
        iplContextRelease(&g_ctx); close_device(); return 0;
    }

    if (iplAudioBufferAllocate(g_ctx, 1, FRAME, &g_in) != IPL_STATUS_SUCCESS ||
        iplAudioBufferAllocate(g_ctx, 2, FRAME, &g_out) != IPL_STATUS_SUCCESS) {
        iplHRTFRelease(&g_hrtf); iplContextRelease(&g_ctx); close_device(); return 0;
    }

    g_ready = 1;
    if (ma_device_start(&g_device) == MA_SUCCESS) g_devstarted = 1;
    return 1;
}

EXPORT int PA3D_Channel(const char* path, int loop) {
    int i, count = 0, rate = RATE; float* pcm;
    IPLBinauralEffectSettings es;
    IPLDirectEffectSettings ds;
    IPLBinauralEffect effect = NULL;
    IPLDirectEffect direct = NULL;
    if (!g_ready) return -1;
    for (i = 0; i < MAXCH; i++) if (!g_ch[i].used) break;
    if (i >= MAXCH) return -1;
    pcm = load_wav_f32(path, &count, &rate);
    if (!pcm || count <= 0) { free(pcm); return -1; }
    memset(&es, 0, sizeof(es));
    es.hrtf = g_hrtf;
    if (iplBinauralEffectCreate(g_ctx, &g_audio, &es, &effect) != IPL_STATUS_SUCCESS || !effect) {
        free(pcm); return -1;
    }
    memset(&ds, 0, sizeof(ds));
    ds.numChannels = 1;
    if (iplDirectEffectCreate(g_ctx, &g_audio, &ds, &direct) != IPL_STATUS_SUCCESS) direct = NULL;
    g_ch[i].pcm = pcm;
    g_ch[i].count = count;
    g_ch[i].step = (double)rate / (double)g_rate;
    g_ch[i].head = 0.0;
    g_ch[i].playing = 0;
    g_ch[i].vol100 = 100;
    g_ch[i].pitch100 = 100;
    g_ch[i].x100 = 0;
    g_ch[i].y100 = 0;
    g_ch[i].occ100 = 0;
    g_ch[i].loop = loop ? 1 : 0;
    g_ch[i].effect = effect;
    g_ch[i].direct = direct;
    g_ch[i].used = 1;
    return i;
}

EXPORT void PA3D_Listener(int x100, int y100) {
    g_lx100 = x100; g_ly100 = y100;
}

EXPORT void PA3D_Set(int ch, int x100, int y100, int vol100, int play) {
    if (!g_ready || ch < 0 || ch >= MAXCH || !g_ch[ch].used) return;
    g_ch[ch].x100 = x100;
    g_ch[ch].y100 = y100;
    g_ch[ch].vol100 = vol100;
    if (play) {
        if (g_ch[ch].loop) {
            if (!g_ch[ch].playing) { g_ch[ch].playing = 1; }
        } else {
            g_ch[ch].head = 0.0;
            g_ch[ch].playing = 1;
        }
    } else {
        g_ch[ch].playing = 0;
    }
}

EXPORT void PA3D_Master(int vol100) {
    g_master100 = vol100;
}

/* per-channel playback rate in percent (100 = as recorded), clamped to 25-400 so a bad value can neither
   freeze a channel nor make it skip whole samples. Takes effect from the next block, mid-sound too. */
EXPORT void PA3D_Pitch(int ch, int pitch100) {
    if (ch < 0 || ch >= MAXCH || !g_ch[ch].used) return;
    if (pitch100 < 25) pitch100 = 25;
    if (pitch100 > 400) pitch100 = 400;
    g_ch[ch].pitch100 = pitch100;
}

/* per-channel occlusion amount 0-100, clamped (0 = clear, 100 = fully muffled behind a wall): Steam Audio's
   occlusion factor is the share left clear, 1 - amount, and the rest passes through k_wall_transmission. */
EXPORT void PA3D_Occl(int ch, int occ100) {
    if (ch < 0 || ch >= MAXCH || !g_ch[ch].used) return;
    if (occ100 < 0) occ100 = 0;
    if (occ100 > 100) occ100 = 100;
    g_ch[ch].occ100 = occ100;
}

/* global air-absorption toggle: 1 makes distant sources lose treble, 0 off. */
EXPORT void PA3D_Air(int on) {
    g_air = on ? 1 : 0;
}

/* how sources reach the speakers: 0 binaural through the HRTF (the default), 1 mono, 2 stereo, 3 quadraphonic, 4 5.1,
   5 7.1. Before init it is only noted. On a device with too few channels the largest layout that fits plays instead.
   Another channel count reopens the device at the same rate; if that fails binaural is tried. The output now playing,
   -1 if none: the device is left closed, and the next call tries again. */
EXPORT int PA3D_Output(int output) {
    int i, fit;
    if (output < 0 || output >= OUT_COUNT) return -1;
    if (!g_ready) {
        g_output = output;
        return output;
    }
    if (g_devstarted) {
        fit = fitting_output(output, (int)g_device.playback.internalChannels);
        if (k_layouts[fit].channels == k_layouts[g_output].channels) {
            g_output = fit;
            return fit;
        }
    }
    close_device();
    for (i = 0; i < MAXCH; i++) memset(g_ch[i].pan, 0, sizeof(g_ch[i].pan));
    g_fifo_read = FRAME;
    fit = open_fitting(output, g_rate);
    if (fit < 0) fit = open_fitting(OUT_BINAURAL, g_rate);
    if (fit < 0) return -1;
    g_output = fit;
    if (ma_device_start(&g_device) != MA_SUCCESS) {
        close_device();
        return -1;
    }
    g_devstarted = 1;
    return fit;
}

/* how many channels the device really has, whatever the output asks of it. 0 if down. */
EXPORT int PA3D_DeviceChannels(void) {
    return g_devopen ? (int)g_device.playback.internalChannels : 0;
}

/* the distance in tiles at which a source falls silent, 2 at least (the caller's sonar range plus a margin). */
EXPORT void PA3D_Range(int tiles) {
    g_max_dist = (float)(tiles < 2 ? 2 : tiles);
}

/* the device's actual (native) sample rate, so the caller can load rate-matched assets. 0 if down. */
EXPORT int PA3D_Rate(void) {
    return g_ready ? g_rate : 0;
}

/* the output buffer latency in milliseconds (period size x periods / rate). 0 if down. */
EXPORT int PA3D_Latency(void) {
    return g_ready ? g_latency_ms : 0;
}

EXPORT void PA3D_Shutdown(void) {
    int i;
    if (!g_ready) return;
    g_ready = 0;
    close_device();
    for (i = 0; i < MAXCH; i++) if (g_ch[i].used) {
        if (g_ch[i].effect) iplBinauralEffectRelease(&g_ch[i].effect);
        if (g_ch[i].direct) iplDirectEffectRelease(&g_ch[i].direct);
        free(g_ch[i].pcm); g_ch[i].pcm = NULL; g_ch[i].used = 0;
    }
    iplAudioBufferFree(g_ctx, &g_in);
    iplAudioBufferFree(g_ctx, &g_out);
    if (g_hrtf) iplHRTFRelease(&g_hrtf);
    if (g_ctx) iplContextRelease(&g_ctx);
    g_hrtf = NULL; g_ctx = NULL;
}
