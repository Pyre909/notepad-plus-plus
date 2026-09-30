#!/bin/sh
# final.sh DPI OTHERDPI : baseline / new OFF (then enable) / new ON / test variant (V1 fallback) ON, same Wine DPI
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
DPI=$1; OTHER=$2; O=final$DPI
rm -rf "$O"; mkdir -p "$O"
./dpirun.sh baseline-app "$O/set-base" "$O" "pfx$DPI" "$DPI" base --synthetic "$OTHER"
./dpirun.sh new-app "$O/set-new" "$O" "pfx$DPI" "$DPI" off --synthetic "$OTHER" --expect 0 --set 1
./dpirun.sh new-app "$O/set-new" "$O" "pfx$DPI" "$DPI" on --synthetic "$OTHER" --expect 1
./dpirun.sh testv1-app "$O/set-new" "$O" "pfx$DPI" "$DPI" tv1 --synthetic "$OTHER" --expect 1
echo "==== comparisons ($DPI dpi)"
./cmp.sh "$O/base_1_main.png,$O/off_1_main.png" "$O/base_1_main.png,$O/on_1_main.png" "$O/base_1_main.png,$O/tv1_1_main.png" \
  "$O/base_2_docked.png,$O/off_2_docked.png" "$O/base_2_docked.png,$O/on_2_docked.png" "$O/base_2_docked.png,$O/tv1_2_docked.png" \
  "$O/tv1_2_docked.png,$O/tv1_4_synthetic_back.png"
