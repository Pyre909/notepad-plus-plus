# High-DPI standard toolbar icons, version 1 (2026-10-07)

The 32 "Standard icons" of the Notepad++ toolbar (16x16 bitmaps) redrawn as vector art for 125%-300% scaling
(upstream #16110). Kept as the first version before a flatter polish (version 2). Git tags (local):
`icons-hidpi-v1` (branch `standard-icons-hidpi_20261007`: the assets) and `icons-hidpi-v1-preview` (branch
`standard-icons-hidpi-preview_20261007`: plus the toolbar code that uses them above 100%).

- `svg/16`, `svg/20`, `svg/24`, `svg/32`: one SVG per icon and pixel grid, every edge on whole pixels. 40 and 48 px are
  the 20 and 24 grids doubled.
- `ico/`: `<name>.ico` (PNG-compressed 16, 20, 24, 32, 40, 48 px) and `<name>_dis.ico` (greyed, for disabled
  buttons): 200 KB in all.
- `scripts/`: the pipeline. `gen.py` describes each icon once on a 32 grid and snaps it to each grid (palette `MAT`,
  helpers for pages, floppies, windows, badges, frames; letters drawn as strokes, no font); `export.ps1` runs it, then
  Inkscape 1.4 (plain SVG, PNG per size), `disabled.ps1` (greyed PNGs), oxipng (lossless) and `pack.ps1` (ICOs).
  `strip.ps1`, `critique.ps1` and `originals.ps1` make the review sheets. Copy the scripts into a folder of their own
  and run `export.ps1` with Windows PowerShell 5.1 (needs Python 3, Inkscape at `C:\Program Files\Inkscape`, oxipng
  from winget; `strip.ps1`/`critique.ps1` read the original BMPs from the clone).
- `review/`: the sheets of this version: `strip.png` (the toolbar now vs redrawn at 150% and 200%), `zoom.png` (each
  icon at 16/20/24, 4x), `context.png` (toolbar colour, hover, white, greyed), `tb-preview-zoom-*.png` (the preview
  build's real toolbar at 150%, 3x).

Reviews: two independent AI critiques; the second's findings fixed (grids per size, consistent outlines, hand-drawn
letters). Pyre909's verdict on the preview build: good across 150-250%.
