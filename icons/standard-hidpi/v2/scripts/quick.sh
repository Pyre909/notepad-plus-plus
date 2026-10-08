# Renders some icons from src<G>\ straight to png\ for a quick look (no plain-SVG step, no oxipng, no ICOs).
INK='/c/Program Files/Inkscape/bin/inkscape.com'
for n in "$@"; do
  for g in 16 20 24 32; do
    case $g in 20) S="20 40";; 24) S="24 48";; *) S=$g;; esac
    A=""; for z in $S; do A="$A;export-width:$z;export-height:$z;export-filename:png/$n-$z.png;export-do"; done
    "$INK" --actions="${A#;}" src$g/$n.svg >/dev/null 2>&1
  done
done
