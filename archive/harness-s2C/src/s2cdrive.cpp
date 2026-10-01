// s2cdrive.cpp - drives Notepad++ under Wine for the per-monitor DPI Stage 2 checks of the search results (Finder),
// the incremental search bar (bottom rebar), the Document Map and the docked User Defined Language dialog.
//
// Launch with an isolated settings dir, place the main window, open the Document Map, run a Find All in the current
// document (search results), open the incremental search bar with a search text, open the UDL dialog and dock it,
// report the geometry and capture the main window. With --synthetic DPI (a throwaway test build that fakes the DPI on
// WM_DPICHANGED and sends WM_DPICHANGED_AFTERPARENT to the descendants): synthetic WM_DPICHANGED to DPI and back,
// geometry + captures each time. Close cleanly.
//
// Output lines: RESULT <tab> s2c_<tag> <tab> name <tab> PASS|FAIL|SKIP|INFO|WARN|CRASH <tab> detail

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
#include <algorithm>

namespace {

constexpr UINT IDM_SEARCH_FIND = 43001;
constexpr UINT IDM_SEARCH_FINDINCREMENT = 43011;
constexpr UINT IDM_VIEW_DOC_MAP = 44080;
constexpr UINT IDM_LANG_USER_DLG = 46250;
constexpr int IDFINDWHAT = 1601;
constexpr int IDC_FINDALL_CURRENTFILE = 1641;
constexpr int IDC_INCFINDTEXT = 1682;
constexpr int IDC_DOCK_BUTTON = 20001;
constexpr int IDC_IMPORT_BUTTON = 20015;
constexpr int IDC_VIEWZONECANVAS = 3322;
constexpr UINT WM_DPICHANGED_ = 0x02E0;
constexpr UINT SCI_GETMARGINWIDTHN = 2243;
constexpr UINT SCI_SETCARETPERIOD = 2076;
constexpr UINT SCI_GRABFOCUS = 2400;
constexpr UINT SCI_TEXTHEIGHT = 2279;
constexpr UINT SCI_GETLINECOUNT = 2154;

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
	printf("RESULT\ts2c_%s\t%s\t%s\t%s\n", g_tag.c_str(), name, names[st], buf);
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
		::Sleep(200);
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
bool isFindDlg(HWND h) {
	return className(h) == L"#32770" && ::GetDlgItem(h, IDFINDWHAT) != nullptr && ::GetDlgItem(h, IDC_FINDALL_CURRENTFILE) != nullptr;
}
bool isUdlDlg(HWND h) {
	return className(h) == L"#32770" && ::GetDlgItem(h, IDC_DOCK_BUTTON) != nullptr;
}

struct ChildFind {
	std::vector<HWND> out;
};
BOOL CALLBACK EnumKids(HWND h, LPARAM lp) {
	reinterpret_cast<ChildFind *>(lp)->out.push_back(h);
	return TRUE;
}
std::vector<HWND> descendants(HWND parent) {
	ChildFind f;
	::EnumChildWindows(parent, EnumKids, reinterpret_cast<LPARAM>(&f));
	return f.out;
}
HWND findDescendant(HWND parent, bool (*pred)(HWND)) {
	for (HWND h : descendants(parent))
		if (pred(h))
			return h;
	return nullptr;
}

long long sci(HWND h, UINT m, WPARAM w = 0, LPARAM l = 0) {
	DWORD_PTR r = 0;
	if (!::SendMessageTimeoutW(h, m, w, l, SMTO_ABORTIFHUNG, 3000, &r))
		return -999;
	return static_cast<long long>(static_cast<LONG_PTR>(r));
}

RECT rectIn(HWND h, HWND ref) {
	RECT r{};
	::GetWindowRect(h, &r);
	::MapWindowPoints(nullptr, ref, reinterpret_cast<POINT *>(&r), 2);
	return r;
}
std::string rs(const RECT &r) {
	char b[96];
	snprintf(b, sizeof(b), "[%ld,%ld %ldx%ld]", r.left, r.top, r.right - r.left, r.bottom - r.top);
	return b;
}

void settle(DWORD ms = 400) {
	::Sleep(ms);
	if (g_main)
		responsive(g_main, 5000);
}

bool isIncDlg(HWND h) {
	return className(h) == L"#32770" && ::GetDlgItem(h, IDC_INCFINDTEXT) != nullptr;
}
bool isDockedUdl(HWND h) {
	return className(h) == L"#32770" && ::GetDlgItem(h, IDC_DOCK_BUTTON) != nullptr;
}
bool isViewZone(HWND h) {
	return className(h) == L"#32770" && ::GetDlgItem(h, IDC_VIEWZONECANVAS) != nullptr;
}

// geometry of the elements under test (main window client coordinates)
void geometry(const char *when) {
	std::string s;
	HWND inc = findDescendant(g_main, isIncDlg);
	if (inc) {
		HWND rebar = ::GetParent(inc);
		s += "incDlg" + rs(rectIn(inc, g_main)) + (::IsWindowVisible(inc) ? "(visible)" : "(hidden)") + " rebar" + rs(rectIn(rebar, g_main)) + " ctrls:";
		for (HWND c = ::GetWindow(inc, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT))
			s += " " + std::to_string(::GetDlgCtrlID(c)) + rs(rectIn(c, inc));
	} else
		s += "no incremental dialog";
	report(INFO, (std::string("geom_incremental_") + when).c_str(), "%s", s.c_str());

	s.clear();
	HWND vz = findDescendant(g_main, isViewZone);
	if (vz) {
		HWND docMap = ::GetParent(vz);
		wchar_t zone[64] = {};
		::GetWindowTextW(vz, zone, 63); // the test build writes the zone (higher Y, lower Y) there
		s += "viewZone" + rs(rectIn(vz, g_main)) + " zoneY=" + Narrow(zone) + " docMapDlg" + rs(rectIn(docMap, g_main));
		for (HWND c = ::GetWindow(docMap, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT))
			if (className(c) == L"Scintilla") {
				char b[160];
				snprintf(b, sizeof(b), " mapSci%s textHeight=%lld", rs(rectIn(c, g_main)).c_str(), sci(c, SCI_TEXTHEIGHT, 0));
				s += b;
			}
	} else
		s += "no view zone";
	report(INFO, (std::string("geom_docmap_") + when).c_str(), "%s", s.c_str());

	s.clear();
	for (HWND h : descendants(g_main)) {
		if (className(h) != L"Scintilla")
			continue;
		HWND p = ::GetParent(h);
		if (className(p) != L"#32770" || ::GetDlgItem(p, 1641) != nullptr)
			continue;
		// the Finder: a dialog whose Scintilla has a folding margin (the doc map has no margins)
		if (sci(h, SCI_GETMARGINWIDTHN, 3) <= 0 && sci(h, SCI_GETMARGINWIDTHN, 2) <= 0)
			continue;
		char b[256];
		snprintf(b, sizeof(b), "finderDlg%s%s sci%s lines=%lld textHeight=%lld margins=%lld,%lld,%lld,%lld scrollWidth=%lld; ", rs(rectIn(p, g_main)).c_str(), ::IsWindowVisible(h) ? "" : "(hidden)", rs(rectIn(h, g_main)).c_str(),
			sci(h, SCI_GETLINECOUNT), sci(h, SCI_TEXTHEIGHT, 0), sci(h, SCI_GETMARGINWIDTHN, 0), sci(h, SCI_GETMARGINWIDTHN, 1), sci(h, SCI_GETMARGINWIDTHN, 2), sci(h, SCI_GETMARGINWIDTHN, 3),
			sci(h, 2275 /*SCI_GETSCROLLWIDTH*/));
		s += b;
	}
	report(INFO, (std::string("geom_finder_") + when).c_str(), "%s", s.empty() ? "no finder" : s.c_str());

	s.clear();
	HWND udl = nullptr;
	for (HWND h : descendants(g_main))
		if (isDockedUdl(h))
			udl = h;
	if (udl) {
		s += "udl" + rs(rectIn(udl, g_main)) + " import" + rs(rectIn(::GetDlgItem(udl, IDC_IMPORT_BUTTON), udl)) + " langStatic" + rs(rectIn(::GetDlgItem(udl, 20007), udl))
			+ " langCombo" + rs(rectIn(::GetDlgItem(udl, 20006), udl)) + " ignoreCase" + rs(rectIn(::GetDlgItem(udl, 20012), udl));
		for (HWND c = ::GetWindow(udl, GW_CHILD); c; c = ::GetWindow(c, GW_HWNDNEXT))
			if (className(c) == L"SysTabControl32")
				s += " tab" + rs(rectIn(c, udl));
			else if (className(c) == L"#32770" && ::IsWindowVisible(c))
				s += " page" + rs(rectIn(c, udl));
		SCROLLINFO si{sizeof(si), SIF_ALL};
		::GetScrollInfo(udl, SB_VERT, &si);
		char b[96];
		snprintf(b, sizeof(b), " vscroll min=%d max=%d page=%u pos=%d", si.nMin, si.nMax, si.nPage, si.nPos);
		s += b;
	} else
		s += "no docked UDL";
	report(INFO, (std::string("geom_udl_") + when).c_str(), "%s", s.c_str());
}

void noBlink() {
	// no blinking caret in the captures (Scintilla views); the focus goes to the main editor
	HWND best = nullptr;
	long bestArea = 0;
	for (HWND h : descendants(g_main)) {
		if (className(h) != L"Scintilla")
			continue;
		sci(h, SCI_SETCARETPERIOD, 0);
		if (::GetParent(h) == g_main && ::IsWindowVisible(h)) {
			RECT r{};
			::GetWindowRect(h, &r);
			const long area = (r.right - r.left) * (r.bottom - r.top);
			if (area > bestArea) {
				bestArea = area;
				best = h;
			}
		}
	}
	if (best)
		sci(best, SCI_GRABFOCUS);
}

}	// namespace

int main(int argc, char **argv) {
	std::string exe, settings, file;
	int synthDpi = 0, width = 1600, height = 1000;
	bool udl = true, inc = true, finder = true, docmap = true, wrap = false, udlScroll = false, finder2 = false;
	for (int i = 1; i < argc; ++i) {
		const std::string a = argv[i];
		auto next = [&]() -> std::string { return (i + 1 < argc) ? argv[++i] : std::string(); };
		if (a == "--exe") exe = next();
		else if (a == "--settings") settings = next();
		else if (a == "--file") file = next();
		else if (a == "--out") g_out = next();
		else if (a == "--tag") g_tag = next();
		else if (a == "--synthetic") synthDpi = atoi(next().c_str());
		else if (a == "--size") { width = atoi(next().c_str()); height = atoi(next().c_str()); }
		else if (a == "--no-udl") udl = false;
		else if (a == "--no-inc") inc = false;
		else if (a == "--no-finder") finder = false;
		else if (a == "--no-docmap") docmap = false;
		else if (a == "--wrap") wrap = true;
		else if (a == "--udl-scroll") udlScroll = true;
		else if (a == "--finder2") finder2 = true;
		else {
			fprintf(stderr, "usage: s2cdrive.exe --exe WINPATH --settings WINDIR [--file WINPATH] --out DIR [--tag T] [--synthetic DPI] [--size W H] [--no-udl|--no-inc|--no-finder|--no-docmap] [--wrap] [--udl-scroll] [--finder2]\n");
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
	::SetWindowPos(g_main, HWND_TOP, 0, 0, width, height, SWP_SHOWWINDOW);
	settle(1000);

	if (wrap) {
		::SendMessageW(g_main, WM_COMMAND, 44022 /*IDM_VIEW_WRAP*/, 0);
		settle(800);
	}

	if (docmap) {
		::SendMessageW(g_main, WM_COMMAND, IDM_VIEW_DOC_MAP, 0);
		settle(1500);
	}

	if (finder) {
		::PostMessageW(g_main, WM_COMMAND, IDM_SEARCH_FIND, 0);
		HWND fd = waitFor(20000, isFindDlg);
		if (fd) {
			HWND combo = ::GetDlgItem(fd, IDFINDWHAT);
			::SendMessageW(combo, WM_SETTEXT, 0, reinterpret_cast<LPARAM>(L"fox"));
			::SendMessageW(fd, WM_COMMAND, MAKEWPARAM(IDC_FINDALL_CURRENTFILE, BN_CLICKED), reinterpret_cast<LPARAM>(::GetDlgItem(fd, IDC_FINDALL_CURRENTFILE)));
			settle(1500);
			::SendMessageW(fd, WM_COMMAND, IDCANCEL, 0);
			settle(500);
		}
		check(fd != nullptr && alive(), "find_all", "Find dialog %s, Find All in current document sent", fd ? "found" : "NOT found");

		if (finder2) {
			// "Find in these search results..." of the Finder: a second Finder (getFindersOfFinder)
			HWND finderDlg = nullptr;
			for (HWND h : descendants(g_main))
				if (className(h) == L"Scintilla" && ::IsWindowVisible(h) && sci(h, SCI_GETMARGINWIDTHN, 3) > 0 && className(::GetParent(h)) == L"#32770")
					finderDlg = ::GetParent(h);
			HWND fif = nullptr;
			if (finderDlg) {
				::PostMessageW(finderDlg, WM_COMMAND, WM_USER + 40 /*NPPM_INTERNAL_FINDINFINDERDLG*/, 0);
				fif = waitFor(20000, [](HWND h) { return className(h) == L"#32770" && ::GetDlgItem(h, 1712 /*IDFINDWHAT_FIFOLDER*/) != nullptr; });
				if (fif) {
					::SendMessageW(::GetDlgItem(fif, 1712), WM_SETTEXT, 0, reinterpret_cast<LPARAM>(L"brown"));
					DWORD_PTR r = 0;
					::SendMessageTimeoutW(fif, WM_COMMAND, IDOK, 0, SMTO_ABORTIFHUNG, 20000, &r);
					settle(1500);
				}
			}
			check(fif != nullptr && alive(), "finder2", "Finder %s, Find in these search results dialog %s", finderDlg ? "found" : "NOT found", fif ? "found, OK sent" : "NOT found");
		}
	}

	if (inc) {
		::SendMessageW(g_main, WM_COMMAND, IDM_SEARCH_FINDINCREMENT, 0);
		settle(800);
		HWND incDlg = findDescendant(g_main, isIncDlg);
		if (incDlg) {
			// Wine's rebar doesn't show the child of a band shown again (RBBS_HIDDEN removed)
			if (!::IsWindowVisible(incDlg)) {
				report(INFO, "incremental_show", "the incremental search dialog is hidden in its shown band: ShowWindow(SW_SHOWNA)");
				::ShowWindow(incDlg, SW_SHOWNA);
			}
			::SendMessageW(::GetDlgItem(incDlg, IDC_INCFINDTEXT), WM_SETTEXT, 0, reinterpret_cast<LPARAM>(L"lazy"));
			settle(800);
		}
		check(incDlg != nullptr && ::IsWindowVisible(incDlg), "incremental", "incremental search dialog %s", incDlg ? "found" : "NOT found");
	}

	if (udl) {
		::SendMessageW(g_main, WM_COMMAND, IDM_LANG_USER_DLG, 0);
		HWND u = waitFor(20000, isUdlDlg);
		if (u) {
			::SendMessageW(u, WM_COMMAND, IDC_DOCK_BUTTON, 0);
			settle(1500);
		}
		HWND docked = findDescendant(g_main, isDockedUdl);
		check(docked != nullptr && ::IsWindowVisible(docked), "udl_docked", "UDL dialog %s, docked %s", u ? "found" : "NOT found", docked ? "yes" : "NO");
		if (docked && udlScroll) {
			::SendMessageW(docked, WM_VSCROLL, MAKEWPARAM(SB_PAGEDOWN, 0), 0);
			settle(500);
			report(INFO, "udl_scrolled", "WM_VSCROLL SB_PAGEDOWN sent to the docked UDL");
		}
	}

	noBlink();
	settle(1000);
	const bool ok = alive() && responsive(g_main);
	if (!ok) {
		report(CRASH, "setup", "died or hung");
		return 2;
	}
	geometry("start");
	Img start = shot(g_main, g_tag + "_1_start");

	if (synthDpi > 0) {
		using fnGetDpiForWindow = UINT(WINAPI *)(HWND);
		auto gdfw = reinterpret_cast<fnGetDpiForWindow>(reinterpret_cast<void *>(::GetProcAddress(::GetModuleHandleW(L"user32.dll"), "GetDpiForWindow")));
		const UINT dpi0 = gdfw ? gdfw(g_main) : 96;
		DWORD_PTR r = 0;
		::SendMessageTimeoutW(g_main, WM_DPICHANGED_, MAKEWPARAM(synthDpi, synthDpi), 0, SMTO_ABORTIFHUNG, 20000, &r);
		settle(2500);
		bool okUp = alive() && responsive(g_main);
		check(okUp, "synthetic_up", "WM_DPICHANGED(%d): process %s", synthDpi, okUp ? "alive and responsive" : "NOT OK");
		if (!okUp) {
			report(CRASH, "synthetic_up", "died or hung");
			return 2;
		}
		noBlink();
		settle(800);
		geometry((std::string("dpi") + std::to_string(synthDpi)).c_str());
		shot(g_main, g_tag + "_2_dpi" + std::to_string(synthDpi));

		::SendMessageTimeoutW(g_main, WM_DPICHANGED_, MAKEWPARAM(dpi0, dpi0), 0, SMTO_ABORTIFHUNG, 20000, &r);
		settle(2500);
		bool okBack = alive() && responsive(g_main);
		check(okBack, "synthetic_back", "WM_DPICHANGED(%u): process %s", dpi0, okBack ? "alive and responsive" : "NOT OK");
		if (!okBack) {
			report(CRASH, "synthetic_back", "died or hung");
			return 2;
		}
		noBlink();
		settle(800);
		geometry("back");
		Img back = shot(g_main, g_tag + "_3_back");
		report(INFO, "roundtrip", "capture after %d and back to %u vs before: %s", synthDpi, dpi0, diff(start, back).c_str());
	}

	if (alive()) {
		::PostMessageW(g_main, WM_CLOSE, 0, 0);
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
