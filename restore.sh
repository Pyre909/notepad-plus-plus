#!/bin/sh
# restore.sh DEST : copy this tooling into DEST (a new session's scratchpad) and point its scripts at DEST.
# The scripts were written in a session whose scratchpad was:
OLD=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad
set -e
[ $# -eq 1 ] || { echo "usage: restore.sh DEST" >&2; exit 64; }
SRC=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$1" && DEST=$(cd "$1" && pwd)
(cd "$SRC" && tar --exclude=.git -cf - .) | (cd "$DEST" && tar -xf -)
grep -rlF "$OLD" "$DEST" | while read -r f; do sed -i "s#$OLD#$DEST#g" "$f"; done
chmod +x "$DEST"/*.sh "$DEST"/*/*.sh
echo "restored to $DEST"
for c in x86_64-w64-mingw32-g++ xvfb-run convert /usr/lib/wine/wine64 python3; do
	command -v "$c" >/dev/null 2>&1 || [ -x "$c" ] || echo "missing: $c (see README.md, Prerequisites)"
done
