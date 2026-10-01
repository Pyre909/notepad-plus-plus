#!/bin/sh
# fontprobe.sh DPI OTHERDPI : run fontprobe.exe under Wine (prefix of this directory) at DPI
D=$(cd "$(dirname "$0")" && pwd)
DPI=$1; OTHER=$2
x86_64-w64-mingw32-g++ -std=c++20 -O1 -DUNICODE -D_UNICODE "$D/src/fontprobe.cpp" -static -static-libgcc -static-libstdc++ -mconsole -lgdi32 -luser32 -o "$D/fontprobe.exe" || exit 2
export WINEPREFIX=$D/pfx WINEDEBUG=-all WINEARCH=win64 WINEDLLOVERRIDES="mscoree,mshtml="
if [ -z "$IN_XVFB" ]; then IN_XVFB=1 exec xvfb-run -a "$0" "$@"; fi
exec 9>"$D/pfx.lock"; flock -w 3600 9 || exit 75
printf 'REGEDIT4\n\n[HKEY_CURRENT_USER\\Control Panel\\Desktop]\n"LogPixels"=dword:%08x\n' "$DPI" > "$D/pfx/dpi.reg"
/usr/lib/wine/wine64 regedit /S 'Z:'"$(printf '%s' "$D/pfx/dpi.reg" | sed 's#/#\\#g')" >/dev/null 2>&1
/usr/lib/wine/wineserver -w
/usr/lib/wine/wine64 "$D/fontprobe.exe" "$OTHER"
/usr/lib/wine/wineserver -k 2>/dev/null; /usr/lib/wine/wineserver -w
