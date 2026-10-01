// nppdrive.cpp - drives a Notepad++ instance (Wine or Windows) for the nppshot harness.
//
// Launches notepad++.exe with an isolated settings directory, opens Preferences
// (WM_COMMAND IDM_SETTING_PREFERENCE to the "Notepad++" window), selects the "Editing 1" page the way
// the category list does (LB_SETCURSEL + WM_COMMAND(IDC_LIST_DLGTITLE, LBN_SELCHANGE) to the
// Preferences dialog), captures it, cycles the "Text rendering" combos (IDs 6282/6284/6286) through
// all items (CB_SETCURSEL + WM_COMMAND(id, CBN_SELCHANGE) to the page dialog), checks that the process
// survives and stays responsive, sets final selections and closes Notepad++ cleanly (so config.xml is
// written). With --expect, verifies the selections after a restart instead.
//
// Output lines: RESULT <tab> npp <tab> name <tab> PASS|FAIL|SKIP|INFO|WARN|CRASH <tab> detail
// Exit code: 0 ok (FAILs possible), 2 crash-level (process died / hung / did not exit / dialog missing).

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
#include <map>
#include <unordered_map>
#include <algorithm>

namespace {

constexpr UINT IDM_SETTING_PREFERENCE = 48011;	// menuCmdID.h: IDM(40000) + 8000 + 11
constexpr int IDC_BUTTON_CLOSE = 6001;	// preference_rc.h
constexpr int IDC_LIST_DLGTITLE = 6002;
constexpr int IDC_CARETSETTING_STATIC = 6216;	// controls identifying the Editing 1 page
constexpr int IDC_CHECK_VIRTUALSPACE = 6245;
constexpr int IDC_TEXTRENDERING_GB_STATIC = 6280;
struct ComboDef {
	int id, labelId;
	const char *name;
};
const ComboDef kCombos[] = {
	{6282, 6281, "antialiasing"},
	{6284, 6283, "renderingmode"},
	{6286, 6285, "contrast"},
};
constexpr size_t editing1FallbackIndex = 3;	// preferenceDlg.cpp: General, Toolbar, Tab Bar, Editing 1, ...

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

void report(int st, const char *name, const char *fmt, ...) {
	static const char *names[] = {"PASS", "FAIL", "SKIP", "INFO", "WARN", "CRASH"};
	char buf[8192];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	for (char *p = buf; *p; ++p)
		if (*p == '\t' || *p == '\n' || *p == '\r')
			*p = ' ';
	printf("RESULT\tnpp_%s\t%s\t%s\t%s\n", g_tag.c_str(), name, names[st], buf);
	fflush(stdout);
	g_count[st]++;
	if (st == 5)
		g_crash = true;
}
enum { PASS, FAIL, SKIP, INFO, WARN, CRASH };
void check(bool ok, const char *name, const char *fmt, ...) {
	char buf[8192];
	va_list ap;
	va_start(ap, fmt);
	vsnprintf(buf, sizeof(buf), fmt, ap);
	va_end(ap);
	report(ok ? PASS : FAIL, name, "%s", buf);
}

// ---------------------------------------------------------------------------------------------
// Capture (screen pixels)

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

struct Stats {
	uint32_t bg = 0;
	long nonbg = 0, distinct = 0, gray = 0, chroma = 0;
	uint64_t hash = 0;
};

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
	for (const auto &kv : counts)
		if (kv.second > best) {
			best = kv.second;
			s.bg = kv.first;
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

// Capture a window (whole window rect, or client area) from the screen, save it, return stats
Stats shot(HWND h, const std::string &file, bool client = false, std::string *desc = nullptr) {
	RECT rc{};
	if (client) {
		::GetClientRect(h, &rc);
		::MapWindowPoints(h, nullptr, reinterpret_cast<POINT *>(&rc), 2);
	} else {
		::GetWindowRect(h, &rc);
	}
	Img img;
	grabRect(rc, img);
	const Stats s = stats(img);
	if (!file.empty())
		writeBMP(file + ".bmp", img);
	if (desc) {
		char b[256];
		snprintf(b, sizeof(b), "rect=(%ld,%ld)-(%ld,%ld) bg=#%06x nonbg=%ld distinct=%ld aa_gray=%ld chroma=%ld hash=%016llx file=%s.png",
			rc.left, rc.top, rc.right, rc.bottom, s.bg, s.nonbg, s.distinct, s.gray, s.chroma,
			static_cast<unsigned long long>(s.hash), file.c_str());
		*desc = b;
	}
	return s;
}

void screenShot(const std::string &file) {
	RECT rc{0, 0, ::GetSystemMetrics(SM_CXSCREEN), ::GetSystemMetrics(SM_CYSCREEN)};
	Img img;
	grabRectOnce(rc, img);
	writeBMP(file + ".bmp", img);
}

// ---------------------------------------------------------------------------------------------
// Process / windows

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
	// WM_GETTEXT is marshalled between processes
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

// Report (and capture) unexpected dialogs / message boxes of the process
void reportStrayDialogs(const char *when) {
	int n = 0;
	for (HWND h : processTopWindows()) {
		if (isMain(h) || isPrefs(h))
			continue;
		const std::wstring cls = className(h);
		if (cls != L"#32770")
			continue;
		std::wstring texts;
		for (HWND c = ::GetWindow(h, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT)) {
			const std::wstring t = windowText(c);
			if (!t.empty())
				texts += L" | " + t;
		}
		char nm[64];
		snprintf(nm, sizeof(nm), "stray_dialog_%s_%d", when, n);
		report(WARN, nm, "title=\"%s\" texts=\"%s\" file=%s_%s.png", Narrow(windowText(h)).c_str(), Narrow(texts).c_str(), g_tag.c_str(), nm);
		shot(h, g_tag + "_" + nm);
		++n;
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
	if ((!f->directOnly || ::GetParent(h) == f->parent) && className(h) == f->cls)
		f->out.push_back(h);
	return TRUE;
}
std::vector<HWND> children(HWND parent, const wchar_t *cls, bool directOnly) {
	ChildFind f{parent, {}, cls, directOnly};
	::EnumChildWindows(parent, EnumKids, reinterpret_cast<LPARAM>(&f));
	return f.out;
}

HWND visiblePage(HWND prefs) {
	for (HWND h : children(prefs, L"#32770", true))
		if (::IsWindowVisible(h))
			return h;
	return nullptr;
}

HWND mainEditor() {
	HWND best = nullptr;
	long bestArea = 0;
	for (HWND h : children(g_main, L"Scintilla", false)) {
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

// State of a Scintilla window of the Notepad++ process, read with integer-only messages (safe
// across processes): technology, font quality and the 6 private rendering overrides.
constexpr UINT SCI_GETTECHNOLOGY = 2631, SCI_GETFONTQUALITY = 2612, SCI_GETFONTRENDERINGPARAMETER = 5002;
std::string sciState(HWND sci) {
	if (!sci)
		return "no-scintilla";
	auto q = [&](UINT m, WPARAM w) -> long long {
		DWORD_PTR r = 0;
		if (!::SendMessageTimeoutW(sci, m, w, 0, SMTO_ABORTIFHUNG, 3000, &r))
			return -999;
		return static_cast<long long>(static_cast<LONG_PTR>(r));
	};
	char b[256];
	snprintf(b, sizeof(b), "tech=%lld quality=%lld overrides(gamma,ec,gec,ctl,pg,rm)=%lld,%lld,%lld,%lld,%lld,%lld",
		q(SCI_GETTECHNOLOGY, 0), q(SCI_GETFONTQUALITY, 0), q(SCI_GETFONTRENDERINGPARAMETER, 0), q(SCI_GETFONTRENDERINGPARAMETER, 1),
		q(SCI_GETFONTRENDERINGPARAMETER, 2), q(SCI_GETFONTRENDERINGPARAMETER, 3), q(SCI_GETFONTRENDERINGPARAMETER, 4),
		q(SCI_GETFONTRENDERINGPARAMETER, 5));
	return b;
}

void settle(DWORD ms = 400) {
	::Sleep(ms);
	if (g_main)
		responsive(g_main, 5000);
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

std::vector<int> parseList(const std::string &s) {
	std::vector<int> v;
	size_t p = 0;
	while (p <= s.size() && !s.empty()) {
		const size_t c = s.find(',', p);
		v.push_back(atoi(s.substr(p, c == std::string::npos ? std::string::npos : c - p).c_str()));
		if (c == std::string::npos)
			break;
		p = c + 1;
	}
	return v;
}

}	// namespace

int main(int argc, char **argv) {
	std::string exe, settings, file, finalSel, expectSel;
	bool cycle = true;
	DWORD startTimeout = 60000;
	for (int i = 1; i < argc; ++i) {
		const std::string a = argv[i];
		auto next = [&]() -> std::string { return (i + 1 < argc) ? argv[++i] : std::string(); };
		if (a == "--exe") exe = next();
		else if (a == "--settings") settings = next();
		else if (a == "--file") file = next();
		else if (a == "--out") g_out = next();
		else if (a == "--tag") g_tag = next();
		else if (a == "--final") finalSel = next();
		else if (a == "--expect") expectSel = next();
		else if (a == "--no-cycle") cycle = false;
		else if (a == "--start-timeout") startTimeout = static_cast<DWORD>(atoi(next().c_str())) * 1000;
		else {
			fprintf(stderr, "usage: nppdrive.exe --exe WINPATH --settings WINDIR [--file WINPATH] --out DIR [--tag T] [--final a,r,c] [--expect a,r,c] [--no-cycle]\n");
			return 64;
		}
	}
	::SetProcessDPIAware();

	// 1. Launch
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
	check(launched, "launch", "%s (error %lu)", Narrow(cmd).c_str(), launched ? 0UL : ::GetLastError());
	if (!launched)
		return 2;
	::WaitForInputIdle(g_pi.hProcess, 30000);
	g_main = waitFor(startTimeout, isMain);
	check(g_main != nullptr, "main_window", "class \"Notepad++\" window %p", static_cast<void *>(g_main));
	if (!g_main) {
		screenShot(g_tag + "_screen_no_main");
		reportStrayDialogs("startup");
		report(CRASH, "main_window", "no main window (process %s)", alive() ? "alive" : "exited");
		if (alive())
			::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	settle(1500);
	reportStrayDialogs("startup");
	::SetWindowPos(g_main, HWND_TOP, 0, 0, 1024, 420, SWP_SHOWWINDOW);
	settle(800);
	std::string d;
	Stats s = shot(g_main, g_tag + "_main", false, &d);
	check(s.nonbg > 2000, "main_window_capture", "%s", d.c_str());

	// 2. Preferences
	::PostMessageW(g_main, WM_COMMAND, IDM_SETTING_PREFERENCE, 0);
	HWND prefs = waitFor(20000, isPrefs);
	check(prefs != nullptr, "prefs_open", "Preferences dialog %p \"%s\"", static_cast<void *>(prefs), prefs ? Narrow(windowText(prefs)).c_str() : "");
	if (!prefs) {
		screenShot(g_tag + "_screen_no_prefs");
		reportStrayDialogs("prefs");
		report(CRASH, "prefs_open", "Preferences dialog did not open (process %s)", alive() ? "alive" : "exited");
		if (alive())
			::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	RECT pr{};
	::GetWindowRect(prefs, &pr);
	const int ph = pr.bottom - pr.top;
	const int screenH = ::GetSystemMetrics(SM_CYSCREEN);
	::SetWindowPos(prefs, HWND_TOP, 0, std::max(430, screenH - ph - 4), 0, 0, SWP_NOSIZE | SWP_SHOWWINDOW);
	settle();

	// 3. Category list -> "Editing 1"
	HWND list = ::GetDlgItem(prefs, IDC_LIST_DLGTITLE);
	const LRESULT count = ::SendMessageW(list, LB_GETCOUNT, 0, 0);
	std::string names;
	size_t editing1 = static_cast<size_t>(-1);
	for (LRESULT i = 0; i < count; ++i) {
		wchar_t buf[512] = {};
		DWORD_PTR r = 0;
		const LRESULT len = ::SendMessageW(list, LB_GETTEXTLEN, i, 0);
		if (len > 0 && len < 500 && ::SendMessageTimeoutW(list, LB_GETTEXT, i, reinterpret_cast<LPARAM>(buf), SMTO_ABORTIFHUNG, 3000, &r)) {
			names += Narrow(buf) + "|";
			if (wcscmp(buf, L"Editing 1") == 0)
				editing1 = static_cast<size_t>(i);
		} else {
			names += "?|";
		}
	}
	report(INFO, "prefs_categories", "%ld categories: %s", static_cast<long>(count), names.c_str());
	if (editing1 == static_cast<size_t>(-1)) {
		report(WARN, "editing1_index", "\"Editing 1\" not found by name (localised UI or LB_GETTEXT not marshalled); using index %zu", editing1FallbackIndex);
		editing1 = editing1FallbackIndex;
	}
	::SendMessageW(list, LB_SETCURSEL, editing1, 0);
	::SendMessageW(prefs, WM_COMMAND, MAKEWPARAM(IDC_LIST_DLGTITLE, LBN_SELCHANGE), reinterpret_cast<LPARAM>(list));
	settle();
	HWND page = visiblePage(prefs);
	const bool isEditing1 = page && ::GetDlgItem(page, IDC_CARETSETTING_STATIC) && ::GetDlgItem(page, IDC_CHECK_VIRTUALSPACE);
	check(isEditing1, "editing1_page", "visible page %p is Editing 1 (has IDC_CARETSETTING_STATIC and IDC_CHECK_VIRTUALSPACE): %s; LB_GETCURSEL=%ld",
		static_cast<void *>(page), isEditing1 ? "yes" : "no", static_cast<long>(::SendMessageW(list, LB_GETCURSEL, 0, 0)));
	s = shot(prefs, g_tag + "_prefs_editing1", false, &d);
	check(s.nonbg > 3000, "prefs_capture", "%s", d.c_str());
	screenShot(g_tag + "_screen_prefs");
	if (!page) {
		report(CRASH, "editing1_page", "no visible page");
		::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	HWND group = ::GetDlgItem(page, IDC_TEXTRENDERING_GB_STATIC);
	report(group ? PASS : FAIL, "textrendering_group", "IDC_TEXTRENDERING_GB_STATIC(6280) %s%s%s", group ? "present: \"" : "ABSENT",
		group ? Narrow(windowText(group)).c_str() : "", group ? "\"" : "");

	HWND editor = mainEditor();
	report(INFO, "main_editor", "Scintilla %p %s (Notepad++ forces GDI under Wine)", static_cast<void *>(editor), sciState(editor).c_str());

	// 4. Combos
	HWND combos[3] = {};
	int counts[3] = {};
	for (int c = 0; c < 3; ++c) {
		const ComboDef &cd = kCombos[c];
		HWND cb = ::GetDlgItem(page, cd.id);
		combos[c] = cb;
		char nm[64];
		snprintf(nm, sizeof(nm), "combo_%s_present", cd.name);
		if (!cb) {
			report(FAIL, nm, "combo %d ABSENT from the Editing 1 page", cd.id);
			continue;
		}
		const int n = static_cast<int>(::SendMessageW(cb, CB_GETCOUNT, 0, 0));
		counts[c] = n;
		const int cur = static_cast<int>(::SendMessageW(cb, CB_GETCURSEL, 0, 0));
		std::string items;
		for (int i = 0; i < n; ++i) {
			wchar_t buf[512] = {};
			DWORD_PTR r = 0;
			const LRESULT len = ::SendMessageW(cb, CB_GETLBTEXTLEN, i, 0);
			if (len >= 0 && len < 500 && ::SendMessageTimeoutW(cb, CB_GETLBTEXT, i, reinterpret_cast<LPARAM>(buf), SMTO_ABORTIFHUNG, 3000, &r))
				items += std::to_string(i) + "=\"" + Narrow(buf) + "\" ";
			else
				items += std::to_string(i) + "=? ";
		}
		HWND label = ::GetDlgItem(page, cd.labelId);
		check(n > 0 && cur >= 0, nm, "id=%d label=\"%s\" enabled=%d count=%d cursel=%d items: %s", cd.id,
			label ? Narrow(windowText(label)).c_str() : "(no label)", ::IsWindowEnabled(cb) ? 1 : 0, n, cur, items.c_str());
	}
	auto enabledStates = [&]() {
		std::string s2;
		for (int c = 0; c < 3; ++c)
			s2 += std::string(kCombos[c].name) + "=" + (combos[c] ? std::to_string(::IsWindowEnabled(combos[c]) ? 1 : 0) + "/sel" +
				std::to_string(static_cast<int>(::SendMessageW(combos[c], CB_GETCURSEL, 0, 0))) : std::string("absent")) + " ";
		return s2;
	};
	auto select = [&](int c, int i) {
		::SendMessageW(combos[c], CB_SETCURSEL, i, 0);
		::SendMessageW(page, WM_COMMAND, MAKEWPARAM(kCombos[c].id, CBN_SELCHANGE), reinterpret_cast<LPARAM>(combos[c]));
	};

	if (!expectSel.empty()) {
		// Phase 2: verify persisted selections
		const std::vector<int> want = parseList(expectSel);
		for (int c = 0; c < 3 && c < static_cast<int>(want.size()); ++c) {
			if (!combos[c] || want[c] < 0)
				continue;
			const int cur = static_cast<int>(::SendMessageW(combos[c], CB_GETCURSEL, 0, 0));
			char nm[64];
			snprintf(nm, sizeof(nm), "persisted_%s", kCombos[c].name);
			check(cur == want[c], nm, "after restart CB_GETCURSEL=%d, expected %d", cur, want[c]);
		}
		if (editor) {
			s = shot(editor, g_tag + "_editor", true, &d);
			report(INFO, "editor_after_restart", "%s; capture %s", sciState(editor).c_str(), d.c_str());
		}
	} else if (cycle) {
		for (int c = 0; c < 3; ++c) {
			if (!combos[c])
				continue;
			for (int i = 0; i < counts[c]; ++i) {
				char nm[64];
				snprintf(nm, sizeof(nm), "cycle_%s_%d", kCombos[c].name, i);
				select(c, i);
				settle(500);
				const bool ok = alive() && responsive(g_main, 10000);
				const int cur = static_cast<int>(::SendMessageW(combos[c], CB_GETCURSEL, 0, 0));
				std::string ed = "no editor";
				if (editor && ok) {
					char f[64];
					snprintf(f, sizeof(f), "%s_editor_%s_%d", g_tag.c_str(), kCombos[c].name, i);
					shot(editor, f, true, &ed);
				}
				if (!ok) {
					report(CRASH, nm, "Notepad++ %s after selecting item %d", alive() ? "stopped responding" : "exited", i);
					screenShot(g_tag + "_screen_" + nm);
					break;
				}
				check(cur == i, nm, "CB_SETCURSEL(%d)+CBN_SELCHANGE: alive, responsive, cursel=%d; combos %s; editor %s; capture %s", i, cur,
					enabledStates().c_str(), sciState(editor).c_str(), ed.c_str());
			}
			if (g_crash)
				break;
		}
		reportStrayDialogs("cycle");
		if (!g_crash) {
			// Final selections (persisted to config.xml, verified by the --expect run)
			std::vector<int> fin = parseList(finalSel);
			std::string chosen;
			for (int c = 0; c < 3; ++c) {
				if (!combos[c]) {
					chosen += "-1,";
					continue;
				}
				int v = (c < static_cast<int>(fin.size()) && fin[c] >= 0) ? fin[c] : counts[c] - 1;
				v = std::min(v, counts[c] - 1);
				select(c, v);
				settle(300);
				chosen += std::to_string(static_cast<int>(::SendMessageW(combos[c], CB_GETCURSEL, 0, 0))) + ",";
			}
			chosen.pop_back();
			printf("FINAL_SELECTION\t%s\n", chosen.c_str());
			report(INFO, "final_selection", "%s (antialiasing,renderingmode,contrast; -1 = absent) combos %s", chosen.c_str(), enabledStates().c_str());
			s = shot(prefs, g_tag + "_prefs_final", false, &d);
			report(INFO, "prefs_final_capture", "%s", d.c_str());
			if (editor) {
				s = shot(editor, g_tag + "_editor_final", true, &d);
				report(INFO, "editor_final", "%s; capture %s", sciState(editor).c_str(), d.c_str());
			}
		}
	}

	// 5. Close cleanly
	if (alive()) {
		::PostMessageW(prefs, WM_COMMAND, IDC_BUTTON_CLOSE, 0);
		settle(500);
		check(!::IsWindowVisible(prefs), "prefs_closed", "Preferences hidden after IDC_BUTTON_CLOSE");
		::PostMessageW(g_main, WM_CLOSE, 0, 0);
		const DWORD w = ::WaitForSingleObject(g_pi.hProcess, 30000);
		DWORD code = 0;
		::GetExitCodeProcess(g_pi.hProcess, &code);
		if (w != WAIT_OBJECT_0) {
			screenShot(g_tag + "_screen_no_exit");
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
