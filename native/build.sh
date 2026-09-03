#!/usr/bin/env bash
# Builds the PA3D positional-audio backend (Steam Audio) for win32 (x86) and win64 (x64) and runs the two
# standalone checks. Needs the llvm-mingw toolchain (i686-/x86_64-w64-mingw32-gcc, gendef, llvm-dlltool)
# and the two upstream checkouts, neither vendored here:
#
#   STEAMAUDIO_DIR -> the steam-audio repo checked out at the tag of the shipped phonon.dll (v4.8.1); the
#                     SDK headers live in unity/include/phonon, phonon_version.h already generated there
#   MINIAUDIO_DIR  -> the miniaudio repo (miniaudio.h at its root)
#
# Both default to sibling checkouts under ../../../../repositorios genericos/_refmods. No SDK import
# library is needed: each dll links against the phonon.dll the mod ships in assets/<arch>/ through an
# import library generated on the fly (the x86 exports are stdcall-decorated, which direct dll linking
# cannot resolve), so header, import table and runtime dll can never disagree on the version.
#
# Outputs to ./out; copy PA3D_steam_<arch>.dll over assets/<arch>/PA3D_steam.dll once the checks pass.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$here/out"; mkdir -p "$out"
refmods="$here/../../../../repositorios genericos/_refmods"
STEAMAUDIO_DIR="${STEAMAUDIO_DIR:-$refmods/steam-audio}"
MINIAUDIO_DIR="${MINIAUDIO_DIR:-$refmods/miniaudio}"
inc="$STEAMAUDIO_DIR/unity/include/phonon"
CFLAGS="-O2"
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
  "$cc" $CFLAGS -shared -o "$out/PA3D_steam_${tag}.dll" "$here/pa3d_steam.c" "$here/pa3d.def" \
    -I"$inc" -I"$MINIAUDIO_DIR" "$out/libphonon_$tag.a" -lwinmm -lole32
  echo "built $out/PA3D_steam_${tag}.dll"
}

build_steam i686-w64-mingw32-gcc   x86 i386
build_steam x86_64-w64-mingw32-gcc x64 i386:x86-64

x86_64-w64-mingw32-gcc $CFLAGS -o "$out/test_steam.exe" "$here/test_steam.c" -I"$inc" "$out/libphonon_x64.a" -lm
x86_64-w64-mingw32-gcc $CFLAGS -o "$out/test_pitch.exe" "$here/test_pitch.c" -I"$inc" -I"$MINIAUDIO_DIR" \
  "$out/libphonon_x64.a" -lwinmm -lole32
cp -f "$here/../assets/x64/phonon.dll" "$out/phonon.dll"
(cd "$out" && ./test_steam.exe && ./test_pitch.exe)
