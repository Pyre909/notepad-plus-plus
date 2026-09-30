// scitest.cpp - runtime smoke test of Notepad++'s vendored Scintilla (Win32), for Wine or Windows.
//
// Links the static libscintilla.a of a Notepad++ gcc build and exercises the private
// SCI_SETFONTRENDERINGPARAMETER / SCI_GETFONTRENDERINGPARAMETER API, DirectWrite technology,
// measuring (integral vs fractional advances), painting (screen capture, non-blank check),
// technology switches, WM_SETTINGCHANGE, autocompletion list and call tip.
//
// Output: one line per check on stdout (and <out>/results.tsv):
//   RESULT <tab> group <tab> name <tab> PASS|FAIL|SKIP|INFO|WARN|CRASH <tab> detail
// then  SUMMARY <tab> pass=N fail=N skip=N info=N warn=N crash=N
// Exit code: 0 no crash-level failure (FAILs may exist unless --strict), 1 FAILs with --strict,
//            2 crash-level failure caught (C++ exception, window destroyed), 3 unhandled SEH exception.
//
// Usage: scitest.exe [--out DIR] [--groups g1,g2,...] [--font NAME] [--size HUNDREDTHS_OF_PT] [--strict]
//   groups: env techs api matrix sens switch settingchange popups idle   (default: all, in that order)

#ifndef UNICODE
#define UNICODE
#endif
#ifndef _UNICODE
#define _UNICODE
#endif
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dwrite.h>
#include <cstdio>
#include <cstdarg>
#include <cstdint>
#include <cstring>
#include <cmath>
#include <string>
#include <vector>
#include <map>
#include <unordered_map>
#include <set>
#include <algorithm>
#include <stdexcept>

#include "Scintilla.h"

// Build against a header without the private API too (baseline): the values are the contract ones.
#ifndef SCI_SETFONTRENDERINGPARAMETER
#define SCITEST_HEADER_HAS_API 0
#define SCI_SETFONTRENDERINGPARAMETER 5001
#define SCI_GETFONTRENDERINGPARAMETER 5002
#define SC_FONTRENDERING_DEFAULT -1
#define SC_FONTRENDERING_GAMMA 0
#define SC_FONTRENDERING_ENHANCEDCONTRAST 1
#define SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST 2
#define SC_FONTRENDERING_CLEARTYPELEVEL 3
#define SC_FONTRENDERING_PIXELGEOMETRY 4
#define SC_FONTRENDERING_RENDERINGMODE 5
#define SC_PIXELGEOMETRY_FLAT 0
#define SC_PIXELGEOMETRY_RGB 1
#define SC_PIXELGEOMETRY_BGR 2
#define SC_RENDERINGMODE_DEFAULT 0
#define SC_RENDERINGMODE_GDICLASSIC 2
#define SC_RENDERINGMODE_GDINATURAL 3
#define SC_RENDERINGMODE_NATURAL 4
#define SC_RENDERINGMODE_NATURALSYMMETRIC 5
#else
#define SCITEST_HEADER_HAS_API 1
#endif
#ifndef SC_FONTRENDERING_LIGHTTEXTGAMMA
#define SC_FONTRENDERING_LIGHTTEXTGAMMA 6
#endif
#ifndef SC_RENDERINGMODE_ADAPTIVE
#define SC_RENDERINGMODE_ADAPTIVE 100
#endif

#ifndef PW_CLIENTONLY
#define PW_CLIENTONLY 1
#endif
#ifndef CAPTUREBLT
#define CAPTUREBLT 0x40000000
#endif

namespace {

// ---------------------------------------------------------------------------------------------
// Reporting

enum class St { PASS, FAIL, SKIP, INFO, WARN, CRASH };
const char *StName(St s) {
	switch (s) {
	case St::PASS: return "PASS";
	case St::FAIL: return "FAIL";
	case St::SKIP: return "SKIP";
	case St::INFO: return "INFO";
	case St::WARN: return "WARN";
	case St::CRASH: return "CRASH";
	}
	return "?";
}

FILE *g_tsv = nullptr;
std::string g_outDir = ".";
std::string g_group = "init";
std::string g_test = "init";
int g_count[6] = {};
bool g_strict = false;
long g_firstChance = 0;

void report(St st, const char *name, const char *fmt, ...) {
	char buf[8192];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	for (char *p = buf; *p; ++p) {
		if (*p == '\t' || *p == '\n' || *p == '\r')
			*p = ' ';
	}
	printf("RESULT\t%s\t%s\t%s\t%s\n", g_group.c_str(), name, StName(st), buf);
	fflush(stdout);
	if (g_tsv) {
		fprintf(g_tsv, "%s\t%s\t%s\t%s\n", g_group.c_str(), name, StName(st), buf);
		fflush(g_tsv);
	}
	g_count[static_cast<int>(st)]++;
}

void check(bool ok, const char *name, const char *fmt, ...) {
	char buf[8192];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	report(ok ? St::PASS : St::FAIL, name, "%s", buf);
}

void printSummary() {
	printf("SUMMARY\tpass=%d\tfail=%d\tskip=%d\tinfo=%d\twarn=%d\tcrash=%d\tfirstchance_exceptions=%ld\n",
		g_count[0], g_count[1], g_count[2], g_count[3], g_count[4], g_count[5], g_firstChance);
	fflush(stdout);
	if (g_tsv) {
		fprintf(g_tsv, "SUMMARY\tpass=%d\tfail=%d\tskip=%d\tinfo=%d\twarn=%d\tcrash=%d\n",
			g_count[0], g_count[1], g_count[2], g_count[3], g_count[4], g_count[5]);
		fflush(g_tsv);
	}
}

LONG WINAPI CrashFilter(EXCEPTION_POINTERS *ep) {
	report(St::CRASH, g_test.c_str(), "unhandled SEH exception code=0x%08lx addr=%p",
		static_cast<unsigned long>(ep->ExceptionRecord->ExceptionCode), ep->ExceptionRecord->ExceptionAddress);
	printSummary();
	ExitProcess(3);
	return EXCEPTION_EXECUTE_HANDLER;
}

LONG WINAPI FirstChanceLogger(EXCEPTION_POINTERS *ep) {
	const DWORD code = ep->ExceptionRecord->ExceptionCode;
	if (code == EXCEPTION_ACCESS_VIOLATION || code == EXCEPTION_STACK_OVERFLOW || code == EXCEPTION_ILLEGAL_INSTRUCTION ||
		code == EXCEPTION_INT_DIVIDE_BY_ZERO || code == EXCEPTION_PRIV_INSTRUCTION || code == 0xC0000409 /*STACK_BUFFER_OVERRUN*/) {
		g_firstChance++;
		fprintf(stderr, "first-chance exception 0x%08lx at %p during %s/%s\n", static_cast<unsigned long>(code),
			ep->ExceptionRecord->ExceptionAddress, g_group.c_str(), g_test.c_str());
	}
	return EXCEPTION_CONTINUE_SEARCH;
}

// ---------------------------------------------------------------------------------------------
// Window + Scintilla

HINSTANCE g_hInst = nullptr;
HWND g_frame = nullptr;
HWND g_sci = nullptr;
std::string g_font;
int g_sizeHundredths = 0;	// 0: chosen automatically so the natural advance is clearly fractional
double g_expectedNaturalAdvance = 0.0;
constexpr int frameX = 30, frameY = 30, clientW = 960, clientH = 360;

sptr_t sci(unsigned int msg, uptr_t w = 0, sptr_t l = 0) {
	return ::SendMessageW(g_sci, msg, w, l);
}

// Messages dispatched by pump(), per window class, WM_PAINT only (to detect repaint storms)
std::map<std::wstring, long> g_paintCounts;

// Bounded message pump: never loops forever even when a window keeps generating WM_PAINT
// (seen under Wine for the Direct2D call tip).
void pump(DWORD ms) {
	const DWORD end = ::GetTickCount() + ms;
	do {
		MSG m;
		int n = 0;
		while (n < 500 && ::PeekMessageW(&m, nullptr, 0, 0, PM_REMOVE)) {
			if (m.message == WM_PAINT && m.hwnd) {
				wchar_t cls[64] = {};
				::GetClassNameW(m.hwnd, cls, 63);
				g_paintCounts[cls]++;
			}
			::TranslateMessage(&m);
			::DispatchMessageW(&m);
			++n;
			if (static_cast<LONG>(::GetTickCount() - end) >= 0)
				break;
		}
		::Sleep(5);
	} while (static_cast<LONG>(::GetTickCount() - end) < 0);
}

// WM_PAINT count per window class during an idle period of ms milliseconds (0 expected once painted)
std::string paintStorm(DWORD ms, long &total) {
	g_paintCounts.clear();
	pump(ms);
	std::string s;
	total = 0;
	for (const auto &kv : g_paintCounts) {
		std::string cls(kv.first.begin(), kv.first.end());
		s += cls + "=" + std::to_string(kv.second) + " ";
		total += kv.second;
	}
	return s.empty() ? std::string("none") : s;
}

void repaint(HWND h = nullptr) {
	if (!h)
		h = g_frame;
	::RedrawWindow(h, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW | RDW_ALLCHILDREN | RDW_FRAME);
	::UpdateWindow(h);
	::GdiFlush();
	pump(120);
	::RedrawWindow(h, nullptr, nullptr, RDW_UPDATENOW | RDW_ALLCHILDREN);
	::GdiFlush();
	pump(60);
}

long g_updateUI = 0;	// SCN_UPDATEUI notifications received (delivered through SC_WORK_IDLE)

LRESULT CALLBACK FrameProc(HWND h, UINT m, WPARAM w, LPARAM l) {
	switch (m) {
	case WM_NOTIFY:
		if (l && reinterpret_cast<const NMHDR *>(l)->code == SCN_UPDATEUI)
			g_updateUI++;
		return 0;
	case WM_SIZE:
		if (g_sci)
			::MoveWindow(g_sci, 0, 0, LOWORD(l), HIWORD(l), TRUE);
		return 0;
	case WM_ERASEBKGND:
		return 1;
	default:
		break;
	}
	return ::DefWindowProcW(h, m, w, l);
}

const char *kLine0Unit = "The quick brown fox jumps over the lazy dog 0123456789 ";

std::string buildText() {
	std::string line0;
	while (line0.size() < 260)
		line0 += kLine0Unit;
	std::string t = line0 + "\n";
	t += "int main(int argc, char **argv) { return printf(\"%d\\n\", argc); } // code line\n";
	t += "iiiiiiiiii WWWWWWWWWW mmmmmmmmmm 0O0O0O0O lIlIlI1|1| {}[]()<> ~!@#$%^&*_+=\n";
	t += "Latin-1: caf\xC3\xA9 na\xC3\xAFve \xC3\xBC\xC3\xB6\xC3\xA4 \xC3\x9F  Greek: \xCE\xB1\xCE\xB2\xCE\xB3  Cyrillic: \xD0\xB6\xD1\x83\xD0\xBA\n";
	t += "\tTabbed line\twith\ttabs\n";
	t += "alp";	// autocompletion anchor at end of document
	return t;
}

void setupContent() {
	sci(SCI_SETCODEPAGE, SC_CP_UTF8);
	sci(SCI_STYLERESETDEFAULT);
	sci(SCI_STYLESETFONT, STYLE_DEFAULT, reinterpret_cast<sptr_t>(g_font.c_str()));
	sci(SCI_STYLESETSIZEFRACTIONAL, STYLE_DEFAULT, g_sizeHundredths);
	sci(SCI_STYLESETFORE, STYLE_DEFAULT, 0x000000);
	sci(SCI_STYLESETBACK, STYLE_DEFAULT, 0xFFFFFF);
	sci(SCI_STYLECLEARALL);
	for (int i = 0; i < 5; ++i)
		sci(SCI_SETMARGINWIDTHN, i, 0);
	sci(SCI_SETCARETSTYLE, CARETSTYLE_INVISIBLE);
	sci(SCI_SETCARETPERIOD, 0);
	sci(SCI_SETHSCROLLBAR, 0);
	sci(SCI_SETVSCROLLBAR, 0);
	sci(SCI_SETLAYOUTCACHE, SC_CACHE_PAGE);
	const std::string t = buildText();
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>(t.c_str()));
	sci(SCI_EMPTYUNDOBUFFER);
	sci(SCI_SETXOFFSET, 0);
	sci(SCI_SETFIRSTVISIBLELINE, 0);
	sci(SCI_SETEMPTYSELECTION, 0);
}

bool createWindows() {
	WNDCLASSW wc{};
	wc.lpfnWndProc = FrameProc;
	wc.hInstance = g_hInst;
	wc.hCursor = ::LoadCursor(nullptr, IDC_ARROW);
	wc.lpszClassName = L"SciTestFrame";
	wc.hbrBackground = static_cast<HBRUSH>(::GetStockObject(WHITE_BRUSH));
	static bool registered = false;
	if (!registered) {
		::RegisterClassW(&wc);
		registered = true;
	}
	RECT rc{0, 0, clientW, clientH};
	const DWORD style = WS_POPUP | WS_BORDER | WS_VISIBLE | WS_CLIPCHILDREN;
	::AdjustWindowRectEx(&rc, style, FALSE, WS_EX_TOPMOST);
	g_frame = ::CreateWindowExW(WS_EX_TOPMOST, L"SciTestFrame", L"scitest", style, frameX, frameY,
		rc.right - rc.left, rc.bottom - rc.top, nullptr, nullptr, g_hInst, nullptr);
	if (!g_frame)
		return false;
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE | WS_TABSTOP, 0, 0, clientW, clientH,
		g_frame, reinterpret_cast<HMENU>(static_cast<INT_PTR>(1)), g_hInst, nullptr);
	if (!g_sci)
		return false;
	::ShowWindow(g_frame, SW_SHOW);
	::SetForegroundWindow(g_frame);
	::SetFocus(g_sci);
	setupContent();
	repaint();
	return true;
}

void destroyWindows() {
	if (g_frame)
		::DestroyWindow(g_frame);
	g_frame = nullptr;
	g_sci = nullptr;
	pump(50);
}

// ---------------------------------------------------------------------------------------------
// Capture

struct Img {
	int w = 0, h = 0;
	std::vector<uint32_t> px;	// 0x00RRGGBB, top-down
};

struct Stats {
	uint32_t bg = 0;
	long nonbg = 0;
	long distinct = 0;
	long gray = 0;	// achromatic antialiasing levels (neither background nor near black)
	long chroma = 0;	// coloured pixels (ClearType fringes)
	uint64_t hash = 0;
};

bool grabDC(HDC src, int sx, int sy, int w, int h, Img &img, bool print = false, HWND hwndPrint = nullptr) {
	if (w <= 0 || h <= 0)
		return false;
	HDC screen = ::GetDC(nullptr);
	HDC mem = ::CreateCompatibleDC(screen);
	BITMAPINFO bi{};
	bi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
	bi.bmiHeader.biWidth = w;
	bi.bmiHeader.biHeight = -h;
	bi.bmiHeader.biPlanes = 1;
	bi.bmiHeader.biBitCount = 32;
	bi.bmiHeader.biCompression = BI_RGB;
	void *bits = nullptr;
	HBITMAP bmp = ::CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	bool ok = false;
	if (bmp && bits) {
		HGDIOBJ old = ::SelectObject(mem, bmp);
		// Pre-fill with a sentinel colour so "nothing copied" is visible
		RECT r{0, 0, w, h};
		HBRUSH br = ::CreateSolidBrush(RGB(255, 0, 255));
		::FillRect(mem, &r, br);
		::DeleteObject(br);
		if (print)
			ok = ::PrintWindow(hwndPrint, mem, PW_CLIENTONLY) != FALSE;
		else
			ok = ::BitBlt(mem, 0, 0, w, h, src, sx, sy, SRCCOPY | CAPTUREBLT) != FALSE;
		::GdiFlush();
		img.w = w;
		img.h = h;
		img.px.assign(static_cast<const uint32_t *>(bits), static_cast<const uint32_t *>(bits) + static_cast<size_t>(w) * h);
		for (auto &p : img.px)
			p &= 0xFFFFFF;
		::SelectObject(mem, old);
		::DeleteObject(bmp);
	}
	::DeleteDC(mem);
	::ReleaseDC(nullptr, screen);
	return ok;
}

bool grabScreenOnce(HWND hwnd, Img &img, bool wholeWindow) {
	RECT rc{};
	if (wholeWindow) {
		::GetWindowRect(hwnd, &rc);
	} else {
		::GetClientRect(hwnd, &rc);
		::MapWindowPoints(hwnd, nullptr, reinterpret_cast<POINT *>(&rc), 2);
	}
	HDC screen = ::GetDC(nullptr);
	const bool ok = grabDC(screen, rc.left, rc.top, rc.right - rc.left, rc.bottom - rc.top, img);
	::ReleaseDC(nullptr, screen);
	return ok;
}

int g_lastGrabTries = 0;
bool g_lastGrabStable = true;

// Screen pixels of the client area of hwnd (what is really on the X server / desktop).
// Direct2D/Direct3D presents (GL under Wine) can land on screen a little after WM_PAINT returns,
// so the capture is repeated until two consecutive grabs are identical (max ~3 s).
bool grabScreen(HWND hwnd, Img &img, bool wholeWindow = false) {
	bool ok = grabScreenOnce(hwnd, img, wholeWindow);
	g_lastGrabTries = 1;
	g_lastGrabStable = false;
	for (int i = 0; i < 30 && ok; ++i) {
		pump(100);
		Img again;
		ok = grabScreenOnce(hwnd, again, wholeWindow);
		g_lastGrabTries++;
		const bool same = again.px == img.px;
		img = std::move(again);
		if (same) {
			g_lastGrabStable = true;
			break;
		}
	}
	return ok;
}

bool grabWindowDC(HWND hwnd, Img &img) {
	RECT rc{};
	::GetClientRect(hwnd, &rc);
	HDC dc = ::GetDC(hwnd);
	const bool ok = grabDC(dc, 0, 0, rc.right, rc.bottom, img);
	::ReleaseDC(hwnd, dc);
	return ok;
}

bool grabPrintWindow(HWND hwnd, Img &img) {
	RECT rc{};
	::GetClientRect(hwnd, &rc);
	return grabDC(nullptr, 0, 0, rc.right, rc.bottom, img, true, hwnd);
}

Stats stats(const Img &img) {
	Stats s;
	std::unordered_map<uint32_t, long> counts;
	uint64_t h = 1469598103934665603ULL;
	for (uint32_t p : img.px) {
		counts[p]++;
		for (int i = 0; i < 3; ++i) {
			h ^= (p >> (i * 8)) & 0xFF;
			h *= 1099511628211ULL;
		}
	}
	s.hash = h;
	s.distinct = static_cast<long>(counts.size());
	long best = -1;
	for (const auto &kv : counts) {
		if (kv.second > best) {
			best = kv.second;
			s.bg = kv.first;
		}
	}
	for (uint32_t p : img.px) {
		if (p == s.bg)
			continue;
		s.nonbg++;
		const int r = (p >> 16) & 0xFF, g = (p >> 8) & 0xFF, b = p & 0xFF;
		const int mx = std::max({r, g, b}), mn = std::min({r, g, b});
		if (mx - mn > 32)
			s.chroma++;
		else if (mx > 40 && mn < 215)
			s.gray++;
	}
	return s;
}

std::string statsStr(const Stats &s, const Img &img) {
	char buf[256];
	snprintf(buf, sizeof(buf), "size=%dx%d bg=#%06x nonbg=%ld distinct=%ld aa_gray=%ld chroma=%ld hash=%016llx",
		img.w, img.h, s.bg, s.nonbg, s.distinct, s.gray, s.chroma, static_cast<unsigned long long>(s.hash));
	return buf;
}

bool writeBMP(const std::string &name, const Img &img) {
	const std::string path = g_outDir + "/" + name;
	FILE *f = fopen(path.c_str(), "wb");
	if (!f)
		return false;
	const int rowBytes = ((img.w * 3 + 3) / 4) * 4;
	const uint32_t dataSize = static_cast<uint32_t>(rowBytes) * img.h;
	BITMAPFILEHEADER fh{};
	fh.bfType = 0x4D42;
	fh.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
	fh.bfSize = fh.bfOffBits + dataSize;
	BITMAPINFOHEADER ih{};
	ih.biSize = sizeof(ih);
	ih.biWidth = img.w;
	ih.biHeight = img.h;	// bottom-up
	ih.biPlanes = 1;
	ih.biBitCount = 24;
	ih.biCompression = BI_RGB;
	ih.biSizeImage = dataSize;
	fwrite(&fh, sizeof(fh), 1, f);
	fwrite(&ih, sizeof(ih), 1, f);
	std::vector<unsigned char> row(rowBytes, 0);
	for (int y = img.h - 1; y >= 0; --y) {
		for (int x = 0; x < img.w; ++x) {
			const uint32_t p = img.px[static_cast<size_t>(y) * img.w + x];
			row[x * 3 + 0] = p & 0xFF;
			row[x * 3 + 1] = (p >> 8) & 0xFF;
			row[x * 3 + 2] = (p >> 16) & 0xFF;
		}
		fwrite(row.data(), 1, row.size(), f);
	}
	fclose(f);
	return true;
}

constexpr long minNonBlank = 300;	// text pixels expected in the capture of the Scintilla window

// Capture Scintilla's client area from the screen; report a non-blank check; save <file>.bmp.
Stats captureCheck(const char *name, const std::string &file, HWND hwnd = nullptr, long minPixels = minNonBlank) {
	if (!hwnd)
		hwnd = g_sci;
	Img img;
	const bool ok = grabScreen(hwnd, img);
	Stats s = stats(img);
	if (!file.empty())
		writeBMP(file + ".bmp", img);
	const bool sentinel = s.bg == 0xFF00FF;
	check(ok && !sentinel && s.nonbg >= minPixels, name, "capture %s %s grabs=%d%s file=%s.bmp", ok ? "ok" : "BitBlt-failed",
		statsStr(s, img).c_str(), g_lastGrabTries, g_lastGrabStable ? "" : "(unstable)", file.c_str());
	return s;
}

// ---------------------------------------------------------------------------------------------
// Measuring

struct Meas {
	std::vector<int> x;
	double avg = 0.0;
	int dmin = 0, dmax = 0;
	bool uniform = false;
};

Meas measure(int line = 0, int n = 200) {
	Meas m;
	const sptr_t start = sci(SCI_POSITIONFROMLINE, line);
	for (int i = 0; i <= n; ++i)
		m.x.push_back(static_cast<int>(sci(SCI_POINTXFROMPOSITION, 0, start + i)));
	m.dmin = 1 << 30;
	m.dmax = -(1 << 30);
	for (int i = 0; i < n; ++i) {
		const int d = m.x[i + 1] - m.x[i];
		m.dmin = std::min(m.dmin, d);
		m.dmax = std::max(m.dmax, d);
	}
	m.uniform = m.dmin == m.dmax;
	m.avg = static_cast<double>(m.x[n] - m.x[0]) / n;
	return m;
}

std::string measStr(const Meas &m) {
	std::string s = "x[0..20]=";
	for (int i = 0; i <= 20 && i < static_cast<int>(m.x.size()); ++i) {
		if (i)
			s += ",";
		s += std::to_string(m.x[i]);
	}
	char buf[160];
	snprintf(buf, sizeof(buf), " adv_avg200=%.4f dmin=%d dmax=%d advances=%s", m.avg, m.dmin, m.dmax,
		m.uniform ? "integral" : "fractional");
	return s + buf;
}

// ---------------------------------------------------------------------------------------------
// DirectWrite helpers (environment report + font / size choice)

typedef HRESULT(WINAPI *DWriteCreateFactorySig)(DWRITE_FACTORY_TYPE, REFIID, IUnknown **);

IDWriteFactory *DWriteFactory() {
	static IDWriteFactory *factory = nullptr;
	static bool tried = false;
	if (!tried) {
		tried = true;
		HMODULE h = ::LoadLibraryW(L"dwrite.dll");
		if (h) {
			auto fn = reinterpret_cast<DWriteCreateFactorySig>(reinterpret_cast<void *>(::GetProcAddress(h, "DWriteCreateFactory")));
			if (fn) {
				IUnknown *u = nullptr;
				if (SUCCEEDED(fn(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), &u)) && u)
					factory = static_cast<IDWriteFactory *>(u);
			}
		}
	}
	return factory;
}

std::wstring Widen(const std::string &s) {
	if (s.empty())
		return {};
	const int n = ::MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, nullptr, 0);
	std::wstring w(n, L'\0');
	::MultiByteToWideChar(CP_UTF8, 0, s.c_str(), -1, w.data(), n);
	w.resize(n - 1);
	return w;
}

std::string Narrow(const std::wstring &w) {
	if (w.empty())
		return {};
	const int n = ::WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
	std::string s(n, '\0');
	::WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, s.data(), n, nullptr, nullptr);
	s.resize(n - 1);
	return s;
}

bool DWriteHasFamily(const std::string &name) {
	IDWriteFactory *f = DWriteFactory();
	if (!f)
		return false;
	IDWriteFontCollection *coll = nullptr;
	if (FAILED(f->GetSystemFontCollection(&coll, FALSE)) || !coll)
		return false;
	UINT32 index = 0;
	BOOL exists = FALSE;
	coll->FindFamilyName(Widen(name).c_str(), &index, &exists);
	coll->Release();
	return exists != FALSE;
}

// Natural advance of '0' as a fraction of the em, from the DirectWrite font (0 if unknown).
double DWriteAdvanceRatio(const std::string &name) {
	IDWriteFactory *f = DWriteFactory();
	if (!f)
		return 0;
	double ratio = 0;
	IDWriteFontCollection *coll = nullptr;
	if (FAILED(f->GetSystemFontCollection(&coll, FALSE)) || !coll)
		return 0;
	UINT32 index = 0;
	BOOL exists = FALSE;
	coll->FindFamilyName(Widen(name).c_str(), &index, &exists);
	if (exists) {
		IDWriteFontFamily *fam = nullptr;
		if (SUCCEEDED(coll->GetFontFamily(index, &fam)) && fam) {
			IDWriteFont *font = nullptr;
			if (SUCCEEDED(fam->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL, DWRITE_FONT_STYLE_NORMAL, &font)) && font) {
				IDWriteFontFace *face = nullptr;
				if (SUCCEEDED(font->CreateFontFace(&face)) && face) {
					DWRITE_FONT_METRICS fm{};
					face->GetMetrics(&fm);
					UINT32 cp = '0';
					UINT16 gi = 0;
					DWRITE_GLYPH_METRICS gm{};
					if (SUCCEEDED(face->GetGlyphIndices(&cp, 1, &gi)) && SUCCEEDED(face->GetDesignGlyphMetrics(&gi, 1, &gm, FALSE)) && fm.designUnitsPerEm)
						ratio = static_cast<double>(gm.advanceWidth) / fm.designUnitsPerEm;
					face->Release();
				}
				font->Release();
			}
			fam->Release();
		}
	}
	coll->Release();
	return ratio;
}

int CALLBACK EnumFamProc(const LOGFONTW *lf, const TEXTMETRICW *, DWORD type, LPARAM lp) {
	auto *out = reinterpret_cast<std::set<std::wstring> *>(lp);
	if ((lf->lfPitchAndFamily & 3) == FIXED_PITCH || wcsstr(lf->lfFaceName, L"Mono") || wcsstr(lf->lfFaceName, L"Courier")) {
		if (lf->lfFaceName[0] != L'@' && (type & TRUETYPE_FONTTYPE))
			out->insert(lf->lfFaceName);
	}
	return 1;
}

std::set<std::wstring> GdiFixedFamilies() {
	std::set<std::wstring> out;
	HDC dc = ::GetDC(nullptr);
	LOGFONTW lf{};
	lf.lfCharSet = DEFAULT_CHARSET;
	::EnumFontFamiliesExW(dc, &lf, EnumFamProc, reinterpret_cast<LPARAM>(&out), 0);
	::ReleaseDC(nullptr, dc);
	return out;
}

const char *kFontCandidates[] = {"DejaVu Sans Mono", "Liberation Mono", "Consolas", "Courier New", "Cascadia Mono",
	"Noto Sans Mono", "FreeMono"};

void chooseFontAndSize() {
	if (g_font.empty()) {
		const auto gdi = GdiFixedFamilies();
		for (const char *c : kFontCandidates) {
			if (DWriteHasFamily(c) && gdi.count(Widen(c))) {
				g_font = c;
				break;
			}
		}
		if (g_font.empty())
			g_font = "Courier New";
	}
	const double ratio = DWriteAdvanceRatio(g_font);
	if (g_sizeHundredths == 0) {
		g_sizeHundredths = 1100;
		if (ratio > 0) {
			// Choose a size near 11pt whose natural advance (at 96 dpi) has a fractional part in [0.3, 0.7]
			for (int delta = 0; delta <= 400; delta += 25) {
				bool found = false;
				for (int sign : {1, -1}) {
					const int hs = 1100 + sign * delta;
					const double adv = hs / 100.0 * 96.0 / 72.0 * ratio;
					const double frac = adv - std::floor(adv);
					if (frac >= 0.3 && frac <= 0.7) {
						g_sizeHundredths = hs;
						found = true;
						break;
					}
				}
				if (found)
					break;
			}
		}
	}
	g_expectedNaturalAdvance = ratio > 0 ? g_sizeHundredths / 100.0 * 96.0 / 72.0 * ratio : 0.0;
}

// ---------------------------------------------------------------------------------------------
// Rendering parameter helpers

sptr_t getParam(int p) {
	return sci(SCI_GETFONTRENDERINGPARAMETER, static_cast<uptr_t>(static_cast<intptr_t>(p)));
}
void setParam(int p, int v) {
	sci(SCI_SETFONTRENDERINGPARAMETER, static_cast<uptr_t>(static_cast<intptr_t>(p)), v);
}
void resetParams() {
	for (int p = 0; p <= 6; ++p)
		setParam(p, SC_FONTRENDERING_DEFAULT);
}
const char *ParamName(int p) {
	static const char *n[] = {"GAMMA", "ENHANCEDCONTRAST", "GRAYSCALEENHANCEDCONTRAST", "CLEARTYPELEVEL", "PIXELGEOMETRY", "RENDERINGMODE", "LIGHTTEXTGAMMA"};
	return (p >= 0 && p <= 6) ? n[p] : "UNKNOWN";
}
const char *ModeName(int m) {
	switch (m) {
	case -1: return "unset";
	case SC_RENDERINGMODE_DEFAULT: return "DEFAULT";
	case SC_RENDERINGMODE_GDICLASSIC: return "GDICLASSIC";
	case SC_RENDERINGMODE_GDINATURAL: return "GDINATURAL";
	case SC_RENDERINGMODE_NATURAL: return "NATURAL";
	case SC_RENDERINGMODE_NATURALSYMMETRIC: return "NATURALSYMMETRIC";
	case SC_RENDERINGMODE_ADAPTIVE: return "ADAPTIVE";
	}
	return "?";
}
const char *QualityName(int q) {
	static const char *n[] = {"DEFAULT", "NON_ANTIALIASED", "ANTIALIASED", "LCD_OPTIMIZED"};
	return (q >= 0 && q <= 3) ? n[q] : "?";
}
const char *TechName(int t) {
	static const char *n[] = {"DEFAULT(GDI)", "DIRECTWRITE", "DIRECTWRITERETAIN", "DIRECTWRITEDC", "DIRECT_WRITE_1"};
	return (t >= 0 && t <= 4) ? n[t] : "?";
}
bool IsGdiMode(int m) {
	return m == SC_RENDERINGMODE_GDICLASSIC || m == SC_RENDERINGMODE_GDINATURAL;
}

bool setTech(int t) {
	sci(SCI_SETTECHNOLOGY, t);
	return sci(SCI_GETTECHNOLOGY) == t;
}

template <typename F>
void guarded(const char *name, F &&f) {
	g_test = name;
	try {
		f();
	} catch (const std::exception &e) {
		report(St::CRASH, name, "C++ exception: %s", e.what());
	} catch (...) {
		report(St::CRASH, name, "unknown C++ exception");
	}
	if (g_sci && !::IsWindow(g_sci)) {
		report(St::CRASH, name, "Scintilla window was destroyed");
		g_sci = nullptr;
		if (g_frame && ::IsWindow(g_frame))
			::DestroyWindow(g_frame);
		g_frame = nullptr;
		if (!createWindows())
			report(St::CRASH, name, "could not recreate the test window");
	}
}

// ---------------------------------------------------------------------------------------------
// Groups

void groupEnv() {
	guarded("wine_version", [] {
		HMODULE nt = ::GetModuleHandleW(L"ntdll.dll");
		typedef const char *(CDECL * WGV)(void);
		auto wgv = nt ? reinterpret_cast<WGV>(reinterpret_cast<void *>(::GetProcAddress(nt, "wine_get_version"))) : nullptr;
		report(St::INFO, "wine_version", "%s", wgv ? wgv() : "not running on Wine");
		report(St::INFO, "header_has_api", "%s", SCITEST_HEADER_HAS_API ? "Scintilla.h declares SCI_SETFONTRENDERINGPARAMETER"
			: "Scintilla.h lacks the private API; built with the contract values");
	});
	guarded("fonts", [] {
		const auto gdi = GdiFixedFamilies();
		std::string list;
		for (const auto &f : gdi) {
			if (!list.empty())
				list += "; ";
			list += Narrow(f);
		}
		report(St::INFO, "gdi_fixed_pitch_fonts", "%zu: %s", gdi.size(), list.c_str());
		std::string dw;
		for (const char *c : kFontCandidates) {
			dw += c;
			dw += DWriteHasFamily(c) ? "=yes " : "=no ";
		}
		report(St::INFO, "dwrite_candidates", "%s", dw.c_str());
		report(St::INFO, "chosen_font", "font=\"%s\" size=%.2fpt expected_natural_advance=%.4fpx (size chosen so the natural advance is clearly fractional; the GDI-compatible advance is the hinted one, not necessarily the rounded natural one)",
			g_font.c_str(), g_sizeHundredths / 100.0, g_expectedNaturalAdvance);
	});
	guarded("dwrite", [] {
		IDWriteFactory *f = DWriteFactory();
		check(f != nullptr, "dwrite_factory", "DWriteCreateFactory %s", f ? "ok" : "FAILED");
		if (!f)
			return;
		IDWriteFontCollection *coll = nullptr;
		if (SUCCEEDED(f->GetSystemFontCollection(&coll, FALSE)) && coll) {
			report(St::INFO, "dwrite_system_families", "%u families", coll->GetFontFamilyCount());
			coll->Release();
		}
		IDWriteRenderingParams *rp = nullptr;
		const HMONITOR mon = ::MonitorFromWindow(g_frame, MONITOR_DEFAULTTOPRIMARY);
		if (SUCCEEDED(f->CreateMonitorRenderingParams(mon, &rp)) && rp) {
			report(St::INFO, "monitor_rendering_params", "gamma=%.3f enhancedContrast=%.3f clearTypeLevel=%.3f pixelGeometry=%d renderingMode=%d",
				rp->GetGamma(), rp->GetEnhancedContrast(), rp->GetClearTypeLevel(), static_cast<int>(rp->GetPixelGeometry()),
				static_cast<int>(rp->GetRenderingMode()));
			rp->Release();
		} else {
			report(St::WARN, "monitor_rendering_params", "CreateMonitorRenderingParams failed");
		}
	});
	guarded("system_smoothing", [] {
		BOOL smoothing = FALSE;
		UINT type = 0, contrast = 0, orientation = 0;
		::SystemParametersInfoW(SPI_GETFONTSMOOTHING, 0, &smoothing, 0);
		::SystemParametersInfoW(SPI_GETFONTSMOOTHINGTYPE, 0, &type, 0);
		::SystemParametersInfoW(SPI_GETFONTSMOOTHINGCONTRAST, 0, &contrast, 0);
		::SystemParametersInfoW(0x2012 /*SPI_GETFONTSMOOTHINGORIENTATION*/, 0, &orientation, 0);
		HDC dc = ::GetDC(nullptr);
		const int dpi = ::GetDeviceCaps(dc, LOGPIXELSY);
		const int bpp = ::GetDeviceCaps(dc, BITSPIXEL);
		::ReleaseDC(nullptr, dc);
		report(St::INFO, "system_font_smoothing", "smoothing=%d type=%u(2=ClearType) contrast=%u orientation=%u dpi=%d bpp=%d",
			smoothing, type, contrast, orientation, dpi, bpp);
	});
	guarded("d2d_load", [] {
		HMODULE d2d = ::LoadLibraryW(L"d2d1.dll");
		HMODULE d3d = ::LoadLibraryW(L"d3d11.dll");
		report(St::INFO, "d2d_dlls", "d2d1.dll=%s d3d11.dll=%s", d2d ? "loaded" : "missing", d3d ? "loaded" : "missing");
	});
}

void groupTechs() {
	const int techs[] = {SC_TECHNOLOGY_DEFAULT, SC_TECHNOLOGY_DIRECTWRITE, SC_TECHNOLOGY_DIRECTWRITERETAIN,
		SC_TECHNOLOGY_DIRECTWRITEDC, SC_TECHNOLOGY_DIRECT_WRITE_1};
	for (int t : techs) {
		std::string name = std::string("tech_") + TechName(t);
		guarded(name.c_str(), [&] {
			const bool ok = setTech(t);
			check(ok, (name + "_get").c_str(), "SCI_SETTECHNOLOGY(%d) -> SCI_GETTECHNOLOGY=%d", t, static_cast<int>(sci(SCI_GETTECHNOLOGY)));
			if (!ok)
				return;
			repaint();
			long paints = 0;
			const std::string storm = paintStorm(400, paints);
			check(paints < 10, (name + "_no_repaint_storm").c_str(), "WM_PAINT dispatched during 400 ms idle: %s", storm.c_str());
			const Meas m = measure();
			report(St::INFO, (name + "_measure").c_str(), "%s", measStr(m).c_str());
			captureCheck((name + "_screen").c_str(), std::string("tech_") + std::to_string(t));
			// Alternative capture paths, to document what works under this platform
			Img a, b;
			const bool okA = grabWindowDC(g_sci, a);
			const Stats sa = stats(a);
			const bool okB = grabPrintWindow(g_sci, b);
			const Stats sb = stats(b);
			report(St::INFO, (name + "_alt_captures").c_str(), "windowDC(%s nonbg=%ld bg=#%06x) PrintWindow(%s nonbg=%ld bg=#%06x)",
				okA ? "ok" : "fail", sa.nonbg, sa.bg, okB ? "ok" : "fail", sb.nonbg, sb.bg);
		});
	}
	setTech(SC_TECHNOLOGY_DEFAULT);
}

struct PV {
	int p, v;
};

void groupApi() {
	if (!setTech(SC_TECHNOLOGY_DIRECTWRITE))
		report(St::WARN, "api_tech", "DirectWrite not available: API checks run with GDI technology");
	guarded("initial_unset", [] {
		std::string got;
		bool ok = true;
		for (int p = 0; p <= 6; ++p) {
			const sptr_t v = getParam(p);
			got += std::string(ParamName(p)) + "=" + std::to_string(v) + " ";
			ok = ok && v == -1;
		}
		check(ok, "initial_unset", "fresh window: every GET returns -1: %s", got.c_str());
	});
	const PV valid[] = {
		{0, 1000}, {0, 1800}, {0, 2200},
		{1, 0}, {1, 50}, {1, 1000},
		{2, 0}, {2, 100}, {2, 1000},
		{3, 0}, {3, 50}, {3, 100},
		{4, SC_PIXELGEOMETRY_FLAT}, {4, SC_PIXELGEOMETRY_RGB}, {4, SC_PIXELGEOMETRY_BGR},
		{5, SC_RENDERINGMODE_DEFAULT}, {5, SC_RENDERINGMODE_GDICLASSIC}, {5, SC_RENDERINGMODE_GDINATURAL},
		{5, SC_RENDERINGMODE_NATURAL}, {5, SC_RENDERINGMODE_NATURALSYMMETRIC}, {5, SC_RENDERINGMODE_ADAPTIVE},
		{6, 0}, {6, 1000}, {6, 1800}, {6, 2200},
	};
	guarded("valid_roundtrip", [&] {
		for (const PV &pv : valid) {
			setParam(pv.p, pv.v);
			const sptr_t got = getParam(pv.p);
			char nm[96];
			snprintf(nm, sizeof(nm), "roundtrip_%s_%d", ParamName(pv.p), pv.v);
			check(got == pv.v, nm, "SET(%d,%d) then GET(%d)=%lld", pv.p, pv.v, pv.p, static_cast<long long>(got));
		}
	});
	// Out-of-range values: a known valid value is set first, the invalid SET must leave it unchanged.
	const PV baseValid[] = {{0, 1500}, {1, 100}, {2, 100}, {3, 50}, {4, SC_PIXELGEOMETRY_RGB}, {5, SC_RENDERINGMODE_NATURAL}, {6, 2000}};
	const PV invalid[] = {
		{0, 999}, {0, 2201}, {0, 0}, {0, -2}, {0, 100000},
		{1, -2}, {1, 1001}, {1, INT32_MIN},
		{2, -2}, {2, 1001},
		{3, -2}, {3, 101},
		{4, -2}, {4, 3}, {4, 99},
		{5, -2}, {5, 1 /*DWRITE_RENDERING_MODE_ALIASED*/}, {5, 6 /*OUTLINE*/}, {5, 7}, {5, 99}, {5, 101},
		{6, -2}, {6, 1}, {6, 999}, {6, 2201},
	};
	guarded("invalid_value_ignored", [&] {
		for (const PV &pv : invalid) {
			const int base = baseValid[pv.p].v;
			setParam(pv.p, base);
			setParam(pv.p, pv.v);
			const sptr_t got = getParam(pv.p);
			char nm[96];
			snprintf(nm, sizeof(nm), "invalid_%s_%d", ParamName(pv.p), pv.v);
			check(got == base, nm, "SET(%d,%d) then SET(%d,%d invalid) then GET=%lld (expect %d)", pv.p, base, pv.p, pv.v,
				static_cast<long long>(got), base);
		}
	});
	guarded("unknown_parameter_ignored", [&] {
		for (const PV &pv : baseValid)
			setParam(pv.p, pv.v);
		const intptr_t unknown[] = {7, 8, 100, -1, -2, 0x10000, static_cast<intptr_t>(0x7FFFFFFF)};
		for (intptr_t p : unknown) {
			sci(SCI_SETFONTRENDERINGPARAMETER, static_cast<uptr_t>(p), 1);
			const sptr_t got = sci(SCI_GETFONTRENDERINGPARAMETER, static_cast<uptr_t>(p));
			char nm[96];
			snprintf(nm, sizeof(nm), "unknown_param_%lld_get", static_cast<long long>(p));
			check(got == -1, nm, "SET(%lld,1) then GET(%lld)=%lld (expect -1)", static_cast<long long>(p),
				static_cast<long long>(p), static_cast<long long>(got));
		}
		bool unchanged = true;
		std::string got;
		for (const PV &pv : baseValid) {
			const sptr_t v = getParam(pv.p);
			got += std::to_string(v) + " ";
			unchanged = unchanged && v == pv.v;
		}
		check(unchanged, "unknown_param_no_side_effect", "known parameters unchanged after unknown SETs: %s", got.c_str());
	});
	guarded("reset", [&] {
		for (const PV &pv : baseValid) {
			setParam(pv.p, pv.v);
			setParam(pv.p, SC_FONTRENDERING_DEFAULT);
			const sptr_t got = getParam(pv.p);
			char nm[96];
			snprintf(nm, sizeof(nm), "reset_%s", ParamName(pv.p));
			check(got == -1, nm, "SET(%d,%d) then SET(%d,-1) then GET=%lld", pv.p, pv.v, pv.p, static_cast<long long>(got));
		}
	});
	guarded("set_return_value", [&] {
		const sptr_t r = sci(SCI_SETFONTRENDERINGPARAMETER, SC_FONTRENDERING_GAMMA, 1400);
		report(St::INFO, "set_return_value", "SCI_SETFONTRENDERINGPARAMETER returned %lld", static_cast<long long>(r));
		resetParams();
	});
	guarded("paint_after_api", [&] {
		repaint();
		captureCheck("paint_after_api", "api_after");
	});
}

void groupMatrix() {
	const bool dw = setTech(SC_TECHNOLOGY_DIRECTWRITE);
	check(dw, "matrix_directwrite", "SCI_GETTECHNOLOGY=%d after SCI_SETTECHNOLOGY(DIRECTWRITE)", static_cast<int>(sci(SCI_GETTECHNOLOGY)));
	if (!dw) {
		report(St::SKIP, "matrix", "DirectWrite unavailable");
		return;
	}
	const int modes[] = {-1, SC_RENDERINGMODE_NATURAL, SC_RENDERINGMODE_NATURALSYMMETRIC, SC_RENDERINGMODE_GDICLASSIC, SC_RENDERINGMODE_GDINATURAL, SC_RENDERINGMODE_ADAPTIVE};
	const int qualities[] = {SC_EFF_QUALITY_DEFAULT, SC_EFF_QUALITY_NON_ANTIALIASED, SC_EFF_QUALITY_ANTIALIASED, SC_EFF_QUALITY_LCD_OPTIMIZED};
	std::map<std::pair<int, int>, Stats> results;
	std::map<std::pair<int, int>, Meas> meas;
	for (int q : qualities) {
		for (int mode : modes) {
			char nm[96];
			snprintf(nm, sizeof(nm), "rm_%s_q_%s", ModeName(mode), QualityName(q));
			guarded(nm, [&] {
				resetParams();
				setParam(SC_FONTRENDERING_RENDERINGMODE, mode);
				sci(SCI_SETFONTQUALITY, q);
				repaint();
				const sptr_t gotMode = getParam(SC_FONTRENDERING_RENDERINGMODE);
				const Meas m = measure();
				meas[{mode, q}] = m;
				// Natural modes: fractional advances expected (the size is chosen so the natural advance is fractional);
				// GDI modes: GDI-compatible measuring, whole-pixel advances.
				const bool wantIntegral = IsGdiMode(mode);
				bool ok = m.uniform == wantIntegral;
				if (!wantIntegral && g_expectedNaturalAdvance > 0)
					ok = ok && std::fabs(m.avg - g_expectedNaturalAdvance) < 0.05;
				check(ok, (std::string(nm) + "_measure").c_str(), "GET(RENDERINGMODE)=%lld expect %s advances%s; %s",
					static_cast<long long>(gotMode), wantIntegral ? "integral" : "fractional",
					wantIntegral ? "" : (" ~" + std::to_string(g_expectedNaturalAdvance)).c_str(), measStr(m).c_str());
				char file[96];
				snprintf(file, sizeof(file), "matrix_rm%s_q%d", mode < 0 ? "unset" : std::to_string(mode).c_str(), q);
				results[{mode, q}] = captureCheck((std::string(nm) + "_paint").c_str(), file);
			});
		}
	}
	// Light text on a dark background with a light-text gamma and the adaptive mode: rendering parameter
	// variants (light, small, small+light) are selected per text colour and size, must paint non-blank.
	for (int q : qualities) {
		char nm[96];
		snprintf(nm, sizeof(nm), "dark_lighttext_adaptive_q_%s", QualityName(q));
		guarded(nm, [&] {
			resetParams();
			sci(SCI_STYLESETFORE, STYLE_DEFAULT, RGB(0xDC, 0xDC, 0xCC));
			sci(SCI_STYLESETBACK, STYLE_DEFAULT, RGB(0x1E, 0x1E, 0x1E));
			sci(SCI_STYLECLEARALL);
			setParam(SC_FONTRENDERING_LIGHTTEXTGAMMA, 2200);
			setParam(SC_FONTRENDERING_RENDERINGMODE, SC_RENDERINGMODE_ADAPTIVE);
			sci(SCI_SETFONTQUALITY, q);
			repaint();
			check(getParam(SC_FONTRENDERING_LIGHTTEXTGAMMA) == 2200, (std::string(nm) + "_get").c_str(), "light text gamma kept");
			char file[96];
			snprintf(file, sizeof(file), "dark_q%d", q);
			captureCheck((std::string(nm) + "_paint").c_str(), file);
		});
	}
	sci(SCI_STYLESETFORE, STYLE_DEFAULT, RGB(0, 0, 0));
	sci(SCI_STYLESETBACK, STYLE_DEFAULT, RGB(0xFF, 0xFF, 0xFF));
	sci(SCI_STYLECLEARALL);
	// Cross-checks of the images (what the platform's Direct2D honours)
	guarded("matrix_summary", [&] {
		for (int q : qualities) {
			std::set<uint64_t> hashes;
			std::string detail;
			for (int mode : modes) {
				const Stats &s = results[{mode, q}];
				hashes.insert(s.hash);
				char b[160];
				snprintf(b, sizeof(b), "%s:gray=%ld,chroma=%ld,hash=%04llx ", ModeName(mode), s.gray, s.chroma,
					static_cast<unsigned long long>(s.hash & 0xFFFF));
				detail += b;
			}
			report(St::INFO, (std::string("images_by_mode_q_") + QualityName(q)).c_str(), "%zu distinct images over %zu modes: %s",
				hashes.size(), std::size(modes), detail.c_str());
		}
		for (int mode : modes) {
			std::set<uint64_t> hashes;
			for (int q : qualities)
				hashes.insert(results[{mode, q}].hash);
			const Stats &na = results[{mode, SC_EFF_QUALITY_NON_ANTIALIASED}];
			const Stats &aa = results[{mode, SC_EFF_QUALITY_ANTIALIASED}];
			const Stats &lcd = results[{mode, SC_EFF_QUALITY_LCD_OPTIMIZED}];
			report(St::INFO, (std::string("quality_effect_rm_") + ModeName(mode)).c_str(),
				"%zu distinct images over 4 qualities; NON_AA gray=%ld chroma=%ld; AA gray=%ld chroma=%ld; LCD gray=%ld chroma=%ld (chroma>0 => subpixel/ClearType output)",
				hashes.size(), na.gray, na.chroma, aa.gray, aa.chroma, lcd.gray, lcd.chroma);
			check(na.chroma == 0, (std::string("non_antialiased_no_color_rm_") + ModeName(mode)).c_str(),
				"SC_EFF_QUALITY_NON_ANTIALIASED output has chroma=%ld coloured pixels", na.chroma);
		}
		// Capture freshness: when two modes measured different positions, their images must differ
		// (identical images would mean a stale capture, i.e. the Direct2D frame was not on screen yet)
		for (int q : qualities) {
			for (size_t i = 0; i < std::size(modes); ++i) {
				for (size_t j = i + 1; j < std::size(modes); ++j) {
					if (meas[{modes[i], q}].x != meas[{modes[j], q}].x && results[{modes[i], q}].hash == results[{modes[j], q}].hash)
						report(St::WARN, "stale_capture", "q=%s modes %s/%s measured differently but captured identical images",
							QualityName(q), ModeName(modes[i]), ModeName(modes[j]));
				}
			}
		}
		// Measuring must not depend on the quality for a given mode
		for (int mode : modes) {
			bool same = true;
			for (int q : qualities)
				same = same && meas[{mode, q}].x == meas[{mode, SC_EFF_QUALITY_DEFAULT}].x;
			check(same, (std::string("measure_independent_of_quality_rm_") + ModeName(mode)).c_str(),
				"POINTXFROMPOSITION identical for the 4 qualities");
		}
	});
	resetParams();
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_DEFAULT);
}

// Which parameters change the Direct2D output on this platform (Wine may ignore some)
void groupSensitivity() {
	if (!setTech(SC_TECHNOLOGY_DIRECTWRITE)) {
		report(St::SKIP, "sensitivity", "DirectWrite unavailable");
		return;
	}
	struct Case {
		int q, p, lo, hi;
	};
	const Case cases[] = {
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_GAMMA, 1000, 2200},
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_ENHANCEDCONTRAST, 0, 1000},
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_CLEARTYPELEVEL, 0, 100},
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_PIXELGEOMETRY, SC_PIXELGEOMETRY_RGB, SC_PIXELGEOMETRY_BGR},
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_PIXELGEOMETRY, SC_PIXELGEOMETRY_FLAT, SC_PIXELGEOMETRY_RGB},
		{SC_EFF_QUALITY_ANTIALIASED, SC_FONTRENDERING_GAMMA, 1000, 2200},
		{SC_EFF_QUALITY_ANTIALIASED, SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST, 0, 1000},
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_RENDERINGMODE, SC_RENDERINGMODE_NATURAL, SC_RENDERINGMODE_NATURALSYMMETRIC},
		{SC_EFF_QUALITY_LCD_OPTIMIZED, SC_FONTRENDERING_RENDERINGMODE, SC_RENDERINGMODE_GDICLASSIC, SC_RENDERINGMODE_GDINATURAL},
	};
	for (const Case &c : cases) {
		char nm[128];
		snprintf(nm, sizeof(nm), "sens_%s_%d_vs_%d_q_%s", ParamName(c.p), c.lo, c.hi, QualityName(c.q));
		guarded(nm, [&] {
			resetParams();
			sci(SCI_SETFONTQUALITY, c.q);
			setParam(c.p, c.lo);
			repaint();
			Img a;
			grabScreen(g_sci, a);
			const Stats sa = stats(a);
			setParam(c.p, c.hi);
			repaint();
			Img b;
			grabScreen(g_sci, b);
			const Stats sb = stats(b);
			long diff = 0;
			for (size_t i = 0; i < a.px.size() && i < b.px.size(); ++i)
				diff += a.px[i] != b.px[i];
			report(St::INFO, nm, "output %s (%ld pixels differ; lo: gray=%ld chroma=%ld nonbg=%ld; hi: gray=%ld chroma=%ld nonbg=%ld)",
				diff ? "CHANGES" : "identical", diff, sa.gray, sa.chroma, sa.nonbg, sb.gray, sb.chroma, sb.nonbg);
			check(sa.nonbg >= minNonBlank && sb.nonbg >= minNonBlank, (std::string(nm) + "_nonblank").c_str(),
				"both captures non-blank (%ld, %ld)", sa.nonbg, sb.nonbg);
		});
	}
	resetParams();
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_DEFAULT);
}

void setOverrides() {
	setParam(SC_FONTRENDERING_GAMMA, 1800);
	setParam(SC_FONTRENDERING_ENHANCEDCONTRAST, 200);
	setParam(SC_FONTRENDERING_GRAYSCALEENHANCEDCONTRAST, 100);
	setParam(SC_FONTRENDERING_CLEARTYPELEVEL, 50);
	setParam(SC_FONTRENDERING_PIXELGEOMETRY, SC_PIXELGEOMETRY_BGR);
	setParam(SC_FONTRENDERING_RENDERINGMODE, SC_RENDERINGMODE_GDICLASSIC);
}

bool overridesKept(std::string &got) {
	const int want[] = {1800, 200, 100, 50, SC_PIXELGEOMETRY_BGR, SC_RENDERINGMODE_GDICLASSIC};
	bool ok = true;
	got.clear();
	for (int p = 0; p <= 5; ++p) {
		const sptr_t v = getParam(p);
		got += std::to_string(v) + " ";
		ok = ok && v == want[p];
	}
	return ok;
}

void groupSwitch() {
	if (!setTech(SC_TECHNOLOGY_DIRECTWRITE)) {
		report(St::SKIP, "switch", "DirectWrite unavailable");
		return;
	}
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_LCD_OPTIMIZED);
	guarded("dw_with_overrides", [] {
		setOverrides();
		repaint();
		const Meas m = measure();
		check(m.uniform, "dw_overrides_gdiclassic_integral", "%s", measStr(m).c_str());
		captureCheck("dw_overrides_paint", "switch_1_dw");
	});
	guarded("to_gdi", [] {
		const bool ok = setTech(SC_TECHNOLOGY_DEFAULT);
		check(ok, "to_gdi_tech", "GETTECHNOLOGY=%d", static_cast<int>(sci(SCI_GETTECHNOLOGY)));
		std::string got;
		check(overridesKept(got), "to_gdi_overrides_kept", "overrides after switch to GDI: %s", got.c_str());
		repaint();
		const Meas m = measure();
		check(m.uniform, "gdi_integral", "GDI technology: %s", measStr(m).c_str());
		captureCheck("gdi_paint", "switch_2_gdi");
	});
	guarded("set_while_gdi", [] {
		setParam(SC_FONTRENDERING_RENDERINGMODE, SC_RENDERINGMODE_NATURAL);
		const sptr_t v = getParam(SC_FONTRENDERING_RENDERINGMODE);
		check(v == SC_RENDERINGMODE_NATURAL, "set_while_gdi_stored", "SET(RENDERINGMODE,NATURAL) with GDI technology then GET=%lld", static_cast<long long>(v));
		repaint();
		captureCheck("set_while_gdi_paint", "switch_3_gdi_natural");
	});
	guarded("back_to_dw", [] {
		const bool ok = setTech(SC_TECHNOLOGY_DIRECTWRITE);
		check(ok, "back_to_dw_tech", "GETTECHNOLOGY=%d", static_cast<int>(sci(SCI_GETTECHNOLOGY)));
		repaint();
		const Meas m = measure();
		check(!m.uniform, "back_to_dw_natural_fractional", "RENDERINGMODE=NATURAL set under GDI applies after the switch: %s", measStr(m).c_str());
		captureCheck("back_to_dw_paint", "switch_4_dw_natural");
		setParam(SC_FONTRENDERING_RENDERINGMODE, SC_RENDERINGMODE_GDICLASSIC);
		repaint();
		const Meas m2 = measure();
		check(m2.uniform, "dw_gdiclassic_again_integral", "%s", measStr(m2).c_str());
		std::string got;
		check(overridesKept(got), "back_to_dw_overrides_kept", "overrides: %s", got.c_str());
	});
	const int cycle[] = {SC_TECHNOLOGY_DIRECTWRITEDC, SC_TECHNOLOGY_DIRECTWRITERETAIN, SC_TECHNOLOGY_DIRECT_WRITE_1, SC_TECHNOLOGY_DEFAULT, SC_TECHNOLOGY_DIRECTWRITE};
	int i = 5;
	for (int t : cycle) {
		std::string nm = std::string("cycle_") + TechName(t);
		guarded(nm.c_str(), [&] {
			const bool ok = setTech(t);
			if (!ok) {
				report(St::WARN, (nm + "_tech").c_str(), "technology %s not available (GET=%d)", TechName(t), static_cast<int>(sci(SCI_GETTECHNOLOGY)));
				return;
			}
			repaint();
			std::string got;
			check(overridesKept(got), (nm + "_overrides_kept").c_str(), "overrides: %s", got.c_str());
			const Meas m = measure();
			check(m.uniform, (nm + "_integral").c_str(), "GDICLASSIC override (or GDI) => integral: %s", measStr(m).c_str());
			captureCheck((nm + "_paint").c_str(), "switch_" + std::to_string(i++) + "_" + std::to_string(t));
		});
	}
	resetParams();
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_DEFAULT);
}

void groupSettingChange() {
	if (!setTech(SC_TECHNOLOGY_DIRECTWRITE)) {
		report(St::SKIP, "settingchange", "DirectWrite unavailable");
		return;
	}
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_LCD_OPTIMIZED);
	guarded("wm_settingchange", [] {
		setOverrides();
		repaint();
		const Meas before = measure();
		::SendMessageW(g_sci, WM_SETTINGCHANGE, SPI_SETFONTSMOOTHINGCONTRAST, 0);
		::SendMessageW(g_sci, WM_SETTINGCHANGE, 0, reinterpret_cast<LPARAM>(L"WindowMetrics"));
		repaint();
		std::string got;
		check(overridesKept(got), "settingchange_overrides_kept", "overrides after WM_SETTINGCHANGE: %s", got.c_str());
		const Meas after = measure();
		check(after.uniform && after.x == before.x, "settingchange_measure_stable", "before: %s | after: %s", measStr(before).c_str(), measStr(after).c_str());
		captureCheck("settingchange_paint", "settingchange_1");
	});
	guarded("system_contrast_change", [] {
		UINT oldContrast = 0;
		::SystemParametersInfoW(SPI_GETFONTSMOOTHINGCONTRAST, 0, &oldContrast, 0);
		// Not persisted (no SPIF_UPDATEINIFILE): only this Wine session / Windows logon session
		const BOOL ok = ::SystemParametersInfoW(SPI_SETFONTSMOOTHINGCONTRAST, 0, reinterpret_cast<PVOID>(static_cast<UINT_PTR>(2000)), 0);
		::SendMessageW(g_sci, WM_SETTINGCHANGE, SPI_SETFONTSMOOTHINGCONTRAST, 0);
		repaint();
		UINT now = 0;
		::SystemParametersInfoW(SPI_GETFONTSMOOTHINGCONTRAST, 0, &now, 0);
		report(St::INFO, "system_contrast_change", "SPI_SETFONTSMOOTHINGCONTRAST(2000) %s, contrast %u -> %u", ok ? "ok" : "failed", oldContrast, now);
		captureCheck("system_contrast_paint", "settingchange_2");
		resetParams();
		::SendMessageW(g_sci, WM_SETTINGCHANGE, SPI_SETFONTSMOOTHINGCONTRAST, 0);
		repaint();
		captureCheck("system_contrast_reset_paint", "settingchange_3");
		if (oldContrast)
			::SystemParametersInfoW(SPI_SETFONTSMOOTHINGCONTRAST, 0, reinterpret_cast<PVOID>(static_cast<UINT_PTR>(oldContrast)), 0);
		::SendMessageW(g_sci, WM_SETTINGCHANGE, SPI_SETFONTSMOOTHINGCONTRAST, 0);
	});
	guarded("broadcast_settingchange", [] {
		setOverrides();
		// The frame does not forward it: this only proves a top-level broadcast is harmless
		DWORD_PTR res = 0;
		::SendMessageTimeoutW(HWND_BROADCAST, WM_SETTINGCHANGE, 0, reinterpret_cast<LPARAM>(L"intl"), SMTO_ABORTIFHUNG, 2000, &res);
		repaint();
		std::string got;
		check(overridesKept(got), "broadcast_overrides_kept", "overrides: %s", got.c_str());
		captureCheck("broadcast_paint", "settingchange_4");
	});
	resetParams();
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_DEFAULT);
}

struct FindCls {
	const wchar_t *cls;
	HWND found;
};

BOOL CALLBACK FindThreadWnd(HWND h, LPARAM lp) {
	auto *f = reinterpret_cast<FindCls *>(lp);
	wchar_t cls[128] = {};
	::GetClassNameW(h, cls, 127);
	if (wcscmp(cls, f->cls) == 0 && ::IsWindowVisible(h)) {
		f->found = h;
		return FALSE;
	}
	return TRUE;
}

HWND findPopup(const wchar_t *cls) {
	FindCls f{cls, nullptr};
	::EnumThreadWindows(::GetCurrentThreadId(), FindThreadWnd, reinterpret_cast<LPARAM>(&f));
	return f.found;
}

void popupsFor(int tech, int mode, int quality) {
	char tag[96];
	snprintf(tag, sizeof(tag), "%s_rm_%s_q_%s", tech ? "dw" : "gdi", ModeName(mode), QualityName(quality));
	char ftag[64];
	snprintf(ftag, sizeof(ftag), "t%d_rm%s_q%d", tech, mode < 0 ? "unset" : std::to_string(mode).c_str(), quality);
	guarded((std::string("autoc_") + tag).c_str(), [&] {
		resetParams();
		setParam(SC_FONTRENDERING_RENDERINGMODE, mode);
		sci(SCI_SETFONTQUALITY, quality);
		sci(SCI_DOCUMENTEND);
		repaint();
		sci(SCI_AUTOCSETSEPARATOR, ' ');
		sci(SCI_AUTOCSHOW, 3, reinterpret_cast<sptr_t>("alpha alphabet alphanumeric alpine altitude"));
		pump(150);
		const bool active = sci(SCI_AUTOCACTIVE) != 0;
		HWND lb = findPopup(L"ListBoxX");
		check(active && lb, (std::string("autoc_shown_") + tag).c_str(), "SCI_AUTOCACTIVE=%d ListBoxX window=%p", active, static_cast<void *>(lb));
		if (lb) {
			::RedrawWindow(lb, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW | RDW_ALLCHILDREN);
			pump(150);
			long paints = 0;
			const std::string storm = paintStorm(500, paints);
			check(paints < 20, (std::string("autoc_no_repaint_storm_") + tag).c_str(), "WM_PAINT dispatched during 500 ms idle: %s", storm.c_str());
			RECT r{};
			::GetWindowRect(lb, &r);
			Img img;
			const bool ok = grabScreen(lb, img, true);
			const Stats s = stats(img);
			writeBMP(std::string("popup_autoc_") + ftag + ".bmp", img);
			check(ok && s.nonbg >= 60 && s.bg != 0xFF00FF, (std::string("autoc_paint_") + tag).c_str(), "rect=(%ld,%ld)-(%ld,%ld) %s file=popup_autoc_%s.bmp",
				r.left, r.top, r.right, r.bottom, statsStr(s, img).c_str(), ftag);
		}
		sci(SCI_AUTOCCANCEL);
		pump(50);
	});
	guarded((std::string("calltip_") + tag).c_str(), [&] {
		const sptr_t pos = sci(SCI_POSITIONFROMLINE, 1) + 8;
		sci(SCI_CALLTIPSHOW, pos, reinterpret_cast<sptr_t>("int main(int argc, char **argv)\nsecond line of the call tip"));
		sci(SCI_CALLTIPSETHLT, 9, 17);
		pump(150);
		const bool active = sci(SCI_CALLTIPACTIVE) != 0;
		HWND ct = findPopup(L"CallTip");
		check(active && ct, (std::string("calltip_shown_") + tag).c_str(), "SCI_CALLTIPACTIVE=%d CallTip window=%p", active, static_cast<void *>(ct));
		if (ct) {
			::RedrawWindow(ct, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW);
			pump(150);
			long paints = 0;
			const std::string storm = paintStorm(500, paints);
			// Known Wine behaviour, also with the baseline Scintilla: the Direct2D call tip creates an
			// HwndRenderTarget in every WM_PAINT and Wine's swap chain creation invalidates the window again,
			// so it repaints continuously (~60/s). Reported as WARN (platform), FAIL only for GDI.
			if (paints >= 20 && tech != SC_TECHNOLOGY_DEFAULT)
				report(St::WARN, (std::string("calltip_repaint_loop_") + tag).c_str(), "WM_PAINT dispatched during 500 ms idle: %s (Wine D2D call tip re-invalidates itself; baseline does it too)", storm.c_str());
			else
				check(paints < 20, (std::string("calltip_no_repaint_storm_") + tag).c_str(), "WM_PAINT dispatched during 500 ms idle: %s", storm.c_str());
			Img img;
			const bool ok = grabScreen(ct, img, true);
			const Stats s = stats(img);
			writeBMP(std::string("popup_calltip_") + ftag + ".bmp", img);
			check(ok && s.nonbg >= 60 && s.bg != 0xFF00FF, (std::string("calltip_paint_") + tag).c_str(), "%s file=popup_calltip_%s.bmp",
				statsStr(s, img).c_str(), ftag);
		}
		// whole Scintilla + popups as seen on screen
		Img all;
		RECT r{};
		::GetWindowRect(g_frame, &r);
		HDC screen = ::GetDC(nullptr);
		grabDC(screen, r.left, r.top, r.right - r.left, r.bottom - r.top + 120, all);
		::ReleaseDC(nullptr, screen);
		writeBMP(std::string("popup_screen_") + ftag + ".bmp", all);
		sci(SCI_CALLTIPCANCEL);
		pump(50);
	});
}

// SC_WIN_IDLE / SC_WORK_IDLE are ScintillaWin-internal window messages; the implementation of the private
// 5001/5002 messages must not break them (the baseline used 5001/5002 for them).
void groupIdle() {
	guarded("work_idle_updateui", [] {
		repaint();
		g_updateUI = 0;
		sci(SCI_DOCUMENTEND);
		sci(SCI_ADDTEXT, 5, reinterpret_cast<sptr_t>("hello"));
		pump(400);
		check(g_updateUI > 0, "work_idle_updateui", "SCN_UPDATEUI notifications after SCI_ADDTEXT: %ld (SC_WORK_IDLE path)", g_updateUI);
	});
	guarded("win_idle_wrapping", [] {
		std::string big;
		std::string line;
		while (line.size() < 400)
			line += kLine0Unit;
		for (int i = 0; i < 4000; ++i)
			big += line + "\n";
		sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>(big.c_str()));
		sci(SCI_SETWRAPMODE, SC_WRAP_WORD);
		sci(SCI_GOTOPOS, 0);
		const sptr_t last = sci(SCI_GETLINECOUNT) - 2;
		const sptr_t before = sci(SCI_WRAPCOUNT, last);
		sptr_t after = before;
		const DWORD t0 = ::GetTickCount();
		while (::GetTickCount() - t0 < 20000) {
			pump(200);
			after = sci(SCI_WRAPCOUNT, last);
			if (after > 1)
				break;
		}
		check(after > 1, "win_idle_wrapping", "wrap count of line %lld (off screen): %lld right after SETWRAPMODE, %lld after %lu ms of idle (SC_WIN_IDLE background wrapping)",
			static_cast<long long>(last), static_cast<long long>(before), static_cast<long long>(after), ::GetTickCount() - t0);
		sci(SCI_SETWRAPMODE, SC_WRAP_NONE);
		setupContent();
	});
	guarded("private_messages_no_idle_side_effect", [] {
		// SET/GET of the private messages must not run idle work (they did on the baseline, as 5001/5002)
		g_updateUI = 0;
		for (int i = 0; i < 50; ++i) {
			setParam(SC_FONTRENDERING_GAMMA, 1500);
			getParam(SC_FONTRENDERING_GAMMA);
		}
		resetParams();
		check(g_updateUI == 0, "private_messages_no_idle_work", "SCN_UPDATEUI synchronously caused by 100 private SET/GET messages: %ld (non-zero: 5001/5002 still reach the idle handlers)", g_updateUI);
	});
}

void groupPopups() {
	popupsFor(SC_TECHNOLOGY_DEFAULT, -1, SC_EFF_QUALITY_DEFAULT);
	if (!setTech(SC_TECHNOLOGY_DIRECTWRITE)) {
		report(St::SKIP, "popups_dw", "DirectWrite unavailable");
		return;
	}
	popupsFor(SC_TECHNOLOGY_DIRECTWRITE, -1, SC_EFF_QUALITY_DEFAULT);
	popupsFor(SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_GDICLASSIC, SC_EFF_QUALITY_LCD_OPTIMIZED);
	popupsFor(SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_NATURAL, SC_EFF_QUALITY_ANTIALIASED);
	popupsFor(SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_GDINATURAL, SC_EFF_QUALITY_NON_ANTIALIASED);
	resetParams();
	sci(SCI_SETFONTQUALITY, SC_EFF_QUALITY_DEFAULT);
}

}	// namespace

int main(int argc, char **argv) {
	::SetUnhandledExceptionFilter(CrashFilter);
	::AddVectoredExceptionHandler(1, FirstChanceLogger);
	::SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX);
	std::vector<std::string> groups;
	for (int i = 1; i < argc; ++i) {
		const std::string a = argv[i];
		auto next = [&]() -> std::string { return (i + 1 < argc) ? argv[++i] : std::string(); };
		if (a == "--out")
			g_outDir = next();
		else if (a == "--groups" || a == "--group") {
			std::string s = next();
			size_t p = 0;
			while (p <= s.size()) {
				const size_t c = s.find(',', p);
				const std::string g = s.substr(p, c == std::string::npos ? std::string::npos : c - p);
				if (!g.empty())
					groups.push_back(g);
				if (c == std::string::npos)
					break;
				p = c + 1;
			}
		} else if (a == "--font")
			g_font = next();
		else if (a == "--size")
			g_sizeHundredths = atoi(next().c_str());
		else if (a == "--strict")
			g_strict = true;
		else {
			fprintf(stderr, "usage: scitest.exe [--out DIR] [--groups env,techs,api,matrix,sens,switch,settingchange,popups,idle] [--font NAME] [--size HUNDREDTHS] [--strict]\n");
			return 64;
		}
	}
	if (groups.empty())
		groups = {"env", "techs", "api", "matrix", "sens", "switch", "settingchange", "popups", "idle"};
	::CreateDirectoryA(g_outDir.c_str(), nullptr);
	std::string tsvName = g_outDir + "/results";
	for (const auto &g : groups)
		tsvName += "_" + g;
	if (groups.size() > 3)
		tsvName = g_outDir + "/results_all";
	tsvName += ".tsv";
	g_tsv = fopen(tsvName.c_str(), "w");

	::SetProcessDPIAware();
	::OleInitialize(nullptr);
	g_hInst = ::GetModuleHandleW(nullptr);
	g_group = "init";
	g_test = "Scintilla_RegisterClasses";
	const int reg = Scintilla_RegisterClasses(g_hInst);
	check(reg != 0, "register_classes", "Scintilla_RegisterClasses returned %d", reg);
	chooseFontAndSize();
	g_test = "create_window";
	const bool created = createWindows();
	check(created, "create_window", "frame=%p scintilla=%p", static_cast<void *>(g_frame), static_cast<void *>(g_sci));
	if (!created) {
		report(St::CRASH, "create_window", "cannot continue without a Scintilla window");
		printSummary();
		return 2;
	}
	report(St::INFO, "config", "font=\"%s\" size=%.2fpt expected_natural_advance=%.4f out=%s", g_font.c_str(),
		g_sizeHundredths / 100.0, g_expectedNaturalAdvance, g_outDir.c_str());

	for (const auto &g : groups) {
		g_group = g;
		// Each group starts from a fresh window so groups are independent
		destroyWindows();
		if (!createWindows()) {
			report(St::CRASH, "create_window", "could not create the window for group %s", g.c_str());
			continue;
		}
		if (g == "env")
			groupEnv();
		else if (g == "techs")
			groupTechs();
		else if (g == "api")
			groupApi();
		else if (g == "matrix")
			groupMatrix();
		else if (g == "sens")
			groupSensitivity();
		else if (g == "switch")
			groupSwitch();
		else if (g == "settingchange")
			groupSettingChange();
		else if (g == "popups")
			groupPopups();
		else if (g == "idle")
			groupIdle();
		else
			report(St::SKIP, "unknown_group", "%s", g.c_str());
	}
	g_group = "exit";
	g_test = "destroy";
	destroyWindows();
	Scintilla_ReleaseResources();
	::OleUninitialize();
	printSummary();
	if (g_tsv)
		fclose(g_tsv);
	if (g_count[static_cast<int>(St::CRASH)])
		return 2;
	if (g_strict && g_count[static_cast<int>(St::FAIL)])
		return 1;
	return 0;
}
