# Status (2026-10-06)

Where the Notepad++ text rendering, DPI and font work stands: branches, upstream PRs and tickets, the Pyre909
build, and what's next. A Claude Code session starts with `CLAUDE.md` on `pyre` (rules, build, code map). The PR kit with every issue/PR/ticket text is `split/PR-TEXTS.md`; the Scintilla side is
`scintilla/SCINTILLA-UPSTREAM.md`, and how Scintilla's maintainer decides (a survey of 792 tickets, compared with
ours) is `scintilla/MAINTAINER-SURVEY.md`; the tools are described in `README.md`.

## Handoff (2026-10-06): read this first

This file is long: read it by section (grep the headings), not whole. One session per phase: start a fresh Claude Code
session from `CLAUDE.md` and this block, and run `/compact` with a keep-note before a break of an hour or more.

- Everything is pushed: `pyre` up to `d594e8a` (font for every theme) and this branch.
- Waiting on Pyre909: open the RTL fix PR (kit section 6), the font smoothing PR (kit 8), the live switch's feature
  request (kit 7); then the font-name PR (kit 5) and the optional comment on #9951.
- Next for Claude, one per session: merge upstream into `pyre` ("Next" 7: conflicts in `AboutDlg`, `dpiManagerV2`);
  the Symmetric / Adaptive check ("Next" 8); the test round's open rows (Antialiasing choices at once, the DPI one).
- Reviews: `review.ps1 -Quiet` (PASS lines to the log only), then the AI review (skill `npp-review`). Keep agents to the
  harness; no ad hoc fan-out.

## The move to the Windows VM (2026-10-01, history)

The cloud session (claude.ai/code: Linux, testing under Wine) hands over to Claude Code on Pyre909's
**Windows 11 ARM64 VM** (Parallels on an Apple Silicon Mac). Clone `%USERPROFILE%\src\npp` on `pyre` (remote
`upstream` = official), worktrees in `%USERPROFILE%\src\npp.worktrees\<branch>`, set up by
`.github/pyre/setup-vm.ps1`. `gh` should be signed in with the `workflow` scope and default to the fork
(check: `gh auth status`; set: `gh repo set-default Pyre909/notepad-plus-plus`), so it never targets official
Notepad++ by accident.

- **Everything is pushed**: all branches in the table below, and this branch. The cloud session's scratchpad
  (Wine prefixes, builds, screenshots, downloaded official releases) doesn't come along and isn't needed: its
  tools are on this branch (`archive/`, `harness*/`, `fork/`, `scintilla/`).
- **Resuming the cloud conversation itself**: in the clone, clean working tree, other Claude session closed:
  `claude --teleport` (pick the session). It loads the conversation and checks out the cloud session's branch
  `claude/awesome-darwin-bsud9v` (old): `git switch pyre` afterwards. Starting fresh with `claude` works too:
  `CLAUDE.md` and this file carry the context.
- Nothing is left running in the cloud: no PR watches, no scheduled check-ins.

### The test round on the VM

Build under test: the installed ARM64 release `pyre-8.9.8.1-aee7bbf`, started for tests with its own settings:
`Start-Process "C:\Program Files\Notepad++\notepad++.exe" -ArgumentList '-multiInst', '-nosession', '-settingsDir=C:\npp-test'`
(the folder must exist). Pyre909 clicks; Claude takes screenshots inside Windows (PowerShell) and measures, e.g.
ink per line of a test file with keyword-only (bold) and identifier-only (regular) lines. macOS rescales the VM
window: judge from the screenshots, not by eye.

| Check | Result |
|---|---|
| Installer: installs over Notepad++, About "(ARM 64-bit, Pyre909 build)", Explorer "Edit with Notepad++", Plugins Admin, no "Update Notepad++" in the ? menu | **pass** |
| Live switch: Text Rendering GDI <-> DirectWrite redraws the text at once, no restart | **pass** |
| The font stays the same after the switch (no fallback font) | **pass** for Bahnschrift Light: after the live GDI -> DirectWrite switch, each line is within 3 px of its GDI width (readings below) |
| With DirectWrite, each Antialiasing choice and DirectWrite mode changes the text at once | to do |
| Default Style "Bahnschrift Light": Light text, SemiBold bold keywords, about the same ink in GDI and DirectWrite | **pass**: with DirectWrite the styles get weight 300 (text) and 600 (keywords) (`SCI_STYLEGETWEIGHT`); ink per line within 2.4% of GDI, width within 3 px; bold lines about 1.26x the regular lines' ink per letter in both (readings below) |
| "Cascadia Code SemiBold": bold keywords draw Bold | to do |
| Baseline: the font tests with the official 8.9.8.1 ARM64 portable (expect DirectWrite to draw a fallback or wrong weight) | to do |
| Per-monitor DPI (MISC. option, restart; then change Windows' scale while Notepad++ runs, or two displays) | to do |
| Uninstall removes `disableNppAutoUpdate.xml` | skipped: it would remove the working install |

Note: a fresh settings folder starts in DirectWrite (technology 1) in this build, not GDI.

Bahnschrift Light readings, Default Style at 10 pt in `C:\npp-fonttest` (tools and procedure in `vm/README.md`; all
readings in `vm/results.csv`, screenshots in `vm/shots/`; ink = darkness / 1000, width in px):

| Line of `vm/weights.cpp` | GDI ink / width | DirectWrite ink / width |
|---|---|---|
| 1, bold keywords | 350.2 / 277 | 343.4 / 276 |
| 2, regular identifiers | 286.1 / 273 | 279.3 / 270 |
| 3, bold keywords | 274.8 / 219 | 269.4 / 217 |
| 4, regular identifiers | 240.3 / 219 | 236.1 / 218 |

Line height: 24 px in GDI, 25 px in DirectWrite. The same font set through Global override ("Enable global font")
gives identical GDI numbers (`bahnschrift-light-override-gdi`). For reference, Courier New with DirectWrite: bold
lines about 1.57x the regular lines' ink per letter (`courier-new-dw`).

### After the test round

1. Font test passes: in kit section 5 (`split/PR-TEXTS.md`), replace "Not tested: a real Windows font
   collection" with the Windows results, keep the official/fork screenshots as before/after. Pyre909 opens the
   issue, then the PR with `fix #<issue>` (AI disclosure stays). Drafts for Pyre909 to post: casual, their voice.
2. Record each result in `CLAUDE.md` ("What still needs real Windows") on `pyre` and in the table above.
3. #18418 was closed on 2026-10-02 (see "Upstream Notepad++"); the live switch goes upstream on its own (kit
   section 6). Waiting on others: Scintilla #2520 (keep the guard).

## The DirectWrite review and its refactoring (2026-10-06)

Three independent reviews of the DirectWrite work (the Scintilla rendering parameters patch, the Text Rendering
settings, the font-name mapping), each finding checked against the code, then the changes below. Pyre909's choices:
keep the DirectWrite "GDI classic" mode (crisp ClearType with ligatures and colour emoji) with its code isolated, drop
the six hidden config.xml overrides, keep the Rendering mode combo in Editing 1, keep pyre's GDI font mapping (fixed),
keep the light-text gamma as it is.

- `directwrite-font-names_20260930`: rewritten as `9f605be` on master `a69bc23` (kit section 5): DirectWrite's own GDI
  mapping (`CreateFontFromLOGFONT`) instead of the hand matcher (the same mapping for the VM's 319 fonts, 3 times faster),
  GDI as upstream, one font record per view, the styles printed with their GDI names (a DirectWrite "Fira Code" Light
  printed Regular), `refreshStyleFonts` leaving the fonts a plugin set.
- `pyre`, four commits: `6e78e65` the font names as on the PR (plus pyre's GDI mapping, cached, non-bold styles at
  weight 400 at most: the 132 changed GDI mappings draw the same pixels); `84dc7f8` "Follow Windows" from kit section 8
  (fixes the ClearType Text Tuner gap, Next 6) and the code of kits 6, 7 and 8 placed as on their branches (each kit's
  diff reverse-applies to pyre, but for the one header spot kits 7 and 8 share), so an upstream merge of them can't add
  definitions twice silently; `409cc09` the settings as tables, the font quality sent only when it changes (it re-wrapped
  every view), the overrides gone, upstream's lines of Parameters.cpp and Notepad_plus.cpp back, Preferences cleaned;
  `0296a87` the Scintilla patch on top of upstream's `UpdateRenderingParams` in two headers of its own
  (`ScintillaFontRendering.h`, `FontRenderingOverrides.h`), the API trimmed and renumbered, upstream lines rewritten
  38 -> 23, rendering pixel-identical before and after (8 settings, light and dark themes).
- Bugs fixed on the way: printing (above), a rendering mode switch replacing the fonts of plugins' Scintillas, the
  Tuner gap, and the aliased-text rule of the settings going stale when Windows' smoothing changed.
- Tests: `directwrite-font-names` and `pyre-text-rendering-config` (new), `pyre-rtl-style-fonts` (the plugin case); all
  10 app tests pass on pyre (154 checks, 157 after the second review below), the PR branch passes its own. Builds:
  ARM64, x64, Win32, no warning.
- Found on the way: an incremental MSVC build after a class layout change left stale objects (a crash at startup with
  0xC000041D); a clean rebuild fixed it (`CLAUDE.md`, Building).
- A second review of the result, by two independent reviewers (the font-name branch with its kit text, pyre's four
  commits), each finding checked against the code. Fixed (the font-name branch amended as `9f605be`; pyre's `9dcdc53`,
  then `fcbbb30` its docs; the new checks fail on the build before the fixes and pass after):
  - Scintilla didn't compile with `DISABLE_D2D` any more (shown with `cl` before and after): the overrides are in its
    Direct2D code now, the messages not handled without it. `deps.mak` and `nmdeps.mak` list the two new headers
    (`DepGen.py`; the MinGW build uses `deps.mak`), so incremental builds recompile what includes them.
  - `technologyChanged` set the whole text rendering again on a GDI/DirectWrite crossing (an RTL tab switch), which
    replaced a font quality a plugin set: it now follows Windows with the `WM_SETTINGCHANGE` rule, for a view still at
    the quality it got from it (test `pyre-rtl-style-fonts`, 18 checks).
  - A config.xml without `smoothFont` (written by hand) read as "no": ClearType became Follow Windows. Now
    `fontAntialiasing` is kept and `smoothFont` set from it (test `pyre-text-rendering-config`, 11 checks).
  - After printing, the style fonts were restored after the line number margin was measured again, which measured it
    with the GDI name (the fallback font under DirectWrite) until the next paint: the fonts first now.
  - Smaller: the GDI family list cache that never got a hit removed, a stretch out of range not used, an unused
    default argument, the author of the font-name commit (Pyre909, as on 6 to 8).
  - Kit section 5: the main upstream issue is #9951 (2021, 29 comments, "scintilla dependent"; #14526 and #16666 point
    to it), not only #12393; DirectWrite is the default since 8.6; the side effects (a style reads back the DirectWrite
    font, also for plugins; the IME composition window's GDI font); the testing claims (MSVC 19.51, code analysis and
    GCC/Clang in CI only).
- Checked and kept:
  - Bold 300 heavier than the font, rather than a cap at Bold. Measured (ink of a sample line through GDI, 15 and
    24 px): GDI emboldens Light, SemiLight and Medium fonts from about Regular to about Bold depending on the font, and
    300 heavier is in that range (closest for MonoLisa Light; a cap at Bold would make Medium lighter than GDI's); GDI
    doesn't embolden SemiBold or heavier fonts at all, their bold is the regular pixel for pixel. Bold of "Cascadia Code
    SemiBold" is Cascadia Code Bold, not simulated: that check of kit section 5 is done.
  - Aliased text with the "GDI classic" mode is measured like GDI since `84dc7f8` (the app's rule for aliased text is
    gone): one pixel tighter lines with Courier New, the same columns, clean text; the layout then doesn't change with
    the antialiasing.
- Gaps left, as upstream and the kits have them: a plugin's own `SCI_SETTECHNOLOGY` doesn't reach `technologyChanged`
  (a plugin that switches a view manages it, as kit 7 has it); `NPPM_SETSMOOTHFONT(FALSE)` follows Windows even with an
  explicit antialiasing chosen (kit 8's meaning, plugins only). The Linux/Wine harness (`harness/`) is history: written
  for the first API.
- Pushed on 2026-10-06 with Pyre909's OK: pyre (`fcbbb30`, CI: all 13 jobs pass), the font-name branch by force
  (`9f605be`, CI: all 13 jobs pass), this branch.
- Printing checked (kit section 5, Before opening 2), with Pyre909's OK as it makes the PDF printer Windows' default:
  "Segoe UI Light" with DirectWrite prints in Segoe UI Light (the PDF's embedded font: weight class 300), on the PR
  build and on pyre (whose bold keywords print in Segoe UI Semibold, as its screen shows them). Tools in `vm/`:
  `print-pdf.ps1`, `pdf-fonts.ps1`, and `inkcmp.cpp` for the bold weights.

## Font for every theme (2026-10-06, pyre only)

Pyre909 forces a font, one size and no bold for all styles with Global override. Only its check boxes were in
config.xml; the values were the theme's Global override style, and upstream moved that entry to the bottom of the style
list (#15640, #16214), so each theme needed it set again, scrolled to.

- The Style Configurator has a row under "Select theme": "For every theme:" Font, Size, Bold, Italic, Underline, each
  "(Theme)" or the value forced (Bold, Italic, Underline: Always / Never). Saved in config.xml next to upstream's force
  flags (`forcedFontName`, `forcedFontSize`, `forcedFontStyle`), applied by `ScintillaEditView::setStyle`, kept when
  switching themes, restored by Cancel. The theme's Global override keeps its colours; its entry shows a note in place
  of its font controls and font check boxes.
- A config.xml without these values (official Notepad++'s, which drops them when it saves config.xml) takes the theme's
  Global override values once, as that Notepad++ forced them: nothing changes on screen.
- Not for upstream: it de-emphasises Global override, and the 2015 report of the per-theme values (#1053) was closed as
  stale.
- pyre `d594e8a`. Test `pyre-font-every-theme` (16 checks; the build before fails them); the dialog checked in light and dark mode
  (screenshots: "(Theme)" fits every box).

## Branches of Pyre909/notepad-plus-plus

| Branch | Head | What |
|---|---|---|
| `master` | `37f76d4` | Mirror of official Notepad++ (kept in sync with GitHub's Sync fork; never add commits here) |
| `pyre` | `fcbbb30` | **Your own Notepad++ (the Pyre909 build)**: everything below, the build name in the About box, and the private release workflow (installers + portable zips, x64 and ARM64). The fork's default branch since 2026-10-01 |
| `claude/awesome-darwin-bsud9v` | `357fec9` | The cloud session's branch: the combined development branch, all the features (pyre is built on it) |
| `text-rendering_20260925` | `bb32194` | Upstream PR #18418, closed by donho on 2026-10-02: Text Rendering settings in Editing 1 |
| `text-rendering-translations_20260925` | `1aa8b0e` | Follow-up of #18418: label capitalisation in 29 translations (on hold: #18418 closed) |
| `live-rendering-switch_20260930` | `08cc23b` | Superseded by `live-rendering-switch_20261005` (this one was stacked on #18418) |
| `rtl-views-gdi_20261006` | `53d0026` | Right-to-left views drawn with GDI, the startup direction sync (bug fix: #17865, #17518, the RTL UI languages on DirectWrite), on upstream `master`: PR to open (kit section 6) |
| `live-rendering-switch_20261005` | `d50fb3b` | Rendering mode applied without restart (MISC. box), one commit on `rtl-views-gdi_20261006`: feature request to open, PR after it's Accepted and section 6 is merged (kit section 7). Its refusal version is kept as `archive/live-rendering-switch-refusal_20261005`, the fallback |
| `directwrite-font-smoothing_20261006` | `76b3210` | DirectWrite following the Windows font smoothing (bug fix: #14954), on upstream `master`: PR to open (kit section 8). CI: all 13 jobs pass (its ARM64 Debug job hung on GitHub's runner once, passed when re-run) |
| `directwrite-font-names_20260930` | `9f605be` | Fonts such as "Fira Code Light" drawn by DirectWrite (Notepad++-only change; a bug fix of #9951 and #12393, PR after the checks of kit section 5). Rewritten, rebased and force-pushed on 2026-10-06 (the first version was `6e8579e`) |
| `per-monitor-dpi_20260925` | `8a0ff70` | Opt-in per-monitor DPI awareness (discuss with maintainers before a PR) |
| `font-size-1pt_20260925` | `faaeb59` | Font sizes 1-4 pt: PR #18412 closed upstream (not wanted); kept in the fork |
| `font-weight-names_20260925` | `47341a4` | Superseded: the Scintilla version of the font-name fix |
| `scintilla-upstream_20260930` | | This branch: tools, kits, notes (no Notepad++ history) |
| `archive/wip-text-rendering-ui_20260925`, `archive/wip-per-monitor-dpi-review_20260925` | | Early work-in-progress snapshots, superseded (kept so nothing is lost) |
| `archive/live-rendering-switch-refusal_20261005` | `305ff13` | The live switch's first standalone version (pushed 2026-10-05 as `live-rendering-switch_20261005`): it refused DirectWrite while the documents shown were RTL. Replaced on 2026-10-06 by the RTL views drawn with GDI; the fallback for the live switch if `rtl-views-gdi_20261006` is turned down |

## Upstream Notepad++

- PR #18418 (text rendering): **closed by donho on 2026-10-02**, quoting Neil (no LLM-generated contributions; the
  100 setting combinations are overwhelming) and adding: "it's rather the large modification which could bring the
  regression. When the PR is accepted in Scintilla project, then we will check again." Issue #18414 stays open. The
  text rendering settings stay in the fork.
- Right-to-left views drawn with GDI (2026-10-06, kit section 6): upstream refuses RTL with DirectWrite (#8847, closed
  "scintilla dependent"; Ctrl+Alt+R then does nothing, #17865), and with an RTL UI language its editor is drawn
  left-to-right in a mirrored window by default (found on 8.9.8.1; a regression of #14374 since 2724e0d), and with
  `editZoneRTL="no"` it stays mirrored (#17518). A bug fix PR, 4 files: ready to open. CI: all 13 jobs pass
  (`53d0026`).
- The live switch (kit section 7), split from it on 2026-10-06 (one feature or bug fix per PR): the feature request
  first; the PR once it's Accepted and section 6 is merged. CI: all 13 jobs pass (`d50fb3b`, with section 6's commit).
- DirectWrite following the Windows font smoothing (2026-10-06, kit section 8): with DirectWrite, the default since 8.6,
  turning the Windows font smoothing off, or to Standard, changes nothing (#14954, open since 2024). A bug fix PR, 4
  files, no new setting, made from pyre's "Follow Windows" antialiasing: ready to open. Tested with the Windows setting
  off, Standard and ClearType (Pyre909 changed it) and live; CI: all 13 jobs pass (`76b3210`).
- Fonts of a weight under DirectWrite (kit section 5): upstream has the bug reports, #9951 (2021, open, 29 comments,
  labelled "scintilla dependent") and #12393 (2022), so it's a bug fix PR, no feature request to wait for. Rewritten and
  rebased on 2026-10-06 (`9f605be`, printing checked, CI: all 13 jobs pass). Ready to open; the optional comment on
  #9951 first.
- PR #18412 (font sizes 1-4 pt): closed, not wanted.
- Next PRs from the fork only when a feature looks worthwhile to upstream.

## Scintilla (SourceForge)

- **Survey (2026-10-01)**: `scintilla/MAINTAINER-SURVEY.md`. Our tickets were the only ones in 2017-2026 to
  mention AI; #1592's patch was larger than 258 of 264 patches and its description 8x the median. What works there:
  one small change, evidence on Windows reproducible in SciTE, few choices, DirectWrite-first, mailing list first
  for new features. Next: a short closing reply on #1592 in Pyre909's own words; #2520's fix left to them.

- The maintainer, on feature request #1592 (2026-09-30): "I am not currently accepting LLM-generated
  contributions." and the 100 setting combinations are "overwhelming". So no code from this work goes to Scintilla.
- #2519 (GDI weight family names): withdrawn; the mapping lives in Notepad++ now.
- #1592 (DirectWrite rendering parameters API): declined.
- #2520 (crash in FontDirectWrite::HFont with no text format): open; zufuliu suggested clamping weight and
  stretch in the E_INVALIDARG retry; our reply (with a clamp + guard patch as illustration) is posted. The guard is
  kept in the fork until a Scintilla release fixes it.
- Right-to-left with DirectWrite (2026-10-06): not reported, already asked twice. Feature request #1435 (2022, a
  Notepad++ user): mirroring (`WS_EX_LAYOUTRTL`) was never actively supported, "may have worked with GDI drawing but
  not DirectWrite". Bug #2233 (2021, ScintillaNET, open): `SC_BIDIRECTIONAL_R2L` was never finished; for a DirectWrite
  reading direction, patch your own copy. Fixed in Notepad++ instead (GDI for mirrored views, kit section 6).

## The Pyre909 build (releases)

- Workflow `.github/workflows/pyre-release.yml` on `pyre`: MSBuild x64 and ARM64 Release, then for each
  `.github/pyre/package.ps1 -Arch` (portable zip in the official layout) and `.github/pyre/installer.ps1 -Arch`
  (installer from the official `nppSetup.nsi`), with the plugins, updater and Explorer context menu of the
  official release of the same version and architecture. The result is a **draft** release with 8 files: only
  people with push access see it.
- Auto-update is off in all of them (disableNppAutoUpdate.xml), so the official updater can't replace the build;
  Plugins Admin still works. The installer replaces an official installation (same folder and settings) and is
  unsigned (SmartScreen: More info, Run anyway).
- Tested here: both scripts run for both architectures (PowerShell 7 + NSIS + 7-Zip on Linux), the portable build
  runs under Wine (Local Conf mode, plugins load, auto-update off, "(64-bit, Pyre909 build)" in About and Debug
  Info), and each installer holds the official installer's files of its architecture (every plugin, updater and
  NppShell binary of the ARM64 one is ARM64) with our exe.
- Releases: run 1 (`ea151ae`, x64 only) and run 2 (`aee7bbf`, x64 + ARM64) passed on 2026-10-01; draft
  `pyre-8.9.8.1-aee7bbf`. Pyre909's ARM64 installer from it installs and works on their Windows 11 ARM64 VM
  (Parallels on an Apple Silicon Mac): About shows "(ARM 64-bit, Pyre909 build)", the Explorer menu and Plugins
  Admin work, auto-update is off (no "Update Notepad++" in the ? menu). Uninstall not checked (it would remove the
  working install). The x64-only draft `pyre-8.9.8.1-ea151ae` is superseded.

## Next

1. Done: `pyre` is the default branch and the release workflow works (x64 + ARM64).
2. The test round on the VM (see the handoff above).
3. Keep `pyre` current: Sync fork on `master`, then merge `master` into `pyre` (`PYRE-BUILD.md` on `pyre` describes
   the build, its releases and updating).
4. Pyre909 opens the RTL fix PR (kit section 6), the font smoothing PR (kit section 8) and the live switch's feature
   request (kit section 7); the live switch PR follows once both allow it. Then the font-name PR (kit section 5, a bug
   fix of #9951 and #12393), which will need pyre's `refreshStyleFonts` once the technology can change at run time (the
   live switch, the RTL views).
5. Before pushing any branch: the review harness in `review/` (`review.ps1`, then the AI review of `checklist.md`;
   the skill `npp-review` does both). After pushing, check CI, which picks its jobs from the push's last commit alone
   (`git diff --name-only HEAD~1` in `CI_build.yml`): if it changes only `.md` or `.txt` files nothing is built, if
   only XML files just the XML check runs. So a push ending with a CLAUDE.md commit after code commits needs
   `[force all]` in that commit's title, as `CLAUDE.md` says (found on 2026-10-06 when `pyre`'s RTL commit wasn't
   built: see "Later").
6. Done on 2026-10-06 (`84dc7f8`, see the review above): `pyre`'s "Follow Windows" missed a change made in the
   ClearType Text Tuner (`SPI_SETFONTSMOOTHINGORIENTATION`); it now uses section 8's rule.
7. Merge upstream into `pyre`: 13 commits behind on 2026-10-06. A trial merge conflicts in `AboutDlg.cpp/.h` and
   `dpiManagerV2.cpp`: upstream added per-monitor DPI support to the About, hash and Shortcut Mapper dialogs, which
   overlaps pyre's own per-monitor DPI work; reconcile them (and the per-monitor DPI PR candidate) then.
8. Optional: check with screenshots whether the DirectWrite modes "Symmetric" and "Adaptive" differ visibly from
   "Automatic" at editor sizes (a reviewer's question); if not, fewer choices.
9. Later: the toolchain and the unused features below.

## Colour themes (2026-10-03, version 2)

`themes/`: Lucid Light and Lucid Dark, a pair of Notepad++ themes generated for all 93 lexers of
`stylers.model.xml`. Version 1 (2026-10-02) maximised each colour's contrast and looked off to Pyre909 (neon cyan
beside pastels in the dark theme, olive and brown in the light theme). Version 2 is designed for harmony: one
lightness for all syntax colours per theme, chroma held below the gamut edge, the same hue per role in both themes
(violet keywords, blue functions, teal types, green strings, orange numbers, magenta macros, red errors), no dark
yellow or brown. Floors: every style WCAG AA (4.5:1) for readers aged 32 and 70; text 14:1 (light) / 11:1 (dark).
Rendered in the Pyre909 build under Wine (C++, Python, HTML, diff; dark mode switches the theme). Not yet seen on
real Windows (ClearType/DirectWrite and Consolas). Install steps, the evidence and what matters beyond colour
(brightness, room light, breaks, glasses, font size, line spacing, rendering in the VM) are in `themes/README.md`.
Possible fork features: a line-spacing setting (Scintilla's extra ascent/descent); shipping the themes in the
Pyre909 zip and installer (`package.ps1`/`installer.ps1`). Neither done.

## Later: toolchain and unused features (noted 2026-10-01, not started)

Done on `pyre` (2026-10-06): the RTL views drawn with GDI replace the refusal of its live switch (which counted hidden
views and locked DirectWrite out with an RTL UI language) and its two messages; its style fonts are mapped again when a
view's technology changes (`refreshStyleFonts`, test `pyre-rtl-style-fonts`). The refusal port's tests are removed.
CI didn't build it at first: `e3f08a8` was pushed with a CLAUDE.md commit on top (`999c593`), and CI picks its jobs
from a push's last commit alone (Next, item 5). `76552d9` (CLAUDE.md again, `[force all]` in its title) built the whole
tree: all 13 jobs pass (run 37432491225).

Toolchain:

- Done on 2026-10-06, the VM cleanup Pyre909 chose: removed Visual Studio 2022 Build Tools and Windows SDK 10.0.26100
  (the builds use VS 2026, toolset v145), the VS download cache (3 GB to 0.06 GB, the update ran with `--nocache`),
  LLVM, Rust, the .NET 10 SDK and the NuGet caches, Python 3.11, PIX, the Teams add-in for Office, 17 preinstalled
  Store apps (Xbox, News, Weather, Bing Search, Solitaire, Clipchamp, Outlook, Teams, To Do, Office hub, Phone Link,
  Cross-device, Dev Home, Feedback Hub) and 9.8 GB of build outputs. Updated: VS Build Tools 2026 18.7.2 to 18.10.2
  (through winget: the installer's own `update` found none), Git 2.55.0.5, 7-Zip 26.04, the ARM64 VC++ runtime, .NET 8
  Desktop Runtime 8.0.31, Python 3.14.7 and its launcher, Windows Terminal (winget has no ARM64 Zed update: Zed updates
  itself). Free space 53 GB to 59 GB; about 20 GB more stay in the restore points made during the installs until
  Pyre909 cleans them up (Disk Cleanup, System Restore and Shadow Copies). Kept: Neovim, Zed, Chrome, Python 3.14, the
  Japanese, Korean and Chinese language packs. Then `setup-vm.ps1` installs VS 2026 instead of 2022 (`pyre`
  `328f690`: the Build Tools with the ARM64 compiler, `--nocache`), and the clone's `out/` (113 MB of local release
  packages from 2026-10-01) is deleted. Rebuilt with 18.10.2 the same day: the three PR branches and `pyre` build
  without warnings (ARM64, x64, Win32) and pass their app-level tests.
- `pyre-release.yml`: `actions/checkout` v6 -> v7 (read its release notes first). `CI_build.yml` is upstream's: leave
  it to upstream (merge conflicts).
- `installer.ps1` calls `makensis` and `7z` by name, and neither is on the VM's PATH: `setup-vm.ps1` should put NSIS
  and 7-Zip on the user PATH (as it does for Claude Code). Its default worktree list also names older branches
  (`live-rendering-switch_20260930` and not the three PR branches of 2026-10-06).
- `vm/measure.ps1` measures the first Notepad++ window `FindWindow` returns, which can be Pyre909's everyday one. Add
  a launcher that creates `C:\npp-fonttest`, copies `weights.cpp` (a stale copy cost a round on 2026-10-01) and starts
  the test copy with `-titleAdd=FONTTEST`, and make `measure.ps1` match that title.
- Scripted settings: Preferences and the Style Configurator stay loaded once opened, so a script can set a combo box
  and send the dialog the notification a click sends. The Antialiasing / DirectWrite mode check (about 10 settings)
  then runs as one command, with a screenshot each.
- ARM64 in CI: the fork is public, so GitHub's Windows ARM64 runners are free: build ARM64 natively and run the font
  measurements on each release.

Scintilla features Notepad++ never calls (`git grep` in `PowerEditor/src`), all in this work's area. They are
Notepad++ changes using existing Scintilla calls, so Scintilla's no-LLM rule doesn't apply:

- `SCI_SETLAYOUTTHREADS`: lays out long lines and wrapped text on several cores; DirectWrite only (Scintilla's docs:
  4 cores often bring it to just over a quarter of the time). Likely the biggest win.
- `SCI_SETBUFFEREDDRAW(0)`: Scintilla's docs say Win32 clients should turn buffering off at initialisation.
- `SCI_SETPHASESDRAW(SC_PHASES_MULTIPLE)`: tall accents and deep descenders aren't clipped at the line edges. Needs
  buffering off; slower.
- `SCI_SETFONTLOCALE`: the locale DirectWrite uses for language-specific glyphs (Simplified vs Traditional Chinese,
  Japanese forms); Notepad++ leaves "en-us".
- `SCI_SETBIDIRECTIONAL`: experimental Arabic/Hebrew inside left-to-right UTF-8 documents, DirectWrite only. Tried
  on the VM (2026-10-06): the caret lands right in mixed Hebrew/English, but lines stay left-aligned, the opaque
  selection is drawn at the logical place (needs `SCI_SETSELECTIONLAYER` under or over the text), and `R2L` does
  nothing more than `L2R` (never finished). Not a replacement for Notepad++'s RTL; bigger and riskier.

Notepad++ options for tests: `-titleAdd=`, `-noPlugin` (clean comparisons), `-loadingTime` (startup time: GDI vs
DirectWrite, the fork vs official); ? > Debug Info for upstream issues (the bug form asks for it).

Suggested first: the launcher and scripted settings (every remaining test gets faster); then `SCI_SETLAYOUTTHREADS`
with buffering off on `pyre`, measured before and after.

## Parked: how the fork's code is laid out (2026-10-02)

Question: put all the fork's changes in one separate file? No: one module per feature behind a small interface,
with one-line hooks in the official files (`FontFamilyNames.cpp` is the model). One file would still need the
hooks everywhere, would tie unrelated features together, and nothing in it could go upstream on its own.

Merge risk of `pyre` against official `master`, measured over 818 official commits (2025-04 to 2026-09); risk =
change blocks in the file x official commits to that file:

| Part | Files | Changed lines | Blocks | Risk |
|---|---|---|---|---|
| Notepad++ code | 68 | 2,973 (438 in new files) | 323 | 7,229 |
| Translations | 31 | 561 | 99 | 2,197 |
| Scintilla | 6 | 449 | 57 | 280 |
| Installer | 4 | 8 | 5 | 15 |

Top files: `Parameters.cpp` (12 blocks x 113 commits), `ScintillaEditView.cpp` (23 x 47), `Notepad_plus.cpp`
(15 x 64), `preferenceDlg.cpp` (12 x 45), `english.xml` (7 x 59). Scintilla is low risk (`ScintillaWin.cxx`: 8
official commits in 18 months).

When it's picked up, in order of payoff: (1) get features merged upstream, then `pyre` takes the official
version (don't restructure features whose PRs are open); (2) the fork-only rendering settings (DirectWrite mode,
contrast) into one module, e.g. `ScintillaComponent/TextRendering.cpp/.h` (settings, config.xml read/write, apply),
leaving one call each in `Parameters.cpp`, `ScintillaEditView.cpp`, `preferenceDlg.cpp`; the `.rc` layout and
`english.xml` strings stay where they are; (3) drop the 29 translation edits from `pyre` (cosmetic, second-largest
risk) or keep them only until the translations PR is merged; (4) shrink the Scintilla patch after the VM
measurement before moving it; (5) habits: merge `master` into `pyre` often, `git config rerere.enabled true`,
mark every hook `// Pyre909 build`, keep `CLAUDE.md`'s code table as the index. Step 2 needs a Windows build (VM).
