#!/bin/sh
# rundpiseq.sh PREFIX OUTDIR START_DPI SEQ [RIGHTWIDTH [extra s2drive args]]: throwaway test builds (per-monitor code paths forced,
# window DPI from the driver's file mapping, system DPI 96), setting ON: start at START_DPI, right panel RIGHTWIDTH, synthetic DPI changes SEQ
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
PFX=$1; O=$2; START=$3; SEQ=$4; RW=${5:-0}
shift 4; [ $# -gt 0 ] && shift
rm -rf "$O"; mkdir -p "$O"
./s2run.sh test-base/app "$O/set-tbase" "$O" "$PFX" 96 tbset --set 1 --no-menu > /dev/null
./s2run.sh test-new/app "$O/set-tnew" "$O" "$PFX" 96 tnset --set 1 --no-menu > /dev/null
./s2run.sh test-base/app "$O/set-tbase" "$O" "$PFX" 96 tbase --expect 1 --no-menu --dpimap "$START" --rightwidth "$RW" --dpiseq "$SEQ" "$@"
NPP_TEST_LOG="Z:$(printf '%s' "$D/$O/values.log" | sed 's#/#\\#g')" ./s2run.sh test-new/app "$O/set-tnew" "$O" "$PFX" 96 tnew --expect 1 --no-menu --dpimap "$START" --rightwidth "$RW" --dpiseq "$SEQ" "$@"
echo "==== test-base vs test-new"; ./cmptags.sh "$O" tbase tnew
echo "==== values"; sort "$O/values.log" | uniq -c
