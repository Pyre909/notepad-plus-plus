import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/DockingWnd/DockingManager.cpp', [
('''	// with the per-monitor DPI awareness, the window can be created on a monitor whose DPI isn't the system DPI
	if (DPIManagerV2::isPerMonitorV2Active())
	{
		const UINT dpi = DPIManagerV2::getDpiForWindow(_hParent);
		_splitterWidth = DPIManagerV2::scaleFromSystemDpi(SPLITTER_WIDTH, dpi);
		_minWorkWidth = DPIManagerV2::scaleFromSystemDpi(WORK_MIN_WIDTH, dpi);
	}
''',
'''	// the window can be created on a monitor whose DPI isn't the system DPI
	if (DPIManagerV2::isPerMonitorV2Active())
	{
		rescaleForDpi(DPIManagerV2::getDpiForWindow(_hParent), 0);
	}
'''),
('''	DpiSizeRef& ref = _dockedSizeRef[iCont];
	if ((ref.dpi == 0) || (size != ref.scaled))
	{
		// first DPI change, or the size has changed since the last one (user, layout): it's the new reference
		ref.size = size;
		ref.dpi = prevDpi;
	}
	size = DPIManagerV2::scale(static_cast<int>(ref.size), dpi, ref.dpi);
	ref.scaled = size;
''',
'''	DpiSizeRef& ref = _dockedSizeRef[iCont];
	if ((ref._dpi == 0) || (size != ref._scaled))
	{
		// first DPI change, or the size has changed since the last one (user, layout): it's the new reference
		ref._size = size;
		ref._dpi = prevDpi;
	}
	size = DPIManagerV2::scale(static_cast<int>(ref._size), dpi, ref._dpi);
	ref._scaled = size;
'''),
])

rep('PowerEditor/src/WinControls/DockingWnd/DockingManager.h', [
('''	// after a DPI change (per-monitor DPI awareness): sets the splitters width and the minimal views width for dpi, and rescales
	// the docked containers sizes from prevDpi (kept if prevDpi == dpi; round trips don't drift), the layout is updated on the next resize
	void rescaleForDpi(UINT dpi, UINT prevDpi);
''',
'''	// splitters width, minimal views width and docked containers sizes (from prevDpi, 0: none) for dpi, applied by the next resize
	void rescaleForDpi(UINT dpi, UINT prevDpi);
'''),
('''	// per docked container: the size the DPI changes rescale from (and its DPI), and the size the last one gave,
	// so that a round trip between DPIs doesn't accumulate rounding errors
	struct DpiSizeRef
	{
		LONG size = 0;
		UINT dpi = 0;
		LONG scaled = 0;
	};
''',
'''	// per docked container: the size the DPI changes rescale from, its DPI and the last result (no drift on round trips)
	struct DpiSizeRef
	{
		LONG _size = 0;
		UINT _dpi = 0;
		LONG _scaled = 0;
	};
'''),
])
