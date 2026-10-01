#!/bin/sh
# smallcheck.sh WORKTREE FILE... : syntax-check PowerEditor/src/FILE.cpp with the build flags plus -Dsmall=char
WT=$1; shift
cd "$WT/PowerEditor/gcc" || exit 1
X=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/xbuild.sh
CMD=$("$X" VERBOSE=1 -B -n bin.gcc.x86_64.build/dpiManagerV2.o 2>&1 | grep '^x86_64-w64-mingw32-g++' | sed 's# -MMD -c -o bin.gcc.x86_64.build/dpiManagerV2.o ../src/dpiManagerV2.cpp##')
[ -n "$CMD" ] || { echo "no compile command" >&2; exit 1; }
rc=0
for f in "$@"; do
  echo "== $f"
  out=$(eval "$CMD -Dsmall=char -fsyntax-only ../src/$f.cpp" 2>&1) || rc=1
  printf '%s\n' "$out" | grep -E 'error|warning' | grep -v 'Warray-bounds' | head -20
done
exit $rc
