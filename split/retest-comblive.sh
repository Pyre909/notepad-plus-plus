#!/bin/sh
# retest-comb.sh: the combined branch merged with master 37f76d4 (87ddc3d) against master 37f76d4
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
SP=$S/split
echo "==== nppshot (combined 87ddc3d)"
$S/harness/nppshot.sh $SP/app-comb-live/notepad++.exe $S/harness/out/comblive-nppshot > $S/harness/out/comblive-nppshot.log 2>&1
echo "nppshot exit=$?"; grep -E 'NPPSHOT_SUMMARY|^FAIL|^CRASH' $S/harness/out/comblive-nppshot.log | head -20
cd $S/harness-dpi || exit 1
for DPI in 96 144; do
  [ $DPI = 96 ] && OTHER=144 || OTHER=96
  O=cb$DPI; rm -rf $O; mkdir -p $O
  ./dpirun.sh $SP/app-base-rb "$O/set-base" "$O" "pfx$DPI" "$DPI" base --synthetic "$OTHER" > $O/base.log 2>&1
  ./dpirun.sh $SP/app-comb-live "$O/set-comb" "$O" "pfx$DPI" "$DPI" off --synthetic "$OTHER" --expect 0 --set 1 > $O/off.log 2>&1
  ./dpirun.sh $SP/app-comb-live "$O/set-comb" "$O" "pfx$DPI" "$DPI" on --synthetic "$OTHER" --expect 1 > $O/on.log 2>&1
  echo "==== $DPI dpi drivers (base, combined off, combined on)"; grep -hE 'SUMMARY|driver exit' $O/base.log $O/off.log $O/on.log
  echo "==== $DPI dpi comparisons"
  ./cmp.sh "$O/base_1_main.png,$O/off_1_main.png" "$O/base_2_docked.png,$O/off_2_docked.png" \
    "$O/base_1_main.png,$O/on_1_main.png" "$O/base_2_docked.png,$O/on_2_docked.png"
done
echo "==== done"
