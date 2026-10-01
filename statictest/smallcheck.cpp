// smallcheck: how sharply this Notepad++ build draws small text (1 to 12 pt) in each text rendering mode.
// Usage: smallcheck.exe [font...]   (default: MonoLisaCode, Cascadia Mono, Consolas - those installed)
// For each font, writes smallcheck-<font>.png (1:1) and smallcheck-<font>-zoom.png (1 to 8 pt, x4), and the
// sharpness table to smallcheck.txt. A window shows the text for a minute or two: leave it uncovered.
//
// Sharpness = sum(c^2) / sum(c) over all subpixels, c the ink coverage (0 white .. 1 black): the average
// coverage of the ink weighted by itself. Solid stems on whole pixels give ~100%, a stem blurred over two
// half covered pixels 50%. Higher is crisper; the images show the rest (shapes, spacing, legibility).
#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <wincodec.h>
#include <cstdio>
#include <cstdarg>
#include <cwchar>
#include <cmath>
#include <string>
#include <vector>
#include <algorithm>
#include "Scintilla.h"

extern "C" int Scintilla_RegisterClasses(void *hInstance);

static FILE *g_out = nullptr;
static void out(const wchar_t *fmt, ...) {
	va_list ap; va_start(ap, fmt);
	wchar_t buf[4096]; vswprintf(buf, 4096, fmt, ap); va_end(ap);
	fputws(buf, stdout); fflush(stdout);
	if (g_out) fputws(buf, g_out);
}
static std::string utf8(const std::wstring &w) {
	const int n = WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
	std::string s(n, 0); WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, s.data(), n, nullptr, nullptr);
	s.resize(n - 1); return s;
}

static const char *const g_line1 = "int main(void) { return 0x1F; } // 0Oo1lI|";
static const char *const g_line2 = "The quick brown fox jumps over the lazy dog";
static const char *const g_zoomPart = "int main(void) {";

struct Config { const wchar_t *name; int technology; int renderingMode; };
static const Config g_configs[] = {
	{ L"GDI", SC_TECHNOLOGY_DEFAULT, SC_FONTRENDERING_DEFAULT },
	{ L"Automatic", SC_TECHNOLOGY_DIRECTWRITE, SC_FONTRENDERING_DEFAULT },
	{ L"Natural", SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_NATURAL },
	{ L"Symmetric", SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_NATURALSYMMETRIC },
	{ L"GDI-classic", SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_GDICLASSIC },
	{ L"Adaptive", SC_TECHNOLOGY_DIRECTWRITE, SC_RENDERINGMODE_ADAPTIVE },
};
constexpr int configCount = sizeof(g_configs) / sizeof(g_configs[0]);
static const int g_sizes[] = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12 };
constexpr int sizeCount = sizeof(g_sizes) / sizeof(g_sizes[0]);

struct Image {
	int w = 0, h = 0;
	std::vector<unsigned char> bgr;	// top-down, 3 bytes per pixel, stride w*3
	unsigned char *at(int x, int y) { return &bgr[(static_cast<size_t>(y) * w + x) * 3]; }
};
struct Cell { Image image; double sharpness = 0; double ink = 0; double advance = 0; long width = 0, zoomWidth = 0; int lineHeight = 0; };

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
static Image captureClient() {
	Image img;
	RECT rc; ::GetClientRect(g_sci, &rc);
	POINT pt{0, 0}; ::ClientToScreen(g_sci, &pt);
	img.w = rc.right; img.h = rc.bottom; img.bgr.resize(static_cast<size_t>(img.w) * img.h * 3);
	HDC screen = ::GetDC(nullptr);
	HDC mem = ::CreateCompatibleDC(screen);
	BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader); bi.bmiHeader.biWidth = img.w; bi.bmiHeader.biHeight = -img.h;
	bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
	void *bits = nullptr;
	HBITMAP bmp = ::CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	HGDIOBJ old = ::SelectObject(mem, bmp);
	::BitBlt(mem, 0, 0, img.w, img.h, screen, pt.x, pt.y, SRCCOPY);
	::GdiFlush();
	const unsigned char *p = static_cast<const unsigned char *>(bits);
	for (size_t i = 0; i < static_cast<size_t>(img.w) * img.h; ++i) {
		img.bgr[i * 3] = p[i * 4]; img.bgr[i * 3 + 1] = p[i * 4 + 1]; img.bgr[i * 3 + 2] = p[i * 4 + 2];
	}
	::SelectObject(mem, old); ::DeleteObject(bmp); ::DeleteDC(mem); ::ReleaseDC(nullptr, screen);
	return img;
}
static Cell draw(const Config &c, const std::wstring &face, int points) {
	sci(SCI_SETTECHNOLOGY, c.technology);
	sci(SCI_SETFONTRENDERINGPARAMETER, SC_FONTRENDERING_RENDERINGMODE, c.renderingMode);
	const std::string f = utf8(face);
	sci(SCI_STYLESETFONT, STYLE_DEFAULT, reinterpret_cast<sptr_t>(f.c_str()));
	sci(SCI_STYLESETSIZE, STYLE_DEFAULT, points);
	sci(SCI_STYLECLEARALL);
	::InvalidateRect(g_sci, nullptr, TRUE); ::UpdateWindow(g_sci); pump(200);
	Cell cell;
	cell.image = captureClient();
	double sum = 0, sum2 = 0;
	for (const unsigned char v : cell.image.bgr) {
		const double cov = 1.0 - v / 255.0;
		sum += cov; sum2 += cov * cov;
	}
	cell.ink = sum / 3;
	cell.sharpness = sum > 0 ? sum2 / sum : 0;
	cell.width = static_cast<long>(sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>(g_line2)));
	cell.width = std::max(cell.width, static_cast<long>(sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>(g_line1))));
	cell.zoomWidth = static_cast<long>(sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>(g_zoomPart)));
	cell.lineHeight = static_cast<int>(sci(SCI_TEXTHEIGHT, 0));
	cell.advance = sci(SCI_TEXTWIDTH, STYLE_DEFAULT, reinterpret_cast<sptr_t>("MMMMMMMMMMMMMMMMMMMM")) / 20.0;
	return cell;
}

// ---- sheets
static void label(Image &img, int x, int y, const std::wstring &text, int height) {
	BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader); bi.bmiHeader.biWidth = img.w; bi.bmiHeader.biHeight = -img.h;
	bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 24; bi.bmiHeader.biCompression = BI_RGB;
	const int stride = ((img.w * 3 + 3) & ~3);
	void *bits = nullptr;
	HDC mem = ::CreateCompatibleDC(nullptr);
	HBITMAP bmp = ::CreateDIBSection(mem, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	for (int r = 0; r < img.h; ++r) memcpy(static_cast<unsigned char *>(bits) + r * stride, img.at(0, r), img.w * 3);
	HGDIOBJ old = ::SelectObject(mem, bmp);
	HFONT font = ::CreateFontW(-height, 0, 0, 0, FW_BOLD, 0, 0, 0, DEFAULT_CHARSET, 0, 0, ANTIALIASED_QUALITY, 0, L"Segoe UI");
	HGDIOBJ oldFont = ::SelectObject(mem, font);
	::SetBkMode(mem, TRANSPARENT); ::SetTextColor(mem, RGB(0, 90, 170));
	::TextOutW(mem, x, y, text.c_str(), static_cast<int>(text.size()));
	::GdiFlush();
	for (int r = 0; r < img.h; ++r) memcpy(img.at(0, r), static_cast<unsigned char *>(bits) + r * stride, img.w * 3);
	::SelectObject(mem, oldFont); ::DeleteObject(font); ::SelectObject(mem, old); ::DeleteObject(bmp); ::DeleteDC(mem);
}
static void blit(Image &dst, int dx, int dy, Image &src, int sw, int sh, int scale) {
	for (int y = 0; y < sh * scale; ++y) for (int x = 0; x < sw * scale; ++x) {
		const int tx = dx + x, ty = dy + y, sx = x / scale, sy = y / scale;
		if (tx < 0 || ty < 0 || tx >= dst.w || ty >= dst.h || sx >= src.w || sy >= src.h) continue;
		memcpy(dst.at(tx, ty), src.at(sx, sy), 3);
	}
}
static bool savePng(Image &img, const std::wstring &path) {
	IWICImagingFactory *factory = nullptr;
	if (FAILED(CoCreateInstance(CLSID_WICImagingFactory, nullptr, CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&factory)))) return false;
	bool ok = false;
	IWICStream *stream = nullptr; IWICBitmapEncoder *encoder = nullptr; IWICBitmapFrameEncode *frame = nullptr;
	if (SUCCEEDED(factory->CreateStream(&stream)) && SUCCEEDED(stream->InitializeFromFilename(path.c_str(), GENERIC_WRITE)) &&
		SUCCEEDED(factory->CreateEncoder(GUID_ContainerFormatPng, nullptr, &encoder)) &&
		SUCCEEDED(encoder->Initialize(stream, WICBitmapEncoderNoCache)) && SUCCEEDED(encoder->CreateNewFrame(&frame, nullptr)) &&
		SUCCEEDED(frame->Initialize(nullptr)) && SUCCEEDED(frame->SetSize(img.w, img.h))) {
		WICPixelFormatGUID format = GUID_WICPixelFormat24bppBGR;
		if (SUCCEEDED(frame->SetPixelFormat(&format)) && IsEqualGUID(format, GUID_WICPixelFormat24bppBGR) &&
			SUCCEEDED(frame->WritePixels(img.h, img.w * 3, static_cast<UINT>(img.bgr.size()), img.bgr.data())) &&
			SUCCEEDED(frame->Commit()) && SUCCEEDED(encoder->Commit()))
			ok = true;
	}
	if (frame) frame->Release();
	if (encoder) encoder->Release();
	if (stream) stream->Release();
	factory->Release();
	return ok;
}

static std::vector<std::wstring> g_installed;
static int CALLBACK enumFaces(const LOGFONTW *lf, const TEXTMETRICW *, DWORD, LPARAM) {
	g_installed.push_back(lf->lfFaceName);
	return 1;
}
static bool installed(const std::wstring &face) {
	for (const auto &f : g_installed) if (_wcsicmp(f.c_str(), face.c_str()) == 0) return true;
	return false;
}

int wmain(int argc, wchar_t **argv) {
	using SetCtx = BOOL(WINAPI *)(HANDLE);
	if (auto set = reinterpret_cast<SetCtx>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "SetProcessDpiAwarenessContext"))))
		set(reinterpret_cast<HANDLE>(-4));
	else
		SetProcessDPIAware();
	CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
	wchar_t path[MAX_PATH]; GetModuleFileNameW(nullptr, path, MAX_PATH);
	std::wstring dir(path); dir = dir.substr(0, dir.find_last_of(L"\\/") + 1);
	g_out = _wfopen((dir + L"smallcheck.txt").c_str(), L"w, ccs=UTF-8");

	HDC hdc = ::GetDC(nullptr);
	LOGFONTW lf{}; lf.lfCharSet = DEFAULT_CHARSET;
	::EnumFontFamiliesExW(hdc, &lf, enumFaces, 0, 0);
	::ReleaseDC(nullptr, hdc);
	std::vector<std::wstring> faces;
	for (int i = 1; i < argc; ++i) faces.push_back(argv[i]);
	if (faces.empty()) for (const wchar_t *f : { L"MonoLisaCode", L"Cascadia Mono", L"Consolas" }) if (installed(f)) faces.push_back(f);

	OSVERSIONINFOW ov{ sizeof(ov) };
	using RtlGetVersionSig = LONG(WINAPI *)(OSVERSIONINFOW *);
	if (auto rtl = reinterpret_cast<RtlGetVersionSig>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion")))) rtl(&ov);

	HINSTANCE hInst = ::GetModuleHandle(nullptr);
	Scintilla_RegisterClasses(hInst);
	g_top = ::CreateWindowExW(WS_EX_TOPMOST | WS_EX_TOOLWINDOW, L"STATIC", L"smallcheck", WS_POPUP | WS_BORDER | WS_VISIBLE,
		40, 40, 800, 100, nullptr, nullptr, hInst, nullptr);
	g_sci = ::CreateWindowExW(0, L"Scintilla", L"", WS_CHILD | WS_VISIBLE, 0, 0, 800, 100, g_top, nullptr, hInst, nullptr);
	using GetDpiForWindowSig = UINT(WINAPI *)(HWND);
	if (auto gd = reinterpret_cast<GetDpiForWindowSig>(reinterpret_cast<void *>(GetProcAddress(GetModuleHandleW(L"user32.dll"), "GetDpiForWindow"))))
		g_dpi = static_cast<int>(gd(g_sci));
	const int clientW = ::MulDiv(760, g_dpi, 96), clientH = ::MulDiv(64, g_dpi, 96);
	::SetWindowPos(g_top, nullptr, 0, 0, clientW + 2, clientH + 2, SWP_NOMOVE | SWP_NOZORDER);
	::SetWindowPos(g_sci, nullptr, 0, 0, clientW, clientH, SWP_NOMOVE | SWP_NOZORDER);

	BOOL smoothing = FALSE; UINT smoothingType = 0;
	SystemParametersInfoW(SPI_GETFONTSMOOTHING, 0, &smoothing, 0); SystemParametersInfoW(SPI_GETFONTSMOOTHINGTYPE, 0, &smoothingType, 0);
	const bool clearType = smoothing && smoothingType == FE_FONTSMOOTHINGCLEARTYPE;
	out(L"smallcheck - Windows %lu.%lu.%lu - %d DPI (%d%%) - font smoothing %ls\n", ov.dwMajorVersion, ov.dwMinorVersion, ov.dwBuildNumber,
		g_dpi, ::MulDiv(100, g_dpi, 96), !smoothing ? L"off" : clearType ? L"ClearType" : L"standard");
	out(L"Sharpness %% (higher is crisper; ink-weighted coverage) and [character width in pixels]\n");
	out(L"Adaptive: Natural up to 20 px, the monitor's mode above.\n");

	sci(SCI_SETMARGINWIDTHN, 0, 0); sci(SCI_SETMARGINWIDTHN, 1, 0); sci(SCI_SETMARGINWIDTHN, 2, 0);
	sci(SCI_SETCARETSTYLE, CARETSTYLE_INVISIBLE);
	sci(SCI_SETHSCROLLBAR, 0); sci(SCI_SETVSCROLLBAR, 0);
	const int pad = ::MulDiv(4, g_dpi, 96);
	sci(SCI_SETMARGINLEFT, 0, pad);
	// as Notepad++ with "Follow Windows" antialiasing
	std::string text = std::string(g_line1) + "\n" + g_line2 + "\n";
	sci(SCI_SETTEXT, 0, reinterpret_cast<sptr_t>(text.c_str()));

	for (const auto &face : faces) {
		std::vector<std::vector<Cell>> cells(sizeCount, std::vector<Cell>(configCount));
		for (int c = 0; c < configCount; ++c) {
			sci(SCI_SETFONTQUALITY, g_configs[c].technology == SC_TECHNOLOGY_DEFAULT ? SC_EFF_QUALITY_DEFAULT :
				!smoothing ? SC_EFF_QUALITY_NON_ANTIALIASED : clearType ? SC_EFF_QUALITY_LCD_OPTIMIZED : SC_EFF_QUALITY_ANTIALIASED);
			// a first drawing for the switch of technology or mode (its render target is created again)
			draw(g_configs[c], face, g_sizes[sizeCount - 1]);
			pump(300);
			for (int s = 0; s < sizeCount; ++s) cells[s][c] = draw(g_configs[c], face, g_sizes[s]);
		}
		// table
		out(L"\n%ls\n  size  px ", face.c_str());
		for (const auto &c : g_configs) out(L" %-15ls", c.name);
		out(L"\n");
		for (int s = 0; s < sizeCount; ++s) {
			out(L"  %2dpt %4.1f ", g_sizes[s], g_sizes[s] * g_dpi / 72.0);	// em size in pixels
			int best = 0;
			for (int c = 0; c < configCount; ++c) if (cells[s][c].sharpness > cells[s][best].sharpness) best = c;
			for (int c = 0; c < configCount; ++c) {
				wchar_t b[64]; swprintf(b, 64, L"%4.1f%%%ls [%.2f]", cells[s][c].sharpness * 100, c == best ? L"*" : L" ", cells[s][c].advance);
				out(L" %-15ls", b);
			}
			out(L"\n");
		}
		// 1:1 sheet: rows sizes, columns configurations
		const int labelH = ::MulDiv(14, g_dpi, 96), labelW = ::MulDiv(40, g_dpi, 96);
		int colW = 0;
		std::vector<int> rowH(sizeCount);
		for (int s = 0; s < sizeCount; ++s) for (int c = 0; c < configCount; ++c) {
			colW = std::max(colW, static_cast<int>(cells[s][c].width) + 3 * pad);
			rowH[s] = std::max(rowH[s], 2 * cells[s][c].lineHeight + pad);
		}
		colW = std::min(colW, clientW);
		Image sheet; sheet.w = labelW + configCount * colW; sheet.h = labelH + pad;
		for (int s = 0; s < sizeCount; ++s) sheet.h += rowH[s];
		sheet.bgr.assign(static_cast<size_t>(sheet.w) * sheet.h * 3, 255);
		int y = labelH + pad;
		for (int s = 0; s < sizeCount; ++s) {
			for (int c = 0; c < configCount; ++c)
				blit(sheet, labelW + c * colW, y, cells[s][c].image, colW - pad, std::min(rowH[s], cells[s][c].image.h), 1);
			label(sheet, 2, y, std::to_wstring(g_sizes[s]) + L"pt", labelH - 2);
			y += rowH[s];
		}
		for (int c = 0; c < configCount; ++c) label(sheet, labelW + c * colW + pad, 0, g_configs[c].name, labelH - 2);
		// x4 sheet of 1 to 8 pt
		constexpr int zoom = 4;
		constexpr int zoomSizes = 8;	// 1 to 8 pt
		int zColW = 0, zRowsH = 0;
		std::vector<int> zRowH(zoomSizes);
		for (int s = 0; s < zoomSizes; ++s) {
			for (int c = 0; c < configCount; ++c) {
				zColW = std::max(zColW, static_cast<int>(cells[s][c].zoomWidth) + 2 * pad);
				zRowH[s] = std::max(zRowH[s], cells[s][c].lineHeight + 1);
			}
			zRowsH += zRowH[s] * zoom + pad;
		}
		Image zsheet; zsheet.w = labelW + configCount * (zColW * zoom + pad); zsheet.h = labelH + pad + zRowsH;
		zsheet.bgr.assign(static_cast<size_t>(zsheet.w) * zsheet.h * 3, 255);
		y = labelH + pad;
		for (int s = 0; s < zoomSizes; ++s) {
			for (int c = 0; c < configCount; ++c)
				blit(zsheet, labelW + c * (zColW * zoom + pad), y, cells[s][c].image, zColW, std::min(zRowH[s], cells[s][c].lineHeight), zoom);
			label(zsheet, 2, y, std::to_wstring(g_sizes[s]) + L"pt", labelH - 2);
			y += zRowH[s] * zoom + pad;
		}
		for (int c = 0; c < configCount; ++c) label(zsheet, labelW + c * (zColW * zoom + pad) + pad, 0, g_configs[c].name, labelH - 2);
		std::wstring name = face;
		std::replace(name.begin(), name.end(), L' ', L'_');
		const bool ok1 = savePng(sheet, dir + L"smallcheck-" + name + L".png");
		const bool ok2 = savePng(zsheet, dir + L"smallcheck-" + name + L"-zoom.png");
		out(L"  images: smallcheck-%ls.png, smallcheck-%ls-zoom.png%ls\n", name.c_str(), name.c_str(), ok1 && ok2 ? L"" : L" (NOT WRITTEN)");
	}
	::DestroyWindow(g_top);
	out(L"\n* the sharpest for the size. Sharpness isn't everything: compare the images for shapes and spacing.\n");
	if (g_out) fclose(g_out);
	CoUninitialize();
	return 0;
}
