#!/bin/sh
# Build a private libscintilla.a (Notepad++ flavour: boost regex) from a checkout/worktree directory
# or from a git commit, WITHOUT touching that checkout: the sources are copied into OUTDIR/src.
# Usage: build_scilib.sh SOURCE OUTDIR
#   SOURCE: a checkout/worktree directory (working-tree files, uncommitted changes included)
#           or a git commit-ish of /home/user/notepad-plus-plus (e.g. 3b9b347, a branch name)
# Result: OUTDIR/libscintilla.a and OUTDIR/src/scintilla/include (use with build_scitest.sh)
set -e
SRC=$1; OUT=$2
[ -n "$SRC" ] && [ -n "$OUT" ] || { echo "usage: $0 SOURCE_DIR|COMMIT OUTDIR" >&2; exit 64; }
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd)
rm -rf "$OUT/src"; mkdir -p "$OUT/src" "$OUT/obj"
if [ -d "$SRC" ]; then
  cp -r "$SRC/scintilla" "$SRC/boostregex" "$OUT/src/"
  echo "sources: working tree of $SRC"
else
  git -C /home/user/notepad-plus-plus archive "$SRC" scintilla boostregex | tar -x -C "$OUT/src"
  echo "sources: commit $SRC ($(git -C /home/user/notepad-plus-plus log -1 --format='%h %s' "$SRC"))"
fi
T=x86_64-w64-mingw32
make -s -C "$OUT/src/scintilla/win32" -f makefile -f ../../boostregex/nppSpecifics_mingw.mak \
  CXX=$T-g++ AR=$T-ar RANLIB=$T-ranlib WINDRES=$T-windres \
  DEFINES="-DNDEBUG -DUNICODE -D_UNICODE -DNOMINMAX -D_WIN32_WINNT=0x0601" BASE_FLAGS="-O2 -w" \
  DIR_O="$OUT/obj" LIBSCI="$OUT/libscintilla.a" "$OUT/libscintilla.a" -j"$(nproc)"
echo "ok: $OUT/libscintilla.a  include: $OUT/src/scintilla/include"
