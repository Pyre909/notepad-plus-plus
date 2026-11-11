# High-DPI tab bar icons (2026-11-10)

The light mode's tab icons redrawn as line drawings, sharp at every scale: the document states (saved, unsaved, read-only,
read-only by the file's attribute, monitoring) and their "alternate icons" (Preferences > General > Tab Bar), the close
button's four states and the pin's two. Upstream's are one 16-pixel (11 for the close button) frame each, stretched by
Windows at other scales. Asked by Pyre909 after the editor-coloured tabs, from the line icons of a mockup; the meanings
and colours kept (blue saved, red-orange unsaved, grey read-only, an F for the file's attribute, an eye for monitoring;
in the alternate set a check, a pencil, a padlock; the pink close box, red under the mouse). Dark mode's icons are
upstream's (already 16-48 px).

- `scripts/gen_tab.py`: each icon described once (document states on a 16 grid, buttons on an 11 grid), drawn per size
  with strokes of whole pixels (1, 2 or 3 by size) and straight edges snapped to whole pixels; writes `svg/<name>-<size>.svg`.
  Sizes: 16, 20, 24, 28, 32, 40, 48 (the document states, `g_TabIconSize` 16 at 100-300%) and 11, 14, 17, 19, 22, 28, 33
  (the buttons, `g_TabCloseBtnSize` / `g_TabPinBtnSize` 11). Notepad++ loads each at the scaled size (`DPIManagerV2::loadIcon`)
  and Windows takes the frame of that size. At 16 px the floppy's hub is a small label (a circle blurs), the F is drawn
  on pixel rows, the padlock's keyhole is two pixels wide on the middle; below 17 px the unpinned pin is upright (a tilted
  one blurs at 11 and 14 px), grey where the pinned one is blue and filled.
- `scripts/export.ps1`: the pipeline (PowerShell 7, Python 3, Inkscape 1.4 at `C:\Program Files\Inkscape`, oxipng):
  gen_tab.py, Inkscape (one process an icon, all its sizes), oxipng, then `ico/<name>.ico` (PNG-compressed frames).
  Copy the scripts into a folder of their own and run it there.
- `scripts/sheet.ps1 -Old <folder of the current ICOs> -Out <png>`: each icon now and new at 100%, 150% and 200%;
  `focus.ps1 -Names ... -Sizes ... -Out <png>`: a few icons at a few sizes, enlarged a lot; `sheet-current.ps1`: the
  current icons, enlarged.
- `review/`: `review-final.png` (now and new, 100/150/200%), `tabs-final.png` (the tab bar of the preview build at 150%:
  two saved tabs, an unsaved active one with its pin and close box), `focus-docs2.png` and `focus-buttons2.png` (the small
  sizes after the last pass).
