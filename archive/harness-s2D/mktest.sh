#!/bin/sh
# mktest.sh WORKTREE OUTDIR MODE : throwaway (never committed) test build of WORKTREE = its built objects + patched copies of
# a few sources (patch.py MODE), relinked. MODE: "base" (override only) or "new" (override + value log).
# The worktree is only read. Result: OUTDIR/app/notepad++.exe (+ the bin files).
set -e
D=$(cd "$(dirname "$0")" && pwd)
WT=$1; OUT=$2; MODE=$3
[ -n "$MODE" ] || { echo "usage: $0 WORKTREE OUTDIR base|new" >&2; exit 64; }
rm -rf "$OUT"; mkdir -p "$OUT/tree/PowerEditor/gcc"; OUT=$(cd "$OUT" && pwd)
cp -r "$WT/PowerEditor/src" "$OUT/tree/PowerEditor/src"
cp "$WT/PowerEditor/gcc/gcc-fixes.h" "$OUT/tree/PowerEditor/gcc/"
ln -s "$WT/scintilla" "$OUT/tree/scintilla"
ln -s "$WT/lexilla" "$OUT/tree/lexilla"
cp -r "$WT/PowerEditor/gcc/bin.gcc.x86_64.build" "$OUT/tree/PowerEditor/gcc/objs"
mkdir -p "$OUT/app"; cp -r "$WT/PowerEditor/gcc/bin.gcc.x86_64/." "$OUT/app/"
/usr/bin/python3 "$D/patch.py" "$OUT/tree/PowerEditor/src" "$MODE" > "$OUT/patched.txt"
cd "$OUT/tree/PowerEditor/gcc"
FLAGS="-include ../gcc/gcc-fixes.h -std=c++20 -Wpedantic -Wall -Wextra -Wconversion -O3 -Wno-cast-function-type -Wno-overloaded-virtual -Wno-system-headers -isystem ../src/json -isystem ../src/pugixml -isystem ../src/uchardet -isystem ../src/MISC/crc16 -isystem ../src/MISC/md5 -isystem ../src/MISC/sha1 -isystem ../src/MISC/sha2 -isystem ../src/MISC/sha512 -isystem ../src/MISC/hmac -isystem ../../scintilla/include -isystem ../../lexilla/include -I../../scintilla/include -I../../lexilla/include"
for d in $(cd ../src && find . -type d | sed 's#^\./##'); do FLAGS="$FLAGS -I../src/$d"; done
FLAGS="$FLAGS -DUNICODE -D_UNICODE -DOEMRESOURCE -DNOMINMAX -D_WIN32_WINNT=_WIN32_WINNT_WIN7 -DNTDDI_VERSION=NTDDI_WIN7 -DNDEBUG -DSTRSAFE_NO_DEPRECATE"
for f in $(cat "$OUT/patched.txt"); do
  case "$f" in *.cpp) ;; *) continue;; esac
  o=objs/${f%.cpp}.o; rm -f "$o"
  echo "compiling $f"
  x86_64-w64-mingw32-g++ $FLAGS -c -o "$o" "../src/$f" 2>&1 | grep -E 'error' || true
  [ -f "$o" ]
done
OBJS=$(find objs \( -name '*.o' -o -name '*.res' \) -not -path '*/_scintilla.build/*' -not -path '*/_lexilla.build/*' | sort)
x86_64-w64-mingw32-g++ -municode -mwindows -s $OBJS -Lobjs \
  -lcomctl32 -lcrypt32 -ldbghelp -lole32 -lsensapi -lshlwapi -luuid -luxtheme -lversion -lwininet -lwintrust -ldwmapi -lbcrypt \
  -lscintilla -llexilla -limm32 -lmsimg32 -lole32 -loleaut32 -static -o "$OUT/app/notepad++.exe"
echo "ok: $OUT/app/notepad++.exe"
