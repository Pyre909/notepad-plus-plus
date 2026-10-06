# Review checklist

The AI part of a review (see `README.md`). Give it to an independent reviewer with the scope (`git diff <base>` in
the worktree) and one paragraph on what the change is for, but not your own conclusions. Ask for findings ranked by
severity, each with evidence (file:line, the code path, a way to reproduce) and a concrete fix, then a list of what
was checked and found fine. Every finding is verified before anything is changed.

## 1. Correctness

- Every input and range: combo indexes (`CB_ERR`), enum values, empty documents, huge files, both views, cloned
  documents, macros, multi-instance, a plugin calling the same code.
- Settings: read and written (`config.xml`, `stylers.xml`), the default of a fresh settings folder, an older config,
  portable (`doLocalConf.xml`) and installed, Wine and Windows Server Core (no DirectWrite).
- What the user sees afterwards: menu checks, a combo box or check box after a refused change, tooltips, messages.

## 2. Lifetime and re-entrancy

- Every way an object or window ends: `destroy()`, destruction with its parent window, views of plugins
  (`NPPM_CREATESCINTILLAHANDLE`, `ScintillaCtrls`), Finder, Document Map, shutdown order.
- No pointer kept to a destroyed object or window. `ScintillaEditView::execute` calls Scintilla's direct function:
  a destroyed Scintilla must never be called.
- A modal loop (message box, dialog) runs other code: no iterator or collected pointer used after one; state read
  again afterwards.
- Statics: no order dependence between files at start or exit; UI objects on the UI thread only.

## 3. State derived from other state

- What Notepad++ computes from fonts, text metrics, rendering technology, zoom, DPI or styles: line number margin
  width, Document Map, Finder, smart highlighting, folding margin, edge line, caret, call tips, auto-completion.
- The paths that refresh it (`SCN_PAINTED`, `SCN_ZOOM`, `WM_UPDATESCINTILLAS`, `WM_DPICHANGED`, buffer activation):
  is anything stale after the change until a restart, a scroll or a click?

## 4. Plugins

- The plugin API (`NPPM_*`, `NPPN_*`, Scintilla messages sent by plugins) unchanged, or extended compatibly.
- Plugins that set something themselves (a view's technology, styles, margins) keep it.
- Plugins' docking dialogs and Scintillas.

## 5. Security

- Buffer sizes and string lengths (`wchar_t` vs `char`, terminating NUL), integer overflow, signedness, casts.
- Untrusted input: file contents, the command line, settings XML, plugin messages, the clipboard, the updater.
- Paths (UNC, long paths, `..`), DLL loading, running as administrator.

## 6. Performance

- Work on the UI thread per keystroke, paint or notification; files of 100 MB and more; many tabs; word wrap.

## 7. Upstream conventions (notepad-plus-plus/notepad-plus-plus)

- `CONTRIBUTING.md`: an issue first, `fix #NNNNN` in the pull request; one feature per pull request; a single commit;
  no reformatting, typo fixes or refactoring on the side; coding style (braces on their own line, tabs, spaces
  around binary operators, none between a function name and its parenthesis but one after `if`/`for`/`while`/
  `switch`, C++ casts, `!`/`&&`/`||`, `empty()`, variables initialized with `=` for primitives and enums and `{}`
  otherwise, Pascal case classes, camel case functions, `_member` names).
- The pull request template: small (1 to 4 files and about 30 lines for new contributors), AI use disclosed, tested
  on Windows.
- UI texts: `english.xml` and `english_customizable.xml` changed together, the default texts in the code equal to
  them, the other languages left to translators; texts that describe behaviour (such as "restart") still true.
- No code for Scintilla or Lexilla: its maintainer refuses LLM-generated contributions.

## 8. Fork rules (pyre)

- pyre-only changes small and marked "Pyre909 build"; the version line of `resource.h` untouched; upstream files
  such as `CI_build.yml` untouched; release work in its own files (`.github/pyre/`, `pyre-release.yml`).

## 9. Tests

- What the change needs to be proven on Windows (the ARM64 VM: native ARM64, emulated x64), what the app-level
  tests in `tests\` cover, what isn't covered and why.
