# High-DPI standard toolbar icons, version 2 (2026-10-07)

The 32 "Standard icons" of the Notepad++ toolbar (16x16 bitmaps) redrawn as flat vector art for 100%-300% scaling
(upstream #16110). The final set, approved by Pyre909 on the preview build. Version 1 (gradients) is in `../v1`.
Git tags (local): `icons-hidpi-v2` (branch `standard-icons-hidpi_20261007`: the assets) and `icons-hidpi-v2-preview`
(branch `standard-icons-hidpi-preview_20261007`: plus the toolbar code that uses them at every scale, 100% included).

- `svg/16`, `svg/20`, `svg/24`, `svg/32`: one SVG per icon and pixel grid, every edge on whole pixels. 40 and 48 px are
  the 20 and 24 grids doubled.
- `ico/`: `<name>.ico` (PNG-compressed 16, 20, 24, 32, 40, 48 px) and `<name>_dis.ico` (greyed, for disabled
  buttons): 140 KB in all (version 1: 200 KB).
- `scripts/`: the pipeline. `gen.py` describes each icon once on a 32 grid and snaps it to each grid (`FLAT_PAL`: one
  fill and one outline colour per material; the `FLATNESS` setting and the non-flat code paths are left over from
  version 1, not kept up to date); `export.ps1` runs it,
  then Inkscape 1.4 (plain SVG, PNG per size), `disabled.ps1` (greyed PNGs: grey 96-216, 7/8 opaque), oxipng
  (lossless) and `pack.ps1` (ICOs). Review sheets: `strip.ps1` (toolbar order, now vs redrawn), `compare.ps1` (v1 vs
  v2), `at16.ps1` (original | new | greyed at 16 px; `-Size 20 -Zoom 5` for 125%), `focus.ps1` (a few icons at every
  size), `critique.ps1`, `originals.ps1`, `toolbar-shot.ps1` (a screenshot of a running build's toolbar);
  `quick.sh` renders a few icons for a quick look. Copy the scripts into a folder of their own and run `export.ps1`
  with Windows PowerShell 5.1 (`-ExecutionPolicy Bypass`; needs Python 3, Inkscape at `C:\Program Files\Inkscape`,
  oxipng from winget; the sheets read the original BMPs from the clone).
- `review/`: `strip.png`, `compare.png` (v1 vs v2 at 150% and 200%), `at16.png` and `at20.png` (100% and 125%),
  `focus-before.png` and `focus.png` (the last pass: macro icons, Word Wrap, Find, Replace).

Design rules of this version:
- **Flat**: solid fills, no gradients or highlights.
- **Sleek**: an outline only on an object's outer edge; its inner parts are fills, set off by a 1-pixel gap or by
  colour.
- **Nothing fades at 16 px**: details that would blur there are drawn differently at that size, such as the Sync
  Scrolling divider, the floppy label stripe, the Cut blades, and the Replace arrow, which is drawn pixel by pixel.
- **Centred**: the macro frames have the same inset on every side, and their contents are worked out from the
  middle.

Changes in the last pass:
- Word Wrap is the usual "wrap text" symbol.
- Find is two rounded, mirrored barrels.
- Replace is an upright b and a, with the arrow crossing over both.
