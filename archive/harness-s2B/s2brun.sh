#!/bin/sh
# s2brun.sh: run s2bdrive.exe against a notepad++.exe under Wine + Xvfb (adapted from harness-dpi/dpirun.sh).
# Usage: s2brun.sh APPDIR SETTINGSDIR OUTDIR PREFIX DPI TAG [s2bdrive args...]
#   APPDIR      directory containing notepad++.exe (copied to OUTDIR/app-TAG, the source is never written)
#   SETTINGSDIR settings directory (-settingsDir), kept between runs (created if missing)
#   PREFIX      Wine prefix, DPI written to HKCU\Control Panel\Desktop\LogPixels
# The DPI override file of the test build is OUTDIR/dpi-TAG.txt (env NPP_TEST_DPI_FILE, --dpifile).
D=$(cd "$(dirname "$0")" && pwd)
APP=$1; SET=$2; OUT=$3; PFX=$4; DPI=$5; TAG=$6; shift 6
APP=$(cd "$APP" && pwd); PFX=$(cd "$PFX" && pwd)
export WINEPREFIX=$PFX WINEDEBUG=-all WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml="
WINE=/usr/lib/wine/wine64; WINESERVER=/usr/lib/wine/wineserver
to_win() { printf 'Z:%s' "$(printf '%s' "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT" "$SET"
OUT=$(cd "$OUT" && pwd); SET=$(cd "$SET" && pwd)
DRIVE=$D/s2bdrive.exe
if [ ! -f "$DRIVE" ] || [ "$D/src/s2bdrive.cpp" -nt "$DRIVE" ]; then
  x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -DUNICODE -D_UNICODE "$D/src/s2bdrive.cpp" -static -static-libgcc -static-libstdc++ -mconsole \
    -lgdi32 -luser32 -o "$DRIVE" || exit 2
fi
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT/app-$TAG"; cp -r "$APP" "$OUT/app-$TAG"
  [ -f "$OUT/sample.txt" ] || cat > "$OUT/sample.txt" <<'EOF'
Hello from s2brun: The quick brown fox jumps over the lazy dog 0123456789
int main(int argc, char **argv) { return printf("%d\n", argc); } // code line
EOF
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN:-1600x1100x24}" "$0" "$APP" "$SET" "$OUT" "$PFX" "$DPI" "$TAG" "$@"
fi
exec 9>"$PFX.lock"; flock -w 3600 9 || exit 75
printf 'REGEDIT4\n\n[HKEY_CURRENT_USER\\Control Panel\\Desktop]\n"LogPixels"=dword:%08x\n' "$DPI" > "$PFX/dpi.reg"
"$WINE" regedit /S "$(to_win "$PFX/dpi.reg")" >/dev/null 2>&1
"$WINESERVER" -w
EXTRA=
if [ -n "$TESTDPI" ]; then
  export NPP_TEST_DPI_FILE="$(to_win "$OUT/dpi-$TAG.txt")"
  EXTRA="--dpifile $NPP_TEST_DPI_FILE"
fi
( cd "$OUT/app-$TAG" && timeout -k 5 300 "$WINE" "$DRIVE" --exe "$(to_win "$OUT/app-$TAG/notepad++.exe")" --settings "$(to_win "$SET")" \
    --file "$(to_win "$OUT/sample.txt")" --out "Z:$OUT" --tag "$TAG" $EXTRA "$@" ) > "$OUT/$TAG.out" 2> "$OUT/stderr_$TAG.log"
e=$?
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
for f in "$OUT"/"$TAG"_*.bmp; do [ -f "$f" ] && convert "$f" "${f%.bmp}.png" && rm -f "$f"; done
cat "$OUT/$TAG.out"
echo "driver exit $e"
exit $e
