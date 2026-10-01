// hfprobe WEIGHT STRETCH: with DirectWrite, sets the default style's weight and stretch, prints the width of "abc"
// (0: no font was created) and shows an autocompletion list (crashes in FontDirectWrite::HFont without a font)
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
		while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) { ::TranslateMessage(&msg); ::DispatchMessage(&msg); }
		::Sleep(10);
	}
}
int main(int argc, char **argv) {
	const int weight = argc > 1 ? atoi(argv[1]) : 400;
	const int stretch = argc > 2 ? atoi(argv[2]) : 5;
	HINSTANCE hInst = ::GetModuleHandle(nullptr);
	Scintilla_RegisterClasses(hInst);
	HWND top = ::CreateWindowExW(0, L"STATIC", L"hfprobe", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0, 600, 300, nullptr, nullptr, hInst, nullptr);
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE, 0, 0, 580, 260, top, nullptr, hInst, nullptr);
	sci(SCI_SETTECHNOLOGY, SC_TECHNOLOGY_DIRECTWRITE);
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>("abc"));
	sci(SCI_STYLESETFONT, STYLE_DEFAULT, reinterpret_cast<sptr_t>("Fira Code"));
	sci(SCI_STYLESETSIZE, STYLE_DEFAULT, 16);
	sci(SCI_STYLESETWEIGHT, STYLE_DEFAULT, weight);
	sci(SCI_STYLESETSTRETCH, STYLE_DEFAULT, stretch);
	sci(SCI_STYLECLEARALL);
	pump(300);
	printf("width %d\n", static_cast<int>(sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>("abc"))));
	fflush(stdout);
	sci(SCI_GOTOPOS, 3);
	sci(SCI_AUTOCSHOW, 0, reinterpret_cast<sptr_t>("alpha beta gamma"));
	pump(600);
	printf("no crash\n");
	fflush(stdout);
	::DestroyWindow(top);
	return 0;
}
