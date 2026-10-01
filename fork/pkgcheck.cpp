// pkgcheck EXE OUTBMP: starts a packaged Notepad++ (portable, no -settingsDir), prints the Debug Info text, the About box
// bitness label (and saves a capture of the About box), and the Plugins menu items
#include <windows.h>
#include <cstdio>
#include <string>
#include <vector>
static PROCESS_INFORMATION g_pi{};
static std::vector<HWND> topWindows() {
	struct F { DWORD pid; std::vector<HWND> w; } f{ g_pi.dwProcessId, {} };
	::EnumWindows([](HWND h, LPARAM lp) -> BOOL { auto *p = reinterpret_cast<F *>(lp); DWORD pid = 0; ::GetWindowThreadProcessId(h, &pid);
		if (pid == p->pid && ::IsWindowVisible(h)) p->w.push_back(h); return TRUE; }, reinterpret_cast<LPARAM>(&f));
	return f.w;
}
static HWND findTop(const wchar_t *cls) {
	for (HWND h : topWindows()) { wchar_t c[64]{}; ::GetClassNameW(h, c, 64); if (!cls || wcscmp(c, cls) == 0) return h; }
	return nullptr;
}
static HWND findDialogWith(int ctrlId) {
	for (int i = 0; i < 50; ++i) { for (HWND h : topWindows()) if (::GetDlgItem(h, ctrlId)) return h; ::Sleep(200); }
	return nullptr;
}
static void out(const wchar_t *label, const std::wstring &s) {
	const int n = ::WideCharToMultiByte(CP_UTF8, 0, s.c_str(), -1, nullptr, 0, nullptr, nullptr);
	std::string u(n, 0); ::WideCharToMultiByte(CP_UTF8, 0, s.c_str(), -1, u.data(), n, nullptr, nullptr);
	u.resize(n - 1);
	printf("%ls%s\n", label, u.c_str()); fflush(stdout);
}
static void saveBmp(HWND h, const wchar_t *path) {
	RECT rc; ::GetWindowRect(h, &rc);
	const int w = rc.right - rc.left, ht = rc.bottom - rc.top;
	HDC screen = ::GetDC(nullptr), mem = ::CreateCompatibleDC(screen);
	BITMAPINFO bi{}; bi.bmiHeader.biSize = sizeof(bi.bmiHeader); bi.bmiHeader.biWidth = w; bi.bmiHeader.biHeight = -ht;
	bi.bmiHeader.biPlanes = 1; bi.bmiHeader.biBitCount = 32; bi.bmiHeader.biCompression = BI_RGB;
	void *bits = nullptr; HBITMAP bmp = ::CreateDIBSection(screen, &bi, DIB_RGB_COLORS, &bits, nullptr, 0);
	HGDIOBJ old = ::SelectObject(mem, bmp);
	::BitBlt(mem, 0, 0, w, ht, screen, rc.left, rc.top, SRCCOPY); ::GdiFlush();
	BITMAPFILEHEADER fh{}; fh.bfType = 0x4D42; fh.bfOffBits = sizeof(fh) + sizeof(bi.bmiHeader); fh.bfSize = fh.bfOffBits + w * ht * 4;
	FILE *f = _wfopen(path, L"wb");
	if (f) { fwrite(&fh, sizeof(fh), 1, f); fwrite(&bi.bmiHeader, sizeof(bi.bmiHeader), 1, f); fwrite(bits, 4, w * ht, f); fclose(f); }
	::SelectObject(mem, old); ::DeleteObject(bmp); ::DeleteDC(mem); ::ReleaseDC(nullptr, screen);
}
int wmain(int argc, wchar_t **argv) {
	if (argc < 3) return 64;
	std::wstring cmd = L"\"" + std::wstring(argv[1]) + L"\" -multiInst -nosession";
	std::vector<wchar_t> buf(cmd.begin(), cmd.end()); buf.push_back(0);
	STARTUPINFOW si{}; si.cb = sizeof(si);
	if (!::CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &g_pi)) return 2;
	::WaitForInputIdle(g_pi.hProcess, 30000);
	HWND hMain = nullptr;
	for (int i = 0; i < 300 && !hMain; ++i) { ::Sleep(200); hMain = findTop(L"Notepad++"); }
	if (!hMain) { printf("PKG\tFAIL main window\n"); ::TerminateProcess(g_pi.hProcess, 9); return 2; }
	::Sleep(1500);
	// Plugins menu items
	HMENU menu = ::GetMenu(hMain);
	for (int i = 0; i < ::GetMenuItemCount(menu); ++i) {
		wchar_t t[128]{}; ::GetMenuStringW(menu, i, t, 128, MF_BYPOSITION);
		if (wcsstr(t, L"Plugins")) {
			HMENU sub = ::GetSubMenu(menu, i);
			for (int j = 0; j < ::GetMenuItemCount(sub); ++j) { wchar_t s[128]{}; ::GetMenuStringW(sub, j, s, 128, MF_BYPOSITION); if (s[0]) out(L"PKG\tplugins menu: ", s); }
		}
	}
	// Debug Info
	::PostMessageW(hMain, WM_COMMAND, 40000 + 7000 + 12, 0);
	if (HWND hDbg = findDialogWith(1751)) {
		wchar_t text[8192]{}; ::GetDlgItemTextW(hDbg, 1751, text, 8192);
		std::wstring s(text); size_t p = 0;
		while (p < s.size()) { size_t e = s.find(L"\r\n", p); if (e == std::wstring::npos) e = s.size(); out(L"PKG\tdebug info: ", s.substr(p, e - p)); p = e + 2; }
		::PostMessageW(hDbg, WM_CLOSE, 0, 0); ::Sleep(500);
	} else printf("PKG\tFAIL debug info dialog\n");
	// About box
	::PostMessageW(hMain, WM_COMMAND, 40000 + 7000, 0);
	if (HWND hAbout = findDialogWith(1707)) {
		::Sleep(800);
		wchar_t t[256]{}; ::GetDlgItemTextW(hAbout, 1707, t, 256); out(L"PKG\tabout bitness label: ", t);
		HWND hBit = ::GetDlgItem(hAbout, 1707); RECT rc; ::GetClientRect(hBit, &rc);
		HDC dc = ::GetDC(hBit); HGDIOBJ of = ::SelectObject(dc, reinterpret_cast<HFONT>(::SendMessageW(hBit, WM_GETFONT, 0, 0)));
		SIZE sz{}; ::GetTextExtentPoint32W(dc, t, static_cast<int>(wcslen(t)), &sz); ::SelectObject(dc, of); ::ReleaseDC(hBit, dc);
		RECT dlg; ::GetClientRect(hAbout, &dlg); POINT pt{0, 0}; ::MapWindowPoints(hBit, hAbout, &pt, 1);
		printf("PKG\tabout label: text width %ld px, label starts at x=%ld, dialog client width %ld px -> %s\n", sz.cx, pt.x, dlg.right,
			pt.x + sz.cx <= dlg.right ? "fits" : "CLIPPED");
		::RedrawWindow(hAbout, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_UPDATENOW | RDW_ALLCHILDREN);
		for (int k = 0; k < 20; ++k) { MSG m; while (::PeekMessageW(&m, nullptr, 0, 0, PM_REMOVE)) ::DispatchMessageW(&m); ::Sleep(100); }
		saveBmp(hAbout, argv[2]);
		::PostMessageW(hAbout, WM_CLOSE, 0, 0); ::Sleep(500);
	} else printf("PKG\tFAIL about box\n");
	::PostMessageW(hMain, WM_CLOSE, 0, 0);
	if (::WaitForSingleObject(g_pi.hProcess, 20000) != WAIT_OBJECT_0) { printf("PKG\tFAIL exit\n"); ::TerminateProcess(g_pi.hProcess, 9); }
	return 0;
}
