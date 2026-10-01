# Notepad++, Pyre909 build

An unofficial build of [Notepad++](https://notepad-plus-plus.org/) from the `pyre` branch of this fork.
`master` stays an exact copy of official Notepad++; `pyre` is official Notepad++ plus the changes below.
Features that look worthwhile to upstream are offered there as pull requests, one at a time.

## What's different from official Notepad++

- **Text rendering settings** (Preferences > Editing 1 > Text Rendering): the rendering mode (GDI or a
  DirectWrite mode, moved here from MISC.), antialiasing (Follow Windows, ClearType, ClearType with less color
  fringing, Grayscale, None), the DirectWrite mode (Automatic, Natural for sharper small text, Symmetric, GDI
  classic, Adaptive) and the text contrast. "Follow Windows" follows the Windows font smoothing with DirectWrite
  too (official issue #17461).
- **The rendering mode applies at once**, without restarting Notepad++.
- **Fonts of a weight draw correctly with DirectWrite**: "Fira Code Light", "Cascadia Code SemiBold" or
  "Bahnschrift Light" are drawn with their own font instead of a fallback font, and bold is the family's next
  heavier font.
- **Per-monitor DPI awareness** (Preferences > MISC., experimental, restart required).
- **Font sizes 1 to 4 pt** in the font size lists.
- **A crash guard** for DirectWrite fonts with an out-of-range weight (Scintilla bug #2520).
- The About box and Help > Debug Info say "(64-bit, Pyre909 build)", so bug reports can't be mistaken for
  ones about the official build.

## Getting a build

Builds are made by the **Pyre909 release** workflow (Actions tab > Pyre909 release > Run workflow, with `pyre`
as the fork's default branch; or push a tag named `pyre-*`). It creates a **draft release**, visible only to
people with push access to the fork, with:

- `npp.<version>.pyre-<commit>.Installer.x64.exe`: installs like official Notepad++, in the same folder and with
  the same settings (it replaces an official installation). It is unsigned, so Windows SmartScreen asks first:
  More info > Run anyway.
- `npp.<version>.pyre-<commit>.portable.x64.zip`: unzip anywhere; settings stay in that folder.
- A `.sha256` file for each.

The plugins, the updater and the Explorer context menu come from the official release of the same version.
Auto-update is off in both (`disableNppAutoUpdate.xml`), so the official updater can't replace this build;
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
