import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/SplitterContainer/Splitter.cpp', [
('''int Splitter::scaleFromSystemDpi(int x) const
{
	return DPIManagerV2::scaleFromSystemDpiForWindow(x, _hSelf);
}


''', ''),
('''	const int zoneThickness = scaleFromSystemDpi(8);
	const int zoneLength = scaleFromSystemDpi(HEIGHT_MINIMAL);
''',
'''	const int zoneThickness = DPIManagerV2::scaleFromSystemDpiForWindow(8, _hSelf);
	const int zoneLength = DPIManagerV2::scaleFromSystemDpiForWindow(HEIGHT_MINIMAL, _hSelf);
'''),
('''			: (which == WH::width ? zoneLength : _splitterSize);
	}
	else // (_splitterSize > 8)
''',
'''			: (which == WH::width ? zoneLength : _splitterSize);
	}
	else // (_splitterSize > zoneThickness)
'''),
('''				const int endMargin = scaleFromSystemDpi(5);
''',
'''				const int endMargin = DPIManagerV2::scaleFromSystemDpiForWindow(5, _hSelf);
'''),
('''	if (_splitterSize < scaleFromSystemDpi(4))
		return;

	int x0 = 0, y0 = 0, x1 = 0, y1 = 0, w = 0, h = 0;

	if (/*(4 <= _splitterSize) && */(_splitterSize <= scaleFromSystemDpi(8)))
	{
		w = scaleFromSystemDpi(isVertical() ? 4 : 7);
		h = scaleFromSystemDpi(isVertical() ? 7 : 4);
	}
	else // (_splitterSize > 8)
	{
		w = scaleFromSystemDpi(isVertical() ? 6  : 11);
		h = scaleFromSystemDpi(isVertical() ? 11 : 6);
	}
''',
'''	if (_splitterSize < DPIManagerV2::scaleFromSystemDpiForWindow(4, _hSelf))
		return;

	int x0 = 0, y0 = 0, x1 = 0, y1 = 0, w = 0, h = 0;

	if (/*(4 <= _splitterSize) && */(_splitterSize <= DPIManagerV2::scaleFromSystemDpiForWindow(8, _hSelf)))
	{
		w = DPIManagerV2::scaleFromSystemDpiForWindow(isVertical() ? 4 : 7, _hSelf);
		h = DPIManagerV2::scaleFromSystemDpiForWindow(isVertical() ? 7 : 4, _hSelf);
	}
	else // (_splitterSize > 8 pixels of the system DPI)
	{
		w = DPIManagerV2::scaleFromSystemDpiForWindow(isVertical() ? 6 : 11, _hSelf);
		h = DPIManagerV2::scaleFromSystemDpiForWindow(isVertical() ? 11 : 6, _hSelf);
	}
'''),
('''	// both zones, their sizes can follow the DPI (per-monitor DPI awareness)
''',
'''	// both zones, their sizes can follow the DPI
'''),
])

rep('PowerEditor/src/WinControls/SplitterContainer/Splitter.h', [
('''	// x in pixels of the system DPI (legacy sizes), for the DPI of the splitter with the per-monitor DPI awareness
	int scaleFromSystemDpi(int x) const;
''', ''),
])

rep('PowerEditor/src/WinControls/SplitterContainer/SplitterContainer.h', [
('''	// e.g. after a DPI change, the new size is applied by the next reSizeTo()
	void setSplitterSize(int splitterSize)
	{
		_splitterSize = splitterSize;
		_splitter.setSplitterSize(splitterSize);
	}
''',
'''	// e.g. after a DPI change, the new size is applied by the next reSizeTo()
	void setSplitterSize(int splitterSize);
'''),
])

rep('PowerEditor/src/WinControls/SplitterContainer/SplitterContainer.cpp', [
('''void SplitterContainer::reSizeTo(RECT & rc)
{
	_x = rc.left;
	_y = rc.top;
	::MoveWindow(_hSelf, _x, _y, rc.right, rc.bottom, FALSE);
	_splitter.resizeSpliter();
}
''',
'''void SplitterContainer::reSizeTo(RECT & rc)
{
	_x = rc.left;
	_y = rc.top;
	::MoveWindow(_hSelf, _x, _y, rc.right, rc.bottom, FALSE);
	_splitter.resizeSpliter();
}


void SplitterContainer::setSplitterSize(int splitterSize)
{
	_splitterSize = splitterSize;
	_splitter.setSplitterSize(splitterSize);
}
'''),
])
