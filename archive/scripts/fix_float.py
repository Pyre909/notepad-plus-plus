import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
f = 'PowerEditor/src/WinControls/DockingWnd/DockingCont.h'
rep(f, '''	void doDialog(bool willBeShown = true, bool isFloating = false);
''', '''	void doDialog(bool willBeShown = true, bool isFloating = false);

	// places the floating container at its saved rectangle, whose size is kept (see WM_DPICHANGED)
	void setFloatingRect(RECT& rcFloat);
''')
rep(f, '''	// horizontal font for caption and tab
	HFONT _hFont = nullptr;
	HFONT _hFontCaption = nullptr;
''', '''	// horizontal font for caption and tab
	HFONT _hFont = nullptr;
	HFONT _hFontCaption = nullptr;

	bool _isFloatingRectPlacement = false;
''')
f = 'PowerEditor/src/WinControls/DockingWnd/DockingCont.cpp'
rep(f, '''	// restore position if plugin is in floating state
	if ((_isFloating) && (::SendMessage(_hContTab, TCM_GETITEMCOUNT, 0, 0) == 0))
	{
		reSizeToWH(pTbData->rcFloat);
	}
''', '''	// restore position if plugin is in floating state
	if ((_isFloating) && (::SendMessage(_hContTab, TCM_GETITEMCOUNT, 0, 0) == 0))
	{
		setFloatingRect(pTbData->rcFloat);
	}
''')
rep(f, '''			if (Message == WM_DPICHANGED)
			{
				// a floating container: the main window reloads the tab icons for the new DPI
				::PostMessage(::GetParent(_hParent), NPPM_INTERNAL_DPICHANGEDRELAYOUT, 0, 0);
				_dpiManager.setPositionDpi(lParam, _hSelf);
			}
			else
			{
				onSize();
			}
''', '''			if (Message == WM_DPICHANGED)
			{
				// a floating container: the main window reloads the tab icons for the new DPI
				::PostMessage(::GetParent(_hParent), NPPM_INTERNAL_DPICHANGEDRELAYOUT, 0, 0);
			}

			if ((Message == WM_DPICHANGED) && !_isFloatingRectPlacement)
			{
				_dpiManager.setPositionDpi(lParam, _hSelf);
			}
			else
			{
				onSize();
			}
''')
