# Notepad++, Pyre909 build

An unofficial build of [Notepad++](https://notepad-plus-plus.org/) from the `pyre` branch of this fork.
`master` stays an exact copy of official Notepad++; `pyre` is official Notepad++ plus the changes below.
Features that look worthwhile to upstream are offered there as pull requests, one at a time.

## What's different from official Notepad++

- **Needs Windows 10 version 1809 or later** (official Notepad++ runs on older versions too): the build calls
  Windows 10's functions directly, and its installer stops on an older Windows.
- **Text rendering settings** (Preferences > Editing 1 > Text Rendering): the rendering mode (GDI or a
  DirectWrite mode, moved here from MISC.), antialiasing (Follow Windows, ClearType, ClearType with less color
  fringing, Grayscale, None), the DirectWrite mode (Automatic, Natural for sharper small text, Symmetric, GDI
  classic) and the text contrast. "Follow Windows" follows the Windows font smoothing with DirectWrite
  too (official issue #17461), and a change of it at once, the ClearType Text Tuner's included.
- **Line spacing and font ligatures** (Preferences > Editing 1 > Text Rendering): extra space between the lines
  of the editor, +1 to +10 pixels at 100% scale (official issue #971), and the fonts' ligatures, such as the
  arrows and operators of Cascadia Code or Fira Code, turned off when unwanted (DirectWrite; official issue #14764).
- **The rendering mode applies at once**, without restarting Notepad++.
- **Faster with long lines and large files**: the layouts of the lines shown are kept between paints (not for a file
  over the large file size of Preferences > Performance), and lines are laid out on several threads. Moving the caret and typing in files with very long lines (minified JSON
  or JavaScript, logs) are up to 30 times faster (official issue #5267); turning word wrap on in a 1,000,000-line
  file is 2 to 2.5 times faster.
- **Replace All that adds or removes lines is much faster**: adding a line to each of 1,000,000 lines took nearly
  3 minutes, about 3 seconds now, also with the document shown in both views; the same for Remove and Cut Bookmarked
  Lines, Remove Unmarked Lines and Remove Consecutive Duplicate Lines (official issue #10301).
- **The Function List 25 to 30 times faster**: about 6 seconds instead of over 3 minutes for 60,000 lines of C++, a
  third of a second instead of 9.5 seconds for 3,000 (its regular expressions match faster and are compiled once); with
  it open, moving the caret takes 17 ms instead of 374 in 60,000 lines with 18,000 functions.
- **Auto-completion faster in large files**: the words are found in one pass over the text: per keystroke in 60,000
  lines of C++, about 6 ms of CPU instead of 50 (case-insensitive: 10 instead of 47).
- **Profile-guided build**: the release exes are optimized from a training run; syntax highlighting is about 19%
  faster, folding and Mark All 17%, word wrap 15% (measured on ARM64).
- **Tall glyphs drawn whole, Chinese and Japanese in their own forms** (DirectWrite): the parts of glyphs taller than
  a line (Burmese, Thai marks, stacked accents) aren't cut off any more (official issues #12446 and #16259), Han
  characters take the forms of the Windows locale's language (official issue #15265), and the Document Map lays out
  tabs like the editor.
- **Fonts of a weight draw correctly with DirectWrite**: "Fira Code Light", "Cascadia Code SemiBold" or
  "Bahnschrift Light" are drawn with their own font instead of a fallback font, and bold is a heavier font of the
  family: SemiBold for a Light font, the heaviest up to Black for a SemiBold one (which GDI alone doesn't embolden).
- **Style Configurator fixes**: a theme of the installation, once saved, no longer comes back unsaved when selected
  again in the same session; a dark mode switch picks its theme by its exact name ("Solarized", not
  "Solarized-light"), and a style's font too; a font name set back to empty is saved (official issue #13919); the
  user keywords typed are applied when the typing pauses, not on each key.
- **Redrawn "Standard icons"** (Preferences > General > Toolbar): the 32 standard toolbar icons drawn again as
  flat vector art, sharp at every scale from 100% to 300% instead of 16x16 bitmaps stretched (official issue
  #16110, where the icons alone are offered).
- **Rounded corners on Windows 11** for the popups Windows leaves square: call tips, the About box, the colour
  picker and the document peeker (Preferences > Dark Mode, on by default).
- **Ctrl+click opens links** (Preferences > Cloud & Link > "Open with Ctrl+click", off by default): a Ctrl+click on a
  link opens it, and a double-click selects a word in it like anywhere else (official issue #9993). A selected link
  is dragged or deselected by a Ctrl+click as before, and a Ctrl+double-click on a link opens it rather than selecting
  between delimiters.
- **The character after the caret in the status bar**: its Unicode code point after the position ("U+00E9",
  "U+1F600"), to tell look-alike or invisible characters apart, or the byte of an invalid UTF-8 sequence ("0xE9")
  (official issue #2056).
- **Word wrap per document** (Preferences > Editing 1 > Line Wrap > "Per document", off by default): View > Word wrap
  wraps the current document only, each document keeps its own wrap (also in the session), and one opened or created
  takes the last choice (official issue #5232).
- **Per-monitor DPI awareness** (Preferences > MISC., experimental, restart required).
- **Font sizes 1 to 4 pt** in the font size lists.
- **A crash guard** for DirectWrite fonts with an out-of-range weight (Scintilla bug #2520).
- **Official bugs fixed** (offered upstream too): a GDI leak at each Mark Style or tab colour change in the Style
  Configurator; the Document List's Ext. and Path columns growing at each layout above 100% scale; tooltips too narrow
  or too wide in Preferences and the Style Configurator after a scale change.
- The About box and Help > Debug Info say "(64-bit, Pyre909 build)", so bug reports can't be mistaken for
  ones about the official build.

## Getting a build

Builds are made by the **Pyre909 release** workflow (Actions tab > Pyre909 release > Run workflow, with `pyre`
as the fork's default branch). It creates a **draft release**, visible only to
people with push access to the fork, with, for x64 and for ARM64 (Windows on ARM, including Windows in Parallels
on an Apple Silicon Mac):

- `npp.<version>.pyre-<commit>.Installer.<x64|arm64>.exe`: installs like official Notepad++, in the same folder
  and with the same settings (it replaces an official installation). It is unsigned, so Windows SmartScreen asks
  first: More info > Run anyway.
- `npp.<version>.pyre-<commit>.portable.<x64|arm64>.zip`: unzip anywhere; settings stay in that folder.
- A `.sha256` file for each.

On Windows on ARM, take the ARM64 files: the x64 ones run there too (emulated), but the Explorer context menu
of an x64 installation doesn't load in the ARM64 Explorer.

The plugins, the updater and the Explorer context menu come from the official release of the same version and
architecture, unmodified. Their source: [mimeTools](https://github.com/npp-plugins/mimetools),
[NppConverter](https://github.com/npp-plugins/converter), [NppExport](https://github.com/chcg/NPP_ExportPlugin), the
updater [WinGUp](https://github.com/gup4win/wingup), the Explorer menu [NppShell](https://github.com/notepad-plus-plus/nppShell).
Auto-update is off in all of them (`disableNppAutoUpdate.xml`), so the official updater can't replace this build;
Plugins Admin still works. To go back to official Notepad++, uninstall this build first (its uninstaller removes
`disableNppAutoUpdate.xml`), or delete that file from the Notepad++ folder after installing the official one.

The workflow and its scripts: `.github/workflows/pyre-release.yml`, `.github/pyre/package.ps1`,
`.github/pyre/installer.ps1`.

## Keeping up with official Notepad++

1. On GitHub, switch to `master` and use **Sync fork**.
2. Merge `master` into `pyre` (a pull request from `master` to `pyre` on the fork works), resolving conflicts
   if any, and let CI run.
3. Run the release workflow for a new build.

The changes here touch few lines that upstream edits often. The version number is left as upstream has it,
and the release scripts read it from `PowerEditor/src/resource.h`.

## License

Like official Notepad++, this build is under the GPL version 3 with Notepad++'s clarifications ([LICENSE](LICENSE),
`license.txt` in every zip and installation). Its source is this repository: each release links to the commit it was
built from. It is not made or endorsed by the Notepad++ project.
