import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/ImageListSet/ImageListSet.h', [
('''	std::vector<IconList> _iconListVector;
};
''',
'''	std::vector<IconList> _iconListVector;
};

// the light and dark mode image lists of a panel's toolbar icons, replacing the ones of imageLists (destroyed),
// the one of the current mode is set to hToolbar
void setPanelToolbarImageLists(HWND hToolbar, HINSTANCE hInst, int iconSize, const int* iconIDs, const int* iconDarkModeIDs, int nbIcons, std::vector<HIMAGELIST>& imageLists);
'''),
])

rep('PowerEditor/src/WinControls/ImageListSet/ImageListSet.cpp', [
('''	return cleanup(hbmDst);
}
''',
'''	return cleanup(hbmDst);
}

void setPanelToolbarImageLists(HWND hToolbar, HINSTANCE hInst, int iconSize, const int* iconIDs, const int* iconDarkModeIDs, int nbIcons, std::vector<HIMAGELIST>& imageLists)
{
	HIMAGELIST hImageList = ImageList_Create(iconSize, iconSize, ILC_COLOR32 | ILC_MASK, nbIcons, 0);
	HIMAGELIST hImageListDm = ImageList_Create(iconSize, iconSize, ILC_COLOR32 | ILC_MASK, nbIcons, 0);

	for (int i = 0; i < nbIcons; ++i)
	{
		HICON hIcon = nullptr;
		DPIManagerV2::loadIcon(hInst, MAKEINTRESOURCE(iconIDs[i]), iconSize, iconSize, &hIcon, LR_LOADMAP3DCOLORS | LR_LOADTRANSPARENT);
		ImageList_AddIcon(hImageList, hIcon);
		::DestroyIcon(hIcon);
		hIcon = nullptr;

		DPIManagerV2::loadIcon(hInst, MAKEINTRESOURCE(iconDarkModeIDs[i]), iconSize, iconSize, &hIcon, LR_LOADMAP3DCOLORS | LR_LOADTRANSPARENT);
		ImageList_AddIcon(hImageListDm, hIcon);
		::DestroyIcon(hIcon);
	}

	// the image lists of a previous DPI are destroyed once replaced in the toolbar
	const std::vector<HIMAGELIST> prevImageLists = imageLists;
	imageLists = { hImageList, hImageListDm };
	::SendMessage(hToolbar, TB_SETIMAGELIST, 0, reinterpret_cast<LPARAM>(imageLists.at(NppDarkMode::isEnabled() ? 1 : 0)));

	for (HIMAGELIST hPrevImageList : prevImageLists)
	{
		if (hPrevImageList != nullptr)
			::ImageList_Destroy(hPrevImageList);
	}
}
'''),
])

rep('PowerEditor/src/WinControls/FileBrowser/fileBrowser.cpp', [
('''#include "fileBrowser.h"

#include <windows.h>
''',
'''#include "fileBrowser.h"

#include <windows.h>
'''),
('''#include "Common.h"
#include "DockingDlgInterface.h"
''',
'''#include "Common.h"
#include "DockingDlgInterface.h"
#include "ImageListSet.h"
'''),
('''#define FB_ADDFILE (WM_USER + 1024)''',
'''static constexpr int toolbarIconSize = 16; // for 96 DPI

#define FB_ADDFILE (WM_USER + 1024)'''),
('''			setDpi();
			const int iconSizeDyn = _dpiManager.scale(16);
			constexpr int nbIcons = 3;
''',
'''			setDpi();
			const int iconSizeDyn = _dpiManager.scale(toolbarIconSize);
			constexpr int nbIcons = 3;
'''),
('''void FileBrowser::setToolbarImageLists(int iconSize)
{
	constexpr int nbIcons = 3;
	int iconIDs[nbIcons] = { IDI_FB_SELECTCURRENTFILE, IDI_FB_FOLDALL, IDI_FB_EXPANDALL};
	int iconDarkModeIDs[nbIcons] = { IDI_FB_SELECTCURRENTFILE_DM, IDI_FB_FOLDALL_DM, IDI_FB_EXPANDALL_DM};

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
'''void FileBrowser::setToolbarImageLists(int iconSize)
{
	static constexpr int iconIDs[] = { IDI_FB_SELECTCURRENTFILE, IDI_FB_FOLDALL, IDI_FB_EXPANDALL };
	static constexpr int iconDarkModeIDs[] = { IDI_FB_SELECTCURRENTFILE_DM, IDI_FB_FOLDALL_DM, IDI_FB_EXPANDALL_DM };
	setPanelToolbarImageLists(_hToolbarMenu, _hInst, iconSize, iconIDs, iconDarkModeIDs, static_cast<int>(std::size(iconIDs)), _iconListVector);
}
'''),
('''	// toolbar: icons and buttons size, as in WM_INITDIALOG
	const int iconSizeDyn = _dpiManager.scale(16);
''',
'''	// toolbar: icons and buttons size, as in WM_INITDIALOG
	const int iconSizeDyn = _dpiManager.scale(toolbarIconSize);
'''),
])
