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
pwsh -File review.ps1 -Path <worktree> [-Base <ref>] [-Build ARM64,x64,Win32 | -NoBuild] [-Test All | <name>] [-NoFetch]
```

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
- prints `0 checks, 0 failed` when the build isn't the one it tests (a pyre test on an upstream branch): `review.ps1`
  reports it as INFO, skipped, not as a pass;
- closes Notepad++ at the end.

| Test | What it proves |
|---|---|
| `live-rendering-switch.ps1` | The rendering mode of Preferences > MISC. applies at once to every view (Notepad++'s, plugins'), leaves a view a plugin switched itself alone, survives a view destroyed at run time; right-to-left views (the document, the Document Map) drawn with GDI in every mode without a message, the others following; an RTL tab and an LTR tab switching the view between GDI and the mode; 50 quick switches; the choice saved on exit (39 checks) |
| `live-rendering-switch-rtl-ui.ps1` | With a right-to-left UI language (hebrew.xml): every view mirrored from the start and drawn with GDI under DirectWrite, the default; no message at start, on RTL or on exit; an LTR document getting the mode; the hidden mirrored views keeping GDI through the switches (15 checks). Unmodified upstream fails 7 of them |
| `pyre-live-rendering-switch*.ps1` | pyre's versions of the two tests, as of the refusal design of commit `305ff13` (box in Editing 1); they skip other builds |

Driving Notepad++ from a test: menu commands are `WM_COMMAND` with the ids of `menuCmdID.h`; a combo box is
`CB_SETCURSEL` then `WM_COMMAND` with `MAKEWPARAM(id, CBN_SELCHANGE)` to its dialog (what a click sends); Scintilla
state is read with `SCI_*` messages (no pointer arguments across processes); a message box with only OK closes on
`WM_CLOSE` (its button's id is `IDCANCEL`); `PrintWindow` takes screenshots, as in `vm\measure.ps1`.
