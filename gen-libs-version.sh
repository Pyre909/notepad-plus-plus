#!/bin/sh
# POSIX stand-in for PowerEditor/src/NppLibsVersionH-generator.bat (cross-build only).
# Runs with cwd = <repo>/PowerEditor/gcc (make's pre-build event).
R=$(cd ../.. && pwd)
sci=$(grep -o '#define VERSION_SCINTILLA "[^"]*"' $R/scintilla/win32/ScintRes.rc | grep -o '"[^"]*"')
lex=$(grep -o '#define VERSION_LEXILLA "[^"]*"' $R/lexilla/src/LexillaVersion.rc | grep -o '"[^"]*"')
bst=$(grep -o '#define BOOST_LIB_VERSION "[^"]*"' $R/boostregex/boost/version.hpp | grep -o '"[^"]*"')
out=$R/PowerEditor/src/NppLibsVersion.h
new=$(printf '// NppLibsVersion.h\n// - maintained by NppLibsVersionH-generator.bat\n#define NPP_SCINTILLA_VERSION %s\n#define NPP_LEXILLA_VERSION %s\n#define NPP_BOOST_REGEX_VERSION %s' "${sci:-\"N/A\"}" "${lex:-\"N/A\"}" "${bst:-\"N/A\"}")
# only rewrite when content changes, so AboutDlg.cpp is not recompiled every build
[ -f "$out" ] && [ "$(cat $out)" = "$new" ] || printf '%s\n' "$new" > $out
