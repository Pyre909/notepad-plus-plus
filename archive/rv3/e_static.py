import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/StaticDialog/StaticDialog.h', [
('''// Per-monitor DPI awareness (opt-in): the layout of dialogs (the positions and sizes of their controls, the fonts), saved
// for a DPI to be applied again for another DPI the way the dialog manager lays out a dialog template: fonts of the same
// point size, positions and sizes in the dialog units of the dialog font. Applying it is absolute: the result doesn't
// depend on what the dialog manager may have rescaled already (a child dialog of a window which isn't a dialog, e.g. a
// dialog docked in the main window or in a rebar, only receives WM_DPICHANGED_AFTERPARENT).
class DialogDpiLayout final''',
'''// Layout of dialogs (positions, sizes and fonts of their controls) saved for a DPI, applied for another DPI as the dialog
// manager lays out a template: same point sizes, dialog units of the dialog font. For the dialogs which only receive
// WM_DPICHANGED_AFTERPARENT (docked in the main window or in a rebar), with the per-monitor DPI awareness.
class DialogDpiLayout final'''),
('''	bool isSaved() const {
		return _dpi != 0;
	}

	// DPI of the saved layout
	UINT getDpi() const {
		return _dpi;
	}
''',
'''	bool isSaved() const {
		return _dpi != 0;
	}
'''),
])

rep('PowerEditor/src/WinControls/StaticDialog/StaticDialog.cpp', [
('''#include <cstring>
#include <cwchar>
#include <string>
#include <utility>
#include <vector>
''',
'''#include <cstring>
#include <cwchar>
#include <iterator>
#include <string>
#include <utility>
#include <vector>
'''),
('''DialogDpiLayout::~DialogDpiLayout()
{''',
'''// dialog units of the dialog base units, and points per inch (dialog font sizes)
static constexpr int dluPerBaseUnitX = 4;
static constexpr int dluPerBaseUnitY = 8;
static constexpr int pointsPerInch = 72;

DialogDpiLayout::~DialogDpiLayout()
{'''),
('''	SavedFont savedFont;
	if (::GetObject(hFont, lfSize, &savedFont._lf) != lfSize)''',
'''	SavedFont savedFont{};
	if (::GetObject(hFont, lfSize, &savedFont._lf) != lfSize)'''),
('''	Dlg dlg;
	dlg._hDlg = hDlg;
	dlg._iFont = saveFont(reinterpret_cast<HFONT>(::SendMessage(hDlg, WM_GETFONT, 0, 0)));

	RECT rcBaseUnits{ 0, 0, 4, 8 };
	if (::MapDialogRect(hDlg, &rcBaseUnits) && (rcBaseUnits.right >= 4) && (rcBaseUnits.bottom >= 8))''',
'''	Dlg dlg{};
	dlg._hDlg = hDlg;
	dlg._iFont = saveFont(reinterpret_cast<HFONT>(::SendMessage(hDlg, WM_GETFONT, 0, 0)));

	RECT rcBaseUnits{ 0, 0, dluPerBaseUnitX, dluPerBaseUnitY };
	if (::MapDialogRect(hDlg, &rcBaseUnits) && (rcBaseUnits.right >= dluPerBaseUnitX) && (rcBaseUnits.bottom >= dluPerBaseUnitY))'''),
('''		Ctrl ctrl;
		ctrl._hWnd = hChild;''',
'''		Ctrl ctrl{};
		ctrl._hWnd = hChild;'''),
('''	static constexpr wchar_t alphabet[] = L"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
	const HGDIOBJ hOldFont = ::SelectObject(hdc, hFont);
	TEXTMETRIC tm{};
	SIZE szAlphabet{};
	if (::GetTextMetrics(hdc, &tm) && ::GetTextExtentPoint32W(hdc, alphabet, 52, &szAlphabet))
		baseUnits = { (szAlphabet.cx / 26 + 1) / 2, tm.tmHeight };''',
'''	static constexpr wchar_t alphabet[] = L"ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
	static constexpr int alphabetLen = static_cast<int>(std::size(alphabet)) - 1;
	const HGDIOBJ hOldFont = ::SelectObject(hdc, hFont);
	TEXTMETRIC tm{};
	SIZE szAlphabet{};
	if (::GetTextMetrics(hdc, &tm) && ::GetTextExtentPoint32W(hdc, alphabet, alphabetLen, &szAlphabet))
		baseUnits = { (szAlphabet.cx / (alphabetLen / 2) + 1) / 2, tm.tmHeight }; // rounded average width'''),
('''			lf.lfHeight = (lf.lfHeight < 0) ? -::MulDiv(::MulDiv(-lf.lfHeight, 72, _dpi), dpi, 72) : DPIManagerV2::scale(lf.lfHeight, dpi, _dpi);''',
'''			lf.lfHeight = (lf.lfHeight < 0) ? -::MulDiv(::MulDiv(-lf.lfHeight, pointsPerInch, _dpi), dpi, pointsPerInch) : DPIManagerV2::scale(lf.lfHeight, dpi, _dpi);'''),
('''			return isDlu ? ::MulDiv(::MulDiv(x, 4, dlg._baseUnits.cx), baseUnits.cx, 4) : DPIManagerV2::scale(x, dpi, _dpi);''',
'''			return isDlu ? ::MulDiv(::MulDiv(x, dluPerBaseUnitX, dlg._baseUnits.cx), baseUnits.cx, dluPerBaseUnitX) : DPIManagerV2::scale(x, dpi, _dpi);'''),
('''			return isDlu ? ::MulDiv(::MulDiv(y, 8, dlg._baseUnits.cy), baseUnits.cy, 8) : DPIManagerV2::scale(y, dpi, _dpi);''',
'''			return isDlu ? ::MulDiv(::MulDiv(y, dluPerBaseUnitY, dlg._baseUnits.cy), baseUnits.cy, dluPerBaseUnitY) : DPIManagerV2::scale(y, dpi, _dpi);'''),
])
