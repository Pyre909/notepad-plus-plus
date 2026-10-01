# Contributing the Scintilla changes upstream

> **2026-09-30, Neil Hodgson on feature request #1592:** "I am not currently accepting LLM-generated contributions.
> The presentation of this feature, with 100 new setting combinations, is overwhelming so will not be that helpful
> for users." The Scintilla route is closed for code from this work while that policy stands: #1592 is declined,
> and the patches on #2520 can only serve as illustration (the report and test results stand on their own).
> 100 = 5 antialiasing x 5 rendering modes x 4 contrast levels: the same set of choices #18418 offers.

**Status 2026-09-30.**
- Bug #2519 (GDI weight family names): **withdrawn**. zufuliu pointed to #2080 and #2356, where the maintainer
  declined this mapping in Scintilla. The mapping now lives in Notepad++ (PR kit, section 5, branch
  `directwrite-font-names_20260930`), with the same results in the font check (35 names, identical report).
- Feature request (DirectWrite rendering parameters): filed, waiting. Only the standalone patch variant matters now.
- Bug #2520 (filed 2026-09-30): crash in `FontDirectWrite::HFont` with no text format (PR kit appendix section 4,
  patch `scintilla-5.6.7-directwrite-hfont-null-text-format.diff`). It was part of the withdrawn patch.

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
| GDI weight family names ("Fira Code Light") under DirectWrite, real bold under GDI | Filed as Scintilla bug #2519; the maintainer declined this twice before (#2080, #2356) | **Withdrawn from Scintilla**: now Notepad++ PR 5, no Scintilla change |
| Crash: `FontDirectWrite::HFont` with no text format (a weight DirectWrite refuses, then the autocompletion list) | Bug in every Win32 app using DirectWrite | **Filed as Scintilla bug #2520** (3-line patch, PR kit appendix section 4) |
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

## 2. Scintilla Bug Tracker: GDI weight family names

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
