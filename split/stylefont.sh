#!/bin/sh
# stylefont.sh APPDIR OUTDIR [switch] : the font parameters Notepad++ sets its styles with (see stylefont.cpp), for a
# stylers.xml whose Default Style font is "Fira Code Light" (a GDI family name of a weight), C++ COMMENT italic, NUMBER
# with its own font "TestMono Light" and no font style, STRING "Fira Code" bold (the test fonts of statictest installed)
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
. $S/harness/env.sh
APP=$1; OUT=$2; MODE=$3
if [ -z "$IN_XVFB" ]; then
  rm -rf "$OUT"; mkdir -p "$OUT/settings"; OUT=$(cd "$OUT" && pwd); cp -r "$APP" "$OUT/app"
  printf '// comment\nint main() { return 42 + sizeof("text"); }\n' > "$OUT/sample.cpp"
  python3 - "$OUT/app/stylers.model.xml" "$OUT/settings/stylers.xml" <<'EOF'
import re, sys
s = open(sys.argv[1], encoding='utf-8').read()
def setstyle(s, lexer, sid, attrs):
    m = re.search(r'<LexerType name="%s".*?</LexerType>' % lexer, s, re.S)
    block = m.group(0)
    def fix(t):
        for k, v in attrs.items():
            if v is None:
                t = re.sub(r' %s="[^"]*"' % k, '', t)
            else:
                t = re.sub(r'%s="[^"]*"' % k, '%s="%s"' % (k, v), t)
        return t
    nb = re.sub(r'<WordsStyle [^>]*styleID="%d"[^>]*/>' % sid, lambda mm: fix(mm.group(0)), block, count=1)
    return s.replace(block, nb)
s = re.sub(r'(<WidgetStyle name="Default Style" styleID="32"[^>]*fontName=")[^"]*(")', r'\1Fira Code Light\2', s)
s = setstyle(s, 'cpp', 1, {'fontStyle': '2'})
s = setstyle(s, 'cpp', 4, {'fontName': 'TestMono Light', 'fontStyle': None})
s = setstyle(s, 'cpp', 6, {'fontName': 'Fira Code', 'fontStyle': '1'})
open(sys.argv[2], 'w', encoding='utf-8').write(s)
EOF
  [ -f $S/split/stylefont.exe ] && [ $S/split/stylefont.exe -nt $S/split/stylefont.cpp ] || \
    x86_64-w64-mingw32-g++ -std=c++20 -O1 -Wall -municode -DUNICODE -D_UNICODE $S/split/stylefont.cpp -static -static-libgcc -static-libstdc++ -mconsole -luser32 -o $S/split/stylefont.exe || exit 2
  IN_XVFB=1 exec xvfb-run -a -s "-screen 0 $XVFB_SCREEN" "$0" "$APP" "$OUT" "$MODE"
fi
harness_prefix
cp $S/statictest/fonts/*.ttf "$WINEPREFIX/drive_c/windows/Fonts/" 2>/dev/null
( cd "$OUT/app" && timeout -k 5 300 "$WINE" $S/split/stylefont.exe "$(to_win "$OUT/app/notepad++.exe")" "$(to_win "$OUT/settings")" \
    "$(to_win "$OUT/sample.cpp")" $MODE ) 2>/dev/null | tr -d '\r'
"$WINESERVER" -k 2>/dev/null; "$WINESERVER" -w 2>/dev/null
exit 0
