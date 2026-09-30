#!/bin/sh
# setup-trees.sh [DIR] : Scintilla 5.6.7 source trees for the upstream patches, each built with MinGW-w64.
#   DIR/s567/scintilla  pristine 5.6.7
#   DIR/p567            + GDI weight family names fix
#   DIR/r567            + DirectWrite rendering parameters API (standalone patch)
#   DIR/both            + both (weight names, then the "after-weight-names" rendering patch)
# p567, r567 and both are git repositories whose first commit is pristine 5.6.7, so "git diff" gives a patch.
set -e
H=$(cd "$(dirname "$0")" && pwd)
D=${1:-$H/../sci-up}
mkdir -p "$D" && D=$(cd "$D" && pwd) && cd "$D"
[ -f scintilla567.tgz ] || curl -sSfL -o scintilla567.tgz https://www.scintilla.org/scintilla567.tgz
echo "19e4476706750056f86ca70974810e4a5b08e73477e13f7d9fae78243606f6a7  scintilla567.tgz" | sha256sum -c -
rm -rf s567 p567 r567 both && mkdir s567 && tar -xzf scintilla567.tgz -C s567
tree() {   # tree NAME PATCH...
	name=$1; shift
	cp -r s567/scintilla "$name"
	(cd "$name" && git init -q && git add -A && git -c user.name=pristine -c user.email=pristine@localhost commit -qm "Scintilla 5.6.7")
	for p in "$@"; do (cd "$name" && git apply "$H/$p"); done
}
tree p567 scintilla-5.6.7-gdi-weight-family-names.diff
tree r567 scintilla-5.6.7-directwrite-rendering-parameters.diff
tree both scintilla-5.6.7-gdi-weight-family-names.diff scintilla-5.6.7-directwrite-rendering-parameters-after-weight-names.diff
T=x86_64-w64-mingw32
for t in s567/scintilla p567 r567 both; do
	make -C "$t/win32" -j2 CXX=$T-g++ CC=$T-gcc AR=$T-ar RANLIB=$T-ranlib WINDRES=$T-windres > "$D/build-$(basename $t).log" 2>&1
	echo "$t: built, $(grep -c 'warning:' "$D/build-$(basename $t).log") warnings"
done
