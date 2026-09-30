#!/bin/sh
# sizecheck.sh APPDIR OUTDIR : Style Configurator size combo with a theme whose Default Style is 1 pt
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
. $S/harness/env.sh
APP=$1; OUT=$2
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT"; mkdir -p "$OUT/settings"; cp -r "$APP" "$OUT/app"
  sed 's/\(<WidgetStyle name="Default Style" styleID="32"[^>]*fontSize="\)10"/\11"/' "$OUT/app/stylers.model.xml" > "$OUT/settings/stylers.xml"
  grep -c 'name="Default Style" styleID="32".*fontSize="1"' "$OUT/settings/stylers.xml" >&2
  [ -f $S/split/sizecheck.exe ] && [ $S/split/sizecheck.exe -nt $S/split/sizecheck.cpp ] || \
    x86_64-w64-mingw32-g++ -std=c++20 -O1 -municode -DUNICODE -D_UNICODE $S/split/sizecheck.cpp -static -static-libgcc -static-libstdc++ -mconsole -luser32 -o $S/split/sizecheck.exe || exit 2
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 $XVFB_SCREEN" "$0" "$@"
fi
harness_prefix
( cd "$OUT/app" && timeout -k 5 180 "$WINE" $S/split/sizecheck.exe "$(to_win "$OUT/app/notepad++.exe")" "$(to_win "$OUT/settings")" ) 2>/dev/null | tr -d '\r'
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
exit 0
