/* Reuse the upstream device-free Steam Audio/tone helpers, not its main.
   Tests render through the actual production mix_channel/process_block code. */
#define main upstream_pitch_main
#include "test_pitch.c"
#undef main

static void energy(int x, int y, double* left, double* right) {
    int block, sample;
    Channel* channel = &g_ch[0];
    channel->x100 = x; channel->y100 = y; channel->head = 0;
    *left = 0; *right = 0;
    for (block = 0; block < 32; block++) {
        process_block();
        if (block < 16) continue;
        for (sample = 0; sample < FRAME; sample++) {
            if (!isfinite(g_mix[0][sample]) || !isfinite(g_mix[1][sample])) {
                printf("FAIL non-finite rendered audio\n"); failures++; return;
            }
            *left += (double)g_mix[0][sample] * g_mix[0][sample];
            *right += (double)g_mix[1][sample] * g_mix[1][sample];
        }
    }
}

int main(void) {
    static float pcm[TONE_RATE];
    double left, right, total, frontEnergy, low, high, head;
    int toggle;
    expect("HRTF starts enabled", g_output, OUT_BINAURAL);
    if (!init_steam() || !tone_channel(pcm, 440)) {
        printf("FAIL real Steam Audio setup\n"); return 1;
    }
    g_devstarted = 1; g_device.playback.internalChannels = 2; /* device-free same-layout switching */
    energy(-300, 0, &left, &right);
    expect_within("HRTF left source remains audible in both ears", left / right, 1.1, 100);
    PA3D_HRTF(0);
    g_devstarted = 1; g_device.playback.internalChannels = 2; /* device-free same-layout switching */
    energy(-300, 0, &left, &right);
    expect_within("stereo left source is audible", left, 1, 1000);
    expect("stereo left source has no opposite-ear leakage", right, 0);
    total = left + right;
    energy(300, 0, &left, &right);
    expect_within("stereo right source is audible", right, 1, 1000);
    expect("stereo right source has no opposite-ear leakage", left, 0);
    energy(0, -300, &left, &right);
    expect_within("stereo front is balanced", left / right, 0.999, 1.001);
    frontEnergy = left + right;
    expect_within("panning preserves total source power", frontEnergy / total, 0.999, 1.001);
    energy(0, -1000, &left, &right);
    expect_within("distance attenuation still works in stereo", (left + right) / frontEnergy, 0.12, 0.15);
    PA3D_Master(50);
    energy(0, -300, &left, &right);
    expect_within("master volume still works in stereo", (left + right) / frontEnergy, 0.249, 0.251);
    PA3D_Master(0);
    energy(0, -300, &left, &right);
    expect("zero master remains silent", left + right, 0);
    PA3D_Master(100);
    g_ch[0].x100 = -300; g_ch[0].y100 = 0;
    g_ch[0].pitch100 = 200; g_ch[0].head = 0;
    process_block();
    expect("pitch still advances the source at double rate", g_ch[0].head, FRAME * 2);
    g_ch[0].pitch100 = 100;
    for (toggle = 0; toggle < 40; toggle++) {
        head = g_ch[0].head;
        if (toggle % 2) PA3D_Hrtf(1);
        else PA3D_HRTF(0);
        process_block();
        expect("live toggle retains the playback position", g_ch[0].head, head + FRAME);
        expect("requested mode is applied on the next block", g_render_output, toggle % 2 ? OUT_BINAURAL : OUT_STEREO);
    }
    {
        double measured;
        PA3D_HRTF(0);
        PA3D_DirectionalPitch(140, 60, 75, 125);
        stereo_db(0, -300, &total, &measured);
        expect_within("front pitch follows its independent setting", measured, 1.399, 1.401);
        stereo_db(0, 300, &total, &measured);
        expect_within("back pitch follows its independent setting", measured, 0.599, 0.601);
        stereo_db(-300, 0, &total, &measured);
        expect_within("left pitch follows its independent setting", measured, 0.749, 0.751);
        stereo_db(300, 0, &total, &measured);
        expect_within("right pitch follows its independent setting", measured, 1.249, 1.251);
        stereo_db(0, 0, &total, &measured);
        expect_within("a source on the listener keeps its original pitch", measured, 0.999, 1.001);
        g_ch[0].x100 = 0; g_ch[0].y100 = -300; g_ch[0].head = 0;
        PA3D_DirectionalPitch(60, 140, 125, 75);
        mix_channel(&g_ch[0]);
        expect_within("new pitches do not alter a block already in progress", g_ch[0].head / FRAME, 1.399, 1.401);
        head = g_ch[0].head;
        process_block();
        expect_within("next block commits the new directional set", (g_ch[0].head - head) / FRAME, 0.599, 0.601);
        PA3D_Hrtf(1);
        stereo_db(0, -300, &total, &measured);
        expect_within("directional settings leave binaural pitch unchanged", measured, 0.999, 1.001);
        PA3D_HRTF(0);
        PA3D_DirectionalPitch(-999, 999, -999, 999);
        stereo_db(0, -300, &total, &measured);
        expect_within("directional API clamps its lower bound", measured, 0.499, 0.501);
        stereo_db(0, 300, &total, &measured);
        expect_within("directional API clamps its upper bound", measured, 1.499, 1.501);
        PA3D_DirectionalPitch(120, 120, 120, 120);
        stereo_db(300, -300, &total, &measured);
        expect_within("equal pitches stay equal between directions", measured, 1.199, 1.201);
        PA3D_DirectionalPitch(120, 150, 120, 150);
        stereo_db(-300, -300, &total, &measured);
        expect_within("higher unrelated directions leave equal front-left pitches unchanged", measured, 1.199, 1.201);
        PA3D_DirectionalPitch(120, 50, 120, 50);
        stereo_db(-300, -300, &total, &measured);
        expect_within("lower unrelated directions leave equal front-left pitches unchanged", measured, 1.199, 1.201);
        PA3D_DirectionalPitch(60, 150, 75, 150);
        stereo_db(-300, -300, &total, &measured);
        expect_within("two lower adjacent pitches blend within their own range", measured, 0.643, 0.645);
        PA3D_DirectionalPitch(140, 50, 75, 50);
        stereo_db(-300, -300, &total, &measured);
        expect_within("different adjacent pitches blend without unrelated settings", measured, 1.209, 1.211);
        PA3D_DirectionalPitch(120, 80, 100, 100);
    }
    {
        int axis, mode;
        double measured;
        const int positions[4][2] = {{0, -300}, {0, 300}, {-300, 0}, {300, 0}};
        const double adjusted[4] = {1.25, 0.75, 1.0, 1.5};
        PA3D_DirectionalPitch(150, 50, 75, 125);
        PA3D_ChannelDirections(0, 100, 100, 100, 100);
        PA3D_FixedPitch(0, 1);
        for (mode = OUT_MONO; mode <= OUT_STEREO; mode++) {
            /* Exercise the real renderer without reopening a hardware device from this fixture. */
            InterlockedExchange(&g_output, (LONG)mode);
            for (axis = 0; axis < 4; axis++) {
                stereo_db(positions[axis][0], positions[axis][1], &total, &measured);
                expect_within("contact pitch is invariant under shared cardinal settings", measured, 0.999, 1.001);
            }
        }
        g_device.playback.internalChannels = 2;
        PA3D_Output(OUT_STEREO);
        energy(-300, 0, &left, &right);
        expect_within("fixed contact preserves left panning", left, 1, 1000);
        expect("fixed contact preserves opposite-ear silence", right, 0);
        PA3D_Pitch(0, 141);
        stereo_db(0, 300, &total, &measured);
        expect_within("contact keeps its independently chosen family tone", measured, 1.409, 1.411);
        PA3D_Pitch(0, 100);
        PA3D_ChannelDirections(0, 125, 75, 100, 150);
        for (axis = 0; axis < 4; axis++) {
            stereo_db(positions[axis][0], positions[axis][1], &total, &measured);
            expect_within("contact category directions remain independently adjustable", measured, adjusted[axis] - 0.001, adjusted[axis] + 0.001);
        }
        PA3D_FixedPitch(0, 0);
        stereo_db(0, -300, &total, &measured);
        expect_within("ordinary category adjustment multiplies the shared direction", measured, 1.874, 1.876);
        PA3D_ChannelDirections(0, 125, 200, 100, 50);
        stereo_db(-300, -300, &total, &measured);
        head = measured;
        PA3D_ChannelDirections(0, 125, 50, 100, 200);
        stereo_db(-300, -300, &total, &measured);
        expect_within("unrelated category quadrants cannot change front-left pitch", measured, head - 0.0001, head + 0.0001);
        PA3D_Output(OUT_BINAURAL);
        stereo_db(0, -300, &total, &measured);
        expect_within("category adjustments preserve binaural rendering pitch", measured, 0.999, 1.001);
        PA3D_Output(OUT_STEREO);
        PA3D_FixedPitch(0, 1);
        PA3D_ChannelDirections(0, -10, 999, 100, 100);
        stereo_db(0, -300, &total, &measured);
        expect_within("category lower bound is enforced", measured, 0.499, 0.501);
        stereo_db(0, 300, &total, &measured);
        expect_within("category upper bound is enforced", measured, 1.999, 2.001);
        PA3D_ChannelDirections(-1, 50, 50, 50, 50);
        PA3D_FixedPitch(-1, 1);
        stereo_db(0, 300, &total, &measured);
        expect_within("invalid channel controls leave the active channel unchanged", measured, 1.999, 2.001);
        PA3D_FixedPitch(0, 0);
        PA3D_ChannelDirections(0, 100, 100, 100, 100);
        PA3D_DirectionalPitch(120, 80, 100, 100);
    }
    PA3D_HRTF(0); drop_channel();
    if (!tone_channel(pcm, 300)) return 1;
    low = muffled_db(80); drop_channel();
    if (!tone_channel(pcm, 12000)) return 1;
    high = muffled_db(80); drop_channel();
    expect_within("stereo keeps low-frequency wall attenuation", low, -6, -2);
    expect_within("stereo keeps high-frequency wall attenuation", high, -20, -9);
    expect_within("stereo retains frequency-dependent wall muffling", low - high, 6, 20);
    iplAudioBufferFree(g_ctx, &g_in); iplAudioBufferFree(g_ctx, &g_out);
    iplHRTFRelease(&g_hrtf); iplContextRelease(&g_ctx);
    printf("RESULT: %s (%d failures)\n", failures ? "FAIL" : "OK", failures);
    return failures ? 1 : 0;
}
