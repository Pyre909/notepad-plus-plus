#!/bin/sh
# off.sh DPI [OUTDIR]: setting OFF, base (main checkout) vs new (worktree build), docked and floating panels, at the Wine DPI
D=$(cd "$(dirname "$0")" && pwd)
cd "$D" || exit 1
DPI=$1; O=${2:-off$DPI}
rm -rf "$O"; mkdir -p "$O"
for cfg in docked float; do
  for app in base new; do
    rm -rf "$O/set-$app-$cfg"; cp -r "cfg/set-$cfg" "$O/set-$app-$cfg"
    ./s2brun.sh "$app-app" "$O/set-$app-$cfg" "$O" "pfx$DPI" "$DPI" "${app}_$cfg" > "$O/run-${app}_$cfg.log" 2>&1
    tail -1 "$O/run-${app}_$cfg.log"
  done
done
echo "==== comparisons ($DPI dpi)"
for f in "$O"/base_*.png; do
  n=$(basename "$f"); g="$O/new_${n#base_}"
  ./cmp.sh "$f,$g"
done
