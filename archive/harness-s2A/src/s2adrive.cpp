// s2adrive.cpp - drives a Notepad++ instance under Wine for the per-monitor DPI awareness Stage 2 checks of the
// Function List, Folder as Workspace and Project panels.
//
// Launch with an isolated settings dir (config.xml prepared by mksettings.py: panels docked left/right/bottom, a
// FaW root folder, a Project Panel 1 workspace), place the main window at (0,0) WxH, open the 3 panels with their
// menu commands, expand their trees, capture the main window and each panel, report the panels' metrics (toolbar
// height and button size, tree item height and indent, search field size...).
// With --synthetic DPI (test build only, see dpitest.patch): the test build reads a DPI override from the shared
// memory "NppTestDpiOverride" in DPIManagerV2::getDpiForWindow. The driver sets it to DPI, sends WM_DPICHANGED to
// the main window then WM_DPICHANGED_AFTERPARENT to all its descendants (top-down, as Windows does), captures, and
// goes back to the start DPI the same way, and compares with the start.
//
// Output lines: RESULT <tab> s2a_<tag> <tab> name <tab> PASS|FAIL|SKIP|INFO|WARN|CRASH <tab> detail

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
#include <commctrl.h>
#include <cstdio>
#include <cstdarg>
#include <cstdint>
#include <string>
#include <vector>
#include <unordered_map>
#include <algorithm>

namespace {

constexpr UINT IDM_VIEW_PROJECT_PANEL_1 = 44081;
constexpr UINT IDM_VIEW_FUNC_LIST = 44084;
constexpr UINT IDM_VIEW_FILEBROWSER = 44085;
constexpr UINT WM_DPICHANGED_ = 0x02E0;
constexpr UINT WM_DPICHANGED_AFTERPARENT_ = 0x02E3;

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
	printf("RESULT\ts2a_%s\t%s\t%s\t%s\n", g_tag.c_str(), name, names[st], buf);
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

void reportStrayDialogs(const char *when) {
	int n = 0;
	for (HWND h : processTopWindows()) {
		if (isMain(h) || className(h) != L"#32770")
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
// EnumChildWindows enumerates a window before its children (top-down)
std::vector<HWND> children(HWND parent, const wchar_t *cls, bool directOnly) {
	ChildFind f{parent, {}, cls, directOnly};
	::EnumChildWindows(parent, EnumKids, reinterpret_cast<LPARAM>(&f));
	return f.out;
}

void settle(DWORD ms = 400) {
	::Sleep(ms);
	if (g_main)
		responsive(g_main, 5000);
}

LRESULT sendT(HWND h, UINT m, WPARAM w = 0, LPARAM l = 0) {
	DWORD_PTR r = 0;
	if (!::SendMessageTimeoutW(h, m, w, l, SMTO_ABORTIFHUNG, 5000, &r))
		return -999;
	return static_cast<LRESULT>(r);
}

// ---- panels
enum PanelKind { PK_FL, PK_FAW, PK_PP, PK_COUNT };
const char *kPanelName[PK_COUNT] = {"FL", "FaW", "PP1"};

struct Panel {
	HWND dlg = nullptr;
	HWND toolbar = nullptr;
	std::vector<HWND> trees;
	HWND edit = nullptr;
};

// a panel dialog: #32770 with a direct ToolbarWindow32 and a direct SysTreeView32; kind by the toolbar button count
bool findPanels(Panel (&panels)[PK_COUNT]) {
	std::vector<HWND> cands = children(g_main, L"#32770", false);
	for (HWND top : processTopWindows())
		if (top != g_main)
			for (HWND h : children(top, L"#32770", false))
				cands.push_back(h);
	for (HWND d : cands) {
		std::vector<HWND> tbs = children(d, L"ToolbarWindow32", true);
		std::vector<HWND> trees = children(d, L"SysTreeView32", true);
		if (tbs.empty() || trees.empty())
			continue;
		const LRESULT n = sendT(tbs[0], TB_BUTTONCOUNT);
		int kind = n == 4 ? PK_FL : n == 3 ? PK_FAW : n == 2 ? PK_PP : -1;
		if (kind < 0)
			continue;
		Panel &p = panels[kind];
		p.dlg = d;
		p.toolbar = tbs[0];
		p.trees = trees;
		std::vector<HWND> edits = children(tbs[0], L"Edit", true);
		p.edit = edits.empty() ? nullptr : edits[0];
	}
	return panels[PK_FL].dlg && panels[PK_FAW].dlg && panels[PK_PP].dlg;
}

void expandAll(HWND tree) {
	// breadth: expand every item that has children (handles are opaque values, fine across processes)
	std::vector<HTREEITEM> todo;
	for (HTREEITEM it = reinterpret_cast<HTREEITEM>(sendT(tree, TVM_GETNEXTITEM, TVGN_ROOT, 0)); it;
		 it = reinterpret_cast<HTREEITEM>(sendT(tree, TVM_GETNEXTITEM, TVGN_NEXT, reinterpret_cast<LPARAM>(it))))
		todo.push_back(it);
	for (size_t i = 0; i < todo.size() && i < 400; ++i) {
		sendT(tree, TVM_EXPAND, TVE_EXPAND, reinterpret_cast<LPARAM>(todo[i]));
		for (HTREEITEM c = reinterpret_cast<HTREEITEM>(sendT(tree, TVM_GETNEXTITEM, TVGN_CHILD, reinterpret_cast<LPARAM>(todo[i]))); c;
			 c = reinterpret_cast<HTREEITEM>(sendT(tree, TVM_GETNEXTITEM, TVGN_NEXT, reinterpret_cast<LPARAM>(c))))
			todo.push_back(c);
	}
	// scroll to the top
	HTREEITEM root = reinterpret_cast<HTREEITEM>(sendT(tree, TVM_GETNEXTITEM, TVGN_ROOT, 0));
	if (root)
		sendT(tree, TVM_SELECTITEM, TVGN_FIRSTVISIBLE, reinterpret_cast<LPARAM>(root));
}

std::string rectStr(HWND h, HWND relTo) {
	RECT r{};
	::GetWindowRect(h, &r);
	::MapWindowPoints(nullptr, relTo, reinterpret_cast<POINT *>(&r), 2);
	char b[96];
	snprintf(b, sizeof(b), "[%ld,%ld %ldx%ld]", r.left, r.top, r.right - r.left, r.bottom - r.top);
	return b;
}

std::string metrics(const Panel &p) {
	std::string s = "panel " + rectStr(p.dlg, g_main) + " vis=" + std::to_string(::IsWindowVisible(p.dlg) ? 1 : 0);
	const LRESULT bs = sendT(p.toolbar, TB_GETBUTTONSIZE);
	char b[256];
	snprintf(b, sizeof(b), "; toolbar %s btn=%dx%d", rectStr(p.toolbar, p.dlg).c_str(), static_cast<int>(LOWORD(bs)), static_cast<int>(HIWORD(bs)));
	s += b;
	if (p.edit)
		s += "; search " + rectStr(p.edit, p.toolbar);
	for (HWND t : p.trees) {
		snprintf(b, sizeof(b), "; tree%s %s itemH=%d indent=%d count=%d", ::IsWindowVisible(t) ? "" : "(hidden)", rectStr(t, p.dlg).c_str(),
			static_cast<int>(sendT(t, TVM_GETITEMHEIGHT)), static_cast<int>(sendT(t, TVM_GETINDENT)), static_cast<int>(sendT(t, TVM_GETCOUNT)));
		s += b;
	}
	return s;
}

void capturePanels(Panel (&panels)[PK_COUNT], const std::string &step, Img (&out)[PK_COUNT]) {
	for (int k = 0; k < PK_COUNT; ++k) {
		out[k] = shot(panels[k].dlg, g_tag + "_" + step + "_" + kPanelName[k]);
		report(INFO, (std::string("metrics_") + step + "_" + kPanelName[k]).c_str(), "%s", metrics(panels[k]).c_str());
	}
}

// synthetic DPI change: override for GetDpiForWindow (test build), WM_DPICHANGED to the top-level windows, then
// WM_DPICHANGED_AFTERPARENT top-down to all their descendants.
// The main window gets lParam 0 (as the Stage 1 harness: its suggested rectangle would not fit on the screen); the
// floating containers (top-level #32770) get their suggested rectangle (same position, size scaled), written in the
// Notepad++ process since Wine doesn't marshal it.
// Windows sends WM_DPICHANGED_AFTERPARENT before the main window's posted NPPM_INTERNAL_DPICHANGEDRELAYOUT is
// processed; across processes the posted message can be processed between our messages, so it is sent again at the end.
constexpr UINT NPPM_INTERNAL_DPICHANGEDRELAYOUT_ = WM_USER + 114;
volatile UINT *g_override = nullptr;
void dpiChange(UINT dpi, UINT prevDpi) {
	*g_override = dpi;
	std::vector<HWND> tops{g_main};
	for (HWND top : processTopWindows())
		if (top != g_main && className(top) == L"#32770")
			tops.push_back(top);
	for (HWND top : tops) {
		LPARAM lp = 0;
		if (top != g_main) {
			RECT rc{};
			::GetWindowRect(top, &rc);
			RECT suggested{rc.left, rc.top, rc.left + ::MulDiv(rc.right - rc.left, dpi, prevDpi), rc.top + ::MulDiv(rc.bottom - rc.top, dpi, prevDpi)};
			void *remote = ::VirtualAllocEx(g_pi.hProcess, nullptr, sizeof(RECT), MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
			if (remote && ::WriteProcessMemory(g_pi.hProcess, remote, &suggested, sizeof(RECT), nullptr))
				lp = reinterpret_cast<LPARAM>(remote);
			else {
				report(WARN, "floating_rect", "cannot write the suggested rectangle in the process: error %lu", ::GetLastError());
				continue;
			}
		}
		sendT(top, WM_DPICHANGED_, MAKEWPARAM(dpi, dpi), lp);
		for (HWND h : children(top, nullptr, false))
			sendT(h, WM_DPICHANGED_AFTERPARENT_, 0, 0);
	}
	sendT(g_main, NPPM_INTERNAL_DPICHANGEDRELAYOUT_, 0, 0);
}

}	// namespace

int main(int argc, char **argv) {
	std::string exe, settings, file, search;
	int synthDpi = 0, startDpi = 0, winW = 1280, winH = 960;
	for (int i = 1; i < argc; ++i) {
		const std::string a = argv[i];
		auto next = [&]() -> std::string { return (i + 1 < argc) ? argv[++i] : std::string(); };
		if (a == "--exe") exe = next();
		else if (a == "--settings") settings = next();
		else if (a == "--file") file = next();
		else if (a == "--out") g_out = next();
		else if (a == "--tag") g_tag = next();
		else if (a == "--synthetic") synthDpi = atoi(next().c_str());
		else if (a == "--startdpi") startDpi = atoi(next().c_str());
		else if (a == "--size") { winW = atoi(next().c_str()); winH = atoi(next().c_str()); }
		else if (a == "--search") search = next();
		else {
			fprintf(stderr, "usage: s2adrive.exe --exe WINPATH --settings WINDIR [--file WINPATH] --out DIR [--tag T] [--synthetic DPI] [--startdpi DPI] [--size W H]\n");
			return 64;
		}
	}
	::SetProcessDPIAware();

	// DPI override read by the test build (ignored by the other builds)
	HANDLE hMap = ::CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0, 4096, L"NppTestDpiOverride");
	g_override = hMap ? static_cast<volatile UINT *>(::MapViewOfFile(hMap, FILE_MAP_ALL_ACCESS, 0, 0, sizeof(UINT))) : nullptr;
	if (!g_override) {
		report(CRASH, "override", "shared memory: error %lu", ::GetLastError());
		return 2;
	}
	*g_override = static_cast<UINT>(startDpi);

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

	::SetWindowPos(g_main, HWND_TOP, 0, 0, winW, winH, SWP_SHOWWINDOW);
	settle(800);

	// the 3 panels, docked as prepared in config.xml
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_FUNC_LIST, 0);
	settle(1500);
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_FILEBROWSER, 0);
	settle(1500);
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_PROJECT_PANEL_1, 0);
	settle(1500);
	reportStrayDialogs("panels");
	Panel panels[PK_COUNT];
	const bool found = findPanels(panels);
	check(found && alive() && responsive(g_main), "panels_open", "FL %p FaW %p PP1 %p", static_cast<void *>(panels[PK_FL].dlg),
		static_cast<void *>(panels[PK_FAW].dlg), static_cast<void *>(panels[PK_PP].dlg));
	if (!found) {
		if (alive())
			::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	if (!search.empty() && panels[PK_FL].edit) {
		// Function List search field: the search result tree replaces the tree
		::SendMessageW(panels[PK_FL].edit, WM_SETTEXT, 0, reinterpret_cast<LPARAM>(Widen(search).c_str()));
		settle(1000);
	}
	for (int k = 0; k < PK_COUNT; ++k)
		for (HWND t : panels[k].trees)
			if (::IsWindowVisible(t))
				expandAll(t);
	// deselect the search field focus etc.: focus the editor
	settle(1000);

	Img start[PK_COUNT];
	Img mainStart = shot(g_main, g_tag + "_1_main");
	check(nonBg(mainStart) > 2000, "main_capture", "%dx%d non-background %ld", mainStart.w, mainStart.h, nonBg(mainStart));
	capturePanels(panels, "1", start);

	if (synthDpi > 0) {
		HMODULE u = ::GetModuleHandleW(L"user32.dll");
		using fnGetDpiForWindow = UINT(WINAPI *)(HWND);
		auto gdfw = reinterpret_cast<fnGetDpiForWindow>(reinterpret_cast<void *>(::GetProcAddress(u, "GetDpiForWindow")));
		const UINT dpi0 = startDpi ? static_cast<UINT>(startDpi) : (gdfw ? gdfw(g_main) : 96);

		const UINT seq[] = {static_cast<UINT>(synthDpi), dpi0, static_cast<UINT>(synthDpi), dpi0};
		for (int step = 0; step < 4; ++step) {
			dpiChange(seq[step], step == 0 ? dpi0 : seq[step - 1]);
			settle(2000);
			const bool ok = alive() && responsive(g_main);
			char nm[64];
			snprintf(nm, sizeof(nm), "synthetic_%d_to_%u", step + 1, seq[step]);
			check(ok, nm, "process %s", ok ? "alive and responsive" : "NOT OK");
			if (!ok) {
				report(CRASH, nm, "died or hung");
				return 2;
			}
			Img cur[PK_COUNT];
			const std::string stepName = std::to_string(step + 2) + "_" + std::to_string(seq[step]);
			Img mainCur = shot(g_main, g_tag + "_" + stepName + "_main");
			if (step == 0) {
				// diagnostic: the same after a full repaint of the main window and its children
				::RedrawWindow(g_main, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN | RDW_UPDATENOW);
				settle(800);
				Img redrawn = shot(g_main, g_tag + "_" + stepName + "_main_redrawn");
				report(INFO, "full_redraw", "main window capture after a full repaint vs before: %s", diff(mainCur, redrawn).c_str());
				// diagnostic: the container of the Function List and its children
				HWND cont = ::GetParent(::GetParent(panels[PK_FL].dlg));
				std::string s = Narrow(className(cont)) + rectStr(cont, g_main) + ":";
				for (HWND c = ::GetWindow(cont, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT))
					s += " " + Narrow(className(c)) + "#" + std::to_string(::GetDlgCtrlID(c)) + rectStr(c, cont) + (::IsWindowVisible(c) ? "" : "(hidden)");
				report(INFO, "fl_container", "%s; FL parent %s%s", s.c_str(), Narrow(className(::GetParent(panels[PK_FL].dlg))).c_str(),
					rectStr(::GetParent(panels[PK_FL].dlg), cont).c_str());
			}
			capturePanels(panels, stepName, cur);
			if (seq[step] == dpi0) {
				for (int k = 0; k < PK_COUNT; ++k) {
					snprintf(nm, sizeof(nm), "roundtrip_%d_%s", step + 1, kPanelName[k]);
					const std::string d = diff(start[k], cur[k]);
					check(d == "identical", nm, "panel after %d and back to %u vs start: %s", synthDpi, dpi0, d.c_str());
				}
				snprintf(nm, sizeof(nm), "roundtrip_%d_main", step + 1);
				report(INFO, nm, "main window after %d and back to %u vs start: %s", synthDpi, dpi0, diff(mainStart, mainCur).c_str());
			}
		}
	}

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
