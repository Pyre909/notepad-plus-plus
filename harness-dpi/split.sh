#!/bin/sh
# split.sh DPI OTHERDPI : master vs the text-rendering and per-monitor-dpi PR branches, same Wine DPI
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
SP=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/split
DPI=$1; OTHER=$2; O=split$DPI
rm -rf "$O"; mkdir -p "$O"
./dpirun.sh baseline-app "$O/set-base" "$O" "pfx$DPI" "$DPI" base --synthetic "$OTHER"
./dpirun.sh $SP/wt-tr/PowerEditor/gcc/bin.gcc.x86_64 "$O/set-tr" "$O" "pfx$DPI" "$DPI" tr --synthetic "$OTHER"
./dpirun.sh $SP/wt-dpi/PowerEditor/gcc/bin.gcc.x86_64 "$O/set-dpi" "$O" "pfx$DPI" "$DPI" off --synthetic "$OTHER" --expect 0 --set 1
./dpirun.sh $SP/wt-dpi/PowerEditor/gcc/bin.gcc.x86_64 "$O/set-dpi" "$O" "pfx$DPI" "$DPI" on --synthetic "$OTHER" --expect 1
echo "==== comparisons ($DPI dpi)"
./cmp.sh "$O/base_1_main.png,$O/tr_1_main.png" "$O/base_2_docked.png,$O/tr_2_docked.png" \
  "$O/base_1_main.png,$O/off_1_main.png" "$O/base_2_docked.png,$O/off_2_docked.png" \
  "$O/base_1_main.png,$O/on_1_main.png" "$O/base_2_docked.png,$O/on_2_docked.png"
