import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/DockingWnd/Gripper.h', [
('''	// x in pixels of the system DPI (legacy sizes), for the DPI of hWnd with the per-monitor DPI awareness
	static int scaleFromSystemDpi(int x, HWND hWnd) {
		return DPIManagerV2::scaleFromSystemDpiForWindow(x, hWnd);
	}
	void DoCalcGripperRect(RECT* rc, RECT rcCorr, POINT pt) {
		if ((rc->left + rc->right) < pt.x)
			rc->left = pt.x - scaleFromSystemDpi(20, _hParent);
''',
'''	void DoCalcGripperRect(RECT* rc, RECT rcCorr, POINT pt) {
		if ((rc->left + rc->right) < pt.x)
			rc->left = pt.x - DPIManagerV2::scaleFromSystemDpiForWindow(20, _hParent);
'''),
])

rep('PowerEditor/src/WinControls/DockingWnd/Gripper.cpp', [
('''		// frame thickness in pixels of the system DPI, for the DPI of the moved container with the per-monitor DPI awareness
		const LONG frame = scaleFromSystemDpi(3, _pCont->getHSelf());
''',
'''		// frame thickness in pixels of the system DPI
		const LONG frame = DPIManagerV2::scaleFromSystemDpiForWindow(3, _pCont->getHSelf());
'''),
('''				if ((rc.top < pt.y) && (pt.y < (rc.top + scaleFromSystemDpi(24, vCont[iCont]->getHSelf()))))''',
'''				if ((rc.top < pt.y) && (pt.y < (rc.top + DPIManagerV2::scaleFromSystemDpiForWindow(24, vCont[iCont]->getHSelf()))))'''),
('''	/* the thickness is in pixels of the system DPI, for the DPI of the main window with the per-monitor DPI awareness */
	const LONG hitTestThickness = scaleFromSystemDpi(HIT_TEST_THICKNESS, _hParent);
''',
'''	// in pixels of the system DPI
	const LONG hitTestThickness = DPIManagerV2::scaleFromSystemDpiForWindow(HIT_TEST_THICKNESS, _hParent);
'''),
])
