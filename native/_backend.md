# PA3D native audio backend (Steam Audio)

PA3D is the small DLL behind `core/audio/audio3d.rb` (the binaural soundscape). It exposes a
tiny integer/string ABI so the Ruby side never changes:

```
int  PA3D_Init(void)
int  PA3D_Channel(const char* wavPath, int loop)   // -> channel id, or -1
void PA3D_Listener(int x100, int y100)
void PA3D_Set(int ch, int x100, int y100, int vol100, int play)
void PA3D_Master(int vol100)
void PA3D_Occl(int ch, int occ100)                 // 0 clear .. 100 fully muffled behind a wall
void PA3D_Air(int on)                              // distant sources lose treble
void PA3D_Pitch(int ch, int pitch100)              // playback rate percent, 100 = as recorded, 25..400
int  PA3D_Rate(void)                               // the device's native sample rate, 0 if down
int  PA3D_Latency(void)                            // output buffer latency in ms, 0 if down
void PA3D_Shutdown(void)
```

Coordinates are tile units times 100. The listener faces north (`-z`); map `x -> x`,
map `y -> z`. Distance attenuation is linear, clamped between 1 and 14 tiles. The Ruby side treats
everything after `PA3D_Master` as optional: an older dll simply lacks the feature.

## Implementation

`pa3d_steam.c` -> `PA3D_steam.dll`. It uses **Steam Audio (phonon)** for the HRTF math and
**miniaudio** for the output device and mixing: each active channel is rendered with
`iplBinauralEffectApply` and the results are summed in a single playback callback (frame size
256, device native rate). Each channel is resampled to the device rate with linear interpolation,
and the per-channel pitch is one more factor on that same step (the tone menu). Each DLL depends on
`phonon.dll` of the matching architecture (~46 MB x86 / ~53 MB x64) sitting beside it in the install's
`accessibility/lib/` folder; `SetDllDirectory` (set in `speech.rb`) puts that folder on the DLL search
path so it resolves.

miniaudio is compiled into the DLL (header-only). Z/Ópalo are x86; Reminiscencia/Añil are x64.

## Building

Needs the llvm-mingw toolchain (`i686-`/`x86_64-w64-mingw32-gcc`, `gendef`, `llvm-dlltool`; scoop's
`mingw-mstorsjo-llvm-msvcrt`) and two upstream checkouts, neither vendored here because of size and
licensing:

- `STEAMAUDIO_DIR`: the steam-audio repo at the tag of the shipped `phonon.dll` (`v4.8.1`). The SDK
  headers are in `unity/include/phonon`, `phonon_version.h` already generated.
- `MINIAUDIO_DIR`: the miniaudio repo (`miniaudio.h` at its root).

```bash
./build.sh   # defaults to ../../../../repositorios genericos/_refmods/{steam-audio,miniaudio}
```

There is no SDK import library to fetch: `build.sh` generates one from the `phonon.dll` in
`assets/<arch>/` and links against it, so header, import table and runtime dll always agree on the
version. It writes `PA3D_steam_{x86,x64}.dll` to `./out` and runs the two checks; copy the dlls over
`assets/<arch>/PA3D_steam.dll` once they pass.

`test_steam.c` is a standalone correctness check of the HRTF path (no audio device required): it
creates a context, HRTF and binaural effect, renders a 440 Hz tone toward several directions and
asserts the output is non-silent and properly panned (left direction => more energy in the left ear).
`test_pitch.c` checks the resampler's pitch: it includes `pa3d_steam.c` whole, pulls a ramp through
`pull_samples` at several rates and asserts the read head and the interpolated samples, then the
export's clamping. Both run with the x64 `phonon.dll` beside them.
