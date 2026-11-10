# Notepad++, Pyre909 build

An unofficial build of [Notepad++](https://notepad-plus-plus.org/) from the `pyre` branch of this fork.
`master` stays an exact copy of official Notepad++; `pyre` is official Notepad++ plus the changes below.
Features that look worthwhile to upstream are offered there as pull requests, one at a time.

## What's different from official Notepad++

- **Needs Windows 10 version 1809 or later** (official Notepad++ runs on older versions too): the build calls
  Windows 10's functions directly, and its installer stops on an older Windows.
- **Text rendering settings** (Preferences > Editing 1 > Text Rendering): the rendering mode (a DirectWrite mode,
  moved here from MISC.), antialiasing (Follow Windows, ClearType, ClearType with less color fringing, Grayscale,
  None), the DirectWrite mode (Automatic, Natural for sharper small text, Symmetric, GDI classic) and the text
  contrast. "Follow Windows" follows the Windows font smoothing with DirectWrite too (official issue #17461), and a
  change of it at once, the ClearType Text Tuner's included.
- **DirectWrite only**: the rendering modes offered are DirectWrite's (its GDI classic mode looks like GDI, its glyphs
  on whole pixels); the font features, weights and fallback fonts above are DirectWrite's. GDI is listed for a setting
  of an older version (to leave it), where DirectWrite isn't available (Wine), or with `offerGdiRendering="yes"` in
  config.xml's MISC settings, written by hand. Right-to-left documents are still drawn with GDI.
- **The tab bar, the panels and the Ctrl+Tab list drawn like the editor**: their text drawn with DirectWrite and the
  Text Rendering settings above (antialiasing, contrast, DirectWrite mode) while the editor is, applied at once when
  they change; the status bar too in dark mode (Windows draws it in light mode, as its menus and dialogs). Vertical
  tabs and right-to-left languages stay with GDI.
- **Line spacing and font ligatures** (Preferences > Editing 1 > Text Rendering): extra space between the lines
  of the editor, +1 to +10 pixels at 100% scale (official issue #971), and the fonts' ligatures, such as the
  arrows and operators of Cascadia Code or Fira Code, turned off when unwanted (DirectWrite; official issue #14764).
- **OpenType font features** (Preferences > Fonts): the features of the editor's font, chosen from a list of the Default
  Style font's own features with the font's names for its stylistic sets (all its weights and styles: MonoLisa's
  "Script variant" is in its italics only), or typed as a list such as `ss01 zero cv05=2 -calt`; applied to every view
  as soon as the typing pauses, drawn with DirectWrite. With MonoLisa, `ss01` turns italic comments into its script, `dlig` brings its
  coding ligatures; with Cascadia Code, `ss01` its cursive italic, `zero` a slashed zero.
- **The weight of bold** (Preferences > Fonts > Bold): Medium, SemiBold, Bold (as official Notepad++), ExtraBold or
  Black for the bold styles (keywords...) of every language at once; a font of another weight is made as many steps
  heavier ("MonoLisaCode Light" bold: Medium with SemiBold). With a font that has these weights (MonoLisa: ten), drawn
  with its own face, GDI and DirectWrite alike; with a font that has no face for a lighter choice (Medium of Consolas,
  whose Regular would draw it), Bold.
- **Fallback fonts** (Preferences > Fonts > Fallback Fonts): the fonts for the characters the editor's font hasn't
  (Chinese, Japanese, Korean, symbols, emoji), tried in order before Windows' own choice: `BIZ UDGothic; Segoe UI
  Emoji`; each is used for the characters it has (a name of the font lists such as "Fira Code Light" is its family).
  Drawn with DirectWrite (GDI uses Windows' font linking).
- **The rendering mode applies at once**, without restarting Notepad++.
- **Faster with long lines and large files**: the layouts of the lines shown are kept between paints (not for a file
  over the large file size of Preferences > Performance), and lines are laid out on several threads. Moving the caret and typing in files with very long lines (minified JSON
  or JavaScript, logs) are up to 30 times faster (official issue #5267); turning word wrap on in a 1,000,000-line
  file is 2 to 2.5 times faster.
- **Replace All that adds or removes lines is much faster**: adding a line to each of 1,000,000 lines took nearly
  3 minutes, about 3 seconds now, also with the document shown in both views; the same for Remove and Cut Bookmarked
  Lines, Remove Unmarked Lines and Remove Consecutive Duplicate Lines (official issue #10301). Copy and Cut Bookmarked
  Lines no longer slow down with the number of lines (100,000 lines: copy 3 s to 18 ms, cut 3.7 s to 0.7 s).
- **No work when Windows changes an unrelated setting**: official Notepad++ restyles and re-wraps its documents at
  every Windows settings broadcast (group policy, environment, taskbar...): 2 seconds of CPU with a large wrapped file
  and the Document Map. Only the settings the editor reads do that now (font smoothing, ClearType, the mouse wheel and
  pointer, high contrast, the theme). With padding
  set, the Document Map no longer re-wraps itself at every paint. The character grid draws a third faster with
  DirectWrite, and the status bar's counts on very long lines take one pass.
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
- **Characters on a grid** (View > Show Symbol > "Show Characters on a Grid", also in the ¶ button's menu, off by
  default): the text on a grid of cells, a cell being the width of a space in whole pixels, so that the same character
  always looks the same, drawn alike in every cell, for comparing lines and finding hidden characters. Every tab is one tab size wide wherever it is, instead of
  reaching the next tab stop, and the labels of control characters, line ends, non-printing characters and invalid bytes
  take whole cells, their text centred. Every character takes the cells Unicode gives it, in any font: Chinese, Japanese,
  Korean and emoji two (also a character followed by the emoji selector U+FE0F, such as a keycap), combining accents
  none (one, on a dotted circle, with no letter before them), the others one; a glyph narrower than its cells is centred
  in them (CJK borrowed from another font), a wider one narrowed (scaled down for emoji). An emoji made of several
  characters shows as its parts (👍🏽 as 👍 and the skin tone); right-to-left and complex scripts show their characters
  one by one, in the order they're stored, and a hidden bidirectional control (RLO) reorders nothing. In a proportional
  font the cell is as wide as its "0"; in an ANSI document every byte is a cell. Columns made with tabs don't line up
  while it's on, and what counts columns other than the status bar still counts them with the tab stops: the Column
  Editor, Go to column (`-c`), Tab and Shift+Tab with spaces. A plugin's own tab stops (Elastic Tabstops) don't apply
  while it's on; printing keeps the tab stops. Hidden control characters stay hidden (no width).
- **Special characters labelled alike**: control characters, line ends, invisible characters (View > Show Symbol > Show
  Non-Printing Characters) and invalid bytes all show as the same kind of label, a box with rounded corners in a font of
  its own (Segoe UI Semibold, three quarters of the text's size), coloured by kind: slate for control characters, teal
  for line ends (NEL, LS and PS too), purple for invisible characters, red for invalid bytes, in tones for a light or a
  dark theme. Their names throughout (BOM rather than ZWNBSP), and the invisible characters Notepad++ didn't label are
  labelled too: the combining grapheme joiner, the Mongolian variation selectors, the Hangul fillers, the musical and
  shorthand formatting characters, the language tag. Preferences' custom colours of non-printing characters and line
  ends still apply.
- **The status bar's caret position, exact** (Preferences > General > Status Bar): with the character grid, Col is the
  cell the caret is in; beside it, the caret's character and byte positions in the line when they differ from it (after
  a tab, an accented or a CJK character; bytes of the file's encoding, UTF-16's too), and a selection's bytes beside its
  characters. "Caret position" shows the column, the offset in the line in hex (0-based, in bytes: `Off: X'24'`), or
  both; "Line length" adds the line's length (with its bytes when they differ), for fixed-length records.
- **Fold markers and highlighting boxes drawn for the scale**: the fold margin's boxes and lines, the change history
  marks, the link underline and the boxes of Mark All, Find and smart highlighting are 2 pixels wide from 150% scale
  (3 from 250%) instead of 1 pixel at any scale.
- **Many files open much faster** (a session of hundreds of files, official issue #14000): 1,000 files in about 8 seconds
  instead of 41, 300 source files of 57 MB in 1.3 instead of 4.4 (ARM64 VM). Each file opened was looked for in the
  tabs several times, one message per tab, and that grew with the square of the number of files.
- **Preferences opens faster**: about 0.56 s instead of 0.75 the first time (ARM64 VM); the Print page's font lists
  are filled when the page is first shown. With several instances open (`-multiInst`), Preferences names the
  languages and encodings from its own instance's menu, not from the one in front, which may be in another language.
- **Per-monitor DPI awareness** (Preferences > MISC., experimental, restart required).
- **Font sizes 1 to 4 pt** in the font size lists, and **half points** in the Style Configurator's (6.5 to 13.5: 10.5
  between 10 and 11), any hundredth in a theme file (`fontSize="10.25"`), saved as chosen.
- **Official bugs fixed** (offered upstream too): tooltips too narrow or too wide in Preferences and the Style
  Configurator after a scale change.
  Crashes: the next key typed after a plugin set a language that doesn't exist (or after a Language menu command for an
  external language with no external lexer installed); the startup with a `-udl=` or `-pluginMessage=` too long and a
  file to open, a user defined language name of more than about 210 characters, or a folder of more than 260 characters
  in config.xml; a plugin reloading a file by a path of 260 characters or more; a translation's string too long for
  the Shortcut Mapper's column names, the Find in Files progress title, the Find All result, or the Folder as Workspace
  and Function List tooltips; a language description of about 250 characters in a theme (Style Configurator); a Folder
  as Workspace root (session file) or a project workspace (config.xml) of 260 characters or more, given with `\\?\`.
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
