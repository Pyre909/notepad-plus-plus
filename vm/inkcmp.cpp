// inkcmp: how heavy GDI draws the bold of a GDI family name, against the faces DirectWrite picks for candidate weights.
// Everything is drawn by GDI (grayscale antialiasing, black on white) so that the ink is comparable: a DirectWrite face
// is drawn through its GDI LOGFONT (IDWriteGdiInterop::ConvertFontToLOGFONT).
// inkcmp.exe <pixel height> <GDI family name>...   Output: TSV lines.
#include <windows.h>
#include <dwrite.h>
#include <cstdio>
#include <string>
#include <vector>

#pragma comment(lib, "dwrite.lib")

static const wchar_t sample[] = L"The quick brown fox jumps over the lazy dog 0123456789 {}[]()<>;: if (x == 1) return y;";

struct Ink { double ink = 0; int width = 0; };

static Ink measure(const LOGFONTW& lf) {
	HDC dc = ::CreateCompatibleDC(nullptr);
	BITMAPINFO bi{};
	bi.bmiHeader.biSize = sizeof(bi.bmiHeader);
	bi.bmiHeader.biWidth = 2400; bi.bmiHeader.biHeight = -120; bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32;
	void* bits = nullptr;
	HBITMAP bmp = ::CreateDIBSection(dc, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	HGDIOBJ oldBmp = ::SelectObject(dc, bmp);
	RECT rc{ 0, 0, 2400, 120 };
	::FillRect(dc, &rc, static_cast<HBRUSH>(::GetStockObject(WHITE_BRUSH)));
	HFONT font = ::CreateFontIndirectW(&lf);
	HGDIOBJ oldFont = ::SelectObject(dc, font);
	::SetTextColor(dc, RGB(0, 0, 0)); ::SetBkMode(dc, TRANSPARENT);
	::TextOutW(dc, 10, 20, sample, static_cast<int>(wcslen(sample)));
	SIZE size{}; ::GetTextExtentPoint32W(dc, sample, static_cast<int>(wcslen(sample)), &size);
	::GdiFlush();
	Ink result; result.width = size.cx;
	const auto* px = static_cast<const unsigned char*>(bits);
	for (int i = 0; i < 2400 * 120; ++i)
		result.ink += 255 - px[i * 4 + 1]; // green
	::SelectObject(dc, oldFont); ::DeleteObject(font);
	::SelectObject(dc, oldBmp); ::DeleteObject(bmp); ::DeleteDC(dc);
	return result;
}

static LOGFONTW logFont(const wchar_t* name, int weight, int pixels) {
	LOGFONTW lf{};
	lf.lfHeight = -pixels; lf.lfWeight = weight; lf.lfCharSet = DEFAULT_CHARSET; lf.lfQuality = ANTIALIASED_QUALITY;
	wcsncpy_s(lf.lfFaceName, name, _TRUNCATE);
	return lf;
}

int wmain(int argc, wchar_t** argv) {
	if (argc < 3) return 2;
	const int pixels = _wtoi(argv[1]);
	IDWriteFactory* factory = nullptr;
	::DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown**>(&factory));
	IDWriteGdiInterop* interop = nullptr;
	factory->GetGdiInterop(&interop);
	wprintf(L"name\tpx\tbase\tgdiRegular\tgdiBold\tgdiBoldRatio");
	const int candidates[] = { 400, 500, 600, 700, 800, 900 };
	for (int w : candidates) wprintf(L"\tdw%d(face)\tdw%dRatio", w, w);
	wprintf(L"\n");
	for (int a = 2; a < argc; ++a) {
		const wchar_t* name = argv[a];
		const Ink regular = measure(logFont(name, FW_NORMAL, pixels));
		const Ink bold = measure(logFont(name, FW_BOLD, pixels));
		LOGFONTW lf = logFont(name, FW_NORMAL, pixels);
		IDWriteFont* baseFont = nullptr;
		if (FAILED(interop->CreateFontFromLOGFONT(&lf, &baseFont))) { wprintf(L"%s\tno DirectWrite font\n", name); continue; }
		IDWriteFontFamily* family = nullptr; baseFont->GetFontFamily(&family);
		wprintf(L"%s\t%d\t%d\t%.0f\t%.0f\t%.3f", name, pixels, static_cast<int>(baseFont->GetWeight()), regular.ink, bold.ink, bold.ink / regular.ink);
		for (int w : candidates) {
			IDWriteFont* face = nullptr;
			family->GetFirstMatchingFont(static_cast<DWRITE_FONT_WEIGHT>(w), baseFont->GetStretch(), DWRITE_FONT_STYLE_NORMAL, &face);
			LOGFONTW faceLf{}; BOOL isSystem = FALSE;
			interop->ConvertFontToLOGFONT(face, &faceLf, &isSystem);
			faceLf.lfHeight = -pixels; faceLf.lfQuality = ANTIALIASED_QUALITY;
			const bool simulated = face->GetSimulations() != DWRITE_FONT_SIMULATIONS_NONE;
			const Ink ink = measure(faceLf);
			wprintf(L"\t%d%s(%s %d)\t%.3f", w, simulated ? L"sim" : L"", faceLf.lfFaceName, static_cast<int>(face->GetWeight()), ink.ink / regular.ink);
			face->Release();
		}
		wprintf(L"\n");
		family->Release(); baseFont->Release();
	}
	interop->Release(); factory->Release();
	return 0;
}
