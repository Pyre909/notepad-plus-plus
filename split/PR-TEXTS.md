# Upstream PR kit: issues and pull requests to paste

All branches are in `Pyre909/notepad-plus-plus`. Each one is a single commit on official
`master` (v8.9.8.1, `dd40fe4`), as CONTRIBUTING.md asks; 2 and 3 are rebased on the newer master `37f76d4` (2026-09-27).

| # | Branch | Commit | Files | Exe size (MSVC x64) | What | Needs an approved issue |
|---|---|---|---|---|---|---|
| 1 | `font-size-1pt_20260925` | `faaeb59` | 2 | +0 | Font sizes 1–4 pt in the size lists | #18412; **PR closed, not accepted** |
| 2 | `text-rendering_20260925` | `a485acc` + `bb32194` | 20 + 29 xml | +15 KB | Text Rendering group in Editing 1 | #18414; **PR #18418 open** |
| 3 | `text-rendering-translations_20260925` | `1aa8b0e` | 29 xml | – | Label capitalisation (stacked on 2) | no (`[xml]`) |
| 4 | `per-monitor-dpi_20260925` | `8a0ff70` | 63 | +23 KB | Opt-in per-monitor DPI awareness | yes, discuss first |
| 5 | `directwrite-font-names_20260930` | `6e8579e` | 6 (Notepad++ only) | +16 KB | Fonts of a weight ("Fira Code Light") drawn with DirectWrite | yes (issue text below). Replaces `font-weight-names_20260925` (the Scintilla version, declined by precedent) |
| 6 | `live-rendering-switch_20260930` | `bb32194` + `08cc23b` (on 2) | 4 | small | Rendering mode applied at once, no restart | follow-up of 2 (#18414): open after 2 is merged; `bb32194` could go into 2 now |

Sizes are for the MSVC x64 Release exe that the fork's GitHub Actions CI built for each branch, compared with official master (8,525,312 bytes). All branches pass CI on every job (5 and 6: 13/13 jobs, 2026-09-30). Branch 5 is compared with the fork's master CI build at `37f76d4` (8,525,824 bytes).

**How the split was checked.** Each branch was built and tested on its own (results in each
PR's Testing section). Recombined, the branches give the combined branch back byte for byte,
except where two PRs touch the same lines (see Conflicts): nothing was lost or duplicated.

**Order.** 1 was opened and closed without merging. Open 2 now, linked to its issue #18414:
CONTRIBUTING.md needs the issue `Accepted` before the PR is *merged*, not before it is opened. Then open 3 right after 2 is merged (3 contains 2's commit until then). Open 4
after a maintainer agrees on the approach: upstream already has DPI work in progress, so link
or comment on their existing per-monitor DPI issue first. 5 was first offered to Scintilla (bug #2519), but Scintilla's
maintainer has twice declined font-name mapping in Scintilla (bugs #2080, #2356: "leave implementation choice to the
application"), so it is now a Notepad++-only change: open its issue, then its PR. 6 builds on 2's code: open it after 2
is merged. Its first commit (`bb32194`, the RTL message pointing to Editing 1 instead of MISC) fixes a message that 2
itself makes stale, so it can be pushed to 2 as a new commit now.
The general parts of 2's Scintilla patch go to Scintilla too (same file).

**Conflicts between the PRs.** The PRs merge in any order, except:
- 2 and 4 both change the MISC page layout in `preference.rc`;
- 5 and 6 work together only with one more line: after a live switch, the styles must be set again, because 5's font
  parameters depend on the technology. Whichever of 5 and 6 lands second adds, in the Rendering mode handler of
  `preferenceDlg.cpp`, `::SendMessage(::GetParent(_hParent), WM_UPDATESCINTILLAS, FALSE, 0);` when the technology
  changed (combined branch commit `6317b19`).

Whichever lands second needs a quick rebase. The combined branch
`claude/awesome-darwin-bsud9v` shows the resolved result.

**Before opening.** CONTRIBUTING.md asks you to test each PR at least once. All branches pass the
repository's CI on the fork (official MSVC toolchain). The functional tests ran under Wine,
so run each branch's CI exe on real Windows before opening its PR. The exe is the
`Notepad++.MSVC.x64.Release` artifact of the branch's run in the fork's Actions tab.

**Screenshot for PR 2.** Its body says "screenshot attached": take one of Preferences > Editing 1
on Windows. The Wine test setup greys out the Rendering mode box, so its captures aren't usable.

**`fix #NNNNN`.** Replace it with the issue number. Done for 1 (#18412, PR closed without merging) and 2 (#18414, PR #18418 open); 4 and 5 still need their issues. 6 uses #18414.

**AI.** The template asks to say when AI was used. The texts below say so.

---

## 1. Font sizes 1–4 pt

### Issue — title
`[Feature request] Allow font sizes below 5 pt in Style Configurator`

### Issue — Description of the Issue
The font size lists of Style Configurator and of the User Defined Language dialog start at 5 pt.
Smaller sizes are useful for overview-style themes, for hidden or de-emphasised styles, and at
high zoom-out. They can already be set in a theme file, but not chosen in the dialogs.

When a theme sets a size of 1 pt, Style Configurator shows "10": the size is looked up with a
prefix search (`CB_FINDSTRING`), and "1" matches "10".

### Issue — Describe the solution you'd like
Offer 1, 2, 3 and 4 pt in the size lists, and select a style's size with an exact search
(`CB_FINDSTRINGEXACT`), as the User Defined Language dialog already does.

### PR — title
`Allow font sizes 1 to 4 pt in the font size lists`

### PR — body
```
The font size lists of Style Configurator and of the User Defined Language dialog start at 1 pt instead of 5 pt.

Style Configurator now selects a style's size with an exact search (CB_FINDSTRINGEXACT, as the UDL dialog already does): the prefix search selected "10" for a style of 1 pt.

2 files, 2 lines.

Testing (this branch alone, MinGW-w64 GCC 13 x64 build run under Wine 9):
- Style Configurator with a theme whose Default Style is 1 pt: master lists 5-28 and selects "10"; this branch lists 1-28 and selects "1".
- Clang with MSVC-like warnings (/W4 equivalents) on the changed lines: no warnings. Exe size unchanged.
- GitHub Actions (this repository's CI_build workflow, on the fork): all 13 jobs pass. That covers the MSVC x64/Win32/ARM64 Release and Debug builds, the CMake build, the MinGW and Clang builds, XML validation, and the Function List and URL detection tests.
- <your Windows check: choose 1-4 pt for a style, Save & Close, reopen Style Configurator: the size shows as set>

AI disclosure: this change was written with the help of an AI assistant (Claude), then reviewed and tested.

- [x] I have read contributing guidelines

fix #18412
```

---

## 2. Text rendering settings

Issue: **#18414**, PR: **#18418** (opened 2026-09-28, commit `a485acc`). It is merged only once the issue is `Accepted`. Push review fixes as new commits (CONTRIBUTING.md: no amend + force-push on an open PR).

### Issue — title
`[Feature request] Text rendering options: antialiasing, DirectWrite rendering mode and contrast`

### Issue — Description of the Issue
Text rendering can only be tuned with "Enable smooth font" (Editing 1) and the rendering
technology (MISC.). With DirectWrite, the defaults blur small text vertically. There is no
way to choose grayscale antialiasing (better on OLED and rotated screens) or crisper
GDI-like glyphs, or to raise the contrast of thin fonts.

### Issue — Describe the solution you'd like
A "Text Rendering" group in Preferences > Editing 1:
- **Rendering mode:** GDI or DirectWrite, moved from MISC. Restart required, as before.
- **Antialiasing:** Follow Windows (default), ClearType (replaces "Enable smooth font"),
  ClearType less color fringing, Grayscale, None.
- **DirectWrite mode:** Automatic (default), Natural, Symmetric, GDI classic, Adaptive.
- **Text contrast:** Follow Windows (default), Medium, High, Very high.

With Windows ClearType on (the Windows default), the defaults must draw exactly as today. Under DirectWrite, "Follow Windows" should also honour the Windows font smoothing switch (off or Standard), which today is ignored (#17461).

### Issue — Debug Information
Paste the debug info of your usual (official) Notepad++: ? > Debug Info... > "Copy debug info into clipboard".

### Issue — Anything else?
```
A working implementation is ready, one commit on current master:
https://github.com/notepad-plus-plus/notepad-plus-plus/compare/master...Pyre909:notepad-plus-plus:text-rendering_20260925

- With the default settings and Windows ClearType on, the text is drawn exactly as today.
- It also fixes #17461: under DirectWrite, "Follow Windows" honours the Windows "Smooth edges of screen fonts" switch again, at once and after a restart (checked on Windows).
- May help #17180 (narrower characters with DirectWrite): the "GDI classic" mode measures like GDI, with whole-pixel font sizes and advances.
- It passes the full CI on the fork. It includes a small Scintilla patch (Win32, marked "N++"): private messages 5101/5102 for the DirectWrite rendering parameters.
- Written with the help of an AI assistant (Claude), then reviewed and tested.

Screenshot of the new group in Preferences > Editing 1:
```
Then drag the screenshot in below that last line.

### PR — prefilled link (used: PR #18418 is open)
https://github.com/notepad-plus-plus/notepad-plus-plus/compare/master...Pyre909:notepad-plus-plus:text-rendering_20260925?expand=1&title=Add%20text%20rendering%20settings%3A%20antialiasing%2C%20DirectWrite%20mode%2C%20contrast&body=Preferences%20%3E%20Editing%201%20gets%20a%20%22Text%20Rendering%22%20group%20%28screenshot%20attached%29%3A%0A-%20Rendering%20mode%3A%20GDI%20%2F%20DirectWrite%2C%20moved%20from%20MISC.%20%28restart%20required%2C%20as%20before%29%0A-%20Antialiasing%3A%20Follow%20Windows%20%28default%29%2C%20ClearType%20%28replaces%20%22Enable%20smooth%20font%22%29%2C%20ClearType%20less%20color%20fringing%2C%20Grayscale%2C%20None%0A-%20DirectWrite%20mode%3A%20Automatic%20%28default%29%2C%20Natural%2C%20Symmetric%2C%20GDI%20classic%20%28whole-pixel%20glyphs%2C%20GDI-compatible%20measuring%29%2C%20Adaptive%20%28Natural%20for%20small%20text%29%0A-%20Text%20contrast%3A%20Follow%20Windows%20%28default%29%2C%20Medium%2C%20High%2C%20Very%20high%0ADirectWrite%20mode%20and%20Text%20contrast%20apply%20immediately%20and%20are%20disabled%20with%20GDI.%0A%0ACompatibility%3A%0A-%20With%20the%20default%20settings%20and%20Windows%20ClearType%20on%20%28the%20Windows%20default%29%2C%20the%20text%20is%20drawn%20exactly%20as%20before%20%28the%20same%20font%20quality%20and%20DirectWrite%20rendering%20parameters%29.%0A-%20Fixes%20%2317461%3A%20under%20DirectWrite%2C%20%22Follow%20Windows%22%20now%20honours%20the%20Windows%20%22Smooth%20edges%20of%20screen%20fonts%22%20switch%20%28off%3A%20unsmoothed%20text%2C%20Standard%3A%20grayscale%29%2C%20and%20follows%20it%20when%20it%20changes%3B%20DirectWrite%27s%20default%20quality%20ignored%20it.%20GDI%20already%20followed%20it.%0A-%20config.xml%20still%20writes%20smoothFont%20for%20older%20versions%3B%20smoothFont%3D%22yes%22%20becomes%20ClearType.%0A-%20Advanced%20DirectWrite%20overrides%20in%20config.xml%20%28fontGamma%2C%20fontEnhancedContrast%2C%20fontGrayscaleEnhancedContrast%2C%20fontClearTypeLevel%2C%20fontPixelGeometry%2C%20fontLightTextGamma%3B%20-1%20%3D%20not%20set%29%20are%20range-checked%20and%20listed%20in%20Debug%20Info.%0A%0AScintilla%20%28Win32%20only%2C%20N%2B%2B%20patch%20marked%20%22N%2B%2B%22%29%3A%20private%20SCI_SETFONTRENDERINGPARAMETER%20%2F%20SCI_GETFONTRENDERINGPARAMETER%20%285101%2F5102%29%20set%20the%20DirectWrite%20rendering%20parameters%3B%20GDI-compatible%20measuring%20for%20the%20GDI%20rendering%20modes%3B%20the%20autocompletion%20list%20follows%20the%20editor%20once%20the%20text%20rendering%20is%20changed.%0A%0ATranslations%3A%20the%20existing%20%22rendering%20mode%22%20nodes%20%286362%2F6363%29%20move%20from%20%3CMISC%3E%20to%20%3CScintillas%3E%20with%20their%20control%2C%20otherwise%20NativeLangSpeaker%3A%3AchangeDlgLang%20stops%20at%20the%20missing%20combo%20box%20and%20the%20other%20MISC%20combo%20boxes%20lose%20their%20translation.%20Texts%20are%20unchanged.%0A%0ATesting%20%28this%20branch%20alone%2C%20on%20master%2037f76d4%2C%20MinGW-w64%20GCC%2013%20x64%20build%20run%20under%20Wine%209%20%2B%20Xvfb%29%3A%0A-%20Default%20settings%20draw%20exactly%20as%20before%20%28Windows%20ClearType%20on%29.%20Notepad%2B%2B%20uses%20GDI%20under%20Wine%3A%20there%20the%20main%20window%20and%20docked%20panels%20%28Function%20List%2C%20Document%20Map%29%20are%20pixel-identical%20to%20master%20at%2096%20and%20144%20DPI%2C%20the%20autocompletion%20list%20too.%20With%20DirectWrite%2C%20the%20editor%20gets%20master%27s%20font%20quality%20%28SC_EFF_QUALITY_DEFAULT%29%20and%20no%20rendering%20parameter%20override.%0A-%20%2317461%2C%20Follow%20Windows%20and%20the%20Windows%20font%20smoothing%3A%2014%2F14%20checks.%20DirectWrite%20%28a%20test%20build%20without%20Notepad%2B%2B%27s%20Wine%20check%29%3A%20smoothing%20off%20gives%20SC_EFF_QUALITY_NON_ANTIALIASED%2C%20Standard%20SC_EFF_QUALITY_ANTIALIASED%2C%20ClearType%20SC_EFF_QUALITY_DEFAULT%2C%20at%20startup%20and%20on%20WM_SETTINGCHANGE%20while%20running.%20GDI%3A%20SC_EFF_QUALITY_DEFAULT%20in%20every%20case%2C%20as%20before%20%28GDI%20follows%20Windows%20itself%29.%0A-%20Preferences%3A%2041%2F41%20automated%20checks.%20Every%20item%20of%20the%204%20combo%20boxes%20is%20applied%20while%20Notepad%2B%2B%20stays%20responsive%2C%20and%20Scintilla%27s%20font%20quality%20and%20overrides%20are%20read%20back.%20The%20choices%20persist%20after%20a%20restart%2C%20and%20config.xml%20keeps%20smoothFont.%0A-%20Scintilla%3A%20243%20checks%20passed%2C%200%20failed.%20Messages%205101%2F5102%20accept%20only%20valid%20values%20and%20ignore%20unknown%20parameters.%20Overrides%20survive%20technology%20switches.%20GDI-compatible%20measuring%20gives%20whole-pixel%20advances.%20The%20autocompletion%20list%20and%20call%20tips%20paint%2C%20and%20the%20idle%20messages%20are%20unaffected.%20%28Plus%204%20warnings%3A%20a%20Wine%20call-tip%20repaint%20loop%20that%20master%20shows%20too.%29%0A-%20Translations%3A%20the%2031%20changed%20XML%20files%20parse%3B%20each%20moved%206362%2F6363%20node%20keeps%20its%20text%3B%20no%20translation%20still%20has%20the%20rendering%20mode%20combo%20box%20%286362%29%20or%20label%20%286363%29%20under%20MISC.%0A-%20Clang%20with%20MSVC-like%20warnings%20on%20the%20added%20lines%2C%20with%20and%20without%20DISABLE_D2D%3A%20no%20warnings.%0A-%20GitHub%20Actions%20%28this%20repository%27s%20CI_build%20workflow%2C%20on%20the%20fork%29%3A%20all%2013%20jobs%20pass.%20That%20covers%20the%20MSVC%20x64%2FWin32%2FARM64%20Release%20and%20Debug%20builds%2C%20the%20CMake%20build%2C%20the%20MinGW%20and%20Clang%20builds%2C%20XML%20validation%2C%20and%20the%20Function%20List%20and%20URL%20detection%20tests.%20MSVC%20x64%20exe%20%2B15%20KB.%0A-%20Reviewed%20for%3A%20config.xml%20compatibility%20both%20ways%20%28upgrade%20from%20smoothFont%2C%20downgrade%20to%20older%20versions%29%3B%20range%20checks%20on%20every%20value%20read%20from%20config.xml%20or%20from%20plugins%3B%20tooltip%20and%20font%20lifetimes%3B%20dark%20mode.%0A-%20Windows%2C%20DirectWrite%2C%20Antialiasing%20Follow%20Windows%20%28%2317461%29%3A%20unticking%20%22Smooth%20edges%20of%20screen%20fonts%22%20turns%20the%20text%20unsmoothed%20at%20once%20and%20after%20a%20restart%3B%20ticking%20it%20again%20draws%20it%20as%20before.%0A-%20Not%20tested%20on%20real%20Windows%20beyond%20that%3A%20the%20other%20antialiasing%2C%20DirectWrite%20mode%20and%20contrast%20choices%20%28Wine%27s%20DirectWrite%20differs%29.%0A%0AAI%20disclosure%3A%20this%20change%20was%20written%20with%20the%20help%20of%20an%20AI%20assistant%20%28Claude%29%2C%20then%20reviewed%20and%20tested.%0A%0A-%20%5Bx%5D%20I%20have%20read%20contributing%20guidelines%0A%0Afix%20%2318414%2C%20fix%20%2317461

### PR — title
`Add text rendering settings: antialiasing, DirectWrite mode, contrast`

### PR — body
```
Preferences > Editing 1 gets a "Text Rendering" group (screenshot attached):
- Rendering mode: GDI / DirectWrite, moved from MISC. (restart required, as before)
- Antialiasing: Follow Windows (default), ClearType (replaces "Enable smooth font"), ClearType less color fringing, Grayscale, None
- DirectWrite mode: Automatic (default), Natural, Symmetric, GDI classic (whole-pixel glyphs, GDI-compatible measuring), Adaptive (Natural for small text)
- Text contrast: Follow Windows (default), Medium, High, Very high
DirectWrite mode and Text contrast apply immediately and are disabled with GDI.

Compatibility:
- With the default settings and Windows ClearType on (the Windows default), the text is drawn exactly as before (the same font quality and DirectWrite rendering parameters).
- Fixes #17461: under DirectWrite, "Follow Windows" now honours the Windows "Smooth edges of screen fonts" switch (off: unsmoothed text, Standard: grayscale), and follows it when it changes; DirectWrite's default quality ignored it. GDI already followed it.
- config.xml still writes smoothFont for older versions; smoothFont="yes" becomes ClearType.
- Advanced DirectWrite overrides in config.xml (fontGamma, fontEnhancedContrast, fontGrayscaleEnhancedContrast, fontClearTypeLevel, fontPixelGeometry, fontLightTextGamma; -1 = not set) are range-checked and listed in Debug Info.

Scintilla (Win32 only, N++ patch marked "N++"): private SCI_SETFONTRENDERINGPARAMETER / SCI_GETFONTRENDERINGPARAMETER (5101/5102) set the DirectWrite rendering parameters; GDI-compatible measuring for the GDI rendering modes; the autocompletion list follows the editor once the text rendering is changed.

Translations: the existing "rendering mode" nodes (6362/6363) move from <MISC> to <Scintillas> with their control, otherwise NativeLangSpeaker::changeDlgLang stops at the missing combo box and the other MISC combo boxes lose their translation. Texts are unchanged.

Testing (this branch alone, on master 37f76d4, MinGW-w64 GCC 13 x64 build run under Wine 9 + Xvfb):
- Default settings draw exactly as before (Windows ClearType on). Notepad++ uses GDI under Wine: there the main window and docked panels (Function List, Document Map) are pixel-identical to master at 96 and 144 DPI, the autocompletion list too. With DirectWrite, the editor gets master's font quality (SC_EFF_QUALITY_DEFAULT) and no rendering parameter override.
- #17461, Follow Windows and the Windows font smoothing: 14/14 checks. DirectWrite (a test build without Notepad++'s Wine check): smoothing off gives SC_EFF_QUALITY_NON_ANTIALIASED, Standard SC_EFF_QUALITY_ANTIALIASED, ClearType SC_EFF_QUALITY_DEFAULT, at startup and on WM_SETTINGCHANGE while running. GDI: SC_EFF_QUALITY_DEFAULT in every case, as before (GDI follows Windows itself).
- Preferences: 41/41 automated checks. Every item of the 4 combo boxes is applied while Notepad++ stays responsive, and Scintilla's font quality and overrides are read back. The choices persist after a restart, and config.xml keeps smoothFont.
- Scintilla: 243 checks passed, 0 failed. Messages 5101/5102 accept only valid values and ignore unknown parameters. Overrides survive technology switches. GDI-compatible measuring gives whole-pixel advances. The autocompletion list and call tips paint, and the idle messages are unaffected. (Plus 4 warnings: a Wine call-tip repaint loop that master shows too.)
- Translations: the 31 changed XML files parse; each moved 6362/6363 node keeps its text; no translation still has the rendering mode combo box (6362) or label (6363) under MISC.
- Clang with MSVC-like warnings on the added lines, with and without DISABLE_D2D: no warnings.
- GitHub Actions (this repository's CI_build workflow, on the fork): all 13 jobs pass. That covers the MSVC x64/Win32/ARM64 Release and Debug builds, the CMake build, the MinGW and Clang builds, XML validation, and the Function List and URL detection tests. MSVC x64 exe +15 KB.
- Reviewed for: config.xml compatibility both ways (upgrade from smoothFont, downgrade to older versions); range checks on every value read from config.xml or from plugins; tooltip and font lifetimes; dark mode.
- Windows, DirectWrite, Antialiasing Follow Windows (#17461): unticking "Smooth edges of screen fonts" turns the text unsmoothed at once and after a restart; ticking it again draws it as before.
- Not tested on real Windows beyond that: the other antialiasing, DirectWrite mode and contrast choices (Wine's DirectWrite differs).

AI disclosure: this change was written with the help of an AI assistant (Claude), then reviewed and tested.

- [x] I have read contributing guidelines

fix #18414, fix #17461
```

---

## 3. Translations follow-up (open after 2 is merged)

### PR — title
`[xml] Capitalise the rendering mode label, now before its combo box`

### PR — body
```
Follow-up of #18418: the "rendering mode" text (id 6363) used to follow its combo box on the MISC. page; it is now a label before the combo box in Editing 1 > Text Rendering ("Rendering mode:"). The 29 translations get a capital letter and their language's colon ("Largeur :" style for French, full-width colon for Hong Kong Cantonese and Taiwanese Mandarin). Swedish "som renderingsläge" ("as rendering mode") becomes "Renderingsläge:", and Tamil, which had the English text, gets the English label. No other change.

Translators, please correct any wording that doesn't read naturally as a label.

Testing: the 29 files parse (XML), and the repository's CI XML validation passes; one Item text changed per file, encoding and line endings kept.

AI disclosure: prepared with the help of an AI assistant (Claude).
```

Before opening, rebase it onto master once PR 2 (#18418) is merged: `git rebase --onto upstream/master
a485acc text-rendering-translations_20260925` (drops PR 2's original commit, whatever review commits followed it).

---

## 4. Per-monitor DPI awareness (discuss first)

### Issue — title
`[Feature request] Opt-in per-monitor DPI awareness (sharp GUI on monitors of different scaling)`

### Issue — Description of the Issue
Notepad++ is system DPI aware. On a monitor whose scaling differs from the primary one,
Windows bitmap-stretches the whole window, so text and icons are blurry.

### Issue — Describe the solution you'd like
An experimental, opt-in setting (MISC., restart required, off by default) that makes the GUI
thread per-monitor v2 DPI aware. The main window, the panels and the dialogs then rescale on
WM_DPICHANGED. When it's off, nothing changes.

### PR — title
`Add opt-in per-monitor DPI awareness (experimental)`

### PR — body
```
Preferences > MISC. > "Per-monitor DPI awareness (experimental, restart required)": off by default, disabled before Windows 10 1703. When off, Notepad++ stays system DPI aware and behaves exactly as before (every new code path is gated).

When on, the GUI thread is per-monitor v2 DPI aware (SetThreadDpiAwarenessContext; the manifest is unchanged), so Notepad++ is drawn sharp on every monitor. These follow DPI changes: main window, toolbar, tabs, status bar, editor margins and markers, splitters, docked and floating panels (Function List, Folder as Workspace, Project, Document List, Character panel, Clipboard History, Search results, Document Map, docked UDL), incremental search bar and dialogs. Saved window and panel sizes are kept at startup on a monitor of another DPI.

Not covered: plugin panels (they depend on the plugin).

63 files, mostly one rescale hook per panel; shared helpers in DPIManagerV2 and ImageListSet.

Testing (this branch alone, MinGW-w64 GCC 13 x64 build run under Wine 9 + Xvfb, 96 and 144 DPI):
- Option off: the main window and docked panels are pixel-identical to master (the caret aside).
- Option on (the thread becomes per-monitor aware under Wine too): at the same DPI the screenshots are also identical to master (the caret aside). The following all passed: docking a clone view, Function List and Document Map; synthetic WM_DPICHANGED 144->96->144 and WM_DPICHANGED_AFTERPARENT to every Scintilla (editor margins rescaled); clean exit (8/8 checks per run).
- Clang with MSVC-like warnings on the added lines of the 33 changed .cpp files: no warnings.
- GitHub Actions (this repository's CI_build workflow, on the fork): all 13 jobs pass. That covers the MSVC x64/Win32/ARM64 Release and Debug builds, the CMake build, the MinGW and Clang builds, XML validation, and the Function List and URL detection tests. MSVC x64 exe +23 KB.
- Reviewed for: every new code path gated when off; fonts, image lists and bitmaps replaced before the old ones are deleted, and freed once; no DPI of 0; plugin API unchanged (tTbData, NPPM_*).
- Not tested: real multi-monitor Windows with different scaling (the main case to try), plugin panels.

AI disclosure: this change was written with the help of an AI assistant (Claude), then reviewed and tested.

- [x] I have read contributing guidelines

fix #NNNNN
```

---

## 5. Fonts of a weight ("Fira Code Light") under DirectWrite, done by Notepad++

Branch `directwrite-font-names_20260930`, commit `6e8579e` on master `37f76d4`, 6 files (+491 −18): the new
`ScintillaComponent/FontFamilyNames.cpp/.h` (listed in CMakeLists.txt and notepadPlus.vcxproj; the GCC makefile finds
it by itself) and `ScintillaEditView::setSpecialStyle`. No Scintilla change.

Why not Scintilla: its maintainer declined this twice (bug #2080 in 2019, bug #2356 with merge request 36 in 2022:
"encodes a particular policy for font naming", "the application can adjust these parameters itself using
IDWriteGdiInterop"). Scintilla bug #2519 (our ticket) points there; this branch is that application-side fix.

### Issue — title
`DirectWrite draws fonts of a weight such as "Fira Code Light" or "Cascadia Code SemiBold" with a fallback font`

### Issue — Description of the Issue
The font lists in the Style Configurator show GDI family names. When a family has more weights or widths than
regular and bold, GDI names each of them as its own family: "Fira Code Light", "Cascadia Code SemiBold",
"Bahnschrift SemiBold SemiConden" (truncated to 31 characters). DirectWrite only knows the family "Fira Code" with
a Light weight, so with a DirectWrite rendering mode, text in these fonts is drawn with a fallback font.

Steps: install Fira Code (or use Bahnschrift Light, part of Windows 10/11), pick it as the font of the Default Style
in Settings > Style Configurator, and choose a DirectWrite rendering mode. The text is drawn in another font. With GDI,
it is drawn correctly, but bold of a light font is a fake bold of the light font.

### Issue — Describe the solution you'd like
Notepad++ gives Scintilla the font as DirectWrite knows it: the family name with its weight, width and style
(SCI_STYLESETWEIGHT / SCI_STYLESETSTRETCH exist for this). Bold is relative to the font's own weight, as GDI does
it. Scintilla's maintainer leaves this to the application (Scintilla bugs #2080, #2356).

### PR — title
`Draw the fonts of a weight such as "Fira Code Light" with DirectWrite`

### PR — body
```
The font lists show GDI family names, which name a weight or width when a family has more than regular and bold ("Fira Code Light", "Cascadia Code SemiBold", "Bahnschrift SemiBold SemiConden"). DirectWrite only knows the family ("Fira Code"), so with a DirectWrite rendering mode these fonts were drawn with a fallback font.

Notepad++ now sets each style with the font parameters of the rendering technology in use (new FontFamilyNames.cpp, called by ScintillaEditView::setSpecialStyle):
- DirectWrite: the font's DirectWrite family, weight, width and style (SCI_STYLESETWEIGHT, SCI_STYLESETSTRETCH). Bold is relative to the font's weight, as GDI emboldens it: bold of "Fira Code Light" is "Fira Code" SemiBold.
- GDI: the GDI family name with the weight GDI knows its font by. Bold uses the same font as DirectWrite when the family has one (bold of "Fira Code Light" is "Fira Code SemiBold" instead of a fake bold).
- The usual fonts ("Consolas", "Courier New") are unchanged: same Scintilla calls as before.
- DirectWrite is loaded when first needed (no new link dependency). Results are cached per font name for the session. Raster fonts are left as they are.
- Styles without their own font name or font style use the ones SCI_STYLECLEARALL gave them (new clearAllStyles), so their bold and italic are relative to the right font.

This is done in Notepad++ rather than Scintilla: Scintilla's maintainer leaves font naming to the application (Scintilla bugs #2080, #2356).

Testing (MinGW-w64 GCC 13 x64 build, run under Wine 9):
- Font check: every font-list name, regular, bold and italic, drawn by unmodified Scintilla 5.6.6 with the parameters this code gives, compared with the font Windows maps the name to. Test fonts: static families (31-character truncated names, duplicate weights, a legacy family, heavy-only and semibold-only families) and Fira Code. 35 names: 0 failures with DirectWrite and GDI (before: 51 failures). The 7 warnings are bold of families with no heavier font.
- In Notepad++, with "Fira Code Light" as the Default Style font: the styles read back "Fira Code" weight 300 (bold 600) with DirectWrite, and "Fira Code Light" weight 300 (bold "Fira Code SemiBold") with GDI. DirectWrite was tested with a build whose Wine check (ScintillaEditView::init) was disabled; that change is not in this PR.
- Default theme: screenshots of the main window and a docked panel at 96 and 144 DPI are pixel-identical to master.
- No new warnings with the repository's GCC flags (-Wpedantic -Wall -Wextra -Wconversion).
- GitHub Actions (this repository's CI_build workflow, on the fork): all 13 jobs pass: MSVC x64/Win32/ARM64 Release and Debug, the CMake build, the MinGW and Clang builds. MSVC x64 exe +16 KB.
- Not tested: a real Windows font collection. Please try Bahnschrift Light or Cascadia Code SemiBold with DirectWrite.

AI disclosure: this change was written with the help of an AI assistant (Claude), then reviewed and tested.

- [x] I have read contributing guidelines

fix #NNNNN
```

Before opening, check on Windows with the branch's CI exe (`Notepad++.MSVC.x64.Release` artifact of its run in the fork's Actions tab):
Default Style font "Bahnschrift Light", Rendering mode DirectWrite: the text must be drawn in Bahnschrift Light,
and bold keywords in Bahnschrift SemiBold (they were a fallback font before).

---

## 6. Rendering mode applied at once, without restarting (follow-up of 2)

Branch `live-rendering-switch_20260930` (pushed, CI 13/13 jobs), two commits on 2 (`a485acc`):
- `bb32194` "Point the RTL vs DirectWrite message to Editing 1": 2 moves the Rendering mode box from MISC to
  Editing 1, so the existing message "Please disable DirectWrite mode in MISC. section" becomes wrong with 2 alone.
  It belongs in 2: **pushed to `text-rendering_20260925` on 2026-09-30** as a new commit (fast-forward, no force-push).
- `08cc23b` "Apply the rendering mode at once, without restarting": the feature. Open it after 2 is merged, or
  add it to 2 if the reviewer prefers (it is 4 files, +61 −6).

**Decision (2026-09-30): a follow-up PR, opened after #18418 is merged**, so #18418 stays as reviewed. Both
branches are pushed. When #18418 is merged, rebase this branch onto master and open the PR:

```sh
git fetch upstream master
# bb32194 went into #18418, so only 08cc23b is replayed:
git rebase --onto upstream/master bb32194 live-rendering-switch_20260930
```

If #18418 is merged as one squashed commit, the rebase replays only this PR's commits; rebuild and rerun
`techswitch.sh` before pushing (a rebased branch with no PR open yet can be force-pushed).

Comment for #18418 now that bb32194 is pushed there (optional, helps the reviewer):
```
I pushed a small commit: the message shown when RTL is asked with DirectWrite still pointed to the MISC. section, where the rendering mode no longer is. It now names the GDI rendering mode in Editing 1.

A follow-up is ready on my fork (branch live-rendering-switch_20260930): the rendering mode applies at once, without restarting. I'll open it once this PR is merged, to keep this one as reviewed.
```

### PR — title
`Apply the rendering mode at once, without restarting`

### PR — body
```
Follow-up of #18418. Choosing a rendering mode in Preferences > Editing 1 now switches the Notepad++ edit views at once (main and second view, search results, document map), instead of after a restart.
- Views whose technology a plugin changed itself are left as they are: only the views using the technology of the setting follow it.
- The "Follow Windows" antialiasing is applied again, as it depends on the technology.
- DirectWrite can't draw right-to-left text: choosing DirectWrite while a view shows RTL text is refused with a message, and the box shows the rendering mode in use again.
- The tooltip and the RTL message no longer ask to restart.

Testing (MinGW-w64 GCC 13 x64 build under Wine 9; test build with the Wine check of ScintillaEditView::init disabled so that DirectWrite can be chosen, not part of this PR): a probe drives the Rendering mode box and reads each view's technology and font quality. 9/9 checks pass:
- GDI → DirectWrite → DirectWrite (draw to GDI DC) → GDI switch every view, with the matching antialiasing;
- a view a plugin set to another technology is left alone;
- with RTL text, DirectWrite is refused with the message and the box shows GDI again; after LTR, DirectWrite applies;
- config.xml saves the chosen mode.
nppshot and screenshot comparisons at 96 and 144 DPI: unchanged.

AI disclosure: this change was written with the help of an AI assistant (Claude), then reviewed and tested.

- [x] I have read contributing guidelines

fix #18414
```

With 5 merged too, add the restyle line (see Conflicts above), so that fonts such as "Fira Code Light" follow the
switch. Tested on the combined branch: DirectWrite → GDI → DirectWrite gives "Fira Code" 300/600, then
"Fira Code Light" 300 / "Fira Code SemiBold", then "Fira Code" 300/600 again.

Translations: other languages' tooltip and RTL message still mention the restart until translators update them.

---

# Appendix: contributing the Scintilla changes upstream

The reviewer on #18418 is right: every Scintilla change Notepad++ carries has to be re-applied by hand
at each Scintilla upgrade. Notepad++ already does this for its own patches (about 200 changed lines
against pristine Scintilla 5.6.6 today, e.g. `SCFIND_CXX11REGEX`), and our PRs would multiply that by
about five (PR 2: ~450 lines, PR 5: ~450 lines). The goal is to move everything that has a general
effect into Scintilla itself, so Notepad++ gets it with a normal Scintilla update.

Scintilla does **not** take SourceForge merge requests. Its CONTRIBUTING says fixes go to the Bug Tracker,
features to the Feature Request Tracker, both as unified diffs, and questions to the scintilla-interest
mailing list. Code must build as C++17 and follow https://www.scintilla.org/SciCoding.html.

## What is general and what is Notepad++-specific

| Change | Effect | Where it goes |
|---|---|---|
| GDI weight family names ("Fira Code Light") under DirectWrite, real bold under GDI | Filed as Scintilla bug #2519; the maintainer declined this twice before (#2080, #2356) | **Withdrawn from Scintilla**: now Notepad++ PR 5, no Scintilla change (see section 2 below) |
| Crash: `FontDirectWrite::HFont` with no text format (a weight DirectWrite refuses, then the autocompletion list) | Bug in every Win32 app using DirectWrite | **Scintilla Bug Tracker** (section 4 below, 3-line patch). Kept in the combined branch meanwhile |
| DirectWrite rendering-parameter overrides: gamma, enhanced contrast, grayscale enhanced contrast, ClearType level, pixel geometry, rendering mode (PR 2) | New Win32 API, useful to any app (SciTE could expose it as properties) | **Feature Request, patch ready and tested** (section 3) |
| GDI-compatible measuring for the GDI rendering modes (PR 2) | Correctness part of the above: caret and selection match the drawn glyphs | Same proposal |
| Autocompletion list drawn with the editor's parameters once they are customised (PR 2) | Consistency part of the above | Same proposal |
| Adaptive mode (Natural for small text) and light-text gamma (PR 2) | Heuristics with chosen thresholds (20 px, colour intensity 0.5) | Keep in N++ for now; offer later, once the API exists |
| Private message numbers 5101/5102 (PR 2) | N++-only by design: outside Scintilla's range, so they can't collide with future official messages | Replaced by the official messages once Scintilla has them |

If Scintilla accepts the proposal, the next Scintilla update brings the API. Notepad++ then switches
from 5101/5102 to the official messages and drops the local patch in a small follow-up. The settings
stored in config.xml don't change, because the proposal keeps the same units.

---

## 1. Reply for #18418 (post as a comment)

```
Thanks, good point. Notepad++ already re-applies its own Scintilla patches at each upgrade (about 200 changed lines against pristine 5.6.6), and I've kept this PR's Scintilla part marked "N++" so it can be re-applied the same way. But I agree the less Notepad++ carries, the better, so I'm taking the general parts upstream:

1. The DirectWrite rendering-parameter overrides are general: gamma, contrast, ClearType level, pixel geometry and rendering mode are exactly what IDWriteFactory::CreateCustomRenderingParams takes, and Scintilla already builds custom parameters from the Windows ClearType contrast. The same goes for GDI-compatible measuring for the GDI rendering modes, and for the autocompletion list using the editor's parameters. I'm proposing them on the scintilla-interest list / feature request tracker (Scintilla's CONTRIBUTING asks not to use SourceForge merge requests). If they're accepted, this PR's local patch shrinks to the small-text and light-text heuristics, which I can offer upstream afterwards.
2. A separate Scintilla-only fix (GDI weight family names like "Fira Code Light" draw with a fallback font under DirectWrite) goes straight to the Scintilla bug tracker, so it will never need a Notepad++ patch.

Until then the patch stays here, marked N++. Scintilla 5.6.7 (released 2026-09-28) changes none of the files it touches, so the next upgrade would re-apply it as is. The private message numbers (5101/5102) are outside Scintilla's range, so they can't collide with future official messages.
```

---

## 2. Scintilla Bug Tracker: GDI weight family names (filed as #2519, now withdrawn)

zufuliu answered on #2519 with the earlier tickets (#2080, #2356, feature request #1452), where the maintainer declined
this mapping in Scintilla. The mapping now lives in Notepad++ (PR 5), so the patch below is withdrawn. Reply
suggested for #2519 (if not posted yet):

```
Thanks, and sorry for the duplicate: SourceForge's search didn't work for me, so I missed #2080 and #2356. Following Neil's earlier answers, I've withdrawn the patch and moved the mapping into the application (Notepad++), using SCI_STYLESETWEIGHT and SCI_STYLESETSTRETCH with IDWriteGdiInterop, as suggested in #2356. This ticket can be closed.

Would a short note under SCI_STYLESETFONT in ScintillaDoc.html be welcome, saying that DirectWrite takes family names ("Fira Code" with SCI_STYLESETWEIGHT 300) where GDI takes typeface names ("Fira Code Light")? Also, a small typo in the SCI_STYLESETSTRETCH paragraph: "The weight is a number between 1 and 9" should say stretch.
```

The original ticket text follows for reference.

Before posting, search for an existing report (I couldn't search from here, SourceForge refused):
https://sourceforge.net/p/scintilla/bugs/search/?q=DirectWrite+font+name and
https://sourceforge.net/p/scintilla/bugs/search/?q=font+weight

New ticket: https://sourceforge.net/p/scintilla/bugs/new/
Attach: `scintilla-5.6.7-gdi-weight-family-names.diff` (against Scintilla 5.6.7, applies with `git apply`,
`patch -p1` or `hg import`).

### Title
`[Win32] GDI family names of a weight ("Fira Code Light") draw with a fallback font under DirectWrite; GDI fakes their bold`

### Description
```
Font lists built with EnumFontFamiliesEx give GDI family names (the fonts' Win32 family name, name ID 1). For families with weights other than regular and bold, or with other stretches, these names include the weight or stretch: "Fira Code Light", "Fira Code Medium", "Bahnschrift SemiBold SemiConden" (GDI truncates names to 31 characters). Applications store these names in their styles, so Scintilla receives them as font names.

1. DirectWrite only knows typographic family names ("Fira Code"). CreateTextFormat with "Fira Code Light" doesn't find the family and draws with a fallback font: the text changes font entirely when switching to a DirectWrite technology.
2. Under GDI, bold of such a family is synthesised (emboldened) instead of using the family's real heavier font. For monospaced fonts this widens every glyph by a pixel, so columns no longer line up with regular text.

The attached patch (against 5.6.7, win32 only):
- SurfaceD2D: a family name DirectWrite doesn't find is matched to its DirectWrite family, weight, stretch and style through the fonts' Win32 family names (including the 31-character truncation), else through IDWriteGdiInterop::CreateFontFromLOGFONT when that doesn't simulate. The requested weight is applied relative to the matched weight, as GDI does. Matches are cached per name. HFont() of such a font gives GDI its GDI name back.
- SurfaceGDI: bold (and other weights) of a GDI weight family uses the family's real font closest to the requested weight when there is one (GdiLogFont), else GDI's synthesis as before.
- ScintillaWin: the IME composition font uses the same mapping.

Names DirectWrite already knows ("Fira Code", "Consolas") take the unchanged path.

Test: a Scintilla window drawing "iiiii" and "WWWWW" in each family name, regular and bold, GDI and DirectWrite, with width and total ink (darkness) measured, Wine 9, 96 DPI:

  font               bold  tech         5.6.7              5.6.7 + patch
  Fira Code Light    no    DirectWrite  nothing drawn(*)   ink 884748   (GDI: 884589)
  Fira Code Light    yes   DirectWrite  nothing drawn(*)   ink 1564539  (GDI: 1565508)
  Fira Code Medium   no    DirectWrite  nothing drawn(*)   ink 1377513  (GDI: 1377529)
  Fira Code Light    yes   GDI          width 70 (faked)   width 65, ink 1565508 (a real heavier font)
  Fira Code Medium   yes   GDI          width 70 (faked)   width 65
  Fira Code          any   both         unchanged          unchanged

  (*) Wine draws nothing for an unknown family; Windows draws a fallback font.

Builds with g++ --std=c++17 -Wpedantic -Wall -Wextra without warnings; scripts/HeaderCheck.py is clean; Scintilla.dll links with MinGW-w64. The same code has been used in Notepad++ builds, tested with static and variable fonts and their named instances, and on Windows ("Bahnschrift Light" with DirectWrite draws its Light weight).

This patch was prepared with the help of an AI assistant (Claude), then reviewed and tested.
```

Windows check done: "Bahnschrift Light" with DirectWrite draws its Light weight (in the description).

---

## 3. Scintilla Feature Request: DirectWrite rendering parameters (patch ready)

New ticket: https://sourceforge.net/p/scintilla/feature-requests/new/ (search first:
https://sourceforge.net/p/scintilla/feature-requests/search/?q=DirectWrite+rendering)

(Filed.) With the weight-names patch withdrawn, only the first variant matters; if both were attached, a comment can
say the second one is no longer needed.

Attach one of:
- `scintilla-5.6.7-directwrite-rendering-parameters.diff`: applies to pristine 5.6.7 on its own.
- `scintilla-5.6.7-directwrite-rendering-parameters-after-weight-names.diff`: the same change for a tree
  that already has the weight-names fix (section 2). The two patches edit the same DirectWrite font
  constructor, so whichever is applied second needs this variant. File the bug fix first, then this one.

Both variants: 11 files, +440 −30 (285 lines of Win32 implementation, the rest iface entries, generated
headers and documentation). Checked: applies with `patch -p1` / `git apply`; builds as C++17 with
`-Wpedantic -Wall -Wextra` without warnings, also with DISABLE_D2D; HeaderCheck.py and CheckMentioned.py
clean; with the weight-names fix applied too, both test suites give the same results.

Before posting (recommended): run checks 2 and 3 of TESTING.txt in the `npp-msvc-2-text-rendering-a485acc`
build on Windows, which carries the same Scintilla code. Pick DirectWrite, then try each DirectWrite mode
and Text contrast level: text should change at once, and "GDI classic" should look like GDI's glyphs.
Then replace the `<Windows: ...>` line of the description with what you saw, or delete it.

### Title
`[Win32] Add SCI_SETFONTRENDERINGPARAMETER to set DirectWrite rendering parameters (gamma, contrast, ClearType level, pixel geometry, rendering mode)`

### Description
```
On Win32 with DirectWrite, Scintilla draws text with the monitor's rendering parameters (CreateMonitorRenderingParams) and, for ClearType, a custom set whose gamma comes from SPI_GETFONTSMOOTHINGCONTRAST. Applications can't adjust them, but users ask for it: DirectWrite's default rendering mode for small text (natural symmetric) antialiases vertically, which blurs small text compared with GDI; thin fonts look faint; OLED and rotated screens need grayscale or a different pixel geometry. Notepad++ has a feature request and implementation for this (https://github.com/notepad-plus-plus/notepad-plus-plus/issues/18414, https://github.com/notepad-plus-plus/notepad-plus-plus/pull/18418), and a reviewer there suggested that it belongs in Scintilla.

The attached patch (against 5.6.7) adds, for Windows:

  set void SetFontRenderingParameter=2822(FontRenderingParameter parameter, int value)
  get int GetFontRenderingParameter=2823(FontRenderingParameter parameter,)

The parameters SC_FONTRENDERING_GAMMA, _ENHANCEDCONTRAST, _GRAYSCALEENHANCEDCONTRAST, _CLEARTYPELEVEL, _PIXELGEOMETRY and _RENDERINGMODE map onto the arguments of IDWriteFactory::CreateCustomRenderingParams, in integer units Windows already uses:
- gamma in thousandths, 1000..2200 (as SPI_GETFONTSMOOTHINGCONTRAST);
- enhanced contrasts in hundredths, 0..1000;
- ClearType level in percent, 0..100;
- pixel geometry SC_PIXELGEOMETRY_FLAT, _RGB, _BGR (the DWRITE_PIXEL_GEOMETRY values);
- rendering mode SC_RENDERINGMODE_DEFAULT, _GDICLASSIC, _GDINATURAL, _NATURAL, _NATURALSYMMETRIC (the DWRITE_RENDERING_MODE values; aliased and outline are excluded).
SC_FONT_RENDERING_DEFAULT (-1) restores the monitor's value, which is also what GetFontRenderingParameter returns for a parameter not set. Out-of-range values are ignored. Values not set keep the monitor's values and the ClearType contrast still applies unless the gamma is set, so nothing changes until an application sets something. Values are kept when the technology changes and only affect the DirectWrite technologies.

Related behaviour:
- With the GDI rendering modes, text is also measured with GDI-compatible layouts (CreateGdiCompatibleTextLayout) and a whole-pixel font height, so caret and selection positions match the glyphs as drawn. Only while GDI scaling is not active (device scale factor 1). The measuring mode is carried in two bits of the font quality above SC_EFF_QUALITY_MASK, which SCI_SETFONTQUALITY preserves and SCI_GETFONTQUALITY hides, so fonts are realised and cached per measuring mode.
- Aliased text (SC_EFF_QUALITY_NON_ANTIALIASED) keeps the monitor's parameters, as a rendering mode set by the application can be incompatible with aliased drawing.
- The autocompletion list draws with the editor's parameters once the application customises text rendering (a font quality other than default, or a parameter set); otherwise it is drawn as before.

No new platform requirement: the patch uses the IDWriteRenderingParams1 / CreateCustomRenderingParams calls Scintilla already makes, plus CreateGdiCompatibleTextLayout.

Scintilla.iface entries, headers regenerated with HFacer.py and ScintillaAPIFacer.py, and ScintillaDoc.html documentation are included. Names and message numbers are suggestions. If you prefer the element colour pattern (a Reset message instead of -1), that is an easy change.

Testing (MinGW-w64 g++, Wine 9):
- g++ --std=c++17 -Wpedantic -Wall -Wextra: no warnings, also with DISABLE_D2D. HeaderCheck.py and CheckMentioned.py are clean.
- A test program driving a Scintilla window: 229 checks pass. They cover value validation and round trips, values kept across technology changes, drawing in every rendering mode, font quality and technology, whole-pixel advances with the GDI modes, the autocompletion list and call tips, WM_SETTINGCHANGE, and no repainting while idle.
<Windows: tried in Notepad++ with the same Scintilla code: ...>

The patch applies on its own to 5.6.7. It touches the same DirectWrite font constructor as the fix in bug #<weight-names ticket number>, so a second version that applies after that fix is attached too.

Two further options Notepad++ uses, a rendering mode that switches to natural for small text and a separate gamma for light text on dark backgrounds, are left out and could be proposed separately.

This patch was prepared with the help of an AI assistant (Claude), then reviewed and tested.
```

An optional one-line heads-up to https://groups.google.com/g/scintilla-interest with the ticket link can help
the discussion, as the maintainer asks questions there.

### After Scintilla accepts it

Notepad++ picks the API up with its next Scintilla update. Then a small follow-up to #18418's code:
switch 5101/5102 to the official messages and SC_FONTRENDERING_DEFAULT to SC_FONT_RENDERING_DEFAULT,
and drop the local patch except the two Notepad++-only options (or propose those too). config.xml
values stay as they are, since the units are the same.

---

## 4. Scintilla Bug Tracker: crash in FontDirectWrite::HFont when the font has no text format

New ticket: https://sourceforge.net/p/scintilla/bugs/new/. No existing report: the tracker's REST search for "HFont"
finds only #2519, #2080 and #817 (2026-09-30). Attach `scintilla-5.6.7-directwrite-hfont-null-text-format.diff`
(3 lines, applies to 5.6.7 with `git apply` / `patch -p1`, builds as C++17 with -Wpedantic -Wall -Wextra), and
optionally `hfontcrash.cpp` (the reproduction program).

### Title
`[Win32] Crash in FontDirectWrite::HFont when DirectWrite refused the font (e.g. SCI_STYLESETWEIGHT 1000), on showing autocompletion`

### Description
```
With a DirectWrite technology, FontDirectWrite leaves pTextFormat null when CreateTextFormat fails, for example for a weight outside 1..999 set with SCI_STYLESETWEIGHT (Scintilla doesn't validate it). The drawing code checks pTextFormat, but FontDirectWrite::HFont() doesn't, so showing an autocompletion list then crashes: ListBoxX::SetFont calls HFont(), which calls pTextFormat->GetFontFamilyName on a null pointer.

Steps: SCI_SETTECHNOLOGY(SC_TECHNOLOGY_DIRECTWRITE), SCI_STYLESETWEIGHT(STYLE_DEFAULT, 1000), SCI_STYLECLEARALL, SCI_AUTOCSHOW(0, "alpha beta gamma") -> access violation reading address 0 in FontDirectWrite::HFont (called by ListBoxX::SetFont). Reproduced with MinGW-w64 builds of 5.6.6 and 5.6.7 under Wine 9; weight 400 works. With the attached patch applied to 5.6.7, the same steps don't crash.

The attached patch returns no HFONT when there's no text format, as HFont() already does when GetFontFamilyName fails. Alternatively SCI_STYLESETWEIGHT could clamp the weight to 1..999, but SCI_STYLESETSTRETCH doesn't validate its value either (not tried), and any other failure of CreateTextFormat would leave pTextFormat null the same way.

The attached hfontcrash.cpp reproduces it: "hfontcrash 1000" crashes, "hfontcrash 400" works (build line in its header).

This was found and prepared with the help of an AI assistant (Claude), then reviewed and tested.
```
