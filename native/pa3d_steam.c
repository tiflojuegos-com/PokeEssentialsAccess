/*
  PA3D (Steam Audio / phonon build) - positional audio backend for the PokeAccess mod.
  Tiny integer/string ABI so the Ruby side stays unchanged. HRTF spatialization is done per
  source with Steam Audio's binaural effect; device output and mixing use miniaudio.
  Coordinates are tile units times 100; the listener faces north (-z), map x->x, map y->z.
  Distance attenuation is linear, clamped between the reference (1) and max (14) tile distance.
  Each channel has a playback rate in percent (PA3D_Pitch): the mixer already resamples to the device
  rate with linear interpolation, so a tone is one more factor on that step and costs nothing extra.
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

#define MAXCH 24
#define FRAME 256
#define RATE  44100
#define REF_DIST 1.0f
#define MAX_DIST 14.0f
#define EXPORT __declspec(dllexport)

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
} Channel;

static int g_ready = 0;
static IPLContext g_ctx = NULL;
static IPLHRTF g_hrtf = NULL;
static IPLAudioSettings g_audio;
static IPLAudioBuffer g_in;   /* 1 x FRAME */
static IPLAudioBuffer g_out;  /* 2 x FRAME */
static ma_device g_device;
static int g_devstarted = 0;
static int g_rate = RATE;       /* actual device sample rate (native), set at init */
static int g_latency_ms = 0;    /* output buffer latency in ms (period size x periods / rate) */
static Channel g_ch[MAXCH];
static volatile int g_lx100 = 0;
static volatile int g_ly100 = 0;
static volatile int g_master100 = 100;
static volatile int g_air = 0;       /* global air-absorption toggle (distant sources lose treble) */
static float g_mixL[FRAME];     /* one processed FRAME-block, drained across device callbacks */
static float g_mixR[FRAME];
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

/* linear distance gain, clamped between the reference and max distance. */
static float dist_gain(float dist) {
    if (dist <= REF_DIST) return 1.0f;
    if (dist >= MAX_DIST) return 0.0f;
    return 1.0f - (dist - REF_DIST) / (MAX_DIST - REF_DIST);
}

/* pulls up to FRAME mono samples from a channel into dst, zero-padding the tail; handles loop/stop.
   uses linear interpolation between source samples so playing at a sample rate other than the wav's
   (e.g. a 44100 wav on a 48000 device) stays clean -- nearest-neighbour here aliased badly ("old
   telephone" sound). */
static void pull_samples(Channel* c, float* dst) {
    int k; double h = c->head; int playing = c->playing;
    double step = c->step * (c->pitch100 / 100.0);
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

static void mix_channel(Channel* c) {
    IPLBinauralEffectParams params;
    IPLVector3 dir;
    float gx, gz, dist, gain;
    int k;
    pull_samples(c, g_in.data[0]);
    gx = (c->x100 - g_lx100) / 100.0f;
    gz = (c->y100 - g_ly100) / 100.0f;
    dist = (float)sqrt((double)(gx * gx + gz * gz));
    gain = (c->vol100 / 100.0f) * (g_master100 / 100.0f) * dist_gain(dist);
    if (gain <= 1e-4f) return;
    if (c->direct && (c->occ100 > 0 || g_air)) {
        IPLDirectEffectParams dp;
        memset(&dp, 0, sizeof(dp));
        dp.flags = 0;
        if (c->occ100 > 0) { dp.flags |= IPL_DIRECTEFFECTFLAGS_APPLYOCCLUSION; dp.occlusion = c->occ100 / 100.0f; }
        if (g_air) {
            dp.flags |= IPL_DIRECTEFFECTFLAGS_APPLYAIRABSORPTION;
            dp.airAbsorption[0] = 1.0f;
            dp.airAbsorption[1] = (float)exp(-0.04 * (double)dist);
            dp.airAbsorption[2] = (float)exp(-0.11 * (double)dist);
        }
        if (dp.flags) iplDirectEffectApply(c->direct, &dp, &g_in, &g_in);
    }
    if (dist < 1e-4f) { dir.x = 0.0f; dir.y = 0.0f; dir.z = -1.0f; }
    else { dir.x = gx / dist; dir.y = 0.0f; dir.z = gz / dist; }
    params.direction = dir;
    params.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
    params.spatialBlend = 1.0f;
    params.hrtf = g_hrtf;
    params.peakDelays = NULL;
    iplBinauralEffectApply(c->effect, &params, &g_in, &g_out);
    for (k = 0; k < FRAME; k++) {
        g_mixL[k] += g_out.data[0][k] * gain;
        g_mixR[k] += g_out.data[1][k] * gain;
    }
}

/* renders exactly one FRAME-sample block: zeroes the mix and sums every audible channel through
   the HRTF. each block is processed once, no matter how the device chunks its reads. */
static void process_block(void) {
    int i;
    memset(g_mixL, 0, sizeof(g_mixL));
    memset(g_mixR, 0, sizeof(g_mixR));
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
    (void)dev; (void)input;
    for (n = 0; n < frameCount; n++) {
        float l, r;
        if (g_fifo_read >= FRAME) { process_block(); g_fifo_read = 0; }
        l = g_mixL[g_fifo_read]; r = g_mixR[g_fifo_read]; g_fifo_read++;
        if (l > 1.0f) l = 1.0f; else if (l < -1.0f) l = -1.0f;
        if (r > 1.0f) r = 1.0f; else if (r < -1.0f) r = -1.0f;
        out[n * 2] = l;
        out[n * 2 + 1] = r;
    }
}

EXPORT int PA3D_Init(void) {
    IPLContextSettings cs;
    IPLHRTFSettings hs;
    ma_device_config cfg;
    if (g_ready) return 1;
    memset(g_ch, 0, sizeof(g_ch));
    g_fifo_read = FRAME;

    cfg = ma_device_config_init(ma_device_type_playback);
    cfg.playback.format = ma_format_f32;
    cfg.playback.channels = 2;
    cfg.sampleRate = 0;
    cfg.dataCallback = data_callback;
    cfg.performanceProfile = ma_performance_profile_low_latency;
    cfg.periodSizeInMilliseconds = 10;
    cfg.periods = 2;
    if (ma_device_init(NULL, &cfg, &g_device) != MA_SUCCESS) return 0;
    g_rate = (g_device.sampleRate > 0) ? (int)g_device.sampleRate : RATE;
    {
        unsigned int frames = g_device.playback.internalPeriodSizeInFrames * g_device.playback.internalPeriods;
        g_latency_ms = (g_rate > 0) ? (int)((frames * 1000) / (unsigned int)g_rate) : 0;
    }

    memset(&cs, 0, sizeof(cs));
    cs.version = STEAMAUDIO_VERSION;
    if (iplContextCreate(&cs, &g_ctx) != IPL_STATUS_SUCCESS || !g_ctx) {
        ma_device_uninit(&g_device); return 0;
    }

    g_audio.samplingRate = g_rate;
    g_audio.frameSize = FRAME;

    memset(&hs, 0, sizeof(hs));
    hs.type = IPL_HRTFTYPE_DEFAULT;
    hs.volume = 1.0f;
    hs.normType = IPL_HRTFNORMTYPE_NONE;
    if (iplHRTFCreate(g_ctx, &g_audio, &hs, &g_hrtf) != IPL_STATUS_SUCCESS || !g_hrtf) {
        iplContextRelease(&g_ctx); ma_device_uninit(&g_device); return 0;
    }

    if (iplAudioBufferAllocate(g_ctx, 1, FRAME, &g_in) != IPL_STATUS_SUCCESS ||
        iplAudioBufferAllocate(g_ctx, 2, FRAME, &g_out) != IPL_STATUS_SUCCESS) {
        iplHRTFRelease(&g_hrtf); iplContextRelease(&g_ctx); ma_device_uninit(&g_device); return 0;
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

/* per-channel occlusion amount 0-100 (0 = clear, 100 = fully muffled behind a wall). */
EXPORT void PA3D_Occl(int ch, int occ100) {
    if (ch < 0 || ch >= MAXCH || !g_ch[ch].used) return;
    g_ch[ch].occ100 = occ100;
}

/* global air-absorption toggle: 1 makes distant sources lose treble, 0 off. */
EXPORT void PA3D_Air(int on) {
    g_air = on ? 1 : 0;
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
    if (g_devstarted) { ma_device_stop(&g_device); g_devstarted = 0; }
    ma_device_uninit(&g_device);
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
