# Review harness

Reviews a branch of the fork before it is pushed or proposed upstream, in two parts:

1. `review.ps1`: the mechanical checks, the builds and the app-level tests.
2. The AI review: `checklist.md` given to an independent reviewer. The Claude Code skill `npp-review` (`SKILL.md`,
   installed in `%USERPROFILE%\.claude\skills\npp-review\`) runs both, verifies each finding and reports.

Every FAIL gets fixed; every WARN gets fixed or explained in the report and, if it matters to the maintainers, in
the pull request. The style checks are heuristics on the added lines: read the diff as well.

## review.ps1

PowerShell 7, from anywhere:

```powershell
pwsh -File review.ps1 -Path <worktree> [-Base <ref>] [-Build ARM64,x64,Win32 | -NoBuild] [-Test All | <name>] [-NoFetch] [-Quiet]
```

`-Quiet` leaves out the PASS lines (use it when an agent reads the output: fewer tokens). Everything is still written to
`%TEMP%\npp-review\review.log`, each test's own output to `test-<name>.log` and each build's to `build-<branch>-<platform>.log`
there.

It reviews the branch's commits and any uncommitted changes against the merge base with `-Base`: by default
`upstream/master` for a pull request branch and `origin/pyre` for `pyre`. It prints FAIL / WARN / PASS / INFO lines and
exits with 1 when something failed.

| Area | What it checks |
|---|---|
| Branch | One commit (CONTRIBUTING 4), the `<topic>_<YYYYMMDD>` name (2), commits behind the base, uncommitted changes, the AI trailer (to disclose in the pull request) |
| Size | Files and code lines, against the pull request template's guidance for new contributors (1 to 4 files, about 30 lines; `english_customizable.xml` not counted) |
| Protected areas | No Scintilla/Lexilla code in an upstream pull request; no fork-only files or "Pyre909" code in one; the version line of `resource.h`; `CI_build.yml` changed on pyre |
| Line endings and whitespace | Each file keeps its line endings (no conversion, no mixed); `git diff --check` without the CR of CRLF files; whitespace-only changes (no reformatting, CONTRIBUTING 6-7) |
| Coding style | CONTRIBUTING's style rules on the added lines: braces, tabs, spaces after keywords and none after function names, C-style casts, `not`/`and`/`or`, `== ""`, uninitialized variables and statics, debug output, non-ASCII characters, `NULL` |
| Localization | Changed XML files well-formed; `english.xml` and `english_customizable.xml` changed the same way; texts used in the changed code exist in `english.xml` and their default texts in the code match it; other languages changed |
| Build | MSVC Release builds (`-Build`), errors and warnings in the changed files; logs in `%TEMP%\npp-review` |
| Tests | The app-level tests of `tests\` (`-Test`), run with the build of the machine's architecture |

## App-level tests (tests\)

A test drives a built Notepad++ the way a user would and checks the result. Contract:

- takes `-Exe <path to notepad++.exe>`;
- uses a settings folder of its own (`-multiInst -nosession -settingsDir=<folder in %TEMP%>`), never the user's;
- prints `PASS <check>` / `FAIL <check>` lines and, last, `<n> checks, <m> failed`;
- prints `0 checks, 0 failed` when the build hasn't what it tests (a pyre test on an upstream branch, a live switch
  test on a build without it), after a line saying why, `INFO  <reason>: skipped`: `review.ps1` reports it as INFO,
  skipped, not as a pass. Without that line, no check is a FAIL (the test stopped before its first check);
- any error of the test is a FAIL, whatever its summary says: a line on its error stream (an exception, a cmdlet
  error) or a non-zero exit code (a test that throws still prints `0 checks, 0 failed` from its `finally`);
- closes Notepad++ at the end.

Memory errors (any branch): `asan.ps1 -Ref <branch, tag or commit> [-Test All]` builds the ref with AddressSanitizer
(MSVC, ARM64) in `npp.worktreessan` and runs the app-level tests on it; any sanitizer report (use after free, buffer
overflow, double free) is a FAIL with its stack. The script's header says what it takes on Windows (the DLL search flag
of Notepad++'s link, the runtime DLL, a quoted log path). `pyre` on 2026-10-16: 12 test sets, no report.

Leaks (any branch):

| Test | What it proves |
|---|---|
| `leaks.ps1` | Each repeated operation of the fork's changes, 300 times after a warm-up of 200: tab switches restyling with a font of a weight, Windows setting changes, right-to-left and back, the rendering mode switched through every mode, Pyre909's font ligatures and line spacing off and on (the last three skipped where the build lacks them): GDI and USER objects, handles and private memory don't grow (at most 10, 10, 50 and 8 MB per 1000). Where the build records allocation stacks (`umdh-scope.ps1`), UMDH heap snapshots before and after: at most 256 KB of heap per 1000, the largest growths listed with their stacks (file and line, from the build's `npp.pdb`, which `review.ps1` makes with `/DEBUG`) |
| `../umdh-scope.ps1` | Run as administrator: Windows records allocation stacks for the test builds only (Image File Execution Options filtered by full path; the installed Notepad++ isn't touched), with a 512 MB database and the NT heap (on Windows 11 ARM64 Notepad++ gets the segment heap, which records none). `-List` shows it, `-Remove` undoes it |

Right-to-left views drawn with GDI (`rtl-views-gdi_20261006`, kit section 6; also in the live switch branch and pyre):

| Test | What it proves |
|---|---|
| `rtl-views-gdi.ps1` | With DirectWrite (fresh settings): View > Text Direction RTL allowed without a message; the view and the Document Map mirrored on GDI, the other views on DirectWrite, back on DirectWrite once LTR; a technology set by a plugin given back after RTL; an RTL tab and an LTR tab switching the view's technology while a long wrapped document keeps its scroll position; an RTL document cloned to the other view on GDI there too; no message on exit (17 checks) |
| `rtl-ui-gdi.ps1` | With a right-to-left UI language (hebrew.xml): every view mirrored from the start and drawn with GDI under DirectWrite, the default; no message at start, on RTL or on exit; an LTR document getting DirectWrite, the hidden mirrored views keeping GDI (10 checks). Unmodified upstream fails the start ones |
| `rtl-ui-editzone-no.ps1` | Issue #17518: with `editZoneRTL="no"`, started without a session or a file, the first document is LTR, with DirectWrite and with GDI (the issue's case) (15 checks). Unmodified upstream fails it |

The rendering mode applied at once (`live-rendering-switch_20261005`, kit section 7; skipped on builds without it):

| Test | What it proves |
|---|---|
| `live-rendering-switch.ps1` | The rendering mode of Preferences > MISC. applies at once to every view (Notepad++'s, plugins'), leaves a view a plugin switched itself alone, survives a view destroyed at run time; right-to-left views (the document, the Document Map) kept on GDI in every mode without a message, the others following; an RTL tab and an LTR tab switching the view between GDI and the mode, a switch while the RTL tab is shown reaching its LTR neighbour; 50 quick switches; no message on exit; the choice saved on exit (41 checks) |
| `live-rendering-switch-rtl-ui.ps1` | With a right-to-left UI language (hebrew.xml): the mirrored views keep GDI through the switches, an LTR document follows them (15 checks) |
| `live-rendering-switch-scroll.ps1` | A long wrapped document keeps its scroll position when its view switches technology with the tabs, with the DirectWrite setting and with GDI set at run time; no message on exit (11 checks) |

DirectWrite following the Windows font smoothing (`directwrite-font-smoothing_20261006`, kit section 8):

| Test | What it proves |
|---|---|
| `directwrite-font-smoothing.ps1` | With DirectWrite, both views and the Document Map get the font quality of the Windows font smoothing, which the test reads and never changes (off 1, Standard 2, ClearType 0); "Enable smooth font" (`NPPM_SETSMOOTHFONT`) gives 3, and turned off the Windows one again; setting changes (`WM_SETTINGCHANGE`) leave smooth font, a plugin's quality and an unchanged Windows setting alone; with GDI after a restart, 0 (16 checks). With ClearType it can't tell the fix from upstream: change the Windows setting yourself to off or Standard and run it again (upstream fails 4). Following a real change of the setting was checked by hand (kit section 8). pyre passes it too (its "Follow Windows" is this code) |

The fonts of a weight drawn with DirectWrite (`directwrite-font-names_20260930`, kit section 5; also in pyre):

| Test | What it proves |
|---|---|
| `directwrite-font-names.ps1` | With "Bahnschrift Light" as the Default Style font and DirectWrite (fresh settings): the Default Style, a style without its own font and the line numbers get "Bahnschrift" weight 300, a bold C++ keyword 600; restarted with GDI (`writeTechnologyEngine="0"`), "Bahnschrift Light" 400 and bold 700 as upstream (pyre: weight 300, bold in "Bahnschrift SemiBold" 600); no message on exit (13 checks). Printing isn't tested: the VM's default printer is a real one (kit section 5, Before opening) |

pyre only (skipped on other builds):

| Test | What it proves |
|---|---|
| `pyre-rtl-style-fonts.ps1` | pyre maps the fonts of the font lists for the technology in use ("Bahnschrift Light" is "Bahnschrift" at weight 300 for DirectWrite): a view switching technology, with its text direction, its tabs or the rendering mode, gets its style fonts mapped again; a Scintilla created for a plugin (`NPPM_CREATESCINTILLAHANDLE`) keeps the font the plugin set on a style while its other styles follow the switches; a font quality a plugin set survives the view's switches between GDI and DirectWrite with an RTL tab (18 checks; pyre before 2026-10-06 fails the 3 plugin ones) |
| `pyre-font-every-theme.ps1` | The Style Configurator's "For every theme" row (the font, size, bold, italic and underline forced for all styles, in config.xml rather than in the theme): forced from config.xml at start, shown in the row, a choice applied at once, a switch to Monokai keeping it, the Global override entry with its colours only, Cancel restoring it, saved on exit; a config.xml without it (another Notepad++'s) taking the theme's Global override values once (16 checks; pyre before it fails them) |
| `pyre-text-rendering-config.ps1` | The antialiasing of config.xml: `fontAntialiasing` with a `smoothFont` that agrees (ClearType, Grayscale), a `smoothFont` turned off by another Notepad++ sharing config.xml (Follow Windows wins), a config.xml without `fontAntialiasing` (`smoothFont="yes"` is ClearType), one without `smoothFont`, written by hand (`fontAntialiasing` kept); what is saved, and the attributes of the former advanced overrides (`fontGamma`...) dropped; the DirectWrite mode, the dropped Adaptive (4) read as Natural (14 checks) |
| `pyre-text-rendering-live.ps1` | With DirectWrite (fresh settings) and the document in both views: each Antialiasing choice and DirectWrite mode of Editing 1 > Text Rendering, chosen through the real combo handler, reaches both views at once (font quality, ClearType level, rendering mode) and redraws the text (screenshot against the previous choice, caret hidden; a control pair without a change must be identical); the mode box has 4 items (Adaptive dropped). The order makes each choice draw differently from the one before: GDI classic between the other modes, which can draw alike (30 checks) |
| `pyre-text-options.ps1` | The options of 2026-10-19: the edit views' page layout cache, layout threads (8 at most) and multiple phases; Editing 1 > Text Rendering > Line spacing (+3: both views at once, the lines taller, the text redrawn; not the Document Map; a plugin's extra ascent kept at Normal) and Font ligatures (off: both views, Cascadia Code's ligatures not drawn; on again: drawn as before); saved in config.xml and read back at the next start (16 checks) |
| `pyre-layout-cache.ps1` | The layout cache as reviewed: page cache and multiple phases for an edit view, not for a large file (2 MB over a 1 MB setting) nor the Document Map; a kept line laid out again after `SCI_ADDTABSTOP` / `SCI_CLEARTABSTOPS` and after representation changes (`SCI_CLEARALLREPRESENTATIONS` alone, the Non-Printing Characters appearance); Replace All adding a line per match with the document cloned in the other view under 15 s, both views shown again (12 checks; 4 fail on the build before the review) |
| `pyre-style-configurator.ps1` | The Style Configurator fixes of 2026-10-19, on a copy of the build laid out as installed (four themes next to it, its own settings folder): an emptied font name saved (#13919) and a font name where the theme had none; an installation's theme saved as the user's copy and selected again in the same session keeps its change; user keywords typed cost under 8 ms a key with 100,000 C++ lines and are applied once the typing pauses; a dark mode switch picks Solarized, not Solarized-light; dark mode before the dialog exists: the dialog shows that theme; a font chosen where the attribute was emptied on load is saved (9 checks; 3 fail before the fixes, 1 on `cff6c08`, before the review's) |
| `pyre-rounded-popups.ps1` | Preferences > Dark Mode > "Rounded corners on popups (Windows 11)", read from what each window asked DWM for (`DWMWA_WINDOW_CORNER_PREFERENCE`): on by default, the About box and the colour picker popup round, a call tip (the Find dialog's zero-length match tip) round small, the main window left to Windows; turned off, each one shown again square at once (the call tip and the colour popup are new windows each time: the About box, kept, is what proves the switch); saved in config.xml (MISC `roundedPopups="no"`) and read back at the next start; on again, round at once (12 checks; 7 fail on `266b8dd`, before the option). The document peeker isn't driven (it needs the real mouse over a tab); skipped before Windows 11 |

Driving Notepad++ from a test: menu commands are `WM_COMMAND` with the ids of `menuCmdID.h`; a combo box is
`CB_SETCURSEL` then `WM_COMMAND` with `MAKEWPARAM(id, CBN_SELCHANGE)` to its dialog (what a click sends); Scintilla
state is read with `SCI_*` messages (no pointer arguments across processes); a message box with only OK closes on
`WM_CLOSE` (its button's id is `IDCANCEL`); `PrintWindow` takes screenshots, as in `vm\measure.ps1`.
