# Upstream PR kit: issues and pull requests to paste

All branches are in `Pyre909/notepad-plus-plus`. Each one is a single commit on official
`master` (v8.9.8.1, `dd40fe4`), as CONTRIBUTING.md asks; 2 and 3 are rebased on the newer master `37f76d4` (2026-09-27),
6 is on master `697f46b` (2026-10-05), 8 on `a69bc23` (2026-10-06), and 7 is 6's commit plus its own until 6 is merged.

| # | Branch | Commit | Files | Exe size (MSVC x64) | What | Needs an approved issue |
|---|---|---|---|---|---|---|
| 1 | `font-size-1pt_20260925` | `faaeb59` | 2 | +0 | Font sizes 1–4 pt in the size lists | #18412; **PR closed, not accepted** |
| 2 | `text-rendering_20260925` | `a485acc` + `bb32194` | 20 + 29 xml | +15 KB | Text Rendering group in Editing 1 | #18414; **PR #18418 closed** (2026-10-02: too large a change) |
| 3 | `text-rendering-translations_20260925` | `1aa8b0e` | 29 xml | – | Label capitalisation (stacked on 2) | no (`[xml]`); on hold, 2 is closed |
| 4 | `per-monitor-dpi_20260925` | `8a455e0` | 61 | +23 KB | Opt-in per-monitor DPI awareness | yes, discuss first |
| 5 | `directwrite-font-names_20260930` | `9f605be` | 7 (Notepad++ only) | not measured | Fonts of a weight ("Fira Code Light") drawn with DirectWrite | no: bug fix of #9951 (open since 2021) and #12393. Replaces `font-weight-names_20260925` (the Scintilla version, declined by precedent) |
| 6 | `rtl-views-gdi_20261006` | `53d0026` | 4 | small | Right-to-left views drawn with GDI (DirectWrite can't mirror them) | no: bug fix of #17865 and #17518 (both open); open it first |
| 7 | `live-rendering-switch_20261005` | `53d0026` + `d50fb3b` (on 6) | 5 | small | Rendering mode applied at once, no restart | yes (feature request in section 7); the PR after 6 is merged. Replaces `live-rendering-switch_20260930` (stacked on 2) |
| 8 | `directwrite-font-smoothing_20261006` | `76b3210` | 4 | small | DirectWrite following the Windows font smoothing | no: bug fix of #14954 (open since 2024) |

Sizes are for the MSVC x64 Release exe that the fork's GitHub Actions CI built for each branch, compared with official master (8,525,312 bytes). All pushed branches pass CI on every job (5: 13/13 jobs, `9f605be`, 2026-10-06; 6, 7 and 8: 13/13, 2026-10-06). 6, 7 and 8 change a few dozen lines each: not measured. Branch 5 is compared with the fork's master CI build at `37f76d4` (8,525,824 bytes).

**How the split was checked.** Each branch was built and tested on its own (results in each
PR's Testing section). Recombined, branches 1 to 5 and the first live switch (`live-rendering-switch_20260930`) give
the combined branch back byte for byte, except where two PRs touch the same lines (see Conflicts): nothing was lost or
duplicated. 6, 7 and 8 came later (2026-10-05 and 06), on upstream `master`; `pyre` has them in its own version (8 as
the "Follow Windows" antialiasing of its Text Rendering settings).

**Order.** 1 and 2 were opened and closed without merging (2, #18418, on 2026-10-02: too large a change), so 3 is on
hold. Open 4 after a maintainer agrees on the approach: upstream already has DPI work in progress, so link or comment
on their existing per-monitor DPI issue first. 5 was first offered to Scintilla (bug #2519), but Scintilla's
maintainer has twice declined font-name mapping in Scintilla (bugs #2080, #2356: "leave implementation choice to the
application"), so it is now a Notepad++-only change, and a bug fix of #9951 and #12393: its checks are done, ready to
open (section 5).
6 is a bug fix: open it first. 7 is
an enhancement on top of 6: its feature request now, its PR once the request is Accepted and 6 is merged. 8 is a bug
fix too: its PR after the checks of section 8. No code goes
to Scintilla: its maintainer takes no LLM-generated contributions (2026-09-30).

**Conflicts between the PRs.** The PRs merge in any order, except:
- 2 and 4 both change the MISC page layout in `preference.rc`;
- 5 with 6 and 7: 5's font names depend on the technology ("Bahnschrift Light" is "Bahnschrift" at weight 300 for
  DirectWrite, not for GDI), and 6 (a right-to-left view gets GDI, and the setting's technology back once
  left-to-right) and 7 (the live switch) change a view's technology at run time. Whichever lands second sets the style
  fonts again when a view's technology changes, with 5's `ScintillaEditView::refreshStyleFonts(technology,
  previousTechnology)` (which also leaves the fonts a plugin set): `pyre` calls it from `technologyChanged`, after
  `changeTextDirection` and `setTechnologyToAll` (test `pyre-rtl-style-fonts`);
- 8 with 6 and 7: a view whose technology changes at run time (6: a right-to-left view goes to GDI and back; 7: the
  live switch) needs the font quality of the Windows font smoothing for its new technology, whichever lands second:
  with 8's `WM_SETTINGCHANGE` rule, only a view still at the quality it got from Windows (a plugin's is kept), as
  `pyre`'s `technologyChanged` does;
- 7 contains 6's commit until 6 is merged.

Whichever lands second needs a quick rebase. The combined branch
`claude/awesome-darwin-bsud9v` shows the resolved result for 1 to 5, `pyre` for 5 with 6 and 7.

**Before opening.** CONTRIBUTING.md asks you to test each PR at least once. All branches pass the
repository's CI on the fork (official MSVC toolchain). The functional tests of 1 to 4 ran under Wine,
so run those branches' CI exe on real Windows before opening their PR (5 to 8 were tested on the Windows VM). The
exe is the `Notepad++.MSVC.x64.Release` artifact of the branch's run in the fork's Actions tab.

**Screenshot for PR 2.** Its body says "screenshot attached": take one of Preferences > Editing 1
on Windows. The Wine test setup greys out the Rendering mode box, so its captures aren't usable.

**`fix #NNNNN`.** Replace it with the issue number. Done for 1 (#18412, PR closed without merging), 2 (#18414, PR #18418 closed), 5 (#9951, #12393), 6 (#17865, #17518) and 8 (#14954); 4 and 7 still need their issues.

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

Branch `per-monitor-dpi_20260925`, one commit `8a455e0` on upstream `master` `a69bc23` (reconciled on 2026-10-07: rebased
from 8.9.8.1's `8a0ff70`, authored by Pyre909 with the Co-Authored-By line), 61 files, +1529 −254. Upstream's 13 new
commits made the About, hash and Shortcut Mapper dialogs per-monitor (ozone10, part of #14959): AboutDlg now takes
upstream's code whole (the branch no longer changes it), dpiManagerV2.cpp keeps both sides' functions in `pyre`'s
order, and the status bar gets `WM_DPICHANGED` from the main window (upstream's `e083cef9f` removed
`WM_DPICHANGED_AFTERPARENT` from its subclass; `pyre`'s `7eba8f3`). Every DPI line equals `pyre`'s: 50 of the 61 files
are byte-identical, the other 11 differ by `pyre`'s other features only (and the MISC. checkbox position, as `pyre`
moved the rendering mode off that page), plus one trailing space this branch keeps as upstream has it.

Review harness (2026-10-07, ARM64, x64 and Win32 builds): no FAIL of its own; the 4 FAILs are other PRs' tests
(`directwrite-font-names`, the three RTL ones) failing as on unmodified upstream. WARNs explained: the size; whitespace of
code moved into a new block; `UserDefineDialog.cpp` indented with spaces as upstream's file is; `try {` as upstream
writes it 32 times out of 33. The independent AI review of `pyre`'s merge (2026-10-06) covered the same DPI code against
the same upstream; its open point is disclosed in the PR body. Not tested: two monitors of different scales (test round
row, waiting on Pyre909). CI of `8a455e0`: to check once pushed (the force push of 2026-10-07 got
GitHub "Internal Server Error" three times); the body's CI line holds only after that.

Why discuss first, and where: on #14959 (ozone10's hiDPI tracking issue, open), the unchecked items are the UDL
splitter and the whole Panels section (title, tab control, main field, splitter, plugin support), and ozone10 wrote on
2026-01-15 that panels are "really complex" (docked state, saving positions, plugins) and "feel free to do PR". Upstream
is still system DPI aware (manifest) and makes its dialogs per-monitor one by one; this branch makes the whole GUI
thread per-monitor, opt-in. Order: Pyre909 posts the comment below; the PR follows (or a split of it) if ozone10 or
donho agree.

### Comment on #14959
```
@ozone10 about the panels part you mentioned (docked state, saved positions, plugins), I've been working on exactly that and have it in a branch: https://github.com/Pyre909/notepad-plus-plus/tree/per-monitor-dpi_20260925

Short version: it's an opt-in setting (MISC. > "Per-monitor DPI awareness (experimental, restart required)", off by default). When it's on, the GUI thread runs PerMonitorV2, so the main window and the panels rescale on WM_DPICHANGED instead of getting bitmap-stretched: Function List, Folder as Workspace, Project, Document List, Character panel, Clipboard History, search results, Document Map, the docked UDL, plus splitters, the panel titles/tabs, floating panels, and saved panel sizes kept right when starting on a monitor with another scale. When it's off, nothing changes. It sits on top of your dialog work (About, hash, Shortcut Mapper, Find), which keeps working the same either way.

Not covered: plugin panels, since how they lay out is up to each plugin.

It's big (61 files, mostly one rescale hook per panel), so before opening a PR I wanted to ask if the approach (opt-in, whole thread PerMonitorV2) fits what you have in mind, or if you'd rather have it split up some way. Happy to rework it.

(Written with help from an AI assistant, which I'd disclose in the PR too.)
```

### Issue — title (if a separate feature request is wanted instead)
`[Feature request] Opt-in per-monitor DPI awareness (sharp GUI on monitors of different scaling)`

### PR — title
`Add opt-in per-monitor DPI awareness (experimental)`

### PR — body
```
Follow-up to the panels part of #14959. Preferences > MISC. > "Per-monitor DPI awareness (experimental, restart required)": off by default, greyed out before Windows 10 1703. When it's off, Notepad++ stays system DPI aware and nothing changes (every new code path checks it).

When it's on, the GUI thread runs PerMonitorV2 (SetThreadDpiAwarenessContext; the manifest stays as it is), so Notepad++ is sharp on every monitor instead of bitmap-stretched. These follow DPI changes: main window, toolbar, tabs, status bar, editor margins and markers, splitters, docked and floating panels (Function List, Folder as Workspace, Project, Document List, Character panel, Clipboard History, search results, Document Map, docked UDL), the incremental search bar and dialogs. Saved window and panel sizes stay right when starting on a monitor with another scale. The status bar gets WM_DPICHANGED from the main window, like the Find dialog's.

The per-monitor dialogs already in master (About, hash dialogs, Shortcut Mapper, Find) work the same with the option on or off.

Not covered: plugin panels, since that depends on the plugin.

It's big, 61 files, mostly one rescale hook per panel, with shared helpers in DPIManagerV2 and ImageListSet.

Testing:
- Windows 11 ARM64, Release builds for ARM64, x64 and Win32; with the option off, the app-level tests I have pass the same as on master.
- Earlier, with a MinGW build under Wine at 96 and 144 DPI: option off, the main window and docked panels are pixel-identical to master; option on at the same DPI, identical too; docking a clone view, Function List and Document Map, synthetic WM_DPICHANGED 144 -> 96 -> 144 and WM_DPICHANGED_AFTERPARENT to every Scintilla (margins rescaled), clean exit.
- All 13 CI jobs pass on my fork.
- Not tested yet: two real monitors with different scaling, which is the main case. Plugin panels.

Known: with the option off, upstream's always-PerMonitorV2 dialogs (Shortcut Mapper, About...) on a monitor of another scale still get system-DPI metrics from getSystemMetricsForWindow, same as master today.

AI disclosure: I wrote this with help from an AI assistant (Claude), then reviewed and tested it myself.

- [x] I have read contributing guidelines

fix #NNNNN (or "ref #14959")
```

---

## 5. Fonts of a weight ("Fira Code Light") under DirectWrite, done by Notepad++

Branch `directwrite-font-names_20260930`, commit `9f605be` on master `a69bc23` (rewritten 2026-10-06 after a review of
the first version, `6e8579e`, and corrected after a second review), 7 files (+361 −19): the new
`ScintillaComponent/FontFamilyNames.cpp/.h` (listed in CMakeLists.txt and notepadPlus.vcxproj; the GCC makefile finds
it by itself), `ScintillaEditView` (`setSpecialStyle`, one font record per view, `refreshStyleFonts`) and `Printer.cpp`.
No Scintilla change. Authored by Pyre909 like 6 to 8, with the Co-Authored-By line (the first version's author was the
cloud session's "Claude").

What the rewrite changed: the mapping is DirectWrite's own GDI mapping (`IDWriteGdiInterop::CreateFontFromLOGFONT`)
instead of a matcher of the Win32 names of the whole font collection (tuned under Wine, where Notepad++ uses GDI
anyway): the same result for the 319 fonts of the Windows 11 VM, 3 times faster (about 15 ms for all of them, against
45). GDI is left as upstream draws it (the first version also mapped GDI's bold, and, under GDI, made non-bold SemiBold
styles read back as bold). Printing was broken by the first version: Scintilla prints with GDI from the screen styles,
so "Fira Code" Light printed as Regular; the styles now get their GDI names back while printing, and their DirectWrite
ones back before the line number margin is measured again.

Bold is 300 heavier than the font, as bold is to regular. Checked against GDI on 2026-10-06 (the ink of a sample line
at 15 and 24 px, every font drawn by GDI, `vm/inkcmp.cpp`):
- GDI emboldens a Light, SemiLight or Medium font, and how heavy that gets depends on the font and the size: from about
  the Regular (Segoe UI Light) to about the Bold (Bahnschrift Light at 15 px). 300 heavier is in that range, and the
  closest weight for MonoLisa Light, and at 24 px for Bahnschrift Light and MonoLisa Medium. A cap at Bold, as a
  reviewer suggested, would make Medium fonts lighter than GDI's (MonoLisa Medium: GDI 1.42-1.44 times the ink of its
  regular, Bold 1.00-1.28, ExtraBold 1.32-1.36).
- GDI doesn't embolden a SemiBold or heavier font at all: its bold is the regular, pixel for pixel (Segoe UI,
  Bahnschrift, Cascadia Code, MonoLisa, Noto Serif JP). With DirectWrite their bold is new: the family's heaviest up to
  Black ("Cascadia Code SemiBold": Cascadia Code Bold, a real font, not a simulated bold; "Segoe UI Semibold": Segoe UI
  Black).

Why not Scintilla: its maintainer declined this twice (bug #2080 in 2019, bug #2356 with merge request 36 in 2022:
"encodes a particular policy for font naming", "the application can adjust these parameters itself using
IDWriteGdiInterop"). Scintilla bug #2519 (our ticket) points there; this branch is that application-side fix.

The upstream issues (checked 2026-10-06):
- The main one is **#9951** "Inability to display some fonts" (2021-06, open, label "scintilla dependent", 29
  comments). #14526 (2023, closed by its reporter after "switch DirectWrite off") and #16666 (2025, closed as a
  duplicate) point to it.
- In #14526 the collaborator xomx wrote that, Scintilla's patch being refused, Notepad++ would have to map its GDI fonts
  to DirectWrite's weight/stretch/style families: what this branch does.
- A 2024 comment on #9951 says the maintainer turned down a Notepad3-style workaround as a hack (no source given, none
  found). So the PR says up front that this is the application-side mapping Scintilla's maintainer pointed to, with no
  Scintilla patch.
- #12393 (2022, open, no reply) is the same bug from a theme whose styles use fonts of other weights.
- DirectWrite is the default rendering mode since 8.6 (upstream `975d29b`, 2023-11-18), so everyone who picks such a
  font gets the fallback font, without changing any setting.

So it's a bug fix, `fix #9951` and `fix #12393`: no new issue, no Accepted label to wait for (though Neil called the
Scintilla version a feature addition on #2356). The issue texts drafted before are replaced by the optional comment
below.

### Comment on #9951 (optional, before the PR)
Where the watchers are; it answers the "scintilla dependent" label first. Repro checked on 2026-10-06 with upstream
`master` `a69bc23` built for ARM64 (the baseline row of the test round in `STATUS.md`): "Bahnschrift Light" goes to
DirectWrite at weight 400 and is drawn in a fallback font; nothing about font names changed upstream since 8.9.8.1.
```
Still happening on 8.9.8.1. And since DirectWrite is the default rendering mode now (8.6+), you don't need to touch any setting to hit it: Style Configurator > Default Style > font Bahnschrift Light (ships with Windows 10/11), and the text comes out in a fallback font. Same with Cascadia Code SemiBold, Segoe UI Light, Fira Code Light...

About the "scintilla dependent" label: Neil declined doing this name mapping inside Scintilla (bugs 2080 and 2356, the merge request mentioned above) and said the app can do it itself with IDWriteGdiInterop. Like xomx said in #14526, that means Notepad++ turning its GDI font names into the DirectWrite family + weight before handing them to Scintilla. I've got a PR that does just that, in Notepad++ only, no Scintilla patch, and GDI stays exactly as it is. PR coming.
```

### PR — title
`Draw the fonts of a weight such as "Fira Code Light" with DirectWrite`

### PR — body
```
The font lists show GDI family names, and those include the weight or width when a family has more than regular and bold: "Fira Code Light", "Cascadia Code SemiBold", "Bahnschrift SemiBold SemiConden". DirectWrite only knows the family ("Fira Code"), so with DirectWrite, which is the default rendering mode since 8.6, all of these get drawn in a fallback font (#9951; #12393 is the same thing coming from a theme). Easy to see: Style Configurator > Default Style > Bahnschrift Light, which ships with Windows.

Scintilla's maintainer doesn't want this name mapping inside Scintilla (Scintilla bugs 2080 and 2356) and pointed to IDWriteGdiInterop for the app to do it, like xomx said in #14526. So this does it in Notepad++ only, nothing in Scintilla:

- With DirectWrite, each style gets the family, weight, width and style DirectWrite knows the font by (new FontFamilyNames.cpp, called from ScintillaEditView::setSpecialStyle). The lookup is DirectWrite's own GDI mapping (IDWriteGdiInterop::CreateFontFromLOGFONT), so it's never a simulated bold. Names DirectWrite already knows as a family ("Consolas", "Courier New") are left as they are.
- Bold is 300 heavier than the font, the same step as regular to bold: bold "Fira Code Light" becomes "Fira Code" SemiBold. That's in the range of how heavy GDI makes a light font bold. GDI doesn't bold a SemiBold font at all; with DirectWrite its bold is the family's heaviest, up to Black.
- GDI isn't touched, it understands the GDI names already.
- Printing: Scintilla prints with GDI from the screen styles, so while printing the styles get their GDI names back, then their DirectWrite ones afterwards. A style a plugin changed itself is left alone.
- DirectWrite is only loaded when first needed (no new link dependency), and the lookup is cached per font name, about 15 ms for all 319 fonts on my machine.
- Styles without their own font use what SCI_STYLECLEARALL gave them (one font record per view), so their bold and italic are relative to the right font.

It's bigger than the usual small PR (7 files, ~360 lines), mostly the new FontFamilyNames.cpp/.h. I don't see a smaller way that fixes it for all fonts.

Side effects, DirectWrite only:
- A style reads back the DirectWrite font (SCI_STYLEGETFONT "Fira Code", SCI_STYLEGETWEIGHT 300), and so do plugins that read styles, an exporter for example.
- A Medium or SemiBold font has a weight above normal, so SCI_STYLEGETBOLD says bold; a family with only italic fonts reads back as italic.
- Scintilla's IME composition window builds a GDI font from the style's name and weight, so it shows "Fira Code" Regular instead of Light.

Tested on Windows 11 ARM64, Release builds for ARM64, x64 and Win32, no warnings in the changed files:
- Every name in the font list (319 fonts, regular, bold, italic) maps to the right DirectWrite font, including truncated names like "Bahnschrift SemiBold SemiConden", families from Hairline to Black, CJK fonts and the "@" vertical names.
- Bold measured against GDI's (ink of a sample line at 15 and 24 px): 300 heavier lands in GDI's range for Light and Medium fonts, and bold "Cascadia Code SemiBold" comes out as Cascadia Code Bold, not a fake bold.
- In Notepad++ with "Bahnschrift Light" as the Default Style font (automated test): with DirectWrite the styles read back "Bahnschrift" 300, bold 600; with GDI "Bahnschrift Light" 400, bold 700, same as before. Current master gets the fallback font here.
- Printing with DirectWrite on, "Segoe UI Light" to Microsoft Print to PDF: the PDF embeds Segoe UI Light (weight 300), same as GDI prints it.
- All 13 CI jobs pass on my fork (MSVC with code analysis, CMake, MinGW, Clang).

AI disclosure: I wrote this with help from an AI assistant (Claude), then reviewed and tested it myself.

- [x] I have read contributing guidelines

fix #9951
fix #12393
```

Before opening:
1. Push and CI: done (2026-10-06): force-pushed (`6e8579e` replaced), all 13 jobs pass, the Debug x64 code analysis
   and GCC and Clang included; the body's CI line is filled.
2. Printing: done (2026-10-06, `9f605be`'s ARM64 build, with Pyre909's OK as Windows then makes the PDF printer the
   default): Default Style "Segoe UI Light", DirectWrite, File > Print to "Microsoft Print to PDF". The PDF names its
   fonts CIDFont+F1..., so the embedded font's own name table was read: Segoe UI Light, weight class 300 (the first
   version would have printed "Segoe UI" Regular). pyre (`fcbbb30`) prints Segoe UI Light too, and its bold keywords
   in Segoe UI Semibold, the font its screen shows. Scripts: `vm/print-pdf.ps1` (the Windows 11 print dialog by UI
   Automation, the PDF printer's Save dialog by window messages) and `vm/pdf-fonts.ps1`.
3. "Cascadia Code SemiBold" with its bold drawn Bold: done (2026-10-06): DirectWrite matches its bold weight (900) to
   Cascadia Code Bold, the family's heaviest, without simulation (`inkcmp`). By eye in Notepad++ too if wanted.
4. Optional: an exporter (NppExport, bundled with the installer) with "Bahnschrift Light" and DirectWrite, to see what
   the side effects of the body give in the exported HTML/RTF (font name, bold).
5. Optional: the comment on #9951 above (its repro checked, see there).
6. If section 6 is merged first, this branch also has to set the style fonts again when a view's technology changes (a
   right-to-left view goes to GDI): `refreshStyleFonts(technology, previousTechnology)` is there for printing already,
   `pyre` calls it from `technologyChanged` (see Conflicts at the top).
7. PR body rewritten in a casual voice on 2026-10-07; checked then: the branch is on `master` `a69bc23` (current),
   #9951 and #12393 still open, no other open PR on them. The body now says why the PR is larger than the template's
   1-4 files / ~30 lines.

---

## 6. Right-to-left views drawn with GDI (bug fix, first)

Branch `rtl-views-gdi_20261006` (worktree `npp.worktrees\rtl-views-gdi_20261006`), one commit on upstream `master`,
4 files, +18 −21, no Scintilla change. Split from the live switch on 2026-10-06 (Pyre909's choice, after the
independent review): CONTRIBUTING wants a single feature or bug fix per PR, and this part fixes two open issues, while
the live switch (section 7) is an enhancement that needs its issue Accepted first.

Notepad++ shows RTL by mirroring the Scintilla window (`WS_EX_LAYOUTRTL`), and only GDI follows the mirroring. On the
VM (`vm/shots/rtl-directwrite-modes.png`): DirectWrite and DX11 draw left-to-right while Windows mirrors the scrollbar
and the mouse (a click 60 px from the editor's left edge reaches Scintilla at x = 936 of 968); DirectWrite (Use DC)
mirrors the whole picture, letters backwards. Scintilla has nothing for it: `SC_BIDIRECTIONAL_R2L` was never
finished, and its maintainer has answered twice (feature request #1435, 2022, from a Notepad++ user: mirroring was
never actively supported, "may have worked with GDI drawing but not DirectWrite"; bug #2233, 2021, ScintillaNET,
still open: patch your own copy), so no new Scintilla ticket.

History: Don's 9bc790b (2023-11-19, #14374) turned DirectWrite off for the whole program when a view was mirrored at
creation; 2724e0d (2023-11-30, per-document RTL) removed that check and added the refusal in `changeTextDirection`
(warned once, then silently nothing: #17865). Since then, with an RTL UI language (Hebrew, Arabic, Farsi, Kurdish,
Urdu, Uyghur; `editZoneRTL` defaults to yes) documents start RTL and every view is mirrored from creation, so with
DirectWrite, the default of a fresh config, the editor is drawn left-to-right in a mirrored window without a warning
(official 8.9.8.1 and master 697f46b: `vm/shots/rtl-ui-before-after.png`). The fix restores 9bc790b's intent per view:
a mirrored view uses GDI (`init` for a view mirrored at creation; `changeTextDirection`: GDI before mirroring, the
setting's technology back after unmirroring, so a view switching between RTL and LTR tabs switches technology too). The
refusal and its `RTLvsDirectWrite` entry are removed. Startup: the first documents are activated while already
current (`activateBuffer` returns early), so with `editZoneRTL="no"` the views stayed mirrored (#17518, reproduced on
master with `-nosession` and no file; it would have shown under DirectWrite too with the GDI rule): two lines in
`Notepad_plus::init` give them the direction of their document.

Reviewed on 2026-10-06 with the review harness (`review/`) and an independent AI review. Its findings: the
`editZoneRTL="no"` regression (fixed, test added); the DX11 swap chain kept after leaving that mode (tested on the VM:
out of DX11, back, RTL under DX11, all drawn right, with this VM's default "Optimizations for windowed games"); the
casts and braces (fixed); a reply on #17865 is from a user, not a maintainer (its claim was wrong). App-level tests,
ARM64 build on the VM: `rtl-views-gdi` (16 checks), `rtl-ui-gdi` (10, Hebrew UI) and `rtl-ui-editzone-no` (7);
unmodified upstream fails the RTL UI and #17518 ones. The fork's CI: all 13 jobs pass (`53d0026`, run 37431213095).
Known, not changed (disclosed in the PR): a plugin that set its own technology on one of Notepad++'s views gets the
setting's after an RTL round trip; a plugin's `SCI_SETBIDIRECTIONAL` is cleared when its view goes to GDI (Scintilla
does that); session documents saved RTL now show RTL under DirectWrite too (intended).

Order: Pyre909 opens the bug report below if they want a record of the RTL UI case (optional: #17865 and #17518 are
open), then the PR with the numbers and `vm/shots/rtl-ui-before-after.png` (in place of "(screenshot)"). PR body
rewritten in a casual voice on 2026-10-07; checked then: the branch merges cleanly with `master` `a69bc23`, #17865 and
#17518 still open, no other open PR on it. The commit can be amended until the PR is
opened, then new commits only. The PR is opened from
https://github.com/notepad-plus-plus/notepad-plus-plus/compare/master...Pyre909:notepad-plus-plus:rtl-views-gdi_20261006

### Issue (optional, bug) — title
`[BUG] RTL UI languages: the editor is mirrored but drawn left-to-right with DirectWrite`

### Issue — checkboxes
Searched: yes (#8847 and #14374 have the same cause, both closed). Without plugin: yes. Portable: yes. SciTE: leave it
unticked (SciTE has no mirrored RTL mode; mirroring is how Notepad++ shows RTL).

### Issue — Description of the Issue
```
With a right-to-left UI language (Hebrew, Arabic, Farsi, Kurdish, Urdu, Uyghur), new documents are RTL and the editor window is mirrored, but with DirectWrite on (the default rendering mode) the text is still drawn left-to-right. The scrollbar is on the left and clicks are mirrored, while the line numbers and the text are drawn like LTR, so clicking the line numbers puts the caret at the far end of the line instead. No warning shows.

Same cause as #8847 and #14374: Notepad++ shows RTL by mirroring the editor window (WS_EX_LAYOUTRTL), and only GDI drawing follows that. 9bc790b turned DirectWrite off in this case; the per-document RTL change (2724e0d) removed that check.
```

### Issue — Steps To Reproduce
```
1. Notepad++ 8.9.8.1 portable with a fresh config (Rendering mode is DirectWrite by default)
2. Settings > Preferences > General > Localization: עברית (Hebrew), then restart Notepad++
3. Open a text file, or type a few words
```

### Issue — Current Behavior
```
The editor window is mirrored (scrollbar on the left) but drawn left-to-right: line numbers on the left, text left-aligned. Clicks land on the mirrored side. (screenshot, left)
```

### Issue — Expected Behavior
```
The text drawn right-to-left, like with Rendering mode GDI. (screenshot, right: with the fix)
```

### Issue — Debug Information
? > Debug Info... > Copy debug info into clipboard, then paste.

### Issue — Anything else?
```
This can be fixed in Notepad++ alone, drawing the mirrored views with GDI and the others with DirectWrite. I'll send a PR, which also fixes #17865 and #17518.
```

### PR — title
`Draw right-to-left views with GDI, as DirectWrite can't mirror them`

### PR — body
```
Notepad++ shows an RTL document by mirroring the editor window (WS_EX_LAYOUTRTL), but only GDI drawing actually follows that mirroring. With DirectWrite the text still comes out left-to-right while Windows mirrors the scrollbar and the mouse, so clicks end up on the wrong side. Scintilla won't help here either, its maintainer said mirroring only ever worked with GDI: https://sourceforge.net/p/scintilla/feature-requests/1435/

What that looks like right now:
- With DirectWrite on, View > Text Direction RTL pops up "RTL is not compatible with DirectWrite mode" once, then just does nothing after that (#17865).
- With an RTL UI language (Hebrew, Arabic, Farsi, Kurdish, Urdu, Uyghur), documents start RTL and every view is mirrored from the start. DirectWrite is the default rendering mode, so out of the box the editor is drawn left-to-right inside a mirrored window, no warning at all. Screenshot below: 8.9.8.1 on the left, this PR on the right. 9bc790b used to turn DirectWrite off for that case, but the per-document RTL change (2724e0d) took that check out.

So this PR just draws a mirrored view with GDI, whatever the rendering mode is, and gives it its rendering mode back once it's LTR again (that includes switching between RTL and LTR tabs). A view that starts mirrored never gets DirectWrite in the first place. The refusal and its message are gone.

While I was in there: at startup the first document gets activated while it's already the current one, so the views never got their direction set, and with editZoneRTL="no" they stayed mirrored anyway (#17518). Two lines in Notepad_plus::init fix that.

4 files, nothing in Scintilla.

(screenshot)

Tested on Windows 11 ARM64 with Release builds of this branch (x64 and Win32 build fine too), fresh config so DirectWrite is on: RTL/LTR back and forth, RTL and LTR tabs, an RTL doc cloned to the other view, the Document Map following along, a long wrapped doc keeping its scroll position through all of it, and the Hebrew UI from startup to exit, also with editZoneRTL="no" and no session. No messages anywhere, and LTR documents stay on DirectWrite.

Two things I know about and left alone: if a plugin set its own technology on one of Notepad++'s views, it gets the rendering mode back after an RTL round trip, and a plugin's SCI_SETBIDIRECTIONAL gets cleared when its view switches to GDI (that's Scintilla's doing).

AI disclosure: I wrote this with help from an AI assistant (Claude), then reviewed and tested it myself.

- [x] I have read contributing guidelines

fix #17865, fix #17518
```

Translations: the other languages' `RTLvsDirectWrite` entry is no longer used (left to translators, or a separate
`[xml]` PR).

---

## 7. Rendering mode applied at once, without restarting (enhancement, after section 6)

Branch `live-rendering-switch_20261005` (worktree `npp.worktrees\live-rendering-switch_20261005`): section 6's commit,
then one commit for the live switch (5 files on top of it, +34 −5; `english_customizable.xml` mirrors `english.xml`).
#18418 was closed by donho on 2026-10-02 (the large modification could bring regressions; he'll look again once
Scintilla accepts its part, which it won't: see the appendix), so the live switch was rebuilt on upstream `master` on
its own; the old follow-up branch `live-rendering-switch_20260930` (stacked on #18418) is superseded. Its first
standalone version (`305ff13`, pushed 2026-10-05) refused DirectWrite while RTL text was shown; with section 6's rule
the right-to-left views simply keep GDI. That version is kept as `archive/live-rendering-switch-refusal_20261005`: if
section 6 is turned down, it is the fallback (its tests: `review/tests` as of this branch's commit `be26267`).

Reviewed on 2026-10-05 and 2026-10-06 with the review harness and two independent AI reviews (lifetime of the view
list sound; the RTL lock-out of the first version fixed). App-level tests: `live-rendering-switch` (40 checks: every
view of Notepad++ and of plugins follows, a view a plugin switched itself is left alone, a view destroyed at run time
is skipped, the RTL views kept on GDI, 50 quick switches, the choice saved), `live-rendering-switch-rtl-ui` (15, Hebrew
UI) and `live-rendering-switch-scroll` (11). The fork's CI: all 13 jobs pass (`d50fb3b`, run 37431216681). Known, not
changed: smart highlighting and link styling of lines newly in view after a switch come with the next scroll or caret
move (as after a font change in the Style Configurator); plugins get no notification of the switch; a plugin view set
to the same technology as the previous setting is switched too (nothing tells it apart).

Order: Pyre909 opens the feature request below; once it's Accepted and section 6's PR is merged, the branch is rebased
on `master` (one commit) and the PR is opened from
https://github.com/notepad-plus-plus/notepad-plus-plus/compare/master...Pyre909:notepad-plus-plus:live-rendering-switch_20261005

### Issue — title
`[Feature request] Apply the rendering mode without restarting Notepad++`

### Issue — existing issue
Tick "I have searched the existing issues". #18414 (Pyre909's, open) covers the Text Rendering settings and keeps the
restart ("Restart required, as before"), so this isn't a duplicate.

### Issue — Description of the Issue
```
Changing the rendering mode in Preferences > MISC. (GDI or one of the DirectWrite modes) only kicks in after you restart Notepad++, and the tooltip says so. Its own tooltip suggests trying another mode when something renders wrong ("May improve rendering of special characters or resolve some graphics issues"), but to actually try that you have to close everything, restart, look, and restart again if it didn't help. Same thing if you just want to compare how your font looks in GDI vs DirectWrite.
```

### Issue — Describe the solution you'd like
```
Apply the new rendering mode right away to everything that's open: both views, the Document Map, search results, and Scintilla views created by plugins. A view whose mode a plugin set itself would be left alone.

I've got a small patch for this already (5 files, nothing in Scintilla), tested on Windows 11, and I'll open a PR once this is OK'd.
```

### Issue — Debug Information
From the official Notepad++ (8.9.8.1, as in #18414), not the Pyre909 build, whose Debug Info names the build and has
text rendering lines: ? > Debug Info... > Copy debug info into clipboard, then paste.

### Issue — Anything else?
```
Related to #18414 / #18418, which asked for more text rendering options and kept the restart. This is just the restart part, on its own and much smaller.

One thing it relies on: right-to-left documents have to stay on GDI, since DirectWrite can't draw a mirrored window (#17865). I've got a separate fix PR for that, and the live switch keeps RTL views on GDI too.
```
Once section 6's PR is open, its number can replace "a separate fix PR". Drafted in a casual voice on 2026-10-07; the
quoted tooltip is upstream's (`scintillaRenderingTechnology-tip`, `master` `a69bc23`).

### PR — title
`Apply the rendering mode at once, without restarting`

### PR — body
```
Picking a rendering mode in Preferences > MISC. now applies right away to every Notepad++ view that follows the setting (both views, Document Map, search results, plugins' views) instead of after a restart.

- A view whose technology a plugin changed itself is left alone: only the views still on the old setting follow.
- Right-to-left views keep GDI, the only technology that follows their mirroring (#<section 6's PR>): they get the new mode once they're left-to-right.
- The tooltip no longer says to restart.

5 files (english_customizable.xml mirrors english.xml), no Scintilla changes.

Tested on Windows 11 ARM64 with Release builds of this branch (x64 and Win32 build too): I went through all five modes many times with both views, the Document Map, search results and plugin-created Scintillas open. Every view switched together and redrew right away; a view a plugin had switched itself stayed as it was, and RTL documents stayed on GDI. The chosen mode is saved in config.xml.

Known: a plugin view set to the same mode as the previous setting is switched too, and plugins get no notification.

AI disclosure: this change was written with the help of an AI assistant (Claude), then reviewed and tested.

- [x] I have read contributing guidelines

fix #NNNNN
```

Translations: the other languages' tooltip still mentions the restart until translators update it.

---

## 8. DirectWrite following the Windows font smoothing (bug fix)

Branch `directwrite-font-smoothing_20261006` (worktree `npp.worktrees\directwrite-font-smoothing_20261006`), one commit
(`76b3210`) on upstream `master` `a69bc23`, 4 files, +52 −4, no Scintilla change, no new setting or UI text. Made on
2026-10-06 from the "Follow Windows" antialiasing of the fork's Text Rendering settings (#18418, rejected), without the
setting.

Upstream bug #14954 (2024-04-07, open): since 8.6 made DirectWrite the default, unticking "Enable smooth font"
(Preferences > Editing 1) no longer gives unsmoothed text to someone whose Windows font smoothing is off, as it did in
8.1.4 with GDI, whose default quality follows Windows (rdipardo's reply: it's DirectWrite; the workaround is GDI in
MISC.). Scintilla turns its font quality into DirectWrite's text antialias mode (`DWriteMapFontQuality` in
`SurfaceD2D.cxx`: non-antialiased to aliased, antialiased to grayscale, LCD optimized to ClearType, default to
Direct2D's default), and Direct2D's default smooths whatever Windows says: on the VM, master draws ClearType with the
Windows font smoothing off and with Standard. The fix: `ScintillaEditView::applyWindowsFontQuality` gives a view on
DirectWrite the quality matching Windows (off: `SC_EFF_QUALITY_NON_ANTIALIASED`, Standard: `SC_EFF_QUALITY_ANTIALIASED`,
ClearType: `SC_EFF_QUALITY_DEFAULT` as before; a GDI view the default) and remembers it, when the view is created (`init`:
both views, Document Map, search results, plugins' views) and when "Enable smooth font" is turned off
(`NPPM_SETSMOOTHFONT`). On any `WM_SETTINGCHANGE` (Notepad++ passes it on to both views and the search results), a view
still at the quality it got follows a new one; "Enable smooth font" and a quality set by a plugin are kept. Any, because
the ClearType Text Tuner announces its change as `SPI_SETFONTSMOOTHINGORIENTATION` and Performance Options as
`SPI_SETFONTSMOOTHING` then `VisualEffects` (logged on the VM).

Reviewed on 2026-10-06 with the review harness (0 FAIL, 0 WARN; ARM64, x64 and Win32 builds) and an independent AI
review, which found no bug. Its points, taken: the first version listened only for `SPI_SETFONTSMOOTHING` and
`SPI_SETFONTSMOOTHINGTYPE` (it would have missed the Tuner) and reset any quality but ClearType on a setting change, a
plugin's too; the PR text now names the reporter's case, what people with smoothing off will see, and every view that
follows a change only after a restart. Tested with the Windows font smoothing off, Standard and ClearType (Pyre909
changed it): the app-level test `directwrite-font-smoothing` (16 checks) passes on this branch each time, unmodified
upstream fails 4 with off and with Standard (its views and Document Map stay at the default quality). Screenshots,
`vm/shots/font-smoothing-before-after.png` (captures in `vm/shots/font-smoothing/`): off, master ClearType and this
branch aliased (2 colors); Standard, master ClearType and this branch grayscale (no colored pixel); ClearType, both the
same. Live, both builds running: the Tuner (Standard to ClearType) and Performance Options (off, then on) changed this
branch's views at once (quality 2 to 0, 0 to 1, 1 to 0); master's stayed at the default.

Known, not changed (disclosed in the PR): people whose Windows font smoothing is off or Standard ("Adjust for best
performance", some Remote Desktop and VM setups) get unsmoothed or grayscale text after updating, as Windows is set;
"Enable smooth font" gives ClearType back. The Document Map, the tab preview, extra search results windows and plugins'
views get the quality when created but follow a change of the setting only after a restart (Notepad++ doesn't pass
`WM_SETTINGCHANGE` on to them). The autocompletion list stays smoothed: Scintilla draws it on a surface without rendering
parameters, where `SurfaceD2D::SetFontQuality` does nothing.

Before opening:
1. Done: pushed on 2026-10-06, CI 13/13, the MinGW and Clang jobs too (the ARM64 Debug job hung once on GitHub's runner
   and passed when re-run).
2. With section 6 or 7 merged first: a view whose technology changes at run time (6: a right-to-left view goes to GDI
   and back; 7: the live switch) calls `applyWindowsFontQuality` after the switch, see Conflicts at the top.
3. Attach `vm/shots/font-smoothing-before-after.png` to the PR, in place of "(screenshot...)".
4. PR body rewritten in a casual voice on 2026-10-07; checked then: the branch is on `master` `a69bc23` (current),
   #14954 still open, no other open PR on it.

### PR — title
`Follow the Windows font smoothing with DirectWrite`

### PR — body
```
Since 8.6 made DirectWrite the default, Notepad++ smooths text no matter what the Windows font smoothing is set to. Turn off "Smooth edges of screen fonts", or pick Standard instead of ClearType, and nothing changes, so unticking "Enable smooth font" doesn't give you unsmoothed text anymore either (#14954). With GDI it still follows the Windows setting like it always did.

What happens: Scintilla maps its font quality onto DirectWrite's antialias mode, and with the default quality Direct2D just smooths anyway. So now a view on DirectWrite gets the quality that matches Windows:
- smoothing off: SC_EFF_QUALITY_NON_ANTIALIASED (unsmoothed)
- Standard: SC_EFF_QUALITY_ANTIALIASED (grayscale)
- ClearType: SC_EFF_QUALITY_DEFAULT, same as before

That gets set when a view is created and when "Enable smooth font" is turned off. When Windows announces a setting change (WM_SETTINGCHANGE), a view that's still on the quality it got from Windows follows the change, so "Enable smooth font" and anything a plugin set itself are left alone. GDI views keep the default quality.

4 files, no new setting, nothing in Scintilla.

(screenshot: master on the left, this PR on the right)

Tested on Windows 11 ARM64 with Release builds of this branch (x64 and Win32 build fine too), with the Windows font smoothing off, on Standard and on ClearType: both views and the Document Map get the matching quality, and the text comes out unsmoothed, grayscale and ClearType. Changing the setting while Notepad++ is running, both in Performance Options and in the ClearType Text Tuner, updates the views right away. Also checked "Enable smooth font" on and off, a plugin's own quality being kept, and GDI not changing.

Things to know:
- If your Windows font smoothing is off or on Standard, you'll get unsmoothed or grayscale text after updating, because that's what Windows is set to. Ticking "Enable smooth font" brings ClearType back.
- The Document Map, the tab preview, extra search results windows and plugins' views only pick up a change of the Windows setting after a restart, since Notepad++ doesn't pass WM_SETTINGCHANGE on to them.
- The autocompletion list stays smoothed (Scintilla draws it without the font quality).

AI disclosure: I wrote this with help from an AI assistant (Claude), then reviewed and tested it myself.

- [x] I have read contributing guidelines

fix #14954
```

---

# Appendix: contributing the Scintilla changes upstream

> **2026-09-30, Neil Hodgson on feature request #1592:** "I am not currently accepting LLM-generated contributions.
> The presentation of this feature, with 100 new setting combinations, is overwhelming so will not be that helpful
> for users." The Scintilla route is closed for code from this work while that policy stands: #1592 is declined,
> and the patches on #2520 can only serve as illustration (the report and test results stand on their own).
> 100 = 5 antialiasing x 5 rendering modes x 4 contrast levels: the same set of choices #18418 offers.

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
| Crash: `FontDirectWrite::HFont` with no text format (a weight DirectWrite refuses, then the autocompletion list) | Bug in every Win32 app using DirectWrite | **Filed as Scintilla bug #2520** (2026-09-30, section 4 below, 3-line patch). Kept in the combined branch until a Scintilla release has it |
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

**Filed: https://sourceforge.net/p/scintilla/bugs/2520/** (2026-09-30), with the patch and `hfontcrash.cpp` attached.
When a Scintilla release includes the fix, drop the guard from the combined branch at the next Scintilla update.

**2026-10-01, zufuliu:** weight ranges differ between platforms (GDI, D2D 1..999, Pango, Qt, wx, CSS); suggested
clamping weight and stretch in the `E_INVALIDARG` retry of the FontDirectWrite constructor instead. Tested under Wine
(`hfprobe.cpp`): clamping draws text for negative weights and bad stretches (0, 10, -1, which crashed too), but Wine
refuses weights above 950 even clamped to 999, so it still crashes there; clamp + guard never crashes. Reply proposes
both, with `scintilla-5.6.7-directwrite-font-clamp-and-hfont-guard.diff`.
Reply posted 2026-10-01 with that patch attached to the comment (checked: identical to the tested file). Waiting for
the maintainer.

New ticket: https://sourceforge.net/p/scintilla/bugs/new/. No existing report: the tracker's REST search for "HFont"
finds only #2519, #2080 and #817 (2026-09-30). Attach `scintilla-5.6.7-directwrite-hfont-null-text-format.diff`
(3 lines, applies to 5.6.7 with `git apply` / `patch -p1`, builds as C++17 with -Wpedantic -Wall -Wextra), and
optionally `hfontcrash.cpp` (the reproduction program).

### Title
`[Win32] Crash in FontDirectWrite::HFont when DirectWrite refused the font (e.g. SCI_STYLESETWEIGHT 1000), on showing autocompletion`

### Description
```
With a DirectWrite technology, FontDirectWrite leaves pTextFormat null when CreateTextFormat fails, for example for a weight DirectWrite refuses, set with SCI_STYLESETWEIGHT (Scintilla doesn't validate it; Windows documents 1..999 as the valid weights). The drawing code checks pTextFormat, but FontDirectWrite::HFont() doesn't, so showing an autocompletion list then crashes: ListBoxX::SetFont calls HFont(), which calls pTextFormat->GetFontFamilyName on a null pointer.

Steps: SCI_SETTECHNOLOGY(SC_TECHNOLOGY_DIRECTWRITE), SCI_STYLESETWEIGHT(STYLE_DEFAULT, 1000), SCI_STYLECLEARALL, SCI_AUTOCSHOW(0, "alpha beta gamma") -> access violation reading address 0 in FontDirectWrite::HFont (called by ListBoxX::SetFont). Reproduced with MinGW-w64 builds of 5.6.6 and 5.6.7 under Wine 9, whose DirectWrite accepts weights 0..950: negative weights and weights above 950 crash (tried -100, -1, 951, 999, 1000, 5000), 0..950 work. With the attached patch applied to 5.6.7, none of them crash.

The attached patch returns no HFONT when there's no text format, as HFont() already does when GetFontFamilyName fails. Alternatively SCI_STYLESETWEIGHT could clamp the weight, but SCI_STYLESETSTRETCH doesn't validate its value either (not tried), and any other failure of CreateTextFormat would leave pTextFormat null the same way.

The attached hfontcrash.cpp reproduces it: "hfontcrash 1000" crashes, "hfontcrash 400" works (build line in its header).

This was found and prepared with the help of an AI assistant (Claude), then reviewed and tested.
```
