/* Scintilla source code edit control */
/** @file ScintillaFontRendering.h
 ** N++ (Pyre909 build): the DirectWrite text rendering overrides of the Win32 platform, private messages of this copy of
 ** Scintilla (not in Scintilla.iface). Included by Scintilla.h, and by FontRenderingOverrides.h which implements them.
 **/

#ifndef SCINTILLAFONTRENDERING_H
#define SCINTILLAFONTRENDERING_H

/* SCI_SETFONTRENDERINGPARAMETER(int parameter, int value) overrides a parameter of the rendering parameters DirectWrite
   draws text with (the monitor's), SC_FONTRENDERING_DEFAULT removes the override; SCI_GETFONTRENDERINGPARAMETER(int
   parameter) returns it. Kept whatever the technology, they take effect while DirectWrite is used. Aliased text
   (SC_EFF_QUALITY_NON_ANTIALIASED) is drawn with the monitor's parameters. Not handled in builds without Direct2D
   (DISABLE_D2D).
   (5001 and 5002 are ScintillaWin's idle messages.) */
#define SCI_SETFONTRENDERINGPARAMETER 5101
#define SCI_GETFONTRENDERINGPARAMETER 5102

#define SC_FONTRENDERING_DEFAULT -1
#define SC_FONTRENDERING_ENHANCEDCONTRAST 0          /* in hundredths, 0-1000: the contrast of ClearType text */
#define SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST 1 /* in hundredths, 0-1000: the contrast of grayscale text */
#define SC_FONTRENDERING_CLEARTYPELEVEL 2            /* in percent, 0-100: 0 is grayscale, 100 full ClearType colors */
#define SC_FONTRENDERING_RENDERINGMODE 3             /* SC_RENDERINGMODE_* */
#define SC_FONTRENDERING_LIGHTTEXTGAMMA 4            /* in thousandths, 1000-2200: the least gamma of light text, heavier */
#define SC_FONTRENDERING_PARAMETERS 5

/* DWRITE_RENDERING_MODE values; GDI classic text is also measured like GDI */
#define SC_RENDERINGMODE_GDICLASSIC 2
#define SC_RENDERINGMODE_NATURAL 4
#define SC_RENDERINGMODE_NATURALSYMMETRIC 5

#endif
