#!/bin/sh
# cmpcrop.sh WxH a.png,b.png ... : compare the top-left WxH area of image pairs (panels whose size differs by
# the docking containers' rounding)
G=$1; shift
D=$(mktemp -d)
i=0
for pair in "$@"; do
  a=${pair%%,*}; b=${pair#*,}
  i=$((i + 1))
  convert "$a" -crop "$G+0+0" +repage "$D/a$i.png"
  convert "$b" -crop "$G+0+0" +repage "$D/b$i.png"
  n=$(compare -metric AE "$D/a$i.png" "$D/b$i.png" null: 2>&1)
  printf '%-60s top-left %s: %s px differ\n' "$pair" "$G" "$n"
done
rm -rf "$D"
