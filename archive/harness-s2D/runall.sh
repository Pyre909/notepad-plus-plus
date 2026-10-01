#!/bin/sh
# runall.sh DPI PREFIX OUTDIR [extra s2drive args]: baseline (main checkout build) / new build OFF / new build ON at the Wine DPI
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
DPI=$1; PFX=$2; O=$3; shift 3
rm -rf "$O"; mkdir -p "$O"
./s2run.sh base-app "$O/set-base" "$O" "$PFX" "$DPI" base "$@"
./s2run.sh new-app "$O/set-new" "$O" "$PFX" "$DPI" off --expect 0 --set 1 "$@"
./s2run.sh new-app "$O/set-new" "$O" "$PFX" "$DPI" on --expect 1 "$@"
echo "==== base vs off ($DPI dpi)"; ./cmptags.sh "$O" base off
echo "==== base vs on ($DPI dpi)"; ./cmptags.sh "$O" base on
