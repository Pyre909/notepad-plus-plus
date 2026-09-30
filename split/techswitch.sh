#!/bin/sh
# techswitch.sh APPDIR OUTDIR : the Rendering mode applies at once (see techswitch.cpp); APPDIR must be a test build
# without Notepad++'s Wine check, as Notepad++ uses GDI only under Wine
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
. $S/harness/env.sh
APP=$1; OUT=$2
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT"; mkdir -p "$OUT/settings"; OUT=$(cd "$OUT" && pwd); cp -r "$APP" "$OUT/app"
  printf 'The quick brown fox jumps over the lazy dog 0123456789\n' > "$OUT/sample.txt"
  [ -f $S/split/techswitch.exe ] && [ $S/split/techswitch.exe -nt $S/split/techswitch.cpp ] || \
    x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -municode -DUNICODE -D_UNICODE $S/split/techswitch.cpp -static -static-libgcc -static-libstdc++ -mconsole -luser32 -o $S/split/techswitch.exe || exit 2
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 $XVFB_SCREEN" "$0" "$APP" "$OUT"
fi
harness_prefix
( cd "$OUT/app" && timeout -k 5 300 "$WINE" $S/split/techswitch.exe "$(to_win "$OUT/app/notepad++.exe")" "$(to_win "$OUT/settings")" \
    "$(to_win "$OUT/sample.txt")" ) 2>/dev/null | tr -d '\r'
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
"$WINE" regedit /S "$(to_win "$WINEPREFIX/harness.reg")" >/dev/null 2>&1; "$WINESERVER" -w
grep -o 'writeTechnologyEngine="[0-9]*"' "$OUT/settings/config.xml" 2>/dev/null | sed 's/^/CONFIG\t/'
exit 0
