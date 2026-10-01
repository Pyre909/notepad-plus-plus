# Status (2026-10-01)

Where the Notepad++ text rendering, DPI and font work stands: branches, upstream PRs and tickets, the Pyre909
build, and what's next. A Claude Code session starts with `CLAUDE.md` on `pyre` (rules, build, code map). The PR kit with every issue/PR/ticket text is `split/PR-TEXTS.md`; the Scintilla side is
`scintilla/SCINTILLA-UPSTREAM.md`; the tools are described in `README.md`.

## Branches of Pyre909/notepad-plus-plus

| Branch | Head | What |
|---|---|---|
| `master` | `37f76d4` | Mirror of official Notepad++ (kept in sync with GitHub's Sync fork; never add commits here) |
| `pyre` | `98673f7` | **Your own Notepad++ (the Pyre909 build)**: everything below, the build name in the About box, and the private release workflow (installer + portable zip). Meant to be the fork's default branch |
| `claude/awesome-darwin-bsud9v` | `357fec9` | The combined development branch: all the features (pyre is built on it) |
| `text-rendering_20260925` | `bb32194` | Upstream PR #18418 (open): Text Rendering settings in Editing 1 |
| `text-rendering-translations_20260925` | `1aa8b0e` | Follow-up of #18418: label capitalisation in 29 translations (`[xml]` PR after #18418 is merged) |
| `live-rendering-switch_20260930` | `08cc23b` | Follow-up of #18418: rendering mode applied without restart (PR after #18418 is merged) |
| `directwrite-font-names_20260930` | `6e8579e` | Fonts such as "Fira Code Light" drawn by DirectWrite (Notepad++-only change; issue + PR not opened yet) |
| `per-monitor-dpi_20260925` | `8a0ff70` | Opt-in per-monitor DPI awareness (discuss with maintainers before a PR) |
| `font-size-1pt_20260925` | `faaeb59` | Font sizes 1-4 pt: PR #18412 closed upstream (not wanted); kept in the fork |
| `font-weight-names_20260925` | `47341a4` | Superseded: the Scintilla version of the font-name fix |
| `scintilla-upstream_20260930` | | This branch: tools, kits, notes (no Notepad++ history) |
| `archive/wip-text-rendering-ui_20260925`, `archive/wip-per-monitor-dpi-review_20260925` | | Early work-in-progress snapshots, superseded (kept so nothing is lost) |

## Upstream Notepad++

- Issue #18414 + PR #18418 (text rendering): open, positive feedback. Reviewer asked to take the Scintilla
  parts upstream; that route is closed (see below), so #18418 either keeps its ~400-line Scintilla patch or is
  slimmed down to what needs no Scintilla change (technology in Editing 1, antialiasing, the #17461 fix), with
  the DirectWrite mode / contrast options as a separate PR. Not decided; the user chose to maintain the fork.
- PR #18412 (font sizes 1-4 pt): closed, not wanted.
- Next PRs from the fork only when a feature looks worthwhile to upstream.

## Scintilla (SourceForge)

- The maintainer, on feature request #1592 (2026-09-30): "I am not currently accepting LLM-generated
  contributions." and the 100 setting combinations are "overwhelming". So no code from this work goes to Scintilla.
- #2519 (GDI weight family names): withdrawn; the mapping lives in Notepad++ now.
- #1592 (DirectWrite rendering parameters API): declined.
- #2520 (crash in FontDirectWrite::HFont with no text format): open; zufuliu suggested clamping weight and
  stretch in the E_INVALIDARG retry; our reply (with a clamp + guard patch as illustration) is posted. The guard is
  kept in the fork until a Scintilla release fixes it.

## The Pyre909 build (releases)

- Workflow `.github/workflows/pyre-release.yml` on `pyre`: MSBuild x64 Release, then `.github/pyre/package.ps1`
  (portable zip in the official layout) and `.github/pyre/installer.ps1` (installer from the official
  `nppSetup.nsi`), both with the plugins, updater and Explorer context menu of the official release of the same
  version. The result is a **draft** release: only people with push access see it.
- Auto-update is off in both (disableNppAutoUpdate.xml), so the official updater can't replace the build;
  Plugins Admin still works. The installer replaces an official installation (same folder and settings) and is
  unsigned (SmartScreen: More info, Run anyway).
- Tested here: both scripts run (PowerShell 7 + NSIS + 7-Zip on Linux), the portable build runs under Wine (Local
  Conf mode, plugins load, auto-update off, "(64-bit, Pyre909 build)" in About and Debug Info), and the
  installer holds the official installer's files with our exe. Not tested: running the installer (NSIS
  installers are 32-bit; this Wine is 64-bit only) and the first workflow run.

## Next

1. Set the fork's default branch to `pyre` (Settings, General, Default branch). Then Actions, Pyre909 release,
   Run workflow, and check the draft release.
2. On the Windows 11 VM: install the installer over Notepad++, check About / Debug Info, Plugins Admin, the
   Explorer menu, and DirectWrite with "Bahnschrift Light" (Light text, SemiBold bold).
3. Keep `pyre` current: Sync fork on `master`, then merge `master` into `pyre` (`PYRE-BUILD.md` on `pyre` describes
   the build, its releases and updating).
4. Optional: the slimmer #18418, the font-name issue/PR (kit section 5), the live switch PR after #18418.
