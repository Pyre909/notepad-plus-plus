#!/bin/sh
# Cross-compile Notepad++ (x86_64, release) with MinGW-w64 from Linux.
# Usage: xbuild.sh [make args]     -- run from anywhere inside a checkout/worktree.
# First build in a fresh worktree is seeded from the main checkout's objects (then touched),
# so only files that differ from the seed get recompiled.
T=x86_64-w64-mingw32
REPO=$(git rev-parse --show-toplevel) || exit 1
SEED=/home/user/notepad-plus-plus/PowerEditor/gcc/bin.gcc.x86_64.build
B=$REPO/PowerEditor/gcc/bin.gcc.x86_64.build
if [ ! -d "$B" ] && [ -d "$SEED" ] && [ "$REPO" != /home/user/notepad-plus-plus ]; then
  cp -r "$SEED" "$B" && find "$B" -type f -exec touch {} +
  # then re-touch sources that differ from the seed checkout so they rebuild
  (cd "$REPO" && git diff --name-only $(git -C /home/user/notepad-plus-plus rev-parse HEAD) -- . | while read f; do [ -f "$f" ] && touch "$f"; done)
fi
cd "$REPO/PowerEditor/gcc" && exec make CXX=$T-g++ RC=$T-windres AR=$T-ar RANLIB=$T-ranlib WINDRES=$T-windres PREBUILD_EVENT_CMD=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/gen-libs-version.sh CPP_DEFINE="UNICODE _UNICODE OEMRESOURCE NOMINMAX _WIN32_WINNT=_WIN32_WINNT_WIN7 NTDDI_VERSION=NTDDI_WIN7 NDEBUG STRSAFE_NO_DEPRECATE" NUMBER_OF_PROCESSORS=2 -j2 "$@"
