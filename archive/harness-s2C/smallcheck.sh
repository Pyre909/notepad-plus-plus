#!/bin/sh
# smallcheck.sh FILE.cpp... : syntax-check sources (paths relative to PowerEditor/gcc) as xbuild compiles them,
# plus -Dsmall=char (rpcndr.h's macro under MSVC). Run from the worktree root.
cd PowerEditor/gcc || exit 1
CMD=$(/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/xbuild.sh VERBOSE=1 -n -B bin.gcc.x86_64.build/WinControls/StaticDialog/StaticDialog.o 2>&1 | grep "g++" | head -1 | sed 's/ -MMD -c -o [^ ]* [^ ]*$//')
for f in "$@"; do
  echo "== $f"
  $CMD -Dsmall=char -fsyntax-only "$f" 2>&1 | head -20
done
echo done
