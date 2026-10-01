#!/bin/sh
# synth.sh DPI OTHER [OUTDIR]: throwaway test build (DPI override file), Wine DPI = DPI:
#   docked: main window WM_DPICHANGED(OTHER) + WM_DPICHANGED_AFTERPARENT to all + relayout, and back
#   float: floating containers only to OTHER (resized like the system does, then AFTERPARENT), and back
#   floatap: same, but AFTERPARENT before the resize (the panels' onDpiChanged from DockingDlgInterface)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
DPI=$1; OTHER=$2; O=${3:-synth$DPI}
rm -rf "$O"; mkdir -p "$O"
for run in docked float floatap; do
  case $run in
    docked) cfg=docked; ARG="--synthetic $OTHER";;
    float) cfg=float; ARG="--floatdpi $OTHER";;
    floatap) cfg=float; ARG="--floatdpi $OTHER --afterparent-first";;
  esac
  rm -rf "$O/set-$run"; cp -r "cfg/set-$cfg" "$O/set-$run"
  TESTDPI=1 ./s2brun.sh test-app "$O/set-$run" "$O" "pfx$DPI" "$DPI" "test_$run" $ARG --repaint > "$O/run-test_$run.log" 2>&1
  tail -1 "$O/run-test_$run.log"
  echo "---- onDpiChanged log ($run)"; cat "$O/dpi-test_$run.txt.log" 2>/dev/null
done
echo "==== round trips ($DPI dpi)"
for run in docked float floatap; do
  for p in main doclist charpanel clipboard; do
    a="$O/test_${run}_1_$p.png"; b=$(ls "$O"/test_${run}_3_*$p*.png 2>/dev/null | head -1)
    [ -f "$a" ] && [ -n "$b" ] && ./cmp.sh "$a,$b"
  done
  grep -h "roundtrip_repaint" "$O/test_$run.out" | cut -f3,5
done
