#!/bin/sh
# run.sh: run s2cdrive.exe against a notepad++.exe under Wine + Xvfb, with the Wine prefix of this directory and a given DPI.
# Usage: run.sh APPDIR SETTINGSDIR OUTDIR DPI TAG [s2cdrive args...]
#   APPDIR      directory containing notepad++.exe (copied to OUTDIR/app-TAG, the source is never written)
#   SETTINGSDIR settings directory (-settingsDir), created if missing
#   DPI         written to HKCU\Control Panel\Desktop\LogPixels of the prefix before the run
# Environment: NPP_TEST_PMV2=1 is passed to Notepad++ (the throwaway test build then forces the per-monitor code paths)
D=$(cd "$(dirname "$0")" && pwd)
APP=$1; SET=$2; OUT=$3; DPI=$4; TAG=$5; shift 5
APP=$(cd "$APP" && pwd); PFX=$D/pfx
export WINEPREFIX=$PFX WINEDEBUG=-all WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml="
WINE=/usr/lib/wine/wine64; WINESERVER=/usr/lib/wine/wineserver
to_win() { printf 'Z:%s' "$(printf '%s' "$1" | sed 's#/#\\#g')"; }
mkdir -p "$OUT" "$SET"
OUT=$(cd "$OUT" && pwd); SET=$(cd "$SET" && pwd)
DRIVE=$D/s2cdrive.exe
if [ ! -f "$DRIVE" ] || [ "$D/src/s2cdrive.cpp" -nt "$DRIVE" ]; then
  x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -DUNICODE -D_UNICODE "$D/src/s2cdrive.cpp" -static -static-libgcc -static-libstdc++ -mconsole \
    -lgdi32 -luser32 -lcomctl32 -o "$DRIVE" || exit 2
fi
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT/app-$TAG"; cp -r "$APP" "$OUT/app-$TAG"
  [ -f "$OUT/sample.txt" ] || python3 - "$OUT/sample.txt" <<'EOF'
import sys
lines = []
for i in range(1, 301):
    if i % 7 == 0:
        lines.append("line %d: The quick brown fox jumps over the lazy dog %d" % (i, i))
    elif i % 5 == 0:
        lines.append("int f%d(int x) { return x * %d; } // code line %d" % (i, i, i))
    else:
        lines.append("line %d " % i + "abcdefghij " * (i % 9))
open(sys.argv[1], "w", newline="\r\n").write("\n".join(lines) + "\n")
EOF
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 ${XVFB_SCREEN:-1920x1200x24}" "$0" "$APP" "$SET" "$OUT" "$DPI" "$TAG" "$@"
fi
exec 9>"$PFX.lock"; flock -w 3600 9 || exit 75
printf 'REGEDIT4\n\n[HKEY_CURRENT_USER\\Control Panel\\Desktop]\n"LogPixels"=dword:%08x\n' "$DPI" > "$PFX/dpi.reg"
"$WINE" regedit /S "$(to_win "$PFX/dpi.reg")" >/dev/null 2>&1
"$WINESERVER" -w
( cd "$OUT/app-$TAG" && timeout -k 5 400 "$WINE" "$DRIVE" --exe "$(to_win "$OUT/app-$TAG/notepad++.exe")" --settings "$(to_win "$SET")" \
    --file "$(to_win "$OUT/sample.txt")" --out "Z:$OUT" --tag "$TAG" "$@" ) > "$OUT/$TAG.out" 2> "$OUT/stderr_$TAG.log"
e=$?
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
for f in "$OUT"/"$TAG"_*.bmp; do [ -f "$f" ] && convert "$f" "${f%.bmp}.png" && rm -f "$f"; done
cat "$OUT/$TAG.out"
echo "driver exit $e"
exit $e
