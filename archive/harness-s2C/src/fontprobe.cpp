// fontprobe.cpp - prints the LOGFONT of a DS_SHELLFONT dialog font (MS Shell Dlg 8) under the current Wine DPI,
// and the text extent of a sample with it and with a copy scaled from/to another DPI
#include <windows.h>
#include <cstdio>
#include <vector>

static void dumpFont(const char* what, HFONT hFont)
{
	LOGFONTW lf{};
	GetObjectW(hFont, sizeof(lf), &lf);
	HDC dc = GetDC(nullptr);
	HGDIOBJ old = SelectObject(dc, hFont);
	SIZE sz{};
	GetTextExtentPoint32W(dc, L"User language:", 14, &sz);
	TEXTMETRICW tm{};
	GetTextMetricsW(dc, &tm);
	SelectObject(dc, old);
	ReleaseDC(nullptr, dc);
	printf("%s: h=%ld w=%ld weight=%ld charset=%d quality=%d pitch=%d face='%ls' -> extent %ldx%ld tmHeight=%ld tmAveCharWidth=%ld\n", what, lf.lfHeight, lf.lfWidth,
		lf.lfWeight, lf.lfCharSet, lf.lfQuality, lf.lfPitchAndFamily, lf.lfFaceName, sz.cx, sz.cy, tm.tmHeight, tm.tmAveCharWidth);
}

int main(int argc, char** argv)
{
	SetProcessDPIAware();
	const int otherDpi = (argc > 1) ? atoi(argv[1]) : 96;
	// DLGTEMPLATEEX with DS_SETFONT | DS_FIXEDSYS, FONT 8, "MS Shell Dlg"
	std::vector<WORD> t;
	auto dw = [&](DWORD v) { t.push_back(LOWORD(v)); t.push_back(HIWORD(v)); };
	t.push_back(1); t.push_back(0xFFFF); dw(0); dw(0); dw(DS_SETFONT | DS_FIXEDSYS | WS_POPUP);
	t.push_back(0); t.push_back(0); t.push_back(0); t.push_back(100); t.push_back(50);
	t.push_back(0); t.push_back(0); t.push_back(0); // menu, class, title
	t.push_back(8); t.push_back(0); t.push_back(0); // pointsize, weight, italic|charset
	for (const wchar_t* p = L"MS Shell Dlg"; ; ++p) { t.push_back(*p); if (!*p) break; }
	HWND dlg = CreateDialogIndirectParamW(GetModuleHandleW(nullptr), reinterpret_cast<LPCDLGTEMPLATEW>(t.data()), nullptr,
		[](HWND, UINT, WPARAM, LPARAM) -> INT_PTR { return FALSE; }, 0);
	if (!dlg) { printf("no dialog %lu\n", GetLastError()); return 1; }
	HDC dc = GetDC(nullptr);
	printf("LOGPIXELSY=%d\n", GetDeviceCaps(dc, LOGPIXELSY));
	ReleaseDC(nullptr, dc);
	RECT r{0, 0, 4, 8};
	MapDialogRect(dlg, &r);
	printf("base units cx=%ld cy=%ld\n", r.right, r.bottom);
	HFONT hf = reinterpret_cast<HFONT>(SendMessageW(dlg, WM_GETFONT, 0, 0));
	dumpFont("dialog font", hf);
	LOGFONTW lf{};
	GetObjectW(hf, sizeof(lf), &lf);
	HDC dc2 = GetDC(nullptr);
	const int dpi = GetDeviceCaps(dc2, LOGPIXELSY);
	ReleaseDC(nullptr, dc2);
	lf.lfHeight = MulDiv(lf.lfHeight, otherDpi, dpi);
	HFONT hf2 = CreateFontIndirectW(&lf);
	char what[64];
	snprintf(what, sizeof(what), "scaled to %d", otherDpi);
	dumpFont(what, hf2);
	LOGFONTW lf3{};
	GetObjectW(hf, sizeof(lf3), &lf3);
	lf3.lfHeight = -MulDiv(8, otherDpi, 72);
	HFONT hf3 = CreateFontIndirectW(&lf3);
	snprintf(what, sizeof(what), "8pt for %d", otherDpi);
	dumpFont(what, hf3);
	return 0;
}
