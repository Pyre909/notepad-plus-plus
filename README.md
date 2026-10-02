# Test tooling and Scintilla upstream work

Everything that lived only in a Claude Code session's scratchpad while preparing the text rendering,
per-monitor DPI and font PRs for Notepad++, and the patches submitted to Scintilla. Sources and scripts
only: builds, outputs and the Wine prefix are recreated by the scripts. This branch has no Notepad++
history and no workflows, so it doesn't run CI.

## Restore in a new session

```sh
git clone --branch scintilla-upstream_20260930 --single-branch https://github.com/Pyre909/notepad-plus-plus tooling
sh tooling/restore.sh <scratchpad dir>     # copies everything there and rewrites the old scratchpad path
```

Prerequisites (Ubuntu 24.04):

```sh
apt-get install -y --no-install-recommends g++-mingw-w64-x86-64-posix wine64 wine xvfb imagemagick \
  fontconfig fonts-dejavu-core fonts-firacode fonts-cascadia-code python3 python3-fonttools
```

The Wine prefix is created on first use by `harness/env.sh` (`harness_prefix`): ClearType smoothing,
no crash dialog, unmanaged windows, font substitutes. `statictest/mkfonts.py` (fontTools) makes the
`TestMono` static font family from Fira Code, and `statictest/gdiweight.sh` copies it into the prefix's
Fonts folder, for the static-font weight tests.

## Layout

| Path | What |
|---|---|
| `scintilla/` | The Scintilla submissions: `SCINTILLA-UPSTREAM.md` (ticket texts, plan and status), the patches against Scintilla 5.6.7 (the weight-names one is withdrawn; `…-hfont-null-text-format.diff` is the crash fix, reproduced by `hfontcrash.cpp`), `setup-trees.sh` (downloads 5.6.7, checks its SHA-256, builds pristine and patched trees), `test.sh` (font-weight test and scitest against one tree) |
| `harness/` | Scintilla and Notepad++ checks under Wine + Xvfb: `scitest` (Scintilla test program), `nppshot.sh` (Preferences > Editing 1 checks, 41 checks), `build_scilib.sh`, `link_npp.sh`. See `harness/README.md` |
| `harness-dpi/` | Screen captures at 96/144 DPI (`dpirun.sh`, `src/dpidrive.cpp`), pixel comparison (`cmp.sh`), per-monitor DPI on/off runs (`split.sh`) |
| `split/` | Splitting the combined branch into single-commit PR branches (`spec.py`, `sub.py`, `hunks.py`, `mk.py`), the PR kit `PR-TEXTS.md`, and targeted checks: `sizecheck` (font size list), `smoothcheck` (#17461, Windows font smoothing, with a helper plugin `smoothplugin.cpp`), `techswitch` (Rendering mode applied without restart, 9 checks), `stylefont` (font parameters of the styles for a "Fira Code Light" theme, optionally across a live switch), `bmpstat.py`, `retest-*.sh` |
| `fonttest/` | GDI weight family names ("Fira Code Light") under GDI and DirectWrite: width and ink |
| `statictest/` | Static test fonts of many weights, a GDI weight check, and `fontcheck` (each font-list name drawn as Notepad++ draws it vs. the font Windows maps it to; `run.sh`, `build.sh`). `fontcheck-app.cpp` is the same check with Notepad++'s `FontFamilyNames.cpp` mapping in front of unmodified Scintilla (build with `-DAPP_MAPPING -I<worktree>/PowerEditor/src/ScintillaComponent` plus that .cpp); `mapprobe.cpp` prints the mapping per name |
| `xbuild.sh`, `gen-libs-version.sh` | MinGW-w64 cross build of a Notepad++ checkout or worktree |
| `fork/` | Local tests of the Pyre909 build packaging (portable zip and installer scripts of the `pyre` branch): a package check probe, the signing stand-in, instructions |
| `themes/` | Lucid Light and Lucid Dark, Notepad++ colour themes computed from contrast targets (APCA), with the generator, the checks and the evidence: see `themes/README.md` |
| `archive/` | Earlier harnesses and one-off scripts, kept for reference; and the list of other projects' sources consulted |
| `STATUS.md` | Where everything stands: branches, upstream PRs and tickets, releases, next steps |

## Common runs

```sh
sh xbuild.sh                                          # in a checkout or worktree: build notepad++.exe
harness/nppshot.sh <build>/notepad++.exe harness/out/x-nppshot     # Preferences checks
scintilla/setup-trees.sh sci-up && scintilla/test.sh sci-up/both    # Scintilla patches
```

To revise a Scintilla patch: edit `sci-up/r567` (or `p567`); after a `Scintilla.iface` change run
`scripts/HFacer.py` and `scripts/ScintillaAPIFacer.py`; `git diff > ../../scintilla/<patch>.diff`;
rebuild with `make -C win32 CXX=x86_64-w64-mingw32-g++ ...` (see `setup-trees.sh`); run `test.sh`,
`scripts/HeaderCheck.py`, and a `-DDISABLE_D2D` compile. Remake the "after-weight-names" variant from
`both` so the two patches still apply one after the other.

## Lessons from the testing

- Notepad++ forces GDI under Wine (`wine_get_version` check in `ScintillaEditView.cpp`), so Notepad++
  captures under Wine test GDI. DirectWrite paths were tested with a test-only build that disables that
  check, never committed. Scintilla-level tests (`scitest`) drive DirectWrite directly.
- DirectWrite drawing inside Notepad++ under Wine can't be captured (blank); scitest's own window can.
- Wine 9 doesn't broadcast WM_SETTINGCHANGE for SPIF_SENDCHANGE, and caches SystemParametersInfo per
  process: `smoothcheck` sends WM_SETTINGCHANGE itself, from a helper plugin inside the Notepad++ process.
- Wine's GDI reads the font smoothing from the registry at startup only.
- MSVC decays arrays in a conditional expression to pointers (C2664) where GCC and Clang don't:
  CI on the fork (MSVC) catches what the MinGW build can't.
- The caret blinks: a 1-pixel column at the caret position (#8000FF) differing between captures is not a
  regression.
- SourceForge refuses automated tracker searches (403); search by hand before filing.
- In a newly created Wine prefix, the first runs can capture a window before DirectWrite repaints:
  fonttest then shows the previous row's ink, and scitest `stale_capture` warnings. Run once more.
  The same happened once to `fontcheck` (one name with the previous draw's ink); two reruns were identical.
- Font-name mapping in Notepad++ was validated by comparing `fontcheck-app` (mapping + unmodified
  Scintilla) with `fontcheck` built on the old Scintilla patch, run in the same prefix: identical reports.
