#!/bin/sh
# Link a private notepad++.exe from an existing Notepad++ gcc build's objects and ANOTHER libscintilla.a
# (e.g. UI worktree objects + Scintilla implementation built by build_scilib.sh), without touching
# either tree: the objects are snapshotted into OUTDIR first. OUTDIR/app becomes a runnable app dir
# (the build's bin.gcc.x86_64 files + the new exe) for nppshot.sh.
# Usage: link_npp.sh CHECKOUT_OR_WORKTREE LIBSCINTILLA_A OUTDIR
set -e
WT=$1; LIB=$2; OUT=$3
[ -n "$OUT" ] || { echo "usage: $0 CHECKOUT_OR_WORKTREE LIBSCINTILLA_A OUTDIR" >&2; exit 64; }
B=$WT/PowerEditor/gcc/bin.gcc.x86_64.build
BIN=$WT/PowerEditor/gcc/bin.gcc.x86_64
[ -d "$B" ] && [ -d "$BIN" ] && [ -f "$LIB" ] || { echo "missing $B, $BIN or $LIB" >&2; exit 64; }
mkdir -p "$OUT"; OUT=$(cd "$OUT" && pwd); LIB=$(cd "$(dirname "$LIB")" && pwd)/$(basename "$LIB")
rm -rf "$OUT/objs" "$OUT/app" "$OUT/scilib"; mkdir -p "$OUT/app" "$OUT/scilib"
cp -r "$B" "$OUT/objs"
cp "$LIB" "$OUT/scilib/libscintilla.a"
cp -r "$BIN/." "$OUT/app/"
cd "$OUT"
OBJS=$(find objs \( -name '*.o' -o -name '*.res' \) -not -path '*/_scintilla.build/*' -not -path '*/_lexilla.build/*' | sort)
# same libraries as PowerEditor/gcc/makefile (LD_LINK)
x86_64-w64-mingw32-g++ -municode -mwindows -s $OBJS -Lscilib -Lobjs \
  -lcomctl32 -lcrypt32 -ldbghelp -lole32 -lsensapi -lshlwapi -luuid -luxtheme -lversion -lwininet -lwintrust -ldwmapi -lbcrypt \
  -lscintilla -llexilla -limm32 -lmsimg32 -lole32 -loleaut32 -static -o "$OUT/app/notepad++.exe"
rm -rf "$OUT/objs"
echo "ok: $OUT/app/notepad++.exe (objects of $WT, Scintilla $LIB)"
