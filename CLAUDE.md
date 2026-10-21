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
- Earlier work was done in a cloud Claude Code session on Linux, testing under Wine. Since 2026-10-01 it
  continues on Pyre909's Windows VM, which can do what Wine couldn't (see "What still needs real Windows").
  **Where the work stands: the "Handoff" section of `STATUS.md`** (tooling branch, see "Where the rest is").
- That cloud conversation can be resumed here with `claude --teleport` (same claude.ai account, in the clone,
  clean working tree, no other Claude session running in it). Teleport checks out the cloud session's branch,
  `claude/awesome-darwin-bsud9v`: run `git switch pyre` afterwards. The cloud session's scratchpad files
  (`/tmp/claude-0/...`) don't come along; everything worth keeping is on the branches.

## Branches and their rules

| Branch | Rule |
|---|---|
| `master` | Exact mirror of upstream. Only updated with GitHub's **Sync fork**. Never commit here. |
| `pyre` | The product. Merge `master` into it to take new upstream versions. New features land here. |
| `claude/awesome-darwin-bsud9v` | The cloud session's branch: the combined development branch `pyre` was built on (`357fec9`); no longer needed for new work (`claude --teleport` checks it out: switch back to `pyre`). |
| `text-rendering_20260925` | Upstream PR #18418, **closed** by the maintainer on 2026-10-02 (too large a change, regression risk; reconsidered only if Scintilla takes its part, which it won't). Kept as history. |
| `text-rendering-translations_20260925` | Follow-up of the closed #18418: on hold. |
| `rtl-views-gdi_20261006` | Right-to-left views drawn with GDI (DirectWrite ignores the mirroring `WS_EX_LAYOUTRTL`; fixes #17865, #17518 and the RTL UI languages, drawn left-to-right in a mirrored window by default upstream), one commit on upstream `master` (`53d0026`, CI: all 13 jobs pass); PR texts in kit section 6. `pyre` has the same design since 2026-10-06. |
| `live-rendering-switch_20261005` | The rendering mode applied without restarting (MISC. box), one commit on top of `rtl-views-gdi_20261006` (`61eccb1` since 2026-10-20: upstream's two lines of the Preferences handler left as they are, `setTechnologyToAll(previous, technology)` only the loop; CI: all 13 jobs pass; rebased on `master` once that one is merged); feature request + PR texts in kit section 7, the PR once the request is Accepted. Amend freely until the PR is opened, then new commits only (upstream CONTRIBUTING rule 10). Its first version (`305ff13`, pushed 2026-10-05), which refused DirectWrite while right-to-left documents were shown, is kept as `archive/live-rendering-switch-refusal_20261005`: the fallback if `rtl-views-gdi_20261006` is turned down. |
| `directwrite-font-smoothing_20261006` | DirectWrite following the Windows font smoothing (fixes #14954: with DirectWrite, turning the Windows font smoothing off, or to Standard, changed nothing), one commit on upstream `master` (`76b3210`, CI: all 13 jobs pass); PR texts in kit section 8. `pyre` has its code as the "Follow Windows" antialiasing of its Text Rendering settings (since 2026-10-06). |
| `directwrite-font-names_20260930`, `per-monitor-dpi_20260925` | PR candidates (font names: a bug fix of #9951 and #12393, rewritten on 2026-10-06, rebased on `b661c2b` on 2026-10-20 with `setStyleFont` in one body as `ace29cd`, PR texts ready, what's left in kit section 5; DPI: rebased on upstream `b661c2b` on 2026-10-20 as `4eaa93d`, with `pyre`'s section 2 parts A and B, CI: all 13 jobs pass; discuss with maintainers first, through the comment for #14959 in kit section 4). |
| `font-size-1pt_20260925`, `font-weight-names_20260925`, the other `archive/*` | History: a closed PR, a superseded version, early drafts. Don't build on them. |
| `function-list-caret_20261020`, `doclist-column-width_20261020` | Bug fixes for upstream (2026-10-20), one commit each on upstream `master` `b661c2b`, CI: all 13 jobs pass; texts in kit sections 9 and 10, issues to open first: the Function List's caret tracking walked the whole tree on each caret move (`398b2c2`: 374 ms to 16.6 ms on 60,000 lines), the Document List's column widths grew over 100% scale (`20f0a90`; Pyre909 checks it by hand first). `pyre` has both (`4d4b96b`, `dd3cd5a`). |
| `standard-icons-hidpi_20261007` | The 32 "Standard icons" of the toolbar redrawn (ICOs 16-48 px and their SVGs, no code), one commit on upstream `master` (`bc2e60f`): offered by a comment on #16110 (2026-10-07), no PR; the maintainers decide how to use them. `pyre` has the same icons in place of the bitmaps. |
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

- New machine: `.github/pyre/setup-vm.ps1` installs the tools (winget), Claude Code, clones the fork (`pyre`,
  remote `upstream` = official), sets `core.autocrlf false` (the sources mix CRLF and LF: don't convert), and
  adds worktrees for the PR and tooling branches in `<clone>.worktrees\<branch>`. Work on a PR branch in its
  worktree, not by switching branches in the clone.
- Pyre909's test machine is a **Windows 11 ARM64 VM in Parallels** on an Apple Silicon Mac. x64 builds run
  there under emulation (DirectWrite is the same system code, so rendering tests hold), but an x64 Explorer menu
  doesn't load in the ARM64 Explorer: test that with the ARM64 installer. macOS can rescale the VM window, so judge
  rendering from screenshots taken inside Windows, not from what Pyre909 sees on the Mac screen.
- Visual Studio 2026 (toolset v145) or 2022 (v143) with "Desktop development with C++". The VM has the VS 2026 Build
  Tools only (18.10.2 since 2026-10-06, VS 2022 removed), which `setup-vm.ps1` installs.
- `PowerEditor\visual.net\notepadPlus.sln`; from a Developer PowerShell:
  `msbuild PowerEditor\visual.net\notepadPlus.sln /m /p:configuration=Release /p:platform=x64`
  gives `PowerEditor\bin64\Notepad++.exe`; `/p:platform=ARM64` gives `PowerEditor\binarm64\Notepad++.exe` (native on
  the VM; needs Visual Studio's MSVC ARM64 build tools component, which the setup script adds).
- The Pyre909 build differs from upstream's build settings (since 2026-10-20; one-line changes, so merges stay easy):
  **C++23** everywhere (`stdcpp23` = `/std:c++23preview` in `notepadPlus.Cpp.props`, `Scintilla.vcxproj`,
  `Lexilla.vcxproj`; `-std:c++23preview` in `scintilla.mak` and `lexilla.mak`; `CMAKE_CXX_STANDARD 23`; `-std=c++23` in
  the three makefiles), not `stdcpplatest` (the C++26 preview); **Windows 10 1809** as the minimum (`_WIN32_WINNT_WIN10`,
  `NTDDI_WIN10_RS5`, linker `MinimumRequiredVersion` 10.0, the installer's check in `tools.nsh`), so Windows 10 functions
  are called directly, not through `GetProcAddress` (only the undocumented dark mode functions, plugins, Wine's
  `wine_get_version`, DbgHelp and DirectWrite stay dynamic); **PGO** switch: `/p:PyrePgo=Instrument`, the training run,
  then `/p:PyrePgo=Optimize` (the instrumented exe is linked without `/DEPENDENTLOADFLAG:0x800`, to find `pgort140.dll`
  next to it). Measured on the VM (ARM64, 2026-10-20): lexing 19% faster, folding and Mark All 17%, wrapping 15%.
- After a change of a class layout in a header many files include (a member of `ScintillaEditView.h`, `Parameters.h`,
  `SurfaceD2D.h`), rebuild clean (`/t:Rebuild`) before testing: an incremental build left stale objects once, and the
  exe crashed at startup (0xC000041D, 2026-10-06).
- To run a build without touching the real settings (PowerShell; the folder must exist, else Notepad++ says
  "Invalid directory" and uses the normal settings):
  `Start-Process "C:\Program Files\Notepad++\notepad++.exe" -ArgumentList '-multiInst', '-nosession', '-settingsDir=C:\npp-test'`
  (a dev build: `PowerEditor\bin64\Notepad++.exe` or `binarm64`), or a copy of the exe in a folder with
  `doLocalConf.xml`. Quote the path (it has a space). From Git Bash, which Claude Code uses for shell commands
  on Windows, don't start the exe directly: the command waits until Notepad++ closes, and an unquoted
  `C:\npp-test` loses its backslash. Use `powershell -Command "Start-Process ..."` instead.
- CI runs **only when started by hand** (since 2026-10-16): Actions > **Pyre909 CI** > Run workflow, or
  `gh workflow run pyre-ci.yml --ref pyre -f ref=<branch, tag or commit>` (`-f jobs=auto` for upstream's filtering).
  It's upstream's `CI_build.yml` (13 jobs: MSVC x64/Win32/ARM64 Release and Debug, CMake, MinGW, Clang), turned into
  `.github/workflows/pyre-ci.yml` by `.github/pyre/make-ci.ps1`: run that script again after an upstream merge that
  changes `CI_build.yml`. Upstream's own `CI_build` and `release-notifier` workflows are disabled on the fork
  (`gh workflow disable`, a repository setting, not a file change), so pushes build nothing. Run CI before pushing a
  PR branch for review, and after an upstream merge into `pyre`; MSVC catches things GCC doesn't and vice versa. By
  default every job runs: upstream's filter (only `.md`/`.txt` changed: nothing built; `[force all]` in the title)
  applies with `jobs=auto` only.
- The CI's GCC and Clang builds also run locally (MSYS2 on the VM since 2026-10-20: MINGW64 GCC, CLANG64 Clang), in a
  clean worktree: `$Env:MSYSTEM = 'MINGW64'` (or `CLANG64`), `C:\msys64\mingw64\bin` (or `clang64\bin`) and
  `C:\msys64\usr\bin` first in `PATH`, then `mingw32-make -j 6 -f PowerEditor\gcc\makefile` (about 4 minutes; `DEBUG=1`
  for Debug). Also on the VM: Visual Studio's Clang tools (`/p:PlatformToolset=ClangCL`), WinDbg, Sysinternals (DebugView,
  Process Explorer), the Windows Performance Toolkit.

## Code conventions

- Match the file's line endings: most `PowerEditor` sources are CRLF, most Scintilla sources LF (not
  `ScintillaWin.cxx`, `Scintilla.h`, `deps.mak`: check with `git ls-files --eol`). Tabs, Notepad++'s own style
  (`_member` names, braces on new lines).
- A new source file must be listed in `PowerEditor/src/CMakeLists.txt` and
  `PowerEditor/visual.net/notepadPlus.vcxproj` (the GCC makefile finds files by itself). A new Scintilla header: run
  `python DepGen.py` in `scintilla/win32` so that `deps.mak` (the MinGW build) and `nmdeps.mak` list it, keep only its
  lines (it also adds a `BoostRegexSearch.h` upstream doesn't list), and put `nmdeps.mak` back to LF (it writes CRLF).
- New UI strings go in `PowerEditor/installer/nativeLang/english.xml`; other languages get them from
  translators (or a separate `[xml]` PR).
- Don't change the version line in `PowerEditor/src/resource.h` (upstream edits it each release; merges would
  conflict). The build name is added in `AboutDlg.cpp` (`PYRE_BUILD_TAG`).
- Keep `pyre`-only changes small and marked "Pyre909 build" in comments, so upstream merges stay easy.

## Where the fork's code is

| Feature | Main places |
|---|---|
| Text rendering settings (Editing 1 > Text Rendering) | `ScintillaEditView::applyTextRenderingSettings` / `applyTextRenderingSettingsToAll` (tables), "Follow Windows" = kit 8's `getWindowsFontQuality` / `applyWindowsFontQuality` and the `WM_SETTINGCHANGE` case of `ScintillaProc`, `EditingSubDlg` in `preferenceDlg.cpp`, enums in `NppConstants.h`, config.xml `fontAntialiasing` / `fontRenderingMode` / `fontContrast` / `fontLigatures` / `lineSpacing` (`readTextRenderingParams` / `writeTextRenderingParams` in `Parameters.cpp`; upstream's `smoothFont` kept in sync); Line spacing = `applyLineSpacing` (the edit views only, `_isMainEditZone`; again in `updateForDpi`), Font ligatures = `SC_FONTRENDERING_LIGATURES` |
| DirectWrite rendering parameters (Scintilla, local patch) | API in `scintilla/include/ScintillaFontRendering.h` (private messages `SCI_SETFONTRENDERINGPARAMETER` 5101 / `SCI_GETFONTRENDERINGPARAMETER` 5102), logic in `scintilla/win32/FontRenderingOverrides.h` (header only), applied at the end of upstream's `ScintillaWin::UpdateRenderingParams`; the messages in `WndProc`'s first switch (Direct2D builds only); `SurfaceD2D::SetFontQuality` (variants), `LayoutCreateMeasured` (GDI classic, and the font's typography); `ListBox.cxx`. Font bits in `vs.extraFontFlag` above `QualityMask` (`ScintillaWin::UpdateFontBits`): `fontQualityMeasuringGdiClassic`, `fontQualityNoLigatures` (`FontDirectWrite::pTypography`: liga, clig and calt off) |
| Rendering mode applied without restart | `ScintillaEditView::setTechnologyToAll` (as on its PR branch, all views in `_liveViews`); pyre's `switchTechnologyOfAll` calls it, then `technologyChanged` on each view that switched (antialiasing, style fonts); the handler in `preferenceDlg.cpp` |
| Right-to-left views drawn with GDI (DirectWrite ignores `WS_EX_LAYOUTRTL`) | `ScintillaEditView::changeTextDirection`, `init` (a view mirrored at creation), `setTechnologyToAll` (skips mirrored views), the startup direction sync in `Notepad_plus::init` |
| Fonts of a weight under DirectWrite ("Fira Code Light") | `ScintillaComponent/FontFamilyNames.cpp/.h` (as on its PR branch, plus pyre's GDI block), `ScintillaEditView::setSpecialStyle` and `clearAllStyles` (one record per view, `_styleFonts`); `refreshStyleFonts(technology, previousTechnology)` maps them again when a view's technology changes (`technologyChanged`) and for printing (`Printer.cpp`), leaving the fonts a plugin set |
| Font for every theme (Style Configurator, Global override's font controls) | `WordStyleDlg` (`setVisualFromGlobalOverrideFont`, `globalOverrideFontChanged`: the font controls of the Global override page, taken before upstream's `WM_COMMAND` switch; `showGlobalOverrideCtrls` shows the note), `WordStyleDlg.rc` (upstream's layout plus the note, ID 2291 in `WordStyleDlgRes.h`), the font values of `GlobalOverride` (`Parameters.h`; config.xml `forcedFontName` / `forcedFontSize` / `forcedFontStyle` next to upstream's force flags, taken once from the theme's Global override by `initGlobalOverrideFont` in `Parameters.cpp`), `ScintillaEditView::setStyle` |
| Per-monitor DPI (MISC., `perMonitorDpiAwareness`) | `dpiManagerV2` (the fonts set for a DPI owned by `UniqueFont`: `replaceWindowFont`, `initIconTitleFont`, `setIconTitleFont`), `StaticDialog` (`DialogDpiLayout`), docking (`DockingCont`, `DockingManager`, `Gripper`), panels; a real DPI change: the tooling branch's `review/tests/pyre-dpi-scale.ps1 -WaitForScaleChange` (a person changes the display scale) |
| Font sizes 1-4 pt | `fontSizeStrs` in `NppConstants.h` |
| Crash guard (Scintilla bug #2520) | `FontDirectWrite::HFont` in `SurfaceD2D.cxx` |
| Layout speed and drawing of the views (2026-10-19) | `ScintillaEditView::applyLayoutCache` (the edit views: page layout cache and multiple phases, not for a large file; at `init` and `activateBuffer`), `init`: layout threads (8 at most), font locale; Scintilla local patches: segments taken in blocks in `LayoutSegments` (`EditView.cxx`), kept layouts laid out again after a tab stop or representation change (`Editor.cxx`); Document Map and Peeker: `SCI_SETTABMINIMUMWIDTH` 0 |
| Regex search speed (the Function List 25 to 30 times faster, 2026-10-20) | `boostregex/BoostRegExSearch.cxx`: `NppWideRegexTraits` (the Win32 traits of `wchar_t` from tables, MSVC builds only: `BOOST_REGEX_USE_WIN32_LOCALE`), the 16 compiled regexes of `EncodingDependent::compileRegex`; `FunctionParser::isInZones` (binary search). Check with the tooling branch's `review/tests/function-list.ps1` (upstream's 46 Function List unit tests) |
| Windows 11 rounded corners on the popups it leaves square (Preferences > Dark Mode, config.xml MISC `roundedPopups`) | `NppDarkMode::setRoundedCorners` (`DWMWA_WINDOW_CORNER_PREFERENCE`, Windows 11 only), called at each showing: call tips (`setRoundedCallTips` from `ScintillaEditView::showCallTip`; Scintilla makes a new window each time), `AboutDlg::doDialog`, `DocumentPeeker::doDialog`, the colour popup's `WM_INITDIALOG`; the checkbox in `DarkModeSubDlg`. Test: the tooling branch's `review/tests/pyre-rounded-popups.ps1`. Mica isn't needed: Windows 11 gives the title bars Mica itself |
| Function List caret tracking and auto-completion speed (2026-10-20) | `FunctionListPanel::markEntry` (the leaves in document order, `_leafPositions`, a binary search; reset in `reload`, `sortOrUnsort`, `searchFuncAndSwitchView`, `removeAllEntries`); `AutoCompletion::getWordArray`: `findWordsWithPrefix` (MSVC builds, UTF-8 documents: one pass over `SCI_GETCHARACTERPOINTER`, the regex's words exactly; the regex kept for other encodings, a non-ASCII prefix in case-insensitive mode and invalid UTF-8), `sortInsensitive` (an upper-case table) |
| Replace All and line removals with the redraw off (upstream #10301) | `ScintillaEditView::RedrawOff` (every shown view of the document), in `FindReplaceDlg::processAll`, `Notepad_plus::deleteMarkedLines`, `cutMarkedLines`, `removeDuplicateLines` |
| Standard toolbar icons (redrawn, in place of the 16x16 bitmaps) | `icons/standard/toolbar-hidpi/` (ICOs: the button's `IDR_` + 4000, disabled + 4100, `IDI_STDHD_*` in `resource.h`; sources and generator in the tooling branch's `icons/standard-hidpi/v2`), the image lists `HLIST_STD_HIDPI` / `HLIST_DISABLE_STD_HIDPI` in `ImageListSet` (plugin buttons: their toolbar bitmap), the standard branch of `ToolBar::reset` |
| Build name | `AboutDlg.cpp` |
| Releases | `.github/workflows/pyre-release.yml`, `.github/pyre/package.ps1`, `.github/pyre/installer.ps1`, installer tweaks in `PowerEditor/installer/nsisInclude/` |

## Releases

Actions > **Pyre909 release** > Run workflow (or `gh workflow run pyre-release.yml --ref pyre`). It builds x64 and ARM64 with MSBuild, then for each a portable zip and an installer (official
`nppSetup.nsi`), with the official release's plugins, updater and Explorer context menu of the same architecture,
and auto-update off (`disableNppAutoUpdate.xml`). The result is a **draft release**, private to people with push
access. Publishing a draft creates its `pyre-*` tag; since 2026-10-16 that starts nothing (the workflow has no tag
trigger any more; before, it ran the release and CI again and made a duplicate draft). The files are unsigned: SmartScreen warns on other machines (More info > Run anyway); the
release notes say so. Locally: run `package.ps1` then `installer.ps1`, each with `-Arch x64` or `-Arch arm64` and the same
`-OutDir` (PowerShell 7; the installer also needs NSIS and 7-Zip).

## What still needs real Windows

The cloud session couldn't test these (Wine forces GDI in Notepad++, can't capture DirectWrite or dialog text,
and can't run 32-bit NSIS installers):

1. The installer: **done** (2026-10-01, ARM64 installer of release `pyre-8.9.8.1-aee7bbf` on the VM: it installs,
   About says "(ARM 64-bit, Pyre909 build)", the Windows 11 Explorer "Edit with Notepad++" menu works, Plugins
   Admin works, auto-update is off: the ? menu has no "Update Notepad++" or "Set Updater Proxy..."). Not checked:
   uninstall removing `disableNppAutoUpdate.xml` (it would remove Pyre909's working install; check it when going
   back to official Notepad++).
2. DirectWrite in Notepad++: the rendering mode switches GDI <-> DirectWrite without restart, the text redraws
   at once (**pass**, 2026-10-01, ARM64 install on the VM), and the font stays the same, no fallback font
   (**pass**, 2026-10-01, Bahnschrift Light). With DirectWrite each Antialiasing choice and DirectWrite mode changes
   the text at once (**pass**, 2026-10-06, test `pyre-text-rendering-live`).
3. Fonts: Default Style "Bahnschrift Light" with DirectWrite draws Light, bold keywords SemiBold (**pass**,
   2026-10-01: weights 300 and 600, ink and width per line within 2.4% and 3 px of GDI; readings in `STATUS.md`).
   "Cascadia Code SemiBold" bold: DirectWrite draws it with Cascadia Code Bold, not a simulated bold (**pass**,
   2026-10-06, the face DirectWrite matches to the bold weight; GDI doesn't embolden a SemiBold font at all).
4. Per-monitor DPI with a change of Windows' scale: **done** (2026-10-20, Pyre909 changed it 150% -> 100% -> 150% while
   the tooling branch's `review/tests/pyre-dpi-scale.ps1 -WaitForScaleChange` ran): every panel follows both ways.
   The Project Panel's text-button toolbar didn't (comctl32 keeps text buttons no higher than for the DPI the toolbar was
   made at, and the theme change after a DPI change puts that back): fixed by `ProjectPanel::ToolbarSubclass`, checked
   with 150 -> 200 -> 150%. Below the start scale the status bars stay at least 28 pixels (comctl32, left as is). Two
   monitors of different scales: still to do (needs a second display).

## Where the rest is

On branch `scintilla-upstream_20260930`. On the VM, the setup script checked it out in
`%USERPROFILE%\src\npp.worktrees\scintilla-upstream_20260930` (`git pull` there first); elsewhere,
`git fetch origin scintilla-upstream_20260930`, then `git show origin/scintilla-upstream_20260930:STATUS.md`.

- `STATUS.md`: **the handoff (where the test round stands, what's next)**, branches, upstream PRs and Scintilla
  tickets.
- `split/PR-TEXTS.md`: every issue / PR / ticket text, rebase commands, testing notes.
- `review/`: the review harness, run before pushing a branch: `review.ps1` (upstream and fork rules, coding style,
  localization, MSVC builds, app-level tests in `review/tests/`) and `checklist.md` (the independent AI review). The
  Claude Code skill `npp-review` (installed in `%USERPROFILE%\.claude\skills\`) does both.
- `scintilla/SCINTILLA-UPSTREAM.md`: the Scintilla tickets and their outcome.
- `README.md`: the Linux/Wine test tools (`harness/`, `harness-dpi/`, `statictest/`, `fork/`, ...).
