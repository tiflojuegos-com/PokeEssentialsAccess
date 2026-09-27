#!/usr/bin/env bash
# Builds the PA3D positional-audio backend (Steam Audio) for x86 and x64 and runs the two standalone checks.
# Needs the llvm-mingw toolchain (i686-/x86_64-w64-mingw32-gcc, gendef, llvm-dlltool) and two checkouts:
#   STEAMAUDIO_DIR  the steam-audio repo at the tag of the shipped phonon.dll (v4.8.1; headers in unity/include)
#   MINIAUDIO_DIR   the miniaudio repo (miniaudio.h at its root)
# Each dll links against assets/<arch>/phonon.dll through an import library generated here (the x86 exports are
# stdcall-decorated). Outputs to ./out; copy PA3D_steam_<arch>.dll over assets/<arch>/PA3D_steam.dll once the
# checks pass.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"; mkdir -p "$out"
STEAMAUDIO_DIR="${STEAMAUDIO_DIR:?set STEAMAUDIO_DIR to a steam-audio checkout (tag v4.8.1)}"
MINIAUDIO_DIR="${MINIAUDIO_DIR:?set MINIAUDIO_DIR to a miniaudio checkout}"
inc="$STEAMAUDIO_DIR/unity/include/phonon"
CFLAGS="-O2"
# Build folders mapped to short names, so no path of the building machine ends up in a dll.
MAPS=(-ffile-prefix-map="$MINIAUDIO_DIR"=miniaudio -ffile-prefix-map="$STEAMAUDIO_DIR"=steam-audio
      -ffile-prefix-map="$here"=native)
[ -f "$inc/phonon.h" ] || { echo "phonon.h not found under $inc: set STEAMAUDIO_DIR to a steam-audio checkout"; exit 1; }
[ -f "$MINIAUDIO_DIR/miniaudio.h" ] || { echo "miniaudio.h not found: set MINIAUDIO_DIR to a miniaudio checkout"; exit 1; }

# Import library for the shipped phonon.dll of one architecture.
implib() {
  local tag="$1" machine="$2"
  gendef - "$here/../assets/$tag/phonon.dll" > "$out/phonon_$tag.def" 2>/dev/null
  llvm-dlltool -m "$machine" -d "$out/phonon_$tag.def" -D phonon.dll -l "$out/libphonon_$tag.a"
}

build_steam() {
  local cc="$1" tag="$2" machine="$3"
  implib "$tag" "$machine"
  "$cc" $CFLAGS "${MAPS[@]}" -shared -o "$out/PA3D_steam_${tag}.dll" "$here/pa3d_steam.c" "$here/pa3d.def" \
    -I"$inc" -I"$MINIAUDIO_DIR" "$out/libphonon_$tag.a" -lwinmm -lole32
  echo "built $out/PA3D_steam_${tag}.dll"
}

build_steam i686-w64-mingw32-gcc   x86 i386
build_steam x86_64-w64-mingw32-gcc x64 i386:x86-64

x86_64-w64-mingw32-gcc $CFLAGS "${MAPS[@]}" -o "$out/test_steam.exe" "$here/test_steam.c" -I"$inc" "$out/libphonon_x64.a" -lm
x86_64-w64-mingw32-gcc $CFLAGS "${MAPS[@]}" -o "$out/test_pitch.exe" "$here/test_pitch.c" -I"$inc" -I"$MINIAUDIO_DIR" \
  "$out/libphonon_x64.a" -lwinmm -lole32
cp -f "$here/../assets/x64/phonon.dll" "$out/phonon.dll"
(cd "$out" && ./test_steam.exe && ./test_pitch.exe)
