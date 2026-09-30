#!/bin/sh
# retest-rb.sh: the rebased text-rendering PR (a485acc) against upstream master 37f76d4
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
SP=$S/split
echo "==== nppshot (rebased tr)"
$S/harness/nppshot.sh $SP/app-tr-rb/notepad++.exe $S/harness/out/rebase-tr-nppshot > $S/harness/out/rebase-tr-nppshot.log 2>&1
echo "nppshot exit=$?"; grep -E 'NPPSHOT_SUMMARY|^FAIL|^CRASH' $S/harness/out/rebase-tr-nppshot.log | head -20
cd $S/harness-dpi || exit 1
for DPI in 96 144; do
  [ $DPI = 96 ] && OTHER=144 || OTHER=96
  O=rb$DPI; rm -rf $O; mkdir -p $O
  ./dpirun.sh $SP/app-base-rb "$O/set-base" "$O" "pfx$DPI" "$DPI" base --synthetic "$OTHER" > $O/base.log 2>&1
  ./dpirun.sh $SP/app-tr-rb "$O/set-tr" "$O" "pfx$DPI" "$DPI" tr --synthetic "$OTHER" > $O/tr.log 2>&1
  echo "==== $DPI dpi drivers"; grep -hE 'SUMMARY|driver exit' $O/base.log $O/tr.log
  echo "==== $DPI dpi comparisons"
  ./cmp.sh "$O/base_1_main.png,$O/tr_1_main.png" "$O/base_2_docked.png,$O/tr_2_docked.png"
done
echo "==== smoothcheck GDI (rebased tr)"
$SP/smoothcheck.sh $SP/app-tr-rb $SP/smooth-rb-gdi plugin 2>&1 | grep -E 'SMOOTH'
echo "==== smoothcheck DirectWrite (rebased tr, Wine check disabled)"
$SP/smoothcheck.sh $SP/app-tr-dw-rb $SP/smooth-rb-dw plugin 2>&1 | grep -E 'SMOOTH'
echo "==== done"
