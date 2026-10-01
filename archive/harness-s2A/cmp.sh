#!/bin/sh
# cmp.sh a.png,b.png ... : number of differing pixels and their bounding box (ImageMagick)
for pair in "$@"; do
  a=${pair%%,*}; b=${pair#*,}
  sa=$(identify -format '%wx%h' "$a" 2>/dev/null); sb=$(identify -format '%wx%h' "$b" 2>/dev/null)
  if [ "$sa" != "$sb" ]; then printf '%-60s size %s vs %s\n' "$pair" "$sa" "$sb"; continue; fi
  n=$(compare -metric AE "$a" "$b" null: 2>&1)
  if [ "$n" = "0" ]; then printf '%-60s identical\n' "$pair"; continue; fi
  bb=$(convert "$a" "$b" -compose difference -composite -threshold 0 -trim -format '%wx%h%O' info: 2>/dev/null)
  printf '%-60s %s px differ, bbox %s\n' "$pair" "$n" "$bb"
done
