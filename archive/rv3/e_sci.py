import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/ScintillaComponent/ScintillaEditView.cpp', [
('''		case WM_DPICHANGED:
		case WM_DPICHANGED_AFTERPARENT:
		{
			// Scintilla updates its DPI (fonts...) first, then the Notepad++ sizes (margins, markers) are recomputed with it
''',
'''		case WM_DPICHANGED_AFTERPARENT:
		{
			// Scintilla updates its DPI (fonts...) first, then the Notepad++ sizes (margins, markers) are recomputed with it
'''),
('''		// after a DPI change, a marker redefined by a plugin is left as it is
''',
'''		// after a DPI change, a marker redefined by a plugin with a non-RGBA symbol is left as it is
'''),
('''			// the padding is in pixels of the system DPI, with the per-monitor DPI awareness it's scaled for the DPI of the view
			const int padding = DPIManagerV2::isPerMonitorV2Active() ? DPIManagerV2::scaleFromSystemDpi(8, DPIManagerV2::getDpiForWindow(_hSelf)) : 8;
''',
'''			const int padding = DPIManagerV2::scaleFromSystemDpiForWindow(8, _hSelf); // in pixels of the system DPI
'''),
])

rep('PowerEditor/src/ScintillaComponent/ScintillaEditView.h', [
('''	int _nppMarginWidths[_nbNppMargins] = { 0, 0, 0, 0 };
''',
'''	int _nppMarginWidths[_nbNppMargins]{};
'''),
('''	void updateForDpi(); // after WM_DPICHANGED(_AFTERPARENT): the Notepad++ pixel sizes (margins, markers) for the new DPI
''',
'''	void updateForDpi(); // after WM_DPICHANGED_AFTERPARENT: the Notepad++ pixel sizes (margins, markers) for the new DPI
'''),
])
