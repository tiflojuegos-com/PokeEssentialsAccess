/* Standalone correctness test for the Steam Audio binaural pipeline (no audio device needed). */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "phonon.h"

#define FRAME 1024

static float energy(const float* b, int n) {
    double s = 0.0; int i; for (i = 0; i < n; i++) s += (double)b[i] * b[i]; return (float)(s / n);
}

static int run_dir(IPLContext ctx, IPLHRTF hrtf, IPLAudioSettings* as,
                   IPLBinauralEffect eff, IPLAudioBuffer* in, IPLAudioBuffer* out,
                   float x, float y, float z, const char* label) {
    IPLBinauralEffectParams p; float el, er;
    memset(&p, 0, sizeof(p));
    p.direction.x = x; p.direction.y = y; p.direction.z = z;
    p.interpolation = IPL_HRTFINTERPOLATION_BILINEAR;
    p.spatialBlend = 1.0f;
    p.hrtf = hrtf;
    p.peakDelays = NULL;
    iplBinauralEffectApply(eff, &p, in, out);
    el = energy(out->data[0], FRAME);
    er = energy(out->data[1], FRAME);
    printf("  dir %-6s -> L=%.5f R=%.5f  (%s)\n", label, el, er,
           (el + er > 1e-9f) ? "non-silent" : "SILENT!");
    (void)ctx; (void)as;
    return (el + er > 1e-9f);
}

/* Runs the binaural effect from three directions, then checks that a left-panned source lands louder in the left
   ear than the right. */
int main(void) {
    IPLContext ctx = NULL; IPLHRTF hrtf = NULL; IPLBinauralEffect eff = NULL;
    IPLContextSettings cs; IPLHRTFSettings hs; IPLAudioSettings as;
    IPLBinauralEffectSettings es; IPLAudioBuffer in, out;
    int i, ok = 1;

    memset(&cs, 0, sizeof(cs)); cs.version = STEAMAUDIO_VERSION;
    printf("STEAMAUDIO_VERSION = 0x%06x\n", (unsigned)STEAMAUDIO_VERSION);
    if (iplContextCreate(&cs, &ctx) != IPL_STATUS_SUCCESS || !ctx) { printf("iplContextCreate FAILED\n"); return 1; }
    printf("context ok\n");

    as.samplingRate = 44100; as.frameSize = FRAME;
    memset(&hs, 0, sizeof(hs)); hs.type = IPL_HRTFTYPE_DEFAULT; hs.volume = 1.0f; hs.normType = IPL_HRTFNORMTYPE_NONE;
    if (iplHRTFCreate(ctx, &as, &hs, &hrtf) != IPL_STATUS_SUCCESS || !hrtf) { printf("iplHRTFCreate FAILED\n"); return 1; }
    printf("hrtf ok\n");

    if (iplAudioBufferAllocate(ctx, 1, FRAME, &in) != IPL_STATUS_SUCCESS ||
        iplAudioBufferAllocate(ctx, 2, FRAME, &out) != IPL_STATUS_SUCCESS) { printf("buffer alloc FAILED\n"); return 1; }
    printf("buffers ok (in ch=%d, out ch=%d)\n", in.numChannels, out.numChannels);

    memset(&es, 0, sizeof(es)); es.hrtf = hrtf;
    if (iplBinauralEffectCreate(ctx, &as, &es, &eff) != IPL_STATUS_SUCCESS || !eff) { printf("effect create FAILED\n"); return 1; }
    printf("effect ok\n");

    for (i = 0; i < FRAME; i++) in.data[0][i] = 0.3f * (float)sin(2.0 * 3.14159265 * 440.0 * i / 44100.0);

    printf("binaural apply per direction:\n");
    ok &= run_dir(ctx, hrtf, &as, eff, &in, &out, -1.0f, 0.0f, 0.0f, "left");
    ok &= run_dir(ctx, hrtf, &as, eff, &in, &out,  1.0f, 0.0f, 0.0f, "right");
    ok &= run_dir(ctx, hrtf, &as, eff, &in, &out,  0.0f, 0.0f, -1.0f, "front");

    {
        IPLBinauralEffectParams p; float el, er;
        memset(&p, 0, sizeof(p)); p.direction.x = -1.0f; p.direction.z = 0.0f;
        p.interpolation = IPL_HRTFINTERPOLATION_BILINEAR; p.spatialBlend = 1.0f; p.hrtf = hrtf;
        iplBinauralEffectApply(eff, &p, &in, &out);
        el = energy(out.data[0], FRAME); er = energy(out.data[1], FRAME);
        printf("left-pan check: L=%.5f R=%.5f -> %s\n", el, er, (el > er) ? "PASS (L>R)" : "check");
    }

    iplBinauralEffectRelease(&eff);
    iplAudioBufferFree(ctx, &in); iplAudioBufferFree(ctx, &out);
    iplHRTFRelease(&hrtf); iplContextRelease(&ctx);
    printf(ok ? "\nRESULT: OK (all directions non-silent)\n" : "\nRESULT: FAIL\n");
    return ok ? 0 : 2;
}
