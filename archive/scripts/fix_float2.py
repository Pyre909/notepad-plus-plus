import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
f = 'PowerEditor/src/WinControls/DockingWnd/DockingCont.cpp'
rep(f, '''	display(willBeShown);
}


DockedWidgetData* DockingCont::createDockedWidget(const DockedWidgetData& data)''', '''	display(willBeShown);
}

void DockingCont::setFloatingRect(RECT& rcFloat)
{
	// With the per-monitor DPI awareness, the rectangle is saved in the pixels of its monitor:
	// a move to a monitor of another DPI sends WM_DPICHANGED, whose suggested size must not be applied
	_isFloatingRectPlacement = true;
	reSizeToWH(rcFloat);
	_isFloatingRectPlacement = false;
}


DockedWidgetData* DockingCont::createDockedWidget(const DockedWidgetData& data)''')
f = 'PowerEditor/src/WinControls/DockingWnd/DockingManager.cpp'
rep(f, '''				pCont->doDialog(false, true);
				pCont->reSizeToWH(data.rcFloat);''', '''				pCont->doDialog(false, true);
				pCont->setFloatingRect(data.rcFloat);''')
