#!/bin/sh
# Build scitest.exe against a Notepad++ gcc build's static Scintilla.
# Usage: build_scitest.sh [LIBSCINTILLA_A] [SCINTILLA_INCLUDE_DIR] [OUT_EXE]
#   env: LIBSCINTILLA, SCI_INCLUDE, SCITEST_EXE override the same things.
# Defaults: the main checkout's build (/home/user/notepad-plus-plus).
set -e
H=$(cd "$(dirname "$0")" && pwd)
LIB=${1:-${LIBSCINTILLA:-/home/user/notepad-plus-plus/PowerEditor/gcc/bin.gcc.x86_64.build/libscintilla.a}}
INC=${2:-${SCI_INCLUDE:-}}
if [ -z "$INC" ]; then
  # <checkout>/PowerEditor/gcc/bin.gcc.x86_64.build/libscintilla.a -> <checkout>/scintilla/include
  # or, for a build_scilib.sh output dir, <dir>/src/scintilla/include
  CAND=$(cd "$(dirname "$LIB")/../../.." 2>/dev/null && pwd)/scintilla/include
  CAND2=$(cd "$(dirname "$LIB")" && pwd)/src/scintilla/include
  if [ -f "$CAND2/Scintilla.h" ]; then INC=$CAND2
  elif [ -f "$CAND/Scintilla.h" ]; then INC=$CAND
  else INC=/home/user/notepad-plus-plus/scintilla/include; fi
fi
OUT=${3:-${SCITEST_EXE:-$H/out/scitest.exe}}
mkdir -p "$(dirname "$OUT")"
[ -f "$LIB" ] || { echo "no such library: $LIB" >&2; exit 1; }
[ -f "$INC/Scintilla.h" ] || { echo "no Scintilla.h in $INC" >&2; exit 1; }
echo "building $OUT"
echo "  lib:     $LIB ($(stat -c '%y' "$LIB" | cut -d. -f1))"
echo "  include: $INC"
x86_64-w64-mingw32-g++ -std=c++20 -O1 -g0 -Wall -Wno-unused-function \
  -DUNICODE -D_UNICODE -DNOMINMAX -D_WIN32_WINNT=0x0601 \
  -I"$INC" "$H/src/scitest.cpp" "$LIB" \
  -static -static-libgcc -static-libstdc++ -mconsole \
  -lgdi32 -luser32 -limm32 -lmsimg32 -lole32 -loleaut32 -luuid -lcomctl32 -luxtheme -lshcore -ldwmapi \
  -o "$OUT"
echo "ok: $OUT"
