#!/bin/sh
# s2arun.sh: run s2adrive.exe against a notepad++.exe under Wine + Xvfb, with a given Wine prefix and DPI.
# Usage: s2arun.sh APPDIR SETTINGSDIR OUTDIR PREFIX DPI TAG [s2adrive args...]
#   APPDIR      directory containing notepad++.exe (copied to OUTDIR/app-TAG)
#   SETTINGSDIR prepared settings directory (mksettings.py), copied to OUTDIR/set-TAG (the source is never written)
#   PREFIX      Wine prefix (a copy of the harness prefix), DPI written to HKCU\Control Panel\Desktop\LogPixels
D=$(cd "$(dirname "$0")" && pwd)
APP=$1; SETSRC=$2; OUT=$3; PFX=$4; DPI=$5; TAG=$6; shift 6
APP=$(cd "$APP" && pwd); PFX=$(cd "$PFX" && pwd); SETSRC=$(cd "$SETSRC" && pwd)
export WINEPREFIX=$PFX WINEDEBUG=-all WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml="
WINE=/usr/lib/wine/wine64; WINESERVER=/usr/lib/wine/wineserver
to_win() { printf 'Z:%s' "$(printf '%s' "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
DRIVE=$D/s2adrive.exe
if [ ! -f "$DRIVE" ] || [ "$D/src/s2adrive.cpp" -nt "$DRIVE" ]; then
  x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -DUNICODE -D_UNICODE "$D/src/s2adrive.cpp" -static -static-libgcc -static-libstdc++ -mconsole \
    -lgdi32 -luser32 -o "$DRIVE" || exit 2
fi
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT/app-$TAG" "$OUT/set-$TAG"; cp -r "$APP" "$OUT/app-$TAG"; cp -r "$SETSRC" "$OUT/set-$TAG"
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN:-1280x1024x24}" "$0" "$APP" "$SETSRC" "$OUT" "$PFX" "$DPI" "$TAG" "$@"
fi
exec 9>"$PFX.lock"; flock -w 3600 9 || exit 75
printf 'REGEDIT4\n\n[HKEY_CURRENT_USER\\Control Panel\\Desktop]\n"LogPixels"=dword:%08x\n' "$DPI" > "$PFX/dpi.reg"
"$WINE" regedit /S "$(to_win "$PFX/dpi.reg")" >/dev/null 2>&1
"$WINESERVER" -w
( cd "$OUT/app-$TAG" && timeout -k 5 300 "$WINE" "$DRIVE" --exe "$(to_win "$OUT/app-$TAG/notepad++.exe")" --settings "$(to_win "$OUT/set-$TAG")" \
    --file "$(to_win "$D/data/sample.cpp")" --out "Z:$OUT" --tag "$TAG" "$@" ) > "$OUT/$TAG.out" 2> "$OUT/stderr_$TAG.log"
e=$?
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
for f in "$OUT"/"$TAG"_*.bmp; do [ -f "$f" ] && convert "$f" "${f%.bmp}.png" && rm -f "$f"; done
cat "$OUT/$TAG.out"
echo "driver exit $e"
exit $e
