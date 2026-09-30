#!/bin/sh
# run.sh TEXT : fontcheck under Wine + Xvfb with the synthetic static fonts installed in the prefix
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
. $S/harness/env.sh
harness_prefix
mkdir -p "$WINEPREFIX/drive_c/windows/Fonts"
cp $S/statictest/fonts/*.ttf "$WINEPREFIX/drive_c/windows/Fonts/"
# DirectWrite (unlike GDI) only sees registered fonts
REG=$S/statictest/fonts.reg
printf 'Windows Registry Editor Version 5.00\r\n\r\n[HKEY_LOCAL_MACHINE\\Software\\Microsoft\\Windows NT\\CurrentVersion\\Fonts]\r\n' > $REG
for f in $S/statictest/fonts/*.ttf; do n=$(basename $f .ttf); printf '"%s (TrueType)"="%s"\r\n' "$n" "$(basename $f)" >> $REG; done
"$WINE" regedit /S "$(winepath -w $REG 2>/dev/null || echo Z:$REG)" 2>/dev/null
"$WINESERVER" -w
cd $S/statictest
xvfb-run -a -s "-screen 0 1280x800x24" "$WINE" ${EXE:-fontcheck.exe} "$@" 2>/dev/null | tr -d '\r'
"$WINESERVER" -k 2>/dev/null
exit 0
