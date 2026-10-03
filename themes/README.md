# Lucid Light and Lucid Dark: Notepad++ themes for legible code (version 2)

Two themes, one pair: `Lucid Light.xml` for bright rooms and long reading, `Lucid Dark.xml` for dim rooms. Both
cover all 93 lexers and 1,774 styles of Notepad++'s `stylers.model.xml` (2026-05-25).

![C++ and Python in Lucid Light (top) and Lucid Dark (bottom), Notepad++ under Wine](preview.png)

(The screenshots were taken under Wine, where Consolas is replaced by DejaVu Sans Mono and Notepad++ draws
with GDI.)

## Why version 2

Version 1 gave each colour the highest contrast its hue allowed. It was legible, but it looked off:
- **Dark theme:** a near-neon cyan sat next to washed-out pastel pink and periwinkle.
- **Light theme:** functions and numbers came out olive and brown. Dark yellow and brown are the least liked
  colours in color-preference studies (Palmer & Schloss 2010).
- **Hues:** seven of them, spread evenly round the colour wheel, and several changed between the two themes.

Version 2 puts harmony first and keeps legibility as a hard floor.

## Install

1. Copy both `.xml` files into Notepad++'s themes folder:
   - installed Notepad++: `%APPDATA%\Notepad++\themes\` (create the folder if it's missing);
   - portable Notepad++, or one started with `-settingsDir=<dir>`: `<that folder>\themes\`.
2. Restart Notepad++.
3. In light mode: **Settings > Style Configurator > Select theme: Lucid Light > Save & Close**.
4. **Settings > Preferences > Dark Mode**: turn dark mode on. Then choose **Lucid Dark** in the Style Configurator.

Notepad++ remembers one theme per mode (`darkThemeName` and `lightThemeName` in `config.xml`), so after this,
switching between light and dark mode also switches the theme. "Follow Windows" works the same way. Updating the
files later keeps the selection, because the file names stay the same.

The themes set the editor font to Consolas 10 pt, like Notepad++'s own themes. To use a different font or size,
change **Global Styles > Default Style** after selecting the theme.

## The palette

| Role | Lucid Light (soft paper) | Lucid Dark (slate) |
|---|---|---|
| Background | `#FAF7F3` | `#1F232A` |
| Text | `#23272C`, 14.1:1 | `#D6DBE3`, 11.3:1 |
| Keywords (bold where the lexer bolds them) | violet `#724AAB`, 6.0:1 | lavender `#C7B0F2`, 8.1:1 |
| Functions, classes, built-ins | blue `#2165A9`, 5.6:1 | sky blue `#97C2F2`, 8.2:1 |
| Types, attributes, keys | teal `#247073`, 5.4:1 | teal `#6BD0D6`, 8.4:1 |
| Strings | green `#277620`, 5.3:1 | green `#95D08E`, 8.8:1 |
| Numbers, constants | orange `#A65010`, 4.9:1 | orange `#F3AB7A`, 8.2:1 |
| Preprocessor, macros, variables, decorators | magenta `#98397E`, 5.9:1 | pink `#EEA2D4`, 8.1:1 |
| Errors (on a tinted background) | red `#A83634`, 5.6:1 | coral `#F3A7A0`, 8.1:1 |
| Comments | grey `#676C75`, 4.9:1 | grey `#A1A8B5`, 6.6:1 |

The ratios are WCAG 2 contrast against the background. Each one is the lower of two readers' values: one aged
32, one aged 70 (point 6 below).

## How it was designed

1. **One lightness for all syntax colours, and colour held back from the screen's limits.** Harmony ratings are
   highest when colours share lightness and saturation and differ clearly in lightness from their background (Ou
   & Luo 2006; Schloss & Palmer 2011).
   - The syntax colours of each theme share one OKLab lightness: 0.80 in the dark theme, 0.50 in the light theme.
   - Their chroma stays at 80-85% of what the sRGB screen can show at that lightness and hue. Colours at the
     gamut edge, with one primary switched off, are what looked neon in version 1.
   - Teal gets less chroma than the rest, because cyan looks more saturated and lighter than its numbers say (the
     Helmholtz-Kohlrausch effect: with Hellwig, Stolitzka & Fairchild's 2022 model, every syntax colour still
     looks at least 5 units darker than the text).
2. **The same hue for each role in both themes,** so switching themes doesn't change what a colour means: violet,
   blue, teal, green, orange, magenta, red. The one exception is the light theme's orange. It sits a little lighter
   than the other colours (4.9:1), because a darker orange turns brown.
3. **Neutrals with one tint per theme.** The dark theme's background, text and comments are a cool slate. The light
   theme's background is a soft warm paper with cool grey text. The tint is a matter of taste; no study shows a
   tint reduces eye strain, and a Cochrane review found blue-light filtering doesn't (Singh et al. 2023).
4. **Text contrast stays high.**
   - In a study of reading on screens at night, visual fatigue went down as text contrast went up, and the lowest
     contrasts tested were liked least (Xie et al. 2021).
   - Coloured text is more comfortable the further its colour is from the background's (Li et al. 2025).
   - So plain text is 11-14:1. Syntax colours are 8:1 or more in the dark theme and 4.9-6:1 in the light theme,
     where darker colours would turn muddy.
   - Reading speed doesn't rise above a modest contrast (Legge, Rubin & Luebker 1987), so the extra contrast is
     margin for comfort, small fonts, blur and age.
5. **Dark-theme text is off-white, not white.** The visual system resolves light-on-dark less sharply than
   dark-on-light: light strokes spread (Kremkow et al. 2014). That is part of why dark text on a light background
   reads better (Piepenbrock et al. 2013, 2014). Text at `#D6DBE3` keeps 11:1 without the glare of pure white.
6. **Older eyes.** The eye's lens yellows with age and absorbs more blue light (Pokorny, Smith & Lutze 1987;
   CIE 170-1:2006). Every contrast figure is checked for a 70-year-old reader as well as a 32-year-old, and
   `vision-report.md` adds an 80-year-old.
7. **Colour blindness.** About 8% of men of European descent have red-green colour vision deficiency (Birch 2012).
   - All colours were simulated for the three types of colour blindness (Machado, Oliveira & Fernandes 2009); the
     distances are in `palette-report.md`.
   - Keywords and strings, the most frequent pair, stay well apart in all of them.
   - Violet keywords and blue functions look alike to deuteranopes. There, the keywords' bold weight and the
     lightness steps between text, syntax colours and comments carry the difference.
8. **Restrained colour, no italics.** Syntax highlighting changes where people look more than how well they
   understand code (Sarkar 2015; Hannebauer, Hesenius & Gruhn 2018). So colour marks categories without
   competing with the text. Italics slow reading slightly (Tinker 1963), so comments are set apart by lightness and
   stay upright.

Highlights were checked as Notepad++ draws them. Smart highlighting, search marks and Mark Styles 1-5 are rounded
boxes under the text at alpha 100/255, and they use the palette's hues.
- Plain text on any highlight stays at 6.7:1 or more in the dark theme and 11:1 or more in the light theme.
- Syntax colours on a highlight or the selection stay at 3.7:1 or more; those only appear for a moment.
- On the current-line band, which is always there, every colour still meets 4.5:1.
- Every style in both files meets WCAG AA (4.5:1) against its own background, for both readers (`check.py`).
- The figures are in `palette-report.md`.

## Beyond the colours

The palette is a small part of eye strain. In rough order of effect:

- **Screen brightness matched to the room.** The most comfortable screen luminance rises with room light. A bright
  screen in a dark room, or a dim one in a bright room, strains more than any colour choice.
- **The room decides the theme.** Use the dark theme in dim rooms. In bright rooms, a dark screen shows
  reflections and makes the pupil open wider, and the light theme reads better.
- **Blinking and breaks.** People blink far less at screens. Taking a 20-second break every 20 minutes, looking
  20 feet (6 m) away, reduced dry-eye symptoms and eye strain while people kept it up (Talens-Estarelles et al.
  2023).
- **Glasses.** Uncorrected astigmatism, or presbyopia after about 40, cause much of computer eye strain
  (Rosenfield 2011).
- **Font size and line spacing.** See below. Lines of text form stripes that can cause discomfort, less so with more
  space between lines (Wilkins & Nimmo-Smith 1987). Notepad++ has no line-spacing setting; Scintilla does
  (`SCI_SETEXTRAASCENT`/`SCI_SETEXTRADESCENT`), reachable from the PythonScript plugin.
- **Sharp rendering.** In a virtual machine whose window the host rescales, ClearType's coloured edges and the
  resampling blur the text. Grayscale antialiasing, and a VM resolution that maps 1:1 to the host's pixels, keep it
  sharp.
- **The rest of the screen.** A dark editor next to bright windows makes the eyes adapt back and forth. Let Windows,
  Notepad++'s dark mode and the theme follow the same setting.

## Font size

Reading speed is highest when the x-height spans at least about 0.2° of visual angle, the critical print size of
normally sighted adults (Legge & Bigelow 2011). Older eyes need more. Consolas's x-height is 0.49 em, so:

  x-height in mm = 16.65 × points × Windows scale ÷ screen pixels per inch

At 60 cm, 0.2° is 2.1 mm:

- a 24-inch 1080p monitor at 100% scale (92 ppi) needs about **12 pt**;
- a 27-inch 1440p monitor at 125% scale (109 ppi) needs about **11 pt**.

Ctrl + mouse wheel zooms if a fixed size isn't wanted.

## Files

| File | What |
|---|---|
| `Lucid Light.xml`, `Lucid Dark.xml` | The themes |
| `palette.py` | The two palettes in OKLCH (lightness, chroma limit, hue per role); `python3 palette.py` prints `palette-report.md` |
| `colormath.py` | sRGB, OKLab/OKLCH, WCAG 2 and APCA-W3 0.0.98G-4g (each with the luminance weights of a 32- and a 70-year-old), colour-blindness simulation (checked against APCA's published values) |
| `gen_theme.py` | Writes both themes from `stylers.model.xml`: each style gets a role from its name, or from its colour in the model when the name says nothing; layout and comments are kept |
| `check.py` | Same lexers, styles and IDs as the model; WCAG and APCA contrast of every style |
| `palette-report.md` | Contrast on background, current line, selection and highlights; share of the available chroma; colour-blindness distances |
| `roles.tsv` | The role chosen for each of the 1,774 styles, and how it was chosen |
| `vision/agelens.py` | Luminance weights of the display primaries by age: CIE 2006 lens model on Stockman & Sharpe cone fundamentals; the age-dependent lens density table `asano_cie2006_docul.dat` is CIE 170-1's, as tabulated in luxpy |
| `vision/report.py`, `vision-report.md` | Every colour for readers aged 32, 70 and 80, and its CAM16 lightness with and without the Helmholtz-Kohlrausch effect. Needs `pip install colour-science`; the themes themselves don't |

Regenerate after a Notepad++ update adds lexers:

```sh
python3 gen_theme.py <repo>/PowerEditor/src/stylers.model.xml <repo>/PowerEditor/installer/themes/DarkModeDefault.xml .
python3 check.py <repo>/PowerEditor/src/stylers.model.xml "Lucid Light.xml" "Lucid Dark.xml"
```

## References

- Birch J (2012). Worldwide prevalence of red-green color deficiency. *J Opt Soc Am A* 29(3):313-320.
- CIE 170-1:2006. Fundamental chromaticity diagram with physiological axes, Part 1.
- Hannebauer C, Hesenius M, Gruhn V (2018). Does syntax highlighting help programming novices? *Empirical
  Software Engineering* 23:2795-2828.
- Hellwig L, Stolitzka D, Fairchild MD (2022). Extending CIECAM02 and CAM16 for the Helmholtz-Kohlrausch
  effect. *J Opt Soc Am A* 39(6).
- Kremkow J, Jin J, Komban SJ, et al. (2014). Neuronal nonlinearity explains greater visual spatial resolution for
  darks than lights. *PNAS* 111(8):3170-3175.
- Legge GE, Bigelow CA (2011). Does print size matter for reading? A review of findings from vision science and
  typography. *J Vision* 11(5):8.
- Legge GE, Rubin GS, Luebker A (1987). Psychophysics of reading V: the role of contrast in normal vision.
  *Vision Research* 27(7):1165-1177.
- Li et al. (2025). Visual comfort models based on coloured text and neutral background combinations. *Vision
  Research* 227.
- Machado GM, Oliveira MM, Fernandes LAF (2009). A physiologically-based model for simulation of color vision
  deficiency. *IEEE TVCG* 15(6):1291-1298.
- Ottosson B (2020). A perceptual color space for image processing (OKLab).
- Ou L-C, Luo MR (2006). A colour harmony model for two-colour combinations. *Color Research & Application*
  31(3):191-204.
- Palmer SE, Schloss KB (2010). An ecological valence theory of human color preference. *PNAS* 107(19):8877-8882.
- Piepenbrock C, Mayr S, Mund I, Buchner A (2013). Positive display polarity is advantageous for both younger and
  older adults. *Ergonomics* 56(7):1116-1124.
- Piepenbrock C, Mayr S, Buchner A (2014). Smaller pupil size and better proofreading performance with positive
  than with negative polarity displays. *Ergonomics* 57(11):1670-1677.
- Pokorny J, Smith VC, Lutze M (1987). Aging of the human lens. *Applied Optics* 26(8):1437-1440.
- Rosenfield M (2011). Computer vision syndrome: a review of ocular causes and potential treatments. *Ophthalmic
  Physiol Opt* 31(5):502-515.
- Sarkar A (2015). The impact of syntax colouring on program comprehension. *PPIG 2015*.
- Schloss KB, Palmer SE (2011). Aesthetic response to color combinations: preference, harmony, and similarity.
  *Attention, Perception, & Psychophysics* 73(2):551-571.
- Singh S, Keller PR, Busija L, et al. (2023). Blue-light filtering spectacles for improving visual performance,
  sleep, and macular health in adults. *Cochrane Database Syst Rev* 8:CD013244.
- Somers A. APCA, the Accessible Perceptual Contrast Algorithm (APCA-W3 0.0.98G-4g).
- Stockman A, Sharpe LT (2000). The spectral sensitivities of the middle- and long-wavelength-sensitive cones
  derived from measurements in observers of known genotype. *Vision Research* 40(13):1711-1737.
- Talens-Estarelles C, et al. (2023). The effects of breaks on digital eye strain, dry eye and binocular vision:
  testing the 20-20-20 rule. *Contact Lens and Anterior Eye*.
- Tinker MA (1963). *Legibility of Print*. Iowa State University Press.
- Wilkins AJ, Nimmo-Smith MI (1987). The clarity and comfort of printed text. *Ergonomics* 30(12):1705-1720.
- Xie X, Song F, Liu Y, Wang S, Yu D (2021). Study on the effects of display color mode and luminance contrast on
  visual fatigue. *IEEE Access* 9:35915-35923.
