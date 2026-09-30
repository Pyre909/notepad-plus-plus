#!/bin/sh
S=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
x86_64-w64-mingw32-g++ -std=c++20 -O1 -DUNICODE -D_UNICODE -municode $S/statictest/gdiweight.cpp /home/user/notepad-plus-plus/PowerEditor/gcc/bin.gcc.x86_64.build/libscintilla.a -static -mconsole -lgdi32 -luser32 -limm32 -lmsimg32 -lole32 -loleaut32 -luuid -lcomctl32 -luxtheme -lshcore -ldwmapi -ldwrite -o $S/statictest/gdiweight.exe || exit 1
. $S/harness/env.sh
harness_prefix
cp $S/statictest/fonts/*.ttf "$WINEPREFIX/drive_c/windows/Fonts/"
"$WINE" $S/statictest/gdiweight.exe "TestMono Hairline" "TestMono Thin" "TestMono ExtraLight" "TestMono Light" "TestMono" "TestMono Medium" "TestHeavy SemiBold" "TestHeavy ExtraBold" "TestHeavy Black" "TestSemi" "Fira Code" "Fira Code Retina" "Tahoma" "NoSuchFont" 2>/dev/null | tr -d '\r'
"$WINESERVER" -k 2>/dev/null; exit 0
