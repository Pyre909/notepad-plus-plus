// hfontcrash: a style weight DirectWrite refuses leaves FontDirectWrite without a text format; does anything then call
// FontDirectWrite::HFont (autocompletion list, call tip, IME) and crash? Usage: hfontcrash.exe WEIGHT [autoc|calltip]
#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include "Scintilla.h"
extern "C" int Scintilla_RegisterClasses(void *hInstance);
static HWND g_sci;
static sptr_t sci(unsigned m, uptr_t w = 0, sptr_t l = 0) { return ::SendMessage(g_sci, m, w, l); }
static void pump(int ms) {
	const DWORD end = ::GetTickCount() + ms;
	MSG msg;
	while (static_cast<int>(::GetTickCount() - end) < 0) {
		while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) { ::TranslateMessage(&msg); ::DispatchMessage(&msg); }
		::Sleep(10);
	}
}
int main(int argc, char **argv) {
	const int weight = argc > 1 ? atoi(argv[1]) : 1000;
	const char *what = argc > 2 ? argv[2] : "autoc";
	HINSTANCE hInst = ::GetModuleHandle(nullptr);
	Scintilla_RegisterClasses(hInst);
	HWND top = ::CreateWindowExW(0, L"STATIC", L"hfontcrash", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0, 600, 300, nullptr, nullptr, hInst, nullptr);
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE, 0, 0, 580, 260, top, nullptr, hInst, nullptr);
	sci(SCI_SETTECHNOLOGY, SC_TECHNOLOGY_DIRECTWRITE);
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>("abc"));
	sci(SCI_STYLESETWEIGHT, STYLE_DEFAULT, weight);
	sci(SCI_STYLECLEARALL);
	pump(300);
	printf("weight %d set, technology %d\n", weight, static_cast<int>(sci(SCI_GETTECHNOLOGY)));
	fflush(stdout);
	sci(SCI_GOTOPOS, 3);
	if (strcmp(what, "calltip") == 0)
		sci(SCI_CALLTIPSHOW, 0, reinterpret_cast<sptr_t>("tip text"));
	else
		sci(SCI_AUTOCSHOW, 0, reinterpret_cast<sptr_t>("alpha beta gamma"));
	pump(800);
	printf("%s shown: no crash\n", what);
	fflush(stdout);
	::DestroyWindow(top);
	return 0;
}
