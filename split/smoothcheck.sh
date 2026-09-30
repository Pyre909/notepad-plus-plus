#!/bin/sh
# smoothcheck.sh APPDIR OUTDIR : "Follow Windows" antialiasing against the Windows font smoothing (#17461)
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
. $S/harness/env.sh
APP=$1; OUT=$2; PLUGIN=$3
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT"; mkdir -p "$OUT/settings"; OUT=$(cd "$OUT" && pwd); cp -r "$APP" "$OUT/app"
  if [ "$PLUGIN" = plugin ]; then
    mkdir -p "$OUT/app/plugins/SmoothTest"
    x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -shared -DUNICODE -D_UNICODE $S/split/smoothplugin.cpp -static -static-libgcc -static-libstdc++ -luser32 -o "$OUT/app/plugins/SmoothTest/SmoothTest.dll" || exit 2
  fi
  printf 'The quick brown fox jumps over the lazy dog 0123456789\nint main(int argc, char **argv) { return 0; }\nWWW mmm ||| iii --- ### @@@ %%%%%%\n' > "$OUT/sample.txt"
  [ -f $S/split/smoothcheck.exe ] && [ $S/split/smoothcheck.exe -nt $S/split/smoothcheck.cpp ] || \
    x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -municode -DUNICODE -D_UNICODE $S/split/smoothcheck.cpp -static -static-libgcc -static-libstdc++ -mconsole -luser32 -lgdi32 -o $S/split/smoothcheck.exe || exit 2
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 $XVFB_SCREEN" "$0" "$APP" "$OUT" "$PLUGIN"
fi
harness_prefix
( cd "$OUT/app" && timeout -k 5 300 "$WINE" $S/split/smoothcheck.exe "$(to_win "$OUT/app/notepad++.exe")" "$(to_win "$OUT/settings")" \
    "$(to_win "$OUT/sample.txt")" "$(to_win "$OUT")" $PLUGIN ) 2>/dev/null | tr -d '\r'
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
# the harness settings again, whatever happened (ClearType on)
"$WINE" regedit /S "$(to_win "$WINEPREFIX/harness.reg")" >/dev/null 2>&1; "$WINESERVER" -w
python3 $S/split/bmpstat.py "$OUT"/*.bmp
exit 0
