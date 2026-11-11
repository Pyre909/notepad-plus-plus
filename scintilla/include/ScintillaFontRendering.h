/* Scintilla source code edit control */
/** @file ScintillaFontRendering.h
 ** N++ (Pyre909 build): the DirectWrite text rendering overrides of the Win32 platform, and the character grid, private
 ** messages of this copy of Scintilla (not in Scintilla.iface). Included by Scintilla.h, and by FontRenderingOverrides.h
 ** which implements the overrides.
 **/

#ifndef SCINTILLAFONTRENDERING_H
#define SCINTILLAFONTRENDERING_H

/* SCI_SETFONTRENDERINGPARAMETER(int parameter, int value) overrides a parameter of the rendering parameters DirectWrite
   draws text with (the monitor's), or of the fonts' features, SC_FONTRENDERING_DEFAULT removes the override;
   SCI_GETFONTRENDERINGPARAMETER(int parameter) returns it. Kept whatever the technology, they take effect while
   DirectWrite is used. Aliased text (SC_EFF_QUALITY_NON_ANTIALIASED) is drawn with the monitor's parameters. Not handled
   in builds without Direct2D (DISABLE_D2D).
   (5001 and 5002 are ScintillaWin's idle messages.) */
#define SCI_SETFONTRENDERINGPARAMETER 5101
#define SCI_GETFONTRENDERINGPARAMETER 5102

#define SC_FONTRENDERING_DEFAULT -1
#define SC_FONTRENDERING_ENHANCEDCONTRAST 0          /* in hundredths, 0-1000: the contrast of ClearType text */
#define SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST 1 /* in hundredths, 0-1000: the contrast of grayscale text */
#define SC_FONTRENDERING_CLEARTYPELEVEL 2            /* in percent, 0-100: 0 is grayscale, 100 full ClearType colors */
#define SC_FONTRENDERING_RENDERINGMODE 3             /* SC_RENDERINGMODE_* */
#define SC_FONTRENDERING_LIGHTTEXTGAMMA 4            /* in thousandths, 1000-2200: the least gamma of light text, heavier */
#define SC_FONTRENDERING_LIGATURES 5                 /* 0: the fonts' ligatures and contextual alternates (liga, clig, calt) off */
#define SC_FONTRENDERING_PARAMETERS 6

/* DWRITE_RENDERING_MODE values; GDI classic text is also measured like GDI */
#define SC_RENDERINGMODE_GDICLASSIC 2
#define SC_RENDERINGMODE_NATURAL 4
#define SC_RENDERINGMODE_NATURALSYMMETRIC 5

/* SCI_SETCHARACTERGRID(bool grid) lays out on a grid of cells, a cell being the width of a space of STYLE_DEFAULT: a tab is
   one tab width wide wherever it is (not up to the next tab stop), and the representations (control characters, line
   ends, those of SCI_SETREPRESENTATION, invalid bytes) take whole cells, their text centred (a representation of no width,
   such as a zero width space, stays of no width). Every character takes the cells Unicode gives it (East Asian wide 2,
   combining and format characters 0, others 1), its glyph centred or narrowed in them; the cell in whole pixels. The
   edge's background mode starts at its column in cells. Explicit tab stops (SCI_ADDTABSTOP) and the bidirectional mode
   aren't on the grid. SCI_GETCHARACTERGRID returns it. Whatever the technology. */
#define SCI_SETCHARACTERGRID 5103
#define SCI_GETCHARACTERGRID 5104

/* SCI_GETCELLCOLUMN(position pos) returns the cell pos is drawn in, counted from the start of its line (0 for the first,
   wrapped or not): where it starts in the line's layout, in widths of a space of STYLE_DEFAULT (with the character grid,
   its cells: a space, or a "0" where wider), rounded. With the character grid, what the view shows. */
#define SCI_GETCELLCOLUMN 5105

/* SCI_SETFONTFEATURES(<unused>, const char *features) sets the OpenType features of every font of the view, as CSS's
   font-feature-settings or simpler: separated by commas, semicolons or spaces, "ss01" or "+ss01" on, "-calt" off,
   "cv05=2" a value (an alternate's number); a tag of 1 to 4 letters, digits or underscores (padded with spaces); a later
   one wins, at most 64; what isn't a feature is ignored. They override SC_FONTRENDERING_LIGATURES 0's. NULL or "" for
   none. SCI_GETFONTFEATURES(<unused>, char *features) copies them as set and returns their length. Drawn with
   DirectWrite only (GDI draws no OpenType features). */
#define SCI_SETFONTFEATURES 5106
#define SCI_GETFONTFEATURES 5107

/* SCI_SETFONTFALLBACK(<unused>, const char *fonts) sets the fonts DirectWrite draws the characters a style's font hasn't
   with, tried in order before the system's fallback: family names separated by semicolons or commas ("BIZ UDGothic;
   Segoe UI Emoji"), each for the characters it has; a name DirectWrite doesn't know is left out. NULL or "" for the
   system's fallback alone. SCI_GETFONTFALLBACK(<unused>, char *fonts) copies the list as set and returns its length.
   Drawn with DirectWrite only (GDI's fallback is Windows' font linking). */
#define SCI_SETFONTFALLBACK 5108
#define SCI_GETFONTFALLBACK 5109

/* SCI_SETINDENTGUIDESOLID(bool solid) draws the indentation guides as solid lines instead of dotted ones;
   SCI_GETINDENTGUIDESOLID returns it. Whatever the technology. */
#define SCI_SETINDENTGUIDESOLID 5110
#define SCI_GETINDENTGUIDESOLID 5111

/* SCI_UPDATEACTIVEINDENTGUIDE(int update) highlights the indentation guide of the main caret's block, in
   SC_ELEMENT_ACTIVEINDENTGUIDE's colour (else STYLE_BRACELIGHT's foreground, as a brace's guide): the guide at the
   indentation of the line the block hangs from (the line before it indented less; the caret's line itself when the next
   non-blank line is indented further), on the block's lines up to its last non-blank one. A blank line takes the larger
   indentation of the non-blank lines around it. Up to 10,000 lines beyond the view are read. update 1: the block found
   again (after the caret moved, the text or the tab width changed); 2: only if the last block found depended on the view,
   reaching the lines not read (after the view moved); 0: no highlight. The lines of the guide redrawn when it changes.
   Returns the guide's column (0: none). SCI_GETACTIVEINDENTGUIDE(int what) returns its column (0), first line (1) or last
   line (2). */
#define SCI_UPDATEACTIVEINDENTGUIDE 5112
#define SCI_GETACTIVEINDENTGUIDE 5113

/* Elements of SCI_SETELEMENTCOLOUR: the number of the main caret's line in the line number margin (else drawn as the
   other numbers), and the active indentation guide (SCI_UPDATEACTIVEINDENTGUIDE). */
#define SC_ELEMENT_CARETLINENUMBER 5120
#define SC_ELEMENT_ACTIVEINDENTGUIDE 5121

#endif
