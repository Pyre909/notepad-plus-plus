#!/bin/sh
# msvcmacros.sh WORKTREE file.cpp... : syntax-check files (paths relative to PowerEditor/src) with the exact
# xbuild.sh compile command plus the Windows SDK rpcndr.h macros (small, near, far, hyper)
WT=$1; shift
cd "$WT/PowerEditor/gcc" || exit 1
CMD=$(/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/xbuild.sh VERBOSE=1 -n -B bin.gcc.x86_64.build/WinControls/TreeView/TreeView.o 2>&1 | grep -- "-c -o bin.gcc.x86_64.build/WinControls/TreeView/TreeView.o" | head -1)
[ -n "$CMD" ] || { echo "no compile command"; exit 1; }
BASE=$(printf '%s' "$CMD" | sed 's# -MMD -c -o bin.gcc.x86_64.build/WinControls/TreeView/TreeView.o ../src/WinControls/TreeView/TreeView.cpp##')
rc=0
for f in "$@"; do
  echo "== $f"
  sh -c "$BASE -Dsmall=char -Dnear= -Dfar= -Dhyper=__int64 -fsyntax-only ../src/$f" || rc=1
done
exit $rc
