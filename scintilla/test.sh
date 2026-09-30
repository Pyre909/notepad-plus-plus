#!/bin/sh
# test.sh TREE [OUT] : run the font-weight test (fonttest) and the Scintilla test program (scitest)
# against a Scintilla tree built by setup-trees.sh (TREE/bin/libscintilla.a), under Wine + Xvfb.
# Expected, trees with the rendering API (r567, both): scitest pass=229 fail=14 warn=4. The 14 FAILs are
# the two Notepad++-only options left out of the upstream patch (SC_RENDERINGMODE_ADAPTIVE and
# SC_FONTRENDERING_LIGHTTEXTGAMMA); the 4 WARNs are a Wine call tip repaint loop pristine Scintilla shows too.
# Trees with the weight-names fix (p567, both): DirectWrite ink of "Fira Code Light/Medium" within 0.1% of GDI's.
set -e
H=$(cd "$(dirname "$0")" && pwd); R=$(cd "$H/.." && pwd)
TREE=$(cd "$1" && pwd); OUT=${2:-$TREE/../test-$(basename "$TREE")}
mkdir -p "$OUT" && OUT=$(cd "$OUT" && pwd)
LIB=$TREE/bin/libscintilla.a; INC=$TREE/include
LIBS="-static -static-libgcc -static-libstdc++ -mconsole -lgdi32 -luser32 -limm32 -lmsimg32 -lole32 -loleaut32 -luuid -lcomctl32 -luxtheme -lshcore -ldwmapi -ldwrite"
x86_64-w64-mingw32-g++ -std=c++17 -O1 -DUNICODE -D_UNICODE -DNOMINMAX -D_WIN32_WINNT=0x0601 -I "$INC" "$R/fonttest/fonttest.cpp" "$LIB" $LIBS -o "$OUT/fonttest.exe"
DEF=; grep -q 'SC_FONT_RENDERING_DEFAULT' "$INC/Scintilla.h" && DEF=-DSC_FONTRENDERING_DEFAULT=-1
x86_64-w64-mingw32-g++ -std=c++20 -O1 -g0 -Wall -Wno-unused-function -DUNICODE -D_UNICODE -DNOMINMAX -D_WIN32_WINNT=0x0601 $DEF \
	-I "$INC" "$R/harness/src/scitest.cpp" "$LIB" $LIBS -ld2d1 -ld3d11 -ldxgi -lwindowscodecs -o "$OUT/scitest.exe"
. "$R/harness/env.sh"
( harness_prefix
  timeout -k 5 180 xvfb-run -a -s "-screen 0 1280x800x24" "$WINE" "$OUT/fonttest.exe" 2>/dev/null | tr -d '\r' > "$OUT/fonttest.txt" || true
  "$WINESERVER" -k 2>/dev/null || true; "$WINESERVER" -w 2>/dev/null || true )
grep '^bold=' "$OUT/fonttest.txt" | sed 's/  */ /g'
"$R/harness/run_scitest.sh" -e "$OUT/scitest.exe" -o "$OUT/scitest" > "$OUT/scitest.log" 2>&1 || true
grep -E 'SCITEST_SUMMARY' "$OUT/scitest.log"
