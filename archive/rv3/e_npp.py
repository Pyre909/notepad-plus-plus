import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/Notepad_plus.cpp', [
('''static constexpr int IDI_SEPARATOR_ICON = -1;
''',
'''static constexpr int IDI_SEPARATOR_ICON = -1;

static constexpr int colourMenuItemIconSize = 16; // in pixels of the system DPI
static constexpr int minFloatingPanelWidthRatio = 6; // minimal width of a floating panel, in caption heights
'''),
('''	delete _pFuncList;
	delete _pFileBrowser;
}
''',
'''	delete _pFuncList;
	delete _pFileBrowser;

	for (const auto& colourBitmap : _mainMenuColourBitmaps)
		::DeleteObject(colourBitmap.second);
}
'''),
('''	// preset minimal panel dimensions according to the current DPI
	dmd._minDockedPanelVisibility = DPIManagerV2::scale(nppGUI._dockingData._minDockedPanelVisibility, dpi);
	dmd._minFloatingPanelSize.cy = nppGUI._dockingData._minDockedPanelVisibility;
	dmd._minFloatingPanelSize.cx = std::max(static_cast<int>(nppGUI._dockingData._minFloatingPanelSize.cy * 6),
		DPIManagerV2::getSystemMetricsForDpi(SM_CXMINTRACK, dpi));
''',
'''	// preset minimal panel dimensions according to the current DPI
	setMinPanelSizesForDpi(dpi);
'''),
('''	NppParameters& nppParam = NppParameters::getInstance();
	StyleArray& styleArray = nppParam.getMiscStylerArray();

	for (size_t j = 0; j < sizeof(bitmapOnStyleMenuItemsInfo) / sizeof(bitmapOnStyleMenuItemsInfo[0]); ++j)
	{
		const Style * pStyle = styleArray.findByID(bitmapOnStyleMenuItemsInfo[j].styleIndic);
		if (pStyle)
		{
			HBITMAP hNewBitmap = getMainMenuColourBitmap(pStyle->_bgColor);
			if (hNewBitmap)
			{
				if (::SetMenuItemBitmaps(_mainMenuHandle, bitmapOnStyleMenuItemsInfo[j].firstOfThisColorMenuId, MF_BYCOMMAND, hNewBitmap, hNewBitmap))
				{
''',
'''	NppParameters& nppParam = NppParameters::getInstance();
	StyleArray& styleArray = nppParam.getMiscStylerArray();

	// with the per-monitor DPI awareness, set again at each DPI change: cached, as the context menus share them
	const bool isBitmapCached = DPIManagerV2::isPerMonitorV2Active();

	for (size_t j = 0; j < sizeof(bitmapOnStyleMenuItemsInfo) / sizeof(bitmapOnStyleMenuItemsInfo[0]); ++j)
	{
		const Style * pStyle = styleArray.findByID(bitmapOnStyleMenuItemsInfo[j].styleIndic);
		if (pStyle)
		{
			HBITMAP hNewBitmap = isBitmapCached ? getMainMenuColourBitmap(pStyle->_bgColor) : generateSolidColourMenuItemIcon(pStyle->_bgColor);
			if (hNewBitmap)
			{
				if (!::SetMenuItemBitmaps(_mainMenuHandle, bitmapOnStyleMenuItemsInfo[j].firstOfThisColorMenuId, MF_BYCOMMAND, hNewBitmap, hNewBitmap))
				{
					if (!isBitmapCached)
						::DeleteObject(hNewBitmap);
				}
				else
				{
'''),
('''		HBITMAP hBitmap = getMainMenuColourBitmap(colour);
		if (hBitmap)
		{
			::SetMenuItemBitmaps(_mainMenuHandle, IDM_VIEW_TAB_COLOUR_1 + i, MF_BYCOMMAND, hBitmap, hBitmap);
		}
	}
}

HBITMAP Notepad_plus::getMainMenuColourBitmap(COLORREF colour)
{
	// same size as generateSolidColourMenuItemIcon()
	const int bitmapXYsize = DPIManagerV2::scaleFromSystemDpiForWindow(16, _pPublicInterface->getHSelf());
	const auto key = std::make_pair(bitmapXYsize, colour);
''',
'''		HBITMAP hBitmap = isBitmapCached ? getMainMenuColourBitmap(colour) : generateSolidColourMenuItemIcon(colour);
		if (hBitmap)
		{
			if (!::SetMenuItemBitmaps(_mainMenuHandle, IDM_VIEW_TAB_COLOUR_1 + i, MF_BYCOMMAND, hBitmap, hBitmap) && !isBitmapCached)
				::DeleteObject(hBitmap);
		}
	}
}

HBITMAP Notepad_plus::getMainMenuColourBitmap(COLORREF colour)
{
	const int bitmapXYsize = DPIManagerV2::scaleFromSystemDpiForWindow(colourMenuItemIconSize, _pPublicInterface->getHSelf());
	const auto key = std::make_pair(bitmapXYsize, colour);
'''),
('''	// in pixels of the system DPI, for the DPI of the main window with the per-monitor DPI awareness
	const int bitmapXYsize = DPIManagerV2::scaleFromSystemDpiForWindow(16, _pPublicInterface->getHSelf());
''',
'''	const int bitmapXYsize = DPIManagerV2::scaleFromSystemDpiForWindow(colourMenuItemIconSize, _pPublicInterface->getHSelf());
'''),
('''void Notepad_plus::clearChangesHistory(int iView)''',
'''void Notepad_plus::setMinPanelSizesForDpi(UINT dpi)
{
	DockingManagerData& dmd = NppParameters::getInstance().getNppGUI()._dockingData;
	dmd._minDockedPanelVisibility = DPIManagerV2::scale(HIGH_CAPTION, dpi);
	dmd._minFloatingPanelSize.cy = dmd._minDockedPanelVisibility;
	dmd._minFloatingPanelSize.cx = std::max(static_cast<int>(dmd._minFloatingPanelSize.cy * minFloatingPanelWidthRatio),
		DPIManagerV2::getSystemMetricsForDpi(SM_CXMINTRACK, dpi));
}

void Notepad_plus::clearChangesHistory(int iView)'''),
])

rep('PowerEditor/src/NppBigSwitch.cpp', [
('''					// minimal panel dimensions (as preset by init)
					DockingManagerData& dmd = nppParam.getNppGUI()._dockingData;
					dmd._minDockedPanelVisibility = DPIManagerV2::scale(HIGH_CAPTION, dpi);
					dmd._minFloatingPanelSize.cy = dmd._minDockedPanelVisibility;
					dmd._minFloatingPanelSize.cx = std::max(static_cast<int>(dmd._minFloatingPanelSize.cy * 6),
						DPIManagerV2::getSystemMetricsForDpi(SM_CXMINTRACK, dpi));
''',
'''					setMinPanelSizesForDpi(dpi);
'''),
('''			// the Document List shares the tab icons resized in place above: it takes the icons of its DPI
			// (its DPI changes later with WM_DPICHANGED_AFTERPARENT if it's docked), no need to recreate it
			if (_pDocumentListPanel != nullptr)
''',
'''			// the Document List shares the tab icons resized above (no need to recreate it)
			if (_pDocumentListPanel != nullptr)
'''),
])

rep('PowerEditor/src/Notepad_plus.h', [
('''	// Colour samples of the main menu items by (size, colour): the context menus share them (so they are never deleted),
	// they are reused instead of generated again (and leaked) at each DPI change or style update
	std::map<std::pair<int, COLORREF>, HBITMAP> _mainMenuColourBitmaps;
	HBITMAP getMainMenuColourBitmap(COLORREF colour);
''',
'''	// per-monitor DPI awareness: colour samples of the main menu items by (size, colour), shared with the context menus
	std::map<std::pair<int, COLORREF>, HBITMAP> _mainMenuColourBitmaps;
	HBITMAP getMainMenuColourBitmap(COLORREF colour);
	void setMinPanelSizesForDpi(UINT dpi);
'''),
])
