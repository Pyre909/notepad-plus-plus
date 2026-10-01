// s2drive.cpp - drives a Notepad++ instance under Wine for the per-monitor DPI awareness Stage 2 (frame metrics) checks.
// Derived from harness-dpi/src/dpidrive.cpp.
//
// Steps: main window (0,0 1024x640) with 2 documents; split view (clone) + Function List docked (splitters);
// Ctrl+Tab task list; Go To Line (centred dialog); About box; command line arguments box; Shortcut Mapper;
// tab context menu "Apply Color to Tab" submenu (colour bitmaps); distraction-free mode and back; optional:
// drag of the docked panel's caption (drag rectangle, docking hit zones); Preferences > MISC. checkbox; clean exit.
//
// Output lines: RESULT <tab> s2_<tag> <tab> name <tab> PASS|FAIL|SKIP|INFO|WARN|CRASH <tab> detail

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

constexpr UINT IDM_FILE_NEW = 41001;
constexpr UINT IDM_SEARCH_GOTOLINE = 43004;
constexpr UINT IDM_VIEW_DISTRACTIONFREE = 44011;
constexpr UINT IDM_VIEW_FUNC_LIST = 44084;
constexpr UINT IDM_VIEW_CLONE_TO_ANOTHER_VIEW = 10002;
constexpr UINT IDM_ABOUT = 47000;
constexpr UINT IDM_CMDLINEARGUMENTS = 47010;
constexpr UINT IDM_SETTING_PREFERENCE = 48011;
constexpr UINT IDM_SETTING_SHORTCUT_MAPPER = 48009;
constexpr UINT IDC_NEXT_DOC = 50004;
constexpr int IDC_BUTTON_CLOSE = 6001;
constexpr int IDC_LIST_DLGTITLE = 6002;
constexpr int IDC_CHECK_PERMONITORDPIAWARENESS = 6367;
constexpr int IDC_CHECK_ALOOWSIMLINKFAW = 6366;

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
	printf("RESULT\ts2_%s\t%s\t%s\t%s\n", g_tag.c_str(), name, names[st], buf);
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

Img shotRect(const RECT &rc, const std::string &file) {
	Img img;
	grabRect(rc, img);
	if (!file.empty())
		writeBMP(file + ".bmp", img);
	return img;
}

Img shot(HWND h, const std::string &file) {
	RECT rc{};
	::GetWindowRect(h, &rc);
	return shotRect(rc, file);
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
template <typename Pred>
HWND waitFor(DWORD timeoutMs, Pred pred) {
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
bool waitGone(HWND h, DWORD timeoutMs) {
	const DWORD end = ::GetTickCount() + timeoutMs;
	while (::IsWindow(h) && ::IsWindowVisible(h)) {
		if (static_cast<LONG>(::GetTickCount() - end) >= 0)
			return false;
		::Sleep(100);
	}
	return true;
}
bool isMain(HWND h) {
	return className(h) == L"Notepad++";
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

std::string rectStr(const RECT &r) {
	char b[96];
	snprintf(b, sizeof(b), "(%ld,%ld %ldx%ld)", r.left, r.top, r.right - r.left, r.bottom - r.top);
	return b;
}

// geometry of the visible children of the main window (client coordinates), sorted
std::string layout(bool directOnly = true) {
	std::vector<std::string> items;
	for (HWND h : children(g_main, nullptr, directOnly)) {
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

std::vector<HWND> g_known;
bool isNewDialog(HWND h) {
	return className(h) == L"#32770" && std::find(g_known.begin(), g_known.end(), h) == g_known.end();
}
void rememberTops() {
	g_known = processTopWindows();
}

void keyInput(WORD vk, bool up) {
	INPUT in{};
	in.type = INPUT_KEYBOARD;
	in.ki.wVk = vk;
	in.ki.dwFlags = up ? KEYEVENTF_KEYUP : 0;
	::SendInput(1, &in, sizeof(in));
}
void keyPress(WORD vk) {
	keyInput(vk, false);
	::Sleep(60);
	keyInput(vk, true);
	::Sleep(250);
}
void mouseTo(int x, int y) {
	::SetCursorPos(x, y);
	::Sleep(80);
}
void mouseButton(DWORD flag) {
	INPUT in{};
	in.type = INPUT_MOUSE;
	in.mi.dwFlags = flag;
	::SendInput(1, &in, sizeof(in));
	::Sleep(120);
}

// a dialog opened by a WM_COMMAND posted to the main window: capture it, report its rectangle, close it
HWND openDialog(UINT cmd, const char *name, const std::string &file, bool (*extra)(HWND) = nullptr) {
	rememberTops();
	::PostMessageW(g_main, WM_COMMAND, cmd, 0);
	HWND dlg = waitFor(15000, [extra](HWND h) { return isNewDialog(h) && (!extra || extra(h)); });
	if (!dlg) {
		report(alive() ? FAIL : CRASH, name, "dialog did not open (process %s)", alive() ? "alive" : "exited");
		return nullptr;
	}
	settle(800);
	RECT wr{}, cr{}, mr{};
	::GetWindowRect(dlg, &wr);
	::GetClientRect(dlg, &cr);
	::GetWindowRect(g_main, &mr);
	const long dx = (wr.left + wr.right) / 2 - (mr.left + mr.right) / 2;
	const long dy = (wr.top + wr.bottom) / 2 - (mr.top + mr.bottom) / 2;
	Img img = shot(dlg, file);
	report(INFO, name, "\"%s\" window=%s client=%ldx%ld centre offset from the main window=(%ld,%ld) nonbg=%ld", Narrow(windowText(dlg)).c_str(),
		rectStr(wr).c_str(), cr.right, cr.bottom, dx, dy, nonBg(img));
	return dlg;
}
void closeDialog(HWND dlg, const char *name, WPARAM cmd = IDCANCEL) {
	if (!dlg)
		return;
	::PostMessageW(dlg, WM_COMMAND, cmd, 0);
	const bool gone = waitGone(dlg, 10000);
	check(gone && alive() && responsive(g_main), name, "closed=%d alive=%d", gone ? 1 : 0, alive() ? 1 : 0);
}

volatile UINT *g_dpiMap = nullptr;

// the visible docked container (direct #32770 child of the main window)
HWND dockedContainer() {
	for (HWND h : children(g_main, L"#32770", true))
		if (::IsWindowVisible(h))
			return h;
	return nullptr;
}

BOOL CALLBACK SendAfterParent(HWND h, LPARAM) {
	DWORD_PTR r = 0;
	::SendMessageTimeoutW(h, 0x02E3 /*WM_DPICHANGED_AFTERPARENT*/, 0, 0, SMTO_ABORTIFHUNG, 5000, &r);
	return TRUE;
}

// synthetic DPI change: every window reports the new DPI (test build), WM_DPICHANGED to the main window (lParam 0: no RECT
// across processes), then WM_DPICHANGED_AFTERPARENT to all its descendants, like Windows does
void syntheticDpiChange(UINT dpi) {
	if (g_dpiMap)
		*g_dpiMap = dpi;
	DWORD_PTR r = 0;
	::SendMessageTimeoutW(g_main, 0x02E0 /*WM_DPICHANGED*/, MAKEWPARAM(dpi, dpi), 0, SMTO_ABORTIFHUNG, 10000, &r);
	::EnumChildWindows(g_main, SendAfterParent, 0);
	settle(1500);
}

bool hasListView(HWND h) {
	return !children(h, WC_LISTVIEWW, true).empty();
}
bool titleGoTo(HWND h) {
	return windowText(h).find(L"Go To") != std::wstring::npos;
}

}	// namespace

int main(int argc, char **argv) {
	std::string exe, settings, file;
	int setPmv2 = -1, expectPmv2 = -1, dpiMap = -1, rightWidth = 0;
	std::vector<UINT> dpiSeq;
	bool drag = false, menu = true, contDpi = false;
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
		else if (a == "--drag") drag = true;
		else if (a == "--no-menu") menu = false;
		else if (a == "--contdpi") contDpi = true;
		else if (a == "--dpimap") dpiMap = atoi(next().c_str());
		else if (a == "--rightwidth") rightWidth = atoi(next().c_str());
		else if (a == "--dpiseq") {
			std::string s = next();
			for (size_t p = 0; p < s.size();) {
				const size_t q = s.find(',', p);
				dpiSeq.push_back(static_cast<UINT>(atoi(s.substr(p, q == std::string::npos ? std::string::npos : q - p).c_str())));
				if (q == std::string::npos)
					break;
				p = q + 1;
			}
		}
		else {
			fprintf(stderr, "usage: s2drive.exe --exe WINPATH --settings WINDIR [--file WINPATH] --out DIR [--tag T] [--set 0|1] [--expect 0|1] [--drag] [--no-menu]\n");
			return 64;
		}
	}
	::SetProcessDPIAware();

	if (dpiMap >= 0) {
		HANDLE hMap = ::CreateFileMappingW(INVALID_HANDLE_VALUE, nullptr, PAGE_READWRITE, 0, sizeof(UINT), L"NppTestWindowDpi");
		if (hMap)
			g_dpiMap = static_cast<volatile UINT *>(::MapViewOfFile(hMap, FILE_MAP_WRITE, 0, 0, sizeof(UINT)));
		if (g_dpiMap)
			*g_dpiMap = static_cast<UINT>(dpiMap);
		report(g_dpiMap ? INFO : FAIL, "dpimap", "NppTestWindowDpi=%d", dpiMap);
	}

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

	// 1. main window, 2 documents
	::SetWindowPos(g_main, HWND_TOP, 0, 0, 1024, 640, SWP_SHOWWINDOW);
	::SetForegroundWindow(g_main);
	::SendMessageW(g_main, WM_COMMAND, IDM_FILE_NEW, 0);
	settle(1000);
	report(INFO, "layout_main", "%s", layout().c_str());
	Img main1 = shot(g_main, g_tag + "_1_main");
	check(nonBg(main1) > 2000, "main_capture", "%dx%d non-background %ld", main1.w, main1.h, nonBg(main1));

	// 2. split view + Function List (docked right)
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_CLONE_TO_ANOTHER_VIEW, 0);
	settle(800);
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_FUNC_LIST, 0);
	settle(2000);
	check(alive() && responsive(g_main), "docking", "split + Function List: %s", layout().c_str());
	Img docked = shot(g_main, g_tag + "_2_docked");
	for (const wchar_t *cls : {L"wespliter", L"nsspliter", L"wedockspliter", L"nsdockspliter"}) {
		int n = 0;
		for (HWND h : children(g_main, cls, false)) {
			if (!::IsWindowVisible(h))
				continue;
			RECT r{};
			::GetWindowRect(h, &r);
			char nm[64];
			snprintf(nm, sizeof(nm), "splitter_%s_%d", Narrow(cls).c_str(), n);
			// the splitter plus a margin, magnified later
			RECT rr{r.left - 4, r.top, r.right + 4, std::min(r.bottom, r.top + 120)};
			shotRect(rr, g_tag + "_2_" + nm);
			report(INFO, nm, "window=%s", rectStr(r).c_str());
			++n;
		}
	}

	// 2b. optional: right panel width, then synthetic DPI changes (docked sizes round trip, container repaint)
	if (!dpiSeq.empty()) {
		HWND dm = nullptr;
		for (HWND h : children(g_main, L"dockingManager", true))
			dm = h;
		HWND split = nullptr;
		for (HWND h : children(g_main, L"wedockspliter", false))
			if (::IsWindowVisible(h))
				split = h;
		HWND cont = dockedContainer();
		RECT cr{};
		::GetWindowRect(cont, &cr);
		if (rightWidth > 0 && dm && split) {
			DWORD_PTR r = 0;
			::SendMessageTimeoutW(dm, 0x500B /*DMM_MOVE_SPLITTER*/, static_cast<WPARAM>(rightWidth - (cr.right - cr.left)), reinterpret_cast<LPARAM>(split),
				SMTO_ABORTIFHUNG, 5000, &r);
			settle(800);
			::GetWindowRect(cont, &cr);
		}
		report(INFO, "dpiseq_start", "docked container %s", rectStr(cr).c_str());
		int step = 0;
		for (UINT d : dpiSeq) {
			syntheticDpiChange(d);
			cont = dockedContainer();
			::GetWindowRect(cont, &cr);
			char nm[64];
			snprintf(nm, sizeof(nm), "dpiseq_%d_%u", step, d);
			report(alive() && responsive(g_main) ? INFO : CRASH, nm, "docked container %s; %s", rectStr(cr).c_str(), layout().c_str());
			// the container's caption, the gap and the top of its contents
			RECT top{cr.left, cr.top, cr.right, cr.top + 60};
			shotRect(top, g_tag + "_2b_" + nm + "_container");
			shot(g_main, g_tag + "_2b_" + nm);
			++step;
		}
		if (contDpi) {
			// WM_DPICHANGED without its RECT (lParam 0) sent directly to the docked container
			const UINT d = dpiSeq.back();
			DWORD_PTR r = 0;
			const LRESULT ok = ::SendMessageTimeoutW(dockedContainer(), 0x02E0 /*WM_DPICHANGED*/, MAKEWPARAM(d, d), 0, SMTO_ABORTIFHUNG, 10000, &r);
			settle(800);
			::GetWindowRect(dockedContainer(), &cr);
			check(ok != 0 && alive() && responsive(g_main), "container_dpichanged_lparam0", "sent=%d alive=%d docked container %s", ok ? 1 : 0,
				alive() ? 1 : 0, rectStr(cr).c_str());
			if (!alive()) {
				report(CRASH, "container_dpichanged_lparam0", "Notepad++ died");
				return 2;
			}
		}
	}

	// 3. Ctrl+Tab task list (modal), closed by the Ctrl key up that its list view expects
	HWND tl = openDialog(IDC_NEXT_DOC, "tasklist", g_tag + "_3_tasklist", hasListView);
	if (tl) {
		std::vector<HWND> lv = children(tl, WC_LISTVIEWW, true);
		RECT lr{};
		if (!lv.empty())
			::GetWindowRect(lv[0], &lr);
		report(INFO, "tasklist_list", "list view %s", rectStr(lr).c_str());
		if (!lv.empty())
			::PostMessageW(lv[0], WM_KEYUP, VK_CONTROL, 0);
		const bool gone = waitGone(tl, 10000);
		if (!gone)
			::PostMessageW(tl, WM_COMMAND, IDCANCEL, 0);
		check((gone || waitGone(tl, 5000)) && alive() && responsive(g_main), "tasklist_close", "closed by Ctrl up=%d", gone ? 1 : 0);
	}

	// 4. Go To Line (modeless, centred on the main window)
	HWND gl = openDialog(IDM_SEARCH_GOTOLINE, "gotoline", g_tag + "_4_gotoline", titleGoTo);
	closeDialog(gl, "gotoline_close");

	// 5. About box
	HWND ab = openDialog(IDM_ABOUT, "about", g_tag + "_5_about");
	closeDialog(ab, "about_close");

	// 6. Command line arguments box (monospace font from the non-client metrics)
	HWND ca = openDialog(IDM_CMDLINEARGUMENTS, "cmdlineargs", g_tag + "_6_cmdlineargs");
	if (ca) {
		HWND ed = nullptr;
		for (HWND h : children(ca, L"Edit", true))
			ed = h;
		if (ed) {
			DWORD_PTR hf = 0;
			::SendMessageTimeoutW(ed, WM_GETFONT, 0, 0, SMTO_ABORTIFHUNG, 3000, &hf);
			report(INFO, "cmdlineargs_font", "edit font handle %p", reinterpret_cast<void *>(hf));
		}
	}
	closeDialog(ca, "cmdlineargs_close");

	// 7. Shortcut Mapper (modal, BabyGrid)
	HWND sm = openDialog(IDM_SETTING_SHORTCUT_MAPPER, "shortcutmapper", g_tag + "_7_shortcutmapper");
	if (sm) {
		std::string grids;
		for (HWND h : children(sm, L"BABYGRID", false)) {
			RECT r{};
			::GetWindowRect(h, &r);
			grids += rectStr(r) + " ";
		}
		report(INFO, "shortcutmapper_grid", "BABYGRID %s", grids.c_str());
	}
	closeDialog(sm, "shortcutmapper_close");

	// 8. tab context menu > Apply Color to Tab (colour bitmaps), with real input
	if (menu) {
		HWND tab = nullptr;
		for (HWND h : children(g_main, WC_TABCONTROLW, true))
			if (::IsWindowVisible(h) && !tab)
				tab = h;
		if (tab) {
			RECT ir{};
			// first tab item rectangle (client coordinates of the tab control)
			::SendMessageW(tab, TCM_GETITEMRECT, 0, reinterpret_cast<LPARAM>(&ir));
			::MapWindowPoints(tab, nullptr, reinterpret_cast<POINT *>(&ir), 2);
			::SetForegroundWindow(g_main);
			settle(300);
			const int cx = (ir.left + ir.right) / 2, cy = (ir.top + ir.bottom) / 2;
			mouseTo(cx, cy);
			POINT pc{cx, cy};
			::ScreenToClient(tab, &pc);
			// the tab control sends NM_RCLICK to the main window on the button up; the menu opens at the cursor
			::PostMessageW(tab, WM_RBUTTONDOWN, MK_RBUTTON, MAKELPARAM(pc.x, pc.y));
			::PostMessageW(tab, WM_RBUTTONUP, 0, MAKELPARAM(pc.x, pc.y));
			::Sleep(1200);
			auto visibleMenus = []() {
				std::string menus;
				HWND hm = nullptr;
				while ((hm = ::FindWindowExW(nullptr, hm, L"#32768", nullptr)) != nullptr) {
					if (!::IsWindowVisible(hm))
						continue;
					RECT r{};
					::GetWindowRect(hm, &r);
					menus += rectStr(r) + " ";
				}
				return menus.empty() ? std::string("none") : menus;
			};
			report(INFO, "tabmenu_open", "visible menus: %s", visibleMenus().c_str());
			// the menu loop of Notepad++'s thread reads the keys posted to its queue
			auto menuKey = [](WPARAM vk) {
				::PostMessageW(g_main, WM_KEYDOWN, vk, 0);
				::PostMessageW(g_main, WM_KEYUP, vk, 0xC0000000);
				::Sleep(400);
			};
			menuKey(VK_UP);	// the last item: "Apply Color to Tab" submenu
			menuKey(VK_RIGHT);
			::Sleep(800);
			RECT all{0, 0, ::GetSystemMetrics(SM_CXSCREEN), ::GetSystemMetrics(SM_CYSCREEN)};
			shotRect(all, g_tag + "_8_tabmenu");
			report(INFO, "tabmenu", "visible menus: %s", visibleMenus().c_str());
			menuKey(VK_ESCAPE);
			menuKey(VK_ESCAPE);
			menuKey(VK_ESCAPE);
			settle(500);
			check(alive() && responsive(g_main), "tabmenu_close", "alive after the menu");
		}
	}

	// 9. optional: drag the docked panel's caption over the main window (drag rectangle, docking zones)
	if (drag) {
		HWND cap = nullptr;
		for (HWND h : children(g_main, L"Button", false))
			if (::IsWindowVisible(h) && ::GetDlgCtrlID(h) == 1050)	// IDC_BTN_CAPTION of a docked container
				cap = h;
		if (cap) {
			RECT r{};
			::GetWindowRect(cap, &r);
			// the caption starts the move (DMM_MOVE -> Gripper) on a mouse move with the button down inside it
			const POINT p0{r.left + 30, (r.top + r.bottom) / 2};
			mouseTo(p0.x, p0.y);
			settle(500);	// the real (buttonless) mouse move must be processed before the button down
			POINT c0 = p0;
			::ScreenToClient(cap, &c0);
			::PostMessageW(cap, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(c0.x, c0.y));
			::PostMessageW(cap, WM_MOUSEMOVE, MK_LBUTTON, MAKELPARAM(c0.x + 3, c0.y));
			::Sleep(600);
			HWND grip = nullptr;
			for (int i = 0; i < 20 && !grip; ++i) {
				HWND h = nullptr;
				while ((h = ::FindWindowExW(nullptr, h, L"moveDlg", nullptr)) != nullptr) {
					DWORD pid = 0;
					::GetWindowThreadProcessId(h, &pid);
					if (pid == g_pi.dwProcessId)
						grip = h;
				}
				if (!grip)
					::Sleep(100);
			}
			report(grip ? INFO : WARN, "drag_gripper", "Gripper window %p", static_cast<void *>(grip));
			auto moveTo = [grip](int x, int y) {
				mouseTo(x, y);
				if (grip)
					::PostMessageW(grip, WM_MOUSEMOVE, MK_LBUTTON, 0);
				::Sleep(150);
			};
			for (int i = 1; i <= 10; ++i)
				moveTo(p0.x - i * 40, p0.y + i * 15);
			::Sleep(600);
			RECT all{0, 0, ::GetSystemMetrics(SM_CXSCREEN), ::GetSystemMetrics(SM_CYSCREEN)};
			shotRect(all, g_tag + "_9_drag_float");
			// near the left edge of the main window: the docking hit zone of the (hidden) left container
			RECT mr{};
			::GetClientRect(g_main, &mr);
			::MapWindowPoints(g_main, nullptr, reinterpret_cast<POINT *>(&mr), 2);
			moveTo(mr.left + 12, (mr.top + mr.bottom) / 2);
			moveTo(mr.left + 10, (mr.top + mr.bottom) / 2);
			::Sleep(600);
			shotRect(all, g_tag + "_9_drag_dockzone");
			// back over the own caption: the button up there changes nothing
			moveTo(p0.x, p0.y);
			::Sleep(300);
			if (grip)
				::PostMessageW(grip, WM_LBUTTONUP, 0, 0);
			settle(1000);
			report(INFO, "drag", "caption %s; layout after: %s", rectStr(r).c_str(), layout().c_str());
			check(alive() && responsive(g_main), "drag_alive", "alive after the drag");
		} else {
			report(SKIP, "drag", "no docked caption found");
		}
	}

	// 10. distraction-free mode and back
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_DISTRACTIONFREE, 0);
	settle(1500);
	{
		RECT wr{};
		::GetWindowRect(g_main, &wr);
		std::string tops;
		for (HWND h : processTopWindows()) {
			if (h == g_main)
				continue;
			RECT r{};
			::GetWindowRect(h, &r);
			tops += Narrow(className(h)) + rectStr(r) + " ";
		}
		RECT all{0, 0, ::GetSystemMetrics(SM_CXSCREEN), ::GetSystemMetrics(SM_CYSCREEN)};
		Img df = shotRect(all, g_tag + "_10_distractionfree");
		check(alive() && responsive(g_main), "distractionfree", "main window %s; other top windows: %s; nonbg=%ld", rectStr(wr).c_str(), tops.c_str(), nonBg(df));
	}
	::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_DISTRACTIONFREE, 0);
	settle(1500);
	::SetWindowPos(g_main, HWND_TOP, 0, 0, 1024, 640, SWP_SHOWWINDOW);
	settle(800);
	shot(g_main, g_tag + "_11_after_df");
	report(INFO, "layout_after_df", "%s", layout().c_str());

	// Preferences > MISC. (optional set/expect of the per-monitor DPI awareness checkbox)
	if (setPmv2 >= 0 || expectPmv2 >= 0) {
		::PostMessageW(g_main, WM_COMMAND, IDM_SETTING_PREFERENCE, 0);
		HWND prefs = waitFor(20000, [](HWND h) { return className(h) == L"#32770" && ::GetDlgItem(h, IDC_LIST_DLGTITLE) != nullptr; });
		if (prefs) {
			settle();
			HWND list = ::GetDlgItem(prefs, IDC_LIST_DLGTITLE);
			const LRESULT count = ::SendMessageW(list, LB_GETCOUNT, 0, 0);
			LRESULT misc = count - 1;
			for (LRESULT i = 0; i < count; ++i) {
				wchar_t buf[512] = {};
				DWORD_PTR r = 0;
				if (::SendMessageTimeoutW(list, LB_GETTEXT, i, reinterpret_cast<LPARAM>(buf), SMTO_ABORTIFHUNG, 3000, &r) && wcscmp(buf, L"MISC.") == 0)
					misc = i;
			}
			::SendMessageW(list, LB_SETCURSEL, misc, 0);
			::SendMessageW(prefs, WM_COMMAND, MAKEWPARAM(IDC_LIST_DLGTITLE, LBN_SELCHANGE), reinterpret_cast<LPARAM>(list));
			settle();
			HWND page = nullptr;
			for (HWND h : children(prefs, L"#32770", true))
				if (::IsWindowVisible(h) && ::GetDlgItem(h, IDC_CHECK_ALOOWSIMLINKFAW))
					page = h;
			HWND cb = page ? ::GetDlgItem(page, IDC_CHECK_PERMONITORDPIAWARENESS) : nullptr;
			if (cb) {
				const LRESULT st = ::SendMessageW(cb, BM_GETCHECK, 0, 0);
				if (expectPmv2 >= 0)
					check((st == BST_CHECKED) == (expectPmv2 == 1), "misc_checkbox_state", "checked=%ld expected %d", static_cast<long>(st), expectPmv2);
				if (setPmv2 >= 0) {
					::SendMessageW(cb, BM_SETCHECK, setPmv2 ? BST_CHECKED : BST_UNCHECKED, 0);
					::SendMessageW(page, WM_COMMAND, MAKEWPARAM(IDC_CHECK_PERMONITORDPIAWARENESS, BN_CLICKED), reinterpret_cast<LPARAM>(cb));
					settle();
					report(INFO, "misc_checkbox_set", "set to %d, now checked=%ld", setPmv2, static_cast<long>(::SendMessageW(cb, BM_GETCHECK, 0, 0)));
				}
			} else {
				report(FAIL, "misc_checkbox", "IDC_CHECK_PERMONITORDPIAWARENESS (6367) absent");
			}
			::PostMessageW(prefs, WM_COMMAND, IDC_BUTTON_CLOSE, 0);
			settle(500);
		} else {
			report(FAIL, "prefs_open", "Preferences dialog did not open");
		}
	}

	if (alive()) {
		::PostMessageW(g_main, WM_CLOSE, 0, 0);
		// "save new 1?" -> answer no
		HWND ask = waitFor(5000, [](HWND h) { return className(h) == L"#32770"; });
		if (ask) {
			report(INFO, "exit_prompt", "\"%s\"", Narrow(windowText(ask)).c_str());
			::PostMessageW(ask, WM_COMMAND, IDNO, 0);
		}
		const DWORD w = ::WaitForSingleObject(g_pi.hProcess, 30000);
		DWORD code = 0;
		::GetExitCodeProcess(g_pi.hProcess, &code);
		if (w != WAIT_OBJECT_0) {
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
