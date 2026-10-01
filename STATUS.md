# Status (2026-10-01)

Where the Notepad++ text rendering, DPI and font work stands: branches, upstream PRs and tickets, the Pyre909
build, and what's next. A Claude Code session starts with `CLAUDE.md` on `pyre` (rules, build, code map). The PR kit with every issue/PR/ticket text is `split/PR-TEXTS.md`; the Scintilla side is
`scintilla/SCINTILLA-UPSTREAM.md`; the tools are described in `README.md`.

## Handoff: the work continues on the Windows VM (2026-10-01)

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
| The font stays the same after the switch (no fallback font) | to confirm from the screenshots |
| With DirectWrite, each Antialiasing choice and DirectWrite mode changes the text at once | to do |
| Default Style "Bahnschrift Light": Light text, SemiBold bold keywords, about the same ink in GDI and DirectWrite | to do |
| "Cascadia Code SemiBold": bold keywords draw Bold | to do |
| Baseline: the font tests with the official 8.9.8.1 ARM64 portable (expect DirectWrite to draw a fallback or wrong weight) | to do |
| Per-monitor DPI (MISC. option, restart; then change Windows' scale while Notepad++ runs, or two displays) | to do |
| Uninstall removes `disableNppAutoUpdate.xml` | skipped: it would remove the working install |

### After the test round

1. Font test passes: in kit section 5 (`split/PR-TEXTS.md`), replace "Not tested: a real Windows font
   collection" with the Windows results, keep the official/fork screenshots as before/after. Pyre909 opens the
   issue, then the PR with `fix #<issue>` (AI disclosure stays). Drafts for Pyre909 to post: casual, their voice.
2. Record each result in `CLAUDE.md` ("What still needs real Windows") on `pyre` and in the table above.
3. Waiting on others: #18418 review (new commits only, no amend/force-push), Scintilla #2520 (keep the guard).
   When #18418 is merged: rebase and open the live-switch PR (kit section 6) and the translations PR (section 3).

## Branches of Pyre909/notepad-plus-plus

| Branch | Head | What |
|---|---|---|
| `master` | `37f76d4` | Mirror of official Notepad++ (kept in sync with GitHub's Sync fork; never add commits here) |
| `pyre` | `d49c16a` | **Your own Notepad++ (the Pyre909 build)**: everything below, the build name in the About box, and the private release workflow (installers + portable zips, x64 and ARM64). The fork's default branch since 2026-10-01 |
| `claude/awesome-darwin-bsud9v` | `357fec9` | The cloud session's branch: the combined development branch, all the features (pyre is built on it) |
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
4. Optional: the slimmer #18418, the font-name issue/PR (kit section 5), the live switch PR after #18418.
