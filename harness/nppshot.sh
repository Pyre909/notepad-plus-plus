#!/bin/sh
# nppshot: run a notepad++.exe under Wine + Xvfb with an isolated settings dir, open
# Preferences > Editing 1, capture it, cycle the 3 "Text rendering" combos (6282/6284/6286) through
# all items, set final selections, close cleanly, dump config.xml's ScintillaPrimaryView attributes,
# then restart and check the selections persisted.
#
# Usage: nppshot.sh NOTEPADPP_EXE OUTDIR [-f a,r,c] [-n]
#   -f a,r,c  final combo indices (antialiasing, rendering mode, contrast); default: last item of each
#   -n        no restart / persistence check
# The exe's directory is COPIED to OUTDIR/app (the build tree is never written to).
# Exit: 0 = no crash-level failure (FAIL lines may exist), 2 = crash / hang / no clean exit.
H=$(cd "$(dirname "$0")" && pwd)
. "$H/env.sh"
[ $# -ge 2 ] || { sed -n '2,13p' "$0"; exit 64; }
EXE=$1; OUT=$2; shift 2
FINAL=; RESTART=1
while [ $# -gt 0 ]; do
  case "$1" in
    -f) FINAL=$2; shift 2;;
    -n) RESTART=0; shift;;
    *) echo "unknown option $1" >&2; exit 64;;
  esac
done
[ -f "$EXE" ] || { echo "no such file: $EXE" >&2; exit 64; }
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
EXE=$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")

DRIVE=$H/out/nppdrive.exe
if [ ! -f "$DRIVE" ] || [ "$H/src/nppdrive.cpp" -nt "$DRIVE" ]; then
  mkdir -p "$H/out"
  x86_64-w64-mingw32-g++ -std=c++20 -O1 -DUNICODE -D_UNICODE "$H/src/nppdrive.cpp" -static -static-libgcc \
    -static-libstdc++ -mconsole -lgdi32 -luser32 -o "$DRIVE" || exit 2
fi

if [ -z "$HARNESS_IN_XVFB" ]; then
  [ "$(dirname "$EXE")" = "$OUT/app" ] && { echo "the exe must not live in OUTDIR/app (it is recreated)" >&2; exit 64; }
  rm -rf "$OUT/app" "$OUT/settings" "$OUT"/*.png "$OUT"/*.bmp "$OUT"/*.log "$OUT"/*.tsv "$OUT"/*.txt "$OUT"/*.out
  cp -r "$(dirname "$EXE")" "$OUT/app"
  mkdir -p "$OUT/settings"
  cat > "$OUT/sample.txt" <<'EOF'
Hello from nppshot: The quick brown fox jumps over the lazy dog 0123456789
int main(int argc, char **argv) { return printf("%d\n", argc); } // code line
iiiiiiiiii WWWWWWWWWW mmmmmmmmmm 0O0O0O0O lIlIlI1|1| {}[]()<> ~!@#$%^&*_+=
EOF
  HARNESS_IN_XVFB=1 exec xvfb-run -a -s "-screen 0 $XVFB_SCREEN" "$0" "$EXE" "$OUT" ${FINAL:+-f "$FINAL"} $( [ $RESTART = 0 ] && printf '%s' -n )
fi

harness_prefix
APP_EXE=$OUT/app/$(basename "$EXE")
LOG=$OUT/nppshot.log
: > "$LOG"
echo "nppshot: exe=$EXE (copied to $OUT/app) settings=$OUT/settings display=$DISPLAY prefix=$WINEPREFIX" | tee -a "$LOG"
RC=0

dump_config() {  # $1 = label
  "$PY" - "$OUT/settings/config.xml" "$1" <<'EOF' | tee -a "$LOG" > "$OUT/config_ScintillaPrimaryView_$2.txt"
import sys, xml.etree.ElementTree as ET
path, label = sys.argv[1], sys.argv[2]
NEW = ["smoothFont", "fontAntialiasing", "fontRenderingMode", "fontContrast", "fontGamma", "fontEnhancedContrast",
       "fontGrayscaleEnhancedContrast", "fontClearTypeLevel", "fontPixelGeometry"]
try:
    root = ET.parse(path).getroot()
except Exception as e:
    print(f"CONFIG\t{label}\tERROR\tcannot parse {path}: {e}"); sys.exit(0)
node = root.find(".//GUIConfig[@name='ScintillaPrimaryView']")
if node is None:
    print(f"CONFIG\t{label}\tERROR\tno GUIConfig name=ScintillaPrimaryView"); sys.exit(0)
print(f"CONFIG\t{label}\ttext-rendering\t" + " ".join(f'{k}={node.get(k)!r}' for k in NEW))
print(f"CONFIG\t{label}\tall\t" + " ".join(f'{k}="{v}"' for k, v in node.attrib.items()))
EOF
}

run_drive() {  # tag, extra args...
  tag=$1; shift
  echo "=== $tag" >> "$LOG"
  ( cd "$OUT/app" && timeout -k 5 300 "$WINE" "$DRIVE" --exe "$(to_win "$APP_EXE")" --settings "$(to_win "$OUT/settings")" \
      --file "$(to_win "$OUT/sample.txt")" --out "Z:$OUT" --tag "$tag" "$@" ) > "$OUT/$tag.out" 2> "$OUT/stderr_$tag.log"
  e=$?
  cat "$OUT/$tag.out" >> "$LOG"
  if [ $e = 124 ] || [ $e = 137 ]; then
    printf 'RESULT\tnpp_%s\tdriver\tCRASH\tnppdrive timeout (hang)\n' "$tag" >> "$LOG"; RC=2
  elif [ $e != 0 ]; then
    printf 'RESULT\tnpp_%s\tdriver\tCRASH\tnppdrive exit code %s\n' "$tag" "$e" >> "$LOG"; RC=2
  fi
  "$WINESERVER" -k 2>/dev/null   # nothing of this run may survive into the next one
  "$WINESERVER" -w 2>/dev/null
}

run_drive run1 ${FINAL:+--final "$FINAL"}
SEL=$(grep '^FINAL_SELECTION' "$OUT/run1.out" | cut -f2)
dump_config "after run1 (final selection $SEL)" run1
if [ $RESTART = 1 ] && [ -n "$SEL" ]; then
  run_drive run2 --expect "$SEL"
  dump_config "after run2 (restart)" run2
fi

for f in "$OUT"/*.bmp; do
  [ -f "$f" ] || continue
  convert "$f" "${f%.bmp}.png" 2>/dev/null && rm -f "$f"
done
# Contact sheet of the editor captures made while cycling the combos
if ls "$OUT"/run1_editor_*_*.png >/dev/null 2>&1; then
  ( cd "$OUT" && montage -label '%t' -pointsize 11 $(ls run1_editor_*_[0-9]*.png | sed 's/$/[520x60+0+0]/') \
      -tile 1x -geometry +2+2 editor_cycle_contact.png 2>/dev/null )
fi

grep '^RESULT' "$LOG" > "$OUT/results.tsv"
P=$(grep -c '	PASS	' "$OUT/results.tsv"); F=$(grep -c '	FAIL	' "$OUT/results.tsv")
C=$(grep -c '	CRASH	' "$OUT/results.tsv"); W=$(grep -c '	WARN	' "$OUT/results.tsv")
echo
echo "---- FAIL / CRASH / WARN lines"
grep -E '	(FAIL|CRASH|WARN)	' "$OUT/results.tsv" | cut -f2- | cut -c1-300
echo "---- config.xml ScintillaPrimaryView (text rendering attributes)"
grep 'text-rendering' "$LOG" | cut -f2-
echo
echo "NPPSHOT_SUMMARY pass=$P fail=$F crash=$C warn=$W out=$OUT"
echo "  prefs screenshot: $OUT/run1_prefs_editing1.png  final: $OUT/run1_prefs_final.png  restart: $OUT/run2_prefs_editing1.png"
[ "$C" -gt 0 ] && RC=2
exit $RC
