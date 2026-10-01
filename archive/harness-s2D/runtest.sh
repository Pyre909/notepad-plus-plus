#!/bin/sh
# runtest.sh WINDOWDPI PREFIX OUTDIR [extra s2drive args]: throwaway test builds with every window reporting WINDOWDPI
# (NPP_TEST_WINDOW_DPI) while the Wine/system DPI stays 96, per-monitor DPI awareness ON:
# test-base (9fc893a + override) vs test-new (Stage 2 + override + value log)
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
WDPI=$1; PFX=$2; O=$3; shift 3
rm -rf "$O"; mkdir -p "$O"
# enable the setting (without the override), then run with the override
./s2run.sh test-base/app "$O/set-tbase" "$O" "$PFX" 96 tbset --set 1 --no-menu > /dev/null
./s2run.sh test-new/app "$O/set-tnew" "$O" "$PFX" 96 tnset --set 1 --no-menu > /dev/null
export NPP_TEST_WINDOW_DPI=$WDPI
./s2run.sh test-base/app "$O/set-tbase" "$O" "$PFX" 96 tbase --expect 1 "$@"
NPP_TEST_LOG="Z:$(printf '%s' "$D/$O/values.log" | sed 's#/#\\#g')" ./s2run.sh test-new/app "$O/set-tnew" "$O" "$PFX" 96 tnew --expect 1 "$@"
echo "==== test-base vs test-new (window DPI $WDPI, system 96)"; ./cmptags.sh "$O" tbase tnew
echo "==== values"; sort "$O/values.log" | uniq -c
