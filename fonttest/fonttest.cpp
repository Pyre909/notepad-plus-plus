// fonttest: does a GDI legacy family name of a weight ("Fira Code Light") render with its font under DirectWrite?
#include <windows.h>
#include <dwrite.h>
#include <cstdio>
#include <string>
#include <vector>
#include "Scintilla.h"

extern "C" int Scintilla_RegisterClasses(void *hInstance);

static HWND g_sci;
static sptr_t sci(unsigned m, uptr_t w = 0, sptr_t l = 0) { return ::SendMessage(g_sci, m, w, l); }

static void pump(int ms) {
	const DWORD end = ::GetTickCount() + ms;
	MSG msg;
	while (::GetTickCount() < end) {
		while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) { ::TranslateMessage(&msg); ::DispatchMessage(&msg); }
		::Sleep(10);
	}
}

// darkness sum ("ink") of the client area, text is black on white
static long long ink(HWND hwnd) {
	RECT rc; ::GetClientRect(hwnd, &rc);
	POINT pt{0, 0}; ::ClientToScreen(hwnd, &pt);
	const int w = rc.right, h = rc.bottom;
	HDC screen = ::GetDC(nullptr);
	HDC mem = ::CreateCompatibleDC(screen);
	BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader); bi.bmiHeader.biWidth = w; bi.bmiHeader.biHeight = -h;
	bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
	void *bits = nullptr;
	HBITMAP bmp = ::CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	HGDIOBJ old = ::SelectObject(mem, bmp);
	::BitBlt(mem, 0, 0, w, h, screen, pt.x, pt.y, SRCCOPY);
	long long sum = 0;
	const unsigned char *p = static_cast<const unsigned char *>(bits);
	for (int i = 0; i < w * h; ++i)
		sum += 255 - (p[i * 4] + p[i * 4 + 1] + p[i * 4 + 2]) / 3;
	::SelectObject(mem, old); ::DeleteObject(bmp); ::DeleteDC(mem); ::ReleaseDC(nullptr, screen);
	return sum;
}

static int CALLBACK enumProc(const LOGFONTW *lf, const TEXTMETRICW *, DWORD, LPARAM) {
	if (wcsstr(lf->lfFaceName, L"Fira")) wprintf(L"  GDI family: \"%ls\" weight %ld\n", lf->lfFaceName, lf->lfWeight);
	return 1;
}

int main() {
	HINSTANCE hInst = ::GetModuleHandle(nullptr);
	Scintilla_RegisterClasses(hInst);

	// GDI's view of the families
	wprintf(L"GDI EnumFontFamiliesEx:\n");
	HDC hdc = ::GetDC(nullptr);
	LOGFONTW lf{}; lf.lfCharSet = DEFAULT_CHARSET;
	::EnumFontFamiliesExW(hdc, &lf, enumProc, 0, 0);
	::ReleaseDC(nullptr, hdc);

	// DirectWrite's view of the families
	IDWriteFactory *factory = nullptr;
	if (SUCCEEDED(::DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(&factory)))) {
		IDWriteFontCollection *coll = nullptr;
		factory->GetSystemFontCollection(&coll);
		for (const wchar_t *name : { L"Fira Code", L"Fira Code Light", L"Fira Code Medium" }) {
			UINT32 index = 0; BOOL exists = FALSE;
			coll->FindFamilyName(name, &index, &exists);
			wprintf(L"DirectWrite FindFamilyName(\"%ls\"): %ls\n", name, exists ? L"found" : L"NOT found");
		}
		coll->Release(); factory->Release();
	}

	HWND top = ::CreateWindowExW(0, L"STATIC", L"fonttest", WS_OVERLAPPEDWINDOW | WS_VISIBLE, 0, 0, 900, 300, nullptr, nullptr, hInst, nullptr);
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE, 0, 0, 880, 260, top, nullptr, hInst, nullptr);
	sci(SCI_SETMARGINWIDTHN, 0, 0); sci(SCI_SETMARGINWIDTHN, 1, 0);
	sci(SCI_SETCARETSTYLE, CARETSTYLE_INVISIBLE);
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>("iiiiiiiiii mmmmmmmmmm\nWWWWWWWWWW 0123456789\nThe quick brown fox jumps over the lazy dog\n"));

	for (int tech : { SC_TECHNOLOGY_DEFAULT, SC_TECHNOLOGY_DIRECTWRITE }) {
		sci(SCI_SETTECHNOLOGY, tech);
		for (const char *face : { "Fira Code", "Fira Code Light", "Fira Code Medium" }) for (int bold : {0, 1}) {
			sci(SCI_STYLESETFONT, STYLE_DEFAULT, reinterpret_cast<sptr_t>(face));
			sci(SCI_STYLESETBOLD, STYLE_DEFAULT, bold);
			sci(SCI_STYLESETSIZE, STYLE_DEFAULT, 16);
			sci(SCI_STYLECLEARALL);
			::InvalidateRect(g_sci, nullptr, TRUE); ::UpdateWindow(g_sci); pump(400);
			const sptr_t wi = sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>("iiiii"));
			const sptr_t wW = sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>("WWWWW"));
			printf("bold=%d tech=%s font=%-18s width(iiiii)=%3ld width(WWWWW)=%3ld %s ink=%lld\n",
				bold, tech == SC_TECHNOLOGY_DEFAULT ? "GDI        " : "DirectWrite", face, (long)wi, (long)wW,
				wi == wW ? "monospace   " : "PROPORTIONAL", ink(g_sci));
		}
	}
	::DestroyWindow(top);
	return 0;
}
