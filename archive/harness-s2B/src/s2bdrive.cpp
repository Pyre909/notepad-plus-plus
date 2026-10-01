// s2bdrive.cpp - drives Notepad++ under Wine for the per-monitor DPI (Stage 2) checks of the Document List,
// Character Panel and Clipboard History panels.
//
// Launch with an isolated settings dir; main window at (0,0) 1100x720; open the Clipboard History panel, put 3 texts
// in the clipboard, open 2 new documents (one modified), open the Document List and the Character Panel; capture the
// main window and each panel, report the list metrics.
// --synthetic DPI --dpifile WINPATH (test build with the DPI override file only): write DPI in the override file, send
// WM_DPICHANGED(DPI) to the main window and WM_DPICHANGED_AFTERPARENT to every descendant of the main window and of the
// floating containers (parents first), capture + metrics; back to the initial DPI the same way, capture + compare.
// --floatdpi DPI --dpifile WINPATH: for every floating container holding one of the 3 panels: override its DPI only,
// resize it like the system does (x new/old), then WM_DPICHANGED_AFTERPARENT to its descendants; capture; and back.
//
// Output lines: RESULT <tab> tag <tab> name <tab> PASS|FAIL|INFO|CRASH <tab> detail

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
constexpr UINT IDM_VIEW_DOCLIST = 44070;
constexpr UINT IDM_EDIT_CHAR_PANEL = 42051;
constexpr UINT IDM_EDIT_CLIPBOARDHISTORY_PANEL = 42052;
constexpr UINT WM_DPICHANGED_ = 0x02E0;
constexpr UINT WM_DPICHANGED_AFTERPARENT_ = 0x02E3;
constexpr UINT NPPM_INTERNAL_DPICHANGEDRELAYOUT = WM_USER + 114;

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
	printf("RESULT\t%s\t%s\t%s\t%s\n", g_tag.c_str(), name, names[st], buf);
	fflush(stdout);
	g_count[st]++;
	if (st == CRASH)
		g_crash = true;
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
LRESULT send(HWND h, UINT m, WPARAM w = 0, LPARAM l = 0) {
	DWORD_PTR r = 0;
	if (!::SendMessageTimeoutW(h, m, w, l, SMTO_ABORTIFHUNG, 10000, &r))
		return -999;
	return static_cast<LRESULT>(r);
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

// descendants, parents first
void descendants(HWND parent, std::vector<HWND> &out) {
	for (HWND c = ::GetWindow(parent, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT)) {
		out.push_back(c);
		descendants(c, out);
	}
}

struct Panel {
	const char *name;
	const wchar_t *title;
};
const Panel g_panels[] = {{"doclist", L"Document List"}, {"charpanel", L"ASCII Codes Insertion Panel"}, {"clipboard", L"Clipboard History"}};

HWND findPanel(const Panel &p) {
	std::vector<HWND> roots = processTopWindows();
	for (HWND r : roots) {
		std::vector<HWND> all;
		descendants(r, all);
		for (HWND h : all)
			if (className(h) == L"#32770" && windowText(h) == p.title && ::IsWindowVisible(h))
				return h;
	}
	return nullptr;
}

HWND childOfClass(HWND parent, const wchar_t *cls) {
	std::vector<HWND> all;
	descendants(parent, all);
	for (HWND h : all)
		if (className(h) == cls)
			return h;
	return nullptr;
}

std::string listMetrics(HWND panel) {
	char b[1024];
	RECT pr{};
	::GetClientRect(panel, &pr);
	if (HWND lv = childOfClass(panel, L"SysListView32")) {
		HWND hdr = reinterpret_cast<HWND>(send(lv, LVM_GETHEADER));
		RECT hr{};
		if (hdr)
			::GetWindowRect(hdr, &hr);
		const LRESULT cols = hdr ? send(hdr, HDM_GETITEMCOUNT) : -1;
		std::string widths;
		for (LRESULT i = 0; i < cols; ++i)
			widths += std::to_string(send(lv, LVM_GETCOLUMNWIDTH, i)) + (i + 1 < cols ? "," : "");
		const LRESULT v1 = send(lv, LVM_APPROXIMATEVIEWRECT, 1, MAKELPARAM(-1, -1));
		const LRESULT v3 = send(lv, LVM_APPROXIMATEVIEWRECT, 3, MAKELPARAM(-1, -1));
		const int rowH = (HIWORD(v3) - HIWORD(v1)) / 2;
		snprintf(b, sizeof(b), "panel %ldx%ld; listview: items=%ld perPage=%ld headerH=%ld rowH=%d columns=[%s] bk=%lx textbk=%lx himlSmall=%p", pr.right, pr.bottom,
			static_cast<long>(send(lv, LVM_GETITEMCOUNT)), static_cast<long>(send(lv, LVM_GETCOUNTPERPAGE)), hr.bottom - hr.top, rowH, widths.c_str(),
			static_cast<unsigned long>(send(lv, LVM_GETBKCOLOR)), static_cast<unsigned long>(send(lv, LVM_GETTEXTBKCOLOR)),
			reinterpret_cast<void *>(send(lv, LVM_GETIMAGELIST, LVSIL_SMALL)));
		return b;
	}
	if (HWND lb = childOfClass(panel, L"ListBox")) {
		snprintf(b, sizeof(b), "panel %ldx%ld; listbox: items=%ld itemH=%ld", pr.right, pr.bottom, static_cast<long>(send(lb, LB_GETCOUNT)),
			static_cast<long>(send(lb, LB_GETITEMHEIGHT, 0)));
		return b;
	}
	snprintf(b, sizeof(b), "panel %ldx%ld; no list found", pr.right, pr.bottom);
	return b;
}

void settle(DWORD ms = 400) {
	::Sleep(ms);
	if (g_main)
		responsive(g_main, 5000);
}

// capture every panel, report its metrics; returns the images by panel
std::string describe(HWND h) {
	if (!h)
		return "none";
	char b[512];
	HWND parent = ::GetParent(h);
	snprintf(b, sizeof(b), "%p %s \"%s\" (parent %s \"%s\")", static_cast<void *>(h), Narrow(className(h)).c_str(), Narrow(windowText(h)).c_str(),
		parent ? Narrow(className(parent)).c_str() : "-", parent ? Narrow(windowText(parent)).c_str() : "");
	return b;
}

std::vector<Img> capturePanels(const std::string &step) {
	GUITHREADINFO gti{};
	gti.cbSize = sizeof(gti);
	if (::GetGUIThreadInfo(g_pi.dwThreadId, &gti))
		report(INFO, (step + "_focus").c_str(), "focus %s; active %s", describe(gti.hwndFocus).c_str(), describe(gti.hwndActive).c_str());
	std::vector<Img> imgs;
	for (const Panel &p : g_panels) {
		HWND h = findPanel(p);
		if (!h) {
			report(INFO, (step + "_" + p.name).c_str(), "panel not found / not visible");
			imgs.emplace_back();
			continue;
		}
		RECT r{};
		::GetWindowRect(h, &r);
		HWND root = ::GetAncestor(h, GA_ROOT);
		report(INFO, (step + "_" + p.name).c_str(), "hwnd %p root %s rect (%ld,%ld %ldx%ld) %s", static_cast<void *>(h),
			root == g_main ? "main" : "floating", r.left, r.top, r.right - r.left, r.bottom - r.top, listMetrics(h).c_str());
		imgs.push_back(shot(h, g_tag + "_" + step + "_" + p.name));
	}
	return imgs;
}

void writeDpiFile(const std::string &path, const std::string &content) {
	FILE *f = _wfopen(Widen(path).c_str(), L"w");
	if (f) {
		fputs(content.c_str(), f);
		fclose(f);
	}
}

void afterParentAll(HWND root) {
	std::vector<HWND> all;
	descendants(root, all);
	for (HWND h : all)
		send(h, WM_DPICHANGED_AFTERPARENT_);
}

bool checkAlive(const char *name) {
	const bool ok = alive() && responsive(g_main);
	if (!ok)
		report(CRASH, name, "died or hung");
	return ok;
}

}	// namespace

int main(int argc, char **argv) {
	std::string exe, settings, file, dpiFile;
	int synthDpi = 0, floatDpi = 0;
	bool repaintCheck = false, afterParentFirst = false, userCol = false;
	for (int i = 1; i < argc; ++i) {
		const std::string a = argv[i];
		auto next = [&]() -> std::string { return (i + 1 < argc) ? argv[++i] : std::string(); };
		if (a == "--exe") exe = next();
		else if (a == "--settings") settings = next();
		else if (a == "--file") file = next();
		else if (a == "--out") g_out = next();
		else if (a == "--tag") g_tag = next();
		else if (a == "--synthetic") synthDpi = atoi(next().c_str());
		else if (a == "--floatdpi") floatDpi = atoi(next().c_str());
		else if (a == "--dpifile") dpiFile = next();
		else if (a == "--repaint") repaintCheck = true;
		else if (a == "--afterparent-first") afterParentFirst = true;
		else if (a == "--usercol") userCol = true;
		else {
			fprintf(stderr, "usage: s2bdrive.exe --exe WINPATH --settings WINDIR [--file WINPATH] --out DIR [--tag T] [--synthetic DPI|--floatdpi DPI --dpifile WINPATH]\n");
			return 64;
		}
	}
	::SetProcessDPIAware();
	const UINT dpi0 = ::GetDeviceCaps(::GetDC(nullptr), LOGPIXELSX);
	if (!dpiFile.empty())
		writeDpiFile(dpiFile, std::to_string(dpi0) + "\n");

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
	if (!::CreateProcessW(nullptr, cmdBuf.data(), nullptr, nullptr, FALSE, 0, nullptr, dir.c_str(), &si, &g_pi)) {
		report(CRASH, "launch", "%s", Narrow(cmd).c_str());
		return 2;
	}
	::WaitForInputIdle(g_pi.hProcess, 30000);
	g_main = waitFor(60000, isMain);
	if (!g_main) {
		report(CRASH, "main_window", "no main window");
		return 2;
	}
	settle(1500);
	::SetWindowPos(g_main, HWND_TOP, 0, 0, 1100, 720, SWP_SHOWWINDOW);
	settle(800);

	// Clipboard History first (it records the clipboard changes from then on)
	send(g_main, WM_COMMAND, IDM_EDIT_CLIPBOARDHISTORY_PANEL);
	settle(1000);
	const wchar_t *clips[] = {L"first clip", L"second clipboard entry: The quick brown fox", L"third 0123456789 jumps over the lazy dog"};
	for (const wchar_t *c : clips) {
		if (::OpenClipboard(nullptr)) {
			::EmptyClipboard();
			const size_t bytes = (wcslen(c) + 1) * sizeof(wchar_t);
			HGLOBAL g = ::GlobalAlloc(GMEM_MOVEABLE, bytes);
			memcpy(::GlobalLock(g), c, bytes);
			::GlobalUnlock(g);
			::SetClipboardData(CF_UNICODETEXT, g);
			::CloseClipboard();
		}
		settle(500);
	}
	// 2 new documents, the last one modified
	send(g_main, WM_COMMAND, IDM_FILE_NEW);
	settle(300);
	send(g_main, WM_COMMAND, IDM_FILE_NEW);
	settle(300);
	{
		// the current editor: the largest visible Scintilla child of the main window
		HWND best = nullptr;
		long bestArea = 0;
		std::vector<HWND> all;
		descendants(g_main, all);
		for (HWND h : all)
			if (className(h) == L"Scintilla" && ::IsWindowVisible(h) && ::GetParent(h) == g_main) {
				RECT r{};
				::GetWindowRect(h, &r);
				const long area = (r.right - r.left) * (r.bottom - r.top);
				if (area > bestArea) {
					bestArea = area;
					best = h;
				}
			}
		for (wchar_t ch : std::wstring(L"modified"))
			::PostMessageW(best, WM_CHAR, ch, 0);
	}
	settle(500);
	send(g_main, WM_COMMAND, IDM_VIEW_DOCLIST);
	settle(1000);
	send(g_main, WM_COMMAND, IDM_EDIT_CHAR_PANEL);
	settle(1500);
	if (!checkAlive("open_panels"))
		return 2;

	if (userCol) {
		// a column of the Character Panel resized by the user (HTML Name: 150 px)
		if (HWND h = findPanel(g_panels[1]))
			if (HWND lv = childOfClass(h, L"SysListView32"))
				send(lv, LVM_SETCOLUMNWIDTH, 3, MAKELPARAM(150, 0));
		settle(300);
	}

	Img main1 = shot(g_main, g_tag + "_1_main");
	std::vector<Img> p1 = capturePanels("1");

	if (repaintCheck) {
		// full repaint of the panels (no DPI change): how much of the capture depends on the paint history
		for (const Panel &p : g_panels)
			if (HWND h = findPanel(p))
				::RedrawWindow(h, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW);
		settle(800);
		std::vector<Img> p1r = capturePanels("1r");
		for (size_t i = 0; i < p1.size() && i < p1r.size(); ++i)
			report(INFO, (std::string("repaint_") + g_panels[i].name).c_str(), "full repaint vs first capture: %s", diff(p1[i], p1r[i]).c_str());
	}

	if (synthDpi > 0 && !dpiFile.empty()) {
		// the main window (and the docked panels) to synthDpi and back
		writeDpiFile(dpiFile, std::to_string(synthDpi) + "\n");
		send(g_main, WM_DPICHANGED_, MAKEWPARAM(synthDpi, synthDpi), 0);
		for (HWND top : processTopWindows())
			afterParentAll(top);
		// the system sends WM_DPICHANGED_AFTERPARENT before the relayout posted by WM_DPICHANGED is processed: which can't be
		// guaranteed from another process, so the relayout is done again after them
		send(g_main, NPPM_INTERNAL_DPICHANGEDRELAYOUT);
		settle(2000);
		if (!checkAlive("synthetic_up"))
			return 2;
		shot(g_main, g_tag + "_2_main_" + std::to_string(synthDpi));
		capturePanels("2");

		writeDpiFile(dpiFile, std::to_string(dpi0) + "\n");
		send(g_main, WM_DPICHANGED_, MAKEWPARAM(dpi0, dpi0), 0);
		for (HWND top : processTopWindows())
			afterParentAll(top);
		send(g_main, NPPM_INTERNAL_DPICHANGEDRELAYOUT);
		settle(2000);
		if (!checkAlive("synthetic_back"))
			return 2;
		Img main3 = shot(g_main, g_tag + "_3_main_back");
		std::vector<Img> p3 = capturePanels("3");
		if (repaintCheck) {
			::RedrawWindow(g_main, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN | RDW_UPDATENOW);
			settle(800);
			Img main3r = shot(g_main, g_tag + "_3r_main_back");
			std::vector<Img> p3r = capturePanels("3r");
			report(INFO, "roundtrip_repaint_main", "full repaint after the round trip vs first capture: %s", diff(main1, main3r).c_str());
			for (size_t i = 0; i < p1.size() && i < p3r.size(); ++i)
				report(INFO, (std::string("roundtrip_repaint_") + g_panels[i].name).c_str(), "full repaint after the round trip vs first capture: %s",
					diff(p1[i], p3r[i]).c_str());
		}
		report(INFO, "roundtrip_main", "main window after %d and back vs before: %s", synthDpi, diff(main1, main3).c_str());
		for (size_t i = 0; i < p1.size() && i < p3.size(); ++i)
			report(INFO, (std::string("roundtrip_") + g_panels[i].name).c_str(), "%s", diff(p1[i], p3[i]).c_str());
	}

	if (floatDpi > 0 && !dpiFile.empty()) {
		// every floating container holding one of the panels: to floatDpi (only it) and back
		std::vector<HWND> roots;
		for (const Panel &p : g_panels)
			if (HWND h = findPanel(p)) {
				HWND r = ::GetAncestor(h, GA_ROOT);
				if (r != g_main && std::find(roots.begin(), roots.end(), r) == roots.end())
					roots.push_back(r);
			}
		std::vector<RECT> rects(roots.size());
		std::string content = std::to_string(dpi0) + "\n";
		for (size_t i = 0; i < roots.size(); ++i) {
			::GetWindowRect(roots[i], &rects[i]);
			char b[64];
			snprintf(b, sizeof(b), "%llx %d\n", static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(roots[i])), floatDpi);
			content += b;
		}
		report(INFO, "float_roots", "%zu floating containers", roots.size());
		writeDpiFile(dpiFile, content);
		for (size_t i = 0; i < roots.size(); ++i) {
			const RECT &r = rects[i];
			// like the system: the window gets the size for the new DPI (WM_DPICHANGED suggested rectangle), then its children
			// WM_DPICHANGED_AFTERPARENT
			if (afterParentFirst)
				afterParentAll(roots[i]);
			::SetWindowPos(roots[i], nullptr, r.left, r.top, MulDiv(r.right - r.left, floatDpi, dpi0), MulDiv(r.bottom - r.top, floatDpi, dpi0),
				SWP_NOZORDER | SWP_NOACTIVATE);
			if (!afterParentFirst)
				afterParentAll(roots[i]);
		}
		settle(2000);
		if (!checkAlive("float_up"))
			return 2;
		shot(g_main, g_tag + "_2_main_float" + std::to_string(floatDpi));
		capturePanels("2");

		writeDpiFile(dpiFile, std::to_string(dpi0) + "\n");
		for (size_t i = 0; i < roots.size(); ++i) {
			const RECT &r = rects[i];
			if (afterParentFirst)
				afterParentAll(roots[i]);
			::SetWindowPos(roots[i], nullptr, r.left, r.top, r.right - r.left, r.bottom - r.top, SWP_NOZORDER | SWP_NOACTIVATE);
			if (!afterParentFirst)
				afterParentAll(roots[i]);
		}
		settle(2000);
		if (!checkAlive("float_back"))
			return 2;
		Img main3 = shot(g_main, g_tag + "_3_main_back");
		std::vector<Img> p3 = capturePanels("3");
		if (repaintCheck) {
			for (const Panel &p : g_panels)
				if (HWND h = findPanel(p))
					::RedrawWindow(h, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN | RDW_UPDATENOW);
			settle(800);
			std::vector<Img> p3r = capturePanels("3r");
			for (size_t i = 0; i < p1.size() && i < p3r.size(); ++i)
				report(INFO, (std::string("roundtrip_repaint_") + g_panels[i].name).c_str(), "full repaint after the round trip vs first capture: %s",
					diff(p1[i], p3r[i]).c_str());
		}
		report(INFO, "roundtrip_main", "main window after floating %d and back vs before: %s", floatDpi, diff(main1, main3).c_str());
		for (size_t i = 0; i < p1.size() && i < p3.size(); ++i)
			report(INFO, (std::string("roundtrip_") + g_panels[i].name).c_str(), "%s", diff(p1[i], p3[i]).c_str());
	}

	if (alive()) {
		::PostMessageW(g_main, WM_CLOSE, 0, 0);
		// "save the modified new document?" -> No
		for (int i = 0; i < 20 && alive(); ++i) {
			::Sleep(500);
			for (HWND h : processTopWindows())
				if (className(h) == L"#32770" && h != g_main && ::GetDlgItem(h, IDNO))
					::PostMessageW(h, WM_COMMAND, IDNO, 0);
		}
		const DWORD w = ::WaitForSingleObject(g_pi.hProcess, 20000);
		DWORD code = 0;
		::GetExitCodeProcess(g_pi.hProcess, &code);
		if (w != WAIT_OBJECT_0) {
			report(CRASH, "exit", "Notepad++ did not exit; terminated");
			::TerminateProcess(g_pi.hProcess, 99);
		} else {
			report(code == 0 ? PASS : FAIL, "exit", "Notepad++ exited, exit code %lu", code);
		}
	} else {
		report(CRASH, "exit", "Notepad++ was not running any more before the clean close");
	}
	printf("SUMMARY\tpass=%d\tfail=%d\tinfo=%d\tcrash=%d\n", g_count[0], g_count[1], g_count[3], g_count[5]);
	return g_crash ? 2 : 0;
}
