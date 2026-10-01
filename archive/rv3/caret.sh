#!/bin/sh
# caret.sh DIR X Y H : colours of the pixel column X (Y..Y+H-1) and of the column left of it, in each *_1_main.png
cd "$1" || exit 1
for n in base_1_main off_1_main on_1_main tv1_1_main; do
  c=$(convert "$n.png" -crop "1x$4+$2+$3" -depth 8 txt:- | tail -n +2 | awk '{print $3}' | sort | uniq -c | tr '\n' ' ')
  l=$(convert "$n.png" -crop "1x$4+$(($2 - 1))+$3" -depth 8 txt:- | tail -n +2 | awk '{print $3}' | sort | uniq -c | tr '\n' ' ')
  echo "$n: col $c | left col $l"
done
