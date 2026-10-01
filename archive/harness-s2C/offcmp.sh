#!/bin/sh
# offcmp.sh DPI [driver args...] : normal builds (setting OFF), Wine DPI: baseline (9fc893a), main checkout build, new build;
# the same scenario (docked panels, search results, incremental search bar, docked UDL), captures compared
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
DPI=$1; shift
O=off$DPI
rm -rf "$O"; mkdir -p "$O"
./run.sh base-app "$O/set-base" "$O" "$DPI" base "$@" | grep -v "launch\|geom_"
./run.sh /home/user/notepad-plus-plus/PowerEditor/gcc/bin.gcc.x86_64 "$O/set-main" "$O" "$DPI" main "$@" | grep -v "launch\|geom_"
./run.sh new-app "$O/set-new" "$O" "$DPI" new "$@" | grep -v "launch\|geom_"
echo "==== geometry base vs new ($DPI dpi)"
grep "geom_" "$O/base.out" | cut -f3,5 > "$O/geom-base.txt"
grep "geom_" "$O/new.out" | cut -f3,5 > "$O/geom-new.txt"
diff "$O/geom-base.txt" "$O/geom-new.txt" && echo "geometry identical"
echo "==== comparisons ($DPI dpi)"
./cmp.sh "$O/base_1_start.png,$O/new_1_start.png" "$O/main_1_start.png,$O/new_1_start.png" "$O/base_1_start.png,$O/main_1_start.png"
