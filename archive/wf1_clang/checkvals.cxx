#include <cstdint>
#include <cstddef>
#include "Scintilla.h"
// Values as mirrored in scintilla/win32/ScintillaWin.cxx
static_assert(SC_FONTRENDERING_DEFAULT == -1);
static_assert(SC_FONTRENDERING_GAMMA == 0);
static_assert(SC_FONTRENDERING_ENHANCEDCONTRAST == 1);
static_assert(SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST == 2);
static_assert(SC_FONTRENDERING_CLEARTYPELEVEL == 3);
static_assert(SC_FONTRENDERING_PIXELGEOMETRY == 4);
static_assert(SC_FONTRENDERING_RENDERINGMODE == 5);
static_assert(SC_FONTRENDERING_RENDERINGMODE + 1 == 6);
static_assert(SC_PIXELGEOMETRY_FLAT == 0);
static_assert(SC_PIXELGEOMETRY_BGR == 2);
static_assert(SC_RENDERINGMODE_DEFAULT == 0);
static_assert(SC_RENDERINGMODE_GDICLASSIC == 2);
static_assert(SC_RENDERINGMODE_GDINATURAL == 3);
static_assert(SC_RENDERINGMODE_NATURAL == 4);
static_assert(SC_RENDERINGMODE_NATURALSYMMETRIC == 5);
static_assert(SCI_SETFONTRENDERINGPARAMETER == 5001 && SCI_GETFONTRENDERINGPARAMETER == 5002);
int main() { return 0; }
