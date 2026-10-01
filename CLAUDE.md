# CLAUDE.md: Pyre909's Notepad++ fork

Context for Claude Code sessions in this repository. Read it first; for the full history, read `STATUS.md`
and the PR kit on the tooling branch (see "Where the rest is"). This file is on `pyre` only: on another
branch, read it with `git show origin/pyre:CLAUDE.md`.

## What this is

`Pyre909/notepad-plus-plus` is a fork of official Notepad++ (`notepad-plus-plus/notepad-plus-plus`).

- `pyre` (default branch): **Pyre909's own Notepad++**. It is official Notepad++ plus text rendering, DPI and
  font changes, released privately as the "Pyre909 build". `PYRE-BUILD.md` describes it for users.
- Features that look worthwhile to upstream go there as separate pull requests, one per feature, each a single
  commit on upstream `master`.
- Earlier work was done in a cloud Claude Code session on Linux, testing under Wine. A local Windows session
  can do what that one couldn't (see "What still needs real Windows").

## Branches and their rules

| Branch | Rule |
|---|---|
| `master` | Exact mirror of upstream. Only updated with GitHub's **Sync fork**. Never commit here. |
| `pyre` | The product. Merge `master` into it to take new upstream versions. New features land here. |
| `claude/awesome-darwin-bsud9v` | The combined development branch `pyre` was built on (`357fec9`); no longer needed for new work. |
| `text-rendering_20260925` | **Open upstream PR #18418.** New commits only: no amend, rebase or force-push (upstream CONTRIBUTING rule 10). Push only with Pyre909's OK. |
| `text-rendering-translations_20260925`, `live-rendering-switch_20260930` | Follow-ups of #18418: open them after #18418 is merged, after rebasing onto `master` (commands in the PR kit). |
| `directwrite-font-names_20260930`, `per-monitor-dpi_20260925` | Ready PR candidates (font names: issue + PR texts ready; DPI: discuss with maintainers first). |
| `font-size-1pt_20260925`, `font-weight-names_20260925`, `archive/*` | History: a closed PR, a superseded version, early drafts. Don't build on them. |
| `scintilla-upstream_20260930` | Tooling branch (no Notepad++ history): test tools, PR kit, status notes. |

PR branches are named `<topic>_<YYYYMMDD>` and start from upstream `master`.

## Upstream policies learned the hard way

- **Notepad++**: link every PR to an issue (`fix #NNNNN`); the PR template asks to **disclose AI use** (always
  do); small PRs are preferred; contributors test on Windows before opening.
- **Scintilla**: its maintainer wrote on feature request #1592 (2026-09-30): *"I am not currently accepting
  LLM-generated contributions."* So **never submit code to Scintilla** from this work. Bug reports with
  reproduction steps are fine; leave the fix to them. Font naming is the application's job there, not
  Scintilla's (bugs #2080, #2356), which is why the font-name fix lives in `FontFamilyNames.cpp`.
- Comments and replies are posted by Pyre909 under their own account: draft them in a casual, human voice, not
  formal prose; they edit and post them.

## Building on Windows

- Visual Studio 2022 (toolset v143) or 2026 (v145) with "Desktop development with C++".
- `PowerEditor\visual.net\notepadPlus.sln`; from a Developer PowerShell:
  `msbuild PowerEditor\visual.net\notepadPlus.sln /m /p:configuration=Release /p:platform=x64`
  gives `PowerEditor\bin64\Notepad++.exe`.
- To run a dev build without touching the installed Notepad++: `Notepad++.exe -multiInst -nosession
  -settingsDir=<empty folder>`, or a copy of the exe in a folder with `doLocalConf.xml`.
- CI (`.github/workflows/CI_build.yml`) runs on every push: 13 jobs (MSVC x64/Win32/ARM64 Release and Debug,
  CMake, MinGW, Clang). MSVC catches things GCC doesn't; check it after pushing.

## Code conventions

- Match the file's line endings: most `PowerEditor` sources are CRLF, Scintilla sources LF. Tabs, Notepad++'s
  own style (`_member` names, braces on new lines).
- A new source file must be listed in `PowerEditor/src/CMakeLists.txt` and
  `PowerEditor/visual.net/notepadPlus.vcxproj` (the GCC makefile finds files by itself).
- New UI strings go in `PowerEditor/installer/nativeLang/english.xml`; other languages get them from
  translators (or a separate `[xml]` PR).
- Don't change the version line in `PowerEditor/src/resource.h` (upstream edits it each release; merges would
  conflict). The build name is added in `AboutDlg.cpp` (`PYRE_BUILD_TAG`).
- Keep `pyre`-only changes small and marked "Pyre909 build" in comments, so upstream merges stay easy.

## Where the fork's code is

| Feature | Main places |
|---|---|
| Text rendering settings (Editing 1 > Text Rendering) | `ScintillaEditView::applyTextRenderingSettings` / `applyTextRenderingSettingsToAll`, `EditingSubDlg` in `preferenceDlg.cpp`, enums in `NppConstants.h`, config.xml `fontAntialiasing` / `fontRenderingMode` / `fontContrast` (`Parameters.cpp`) |
| DirectWrite rendering parameters (Scintilla, local patch) | `scintilla/win32/SurfaceD2D.cxx`, `ScintillaWin.cxx`, `ListBox.cxx`; private messages `SCI_SETFONTRENDERINGPARAMETER` 5101 / `SCI_GETFONTRENDERINGPARAMETER` 5102 |
| Rendering mode applied without restart | `ScintillaEditView::setTechnologyToAll` (all views in `_liveViews`), restyle via `WM_UPDATESCINTILLAS` in `preferenceDlg.cpp` |
| Fonts of a weight under DirectWrite ("Fira Code Light") | `ScintillaComponent/FontFamilyNames.cpp/.h`, `ScintillaEditView::setSpecialStyle` and `clearAllStyles` |
| Per-monitor DPI (MISC., `perMonitorDpiAwareness`) | `dpiManagerV2`, `StaticDialog`, docking (`DockingCont`, `DockingManager`, `Gripper`), panels |
| Font sizes 1-4 pt | `fontSizeStrs` in `NppConstants.h` |
| Crash guard (Scintilla bug #2520) | `FontDirectWrite::HFont` in `SurfaceD2D.cxx` |
| Build name | `AboutDlg.cpp` |
| Releases | `.github/workflows/pyre-release.yml`, `.github/pyre/package.ps1`, `.github/pyre/installer.ps1`, installer tweaks in `PowerEditor/installer/nsisInclude/` |

## Releases

Actions > **Pyre909 release** > Run workflow (or push a tag `pyre-*`). It builds x64 with MSBuild, then a
portable zip and an installer (official `nppSetup.nsi`), both with the official release's plugins, updater and
Explorer context menu, and auto-update off (`disableNppAutoUpdate.xml`). The result is a **draft release**,
private to people with push access. Locally: run `package.ps1` then `installer.ps1` (PowerShell 7; the installer
also needs NSIS and 7-Zip).

## What still needs real Windows

The cloud session couldn't test these (Wine forces GDI in Notepad++, can't capture DirectWrite or dialog text,
and can't run 32-bit NSIS installers):

1. The first release run (needs `pyre` as default branch), then the installer over an installed Notepad++:
   About and Help > Debug Info say "(64-bit, Pyre909 build)", auto-update is off, Plugins Admin installs a
   plugin, the Windows 11 Explorer "Edit with Notepad++" menu works, uninstall removes `disableNppAutoUpdate.xml`.
2. DirectWrite in Notepad++: each Text Rendering choice changes the text at once; the rendering mode switches
   GDI <-> DirectWrite without restart, fonts following.
3. Fonts: Default Style "Bahnschrift Light" with DirectWrite draws Light, bold keywords SemiBold;
   "Cascadia Code SemiBold" bold draws Bold (needed before opening the font-name PR).
4. Per-monitor DPI with monitors at different scales.

## Where the rest is

On branch `scintilla-upstream_20260930` (`git fetch origin scintilla-upstream_20260930`, then
`git show origin/scintilla-upstream_20260930:STATUS.md`, or check it out in a separate worktree):

- `STATUS.md`: branches, upstream PRs and Scintilla tickets, next steps.
- `split/PR-TEXTS.md`: every issue / PR / ticket text, rebase commands, testing notes.
- `scintilla/SCINTILLA-UPSTREAM.md`: the Scintilla tickets and their outcome.
- `README.md`: the Linux/Wine test tools (`harness/`, `harness-dpi/`, `statictest/`, `fork/`, ...).
