// fontcheck: do the fonts of the font list names containing a text (default "MonoLisa") draw with their own font
// in this Notepad++ build? Its Scintilla draws each name as Notepad++ does, compared with a reference: the font
// Windows itself maps the name to at its own weight, drawn by its DirectWrite family and weight (or by GDI).
// Usage: fontcheck.exe [text...] [points]   - e.g. fontcheck.exe MonoLisa Cascadia Bahnschrift 11
//   the report is printed and written to fontcheck.txt next to the exe.
// A window shows the text drawn for a few seconds: leave it uncovered until the report is written.
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <dwrite_3.h>
#include <wrl/client.h>
#include <cstdio>
#include <cstdarg>
#include <cwchar>
#include <cmath>
#include <string>
#include <vector>
#include <set>
#include <map>
#include <algorithm>
#include <initializer_list>
#include "Scintilla.h"

extern "C" int Scintilla_RegisterClasses(void *hInstance);
using Microsoft::WRL::ComPtr;

static FILE *g_out = nullptr;
static void out(const wchar_t *fmt, ...) {
	va_list ap; va_start(ap, fmt);
	wchar_t buf[4096]; vswprintf(buf, 4096, fmt, ap); va_end(ap);
	fputws(buf, stdout); fflush(stdout);
	if (g_out) fputws(buf, g_out);
}
static std::wstring lower(std::wstring s) { for (auto &c : s) c = static_cast<wchar_t>(towlower(c)); return s; }
static std::string utf8(const std::wstring &w) {
	const int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
	std::string s(n, 0); WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, s.data(), n, nullptr, nullptr);
	s.resize(n - 1); return s;
}

static const char *const g_lines[] = {
	"iiiii lllll mmmmm WWWWW 0O8B@# ~%&",
	"The quick brown fox jumps over it",
	"=> != <= {}[]() 0123456789 ;:,.'\"",
};
static int clientW = 760, clientH = 150, textX = 8, lineStep = 40;	// at 96 DPI, scaled

struct Render { long long ink = 0; unsigned long long hash = 0; bool done = false; };

struct Oracle {	// the font Windows maps a GDI family name to at its own weight
	bool ok = false;
	std::wstring source, family, axes;
	int weight = 400, stretch = 5, style = 0, copies = 0;
};

struct Family {	// a GDI family: a name of the font lists
	std::wstring face;
	LONG regular = 0;	// weight of its upright font closest to normal
	bool hasItalic = false;
	bool dwFamily = false;	// also a DirectWrite family name
	int dwFamilySimulation = 0;	// simulations of DirectWrite's match of it for the regular weight
	Oracle oracle, oracleItalic;
	Render dwNormal, dwBold, dwItalic, dwRef, dwRefItalic, gdiNormal, gdiBold, gdiRef, gdiAt400;
};

// ---- GDI families
static std::vector<std::wstring> g_texts;
static std::wstring g_text;	// the texts, for the report
static bool matches(const std::wstring &name) {
	for (const auto &t : g_texts) if (lower(name).find(lower(t)) != std::wstring::npos) return true;
	return false;
}
static std::set<std::wstring> g_faces;
static int CALLBACK enumFaces(const LOGFONTW *lf, const TEXTMETRICW *, DWORD, LPARAM) {
	const auto *elf = reinterpret_cast<const ENUMLOGFONTEXW *>(lf);
	if (lf->lfFaceName[0] != L'@' && (matches(lf->lfFaceName) || matches(elf->elfFullName)))
		g_faces.insert(lf->lfFaceName);
	return 1;
}
static int CALLBACK enumMembers(const LOGFONTW *lf, const TEXTMETRICW *, DWORD, LPARAM lParam) {
	Family &f = *reinterpret_cast<Family *>(lParam);
	if (lf->lfItalic) { f.hasItalic = true; return 1; }
	if (lf->lfWeight <= 0) return 1;
	const LONG d = std::abs(lf->lfWeight - 400), dr = std::abs(f.regular - 400);
	if (f.regular == 0 || d < dr || (d == dr && lf->lfWeight < f.regular)) f.regular = lf->lfWeight;
	return 1;
}

// ---- DirectWrite
static ComPtr<IDWriteFactory> g_dw;
static ComPtr<IDWriteFontCollection> g_coll;
static std::wstring firstString(IDWriteLocalizedStrings *s) {
	if (!s || !s->GetCount()) return L"";
	UINT32 i = 0; BOOL ex = FALSE;
	if (FAILED(s->FindLocaleName(L"en-us", &i, &ex)) || !ex) i = 0;
	UINT32 n = 0; s->GetStringLength(i, &n);
	std::wstring v(n + 1, 0); s->GetString(i, v.data(), n + 1); v.resize(n); return v;
}
static bool hasInfo(IDWriteFont *font, DWRITE_INFORMATIONAL_STRING_ID id, const std::wstring &value) {
	ComPtr<IDWriteLocalizedStrings> s; BOOL ex = FALSE;
	if (FAILED(font->GetInformationalStrings(id, s.GetAddressOf(), &ex)) || !ex) return false;
	for (UINT32 i = 0; i < s->GetCount(); ++i) {
		UINT32 n = 0; s->GetStringLength(i, &n);
		std::wstring v(n + 1, 0); s->GetString(i, v.data(), n + 1); v.resize(n);
		if (_wcsicmp(v.c_str(), value.c_str()) == 0) return true;
		// GDI truncates family names to 31 characters
		if (value.length() == LF_FACESIZE - 1 && v.length() > value.length() && _wcsicmp(v.substr(0, value.length()).c_str(), value.c_str()) == 0) return true;
	}
	return false;
}
static std::wstring axes(IDWriteFont *font) {
	ComPtr<IDWriteFontFace> face; ComPtr<IDWriteFontFace5> face5;
	if (FAILED(font->CreateFontFace(face.GetAddressOf())) || FAILED(face.As(&face5))) return L"";
	if (!face5->HasVariations()) return L"static";
	const UINT32 n = face5->GetFontAxisValueCount();
	std::vector<DWRITE_FONT_AXIS_VALUE> v(n); face5->GetFontAxisValues(v.data(), n);
	for (auto &a : v) if (a.axisTag == DWRITE_FONT_AXIS_TAG_WEIGHT) { wchar_t b[32]; swprintf(b, 32, L"variable wght=%g", a.value); return b; }
	return L"variable";
}
static void fillOracle(Oracle &o, IDWriteFont *font, const wchar_t *source) {
	ComPtr<IDWriteFontFamily> fam; ComPtr<IDWriteLocalizedStrings> names;
	if (FAILED(font->GetFontFamily(fam.GetAddressOf())) || FAILED(fam->GetFamilyNames(names.GetAddressOf()))) return;
	o.family = firstString(names.Get());
	o.weight = font->GetWeight(); o.stretch = font->GetStretch(); o.style = font->GetStyle();
	o.axes = axes(font); o.source = source; o.ok = !o.family.empty();
	// fonts of the family of the same weight, stretch and style (a font installed twice: static and variable)
	o.copies = 0;
	for (UINT32 i = 0; i < fam->GetFontCount(); ++i) {
		ComPtr<IDWriteFont> m;
		if (SUCCEEDED(fam->GetFont(i, m.GetAddressOf())) && m->GetSimulations() == DWRITE_FONT_SIMULATIONS_NONE &&
			m->GetWeight() == font->GetWeight() && m->GetStretch() == font->GetStretch() && m->GetStyle() == font->GetStyle())
			++o.copies;
	}
}
static void findOracle(Oracle &o, const Family &f, bool italic) {
	// 1. the GDI mapping of DirectWrite, at the family's own weight so that nothing is simulated
	ComPtr<IDWriteGdiInterop> interop;
	if (SUCCEEDED(g_dw->GetGdiInterop(interop.GetAddressOf()))) {
		LOGFONTW lf{}; wcsncpy(lf.lfFaceName, f.face.c_str(), LF_FACESIZE - 1);
		lf.lfWeight = f.regular; lf.lfItalic = italic; lf.lfCharSet = DEFAULT_CHARSET;
		ComPtr<IDWriteFont> font;
		if (SUCCEEDED(interop->CreateFontFromLOGFONT(&lf, font.GetAddressOf())) && font->GetSimulations() == DWRITE_FONT_SIMULATIONS_NONE &&
			((font->GetStyle() != DWRITE_FONT_STYLE_NORMAL) == italic)) {
			fillOracle(o, font.Get(), L"GDI mapping");
			if (o.ok) return;
		}
	}
	// 2. else the font whose Win32 family name it is, of the weight GDI gives it
	for (UINT32 i = 0; i < g_coll->GetFontFamilyCount(); ++i) {
		ComPtr<IDWriteFontFamily> fam;
		if (FAILED(g_coll->GetFontFamily(i, fam.GetAddressOf()))) continue;
		for (UINT32 j = 0; j < fam->GetFontCount(); ++j) {
			ComPtr<IDWriteFont> font;
			if (SUCCEEDED(fam->GetFont(j, font.GetAddressOf())) && font->GetSimulations() == DWRITE_FONT_SIMULATIONS_NONE &&
				((font->GetStyle() != DWRITE_FONT_STYLE_NORMAL) == italic) && static_cast<LONG>(font->GetWeight()) == f.regular &&
				hasInfo(font.Get(), DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES, f.face)) {
				fillOracle(o, font.Get(), L"font names");
				if (o.ok) return;
			}
		}
	}
}

// ---- drawing
static HWND g_top, g_sci;
static int g_dpi = 96;
static sptr_t sci(unsigned m, uptr_t w = 0, sptr_t l = 0) { return ::SendMessage(g_sci, m, w, l); }
static void pump(int ms) {
	const DWORD end = ::GetTickCount() + ms;
	MSG msg;
	while (static_cast<int>(::GetTickCount() - end) < 0) {
		while (::PeekMessage(&msg, nullptr, 0, 0, PM_REMOVE)) { ::TranslateMessage(&msg); ::DispatchMessage(&msg); }
		::Sleep(10);
	}
}
static void measure(const unsigned char *p, int w, int h, int stride, Render &r) {
	r.ink = 0; r.hash = 1469598103934665603ULL;
	for (int y = 0; y < h; ++y) for (int x = 0; x < w; ++x) {
		const unsigned char *q = p + y * stride + x * 4;
		r.ink += 255 - (q[0] + q[1] + q[2]) / 3;
		for (int c = 0; c < 3; ++c) { r.hash ^= q[c]; r.hash *= 1099511628211ULL; }
	}
	r.done = true;
}
static Render capture() {
	Render r;
	RECT rc; ::GetClientRect(g_sci, &rc);
	POINT pt{0, 0}; ::ClientToScreen(g_sci, &pt);
	const int w = rc.right, h = rc.bottom;
	HDC screen = ::GetDC(nullptr);
	HDC mem = ::CreateCompatibleDC(screen);
	BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader); bi.bmiHeader.biWidth = w; bi.bmiHeader.biHeight = -h;
	bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
	void *bits = nullptr;
	HBITMAP bmp = ::CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	HGDIOBJ old = ::SelectObject(mem, bmp);
	::BitBlt(mem, 0, 0, w, h, screen, pt.x, pt.y, SRCCOPY);
	::GdiFlush();
	measure(static_cast<const unsigned char *>(bits), w, h, w * 4, r);
	::SelectObject(mem, old); ::DeleteObject(bmp); ::DeleteDC(mem); ::ReleaseDC(nullptr, screen);
	return r;
}
// the text drawn by this build's Scintilla, as Notepad++ draws a style
static Render drawScintilla(int technology, const std::wstring &face, int weight, bool italic, int stretch) {
	sci(SCI_SETTECHNOLOGY, technology);
	const std::string f = utf8(face);
	sci(SCI_STYLESETFONT, STYLE_DEFAULT, reinterpret_cast<sptr_t>(f.c_str()));
	sci(SCI_STYLESETWEIGHT, STYLE_DEFAULT, weight);
	sci(SCI_STYLESETITALIC, STYLE_DEFAULT, italic);
	sci(SCI_STYLESETSTRETCH, STYLE_DEFAULT, stretch);
	sci(SCI_STYLECLEARALL);
	::InvalidateRect(g_sci, nullptr, TRUE); ::UpdateWindow(g_sci); pump(250);
	return capture();
}
static int g_points = 14;
#ifdef APP_MAPPING
#include "FontFamilyNames.h"
#endif
// a font list name drawn as Notepad++ draws a style of it
static Render drawNpp(int technology, const std::wstring &face, bool bold, bool italic) {
#ifdef APP_MAPPING
	const ScintillaFont font = getScintillaFont(face, bold, italic, technology);
	return drawScintilla(technology, font._name, font._weight, font._isItalic, font._stretch);
#else
	return drawScintilla(technology, face, bold ? 700 : 400, italic, SC_STRETCH_NORMAL);
#endif
}
// the text drawn by GDI directly with a weight: GDI's own rendering, and the weight Notepad++ asked before
static Render drawGdi(const std::wstring &face, LONG weight) {
	Render r;
	BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader); bi.bmiHeader.biWidth = clientW; bi.bmiHeader.biHeight = -clientH;
	bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
	void *bits = nullptr;
	HDC mem = ::CreateCompatibleDC(nullptr);
	HBITMAP bmp = ::CreateDIBSection(mem, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	HGDIOBJ old = ::SelectObject(mem, bmp);
	RECT rc{0, 0, clientW, clientH}; ::FillRect(mem, &rc, static_cast<HBRUSH>(::GetStockObject(WHITE_BRUSH)));
	LOGFONTW lf{}; wcsncpy(lf.lfFaceName, face.c_str(), LF_FACESIZE - 1);
	lf.lfHeight = -std::lround(::MulDiv(g_points * 100, g_dpi, 72) / 100.0);	// as Scintilla's SurfaceGDI
	lf.lfWeight = weight; lf.lfCharSet = DEFAULT_CHARSET; lf.lfQuality = ANTIALIASED_QUALITY;
	HFONT font = ::CreateFontIndirectW(&lf);
	HGDIOBJ oldFont = ::SelectObject(mem, font);
	::SetTextColor(mem, RGB(0, 0, 0)); ::SetBkMode(mem, TRANSPARENT);
	int y = 2;
	for (const char *line : g_lines) {
		std::wstring w(line, line + strlen(line));
		::ExtTextOutW(mem, textX, y, 0, nullptr, w.c_str(), static_cast<UINT>(w.size()), nullptr);
		y += lineStep;
	}
	::GdiFlush();
	measure(static_cast<const unsigned char *>(bits), clientW, clientH, clientW * 4, r);
	::SelectObject(mem, oldFont); ::DeleteObject(font);
	::SelectObject(mem, old); ::DeleteObject(bmp); ::DeleteDC(mem);
	return r;
}

// ---- verdicts
static int g_fail = 0, g_warn = 0;
static std::wstring same(const Render &a, const Render &b, double tolerance) {
	if (!a.done || !b.done || !b.ink) return L"n/a";
	if (a.hash == b.hash) return L"same pixels";
	const double ratio = double(a.ink) / double(b.ink);
	wchar_t buf[64]; swprintf(buf, 64, L"ink %+.1f%%", (ratio - 1) * 100);
	return std::wstring(std::fabs(ratio - 1) <= tolerance ? L"~ " : L"DIFFERENT ") + buf;
}
static bool isFail(const std::wstring &s) { return s.rfind(L"DIFFERENT", 0) == 0; }

int wmain(int argc, wchar_t **argv) {
	for (int i = 1; i < argc; ++i) {
		if (iswdigit(argv[i][0])) g_points = std::max(6, _wtoi(argv[i]));
		else g_texts.push_back(argv[i]);
	}
	if (g_texts.empty()) g_texts.push_back(L"MonoLisa");
	for (const auto &t : g_texts) g_text += (g_text.empty() ? L"" : L"\" \"") + t;
	using SetCtx = BOOL(WINAPI *)(HANDLE);
	if (auto set = reinterpret_cast<SetCtx>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetProcessDpiAwarenessContext"))))
		set(reinterpret_cast<HANDLE>(-4));	// per monitor v2: captures are 1:1
	else
		SetProcessDPIAware();
	wchar_t path[MAX_PATH]; GetModuleFileNameW(nullptr, path, MAX_PATH);
	std::wstring outPath(path); outPath = outPath.substr(0, outPath.find_last_of(L"\\/") + 1) + L"fontcheck.txt";
	g_out = _wfopen(outPath.c_str(), L"w, ccs=UTF-8");
	OSVERSIONINFOW ov{ sizeof(ov) };
	using RtlGetVersionSig = LONG(WINAPI *)(OSVERSIONINFOW *);
	if (auto rtl = reinterpret_cast<RtlGetVersionSig>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion")))) rtl(&ov);

	HINSTANCE hInst = ::GetModuleHandle(nullptr);
	Scintilla_RegisterClasses(hInst);
	g_top = ::CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, L"STATIC", L"fontcheck", WS_POPUP | WS_BORDER | WS_VISIBLE,
		40, 40, clientW + 2, clientH + 2, nullptr, nullptr, hInst, nullptr);
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE, 0, 0, clientW, clientH, g_top, nullptr, hInst, nullptr);
	using GetDpiForWindowSig = UINT(WINAPI *)(HWND);
	if (auto gd = reinterpret_cast<GetDpiForWindowSig>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"))))
		g_dpi = static_cast<int>(gd(g_sci));
	clientW = ::MulDiv(clientW, g_dpi, 96); clientH = ::MulDiv(clientH, g_dpi, 96); lineStep = ::MulDiv(lineStep, g_dpi, 96);
	::SetWindowPos(g_top, nullptr, 0, 0, clientW + 2, clientH + 2, SWP_NOMOVE | SWP_NOZORDER);
	::SetWindowPos(g_sci, nullptr, 0, 0, clientW, clientH, SWP_NOMOVE | SWP_NOZORDER);
	BOOL clearType = FALSE; UINT smoothing = 0;
	SystemParametersInfoW(SPI_GETFONTSMOOTHING, 0, &clearType, 0); SystemParametersInfoW(SPI_GETFONTSMOOTHINGTYPE, 0, &smoothing, 0);
	out(L"fontcheck \"%ls\" %dpt - Windows %lu.%lu.%lu - %d DPI - font smoothing %ls\n", g_text.c_str(), g_points,
		ov.dwMajorVersion, ov.dwMinorVersion, ov.dwBuildNumber, g_dpi, !clearType ? L"off" : smoothing == 2 ? L"ClearType" : L"standard");
	out(L"Reference: the font Windows maps each font list name to at its own weight (no simulated bold).\n\n");

	sci(SCI_SETMARGINWIDTHN, 0, 0); sci(SCI_SETMARGINWIDTHN, 1, 0); sci(SCI_SETMARGINWIDTHN, 2, 0);
	sci(SCI_SETCARETSTYLE, CARETSTYLE_INVISIBLE);
	sci(SCI_SETHSCROLLBAR, 0); sci(SCI_SETVSCROLLBAR, 0);
	sci(SCI_SETMARGINLEFT, 0, textX);
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_ANTIALIASED);
	sci(SCI_STYLESETSIZE, STYLE_DEFAULT, g_points);
	sci(SCI_SETEXTRAASCENT, 0);
	std::string text;
	for (const char *line : g_lines) { text += line; text += "\n"; }
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>(text.c_str()));

	HDC hdc = ::GetDC(nullptr);
	LOGFONTW lf{}; lf.lfCharSet = DEFAULT_CHARSET;
	::EnumFontFamiliesExW(hdc, &lf, enumFaces, 0, 0);
	std::vector<Family> fams;
	for (const auto &face : g_faces) {
		Family f; f.face = face;
		LOGFONTW m{}; m.lfCharSet = DEFAULT_CHARSET; wcsncpy(m.lfFaceName, face.c_str(), LF_FACESIZE - 1);
		::EnumFontFamiliesExW(hdc, &m, enumMembers, reinterpret_cast<LPARAM>(&f), 0);
		if (f.regular) fams.push_back(f);
	}
	::ReleaseDC(nullptr, hdc);
	if (fams.empty()) { out(L"No font list name contains \"%ls\".\n", g_text.c_str()); return 1; }

	::DWriteCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown **>(g_dw.GetAddressOf()));
	g_dw->GetSystemFontCollection(g_coll.GetAddressOf(), FALSE);
	for (auto &f : fams) {
		UINT32 index = 0; BOOL exists = FALSE;
		if (SUCCEEDED(g_coll->FindFamilyName(f.face.c_str(), &index, &exists)) && exists) {
			f.dwFamily = true;
			ComPtr<IDWriteFontFamily> fam; ComPtr<IDWriteFont> font;
			if (SUCCEEDED(g_coll->GetFontFamily(index, fam.GetAddressOf())) &&
				SUCCEEDED(fam->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL, DWRITE_FONT_STYLE_NORMAL, font.GetAddressOf())))
				f.dwFamilySimulation = font->GetSimulations();
		}
		findOracle(f.oracle, f, false);
		if (f.hasItalic) findOracle(f.oracleItalic, f, true);
	}
	std::sort(fams.begin(), fams.end(), [](const Family &a, const Family &b) {
		return a.oracle.family != b.oracle.family ? a.oracle.family < b.oracle.family : a.oracle.stretch != b.oracle.stretch ? a.oracle.stretch < b.oracle.stretch :
			a.regular != b.regular ? a.regular < b.regular : a.face < b.face;
	});

	// draw: DirectWrite, then GDI
	for (auto &f : fams) {
		f.dwNormal = drawNpp(SC_TECHNOLOGY_DIRECTWRITE, f.face, false, false);
		f.dwBold = drawNpp(SC_TECHNOLOGY_DIRECTWRITE, f.face, true, false);
		if (f.oracle.ok) f.dwRef = drawScintilla(SC_TECHNOLOGY_DIRECTWRITE, f.oracle.family, f.oracle.weight, false, f.oracle.stretch);
		if (f.hasItalic) {
			f.dwItalic = drawNpp(SC_TECHNOLOGY_DIRECTWRITE, f.face, false, true);
			if (f.oracleItalic.ok) f.dwRefItalic = drawScintilla(SC_TECHNOLOGY_DIRECTWRITE, f.oracleItalic.family, f.oracleItalic.weight, true, f.oracleItalic.stretch);
		}
	}
	for (auto &f : fams) {
		f.gdiNormal = drawNpp(SC_TECHNOLOGY_DEFAULT, f.face, false, false);
		f.gdiBold = drawNpp(SC_TECHNOLOGY_DEFAULT, f.face, true, false);
		f.gdiRef = drawGdi(f.face, f.regular);
		f.gdiAt400 = drawGdi(f.face, 400);
	}
	::DestroyWindow(g_top);

	// report
	for (const auto &f : fams) {
		out(L"%ls  (GDI weight %ld%ls)\n", f.face.c_str(), f.regular, f.hasItalic ? L", has italic" : L"");
		if (f.oracle.ok)
			out(L"  reference: DirectWrite family \"%ls\" weight %d stretch %d, %ls (by %ls)%ls\n", f.oracle.family.c_str(), f.oracle.weight,
				f.oracle.stretch, f.oracle.axes.c_str(), f.oracle.source.c_str(),
				f.oracle.copies > 1 ? L" - INSTALLED MORE THAN ONCE (e.g. static and variable)" : L"");
		else
			out(L"  reference: none found\n");
		if (f.dwFamily)
			out(L"  also a DirectWrite family name%ls\n", f.dwFamilySimulation ? L" that DirectWrite fake-bolds at regular weight (handled)" : L"");
		const std::wstring dwOwn = same(f.dwNormal, f.dwRef, 0.003);
		const bool heaviest = f.regular >= 900 || (f.oracle.ok && f.oracle.weight >= 900);	// no heavier font for bold
		const bool dwBoldOk = heaviest || f.dwBold.ink > f.dwNormal.ink * 1.02;
		out(L"  DirectWrite: regular vs reference: %ls | bold heavier: %ls (ink %lld -> %lld)", dwOwn.c_str(),
			f.dwBold.ink > f.dwNormal.ink * 1.02 ? L"yes" : heaviest ? L"no, heaviest weight" : L"NO", f.dwNormal.ink, f.dwBold.ink);
		if (f.hasItalic) {
			const std::wstring it = same(f.dwItalic, f.dwRefItalic, 0.003);
			out(L" | italic vs reference italic: %ls", it.c_str());
			if (isFail(it)) ++g_fail;
		}
		out(L"\n");
		const std::wstring gdiOwn = same(f.gdiNormal, f.gdiRef, 0.01);
		const bool gdiBoldOk = heaviest || f.gdiBold.ink > f.gdiNormal.ink * 1.02;
		const double at400 = f.gdiRef.ink ? double(f.gdiAt400.ink) / double(f.gdiRef.ink) : 1.0;
		out(L"  GDI:         regular vs GDI at weight %ld: %ls | bold heavier: %ls | GDI asked weight 400 (original build): %ls\n",
			f.regular, gdiOwn.c_str(), f.gdiBold.ink > f.gdiNormal.ink * 1.02 ? L"yes" : heaviest ? L"no, heaviest weight" : L"NO",
			f.regular == 400 ? L"same request" : at400 > 1.03 ? L"FAKE BOLD" : L"ok");
		if (isFail(dwOwn) || isFail(gdiOwn)) ++g_fail;
		if (!dwBoldOk || !gdiBoldOk) ++g_warn;
	}

	// weights of a family: each draws differently and heavier than the lighter ones
	out(L"\nWeights by family (DirectWrite ink, lightest first):\n");
	for (size_t i = 0; i < fams.size();) {
		size_t j = i;
		while (j < fams.size() && fams[j].oracle.family == fams[i].oracle.family && fams[j].oracle.stretch == fams[i].oracle.stretch) ++j;
		out(L"  %ls", fams[i].oracle.ok ? fams[i].oracle.family.c_str() : L"(no reference)");
		if (fams[i].oracle.stretch != DWRITE_FONT_STRETCH_NORMAL) out(L" (stretch %d)", fams[i].oracle.stretch);
		out(L":");
		for (size_t k = i; k < j; ++k) out(L" %ls=%lld", fams[k].face.c_str(), fams[k].dwNormal.ink);
		out(L"\n");
		for (size_t k = i + 1; k < j; ++k) {
			const Family &a = fams[k - 1], &b = fams[k];
			if (a.dwNormal.hash == b.dwNormal.hash) {
				out(L"    SAME DRAWING: \"%ls\" and \"%ls\"\n", a.face.c_str(), b.face.c_str()); ++g_fail;
			} else if (a.regular < b.regular && b.dwNormal.ink <= a.dwNormal.ink) {
				out(L"    not heavier: \"%ls\" (weight %ld) vs \"%ls\" (weight %ld)\n", b.face.c_str(), b.regular, a.face.c_str(), a.regular); ++g_warn;
			}
		}
		i = j;
	}
	// GDI draws bold with the font DirectWrite draws it with: when DirectWrite's bold of a name is the regular
	// of another name (ExtraLight bold = Medium), GDI's bold of the name is GDI's regular of the other name
	bool header = false;
	for (const auto &f : fams) {
		for (const auto &g : fams) {
			if (&f == &g || !f.oracle.ok || !g.oracle.ok || f.oracle.family != g.oracle.family || f.oracle.stretch != g.oracle.stretch ||
				g.dwNormal.hash != f.dwBold.hash || !g.gdiNormal.ink) continue;
			const double ratio = double(f.gdiBold.ink) / double(g.gdiNormal.ink);
			const bool ok = std::fabs(ratio - 1) <= 0.01;
			if (!header) { out(L"\nBold drawn with the font of another name (DirectWrite; GDI must match):\n"); header = true; }
			out(L"  %ls bold = %ls: GDI %ls\n", f.face.c_str(), g.face.c_str(), ok ? L"same font" : L"DIFFERENT");
			if (!ok) ++g_fail;
			break;
		}
	}
	out(L"\n%zu font list names checked: %ls (%d failure(s), %d warning(s))\n", fams.size(),
		g_fail ? L"FAIL" : g_warn ? L"PASS with warnings" : L"PASS", g_fail, g_warn);
	if (g_out) fclose(g_out);
	return g_fail ? 2 : 0;
}
