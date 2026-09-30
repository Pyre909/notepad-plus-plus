#!/bin/sh
# run.sh LIB.a OUT.exe : build fonttest against a libscintilla.a and run it under Wine + Xvfb
set -e
LIB=$1; EXE=$2
x86_64-w64-mingw32-g++ -std=c++20 -O1 -DUNICODE -D_UNICODE -DNOMINMAX -D_WIN32_WINNT=0x0601 -I/home/user/notepad-plus-plus/scintilla/include   /tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/fonttest/fonttest.cpp "$LIB" -static -static-libgcc -static-libstdc++ -mconsole   -lgdi32 -luser32 -limm32 -lmsimg32 -lole32 -loleaut32 -luuid -lcomctl32 -luxtheme -lshcore -ldwmapi -ldwrite -o "$EXE"
. /tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/harness/env.sh
harness_prefix
xvfb-run -a -s "-screen 0 1280x800x24" "$WINE" "$EXE" 2>/dev/null
