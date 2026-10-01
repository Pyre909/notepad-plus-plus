# Archive: earlier tools and one-off scripts

Kept so nothing from the work is lost; the current tools are in the other folders. Outputs (screenshots, logs,
builds) and copies of other projects' sources aren't included.

| Path | What |
|---|---|
| `harness-s2A` ... `harness-s2D` | Earlier Notepad++ drivers and runs under Wine (settings, synthetic workspaces, DPI sequences, comparisons; `harness-s2D/patch.py` instruments a copy of the sources for DPI tests), superseded by `harness/` and `harness-dpi/` |
| `rv3/` | Review-round edit scripts (`e_*.py`: exact edits of Notepad++ sources) and checks (`clangcheck.py`, `eol.py`) |
| `wf1_clang/` | Clang check of the Scintilla values mirrored in `scintilla/win32/ScintillaWin.cxx` (`checkvals.cxx`), and a comparison of Clang diagnostics before and after a change (`cmp.sh`) |
| `audit-tr/` | Translation audits: language files' coverage (`langcheck.py`) and moved controls (`movecheck.py`) |
| `scripts/` | One-off source edits (`fix_*.py`, `edit.py`, `movetech.py`, `restore_fw.py`), translation fixes (`tr_*.py`), DirectWrite gamma and font `gasp` table studies (`gam.py`, `gasp*.py`), and a Clang check (`clangcheck.sh`) |

## Reference sources consulted (not copied here)

Studied for how other DirectWrite applications set rendering parameters, read from their public repositories:

- Windows Terminal (MIT): `src/renderer/atlas/` (AtlasEngine, BackendD2D, BackendD3D, dwrite_helpers, shaders)
  https://github.com/microsoft/terminal
- Firefox (MPL 2.0): `gfx/thebes/gfxDWriteFonts.cpp`, `gfxWindowsPlatform.cpp`, `gfx/2d/DWriteSettings.cpp`
  https://github.com/mozilla/gecko-dev
- Skia (BSD): `src/ports/SkScalerContext_win_dw.cpp` https://github.com/google/skia
- MacType: its DirectWrite hooks https://github.com/snowie2000/mactype
- Notepad4 (by zufuliu): its Scintilla `win32` changes https://github.com/zufuliu/notepad4
