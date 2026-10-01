#!/bin/sh
# Downloads Scintilla tickets with their discussions from SourceForge's REST API into bugs/ and feature-requests/
# (one JSON file per ticket), four at a time. analyze.py then builds tickets.json from them.
# Usage: fetch.sh <first bug> <last bug> <first feature request> <last feature request>
set -e
mkdir -p bugs feature-requests
( seq "$1" "$2" | sed 's|^|bugs/|'; seq "$3" "$4" | sed 's|^|feature-requests/|' ) |
	xargs -P4 -I{} sh -c 'f="{}.json"; [ -s "$f" ] || curl -sS -m 40 --retry 2 -o "$f" "https://sourceforge.net/rest/p/scintilla/{}"'
