#!/bin/sh
# retest-fn.sh: the font-name change (directwrite-font-names_20260930) against upstream master 37f76d4
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
SP=$S/split
echo "==== nppshot (font names)"
$S/harness/nppshot.sh $SP/app-fn/notepad++.exe $S/harness/out/fn-nppshot > $S/harness/out/fn-nppshot.log 2>&1
echo "nppshot exit=$?"; grep -E 'NPPSHOT_SUMMARY|^FAIL|^CRASH' $S/harness/out/fn-nppshot.log | head -20
cd $S/harness-dpi || exit 1
for DPI in 96 144; do
  [ $DPI = 96 ] && OTHER=144 || OTHER=96
  O=fn$DPI; rm -rf $O; mkdir -p $O
  ./dpirun.sh $SP/app-base-rb "$O/set-base" "$O" "pfx$DPI" "$DPI" base --synthetic "$OTHER" > $O/base.log 2>&1
  ./dpirun.sh $SP/app-fn "$O/set-fn" "$O" "pfx$DPI" "$DPI" fn --synthetic "$OTHER" > $O/fn.log 2>&1
  echo "==== $DPI dpi drivers"; grep -hE 'SUMMARY|driver exit' $O/base.log $O/fn.log
  echo "==== $DPI dpi comparisons"
  ./cmp.sh "$O/base_1_main.png,$O/fn_1_main.png" "$O/base_2_docked.png,$O/fn_2_docked.png"
done
echo "==== done"
