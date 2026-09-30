// dpidrive.cpp - drives a Notepad++ instance under Wine for the per-monitor DPI awareness (Stage 1) checks.
//
// Launch with an isolated settings dir, place the main window at (0,0) 1024x640, capture it, report the
// DPI awareness of the main window and the geometry of the frame (rebar, tabs, status bar, editors, splitters,
// docking containers) and the editor margins; open Function List + Document Map (docking), clone the document
// to the other view (sub splitter), capture; send synthetic WM_DPICHANGED (lParam 0: the RECT pointer is not
// marshalled between processes) to the main window with another DPI and back, check it survives and that the
// layout comes back; open Preferences > MISC., read/set the "Per-monitor DPI awareness" checkbox (6367);
// close cleanly.
//
// Output lines: RESULT <tab> dpi_<tag> <tab> name <tab> PASS|FAIL|SKIP|INFO|WARN|CRASH <tab> detail

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
#include <cstdio>
#include <cstdarg>
#include <cstdint>
#include <string>
#include <vector>
#include <unordered_map>
#include <algorithm>

namespace {

constexpr UINT IDM_SETTING_PREFERENCE = 48011;
constexpr UINT IDM_VIEW_DOC_MAP = 44080;
constexpr UINT IDM_VIEW_FUNC_LIST = 44084;
constexpr UINT IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002;
constexpr int IDC_BUTTON_CLOSE = 6001;
constexpr int IDC_LIST_DLGTITLE = 6002;
constexpr int IDC_CHECK_PERMONITORDPIAWARENESS = 6367;
constexpr int IDC_CHECK_ALOOWSIMLINKFAW = 6366;
constexpr UINT WM_DPICHANGED_ = 0x02E0;
constexpr UINT WM_DPICHANGED_AFTERPARENT_ = 0x02E3;
constexpr UINT SCI_GETMARGINWIDTHN = 2243;

int g_count[6] = {};
std::string g_out = ".";
std::string g_tag = "run";
bool g_crash = false;

std::string Narrow(const std::wstring &w) {
	if (w.empty())
		return {};
	const int n = ::WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, nullptr, 0, nullptr, nullptr);
	std::string s(n, '\0');
	::WideCharToMultiByte(CP_UTF8, 0, w.c_str(), -1, s.data(), n, nullptr, nullptr);
	s.resize(n - 1);
	return s;
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

enum { PASS, FAIL, SKIP, INFO, WARN, CRASH };
void report(int st, const char *name, const char *fmt, ...) {
	static const char *names[] = {"PASS", "FAIL", "SKIP", "INFO", "WARN", "CRASH"};
	char buf[16384];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	for (char *p = buf; *p; ++p)
		if (*p == '\t' || *p == '\n' || *p == '\r')
			*p = ' ';
	printf("RESULT\tdpi_%s\t%s\t%s\t%s\n", g_tag.c_str(), name, names[st], buf);
	fflush(stdout);
	g_count[st]++;
	if (st == CRASH)
		g_crash = true;
}
void check(bool ok, const char *name, const char *fmt, ...) {
	char buf[16384];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	report(ok ? PASS : FAIL, name, "%s", buf);
}

struct Img {
	int w = 0, h = 0;
	std::vector<uint32_t> px;
};

bool grabRectOnce(const RECT &rc, Img &img) {
	const int w = rc.right - rc.left, h = rc.bottom - rc.top;
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
		ok = ::BitBlt(mem, 0, 0, w, h, screen, rc.left, rc.top, SRCCOPY | CAPTUREBLT) != FALSE;
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

bool grabRect(const RECT &rc, Img &img) {
	bool ok = grabRectOnce(rc, img);
	for (int i = 0; i < 20 && ok; ++i) {
		::Sleep(150);
		Img again;
		ok = grabRectOnce(rc, again);
		const bool same = again.px == img.px;
		img = std::move(again);
		if (same)
			break;
	}
	return ok;
}

bool writeBMP(const std::string &name, const Img &img) {
	const std::string path = g_out + "/" + name;
	FILE *f = fopen(path.c_str(), "wb");
	if (!f)
		return false;
	const int rowBytes = ((img.w * 3 + 3) / 4) * 4;
	BITMAPFILEHEADER fh{};
	fh.bfType = 0x4D42;
	fh.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
	fh.bfSize = fh.bfOffBits + static_cast<DWORD>(rowBytes) * img.h;
	BITMAPINFOHEADER ih{};
	ih.biSize = sizeof(ih);
	ih.biWidth = img.w;
	ih.biHeight = img.h;
	ih.biPlanes = 1;
	ih.biBitCount = 24;
	ih.biCompression = BI_RGB;
	fwrite(&fh, sizeof(fh), 1, f);
	fwrite(&ih, sizeof(ih), 1, f);
	std::vector<unsigned char> row(rowBytes, 0);
	for (int y = img.h - 1; y >= 0; --y) {
		for (int x = 0; x < img.w; ++x) {
			const uint32_t p = img.px[static_cast<size_t>(y) * img.w + x];
			row[x * 3] = p & 0xFF;
			row[x * 3 + 1] = (p >> 8) & 0xFF;
			row[x * 3 + 2] = (p >> 16) & 0xFF;
		}
		fwrite(row.data(), 1, row.size(), f);
	}
	fclose(f);
	return true;
}

long nonBg(const Img &img) {
	std::unordered_map<uint32_t, long> counts;
	for (uint32_t p : img.px)
		counts[p]++;
	long best = 0;
	for (const auto &kv : counts)
		best = std::max(best, kv.second);
	return static_cast<long>(img.px.size()) - best;
}

Img shot(HWND h, const std::string &file) {
	RECT rc{};
	::GetWindowRect(h, &rc);
	Img img;
	grabRect(rc, img);
	if (!file.empty())
		writeBMP(file + ".bmp", img);
	return img;
}

// differing pixels and their bounding box
std::string diff(const Img &a, const Img &b) {
	if (a.w != b.w || a.h != b.h)
		return "size differs " + std::to_string(a.w) + "x" + std::to_string(a.h) + " vs " + std::to_string(b.w) + "x" + std::to_string(b.h);
	long n = 0;
	int x0 = a.w, y0 = a.h, x1 = -1, y1 = -1;
	for (int y = 0; y < a.h; ++y)
		for (int x = 0; x < a.w; ++x)
			if (a.px[static_cast<size_t>(y) * a.w + x] != b.px[static_cast<size_t>(y) * a.w + x]) {
				++n;
				x0 = std::min(x0, x);
				y0 = std::min(y0, y);
				x1 = std::max(x1, x);
				y1 = std::max(y1, y);
			}
	char buf[160];
	if (n)
		snprintf(buf, sizeof(buf), "%ld px differ, bbox (%d,%d)-(%d,%d)", n, x0, y0, x1, y1);
	else
		snprintf(buf, sizeof(buf), "identical");
	return buf;
}

PROCESS_INFORMATION g_pi{};
HWND g_main = nullptr;

bool alive() {
	return g_pi.hProcess && ::WaitForSingleObject(g_pi.hProcess, 0) == WAIT_TIMEOUT;
}
bool responsive(HWND h, UINT ms = 10000) {
	DWORD_PTR r = 0;
	return ::SendMessageTimeoutW(h, WM_NULL, 0, 0, SMTO_ABORTIFHUNG | SMTO_BLOCK, ms, &r) != 0;
}
std::wstring className(HWND h) {
	wchar_t b[256] = {};
	::GetClassNameW(h, b, 255);
	return b;
}
std::wstring windowText(HWND h) {
	wchar_t b[1024] = {};
	DWORD_PTR r = 0;
	::SendMessageTimeoutW(h, WM_GETTEXT, 1023, reinterpret_cast<LPARAM>(b), SMTO_ABORTIFHUNG, 3000, &r);
	return b;
}

struct TopFind {
	DWORD pid;
	std::vector<HWND> wnds;
};
BOOL CALLBACK EnumTop(HWND h, LPARAM lp) {
	auto *f = reinterpret_cast<TopFind *>(lp);
	DWORD pid = 0;
	::GetWindowThreadProcessId(h, &pid);
	if (pid == f->pid && ::IsWindowVisible(h))
		f->wnds.push_back(h);
	return TRUE;
}
std::vector<HWND> processTopWindows() {
	TopFind f{g_pi.dwProcessId, {}};
	::EnumWindows(EnumTop, reinterpret_cast<LPARAM>(&f));
	return f.wnds;
}
HWND waitFor(DWORD timeoutMs, bool (*pred)(HWND)) {
	const DWORD end = ::GetTickCount() + timeoutMs;
	do {
		for (HWND h : processTopWindows())
			if (pred(h))
				return h;
		if (!alive())
			return nullptr;
		::Sleep(200);
	} while (static_cast<LONG>(::GetTickCount() - end) < 0);
	return nullptr;
}
bool isMain(HWND h) {
	return className(h) == L"Notepad++";
}
bool isPrefs(HWND h) {
	return className(h) == L"#32770" && ::GetDlgItem(h, IDC_LIST_DLGTITLE) != nullptr;
}

void reportStrayDialogs(const char *when) {
	int n = 0;
	for (HWND h : processTopWindows()) {
		if (isMain(h) || isPrefs(h) || className(h) != L"#32770")
			continue;
		RECT r{};
		::GetWindowRect(h, &r);
		std::wstring texts;
		for (HWND c = ::GetWindow(h, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT)) {
			const std::wstring t = windowText(c);
			if (!t.empty())
				texts += L" | " + t;
		}
		char nm[64];
		snprintf(nm, sizeof(nm), "top_dialog_%s_%d", when, n++);
		report(INFO, nm, "title=\"%s\" rect=(%ld,%ld)-(%ld,%ld) texts=\"%s\"", Narrow(windowText(h)).c_str(), r.left, r.top, r.right, r.bottom,
			Narrow(texts).c_str());
	}
}

struct ChildFind {
	HWND parent;
	std::vector<HWND> out;
	const wchar_t *cls;
	bool directOnly;
};
BOOL CALLBACK EnumKids(HWND h, LPARAM lp) {
	auto *f = reinterpret_cast<ChildFind *>(lp);
	if ((!f->directOnly || ::GetParent(h) == f->parent) && (!f->cls || className(h) == f->cls))
		f->out.push_back(h);
	return TRUE;
}
std::vector<HWND> children(HWND parent, const wchar_t *cls, bool directOnly) {
	ChildFind f{parent, {}, cls, directOnly};
	::EnumChildWindows(parent, EnumKids, reinterpret_cast<LPARAM>(&f));
	return f.out;
}

HWND mainEditor() {
	HWND best = nullptr;
	long bestArea = 0;
	for (HWND h : children(g_main, L"Scintilla", true)) {
		if (!::IsWindowVisible(h))
			continue;
		RECT r{};
		::GetWindowRect(h, &r);
		const long area = (r.right - r.left) * (r.bottom - r.top);
		if (area > bestArea) {
			bestArea = area;
			best = h;
		}
	}
	return best;
}

long long sci(HWND h, UINT m, WPARAM w = 0) {
	DWORD_PTR r = 0;
	if (!::SendMessageTimeoutW(h, m, w, 0, SMTO_ABORTIFHUNG, 3000, &r))
		return -999;
	return static_cast<long long>(static_cast<LONG_PTR>(r));
}
std::string margins(HWND h) {
	char b[128];
	snprintf(b, sizeof(b), "margins(ln,sym,chg,fold)=%lld,%lld,%lld,%lld", sci(h, SCI_GETMARGINWIDTHN, 0), sci(h, SCI_GETMARGINWIDTHN, 1),
		sci(h, SCI_GETMARGINWIDTHN, 2), sci(h, SCI_GETMARGINWIDTHN, 3));
	return b;
}

// Geometry of the visible direct children of the main window (client coordinates), sorted
std::string layout() {
	std::vector<std::string> items;
	for (HWND h : children(g_main, nullptr, true)) {
		if (!::IsWindowVisible(h))
			continue;
		RECT r{};
		::GetWindowRect(h, &r);
		::MapWindowPoints(nullptr, g_main, reinterpret_cast<POINT *>(&r), 2);
		char b[256];
		snprintf(b, sizeof(b), "%s[%ld,%ld %ldx%ld]", Narrow(className(h)).c_str(), r.left, r.top, r.right - r.left, r.bottom - r.top);
		items.emplace_back(b);
	}
	std::sort(items.begin(), items.end());
	std::string s;
	for (const auto &i : items)
		s += i + " ";
	return s;
}

void settle(DWORD ms = 400) {
	::Sleep(ms);
	if (g_main)
		responsive(g_main, 5000);
}

using fnGetWindowDpiAwarenessContext = DPI_AWARENESS_CONTEXT(WINAPI *)(HWND);
using fnGetAwarenessFromDpiAwarenessContext = int(WINAPI *)(DPI_AWARENESS_CONTEXT);
using fnGetDpiForWindow = UINT(WINAPI *)(HWND);
using fnAreDpiAwarenessContextsEqual = BOOL(WINAPI *)(DPI_AWARENESS_CONTEXT, DPI_AWARENESS_CONTEXT);

std::string awareness(HWND h, bool *isPerMonitor = nullptr) {
	HMODULE u = ::GetModuleHandleW(L"user32.dll");
	auto gwdac = reinterpret_cast<fnGetWindowDpiAwarenessContext>(reinterpret_cast<void *>(::GetProcAddress(u, "GetWindowDpiAwarenessContext")));
	auto gafdac = reinterpret_cast<fnGetAwarenessFromDpiAwarenessContext>(reinterpret_cast<void *>(::GetProcAddress(u, "GetAwarenessFromDpiAwarenessContext")));
	auto gdfw = reinterpret_cast<fnGetDpiForWindow>(reinterpret_cast<void *>(::GetProcAddress(u, "GetDpiForWindow")));
	auto adace = reinterpret_cast<fnAreDpiAwarenessContextsEqual>(reinterpret_cast<void *>(::GetProcAddress(u, "AreDpiAwarenessContextsEqual")));
	if (!gwdac || !gafdac || !gdfw)
		return "no DPI awareness API";
	DPI_AWARENESS_CONTEXT ctx = gwdac(h);
	const int aw = gafdac(ctx);
	const bool isV2 = adace && adace(ctx, reinterpret_cast<DPI_AWARENESS_CONTEXT>(-4));
	if (isPerMonitor)
		*isPerMonitor = (aw == 2);
	char b[160];
	snprintf(b, sizeof(b), "awareness=%d(%s)%s GetDpiForWindow=%u", aw, aw == 0 ? "unaware" : aw == 1 ? "system" : aw == 2 ? "per-monitor" : "?",
		isV2 ? " V2" : "", gdfw(h));
	return b;
}

}	// namespace

int main(int argc, char **argv) {
	std::string exe, settings, file;
	int setPmv2 = -1, expectPmv2 = -1, synthDpi = 0;
	bool dock = true;
	for (int i = 1; i < argc; ++i) {
		const std::string a = argv[i];
		auto next = [&]() -> std::string { return (i + 1 < argc) ? argv[++i] : std::string(); };
		if (a == "--exe") exe = next();
		else if (a == "--settings") settings = next();
		else if (a == "--file") file = next();
		else if (a == "--out") g_out = next();
		else if (a == "--tag") g_tag = next();
		else if (a == "--set") setPmv2 = atoi(next().c_str());
		else if (a == "--expect") expectPmv2 = atoi(next().c_str());
		else if (a == "--synthetic") synthDpi = atoi(next().c_str());
		else if (a == "--no-dock") dock = false;
		else {
			fprintf(stderr, "usage: dpidrive.exe --exe WINPATH --settings WINDIR [--file WINPATH] --out DIR [--tag T] [--set 0|1] [--expect 0|1] [--synthetic DPI] [--no-dock]\n");
			return 64;
		}
	}
	::SetProcessDPIAware();

	std::wstring cmd = L"\"" + Widen(exe) + L"\" -multiInst -nosession -noPlugin";
	if (!settings.empty())
		cmd += L" \"-settingsDir=" + Widen(settings) + L"\"";
	if (!file.empty())
		cmd += L" \"" + Widen(file) + L"\"";
	std::wstring dir = Widen(exe);
	dir = dir.substr(0, dir.find_last_of(L"\\/"));
	STARTUPINFOW si{};
	si.cb = sizeof(si);
	std::vector<wchar_t> cmdBuf(cmd.begin(), cmd.end());
	cmdBuf.push_back(0);
	const BOOL launched = ::CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE, 0, nullptr, dir.c_str(), &si, &g_pi);
	check(launched, "launch", "%s", Narrow(cmd).c_str());
	if (!launched)
		return 2;
	::WaitForInputIdle(g_pi.hProcess, 30000);
	g_main = waitFor(60000, isMain);
	if (!g_main) {
		report(CRASH, "main_window", "no main window (process %s)", alive() ? "alive" : "exited");
		if (alive())
			::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	settle(1500);
	reportStrayDialogs("startup");

	bool isPerMonitor = false;
	const std::string aw = awareness(g_main, &isPerMonitor);
	report(INFO, "main_awareness", "%s; driver %s", aw.c_str(), awareness(::GetDesktopWindow()).c_str());
	// Wine 9.0 reports every window of a DPI aware process as per-monitor aware, and does not know the V2 context: INFO only
	(void)isPerMonitor;

	::SetWindowPos(g_main, HWND_TOP, 0, 0, 1024, 640, SWP_SHOWWINDOW);
	settle(1000);
	RECT wr{}, cr{};
	::GetWindowRect(g_main, &wr);
	::GetClientRect(g_main, &cr);
	HWND editor = mainEditor();
	report(INFO, "layout_start", "window=(%ld,%ld)-(%ld,%ld) client=%ldx%ld; %s; editor %s", wr.left, wr.top, wr.right, wr.bottom, cr.right, cr.bottom,
		layout().c_str(), margins(editor).c_str());
	Img start = shot(g_main, g_tag + "_1_main");
	check(nonBg(start) > 2000, "main_capture", "%dx%d non-background %ld", start.w, start.h, nonBg(start));

	Img docked;
	if (dock) {
		// clone to the other view (sub splitter), Function List + Document Map (docking)
		::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_CLONE_TO_ANOTHER_VIEW, 0);
		settle(800);
		::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_FUNC_LIST, 0);
		settle(1500);
		::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_DOC_MAP, 0);
		settle(2000);
		const bool ok = alive() && responsive(g_main);
		std::vector<HWND> sc = children(g_main, L"Scintilla", false);
		std::string scis;
		for (HWND h : sc)
			if (::IsWindowVisible(h)) {
				RECT r{};
				::GetWindowRect(h, &r);
				char b[200];
				snprintf(b, sizeof(b), "[%ldx%ld %s] ", r.right - r.left, r.bottom - r.top, margins(h).c_str());
				scis += b;
			}
		check(ok, "docking", "clone + Function List + Document Map: process %s; %s; visible Scintillas: %s", ok ? "alive and responsive" : "NOT OK",
			layout().c_str(), scis.c_str());
		std::string tops;
		for (HWND h : processTopWindows()) {
			if (h == g_main)
				continue;
			RECT r{};
			::GetWindowRect(h, &r);
			char b[300];
			snprintf(b, sizeof(b), "%s \"%s\" (%ld,%ld %ldx%ld); ", Narrow(className(h)).c_str(), Narrow(windowText(h)).c_str(), r.left, r.top,
				r.right - r.left, r.bottom - r.top);
			tops += b;
		}
		report(INFO, "floating_windows", "other visible top-level windows: %s", tops.empty() ? "none" : tops.c_str());
		if (!ok) {
			report(CRASH, "docking", "died or hung");
			return 2;
		}
		reportStrayDialogs("docking");
		docked = shot(g_main, g_tag + "_2_docked");
	}

	if (synthDpi > 0) {
		// synthetic WM_DPICHANGED (Wine never sends it, and GetDpiForWindow keeps returning the Wine DPI)
		HMODULE u = ::GetModuleHandleW(L"user32.dll");
		auto gdfw = reinterpret_cast<fnGetDpiForWindow>(reinterpret_cast<void *>(::GetProcAddress(u, "GetDpiForWindow")));
		const UINT dpi0 = gdfw ? gdfw(g_main) : 96;
		DWORD_PTR r = 0;
		::SendMessageTimeoutW(g_main, WM_DPICHANGED_, MAKEWPARAM(synthDpi, synthDpi), 0, SMTO_ABORTIFHUNG, 10000, &r);
		settle(1500);
		bool ok = alive() && responsive(g_main);
		check(ok, "synthetic_dpichanged_up", "WM_DPICHANGED(%d) lParam=0: process %s; %s; editor %s", synthDpi, ok ? "alive and responsive" : "NOT OK",
			layout().c_str(), margins(editor).c_str());
		if (!ok) {
			report(CRASH, "synthetic_dpichanged_up", "died or hung");
			return 2;
		}
		shot(g_main, g_tag + "_3_synthetic_" + std::to_string(synthDpi));
		// the editors never receive WM_DPICHANGED_AFTERPARENT from a synthetic message: send it to exercise the Scintilla subclass
		for (HWND h : children(g_main, L"Scintilla", false))
			::SendMessageTimeoutW(h, WM_DPICHANGED_AFTERPARENT_, 0, 0, SMTO_ABORTIFHUNG, 5000, &r);
		settle(500);
		ok = alive() && responsive(g_main);
		check(ok, "synthetic_afterparent", "WM_DPICHANGED_AFTERPARENT to all Scintillas: process %s; editor %s", ok ? "alive and responsive" : "NOT OK",
			margins(editor).c_str());
		::SendMessageTimeoutW(g_main, WM_DPICHANGED_, MAKEWPARAM(dpi0, dpi0), 0, SMTO_ABORTIFHUNG, 10000, &r);
		settle(1500);
		ok = alive() && responsive(g_main);
		check(ok, "synthetic_dpichanged_back", "WM_DPICHANGED(%u) lParam=0: process %s; %s; editor %s", dpi0, ok ? "alive and responsive" : "NOT OK",
			layout().c_str(), margins(editor).c_str());
		if (!ok) {
			report(CRASH, "synthetic_dpichanged_back", "died or hung");
			return 2;
		}
		Img back = shot(g_main, g_tag + "_4_synthetic_back");
		report(INFO, "synthetic_roundtrip", "capture after %d and back to %u vs before: %s", synthDpi, dpi0, diff(dock ? docked : start, back).c_str());
	}

	// Preferences > MISC.
	::PostMessageW(g_main, WM_COMMAND, IDM_SETTING_PREFERENCE, 0);
	HWND prefs = waitFor(20000, isPrefs);
	if (!prefs) {
		report(CRASH, "prefs_open", "Preferences dialog did not open (process %s)", alive() ? "alive" : "exited");
		if (alive())
			::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	::SetWindowPos(prefs, HWND_TOP, 0, 0, 0, 0, SWP_NOSIZE | SWP_SHOWWINDOW);
	settle();
	HWND list = ::GetDlgItem(prefs, IDC_LIST_DLGTITLE);
	const LRESULT count = ::SendMessageW(list, LB_GETCOUNT, 0, 0);
	LRESULT misc = -1;
	for (LRESULT i = 0; i < count; ++i) {
		wchar_t buf[512] = {};
		DWORD_PTR r = 0;
		if (::SendMessageTimeoutW(list, LB_GETTEXT, i, reinterpret_cast<LPARAM>(buf), SMTO_ABORTIFHUNG, 3000, &r) && wcscmp(buf, L"MISC.") == 0)
			misc = i;
	}
	if (misc < 0)
		misc = count - 1;
	::SendMessageW(list, LB_SETCURSEL, misc, 0);
	::SendMessageW(prefs, WM_COMMAND, MAKEWPARAM(IDC_LIST_DLGTITLE, LBN_SELCHANGE), reinterpret_cast<LPARAM>(list));
	settle();
	HWND page = nullptr;
	for (HWND h : children(prefs, L"#32770", true))
		if (::IsWindowVisible(h) && ::GetDlgItem(h, IDC_CHECK_ALOOWSIMLINKFAW))
			page = h;
	HWND cb = page ? ::GetDlgItem(page, IDC_CHECK_PERMONITORDPIAWARENESS) : nullptr;
	shot(prefs, g_tag + "_5_prefs_misc");
	if (cb) {
		RECT r{};
		::GetWindowRect(cb, &r);
		::MapWindowPoints(nullptr, page, reinterpret_cast<POINT *>(&r), 2);
		const LRESULT st = ::SendMessageW(cb, BM_GETCHECK, 0, 0);
		report(INFO, "misc_checkbox", "6367 \"%s\" rect=(%ld,%ld)-(%ld,%ld) visible=%d enabled=%d checked=%ld", Narrow(windowText(cb)).c_str(), r.left, r.top,
			r.right, r.bottom, ::IsWindowVisible(cb) ? 1 : 0, ::IsWindowEnabled(cb) ? 1 : 0, static_cast<long>(st));
		if (expectPmv2 >= 0)
			check((st == BST_CHECKED) == (expectPmv2 == 1), "misc_checkbox_state", "checked=%ld expected %d", static_cast<long>(st), expectPmv2);
		if (setPmv2 >= 0) {
			::SendMessageW(cb, BM_SETCHECK, setPmv2 ? BST_CHECKED : BST_UNCHECKED, 0);
			::SendMessageW(page, WM_COMMAND, MAKEWPARAM(IDC_CHECK_PERMONITORDPIAWARENESS, BN_CLICKED), reinterpret_cast<LPARAM>(cb));
			settle();
			report(INFO, "misc_checkbox_set", "set to %d, now checked=%ld", setPmv2, static_cast<long>(::SendMessageW(cb, BM_GETCHECK, 0, 0)));
			shot(prefs, g_tag + "_6_prefs_misc_set");
		}
	} else {
		report(setPmv2 >= 0 || expectPmv2 >= 0 ? FAIL : INFO, "misc_checkbox", "IDC_CHECK_PERMONITORDPIAWARENESS (6367) absent (page %p)", static_cast<void *>(page));
	}
	::PostMessageW(prefs, WM_COMMAND, IDC_BUTTON_CLOSE, 0);
	settle(500);

	if (alive()) {
		::PostMessageW(g_main, WM_CLOSE, 0, 0);
		const DWORD w = ::WaitForSingleObject(g_pi.hProcess, 30000);
		DWORD code = 0;
		::GetExitCodeProcess(g_pi.hProcess, &code);
		if (w != WAIT_OBJECT_0) {
			reportStrayDialogs("exit");
			report(CRASH, "exit", "Notepad++ did not exit within 30 s after WM_CLOSE; terminated");
			::TerminateProcess(g_pi.hProcess, 99);
		} else {
			check(code == 0, "exit", "Notepad++ exited, exit code %lu", code);
		}
	} else {
		report(CRASH, "exit", "Notepad++ was not running any more before the clean close");
	}
	printf("SUMMARY\tpass=%d\tfail=%d\tskip=%d\tinfo=%d\twarn=%d\tcrash=%d\n", g_count[0], g_count[1], g_count[2], g_count[3], g_count[4], g_count[5]);
	return g_crash ? 2 : 0;
}
