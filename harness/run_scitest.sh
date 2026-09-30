#!/bin/sh
# Run scitest.exe under Wine + Xvfb, one process per test group (a crash in one group does not
# stop the others), convert the captures to PNG and print a summary.
#
# Usage: run_scitest.sh [-e EXE | -l LIBSCINTILLA_A [-i INCLUDE_DIR]] [-o OUTDIR]
#                       [-g "env techs api matrix sens switch settingchange popups idle"]
#                       [-t TIMEOUT_PER_GROUP_S] [-- extra scitest.exe args, e.g. --font "Liberation Mono" --size 1100]
# Exit: 0 = no crash-level failure, 1 = FAILs only (with -s), 2 = crash / timeout / non-zero process exit.
H=$(cd "$(dirname "$0")" && pwd)
. "$H/env.sh"
EXE=$H/out/scitest.exe
LIB=
INC=
OUT=
TGROUPS="env techs api matrix sens switch settingchange popups idle"
TMO=240
STRICT=0
while [ $# -gt 0 ]; do
  case "$1" in
    -e) EXE=$2; shift 2;;
    -l) LIB=$2; shift 2;;
    -i) INC=$2; shift 2;;
    -o) OUT=$2; shift 2;;
    -g) TGROUPS=$2; shift 2;;
    -t) TMO=$2; shift 2;;
    -s) STRICT=1; shift;;
    --) shift; break;;
    *) echo "unknown option $1" >&2; exit 64;;
  esac
done
[ -n "$OUT" ] || OUT=$H/out/scitest-$(date +%Y%m%d-%H%M%S)
mkdir -p "$OUT"
OUT=$(cd "$OUT" && pwd)
if [ -n "$LIB" ] && [ -z "$HARNESS_IN_XVFB" ]; then
  # Build a fresh scitest.exe for this library into the output directory
  "$H/build_scitest.sh" "$LIB" "$INC" "$OUT/scitest.exe" || exit 64
  EXE=$OUT/scitest.exe
fi
EXE=$(cd "$(dirname "$EXE")" && pwd)/$(basename "$EXE")
[ -f "$EXE" ] || { echo "no such exe: $EXE (run build_scitest.sh first)" >&2; exit 64; }

if [ -z "$HARNESS_IN_XVFB" ]; then
  # Re-run this script inside a private Xvfb server (auto display number)
  HARNESS_IN_XVFB=1 exec xvfb-run -a -s "-screen 0 $XVFB_SCREEN" "$0" -e "$EXE" -o "$OUT" -g "$TGROUPS" -t "$TMO" $( [ $STRICT = 1 ] && echo -s ) -- "$@"
fi

harness_prefix
LOG=$OUT/scitest.log
: > "$LOG"
echo "scitest: exe=$EXE out=$OUT display=$DISPLAY prefix=$WINEPREFIX" | tee -a "$LOG"
RC=0
for g in $TGROUPS; do
  echo "=== group $g" >> "$LOG"
  ( cd "$OUT" && timeout -k 5 "$TMO" "$WINE" "$EXE" --out "Z:$OUT" --groups "$g" "$@" ) >> "$LOG" 2>> "$OUT/stderr_$g.log"
  e=$?
  sed -n '/^first-chance/p' "$OUT/stderr_$g.log" | head -5 | sed "s/^/  [$g stderr] /"
  if [ $e = 124 ] || [ $e = 137 ]; then
    printf 'RESULT\t%s\tprocess\tCRASH\ttimeout after %ss (hang)\n' "$g" "$TMO" >> "$LOG"; RC=2
  elif [ $e -ge 2 ]; then
    printf 'RESULT\t%s\tprocess\tCRASH\tscitest.exe exit code %s\n' "$g" "$e" >> "$LOG"; RC=2
  fi
  echo "group $g: exit $e" | tee -a "$LOG"
  # A crashed/hung process must not leave Wine processes behind for the next group
  [ $e = 0 ] || [ $e = 1 ] || "$WINESERVER" -k 2>/dev/null
done
"$WINESERVER" -w 2>/dev/null

# BMP -> PNG
for f in "$OUT"/*.bmp; do
  [ -f "$f" ] || continue
  convert "$f" "${f%.bmp}.png" 2>/dev/null && rm -f "$f"
done
# Contact sheet of the rendering-mode x quality matrix (top 7 text lines of each capture)
if ls "$OUT"/matrix_*.png >/dev/null 2>&1; then
  ( cd "$OUT" && montage -label '%t' -font DejaVu-Sans -pointsize 11 \
      $(for q in 0 1 2 3; do for m in unset 4 5 2 3; do echo "matrix_rm${m}_q${q}.png[480x125+0+0]"; done; done) \
      -tile 5x4 -geometry +4+4 matrix_contact.png 2>/dev/null )
fi

# Summary
grep '^RESULT' "$LOG" > "$OUT/results.tsv"
P=$(grep -c '	PASS	' "$OUT/results.tsv"); F=$(grep -c '	FAIL	' "$OUT/results.tsv")
C=$(grep -c '	CRASH	' "$OUT/results.tsv"); W=$(grep -c '	WARN	' "$OUT/results.tsv")
echo
echo "---- FAIL / CRASH / WARN lines"
grep -E '	(FAIL|CRASH|WARN)	' "$OUT/results.tsv" | cut -f2- | cut -c1-260
echo
echo "SCITEST_SUMMARY pass=$P fail=$F crash=$C warn=$W out=$OUT"
[ "$C" -gt 0 ] && RC=2
[ $RC = 0 ] && [ $STRICT = 1 ] && [ "$F" -gt 0 ] && RC=1
exit $RC
