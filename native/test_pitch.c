/*
  Standalone check of the per-channel pitch. Includes pa3d_steam.c whole so the static pull_samples is
  reachable, feeds it a ramp and asserts the read head advances pitch percent as fast, then exercises the
  export's clamping. No audio device is opened. Links phonon like the dll does (the included file
  references it), so phonon.dll of the matching architecture must sit beside the executable to start.
*/
#include "pa3d_steam.c"

static int failures = 0;

static void expect(const char* label, double got, double want) {
    double d = got - want;
    if (d < 0) d = -d;
    if (d > 1e-4) { printf("FAIL %s: got %.5f want %.5f\n", label, got, want); failures++; }
    else printf("ok   %s\n", label);
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

    if (failures) printf("RESULT: FAIL (%d)\n", failures);
    else printf("RESULT: OK\n");
    return failures ? 1 : 0;
}
