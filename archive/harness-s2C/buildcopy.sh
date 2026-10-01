#!/bin/sh
# buildcopy.sh DEST LOG : build the worktree (cwd) with xbuild.sh and copy the app directory to DEST
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
DEST=$1; LOG=$2
$S/xbuild.sh -k > "$LOG" 2>&1
e=$?
echo "build exit $e"
grep "compiling\|linking" "$LOG" | head -40
grep "error\|warning: " "$LOG" | grep -v "BabyGrid\|jobserver"
[ $e -eq 0 ] || exit $e
rm -rf "$DEST" && mkdir -p "$DEST" && cp -r PowerEditor/gcc/bin.gcc.x86_64/. "$DEST/"
echo "test markers in $DEST: $(strings -el "$DEST/notepad++.exe" | grep -c NPP_TEST_PMV2)"
md5sum "$DEST/notepad++.exe"
