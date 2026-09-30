// smoothcheck: "Follow Windows" text antialiasing against the Windows font smoothing (issue #17461).
// Changes the Windows smoothing (SPI_SETFONTSMOOTHING / SPI_SETFONTSMOOTHINGTYPE, broadcast with SPIF_SENDCHANGE
// as the Control Panel does) while Notepad++ runs, then before it starts, and reports the editor's technology,
// SCI_GETFONTQUALITY and a capture of the editor for each state.
// Usage: smoothcheck.exe EXE SETTINGSDIR FILE OUTDIR
#include <windows.h>
#include <cstdio>
#include <cstdint>
#include <string>
#include <vector>

static PROCESS_INFORMATION g_pi{};
static std::string g_out;

enum class Smooth { off, standard, clearType };
static const char *name(Smooth s) { return s == Smooth::off ? "off" : s == Smooth::standard ? "standard" : "cleartype"; }

static void setSmoothing(Smooth s, UINT winIni) {
	::SystemParametersInfoW(SPI_SETFONTSMOOTHING, s != Smooth::off, nullptr, winIni);
	if (s != Smooth::off)
		::SystemParametersInfoW(SPI_SETFONTSMOOTHINGTYPE, 0,
			reinterpret_cast<PVOID>(static_cast<UINT_PTR>(s == Smooth::standard ? FE_FONTSMOOTHINGSTANDARD : FE_FONTSMOOTHINGCLEARTYPE)), winIni);
}

static std::string systemSmoothing() {
	BOOL on = FALSE;
	UINT type = 0;
	::SystemParametersInfoW(SPI_GETFONTSMOOTHING, 0, &on, 0);
	::SystemParametersInfoW(SPI_GETFONTSMOOTHINGTYPE, 0, &type, 0);
	return std::string(on ? "on" : "off") + "/" + (type == FE_FONTSMOOTHINGCLEARTYPE ? "cleartype" : "standard");
}

static HWND findMain() {
	struct Find { DWORD pid; HWND h; } f{ g_pi.dwProcessId, nullptr };
	::EnumWindows([](HWND h, LPARAM lp) -> BOOL {
		auto *pf = reinterpret_cast<Find *>(lp);
		DWORD pid = 0;
		wchar_t cls[64]{};
		::GetWindowThreadProcessId(h, &pid);
		::GetClassNameW(h, cls, 64);
		if (pid == pf->pid && ::IsWindowVisible(h) && wcscmp(cls, L"Notepad++") == 0) {
			pf->h = h;
			return FALSE;
		}
		return TRUE;
	}, reinterpret_cast<LPARAM>(&f));
	return f.h;
}

static HWND findEditor(HWND hMain) {
	struct Find { HWND h; LONG area; } f{ nullptr, 0 };
	::EnumChildWindows(hMain, [](HWND h, LPARAM lp) -> BOOL {
		auto *pf = reinterpret_cast<Find *>(lp);
		wchar_t cls[64]{};
		::GetClassNameW(h, cls, 64);
		RECT rc{};
		::GetClientRect(h, &rc);
		const LONG area = rc.right * rc.bottom;
		if (wcscmp(cls, L"Scintilla") == 0 && ::IsWindowVisible(h) && area > pf->area) {
			pf->h = h;
			pf->area = area;
		}
		return TRUE;
	}, reinterpret_cast<LPARAM>(&f));
	return f.h;
}

static LRESULT sci(HWND h, UINT msg) {
	DWORD_PTR r = static_cast<DWORD_PTR>(-99);
	if (!::SendMessageTimeoutW(h, msg, 0, 0, SMTO_ABORTIFHUNG, 5000, &r))
		return -99;
	return static_cast<LRESULT>(r);
}

constexpr UINT SCI_GETFONTQUALITY = 2612;
constexpr UINT SCI_GETTECHNOLOGY = 2631;

// the editor's text area (margins excluded), stable over two grabs
static bool capture(HWND hSci, const std::string &file) {
	::RedrawWindow(hSci, nullptr, nullptr, RDW_INVALIDATE | RDW_UPDATENOW);
	RECT rc{};
	::GetClientRect(hSci, &rc);
	::MapWindowPoints(hSci, nullptr, reinterpret_cast<POINT *>(&rc), 2);
	int w = rc.right - rc.left, h = rc.bottom - rc.top;
	if (w <= 0 || h <= 0)
		return false;
	std::vector<uint32_t> px, prev;
	for (int i = 0; i < 20; ++i) {
		::Sleep(200);
		HDC screen = ::GetDC(nullptr);
		HDC mem = ::CreateCompatibleDC(screen);
		BITMAPINFO bi{};
		bi.bmiHeader = { sizeof(BITMAPINFOHEADER), w, -h, 1, 32, BI_RGB };
		void *bits = nullptr;
		HBITMAP bmp = ::CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
		HGDIOBJ old = ::SelectObject(mem, bmp);
		::BitBlt(mem, 0, 0, w, h, screen, rc.left, rc.top, SRCCOPY);
		::GdiFlush();
		px.assign(static_cast<const uint32_t *>(bits), static_cast<const uint32_t *>(bits) + static_cast<size_t>(w) * h);
		::SelectObject(mem, old);
		::DeleteObject(bmp);
		::DeleteDC(mem);
		::ReleaseDC(nullptr, screen);
		if (px == prev)
			break;
		prev = px;
	}
	FILE *f = fopen((g_out + "/" + file).c_str(), "wb");
	if (!f)
		return false;
	const int rowBytes = ((w * 3 + 3) / 4) * 4;
	BITMAPFILEHEADER fh{};
	fh.bfType = 0x4D42;
	fh.bfOffBits = sizeof(BITMAPFILEHEADER) + sizeof(BITMAPINFOHEADER);
	fh.bfSize = fh.bfOffBits + static_cast<DWORD>(rowBytes) * h;
	BITMAPINFOHEADER ih{ sizeof(ih), w, h, 1, 24, BI_RGB };
	fwrite(&fh, sizeof(fh), 1, f);
	fwrite(&ih, sizeof(ih), 1, f);
	std::vector<unsigned char> row(rowBytes, 0);
	for (int y = h - 1; y >= 0; --y) {
		for (int x = 0; x < w; ++x) {
			const uint32_t p = px[static_cast<size_t>(y) * w + x];
			row[x * 3] = p & 0xFF;
			row[x * 3 + 1] = (p >> 8) & 0xFF;
			row[x * 3 + 2] = (p >> 16) & 0xFF;
		}
		fwrite(row.data(), 1, rowBytes, f);
	}
	fclose(f);
	return true;
}

static bool launch(const std::wstring &cmdLine) {
	std::vector<wchar_t> buf(cmdLine.begin(), cmdLine.end());
	buf.push_back(0);
	STARTUPINFOW si{};
	si.cb = sizeof(si);
	if (!::CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &g_pi))
		return false;
	::WaitForInputIdle(g_pi.hProcess, 30000);
	return true;
}

static void quit(HWND hMain) {
	::PostMessageW(hMain, WM_CLOSE, 0, 0);
	if (::WaitForSingleObject(g_pi.hProcess, 20000) != WAIT_OBJECT_0)
		::TerminateProcess(g_pi.hProcess, 99);
	::CloseHandle(g_pi.hProcess);
	::CloseHandle(g_pi.hThread);
}

static bool waitWindows(HWND &hMain, HWND &hSci) {
	for (int i = 0; i < 300 && !(hMain && hSci); ++i) {
		::Sleep(200);
		hMain = findMain();
		hSci = hMain ? findEditor(hMain) : nullptr;
	}
	::Sleep(1500);
	return hMain && hSci;
}

// quality "Follow Windows" must give under DirectWrite (GDI: always the default quality, GDI follows Windows itself)
static long expected(Smooth s, long tech) {
	if (tech == 0)
		return 0;
	return s == Smooth::off ? 1 : s == Smooth::standard ? 2 : 0;
}

static int g_fail = 0;

static void report(const char *step, HWND hSci, Smooth s, const std::string &how) {
	const std::string file = std::string(step) + ".bmp";
	const bool shot = capture(hSci, file);
	const long tech = static_cast<long>(sci(hSci, SCI_GETTECHNOLOGY)), q = static_cast<long>(sci(hSci, SCI_GETFONTQUALITY));
	const bool ok = q == expected(s, tech);
	g_fail += !ok;
	printf("SMOOTH\t%s\t%s\tsystem=%s\ttech=%ld\tquality=%ld (expected %ld)\t%s\t%s\n", step, ok ? "PASS" : "FAIL", systemSmoothing().c_str(),
		tech, q, expected(s, tech), how.c_str(), shot ? file.c_str() : "(no capture)");
	fflush(stdout);
}

static LRESULT waitQuality(HWND hSci, LRESULT before) {
	LRESULT q = before;
	for (int i = 0; i < 15 && q == before; ++i) {
		::Sleep(200);
		q = sci(hSci, SCI_GETFONTQUALITY);
	}
	return q;
}

int wmain(int argc, wchar_t **argv) {
	if (argc < 5) {
		fprintf(stderr, "usage: smoothcheck.exe EXE SETTINGSDIR FILE OUTDIR [plugin]\n");
		return 64;
	}
	char out[MAX_PATH]{};
	::WideCharToMultiByte(CP_UTF8, 0, argv[4], -1, out, MAX_PATH, nullptr, nullptr);
	g_out = out;
	const bool plugin = argc > 5 && wcscmp(argv[5], L"plugin") == 0;
	const std::wstring cmd = L"\"" + std::wstring(argv[1]) + L"\" -multiInst -nosession" + (plugin ? L"" : L" -noPlugin") +
		L" \"-settingsDir=" + argv[2] + L"\" \"" + argv[3] + L"\"";

	// 1. Windows setting changed while Notepad++ runs (the Control Panel broadcasts WM_SETTINGCHANGE)
	setSmoothing(Smooth::clearType, 0);
	HWND hMain = nullptr, hSci = nullptr;
	if (!launch(cmd) || !waitWindows(hMain, hSci)) {
		printf("SMOOTH\tlaunch\tFAIL pid=%lu main=%p editor=%p\n", g_pi.dwProcessId, static_cast<void *>(hMain), static_cast<void *>(hSci));
		return 2;
	}
	report("run_start_cleartype", hSci, Smooth::clearType, "at start");
	HWND hHelper = plugin ? ::FindWindowW(L"SmoothTestHelper", nullptr) : nullptr;
	if (plugin)
		printf("SMOOTH\thelper\t%s\n", hHelper ? "found" : "NOT FOUND");
	const Smooth runtime[] = { Smooth::off, Smooth::standard, Smooth::clearType };
	for (Smooth s : runtime) {
		const LRESULT before = sci(hSci, SCI_GETFONTQUALITY);
		// from another process, as the Control Panel does
		setSmoothing(s, SPIF_SENDCHANGE);
		LRESULT q = waitQuality(hSci, before);
		std::string how = (q != before) ? "changed by another process's broadcast" : "unchanged by another process's broadcast";
		if (q == before && hHelper) {
			// from inside Notepad++ (its own SystemParametersInfo cache is up to date under Wine)
			DWORD_PTR r = 0;
			::SendMessageTimeoutW(hHelper, WM_APP, static_cast<WPARAM>(s), 1, SMTO_ABORTIFHUNG, 5000, &r);
			q = waitQuality(hSci, before);
			how += (q != before) ? "; changed by the in-process broadcast" : "; unchanged by the in-process broadcast";
			if (q == before) {
				::SendMessageTimeoutW(hHelper, WM_APP, static_cast<WPARAM>(s), 2, SMTO_ABORTIFHUNG, 5000, &r);
				q = waitQuality(hSci, before);
				how += (q != before) ? "; changed by WM_SETTINGCHANGE" : "; unchanged by WM_SETTINGCHANGE";
			}
		}
		const std::string step = std::string("run_") + name(s);
		report(step.c_str(), hSci, s, how);
	}
	quit(hMain);

	// 2. Windows setting at Notepad++ startup
	const Smooth startup[] = { Smooth::off, Smooth::standard, Smooth::clearType };
	for (Smooth s : startup) {
		setSmoothing(s, 0);
		hMain = hSci = nullptr;
		const std::string step = std::string("start_") + name(s);
		if (!launch(cmd) || !waitWindows(hMain, hSci)) {
			printf("SMOOTH\t%s\tFAIL launch\n", step.c_str());
			++g_fail;
			continue;
		}
		report(step.c_str(), hSci, s, "at start");
		quit(hMain);
	}

	// leave the prefix as the harness set it (ClearType on)
	setSmoothing(Smooth::clearType, SPIF_UPDATEINIFILE);
	printf("SMOOTH_SUMMARY\tfail=%d\n", g_fail);
	return 0;
}
