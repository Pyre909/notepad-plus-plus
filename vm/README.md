# Font and rendering tests on the Windows VM

Used for the test round in `STATUS.md` (handoff section), on Pyre909's Windows 11 ARM64 VM.

- `weights.cpp`: the test file. Lines 1 and 3 are only bold C++ keywords, lines 2 and 4 only plain (regular)
  identifiers. Copy it to `C:\npp-fonttest\` (the test settings folder).
- `measure.ps1`: takes a screenshot of the Notepad++ edit view with `PrintWindow` (works when the window is covered,
  GDI and DirectWrite alike) and measures each of the first 4 lines: ink (sum of darkness against the line's
  background, /1000), text width in pixels, and coloured fringe pixels on the black lines (ClearType shows them,
  grayscale doesn't). Also records the view's technology (`SCI_GETTECHNOLOGY`: 0 GDI, 1 DirectWrite, 2/3 the
  DirectWrite DC variants). Writes `shots\<label>.png` and appends to `results.csv` next to the script.
  Run it with Windows PowerShell 5.1 (PowerShell 7's System.Drawing doesn't compile in `Add-Type`):
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File measure.ps1 -Label <name>`

- `inkcmp.cpp`: how heavy GDI draws the bold of a GDI family name ("Segoe UI Semibold" at weight 700), against the
  faces DirectWrite picks for the weights 400 to 900 of its family, each drawn by GDI (ink of a sample line, relative
  to the regular). Build from a Developer prompt: `cl /EHsc /std:c++20 /O2 /DUNICODE /D_UNICODE /DNOMINMAX inkcmp.cpp
  user32.lib gdi32.lib`; run `inkcmp.exe <pixel height> <GDI family name>...` (TSV). Used for the bold weight of the
  font-name PR (kit section 5, 2026-10-06).
- `print-pdf.ps1`: prints a document of a build, its Default Style in a font of a weight, to Microsoft Print to PDF
  through the Windows 11 print dialog, in steps (open, inspect, select, print, cancel, close; see its header), then
  lists the PDF's fonts with `pdf-fonts.ps1`. Windows manages the VM's default printer: printing to PDF makes the PDF
  printer the default, so ask Pyre909 first.
- `pdf-fonts.ps1`: the fonts a PDF embeds by their own name table and weight class (Microsoft Print to PDF names them
  CIDFont+F1...).

Start the build under test with its own settings:

```powershell
Start-Process "C:\Program Files\Notepad++\notepad++.exe" -ArgumentList '-multiInst', '-nosession', '-settingsDir=C:\npp-fonttest', 'C:\npp-fonttest\weights.cpp'
```

What the numbers should show: for one font, the bold lines' ink well above the regular lines'; GDI and DirectWrite
about the same ink and width per line (same font, same weight); a fallback font shows up as a different width.

Setting the font: Settings > Style Configurator opens on Global override; pick Default Style (the next entry) and
close with Save & Close: X or Cancel undoes every change made in the dialog. If `weights.cpp` is rewritten while
Notepad++ runs, use File > Reload from Disk (Notepad++ only notices the change when its window is activated).
