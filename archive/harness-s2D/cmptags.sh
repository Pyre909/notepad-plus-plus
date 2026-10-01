#!/bin/sh
# cmptags.sh DIR TAG_A TAG_B [DIR_B]: pixel-compare every DIR/TAG_A_*.png with DIR_B/TAG_B_*.png (DIR_B defaults to DIR)
D=$(cd "$(dirname "$0")" && pwd)
A=$1; TA=$2; TB=$3; B=${4:-$1}
for fa in "$A"/"$TA"_*.png; do
  n=${fa#"$A"/"$TA"_}
  fb="$B/${TB}_$n"
  if [ -f "$fb" ]; then "$D/cmp.sh" "$fa,$fb"; else echo "missing $fb"; fi
done
