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

Start the build under test with its own settings:

```powershell
Start-Process "C:\Program Files\Notepad++\notepad++.exe" -ArgumentList '-multiInst', '-nosession', '-settingsDir=C:\npp-fonttest', 'C:\npp-fonttest\weights.cpp'
```

What the numbers should show: for one font, the bold lines' ink well above the regular lines'; GDI and DirectWrite
about the same ink and width per line (same font, same weight); a fallback font shows up as a different width.
