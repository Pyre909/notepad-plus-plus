// SmoothTest plugin (test only): changes the Windows font smoothing from inside the Notepad++ process, so that
// the process sees the new value under Wine (which caches SystemParametersInfo per process).
// Its hidden "SmoothTestHelper" window takes WM_APP: wParam 0 = off, 1 = standard, 2 = ClearType;
// lParam 1 = SPIF_SENDCHANGE (the system broadcast), 2 = no broadcast, WM_SETTINGCHANGE sent to Notepad++ directly.
#include <windows.h>

struct NppData {
	HWND _nppHandle = nullptr;
	HWND _scintillaMainHandle = nullptr;
	HWND _scintillaSecondHandle = nullptr;
};
struct ShortcutKey {
	bool _isCtrl, _isAlt, _isShift;
	UCHAR _key;
};
typedef void (__cdecl *PFUNCPLUGINCMD)();
struct FuncItem {
	wchar_t _itemName[64];
	PFUNCPLUGINCMD _pFunc;
	int _cmdID;
	bool _init2Check;
	ShortcutKey *_pShKey;
};

static NppData g_npp;
static void __cdecl noop() {}
static FuncItem g_items[1] = { { L"SmoothTest", noop, 0, false, nullptr } };

static void settingChange(UINT action, LPARAM mode) {
	if (mode == 2)
		::SendMessageW(g_npp._nppHandle, WM_SETTINGCHANGE, action, reinterpret_cast<LPARAM>(L""));
}

static LRESULT CALLBACK helperProc(HWND h, UINT msg, WPARAM wParam, LPARAM lParam) {
	if (msg == WM_APP) {
		const UINT winIni = (lParam == 1) ? SPIF_SENDCHANGE : 0;
		::SystemParametersInfoW(SPI_SETFONTSMOOTHING, wParam != 0, nullptr, winIni);
		settingChange(SPI_SETFONTSMOOTHING, lParam);
		if (wParam != 0) {
			const UINT_PTR type = (wParam == 1) ? FE_FONTSMOOTHINGSTANDARD : FE_FONTSMOOTHINGCLEARTYPE;
			::SystemParametersInfoW(SPI_SETFONTSMOOTHINGTYPE, 0, reinterpret_cast<PVOID>(type), winIni);
			settingChange(SPI_SETFONTSMOOTHINGTYPE, lParam);
		}
		return 1;
	}
	return ::DefWindowProcW(h, msg, wParam, lParam);
}

extern "C" __declspec(dllexport) void setInfo(NppData data) {
	g_npp = data;
	WNDCLASSW wc{};
	wc.lpfnWndProc = helperProc;
	wc.hInstance = ::GetModuleHandleW(nullptr);
	wc.lpszClassName = L"SmoothTestHelper";
	::RegisterClassW(&wc);
	::CreateWindowExW(0, L"SmoothTestHelper", L"SmoothTestHelper", WS_POPUP, 0, 0, 0, 0, nullptr, nullptr, wc.hInstance, nullptr);
}
extern "C" __declspec(dllexport) const wchar_t *getName() { return L"SmoothTest"; }
extern "C" __declspec(dllexport) FuncItem *getFuncsArray(int *nb) { *nb = 1; return g_items; }
extern "C" __declspec(dllexport) void beNotified(void *) {}
extern "C" __declspec(dllexport) LRESULT messageProc(UINT, WPARAM, LPARAM) { return TRUE; }
extern "C" __declspec(dllexport) BOOL isUnicode() { return TRUE; }
