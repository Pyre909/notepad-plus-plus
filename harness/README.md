# Wine smoke-test harness: DirectWrite text rendering overrides

Runtime checks for the private Scintilla API `SCI_SETFONTRENDERINGPARAMETER` (5001) /
`SCI_GETFONTRENDERINGPARAMETER` (5002) and the Notepad++ "Text rendering" preferences group
(Editing 1 page, IDs 6280-6286). Everything runs headless under Wine 9.0 on Xvfb.

The harness never writes to the repository or a worktree: it reads a build's `libscintilla.a` or
`notepad++.exe` and works on copies in `out/`.

```
H=/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/harness
```

| File | Purpose |
|---|---|
| `env.sh` | Shared settings: `WINEPREFIX=$H/wineprefix`, `WINEDEBUG=-all`, the wine64 binary, the Xvfb screen size, and `harness_prefix` (creates the prefix, imports the registry settings, locks the prefix) |
| `src/scitest.cpp`, `build_scitest.sh`, `run_scitest.sh` | Scintilla-level test program, its build script and its Wine/Xvfb runner |
| `src/nppdrive.cpp`, `nppshot.sh` | Program that drives Notepad++, and the Wine/Xvfb runner around it (nppshot builds `out/nppdrive.exe` automatically) |
| `build_scilib.sh` | Builds a private `libscintilla.a` from a worktree directory or a git commit. The sources are copied first |
| `link_npp.sh` | Links a private `notepad++.exe` from a build's objects plus another `libscintilla.a`, to test the UI and Scintilla changes together before they are merged |

Installed with `apt-get install -y --no-install-recommends wine64 wine python3-pil imagemagick
fonts-dejavu-core fontconfig` (Ubuntu 24.04, Wine 9.0~repack-4build3, 64-bit only; `wine32` is
not installed, so ignore its warning). Mesa llvmpipe was already installed, which gives Wine's
wined3d/Direct2D an OpenGL backend on Xvfb. The PIL module is only in `/usr/bin/python3`. The
pipeline uses ImageMagick (`convert`, `montage`) for PNG conversion.

`harness_prefix` puts these settings in the prefix (`env.sh`, marker `wineprefix/.harness_reg_v3`):
- ClearType system font smoothing: FontSmoothingType=2, contrast 1400, orientation RGB. This way
  the default quality goes through Scintilla's ClearType rendering-parameters path.
- The winedbg crash dialog is off, so a crash ends the process instead of blocking it.
- X11 windows are unmanaged ("Managed"="N"). Xvfb has no window manager, so Wine draws the title
  bars itself.
- Font substitutes: "Courier New" (Notepad++'s default font) uses Liberation Mono and "Consolas"
  uses DejaVu Sans Mono. This applies to GDI only.

Scripts that share a prefix run one at a time (`flock` on `wineprefix.lock`). To run in parallel,
give each run its own prefix copy: `cp -a $H/wineprefix /tmp/pfx2 && WINEPREFIX=/tmp/pfx2 ...`.

---

## (a) scitest: Scintilla API, measuring and painting

### Build and run against any libscintilla.a and include directory

```sh
# One step: build out/<dir>/scitest.exe for this library, then run every group (about 50 s)
$H/run_scitest.sh -l /path/to/PowerEditor/gcc/bin.gcc.x86_64.build/libscintilla.a \
                  -i /path/to/scintilla/include  -o $H/out/my-run
# -i is optional: by default it is <checkout>/scintilla/include, derived from the .a path.

# Or in two steps
$H/build_scitest.sh [LIB.a] [INCLUDE_DIR] [OUT.exe]      # default: main checkout build -> out/scitest.exe
$H/run_scitest.sh -e $H/out/scitest.exe -o $H/out/my-run [-g "api matrix"] [-t 240] [-s] [-- --font "Liberation Mono" --size 1100]
```

Without a built library from a worktree (its xbuild.sh has not been run yet), build a private one
from the sources:
```sh
$H/build_scilib.sh /home/user/notepad-plus-plus/.claude/worktrees/<wt> $H/out/lib-wt   # or a commit: build_scilib.sh 3b9b347 ...
$H/run_scitest.sh -l $H/out/lib-wt/libscintilla.a -i $H/out/lib-wt/src/scintilla/include -o $H/out/wt-run
```
`build_scilib.sh` takes about 30 s. It uses its own flags (-O2, NDEBUG, boost regex) and not
xbuild.sh.

Each group runs in its own `scitest.exe` process, with a per-group timeout, so a crash or hang
in one group does not stop the others. The groups:

| group | what it does |
|---|---|
| `env` | Wine version, GDI fixed-pitch fonts, DirectWrite family lookup, the chosen font and size, the monitor rendering parameters, the system smoothing settings |
| `techs` | Set and get each SC_TECHNOLOGY (0-4); measure; screen capture with a non-blank check; also tries the window DC and PrintWindow captures; checks there is no WM_PAINT storm |
| `api` | A fresh window returns -1 for all 6 parameters. Valid values round-trip. Out-of-range values leave the previous value (the ranges are those of the 3b9b347 implementation: gamma 1000-2200, EC/GEC 0-1000, CTL 0-100, PG 0-2, RM {0,2,3,4,5}; edit `valid`/`invalid` in `groupApi` if the contract changes). Unknown parameters (6, 7, 100, -1, -2, 0x10000, INT_MAX) are ignored, return -1 and have no side effects. Setting -1 resets |
| `matrix` | Under DirectWrite, for RM in {unset, NATURAL, NATURALSYMMETRIC, GDICLASSIC, GDINATURAL} x SC_EFF_QUALITY 0-3: apply, repaint synchronously, `SCI_POINTXFROMPOSITION` for positions 0..200 of line 0, integral/fractional verdict, capture with checksum and non-background count. Summary lines: images per mode and per quality, stale-capture detection, measuring independent of quality |
| `sens` | For each parameter, compares two extreme values pixel by pixel. INFO only: it records what the platform's Direct2D honours |
| `switch` | Overrides set under DirectWrite, then GDI (overrides kept, integral), a value set while in GDI, back to DirectWrite (the new value applies), then DirectWriteDC, DirectWriteRetain, DirectWrite1, GDI and DirectWrite (overrides kept, GDICLASSIC stays integral, non-blank) |
| `settingchange` | `WM_SETTINGCHANGE` (SPI_SETFONTSMOOTHINGCONTRAST and "WindowMetrics") with overrides set; SPI contrast changed to 2000 and restored; a broadcast |
| `popups` | `SCI_AUTOCSHOW` list and `SCI_CALLTIPSHOW` tip under GDI and under DirectWrite with several RM/quality settings. Checks they are active and visible, captures them non-blank, checks for repaint storms |
| `idle` | ScintillaWin's internal idle messages still work (SCN_UPDATEUI through SC_WORK_IDLE, background wrapping through SC_WIN_IDLE), and 100 private SET/GET messages cause no idle work (on the baseline, 5001/5002 were the idle messages) |

Font and size: the first of DejaVu Sans Mono, Liberation Mono, Consolas, ... that both
DirectWrite and GDI know. The size is chosen near 11 pt so that the natural advance is clearly
fractional: DejaVu Sans Mono at 10.75 pt gives an 8.629 px natural advance, while GDI-compatible
advances are 8 px. With a fractional natural advance, "all 200 advances equal" is a reliable
integral test, even though `SCI_POINTXFROMPOSITION` truncates to int.

### Output

The console ends with the FAIL/CRASH/WARN lines and
`SCITEST_SUMMARY pass=N fail=N crash=N warn=N out=DIR`. The exit code is 0, or 2 for
crash-level problems (SEH or C++ exception, window destroyed, timeout/hang, non-zero process
exit). With `-s`, the exit code is 1 when there are FAILs.

In the output directory:
- `results.tsv` / `scitest.log`: one line per check, in the form
  `RESULT<TAB>group<TAB>name<TAB>PASS|FAIL|SKIP|INFO|WARN|CRASH<TAB>detail`. Measurement lines
  contain `x[0..20]=...`, `adv_avg200` and `advances=integral|fractional`. Capture lines contain
  `nonbg` (non-background pixels), `aa_gray` (grey antialiasing pixels), `chroma` (coloured,
  that is ClearType, pixels) and the `hash`.
- `matrix_contact.png`: 5x4 contact sheet of the matrix (the rows are qualities 0-3, the columns
  are unset/NATURAL/SYMMETRIC/GDICLASSIC/GDINATURAL).
- `matrix_rm<mode>_q<quality>.png`, `tech_<n>.png`, `switch_*.png`, `settingchange_*.png`,
  `popup_autoc_*.png`, `popup_calltip_*.png`, `popup_screen_*.png` (the window with the call tip).
- `stderr_<group>.log`: first-chance access violations, if there were any.

---

## (b) nppshot: the Notepad++ Preferences UI

```sh
$H/nppshot.sh /path/to/PowerEditor/gcc/bin.gcc.x86_64/notepad++.exe $H/out/npp-run [-f a,r,c] [-n]
#   -f a,r,c : final combo indices (antialiasing, rendering mode, contrast); default: last item of each
#   -n       : skip the restart / persistence run
```
A run takes about 40 s. The exe's whole directory is copied to `OUTDIR/app`, and the settings go to
the empty `OUTDIR/settings` (`-settingsDir=`). Flags: `-multiInst -nosession -noPlugin`, plus a
sample file.

Run 1 (`run1_*`):
1. Launch the exe and wait for the "Notepad++" window. Capture `run1_main.png`.
2. Post `WM_COMMAND IDM_SETTING_PREFERENCE` (48011).
3. Wait for the #32770 dialog that has `IDC_LIST_DLGTITLE` (6002). Read the category names with
   `LB_GETTEXT`, which Wine marshals.
4. Select "Editing 1" the way `PreferenceDlg::run_dlgProc` expects: `LB_SETCURSEL`, then
   `WM_COMMAND(MAKEWPARAM(6002, LBN_SELCHANGE), hList)` sent to the Preferences dialog. The page is
   identified by its controls 6216 and 6245.
5. Capture `run1_prefs_editing1.png` and the whole screen, `run1_screen_prefs.png`. The main
   window is placed at (0,0) 1024x420 and Preferences below it.
6. Check `IDC_TEXTRENDERING_GB_STATIC` (6280) and the 3 combos (6282/6284/6286): label, item
   texts, current selection, enabled state.
7. Cycle every item of each combo: `CB_SETCURSEL`, then `WM_COMMAND(MAKEWPARAM(id, CBN_SELCHANGE),
   hCombo)` sent to the page. After each item, check that the process is alive and answers
   `WM_NULL` within 10 s. Read the main Scintilla's technology, font quality and the 6 overrides
   (`SCI_GET*` 5002 across processes) and capture the editor (`run1_editor_<combo>_<i>.png`,
   contact sheet `editor_cycle_contact.png`).
8. Apply the final selections (`FINAL_SELECTION` line), capture `run1_prefs_final.png`, send
   Close (6001), then `WM_CLOSE`. Notepad++ must exit with code 0 within 30 s.

Run 2 (`run2_*`): restarts Notepad++ with the same settings directory, opens Editing 1 again and
checks that the combos show the final selections (`persisted_*`).

After each run, `config_ScintillaPrimaryView_run{1,2}.txt` holds the attributes of the
`GUIConfig name="ScintillaPrimaryView"` element in `settings/config.xml`, in two lines: one with
smoothFont and the font* attributes, one with all attributes. They are also printed at the end.

Things to look at:
- `NPPSHOT_SUMMARY`, and the FAIL/CRASH/WARN lines.
- `results.tsv`, especially the `cycle_*` lines: `editor tech=0 quality=Q overrides(...)=...`.
- The PNGs.
- `stray_dialog_*` WARN lines. Unexpected message boxes are captured and their text is logged,
  for example a missing resource in a bad link.

To test the UI and Scintilla worktrees together before the merge, link a private exe:
```sh
$H/build_scilib.sh <scintilla-worktree-or-commit> $H/out/lib-x
$H/link_npp.sh <ui-worktree> $H/out/lib-x/libscintilla.a $H/out/combo-build
$H/nppshot.sh $H/out/combo-build/app/notepad++.exe $H/out/combo-nppshot
```
`link_npp.sh` snapshots the worktree's objects, links in about 1 s, and needs that worktree to
have been built with xbuild.sh.

---

## What Wine can and cannot tell you (Wine 9.0, Mesa llvmpipe, Xvfb 24-bit, 96 dpi)

Works and is meaningful:
- Direct2D/DirectWrite load and render headless. All 5 technologies (including DirectWrite1,
  with D3D11 and a DXGI swap chain) paint non-blank text. The screen capture is `BitBlt` from the
  screen DC, repeated until two grabs are identical, because the first D2D frame reaches the
  screen a little after `WM_PAINT`.
- The whole get/set contract (validation, reset, unknown parameters, persistence across
  technology switches and `WM_SETTINGCHANGE`).
- **Measuring mode.** Wine's DirectWrite implements GDI-compatible layout. GDICLASSIC and
  GDINATURAL give whole-pixel advances (8 px, the same as GDI). The other modes give the natural
  8.63 px. The images differ accordingly, so glyph positions in the drawing also follow the
  measuring mode.
- Aliased (NON_ANTIALIASED) versus antialiased output.
- No-crash, no-hang and non-blank checks for the autocompletion list (its D2D DC render target)
  and the call tip.
- The idle-message renumbering.
- For Notepad++: the Preferences page, combo items, enable states and the UI-to-Scintilla
  mapping (the overrides and quality read back from the editor). Also persistence to config.xml
  and a clean exit.

Wine cannot exercise these, so treat them as proven only for no-crash and non-blank:
- **Wine's Direct2D ignores the rendering parameters' pixel effect.** Gamma (1000 vs 2200),
  enhanced contrast (0 vs 1000), grayscale enhanced contrast, ClearType level (0 vs 100) and
  pixel geometry (FLAT/RGB/BGR) all give pixel-identical output (`sens_*` INFO lines).
  NATURAL vs NATURALSYMMETRIC, and GDICLASSIC vs GDINATURAL, are also pixel-identical: only the
  measuring difference shows.
- **No ClearType in Wine's Direct2D.** SC_EFF_QUALITY_LCD_OPTIMIZED and DEFAULT render as
  grayscale (`chroma=0`), even with ClearType as the system setting. Wine's GDI does render
  subpixel ClearType, so GDI captures have chroma > 0.
- `CreateMonitorRenderingParams` ignores the monitor ("monitor setting ignored") and returns
  gamma 2.0, EC 0, CTL 0, PG FLAT, RM DEFAULT. The "Follow Windows / monitor" defaults are
  therefore not realistic.
- **Notepad++ forces GDI under Wine** (`ScintillaEditView::init` detects `wine_get_version`).
  nppshot can only check the settings path, the stored overrides (read back from Scintilla) and
  font quality: the GDI antialiasing differences are visible in `run1_editor_antialiasing_*.png`.
  Rendering mode and contrast have no visible effect there.
- DPI is 96 only, with a single monitor and no WM_DPICHANGED or monitor-change paths.
- `PrintWindow` / WM_PRINTCLIENT cannot capture D2D windows, except DirectWriteDC. This is
  reported as INFO in `techs`. Use the screen captures.

Known Wine artifact, not a regression: under DirectWrite the call tip repaints continuously,
about 60 WM_PAINT per second. `CTPaint` creates an `HwndRenderTarget` in every paint, and Wine's
swap-chain creation invalidates the window again. The baseline does this too. It is reported as
`WARN calltip_repaint_loop_*`, and the harness message pump is bounded so it cannot hang.

## Validation (2026-09-24)

| Run | Output dir | Result |
|---|---|---|
| Baseline scitest (main checkout libscintilla.a, 05:46, no implementation) | `out/baseline-scitest` | pass=138 fail=76 crash=0 warn=4. Every API check fails as expected: GET returns 0 because 5001/5002 were SC_WIN_IDLE/SC_WORK_IDLE. The GDI-mode measure checks fail (advances stay fractional). `private_messages_no_idle_work` fails. Everything paints non-blank |
| Implementation scitest (private lib from commit 3b9b347, worktree 1) | `out/impl-3b9b347-scitest` | pass=214 fail=0 crash=0 warn=4. The 4 warnings are the call tip repaint loop |
| Baseline nppshot (main checkout notepad++.exe) | `out/baseline-nppshot` | pass=16 fail=8 crash=0. The prefs dialog opens on Editing 1 and the captures are non-blank. The 6280 group and the 3 combos are ABSENT, as expected. Clean exit (code 0) and restart. config.xml has only `smoothFont='no'` |
| UI worktree 2 nppshot (commit cce3ef8 exe, baseline Scintilla) | `out/ui-cce3ef8-nppshot` | pass=40 fail=0. All items cycle; `fontAntialiasing/fontRenderingMode/fontContrast` are persisted and restored |
| Combined (worktree 2 objects + 3b9b347 Scintilla, `link_npp.sh`) | `out/combo-nppshot` | pass=40 fail=0. Overrides read back from the editor, e.g. ClearType less fringing sets CTL=50, contrast Medium/High/Very high set EC/GEC=100/150, 200/250, 300/350, and a rendering mode under "None" antialiasing stays -1 |
