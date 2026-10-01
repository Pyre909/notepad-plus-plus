#!/bin/sh
# smallcheck.sh WORKTREE obj... : re-run the compile of each object with -Dsmall=char (and near/far/hyper) as a syntax check
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
WT=$1; shift
cd "$WT" || exit 1
rc=0
for o in "$@"; do
  touch "PowerEditor/src/$o.cpp"
  "$S/xbuild.sh" VERBOSE=1 -n "bin.gcc.x86_64.build/$o.o" 2>&1 | grep '^x86_64-w64-mingw32-g++' \
    | sed "s#-MMD -c -o [^ ]*#-Dsmall=char -Dnear= -Dfar= -Dhyper=__int64 -fsyntax-only#" > "$S/harness-s2B/cmd.sh"
  if (cd PowerEditor/gcc && sh "$S/harness-s2B/cmd.sh"); then echo "OK $o"; else echo "FAIL $o"; rc=1; fi
done
exit $rc
