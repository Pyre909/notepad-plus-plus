# Status (2026-10-19)

Where the Notepad++ text rendering, DPI and font work stands: branches, upstream PRs and tickets, the Pyre909
build, and what's next. A Claude Code session starts with `CLAUDE.md` on `pyre` (rules, build, code map). The PR kit with every issue/PR/ticket text is `split/PR-TEXTS.md`; the Scintilla side is
`scintilla/SCINTILLA-UPSTREAM.md`, and how Scintilla's maintainer decides (a survey of 792 tickets, compared with
ours) is `scintilla/MAINTAINER-SURVEY.md`; the tools are described in `README.md`.

## Handoff (2026-10-19): read this first

This file is long: read it by section (grep the headings), not whole. One session per phase: start a fresh Claude Code
session from `CLAUDE.md` and this block, and run `/compact` with a keep-note before a break of an hour or more.

- `pyre` pushed on 2026-10-19 (`cff6c08`): the speed, glyph and Text Rendering work of that day (`a52ca6a`, section
  "Speed, glyphs and Text Rendering options" below; Pyre909 CI: all 13 jobs pass, run 39352072234) and four
  Style Configurator bug fixes (`a913d55`..`cff6c08`, section "Style Configurator" below), on top of `b0ae0e6` (pushed
  2026-10-16: upstream merged up to `a660d79`, the PR reviews' improvements). Run Pyre909 CI on `cff6c08`
  (`gh workflow run pyre-ci.yml --ref pyre -f ref=pyre`). No release built since: Pyre909 said "Don't build for now"
  (2026-10-16); then Actions > Pyre909 release.
- CI is manual since 2026-10-16 (workflow **Pyre909 CI**, `pyre-ci.yml`, generated from upstream's `CI_build.yml` by
  `.github/pyre/make-ci.ps1`); upstream's `CI_build` and `release-notifier` are disabled on the fork. Actions works
  again (the refusals of 2026-10-15 are over): the four PR branches passed all 13 jobs on 2026-10-16.
- Upstream: **PR #18503** (the RTL fix, `rtl-views-gdi_20261006` `9fdd356`) open since 2026-10-16, no review yet,
  upstream's CI waiting for a maintainer's approval; new commits only from now on. Waiting on Pyre909: the font
  smoothing PR (kit 8, ready), the live switch's feature request (kit 7; its PR after #18503 is merged), a comment on
  #9951 then the font-name PR (kit 5). Whichever of #18503 and the font-name PR is merged second calls
  `setStyleFontsFor` after a technology switch (kit 5, item 6). #16110 (icons): no maintainer reply.
- New upstream candidates (2026-10-19, small, each with an open issue): Replace All with the views' redraw off
  (#10301: `ScintillaEditView::RedrawOff`), the font locale (#15265), multiple phases (#12446, #16259, needs the page
  cache). The page cache itself (#5267) needs the Scintilla fix of its stale layouts (`Editor.cxx`, tab stops and
  representations): never as our code there (Scintilla's LLM policy); a bug report from Pyre909 is fine (draft below).
- The VM's display is at 175% (Notepad++'s windows report 168 DPI): a DPI-unaware script reads 96.
- Memory checks: `review/asan.ps1 -Ref <branch>` (AddressSanitizer) and `leaks.ps1` with UMDH (heap growth with
  stacks; the stack recording is on for the test build paths only, `review/umdh-scope.ps1`, which also makes those
  paths slower: time copies of the builds in plain folders). Debugging Tools installed, symbols in `C:\symbols`.
- Reviews: `review.ps1 -Quiet`, then the AI review (skill `npp-review`). After a change of a class layout in a header
  (a member added), rebuild clean: the harness builds incrementally (5 false failures on 2026-10-15).

## Style Configurator (2026-10-19)

Asked by Pyre909: "can we improve the style configurator somehow". Three research agents (upstream issues and forum,
the code, other editors), then "fix those bugs".
- **Fixed in pyre** (upstream bugs, each its own commit, each a possible small upstream PR with an issue first):
  `a913d55` a theme of the installation saved with Save & Close (written as the user's copy) came back unsaved when
  selected again in the same session (the theme list kept the installation's path; the next save overwrote the copy):
  `ThemeSwitcher::setThemePath` from `writeStyles`. `8c51a77` a dark mode switch picked its theme by a prefix
  (`CB_FINDSTRING`: "Solarized-light" for "Solarized"), a style's font too. `4f783af` an emptied font name wasn't
  saved (upstream #13919). `840214b` each key typed in the user keywords box restyled the views (14.6 ms a key with
  100,000 C++ lines; 2.7 ms now, one restyle 300 ms after the last key; upstream #16143 reports a visible redraw).
  Test `review/tests/pyre-style-configurator.ps1` (8 checks; 3 fail on `a52ca6a`).
- **Wanted upstream, not refused** (issue, signal): fold-line and hidden-lines colours as Global Styles (#12751,
  #10313, #12110), a visible "transparent" (inherit) check box instead of the right-click (#18057, #5620), Ctrl+A in
  the keyword boxes (#16131, a PR invited), the colour popup's slots shifted not overwritten (#9813), the popup opening
  with the previous style's colour (#11996), the dialog not coming to the front when reopened (#11811), the font list
  refreshed without a restart (#17923), a theme reset (#17824). New styles need stylers.model.xml, DarkModeDefault and
  every theme updated and `modelDate` bumped (#18501).
- **Refused upstream** (don't propose): typing in the font name or size combos (#16374, PRs #16710, #16470), font
  sizes 1-4 (#18412, ours), folding Global override into Default Style (#15640: Global override moved last instead),
  translating Global Styles names (#15514), recolouring shipped themes (#14721, #11842).
- **Ideas** (code read + other editors; not started): the style at the caret selected in the dialog (JetBrains' "Jump
  to Colors and Fonts", VS Code's token inspector; use `SCI_GETSTYLEINDEXAT`, not `SCI_GETSTYLEAT` (negative above
  127); HTML-family lexers split by ID range), a banner on every style while Global override forces something (the
  forum's top confusion), the inherited value shown for a blank font or size ("(Default: Consolas)"), keyboard access
  to the colour pickers (no tab stop, announced as "F"), a hex field and recent colours in the colour popup, a search
  box over languages and styles, reset/mark modified styles against the shipped theme, a contrast ratio readout, a
  sample swatch in the empty right half. Smaller: the fork's second font list filled lazily (+70 ms on the first open:
  252 vs 185 ms), Save & Close writing the theme when only "For every theme" changed (pyre), the row's "(Theme)",
  "Always", "Never" not localizable (pyre), `destroy()` resetting the wrong picker, a duplicate swatch, theme font sizes
  over 28 shown blank.

## Speed, glyphs and Text Rendering options (2026-10-19)

Asked by Pyre909: "Is there anything we can do to improve font rendering and quality? Also anything to improve the
GUI? What about performance? Anything is on the table", then measure the layout cache and threads, check the
SourceForge tickets ("a mention about GDI being deprecated"), add what helps even if only in the fork, and the
ligature and line spacing options.
- **GDI**: Neil Hodgson on #2519 (2026-09-30): DirectWrite is the default to think of, GDI a legacy API, "Eventually
  GDI will be deprecated" (no timeline; nothing is deprecated in the docs or the API, GDI is still Scintilla's
  default). Since 2024 DirectWrite is "the focus of development effort" (scintilla-interest). Scintilla 5.6.7 and
  Lexilla 5.5.4 are out (2026-09-28: positions as floats, -40% layout memory on wide lines): upstream PR #18428 brings
  them; Scintilla's unreleased `fa2ab2` fixes #2520, then pyre's crash guard goes.
- **Measured** (`vm/layout-perf.ps1`, `vm/replace-perf.ps1`; 6 cores, Courier New and Segoe UI; builds alternated,
  the VM's speed drifts; medians). Page layout cache, 20 lines of 250 KB: repaint 41 -> 21 ms (monospaced) and 629 ->
  21 ms (proportional), caret move 40 -> 17 and 621 -> 17 ms, typing 60 -> 43 and 557 -> 109 ms; the document cache
  took 1.26 GB after wrapping 1,000,000 lines (rejected). Layout threads: word wrap of 1,000,000 lines 850 -> 350 ms
  and 13.3 -> 7.1 s, but long monospaced lines got slower (relayout 82 -> 197 ms): every segment taken through one
  atomic counter, neighbours' positions sharing cache lines; taken in blocks (Scintilla local patch), 72 ms. Replace
  All adding a line per match to 1,000,000 lines: 169 s -> 3.3 s with the redraw off; without lines added, 2.5 s as
  before. Multiple phases: no cost on caret moves, typing and scrolling (all at the 60 Hz floor); a full relayout of 20
  lines of 250 KB 69 -> 123 ms.
- **pyre**: `ca75fc6` page cache and threads (the blocks patch), `16c04fe` Replace All and line removals with the
  redraw off, `a40cf72` the user's locale for DirectWrite fonts, multiple phases, the Document Map's tabs, `25738ce`
  Preferences > Editing 1 > Text Rendering: Line spacing (+1 to +10 px at 100%, the edit views only, again after a DPI
  change) and Font ligatures (Scintilla local patch: `SC_FONTRENDERING_LIGATURES`, a FontQuality bit, an
  `IDWriteTypography` with liga, clig and calt off on every layout), `5c23f33` as reviewed, `a52ca6a` docs. Note: the
  ligatures were never missing: DirectWrite draws them within a style run (an earlier answer said otherwise).
- **Review** (`npp-review`, two independent reviewers). Fixed: kept layouts not laid out again after a tab stop or
  representation change (ElasticTabstops; Scintilla local patch in `Editor.cxx`); the page cache's memory (10 bytes
  per character per kept line) on every view: now the edit views only, and not for a large file; blocks sized for
  every thread (a line of a few long segments); `RedrawOff` over every shown view of the document (cloned: 41 s ->
  8 s for 200,000 lines; also Cut Bookmarked Lines, Remove Consecutive Duplicate Lines); at most 8 layout threads; a
  plugin's extra ascent kept at Normal spacing; the locale's sort suffix; the Peeker's tabs; the Line spacing items
  translatable. Rejected: page-slot collisions of folded lines repeating per phase (rare, a paint-loop patch), the
  GDI views restyled on a ligature toggle (once). Undo of a big Replace All was already fast (Scintilla defers
  multi-step undo's scroll bars).
- **Tests**: new `pyre-text-options` (16) and `pyre-layout-cache` (12: 4 of them fail on the build before the review);
  `leaks.ps1` gets a ligatures and spacing operation (flat over 1000); the 13 older sets pass.
- **Not done**: fold markers and indicators at high DPI (1 px strokes, thin at 175%: `SCI_MARKERSETSTROKEWIDTH`),
  fractional font sizes (#12364), the experimental bidirectional mode for mixed RTL text in LTR views (Neil: a user
  option, it costs speed). `harness/src/nppdrive.cpp` (the Wine-era driver) reads the overrides with message 5002,
  `SC_WORK_IDLE` since the move to 5101/5102: fix it if that driver is used again.
- **Scintilla bug report draft** (casual, for Pyre909 to edit and post if wanted; a report, no patch):
  > Hi! Ran into this while trying SC_CACHE_PAGE in Notepad++: kept line layouts (SC_CACHE_PAGE or SC_CACHE_DOCUMENT) aren't laid out again after SCI_ADDTABSTOP /
  > SCI_CLEARTABSTOPS or after a representation change (SCI_SETREPRESENTATION, SCI_CLEARREPRESENTATION,
  > SCI_CLEARALLREPRESENTATIONS, SCI_SETREPRESENTATIONAPPEARANCE). ChangeTabStops only redraws, and a kept layout is
  > only checked against the text and styles, so a shown line keeps its old tab positions and representation widths
  > until it's restyled. With the default SC_CACHE_CARET it hardly shows (one slot, reused by every line). Repro:
  > SC_CACHE_PAGE, lines "a\tb", SCI_ADDTABSTOP(line, 200) on a shown line, then SCI_POINTXFROMPOSITION of "b": the old
  > x. Invalidating the layout cache there fixed it in my build.

## PR review round and upstream merge (2026-10-15/16)

Asked by Pyre909: every planned PR checked for quality, one at a time, "true to the maintainers' standards", then
refactored for fewer lines with what C++ and Notepad++ already offer, then tested for leaks.
- RTL fix: the view now gets back the technology it had (`_technologyIfLTR`), not the live setting: a rendering mode
  picked in Preferences reached that view before the restart its tip asks for, and a plugin's technology was replaced
  (new check in `rtl-views-gdi`, 17). Rejected: removing `RTLvsDirectWrite` from the other languages (upstream's usual
  way leaves it to translators, 6 of 8 removals).
- Font smoothing: the `WM_SETTINGCHANGE` handler re-applies without a second comparison (Scintilla restyles on every
  `WM_SETTINGCHANGE`), `getWindowsFontQuality` folded into `applyWindowsFontQuality`, a short commit message. Tested
  with the Windows font smoothing ClearType and off.
- Live switch: an RTL view's remembered technology follows a switch (new check in `live-rendering-switch`, 41).
- Font names: rewritten (see kit 5): no GDI family enumeration (`FW_DONTCARE` gives the same font as before for all 228
  families of the VM, checked by a throwaway program), no new files, upstream's lines of
  `setSpecialStyle` untouched, one `setStyleFontsFor(technology)` for printing and technology switches. Fixed: a family
  name of 32+ characters (Scintilla throws copying it), a style moving from a remapped font to a usual one. Print
  check (2026-10-16, `vm/print-pdf.ps1`, Pyre909's OK): the PDF embeds Segoe UI Light, weight 300; afterwards the
  styles are "Segoe UI" 300 / 600 again.
- Leaks (`leaks.ps1`, 300 repetitions; 2000 on `pyre`): tab switches restyling with a font of a weight, Windows setting
  changes, RTL and back, the rendering mode through every mode: GDI, USER, handles flat. A few GDI objects in the first
  few hundred tab switches are caches filling (flat over 2000), so the warm-up is 50.
- Upstream merge into `pyre` (`6033da5`): `WordStyleDlg.rc` (upstream's label alignment applied at pyre's positions,
  the font row's labels too), `DockingManager.cpp` (upstream's bounds checks, pyre's `setFloatingRect`),
  `StaticDialog.h` (both includes), `StatusBar.cpp` (upstream moved the subclass state into `StatusBar` and handles
  `WM_DPICHANGED` itself; pyre keeps one branch: the main status bar gets the new font, for its height under
  per-monitor DPI), `dpiManagerV2.cpp` (both sides' functions, upstream's `getDefaultGUIFontForDpi(UINT dpi, WORD ...)`).
  Upstream's own per-monitor work (Find dialog) was disabled again by them for a status bar regression (#18462).
  `pyre` keeps its larger font-name code (its GDI block), with the length fix.

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
| With DirectWrite, each Antialiasing choice and DirectWrite mode changes the text at once | **pass** (2026-10-06, `pyre` `3a2c596` ARM64, 150%): test `pyre-text-rendering-live` (30 checks): each choice reaches both views at once and redraws the text |
| Default Style "Bahnschrift Light": Light text, SemiBold bold keywords, about the same ink in GDI and DirectWrite | **pass**: with DirectWrite the styles get weight 300 (text) and 600 (keywords) (`SCI_STYLEGETWEIGHT`); ink per line within 2.4% of GDI, width within 3 px; bold lines about 1.26x the regular lines' ink per letter in both (readings below) |
| "Cascadia Code SemiBold": bold keywords draw Bold | **pass** (2026-10-06, see `CLAUDE.md`): DirectWrite draws them with Cascadia Code Bold, not a simulated bold |
| Baseline: the font tests with the official 8.9.8.1 ARM64 portable (expect DirectWrite to draw a fallback or wrong weight) | **as expected** (2026-10-06), with upstream `master` `a69bc23` built for ARM64 instead of the official download: DirectWrite gets "Bahnschrift Light" at weight 400 / 700 (test `directwrite-font-names`: 4 FAIL) and draws a fallback font (Segoe UI-like): line height 28 px instead of 25, other widths, 5% to 24% more ink (readings below, `vm/shots/baseline-pyre-vs-upstream.png`) |
| Per-monitor DPI (MISC. option, restart; then change Windows' scale while Notepad++ runs, or two displays) | to do: needs Pyre909 (a system setting or a second display) |
| Uninstall removes `disableNppAutoUpdate.xml` | skipped: it would remove the working install |

Note: a fresh settings folder starts in DirectWrite (technology 1) in this build, not GDI.

Bahnschrift Light readings, Default Style at 10 pt in `C:\npp-fonttest` (tools and procedure in `vm/README.md`; all
readings in `vm/results.csv`, screenshots in `vm/shots/`; ink = darkness / 1000, width in px):

| Line of `vm/weights.cpp` | GDI ink / width | DirectWrite ink / width | upstream `a69bc23` DirectWrite (fallback font) |
|---|---|---|---|
| 1, bold keywords | 350.2 / 277 | 343.4 / 276 | 384.4 / 283 |
| 2, regular identifiers | 286.1 / 273 | 279.3 / 270 | 293.9 / 265 |
| 3, bold keywords | 274.8 / 219 | 269.4 / 217 | 334.1 / 232 |
| 4, regular identifiers | 240.3 / 219 | 236.1 / 218 | 257.5 / 219 |

Line height: 24 px in GDI, 25 px in DirectWrite, 28 px for upstream's fallback (pyre `3a2c596` measured again on
2026-10-06: the same numbers, `pyre-3a2c596-bahnschrift-light-dw`). The same font set through Global override ("Enable global font")
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

## Upstream merge (2026-10-06)

`master` synced with upstream (`gh repo sync`, 13 commits up to `a69bc23`), merged into `pyre` as `ba729ad`, plus a fix
`7eba8f3` (CI run 37574517585: all 13 jobs pass).

- Conflicts: `AboutDlg.cpp/.h`, where upstream's `CmdLineArgsDlg::setFont` / `destroyFont` (per-monitor DPI, dialog
  font size) replace pyre's `setEditFont` (same job), so AboutDlg now differs from upstream only by `PYRE_BUILD_TAG` and
  the text rendering debug info; and `dpiManagerV2.cpp`, where both sides' new functions are kept (pyre's
  `getIconTitleFontForDpi` / `replaceWindowFont` serve its panels).
- Found by the AI review, not by git: upstream's `e083cef9f` dropped `WM_DPICHANGED_AFTERPARENT` from the status bar
  subclass (it was unused upstream). Pyre's per-monitor main window relied on it, so after a DPI change the status bar
  kept its old font and height. Fixed in `7eba8f3`: pyre's `WM_DPICHANGED` handler in `NppBigSwitch.cpp` sends it
  `WM_DPICHANGED`, as upstream does for the Find dialog's status bar.
- Harness: clean ARM64 rebuild; `review.ps1 -Build ARM64,x64,Win32 -Test All`: 0 FAIL, 23 PASS. The 4 WARNs are all in
  upstream's own code (Find in Files, Buffer, Find dialog, UDL), left as they are.
- Review findings not acted on:
  - Upstream now creates the About, hash and Shortcut Mapper dialogs per-monitor aware even with pyre's option off,
    and pyre's `getSystemMetricsForWindow` follows the global flag. So in those dialogs, with the option off, it gives
    system-DPI metrics, same as upstream. A candidate fix: base it on the window's DPI awareness.
  - Pyre's `getDialogBaseUnits` (`StaticDialog.cpp`) duplicates upstream's new `DPIManagerV2::getFontAvgAlphaWidth`;
    it could use it.
  - Upstream as-is items: font deleted before its replacement in the new `setFont`s, and the font-size statics in
    Find, TabBar and TaskList.
- To check on Windows with two monitors at different scales (per-monitor DPI on, then off): the main window's status bar
  across monitors; About, Debug info, Command line args, MD5/SHA and Shortcut Mapper dragged across (fonts, grid
  scrollbar); the Find dialog (minimum size, status bar); the dialog font size (Preferences > MISC.) 8 / 12 / 24 with
  the Find bar and docked UDL.

## Standard toolbar icons redrawn (2026-10-07)

Issue #16110 (open, a feature request): the "Standard icons" toolbar set is 32 16x16 bitmaps, stretched and jagged
above 100%. They were redrawn as flat vector art, with an SVG per pixel grid (16, 20, 24, 32; 40 and 48 are the 20 and 24
grids doubled) and an ICO per icon (PNG-compressed 16 to 48 px) plus a greyed `_dis.ico`: 140 KB for 64 ICOs.
The generator, the scripts and the review sheets of both versions are in `icons/standard-hidpi/v1` (gradients) and
`v2` (flat, final), each with a README (design rules, how to rebuild).

- `standard-icons-hidpi_20261007` (`bc2e60f`, on upstream `master`, pushed): the icons alone, no code. Pyre909's
  comment on #16110 (2026-10-07, with two pictures) offers them and leaves how to use them to the maintainers; it
  mentions the toolbar code without a PR.
- `pyre`: `4a86f5e` (the same icons) and `5d5cf9b` (the toolbar takes them at every scale through image lists, like the
  Fluent icons; the 32 bitmaps and their code path removed; a plugin's button shows its toolbar bitmap, opaque, sized
  to the icons; disabled plugin buttons aren't greyed, as with the Fluent icons). The exe grows by about 100 KB
  (+142.6 KB of ICOs, -38.5 KB of bitmaps). Not tested: a plugin that adds toolbar buttons (the bundled plugins add
  none).
- Local only: `standard-icons-hidpi-preview_20261007` (`90bedb0`, the preview build with the bitmaps kept as a
  fallback), superseded by `pyre`. Tags (local): `icons-hidpi-v1`, `icons-hidpi-v1-preview`, `icons-hidpi-v2`,
  `icons-hidpi-v2-preview`.

## Branches of Pyre909/notepad-plus-plus

| Branch | Head | What |
|---|---|---|
| `master` | `37f76d4` | Mirror of official Notepad++ (kept in sync with GitHub's Sync fork; never add commits here) |
| `pyre` | `5771464` | **Your own Notepad++ (the Pyre909 build)**: everything below, the build name in the About box, and the private release workflow (installers + portable zips, x64 and ARM64). The fork's default branch since 2026-10-01 |
| `claude/awesome-darwin-bsud9v` | `357fec9` | The cloud session's branch: the combined development branch, all the features (pyre is built on it) |
| `text-rendering_20260925` | `bb32194` | Upstream PR #18418, closed by donho on 2026-10-02: Text Rendering settings in Editing 1 |
| `text-rendering-translations_20260925` | `1aa8b0e` | Follow-up of #18418: label capitalisation in 29 translations (on hold: #18418 closed) |
| `live-rendering-switch_20260930` | `08cc23b` | Superseded by `live-rendering-switch_20261005` (this one was stacked on #18418) |
| `rtl-views-gdi_20261006` | `53d0026` | Right-to-left views drawn with GDI, the startup direction sync (bug fix: #17865, #17518, the RTL UI languages on DirectWrite), on upstream `master`: PR to open (kit section 6) |
| `live-rendering-switch_20261005` | `d50fb3b` | Rendering mode applied without restart (MISC. box), one commit on `rtl-views-gdi_20261006`: feature request to open, PR after it's Accepted and section 6 is merged (kit section 7). Its refusal version is kept as `archive/live-rendering-switch-refusal_20261005`, the fallback |
| `directwrite-font-smoothing_20261006` | `76b3210` | DirectWrite following the Windows font smoothing (bug fix: #14954), on upstream `master`: PR to open (kit section 8). CI: all 13 jobs pass (its ARM64 Debug job hung on GitHub's runner once, passed when re-run) |
| `directwrite-font-names_20260930` | `9f605be` | Fonts such as "Fira Code Light" drawn by DirectWrite (Notepad++-only change; a bug fix of #9951 and #12393, PR after the checks of kit section 5). Rewritten, rebased and force-pushed on 2026-10-06 (the first version was `6e8579e`) |
| `standard-icons-hidpi_20261007` | `bc2e60f` | The redrawn standard toolbar icons alone (ICOs and SVGs, no code), on upstream `master`: offered on #16110 (a comment, no PR) |
| `per-monitor-dpi_20260925` | `8a455e0` | Opt-in per-monitor DPI awareness (discuss with maintainers before a PR) |
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
- Release `pyre-8.9.8.1-5771464` (run 37723373098, 2026-10-07): **published** (public, Latest) at Pyre909's request,
  with notes on the unofficial build, the new icons and SmartScreen (unsigned: More info, Run anyway; Unblock the
  zip). Publishing creates the tag `pyre-*`, whose push starts the workflow and CI again on the same commit: both
  runs were cancelled. To avoid it, the workflow could skip a tag that already has a release (not done). Its ARM64
  installer is installed on the VM (silent install, exit 0; the standard toolbar at 150% shows the new icons, greyed
  when disabled). The drafts `aee7bbf` and `ea151ae` are still there.

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
7. Done on 2026-10-06: upstream merged into `pyre` (`ba729ad`, `7eba8f3`; see "Upstream merge (2026-10-06)"). The
   per-monitor DPI PR candidate (`per-monitor-dpi_20260925`) was reconciled on 2026-10-07 (`8a455e0`, kit section 4,
   with a comment for #14959).
8. Done on 2026-10-06 (a reviewer's question: do the DirectWrite modes "Symmetric" and "Adaptive" differ visibly from
   "Automatic" at editor sizes?). `vm/modes.ps1` on the ARM64 build of `pyre` `7eba8f3`, VM at 150% (144 DPI),
   ClearType on: Consolas, Cascadia Mono, Courier New, Segoe UI at 9, 10, 12, 14 pt, ClearType and grayscale, each
   mode's screenshot diffed against Automatic (`vm/modes.csv`, `vm/shots/rendering-modes-zoom.png`).
   - Adaptive is never a rendering of its own: pixel-identical to Natural at 9 and 10 pt (up to 20 px) and to Automatic
     at 12 and 14 pt in all 32 cases. At 100% every usual editor size is under 20 px, so there it is Natural.
   - Symmetric equals Automatic at 12 and 14 pt for every font, and for Cascadia Mono at every size. It differs where
     Automatic draws natural (the font's gasp table at small sizes): Consolas, Courier New and Segoe UI at 9 pt,
     Courier New at 10 pt (10,000 to 16,000 pixels of a 700 x 260 crop). Visible enlarged: natural snaps horizontal
     strokes crisper, symmetric is softer and lighter.
   - Pyre909 chose to drop Adaptive and keep Symmetric (the only way to get the symmetric smoothing for those fonts at
     small sizes). Not measured: 100% scaling, other fonts.
   - Done in `pyre` `3a2c596`: Adaptive left the enum, the combo and its tooltip (english.xml, english_customizable.xml),
     Debug Info, and the Scintilla patch (its small-text rendering parameters variant; 100 is no longer a valid
     `SC_FONTRENDERING_RENDERINGMODE`). config.xml's `fontRenderingMode="4"` is read as Natural: the same text for 10 pt
     up to 150% DPI, while at 175% and more Adaptive drew it as Automatic. Test `pyre-text-rendering-config` checks it
     (fails on `7eba8f3`). AI review: nothing blocking. The old Wine harness (`harness/src/scitest.cpp`) still expects
     100; it's unused and already used other message numbers.
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
