#!/usr/bin/python3
# patch.py SRC MODE: throwaway instrumentation of a COPY of PowerEditor/src (never of a worktree).
#  base: NPP_TEST_WINDOW_DPI overrides DPIManagerV2::getDpiForWindow() (so getDpiForParent too); the system DPI stays Wine's
#  new : the same + nppTestLog() lines (file NPP_TEST_LOG) with the values computed by the Stage 2 changes
# Prints the patched files (relative to SRC).
import sys, os

src, mode = sys.argv[1], sys.argv[2]
patched = []


def patch(rel, pairs):
    p = os.path.join(src, rel)
    data = open(p, 'rb').read().decode('utf-8')
    crlf = '\r\n' in data
    for old, new in pairs:
        if crlf:
            old = old.replace('\n', '\r\n')
            new = new.replace('\n', '\r\n')
        n = data.count(old)
        if n != 1:
            sys.stderr.write('patch %s: anchor found %d times: %r\n' % (rel, n, old[:80]))
            sys.exit(1)
        data = data.replace(old, new)
    open(p, 'wb').write(data.encode('utf-8'))
    patched.append(rel)


OVERRIDE = r'''
#include <cstdio>
#include <cstdarg>
#include <cwchar>

// TEST ONLY: NPP_TEST_WINDOW_DPI overrides the DPI of every window; otherwise the UINT of the file mapping "NppTestWindowDpi"
// (created by the test driver, which changes it before sending synthetic DPI change messages), if not 0
static UINT testWindowDpi()
{
	static const UINT dpi = []() -> UINT {
		wchar_t buf[16]{};
		return (::GetEnvironmentVariableW(L"NPP_TEST_WINDOW_DPI", buf, 16) > 0) ? static_cast<UINT>(std::wcstoul(buf, nullptr, 10)) : 0;
	}();
	if (dpi != 0)
		return dpi;
	static const volatile UINT* shared = []() -> const volatile UINT* {
		HANDLE h = ::OpenFileMappingW(FILE_MAP_READ, FALSE, L"NppTestWindowDpi");
		return h ? static_cast<const volatile UINT*>(::MapViewOfFile(h, FILE_MAP_READ, 0, 0, sizeof(UINT))) : nullptr;
	}();
	return shared ? *shared : 0;
}

// TEST ONLY: appends a line to the file NPP_TEST_LOG
void nppTestLog(const char* fmt, ...)
{
	wchar_t path[MAX_PATH]{};
	if (::GetEnvironmentVariableW(L"NPP_TEST_LOG", path, MAX_PATH) == 0)
		return;
	FILE* f = _wfopen(path, L"a");
	if (!f)
		return;
	va_list ap;
	va_start(ap, fmt);
	vfprintf(f, fmt, ap);
	va_end(ap);
	fputc('\n', f);
	fclose(f);
}
'''

patch('dpiManagerV2.cpp', [
    ('#include <commctrl.h>\n', '#include <commctrl.h>\n' + OVERRIDE),
    ('UINT DPIManagerV2::getDpiForWindow(HWND hWnd)\n{\n',
     'UINT DPIManagerV2::getDpiForWindow(HWND hWnd)\n{\n\tif (testWindowDpi() != 0)\n\t\treturn testWindowDpi();\n'),
    # Wine 9 has no V2 context: per-monitor V1 instead, so that the per-monitor code paths run
    ('\t\t_isPerMonitorV2Active = true;\n\t}\n\treturn _isPerMonitorV2Active;\n',
     '\t\t_isPerMonitorV2Active = true;\n\t}\n'
     '\telse if (DPIManagerV2::setThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE) != nullptr) // TEST ONLY\n'
     '\t{\n\t\t_isPerMonitorV2Active = true;\n\t}\n\treturn _isPerMonitorV2Active;\n'),
])

if mode == 'new':
    patch('dpiManagerV2.h', [('#include <windows.h>\n', '#include <windows.h>\n\nvoid nppTestLog(const char* fmt, ...); // TEST ONLY\n')])

    patch('WinControls/SplitterContainer/Splitter.cpp', [
        ('\t_clickZone2BR.top = rc.bottom - _clickZone2BR.bottom;\n',
         '\t_clickZone2BR.top = rc.bottom - _clickZone2BR.bottom;\n'
         '\tnppTestLog("splitter size=%d vertical=%d dpi=%u zone=%ldx%ld endMargin=%d", _splitterSize, isVertical() ? 1 : 0, '
         'DPIManagerV2::getDpiForWindow(_hSelf), _clickZone2TL.right, _clickZone2TL.bottom, scaleFromSystemDpi(5));\n'),
        ('\tif (isVertical())\n\t{\n\t\t// w=4 h=7\n',
         '\tnppTestLog("splitter arrow w=%d h=%d", w, h);\n\tif (isVertical())\n\t{\n\t\t// w=4 h=7\n'),
    ])

    patch('WinControls/DockingWnd/DockingManager.cpp', [
        ('\t\t_minWorkWidth = DPIManagerV2::scaleFromSystemDpi(WORK_MIN_WIDTH, dpi);\n\t}\n',
         '\t\t_minWorkWidth = DPIManagerV2::scaleFromSystemDpi(WORK_MIN_WIDTH, dpi);\n\t}\n'
         '\tnppTestLog("dock splitterWidth=%d minWorkWidth=%d", _splitterWidth, _minWorkWidth);\n'),
    ])

    patch('WinControls/DockingWnd/Gripper.cpp', [
        ('\tconst LONG hitTestThickness = scaleFromSystemDpi(HIT_TEST_THICKNESS, _hParent);\n',
         '\tconst LONG hitTestThickness = scaleFromSystemDpi(HIT_TEST_THICKNESS, _hParent);\n'
         '\tnppTestLog("gripper hitTestThickness=%ld gripperOffset=%d", hitTestThickness, scaleFromSystemDpi(20, _hParent));\n'),
        ('\t\tconst LONG frame = scaleFromSystemDpi(3, _pCont->getHSelf());\n',
         '\t\tconst LONG frame = scaleFromSystemDpi(3, _pCont->getHSelf());\n\t\tnppTestLog("gripper frame=%ld", frame);\n'),
    ])

    patch('WinControls/TaskList/TaskList.cpp', [
        ('\t_rc.bottom += (DPIManagerV2::getSystemMetricsForWindow(SM_CYFRAME, _hParent) + paddedBorder - 1) * 2;\n',
         '\t_rc.bottom += (DPIManagerV2::getSystemMetricsForWindow(SM_CYFRAME, _hParent) + paddedBorder - 1) * 2;\n'
         '\tnppTestLog("tasklist dpi=%u paddedBorder=%d cxframe=%d cyframe=%d (system %d %d %d) leftMarge=%d maxHeight=%ld rc=%ldx%ld", '
         'DPIManagerV2::getDpiForWindow(_hParent), paddedBorder, DPIManagerV2::getSystemMetricsForWindow(SM_CXFRAME, _hParent), '
         'DPIManagerV2::getSystemMetricsForWindow(SM_CYFRAME, _hParent), ::GetSystemMetrics(SM_CXPADDEDBORDER), ::GetSystemMetrics(SM_CXFRAME), '
         '::GetSystemMetrics(SM_CYFRAME), leftMarge, maxHeight, _rc.right, _rc.bottom);\n'),
    ])

    patch('Notepad_plus.cpp', [
        ('\tconst int borderSize = DPIManagerV2::scaleFromSystemDpiForWindow(1, _pPublicInterface->getHSelf());\n',
         '\tconst int borderSize = DPIManagerV2::scaleFromSystemDpiForWindow(1, _pPublicInterface->getHSelf());\n'
         '\tnppTestLog("menu colour bitmap size=%d border=%d", bitmapXYsize, borderSize);\n'),
    ])

    patch('WinControls/AboutDlg/AboutDlg.cpp', [
        ('\t// Use the system font height but change to monospace\n\tHFONT hNewFont',
         '\tnppTestLog("cmdlineargs dpi=%u fontHeight=%ld", _dpiManager.getDpi(), fontHeight);\n'
         '\t// Use the system font height but change to monospace\n\tHFONT hNewFont'),
    ])

    patch('WinControls/StaticDialog/StaticDialog.cpp', [
        ('\t\tint margin = DPIManagerV2::getSystemMetricsForWindow(SM_CYSMCAPTION, _hSelf);\n',
         '\t\tint margin = DPIManagerV2::getSystemMetricsForWindow(SM_CYSMCAPTION, _hSelf);\n'
         '\t\tnppTestLog("staticdialog display margin=%d (system %d)", margin, ::GetSystemMetrics(SM_CYSMCAPTION));\n'),
    ])

    patch('WinControls/Grid/BabyGrid.cpp', [
        ('\t\t\t\tif (innerHeight <= BGHS[SelfIndex].rowheight * 4)\n',
         '\t\t\t\tnppTestLog("babygrid cyedge=%d cyhscroll=%d (system %d %d)", DPIManagerV2::getSystemMetricsForWindow(SM_CYEDGE, hWnd), '
         'DPIManagerV2::getSystemMetricsForWindow(SM_CYHSCROLL, hWnd), ::GetSystemMetrics(SM_CYEDGE), ::GetSystemMetrics(SM_CYHSCROLL));\n'
         '\t\t\t\tif (innerHeight <= BGHS[SelfIndex].rowheight * 4)\n'),
    ])

    patch('MISC/Common/Common.cpp', [
        ('\tSendMessage(hwndTip, TTM_SETMAXTIPWIDTH, 0, DPIManagerV2::scaleFromSystemDpiForWindow(200, hDlg));\n',
         '\tSendMessage(hwndTip, TTM_SETMAXTIPWIDTH, 0, DPIManagerV2::scaleFromSystemDpiForWindow(200, hDlg));\n'
         '\tnppTestLog("createToolTip maxWidth=%d", DPIManagerV2::scaleFromSystemDpiForWindow(200, hDlg));\n'),
    ])

    patch('WinControls/DockingWnd/DockingCont.cpp', [
        ('\t\t\t\t_dpiManager.setDpi(_hParent);\n\t\t\t\tsetDpiDynamicalSizes();\n\t\t\t}\n',
         '\t\t\t\t_dpiManager.setDpi(_hParent);\n\t\t\t\tsetDpiDynamicalSizes();\n\t\t\t}\n'
         '\t\t\tnppTestLog("dockcont dpi=%u caption=%d closeBtn=%d captionTextRightMargin=%d tooltipOffset=%d", _dpiManager.getDpi(), '
         '_captionHeightDynamic, _closeButtonWidth, scaleFromSystemDpi(16), scaleFromSystemDpi(20));\n'),
    ])

    patch('NppBigSwitch.cpp', [
        ('\t\t\t\t\tsetupColorSampleBitmapsOnMainMenuItems();\n\t\t\t\t}\n',
         '\t\t\t\t\tnppTestLog("WM_DPICHANGED %u -> %u: menu colour bitmaps", prevDpi, dpi);\n'
         '\t\t\t\t\tsetupColorSampleBitmapsOnMainMenuItems();\n\t\t\t\t}\n'),
    ])

    patch('winmain.cpp', [
        ('\tauto upNotepadWindow = std::make_unique<Notepad_plus_Window>();\n',
         '\tnppTestLog("startup perMonitorDpiAwareness=%d active=%d systemDpi=%u", nppGui._perMonitorDpiAwareness ? 1 : 0, '
         'DPIManagerV2::isPerMonitorV2Active() ? 1 : 0, DPIManagerV2::getDpiForSystem());\n'
         '\tauto upNotepadWindow = std::make_unique<Notepad_plus_Window>();\n'),
    ])

print('\n'.join(patched))
