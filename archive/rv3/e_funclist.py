import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/FunctionList/functionListPanel.cpp', [
('''#include "ScintillaEditView.h"
#include "localization.h"
#include <fstream>
''',
'''#include "ScintillaEditView.h"
#include "localization.h"
#include "ImageListSet.h"
#include <fstream>
'''),
('''#define FL_PREFERENCES_INITIALSORT_ID   1
''',
'''#define FL_PREFERENCES_INITIALSORT_ID   1

// toolbar sizes for 96 DPI
static constexpr int toolbarIconSize = 16;
static constexpr int searchEditWidth = 100;
static constexpr int searchEditSepWidth = 105; // searchEditWidth + 5
static constexpr int searchEditHeight = 20;
'''),
('''void FunctionListPanel::setToolbarImageLists(int iconSize)
{
	constexpr int nbIcons = 3;
	int iconIDs[nbIcons] = { IDI_FUNCLIST_SORTBUTTON, IDI_FUNCLIST_RELOADBUTTON, IDI_FUNCLIST_PREFERENCEBUTTON };
	int iconDarkModeIDs[nbIcons] = { IDI_FUNCLIST_SORTBUTTON_DM, IDI_FUNCLIST_RELOADBUTTON_DM, IDI_FUNCLIST_PREFERENCEBUTTON_DM };

	// Create an image lists for the toolbar icons
	HIMAGELIST hImageList = ImageList_Create(iconSize, iconSize, ILC_COLOR32 | ILC_MASK, nbIcons, 0);
	HIMAGELIST hImageListDm = ImageList_Create(iconSize, iconSize, ILC_COLOR32 | ILC_MASK, nbIcons, 0);

	for (size_t i = 0; i < nbIcons; ++i)
	{
		int icoID = iconIDs[i];
		HICON hIcon = nullptr;
		DPIManagerV2::loadIcon(_hInst, MAKEINTRESOURCE(icoID), iconSize, iconSize, &hIcon, LR_LOADMAP3DCOLORS | LR_LOADTRANSPARENT);
		ImageList_AddIcon(hImageList, hIcon);
		::DestroyIcon(hIcon);
		hIcon = nullptr;

		icoID = iconDarkModeIDs[i];
		DPIManagerV2::loadIcon(_hInst, MAKEINTRESOURCE(icoID), iconSize, iconSize, &hIcon, LR_LOADMAP3DCOLORS | LR_LOADTRANSPARENT);
		ImageList_AddIcon(hImageListDm, hIcon);
		::DestroyIcon(hIcon); // Clean up the loaded icon
	}

	// the image lists of the previous DPI (per-monitor DPI awareness), released once replaced in the toolbar
	const std::vector<HIMAGELIST> prevIconLists = _iconListVector;
	_iconListVector = { hImageList, hImageListDm };

	// Attach the image list to the toolbar
	::SendMessage(_hToolbarMenu, TB_SETIMAGELIST, 0, reinterpret_cast<LPARAM>(_iconListVector.at(NppDarkMode::isEnabled() ? 1 : 0)));

	for (auto hImgList : prevIconLists)
	{
		if (hImgList != nullptr)
		{
			::ImageList_Destroy(hImgList);
		}
	}
}
''',
'''void FunctionListPanel::setToolbarImageLists(int iconSize)
{
	static constexpr int iconIDs[] = { IDI_FUNCLIST_SORTBUTTON, IDI_FUNCLIST_RELOADBUTTON, IDI_FUNCLIST_PREFERENCEBUTTON };
	static constexpr int iconDarkModeIDs[] = { IDI_FUNCLIST_SORTBUTTON_DM, IDI_FUNCLIST_RELOADBUTTON_DM, IDI_FUNCLIST_PREFERENCEBUTTON_DM };
	setPanelToolbarImageLists(_hToolbarMenu, _hInst, iconSize, iconIDs, iconDarkModeIDs, static_cast<int>(std::size(iconIDs)), _iconListVector);
}
'''),
('''	const int iconSizeDyn = _dpiManager.scale(16);
	setToolbarImageLists(iconSizeDyn);

	TBBUTTON tbSearchPlaceHolder{};
	tbSearchPlaceHolder.idCommand = 0;
	tbSearchPlaceHolder.iBitmap = _dpiManager.scale(105); // width of the separator
''',
'''	const int iconSizeDyn = _dpiManager.scale(toolbarIconSize);
	setToolbarImageLists(iconSizeDyn);

	TBBUTTON tbSearchPlaceHolder{};
	tbSearchPlaceHolder.idCommand = 0;
	tbSearchPlaceHolder.iBitmap = _dpiManager.scale(searchEditSepWidth); // width of the separator
'''),
('''	// search field
	LOGFONT lf{ _dpiManager.getDefaultGUIFontForDpi() };
	HFONT hFontSearchEdit = ::CreateFontIndirect(&lf);
	if (hFontSearchEdit != nullptr)
	{
		::SendMessage(_hSearchEdit, WM_SETFONT, reinterpret_cast<WPARAM>(hFontSearchEdit), MAKELPARAM(TRUE, 0));
		if (_hFontSearchEdit != nullptr)
		{
			::DeleteObject(_hFontSearchEdit);
		}
		_hFontSearchEdit = hFontSearchEdit;
	}
	::SetWindowPos(_hSearchEdit, nullptr, 0, 0, _dpiManager.scale(100), _dpiManager.scale(20), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
''',
'''	// search field
	DPIManagerV2::replaceWindowFont(_hSearchEdit, _dpiManager.getDefaultGUIFontForDpi(), _hFontSearchEdit);
	::SetWindowPos(_hSearchEdit, nullptr, 0, 0, _dpiManager.scale(searchEditWidth), _dpiManager.scale(searchEditHeight), SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
'''),
('''			const int editWidth = _dpiManager.scale(100);
			const int editWidthSep = _dpiManager.scale(105); //editWidth + 5
			const int editHeight = _dpiManager.scale(20);
''',
'''			const int editWidth = _dpiManager.scale(searchEditWidth);
			const int editWidthSep = _dpiManager.scale(searchEditSepWidth);
			const int editHeight = _dpiManager.scale(searchEditHeight);
'''),
('''			const int iconSizeDyn = _dpiManager.scale(16);
			constexpr int nbIcons = 3;
''',
'''			const int iconSizeDyn = _dpiManager.scale(toolbarIconSize);
			constexpr int nbIcons = 3;
'''),
])
