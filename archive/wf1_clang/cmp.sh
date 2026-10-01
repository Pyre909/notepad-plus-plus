#!/bin/sh
# Compare clang diagnostics (in the .cxx files themselves) between HEAD copies and the worktree.
W=/home/user/notepad-plus-plus/.claude/worktrees/wf_b38281fb-6a4-1/scintilla
H=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/wf1_clang/win32
FLAGS="--target=x86_64-w64-mingw32 -fsyntax-only -DNDEBUG -I $W/win32 -I $W/include -I $W/src -I $W/../boostregex --std=c++17 -Wall -Wextra -Wpedantic -Wconversion -Wno-sign-conversion -Wno-implicit-int-conversion -Wno-shorten-64-to-32 -Wno-language-extension-token -DSCI_OWNREGEX -DBOOST_REGEX_STANDALONE"
for f in ScintillaWin SurfaceD2D ListBox; do
  for d in "" "-DDISABLE_D2D"; do
    old=$(clang++ $FLAGS $d $H/$f.cxx 2>&1 | grep -E "^$H/$f.cxx:[0-9]+:[0-9]+: (warning|error)" | sed -E 's/^[^ ]+ //' | sort)
    new=$(clang++ $FLAGS $d $W/win32/$f.cxx 2>&1 | grep -E "^$W/win32/$f.cxx:[0-9]+:[0-9]+: (warning|error)" | sed -E 's/^[^ ]+ //' | sort)
    echo "== $f $d: old=$(printf '%s' "$old" | grep -c .) new=$(printf '%s' "$new" | grep -c .)"
    printf '%s\n' "$old" > /tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/wf1_clang/old.txt
    printf '%s\n' "$new" > /tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/wf1_clang/new.txt
    diff /tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/wf1_clang/old.txt /tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/wf1_clang/new.txt
  done
done
