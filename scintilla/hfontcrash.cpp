// hfontcrash: with DirectWrite, a style weight DirectWrite refuses leaves FontDirectWrite without a text format;
// showing an autocompletion list then crashes in FontDirectWrite::HFont (called by ListBoxX::SetFont).
//
// Usage: hfontcrash [weight]      default 1000: crashes; 400: works (under Wine 9: weights below 0 or above 950 crash)
//
// Build with MinGW-w64 against the static library built by win32/makefile:
//   g++ -std=c++17 -I<scintilla>/include hfontcrash.cpp <scintilla>/bin/libscintilla.a -static -mconsole
//       -lgdi32 -luser32 -limm32 -lmsimg32 -lole32 -loleaut32 -luuid -lcomctl32 -luxtheme -lshcore -ldwmapi -ldwrite -o hfontcrash.exe
#include <windows.h>
#include <cstdio>
#include <cstdlib>
#include "Scintilla.h"

extern "C" int Scintilla_RegisterClasses(void *hInstance);

static HWND g_sci;
static sptr_t sci(unsigned m, uptr_t w = 0, sptr_t l = 0) { return ::SendMessage(g_sci, m, w, l); }

static void pump(int ms) {
	const DWORD end = ::GetTickCount() + ms;
	MSG msg;
	while (static_cast<int>(::GetTickCount() - end) < 0) {
		while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) {
			::TranslateMessage(&msg);
			::DispatchMessage(&msg);
		}
		::Sleep(10);
	}
}

int main(int argc, char **argv) {
	const int weight = argc > 1 ? atoi(argv[1]) : 1000;
	HINSTANCE hInst = ::GetModuleHandle(nullptr);
	Scintilla_RegisterClasses(hInst);
	HWND top = ::CreateWindowExW(0, L"STATIC", L"hfontcrash", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0, 600, 300, nullptr, nullptr, hInst, nullptr);
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE, 0, 0, 580, 260, top, nullptr, hInst, nullptr);

	sci(SCI_SETTECHNOLOGY, SC_TECHNOLOGY_DIRECTWRITE);
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>("abc"));
	sci(SCI_STYLESETWEIGHT, STYLE_DEFAULT, weight);	// Windows documents 1..999 as valid; Wine 9 accepts 0..950
	sci(SCI_STYLECLEARALL);
	pump(300);
	printf("weight %d set, technology %d\n", weight, static_cast<int>(sci(SCI_GETTECHNOLOGY)));
	fflush(stdout);

	sci(SCI_GOTOPOS, 3);
	sci(SCI_AUTOCSHOW, 0, reinterpret_cast<sptr_t>("alpha beta gamma"));	// crashes here with weight 1000
	pump(800);
	printf("autocompletion shown: no crash\n");
	fflush(stdout);
	::DestroyWindow(top);
	return 0;
}
