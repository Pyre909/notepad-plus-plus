# Status (2026-11-01)

Where the Notepad++ text rendering, DPI and font work stands: branches, upstream PRs and tickets, the Pyre909
build, and what's next. A Claude Code session starts with `CLAUDE.md` on `pyre` (rules, build, code map). The PR kit with every issue/PR/ticket text is `split/PR-TEXTS.md`; the Scintilla side is
`scintilla/SCINTILLA-UPSTREAM.md`, and how Scintilla's maintainer decides (a survey of 792 tickets, compared with
ours) is `scintilla/MAINTAINER-SURVEY.md`; the tools are described in `README.md`.

## Handoff (2026-11-01): read this first

This file is long: read it by section (grep the headings), not whole. One session per phase: start a fresh Claude Code
session from `CLAUDE.md` and this block, and run `/compact` with a keep-note before a break of an hour or more.

- **The review round (2026-10-20, evening)**, asked by Pyre909: sync with upstream (the fork's `master` brought to
  `b661c2b` with `gh repo sync`; `pyre` had it), a preview (`C:\npp-preview-49de091`, a portable copy of the installation
  with a copy of their settings), then: are the older PRs as good as they can be, can their restarts go, what does upstream
  do for per-monitor DPI and why, the best APIs. Four read-only reviews (DPI research, the small PRs, the large PRs, an API
  audit with measurements), their findings checked against the code before use.
  - Answers. Upstream builds C++20: PR code stays within it (C++23 is `pyre`'s). Upstream keeps the main window, panels and
    plugins system aware (manifest) and switches dialogs to per-monitor v2 one at a time (Preferences, Style Configurator,
    About...); the Find dialog's switch was backed out after #18462 (a black status bar on scale changes); the panels are
    #14959's open part, which our branch does; their reasons: small reversible steps, custom controls (donho reverted a
    full per-monitor attempt in 2021), plugins. The per-monitor restart can't go (a window's DPI awareness is fixed at
    creation, plugins hold the main window's and the views' handles, mixed hosting only hosts system-aware children in a
    per-monitor parent): a "relaunch" prompt instead. Plugins, to prototype in `pyre`: their own dialogs are scaled by
    Windows in per-monitor v2; docked plugin panels through `DialogDpiLayout` (with an opt-out); an NPPN for DPI changes.
    APIs: rendering, file I/O and XML already the right ones; the gains are algorithms (below).
  - `pyre` (CI 13/13, run 39490875390; harness 0 FAIL 0 WARN), on top of `49de091`: `4d4b96b` Function List caret
    tracking (a binary search; its range cache never hit: 374 -> 16.6 ms a caret move on 60,000 lines with 18,001
    functions; the same entry marked on every line of two test files, sorted and not); `9f3a9c0` + `68c7fdd`
    auto-completion: one pass over the UTF-8 text instead of a regex search per word (MSVC builds; the regex for other
    encodings, a non-ASCII prefix in case-insensitive mode, invalid UTF-8) and an upper-case table for the sort (CPU per
    keystroke, 60,000 lines: 's' 49.5 -> 6.2 ms, case insensitive 47.4 -> 10.4 ms; the lists the same item by item in 7
    cases); `24d3fac` the live switch's `setTechnologyToAll` as on its branch; `dd3cd5a` the Document List's column widths
    stored for 96 DPI.
  - PR branches: `directwrite-font-names_20260930` rebased on `b661c2b`, `setStyleFont` in one body (`ace29cd`, CI 13/13);
    `live-rendering-switch_20261005` leaves upstream's Preferences lines (`61eccb1`, CI 13/13, harness: its tests pass,
    `directwrite-font-names` fails as on upstream); new: kit 9 `function-list-caret_20261020` (`398b2c2`, CI 13/13) and
    kit 10 `doclist-column-width_20261020` (`20f0a90`, CI 13/13; a test can't drive the header's divider: Pyre909 checks it
    by hand at 150% first). The smoothing/RTL interaction is already kit 8's "Before opening 2".
  - Scale sessions (Pyre909 changing the scale: 150 -> 125 -> 200 -> 100 -> 150, then 200 -> 100 -> 150, then 200 -> 150;
    `review/tests/pyre-dpi-scale.ps1` extended: `-Changes`, status bars, the Find dialog, black checks, `-Compare` builds,
    15% instead of 25%, which had let the toolbar pass). The Project Panel toolbar: comctl32 sizes text buttons no higher
    than for the DPI the toolbar was made at (31 pixels at 200% from 150%, text clipped), and the theme change Windows sends
    after a DPI change puts its font and height back; fixed by a toolbar subclass (`97867d0`, in `pyre`
    with `090f5ff` since 2026-10-20, CI 13/13 run 39523430910, the CI's GCC build also run locally; 13/13 checks with
    real changes: 31 -> 38 -> 31). #18462: only `9d99c31`'s `WM_THEMECHANGED` change fixes the black
    (main window's) status bar, the Find dialog's PMv2 can come back: kit 11, a comment for Pyre909 to post. Known,
    left: below the start scale the status bars stay at least 28 pixels (comctl32 keeps them for the system DPI).
  - Tools added (2026-10-20): MSYS2 with MINGW64 GCC 16.2 and CLANG64 Clang 23.1 (the CI's MSYS2 jobs, run locally:
    `$Env:MSYSTEM='MINGW64'`, `C:\msys64\mingw64\bin` and `C:\msys64\usr\bin` first in PATH, `mingw32-make -f
    PowerEditor\gcc\makefile`), Visual Studio's C++ Clang tools (`/p:PlatformToolset=ClangCL`), WinDbg (Time Travel
    Debugging), Sysinternals Suite (DebugView, Process Explorer, Handle, Process Monitor; the Store edition, as winget's zip
    hash was stale). Already there: Windows Performance Toolkit, Application Verifier, cdb.
  - 2026-10-20: the toolbar fix folded into `per-monitor-dpi_20260925` (`cf6a333`, CI 13/13 run 39528881391);
    `setup-vm.ps1` installs the tools added on the VM and adds missing Visual Studio components to an existing install
    (`9618908`); upstream's `fc40460` (#18523, the Find dialog's replace checkboxes not moving on a resize, the reduced
    mode's hide lists) merged into `pyre` (`7e3ee6c`, CI 13/13 run 39528975956). Checked with a scratch script on the
    builds before and after the merge: widened by 200 px, the two replace checkboxes moved 0 px before, 200 after (with the
    buttons), the reduced mode left 5 controls shown before, none after. The VM since its restart (Windows update to build
    26300): builds about 3 times slower, the layout cache test's Replace All between 19 and 66 s on the same build (its
    limit is 15 s): not the code (both builds' best run 19.4 s); check the VM's memory and CPUs in Parallels.
  - The DPI rework (2026-10-20, evening): two read-only reviews of `per-monitor-dpi_20260925` (the split; the helpers),
    checked against the code. With the option off the branch changes only the checkbox and one config.xml attribute:
    most of it can't be run by reviewers before the switch exists, and its few real fixes were gated. Pyre909's choices:
    ask the maintainers before splitting (the 27-step sequence goes into the #14959 comment, kit 4: to write), and fix the
    sizes upstream's own per-monitor dialogs get, with the option off too.
    - `pyre` `35c1b35` (16 files, +89 −142): `scaleFromSystemDpiForWindow` / `getSystemMetricsForWindow` take the
      window's DPI (Preferences' "go to setting" tip keeps the flag: the main window's code makes it); the menu colour
      bitmaps always cached (the GDI leak); `Progress::thread` takes its caller's awareness; `getDialogBaseUnits` uses
      upstream's `getFontAvgAlphaWidth` and a new `getFontHeight`; `scaleLogFont` for `DialogDpiLayout` and Clipboard
      History; `checkDpiChange` returns whether the DPI changed and `WM_DPICHANGED_AFTERPARENT` relayouts the panel once
      (four panels' copies gone); `replaceWindowFont` for DockingCont's fonts and the search field's; the flag dropped
      where the DPI compared is the window's own (kept in `checkDpiChange`: a panel's DPI isn't set while it's created);
      Preferences' three tips of 260 scaled. CI 13/13 (run 39549370355). Harness: 0 FAIL after a clean rebuild (an incremental one crashed at exit,
      0xC0000374: stale objects after `functionListPanel.h`'s member type change; CLAUDE.md now says so), one popup-timing
      flake that passed twice. Scale session (200 -> 100 -> 150%): every panel check passes, the Project toolbar 31 -> 38 ->
      22 -> 31. Its Preferences tooltip check was wrong (Preferences opened at 150% first: closing only hides it): it now
      creates Preferences after the first change only.
    - New upstream bug-fix branches (kit 12, 13): `menu-colour-bitmaps_20261020` (`5903444`: +1,100 GDI objects per 100
      colour updates before, 0 after; test `menu-colour-bitmaps`), `dpi-dialog-sizes_20261020` (`b759ee8`: the tooltip
      widths and Shortcut Mapper's grid metrics in upstream's per-monitor dialogs; scale session: Preferences created at
      200% on the 144-DPI system, tooltip widths 200 and 260 before, 267 and 347 with it; 14/14 checks).
  - Kit 4's comment for #14959 now proposes the split (switch, main window, edit views, docking, tree helper and one PR
    per panel, dialog layout helper with the incremental search bar and the docked UDL, the checkbox last) and asks
    whether the switch comes first as a config.xml-only option: for Pyre909 to post.
  - Release (2026-10-21): upstream's `e013310` (CI only: a modelDate check, `pyre-ci.yml` regenerated) merged; the
    release workflow's artifact actions moved to Node.js 24 (`upload-artifact` v7, `download-artifact` v8: the runs had
    warned about Node.js 20; now 0 annotations); `PYRE-BUILD.md` brought up to date. **Published**:
    `pyre-8.9.8.1-f495ad1` (Latest; x64 and ARM64, PGO), notes with a "What's new since 7c83c57" section; the drafts of
    `56d6ea5` and `e56e9bb` deleted.
  - Global override back to upstream (2026-10-21), asked by Pyre909 ("lets make sure pyre has that more in line like
    upstream"): the font of every theme removed (`aca5fd5`, on top of `f495ad1`): Global override forces the theme's own
    Global override style again; `WordStyleDlg.rc`, `WordStyleDlgRes.h` and `ScintillaEditView::setStyle` byte for byte
    upstream's; the Style Configurator fixes kept. Harness 0 FAIL 0 WARN (ARM64, x64, Win32 builds; every test); test
    `pyre-font-every-theme` became `global-override` (10 checks, any build; the 7c83c57 installation fails 6);
    `vm/modes.ps1` sets its font in stylers.xml now. Independent review: no defect. Its notes, kept: (1) the next
    release's notes need a line by hand (package.ps1 takes PYRE-BUILD.md's list, which just loses the bullet): "Global
    override's font is the theme's again, as in official Notepad++: set it on your theme's Global override style";
    Pyre909's own themes already have MonoLisaCode there; (2) upstream's STYLE_NOT_USED bug is back with upstream's
    `setStyle` (a style without a `fontStyle` attribute turns italic and underlined when bold is forced off; no shipped
    style reaches it): parity chosen, a possible upstream issue. Local refs tidied: `per-monitor-dpi_20260925` was the
    older `4eaa93d` (now `cf6a333`, as on GitHub), `master` at `origin/master`. Pushed with Pyre909's OK (`aca5fd5`), CI
    13/13 (run 39636879927); both releases deleted at Pyre909's request (their `pyre-*` tags kept).
  - Three features (2026-10-21), asked by Pyre909 ("Is there anything missing from notepad++ currently that is worth
    adding?", then "Lets do as you recommend"): from upstream's most upvoted open issues, checked in the code and against
    the maintainers' comments. Recommended and not done: scrollbar marks (#3116), faster opening of many files (#14000);
    skipped: LSP (#4440, plugins exist), tab groups (#9517), print preview (#4236), the 1 px gap of a maximized window
    (#8660). All three off by default where they change behaviour, so `pyre` stays upstream's unless chosen:
    - `6435b2b` links opened by Ctrl+click (#9993), Preferences > Cloud & Link > "Open with Ctrl+click": taken in
      `ScintillaEditView::ScintillaProc` before Scintilla adds a caret; upstream's double-click code shared as
      `Notepad_plus::openLinkAt`. Review: a selected link left to Scintilla (Ctrl+drag), the double-click distance, the
      view focused, the mouse capture respected.
    - `94dd512` the caret's character code in the status bar (#2056): "U+00E9", "0xE9" for an invalid byte; the position
      part 320 px at 96 DPI (+60, the code's width, so upstream's room is kept for translations; 280 clipped).
    - `cd162a0` word wrap per document (#5232), Preferences > Editing 1 > Line Wrap > "Per document": each document's
      wrap mode in its Buffer (set when opened from the last choice), applied on activation, in session.xml. Review: the
      first document of each view lost its session wrap (shown before it was read; fixed), the Document Map stayed
      wrapped, a session could wrap a large file, a plugin's char/whitespace wrap was lost; all fixed. Known: a tab's
      hover preview in the map uses the current document's wrap.
    - Tests: `pyre-links-charcode` (18 checks), `pyre-wrap-per-document` (13); found on the way: a DPI-unaware test
      process gets the clicks it posts scaled by Windows (x1.5 at 144 DPI), so tests that post clicks set per-monitor
      awareness (`pyre-rounded-popups` clicks at 5,5 of a button: unaffected).
    - For upstream: each is a possible feature request (an issue to be Accepted first); not drafted yet.
    - Pushed with Pyre909's OK (`pyre` `cd162a0`), CI 13/13 (run 39664208581); release run 39665322657 (0 annotations),
      **published** as Latest: `pyre-8.9.8.1-cd162a0`, its notes with "What's new since the last release (f495ad1)", the
      Global override change included.
  - Upstream merge (2026-11-01, asked by Pyre909: "Looks like we have some updates upstream. Lets include them?"): 37
    commits up to `2132e15` (Scintilla 5.6.7 and Lexilla 5.5.4, security fixes, the Clipboard History list as a list
    view, the menu items' GDI leaks, Windows dialog and document switcher fixes, CI on UCRT64, translations) merged as
    `a7b991f`. Conflicts: upstream's own fix of the menu colour samples' leak replaces pyre's (kit 12 superseded); per-monitor
    DPI keeps the samples of the previous DPI until exit (`_retiredMenuItemClrBitmaps`, the context menus share them); the
    Clipboard History list view gets the icon title font of its DPI (as the ASCII panel's); the layout-segment blocks
    patch moved onto 5.6.7's `LayoutSegments`; corsican.xml; `pyre-ci.yml` regenerated. Clean ARM64 and x64 rebuilds:
    0 warnings. PR branches against the new upstream (`git merge-tree`): all merge cleanly except
    `menu-colour-bitmaps_20261020` (superseded) and `per-monitor-dpi_20260925` (the same two conflicts as `pyre`: rebase
    it with the same resolutions when it's wanted). PR #18503 still mergeable, no review yet.
  - Second merge (2026-11-01): 5 more upstream commits up to `9923cad` (Boost 1.92.0, the internal list views' highlight
    styles #18563, auto-completion and call tips left behind on a window move, the UDL of new documents, CI) as `4164177`;
    conflict in the ASCII panel (upstream's list view init and includes, pyre's DPI parts kept); `pyre-ci.yml` regenerated.
    Harness: 1 FAIL, `pyre-text-rendering-config` (a config.xml not saved within 30 s), from my MSYS2 update running at the
    same time; alone it passes 4 runs in 4. Pushed with Pyre909's OK.
  - Toolchains and dependencies (2026-11-01, asked by Pyre909): VS Build Tools 2026 18.11.1 -> 18.11.3 (MSVC 14.51.36231;
    `setup.exe update` exits 8006 while MSBuild worker nodes or mspdbsrv of earlier builds are alive: stop them first),
    Git 2.55 -> 2.56, MSYS2 updated (Clang 23.1.4, GCC 16.2.0) plus UCRT64 GCC and make, as the CI's 64-bit GCC jobs moved
    there (`setup-vm.ps1` and CLAUDE.md follow, `e03c197`); the release workflow on `actions/checkout@v7`. MSVC still has
    only `/std:c++23preview`. Libraries in the tree are current (Boost 1.92.0, pugixml 1.16, nlohmann/json 3.12.0) except
    Scintilla 5.6.7 / Lexilla 5.5.4: 5.6.8 (2026-10-31; fixes #2520, the crash pyre guards, and a change history undo
    crash; Unicode 17) and 5.6.9 (5.6.8's XPM colours), Lexilla 5.5.5 / 5.5.6 (lexer crash and memory-safety fixes).
    Upstream PR #18588 (chcg, 2026-11-01, open) brings 5.6.8 and 5.5.5: take it with the next sync rather than updating
    Scintilla in pyre (it would conflict), then drop pyre's crash guard in `SurfaceD2D.cxx` and re-check the local patches.
  - CI 13/13 on `e03c197` (run 41381617160, the UCRT64 jobs included); `PYRE-BUILD.md`: the menu samples' leak no longer listed
    as ours (`b428833`); release run 41382342331 (0 annotations), **published** as Latest: `pyre-8.9.8.1-b428833`, its notes with
    "What's new since the last release (cd162a0)".
  - Left: the plugin prototype (only if Pyre909 wants one: their choice for plugins was to disclose they aren't covered); the UDL undocked onto another monitor (needs a
    second display); the relaunch prompt (probably not needed: the setting says "restart required"). The Document List
    checked by hand (kit 10: 48 -> 72 px before the fix, 50 -> 50 after).
  - For Pyre909: post kit 4's comment (#14959) and kit 11's (#18455); open the issues of kits 12, 9, 13 and 10, then their PRs.
- **The "1 to 8" round (2026-11-01)**, asked by Pyre909 ("go ahead with 1 - 8"; on PR #18588: "It will definitely get
  merged. It's just waiting to get merged."). `pyre` commits on `b428833`, local until Pyre909's OK:
  - 7, Scintilla 5.6.8 / Lexilla 5.5.5: upstream PR #18588 (chcg's `5cd3d32`, `refs/remotes/upstream-pr/18588`) merged
    ahead of upstream (`07a7c00`), 5.6.8's XPM regression fixed as in 5.6.9, the #2520 crash guard dropped (5.6.8's own).
  - 3, stroke widths at high DPI (`c6092bd`): Notepad++'s markers 21-31 and indicators 8, 21-31 in whole pixels for the
    DPI (`setStrokeWidthsForDpi`; 1.5 px looked like 1); plugins' 9-20 and Scintilla's own left alone. Test
    `pyre-stroke-widths.ps1`.
  - 4, Preferences open speed (`2531842`): 760 -> 573 ms first opening (Style Configurator 212 -> 193): font lists with
    `CB_INITSTORAGE` and redraw off, the Print page's lists filled at its first showing, `getNameStrFromCmd` with this
    process's window found once (FindWindow per name, ~0.5 ms each, ~230 names; with `-multiInst` it could take another
    instance's menu names: an upstream bug too). Left: `autoSubclassAndTheme` 75 ms, the Editing page 58 ms. Test
    `pyre-preferences-open.ps1` (release `b428833`: 2 of 6 fail).
  - 2, audit of the plugin messages and WM_COPYDATA (an agent, its two findings reproduced before any fix): `d229f5e`
    `NPPM_SETCURRENTLANGTYPE` / external language commands out of range crash at the next key (0xC000041D); `759e1f7` the
    DTO's `wcsncpy` is MSVC's `wcsncpy_s` and fails fast (0xC0000409) with a long `-udl=` / `-pluginMessage=`, and the same
    in `AutoCompletion::setLanguage` (a UDL name over ~210 characters) and config.xml's open/save folders (stacks with
    cdb on the ASan build). Test `plugin-api-bounds.ps1` (13 checks; release: 11 fail). The other ~80 `wcscpy_s` /
    `wcscat_s` into arrays: a sweep suggested as its own task (not done).
  - 6, buffered drawing: only GDI buffers (Scintilla turns it off for DirectWrite itself); off is 13-38% slower with GDI
    (repaint, scrolls, caret, typing; ARM64 and x64): nothing changed.
  - 5, startup with many files (#14000): timers in `loadSession` (not committed) put 64% in
    `DocTabView::getIndexByBuffer` (TCM_GETITEM per tab, several lookups per file, mostly before it's in a tab):
    `885561b` skips buffers that can't be in the tabs, looks from the last tab, drops `addBuffer`'s second check, adds
    bookmarks only to files that have some. 1,000 files 41.4 -> 8.1 s, 298 files of 57 MB 4.43 -> 1.33 s. Left: the tab
    control's own insert/set work (~5 s at 1,000; redraw off during the load gave 5.8 s once, not kept: multi-line tabs).
    Test `session-load.ps1`.
  - Upstream candidates, one commit each on `9923cad`, local, no CI yet: `langtype-bounds_20261101` (`bbe235f`),
    `long-strings-failfast_20261101` (`2c65c1f`), `session-open-speed_20261101` (`0711cfc`); texts in kit 14-16.
  - Harness on the 8 commits (against `origin/pyre`, ARM64/x64/Win32): 0 FAIL, 7 WARN (Scintilla/Lexilla 5.6.8 code
    style, the bookmark block re-indented), 25 tests pass; the CI's UCRT64 GCC build passes locally.
  - Independent review (an agent, read-only): one real regression, verified and fixed: sorting tabs (Window > Sort By,
    the Windows dialog) set each tab in turn, a buffer is in two tabs for a moment, and 885561b's lookup from the last tab
    labelled the old one ("c | b | c", the first showing a): `setBuffer` / `addBuffer` now label the tab at the index they
    know (`updateTab`, `119a4db`; `session-load.ps1` sorts 78 tabs and checks each label, 9 checks). Also taken: the
    receiver of `COPYDATA_PARAMS` ends the strings, over-long config.xml folders ignored rather than truncated
    (`64fff16`); a wrong comment (`c857068`); `gNppHWND` instead of a cached handle (`9265299`). Left (noted): the stroke
    widths also overwrite a plugin's own widths on markers 21-31 at a DPI change; bookmarks could be added through the
    scratch view instead of swapping the edit view's document.
  - The `wcscpy_s` / `wcscat_s` sweep (a separate session started from a suggestion; merged 2026-11-02 as `eb6b143`, with
    two guards added: `NPPM_RELOADFILE` with a null path, an empty Folder as Workspace root): `NPPM_RELOADFILE` with a
    path of `MAX_PATH` or more refused; translations longer than their arrays (Shortcut Mapper's grid, Find in Files
    progress, Find All result, Folder as Workspace and Function List tooltips) and a theme's long language description
    truncated; a `\\?\` Folder as Workspace root of `MAX_PATH` or more a `std::wstring`; a project workspace that long
    refused. Each reproduced as a crash first. Left: RunDlg's `extractArgs`, one `L'\0'` past `cmdPure` for a command of
    exactly 260 characters with no space (no crash seen). Test: `plugin-api-bounds.ps1` (`03b9d4e`), 25 checks; ARM64 and
    x64 pass, with `pyre-style-configurator`, `function-list` and `session-load`. Upstream: a follow-up PR after kit 15,
    not yet on a branch. The session archived, its worktree and branch removed.
  - Pushed with Pyre909's OK (2026-11-02): `pyre` fast-forwarded to `122db31`, this branch, the three new PR branches,
    `per-monitor-dpi_20260925` force-pushed (`cf6a333` -> `54851f3`, with a lease); the old tag `pyre-8.9.8.1-cd162a0`
    deleted. CI 13/13 on each: `pyre` 41410127730, `langtype-bounds` 41410131131, `long-strings-failfast` 41410134858,
    `session-open-speed` 41410138522, `per-monitor-dpi` 41410141621. Release run 41412176617 (PGO, 0 annotations),
    **published** as Latest: `pyre-8.9.8.1-122db31`, its notes with "What's new since the last release (b428833)".
  - For Pyre909: kit 14-16 (issues, then PRs; #14000's comment first), and the earlier list above.
  - Upstream check (2026-11-02): 2 new commits, `025d452` (Scintilla 5.6.8 / Lexilla 5.5.5 merged upstream directly,
    chcg's PR #18588 closed; its Scintilla and Lexilla content the same as `5cd3d32`) and `8430de0` (Malayalam). Merged
    into `pyre` as `12cee53` (conflicts, pyre's side: the two `.mak` files' `-std:c++23preview`, `XPM.cxx`'s fix): pyre
    gets the translation only. Clean rebuilds, both start in Malayalam. Upstream master keeps 5.6.8's XPM slip, which makes
    its auto-completion icons nearly black: kit 17, an issue pointing at 5.6.9. All ten PR branches still merge cleanly
    onto upstream `025d452`; PR #18503 still unreviewed. Harness 0 FAIL (3 WARN in upstream's Malayalam code); pushed
    with Pyre909's OK ("push if passes"), the fork's `master` synced to `025d452`; CI 13/13 on `pyre` (run 41474122409).
    No new release: the translation is the only change since `pyre-8.9.8.1-122db31`.
  - Characters on a grid (2026-11-02, asked by Pyre909: tabs looked uneven in their session, a tab after one character
    narrower than the one before; that's the tab stops, upstream's behaviour too). View > Show Symbol > "Show Characters
    on a Grid" (`3163c84`, not pushed): a cell is a space's width, a tab one tab size wide wherever it is, every
    representation (control characters, line ends, NPC labels, invalid bytes) in whole cells, centred; letters keep their
    font's widths. Pyre909's choice after talking it over: the grid plus a 2:1 font for CJK (BIZ UDGothic, MS Gothic,
    NSimSun and the Korean ...Che fonts come with Windows), not glyphs squeezed into cells (layer 3, not done: emoji and
    CJK taken from a fallback font in a font without CJK, as MonoLisa, stay off the grid). It replaces the first idea,
    "Show Tabs at Fixed Width" (a tab representation, never pushed). Test `pyre-character-grid.ps1`, 11 checks: ARM64 and
    x64 pass, release `122db31` fails 9. Before/after previews of 8 samples (code, INI, Makefile, TSV, CJK, control and
    invisible characters, invalid bytes, scripts and emoji) in MonoLisa Code and BIZ UDGothic, shown to Pyre909.
    Harness 0 FAIL (7 WARN: the Scintilla patch, its style, comment prose). Independent review: fixes in `975bc6f` (hidden
    control characters took a blank cell; Scintilla's `singles` table of control characters' widths, used by every line
    once a line over 2,000 bytes fills it, stale after a representation change: reset beside pyre's `llc` reset in
    `Editor.cxx`; the edge's background mode in cells; plain labels centred; `SCI_CHOOSECARETX` after a toggle). Rejected:
    the label measured on each paint (23.4 vs 23.7 ms for 1,800 labels). Left, documented: document columns (status bar
    Col, Column Editor, Tab with spaces) count tab stops; explicit tab stops and the bidirectional mode's tabs
    (`ScreenLine::TabPositionAfter`, plugins only) aren't on the grid. Upstream Scintilla, for a bug report (not code):
    `WrapBlock`'s threads lay out lines under 4,000 bytes, and `LayoutLine` fills `singles` for those over 2,000, unlocked
    (a data race; same values). The test now 14 checks (3 new fail on `3163c84`); ARM64 and x64 pass. A PEP 8 sample
    (`inventory_report.py`, pycodestyle and ruff clean) and the reports it writes compared pixel by pixel, grid off vs
    on: code, space-aligned and Markdown reports identical; tab-aligned columns no longer line up (by design).
    Harness again on both commits: 0 FAIL. Pushed with Pyre909's OK: `pyre` fast-forwarded to `975bc6f`, CI 13/13 (run
    41505721464). No release yet (Pyre909's choice): `pyre-8.9.8.1-122db31` stays the latest.
  - Presentation and counting, the plan Pyre909 agreed (2026-11-02), after a long talk (their wishes: consistency in every
    font; what the status bar says and what's shown agree; they work with mainframe data and offsets):
    1. **Special-character labels** (done, pushed 2026-11-02): one label style (a rounded box, its own font: Segoe UI Semibold
       at three quarters of the text's size), a colour by kind (control characters slate, line ends teal, invisible
       characters purple, invalid bytes red; light or dark tones from the theme's background), names everywhere (BOM),
       every invisible character labelled (24 added). Pyre909 chose readable labels in whole cells over one cell each,
       and names over code points. Test `pyre-special-labels.ps1`, 12 checks: ARM64 and x64 pass, release `122db31`
       fails 11. Seen: the mock-up, then the build's own rendering, light and dark. Independent review (10 findings),
       verified and fixed: the label font made lines taller (Courier New, DirectWrite: 30 -> 31 px at zoom +3, 47 -> 51
       at +10): `StyleControlChar` left out of `FindMaxAscentDescent`, and its size set against the zoom (`SCN_ZOOM`);
       GDI drew each box through an alpha-blended bitmap (a screen of 1,900 NUL labels 2.2 -> 42.1 ms a paint, now
       4.5): opaque rows where the surface can't blend, GDI and printing; the box pixel-aligned, skipped when no room,
       the text's width from the layout unless the grid rounded it; the label's text black or white by its box (the
       background's colour lacked contrast on styles with their own background); the Finder's labels coloured and in
       their font after a theme change; printing: the labels at their unzoomed size, the light tones on paper unless
       printed as shown; the Preferences tooltip's BOM; UTF-8 keys of two bytes and more set only in UTF-8 documents (in
       GBK, CD 8F and C2 80 are characters: the release labels C2 80 PAD and hides it as a control character by default,
       an upstream bug); CLAUDE.md's "every reset" claim narrowed (Document Map, Peeker, the other view after a Reload,
       NPPM_DECODESCI already lose Show Non-Printing Characters upstream). The test now 14 checks (release 13 fail).
       Not tested: the Finder after a theme change, printing.
    2. **Status bar** (done, pushed 2026-11-02): Col the cell the caret is in with the grid (`SCI_GETCELLCOLUMN`), the
       character and byte positions beside it when they differ (bytes of the file's encoding, UTF-16's too), a
       selection's bytes; Preferences > General > Status Bar: "Caret position" column / offset in hex (`Off: X'17'`) /
       both, "Line length"; the part grows to its text, never leaving the document type under 60 px. Test
       `pyre-status-position.ps1`, 10 checks: ARM64 and x64 pass, release fails 8 of 9. `pyre-links-charcode`'s status
       text check now allows the "(ch, byte)" annotation.
    3. **Fonts** (done, pushed 2026-11-02; the rendering settings Pyre909's to choose): CJK and emoji fitted in their cells (centred, scaled down when wider; Unicode's East Asian Width, not
       the font, decides the cells: measured, fonts disagree, e.g. Greek and box drawing 2 cells in BIZ UDGothic, 1 in
       MonoLisa); whole-pixel cells with the grid; crisper labels (done in 1); a comparison of pyre's rendering settings
       in Pyre909's font. A wide-character font setting deferred: no single font covers Japanese, Chinese and Korean
       (BIZ UDGothic has no Hangul nor simplified Chinese), so it'd be a font list, as Vim's `guifontwide`.
       Done: every character in its Unicode cells with the grid (`CellsOfCharacter`, a Unicode 17 table;
       `SetCellWidths` in the layout, `DrawTextInCells` drawing, `DrawTextTransparentScaled` on both surfaces), emoji
       sequences as their parts (Pyre909's choice), U+FE0F making a character two cells, a proportional font's cell its
       "0". `pyre-character-grid.ps1` now 16 checks (CJK in Consolas on the grid, 0 off it instead of 47; Unicode's
       widths; Segoe UI every character on the grid). Committed as `996f6ba`; harness 0 FAIL.
       The independent review (no crash or memory finding; the table equal to Unicode 17's) found, fixed in a second
       commit: glyphs wider than one cell shrunk in height too (Segoe UI's m at 2/3; a CJK font's Ambiguous characters,
       box drawing, at half: now narrowed only, scaled both ways from two cells); every paint measured its text again
       (the position cache keeps strings under 40 bytes only: now the layout's `fontWidths`); virtual space in a
       proportional font in the font's spaces (Segoe UI: 9 instead of 5); the block caret drew its character the old
       way; keycaps (`#` U+FE0F U+20E3) one cell; decomposed Hangul 4 cells (its vowel and final consonant now 0); in
       ANSI a byte the font gives no width (C1 controls) joined the one before; a combining mark after a tab drawn over
       it (now a cell, on U+25CC); a run with a right-to-left letter or a hidden RLO reordered by the font (now each
       character, in order); the italic end-of-line hack off the grid. Kept: U+00AD one cell (as terminals); Ambiguous
       characters one cell (an "Ambiguous is wide" option possible). Cost now (a screen of CJK in MonoLisa, ARM64):
       DirectWrite 23 ms a paint, as with the grid off, GDI 12 (16 off): one call for the characters a run neither shapes
       nor reorders (`DrawTextTransparentAt`: GDI `lpDx`, Direct2D `SetCharacterSpacing`); Segoe UI code with GDI 6 ms.
       `pyre-character-grid.ps1` 19 checks (keycap, Hangul, mark after a tab; a hidden RLO by pixels, which differ
       without the grid; ANSI and GBK; virtual space in Segoe UI). Pushed 2026-11-02 (`996f6ba`, `956ed4e`; CI run
       41562948153: 13/13, its Win32 Debug job left "in progress" by GitHub with every step done). Whole-pixel cells,
       measured first: in MonoLisa Code 10 pt with DirectWrite (Pyre909's settings) the cell was 12.794 px and a 0 or
       an m drawn six ways across 24 columns (GDI: 13 px, one way); the cell rounded to whole pixels and a run drawn
       as one only when its advances are the cells within 0.01 px: one way, CJK too; cost a screen of CJK 23 -> 26 ms,
       ASCII code unchanged. `pyre-character-grid.ps1` 20 checks (Consolas zoomed to a fractional advance: one way, 8
       without the grid). Pushed (`da42676`; CI run 41565163490: 13/13). The rendering settings comparison: `vm\rendering-sheet.ps1`, sheets in
       `vm\shots\rendering-settings-pyre-*.png` (14 settings in Pyre Daylight, 5 in Pyre Night). Pyre909's settings
       (DirectWrite, Automatic, antialiasing and contrast Follow Windows: Windows has ClearType on, contrast 1200) on the
       plain-text line: colour fringing 73, solid ink 52%. Natural ClearType 80 / 62%; GDI classic ClearType 81 / 67%
       (whole-pixel advances: 13 px instead of 12.79, the grid's cell anyway); ClearType with less color 37 / 55%;
       Grayscale 9 / 55%; GDI classic Grayscale 11 / 62%; contrast Very high +17% ink; GDI ClearType 75 / 57%, GDI
       Grayscale 8 / 65% but 16% lighter; None 100% solid, jagged. Pyre Night alike (current 59 / 52%, Grayscale 11 /
       51%, Natural 70 / 63%). Suggested to Pyre909: ClearType's colours are made for the screen's own sub-pixels, and
       the VM is seen through Parallels on a Mac screen, which may rescale it; GDI classic with Grayscale is the
       crispest without colours (setting 11 of the sheet), ClearType with less color the middle way. Pyre909's choice,
       by eye, inside Windows. Found on the way: the test's widths in cells must be rounded
       (`SCI_POINTXFROMPOSITION` truncates: 21.98 -> 21); keyboard moves into virtual space need SCVS_USERACCESSIBLE and
       the caret's x chosen (`SCI_CHOOSECARETX` after `SCI_GOTOPOS`); `sed -i` in Git Bash wrote a CRLF file as LF.
    - Decided along the way: right-to-left and complex scripts in data order with the grid; line ends one cell each was
      chosen, then superseded by readable labels in whole cells. Researched: VS Code (status bar Col = visible column,
      CJK and emoji 2, graphemes; `fullwidthCharacterWidth` font/twoCells), Vim (`%c`/`%v`, `ambiwidth`, `guifontwide`),
      Emacs (glyphless characters as a hex box), Sublime, EmEditor, UltraEdit, jEdit/Visual Studio (file and screen
      columns), ISPF (HEX ON: two rows of nibbles under each byte), hex editors.
    - **Parked: a mainframe record view** (Pyre909: later). Binary EBCDIC records can't be shown accurately as text:
      `X'25'` is LF, `X'0D'` CR, `X'15'` NEL, `X'05'` tab in EBCDIC 037/500/1140, and a packed field holds any of them
      (+12.50 is `00 01 25 0C`), so a text view splits records; FB files have no line ends, z/OS FTP drops RDWs unless
      `QUOTE SITE RDW` and trailing blanks of fixed records unless `TRAILINGBLANKS`, and a text transfer destroys packed
      fields. Design: open a file as records (code page: every EBCDIC one, Pyre909 wants them all; format FB with LRECL,
      VB with RDWs, or lines; detected, then asked), each byte one cell (non-printables as stacked hex nibbles, ISPF's
      vertical hex), each record one line whatever bytes it holds, lossless save (all 256 bytes per code page tested),
      FB overwrite-only, VB RDWs recomputed, an ISPF HEX ON toggle, the status bar with record, column, offset in hex,
      file offset; then copybook layouts (fields shaded, the field and its decoded value at the caret, bad packed signs
      flagged). Pyre909 needs view, edit and save; files come by binary and text transfer; medium sizes. Samples:
      `customers-fb.bin`, `-vb.bin`, `-text.txt` (made by `record_examples.py`, not kept in the repository).
  - 8, `per-monitor-dpi_20260925` rebased on `9923cad` (`54851f3`: the same resolutions as `pyre`'s merge), both MSVC
    builds clean; CI needs it pushed (a force-push: Pyre909's OK).
  - 1, AddressSanitizer: all the tests on the final code (`asan.ps1 -Ref 885561b -Test All`, the four new tests
    included): no memory error (the run's only FAILs are the upstream-PR rules, which a `pyre` commit always trips).
- **The performance program (2026-10-20)**, asked by Pyre909: newer toolsets, refactoring, performance "in
  sections/parts", every language feature that helps, Windows 11 polish. Their choices: upstream code changed only where
  a measurement shows a gain (small marked patches), Windows 10 1809 minimum, C++23 everywhere, Windows 11 polish (not a
  redesign). Each part: measured before/after, harness, CI on a scratch branch (`pyre-section<n>_20261020`, deleted
  once `pyre` has it), then `pyre` fast-forwarded to the commit CI passed.
  - Section 1, toolsets, in `pyre`: C++23 (`0aa1234`), Windows 10 1809 (`4140a37`), its functions called directly
    (`e2f301d`), the PGO switch (`ea8a856`), the PGO release workflow (`29189eb`, `12b8184`: 5 jobs, x64 trained on its
    runner, ARM64 instrumented on x64, trained on `windows-11-arm`, optimized on x64; input `test_only`). PGO against
    LTCG (ARM64, `.github/pyre/bench.ps1`, 5 rounds): lexing -19%, folding and Mark All -17%, wrapping -15%, startup -7%.
  - Section 2, refactoring, parts C (`02451e9`) and D (`071a9b5`) in `pyre`; parts A and B (`0b3cbca`, in `pyre` and
    folded into `per-monitor-dpi_20260925`'s commit, CI: all 13 jobs pass): the per-monitor DPI fonts owned by
    `UniqueFont` (dpiManagerV2.h; no destructor or delete block left), `std::ranges::find`, the icon sets as spans, -64
    lines; the harness's `leaks` test unchanged; a real DPI change: `review/tests/pyre-dpi-scale.ps1`, a person changes
    the display scale. Part E (Scintilla patch) skipped, clarity only.
  - The first real DPI change on the VM (2026-10-20, Pyre909 changed the scale 150% -> 100% -> 150% while
    `pyre-dpi-scale.ps1` ran on `0b3cbca`): Notepad++ stays responsive, every tree, list view, list box and toolbar of
    the 7 panels rescales at 100%; back at 150% all but one come back exactly. **Known fault, from before the
    refactoring:** the Project Panel's toolbar of text buttons stays at its 100% height (31 -> 22 pixels). A toolbar of
    the same styles outside Notepad++ follows the same `WM_SETFONT` + `TB_AUTOSIZE` both ways and ignores
    `WM_DPICHANGED_AFTERPARENT` (scratch program), so the cause is in Notepad++; finding it needs a build logging the
    button size through the DPI change and two more scale changes by Pyre909. GDI objects 379 -> 500 at 100% -> 501
    back: resources cached per DPI (`getMainMenuColourBitmap`...), not a leak per change.
  - Section 3, performance: the regex engine (`0d2b005`, in `pyre`; CI: all 13 jobs pass): the Function List on 60,000 lines of
    C++ 190 s -> 6.1 s, on 3,000 lines 9.5 s -> 0.36 s (tables for the Win32 traits of wchar_t, 16 compiled regexes
    kept, `isInZones` binary search); upstream's 46 Function List unit tests the same. Measured and dropped: the tree
    filled in linear time (the same tree, 3% faster). Then auto-completion (`266b8dd`, in `pyre`): the keywords and the
    words found looked up in sets, 108 -> 76 ms a keystroke on 60,000 lines (the same lists, item by item); what's left
    is upstream's search of the whole document for each prefix. The profile is flat after that: no lexer or Scintilla
    change kept.
  - Section 4, Windows 11 polish (`b64b8ed`, in `pyre`): popups Windows 11 leaves square (call tips, About box, colour
    picker, document peeker) rounded by DWM, switchable (Preferences > Dark Mode, config.xml MISC `roundedPopups`,
    default on); test `review/tests/pyre-rounded-popups.ps1`. Mica dropped: the VM's Windows (25H2) already gives the
    title bars Mica (the same pixels with `DWMSBT_MAINWINDOW`), and Mica behind the bars means repainting every
    custom-drawn bar, a redesign. Measured and dropped earlier: caching the status bar texts (Windows' status bar
    repaints at once in `SB_SETTEXT`; no measurable gain). `bench.ps1`'s scroll times are the display's 60 Hz with
    DirectWrite (its "(CPU)" rows are the work).
  - Cleanup (2026-10-20, with Pyre909's OK): the scratch branches, the Actions artifacts (632), the PGO and
    `text-rendering_20260925` worktrees (the branch stays), the test folders in `%TEMP%` and `C:\npp-*` (not
    `C:\npp-test`), the harness's old runs; Pyre909 then removed the allocation stacks Windows recorded for the ARM64 dev
    builds (`review/umdh-scope.ps1 -Remove`, as administrator), which slowed them (`pyre-layout-cache`'s Replace All
    check took 18.2 s once under load against its 15 s limit, 14.8 s alone). For a leak hunt with stacks, run
    `umdh-scope.ps1` again.
  - Release: draft `pyre-8.9.8.1-56d6ea5` (2026-10-20, run 39453207726, all 5 jobs; PGO), the first with this
    program's sections 1 to 4 and parts A and B; its notes list Windows 10 1809 as the minimum. For Pyre909 to
    publish. The draft of `344c2ad` (sections 1 to 4 only) was deleted with their OK.
  - Tools: `.github/pyre/bench.ps1` (benchmarks, PGO training), `.github/pyre/pgo.ps1`, `review/tests/function-list.ps1`
    (upstream's unit tests, timed, test files in CRLF as CI's checkout), the harness's fixes (leaks measured twice before
    a FAIL, normalized line endings, `pyre-text-rendering-config` reads after a `WM_NULL` round trip).

- `pyre` pushed on 2026-10-19 at `a5e52d2`; Pyre909 CI: all 13 jobs pass (run 39374283434). On top of
  `7c83c57`: `f0b94ec` upstream merged up to `b661c2b` (2026-10-19: the incremental search bar at the top, two Find
  options moved out of Preferences; conflict in `resource.h`: upstream's `NPPM_INTERNAL_INCSEARCHBARPOSITION` took
  `+ 114`, the fork's `NPPM_INTERNAL_DPICHANGEDRELAYOUT` is `+ 115` now), and `a5e52d2`, the font of every theme set
  on the Global override page (section "Style Configurator"). The fork's `master` is still at `a660d79`: GitHub Sync
  fork brings it to `b661c2b` (`pyre` has it already). Previewed by Pyre909 from a portable copy of the installation
  with the ARM64 build and a copy of their settings (`C:\npp-preview-a5e52d2`, deleted in the cleanup).
- `7c83c57` (CI: all 13 jobs pass): the speed, glyph and Text Rendering work of that day (`a52ca6a`, section "Speed,
  glyphs and Text Rendering options" below) and the Style Configurator bug fixes (`a913d55`..`7c83c57`), on top of
  `b0ae0e6` (2026-10-16). Released as `pyre-8.9.8.1-7c83c57` (published 2026-10-20 UTC; its ARM64 installer is
  installed on the VM, the exe checked byte for byte against the installer's). No release of `a5e52d2` yet.
- `per-monitor-dpi_20260925` rebased on upstream `b661c2b` on 2026-10-20 (`4eaa93d`, kit section 4: the conflicts in
  `resource.h`, `DockingManager.cpp`, `StaticDialog.h`, `StatusBar.cpp`, `dpiManagerV2.cpp` resolved as `pyre`'s merge;
  `NPPM_INTERNAL_DPICHANGEDRELAYOUT` at `+ 115`; every DPI file equal to `pyre`'s but for `pyre`'s other features).
- Intermittent, to watch (2026-10-19): `live-rendering-switch-scroll` once found its wrapped 3000-line document 2 lines
  up after the tab switches ("top lines 1498, 1498, 1498" for 1500, DirectWrite LTR), in a harness run right after the
  x64 and Win32 builds. Not reproduced since: 6 runs on `a5e52d2`, 3 of them with an x64 rebuild running, and 3 on the
  release `7c83c57` under the same load (it passed in the harness runs on `f0b94ec` and the first redesign too). The
  next time, keep the test's settings folder and the view's wrap state.
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
- **The font of every theme on the Global override page** (removed on 2026-10-21 for parity with upstream: see the
  handoff) (`a5e52d2`, asked by Pyre909: "redesign the style
  configurator a bit. The way we put that global override at the top"; of three layouts, Pyre909 chose this one over a
  one-line summary at the top or a Preferences setting). The row of five "(Theme)" lists under "Select theme" is gone:
  the dialog is upstream's again (`WordStyleDlg.rc` byte for byte, plus a note), so upstream's changes to it merge
  without conflicts. Global override's own font controls and font "Force ..." check boxes show and set the config.xml
  values; the check boxes no longer mark the theme modified (upstream's do: a theme switch then asked to save it).
  Test `review/tests/pyre-font-every-theme.ps1` rewritten for it (21 checks; one is an old `nativeLang.xml` with the former note under its id 2290: the note is 2291).
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

## Font for every theme (2026-10-06, pyre only; removed 2026-10-21, history)

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
| `master` | `025d452` | Mirror of official Notepad++ (kept in sync with GitHub's Sync fork; never add commits here) |
| `pyre` | `da42676` | **Your own Notepad++ (the Pyre909 build)**: everything below, the build name in the About box, and the private release workflow (installers + portable zips, x64 and ARM64). The fork's default branch since 2026-10-01 |
| `claude/awesome-darwin-bsud9v` | `357fec9` | The cloud session's branch: the combined development branch, all the features (pyre is built on it) |
| `text-rendering_20260925` | `bb32194` | Upstream PR #18418, closed by donho on 2026-10-02: Text Rendering settings in Editing 1 |
| `text-rendering-translations_20260925` | `1aa8b0e` | Follow-up of #18418: label capitalisation in 29 translations (on hold: #18418 closed) |
| `live-rendering-switch_20260930` | `08cc23b` | Superseded by `live-rendering-switch_20261005` (this one was stacked on #18418) |
| `rtl-views-gdi_20261006` | `53d0026` | Right-to-left views drawn with GDI, the startup direction sync (bug fix: #17865, #17518, the RTL UI languages on DirectWrite), on upstream `master`: PR to open (kit section 6) |
| `live-rendering-switch_20261005` | `d50fb3b` | Rendering mode applied without restart (MISC. box), one commit on `rtl-views-gdi_20261006`: feature request to open, PR after it's Accepted and section 6 is merged (kit section 7). Its refusal version is kept as `archive/live-rendering-switch-refusal_20261005`, the fallback |
| `directwrite-font-smoothing_20261006` | `76b3210` | DirectWrite following the Windows font smoothing (bug fix: #14954), on upstream `master`: PR to open (kit section 8). CI: all 13 jobs pass (its ARM64 Debug job hung on GitHub's runner once, passed when re-run) |
| `directwrite-font-names_20260930` | `9f605be` | Fonts such as "Fira Code Light" drawn by DirectWrite (Notepad++-only change; a bug fix of #9951 and #12393, PR after the checks of kit section 5). Rewritten, rebased and force-pushed on 2026-10-06 (the first version was `6e8579e`) |
| `standard-icons-hidpi_20261007` | `bc2e60f` | The redrawn standard toolbar icons alone (ICOs and SVGs, no code), on upstream `master`: offered on #16110 (a comment, no PR) |
| `per-monitor-dpi_20260925` | `4eaa93d` | Opt-in per-monitor DPI awareness (discuss with maintainers before a PR); rebased on `b661c2b` on 2026-10-20 |
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
- Release `pyre-8.9.8.1-da42676` (run 41566167144, 2026-11-03, PGO, 8 files) at Pyre909's request: the character grid
  with every character in its Unicode cells and whole-pixel cells, the special-character labels, the status bar's
  caret position (steps 1 to 3 of 2026-11-02). Smoke-tested from the draft: the ARM64 portable zip's SHA-256 matches,
  its exe is ARM64 with the build name; `pyre-character-grid` 20, `pyre-special-labels` 14, `pyre-status-position` 10
  checks pass on it; started as a user would (its folder's settings): the plugins load, no updater entries, the grid's
  menu item, DirectWrite, a normal close. **Published** as Latest the same day (the tag on `da42676`; it started no
  workflow). It is now the only release: Pyre909 deleted `pyre-8.9.8.1-122db31` and `pyre-8.9.8.1-b428833` with their
  tags on 2026-11-03; `5771464` and the drafts `aee7bbf` and `ea151ae` were gone already. The releases and tags named
  above and in the tests' notes ("release `122db31` fails ...") are history: those builds can't be downloaded any more.

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
