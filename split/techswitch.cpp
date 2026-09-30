// techswitch: the Rendering mode of Preferences > Editing 1 applies at once (no restart).
// Starts Notepad++ with the Windows font smoothing off (so "Follow Windows" antialiasing is SC_EFF_QUALITY_DEFAULT with GDI
// and SC_EFF_QUALITY_NON_ANTIALIASED with DirectWrite), switches the rendering mode through the combo box and reads back
// the technology and the font quality of the edit views, then checks the right-to-left refusal and a view left alone.
// Usage: techswitch.exe EXE SETTINGSDIR FILE
#include <windows.h>
#include <cstdio>
#include <string>
#include <vector>

static PROCESS_INFORMATION g_pi{};
static int g_fail = 0;

constexpr UINT SCI_GETFONTQUALITY = 2612;
constexpr UINT SCI_SETTECHNOLOGY = 2630;
constexpr UINT SCI_GETTECHNOLOGY = 2631;
constexpr int IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362;
constexpr int IDM_SETTING_PREFERENCE = 48011;
constexpr int IDM_EDIT_RTL = 42026;
constexpr int IDM_EDIT_LTR = 42027;

static void check(bool ok, const char *name, const std::string &detail) {
	g_fail += !ok;
	printf("TECHSWITCH\t%s\t%s\t%s\n", name, ok ? "PASS" : "FAIL", detail.c_str());
	fflush(stdout);
}

static LRESULT sendTimeout(HWND h, UINT msg, WPARAM w = 0, LPARAM l = 0) {
	DWORD_PTR r = static_cast<DWORD_PTR>(-99);
	if (!::SendMessageTimeoutW(h, msg, w, l, SMTO_ABORTIFHUNG, 5000, &r))
		return -99;
	return static_cast<LRESULT>(r);
}

static std::vector<HWND> topWindows() {
	struct Find { DWORD pid; std::vector<HWND> wnds; } f{ g_pi.dwProcessId, {} };
	::EnumWindows([](HWND h, LPARAM lp) -> BOOL {
		auto *pf = reinterpret_cast<Find *>(lp);
		DWORD pid = 0;
		::GetWindowThreadProcessId(h, &pid);
		if (pid == pf->pid && ::IsWindowVisible(h))
			pf->wnds.push_back(h);
		return TRUE;
	}, reinterpret_cast<LPARAM>(&f));
	return f.wnds;
}

static HWND findTop(const wchar_t *cls, const wchar_t *title) {
	for (HWND h : topWindows()) {
		wchar_t c[64]{}, t[128]{};
		::GetClassNameW(h, c, 64);
		::GetWindowTextW(h, t, 128);
		if ((!cls || wcscmp(c, cls) == 0) && (!title || wcsstr(t, title)))
			return h;
	}
	return nullptr;
}

// the edit views: the Scintilla children of the main window (main and sub view), largest first
static std::vector<HWND> editViews(HWND hMain) {
	struct Find { std::vector<HWND> v; } f;
	::EnumChildWindows(hMain, [](HWND h, LPARAM lp) -> BOOL {
		wchar_t cls[64]{};
		::GetClassNameW(h, cls, 64);
		if (wcscmp(cls, L"Scintilla") == 0)
			reinterpret_cast<Find *>(lp)->v.push_back(h);
		return TRUE;
	}, reinterpret_cast<LPARAM>(&f));
	return f.v;
}

static HWND findDescendant(HWND parent, int id) {
	struct Find { int id; HWND h; } f{ id, nullptr };
	::EnumChildWindows(parent, [](HWND h, LPARAM lp) -> BOOL {
		auto *pf = reinterpret_cast<Find *>(lp);
		if (::GetDlgCtrlID(h) == pf->id) {
			pf->h = h;
			return FALSE;
		}
		return TRUE;
	}, reinterpret_cast<LPARAM>(&f));
	return f.h;
}

static std::string techs(const std::vector<HWND> &views) {
	std::string s;
	for (HWND h : views)
		s += std::to_string(sendTimeout(h, SCI_GETTECHNOLOGY)) + "/q" + std::to_string(sendTimeout(h, SCI_GETFONTQUALITY)) + " ";
	return s;
}

// chooses a rendering mode in the combo box as the user does (posted: a refusal shows a modal message box)
static void chooseRendering(HWND hCombo, int index) {
	::SendMessageW(hCombo, CB_SETCURSEL, index, 0);
	::PostMessageW(::GetParent(hCombo), WM_COMMAND, MAKEWPARAM(IDC_COMBO_SC_TECHNOLOGY_CHOICE, CBN_SELCHANGE), reinterpret_cast<LPARAM>(hCombo));
	::Sleep(1500);
}

int wmain(int argc, wchar_t **argv) {
	if (argc < 4) {
		fprintf(stderr, "usage: techswitch.exe EXE SETTINGSDIR FILE\n");
		return 64;
	}
	// Windows font smoothing off for the Notepad++ process (not persisted)
	::SystemParametersInfoW(SPI_SETFONTSMOOTHING, FALSE, nullptr, 0);
	std::wstring cmd = L"\"" + std::wstring(argv[1]) + L"\" -multiInst -nosession -noPlugin \"-settingsDir=" + argv[2] + L"\" \"" + argv[3] + L"\"";
	std::vector<wchar_t> buf(cmd.begin(), cmd.end());
	buf.push_back(0);
	STARTUPINFOW si{};
	si.cb = sizeof(si);
	if (!::CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &g_pi)) {
		check(false, "launch", "CreateProcess failed");
		return 2;
	}
	::WaitForInputIdle(g_pi.hProcess, 30000);
	HWND hMain = nullptr;
	for (int i = 0; i < 300 && !hMain; ++i) {
		::Sleep(200);
		hMain = findTop(L"Notepad++", nullptr);
	}
	::Sleep(1500);
	std::vector<HWND> views = hMain ? editViews(hMain) : std::vector<HWND>{};
	if (views.size() < 2) {
		check(false, "views", "main window or its two edit views not found");
		::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	check(sendTimeout(views[0], SCI_GETTECHNOLOGY) == 1 && sendTimeout(views[1], SCI_GETTECHNOLOGY) == 1 &&
		sendTimeout(views[0], SCI_GETFONTQUALITY) == 1, "start_directwrite", "tech/quality per view: " + techs(views));

	::PostMessageW(hMain, WM_COMMAND, IDM_SETTING_PREFERENCE, 0);
	HWND hPref = nullptr, hCombo = nullptr;
	for (int i = 0; i < 100 && !hCombo; ++i) {
		::Sleep(200);
		for (HWND h : topWindows())
			if (HWND c = findDescendant(h, IDC_COMBO_SC_TECHNOLOGY_CHOICE)) {
				hPref = h;
				hCombo = c;
			}
	}
	if (!hCombo) {
		check(false, "preferences", "Rendering mode combo box not found");
		::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	check(::IsWindowEnabled(hCombo) != FALSE, "combo_enabled", "Rendering mode combo box enabled");

	chooseRendering(hCombo, 0);
	check(sendTimeout(views[0], SCI_GETTECHNOLOGY) == 0 && sendTimeout(views[1], SCI_GETTECHNOLOGY) == 0 &&
		sendTimeout(views[0], SCI_GETFONTQUALITY) == 0, "switch_to_gdi", "tech/quality per view: " + techs(views));

	chooseRendering(hCombo, 1);
	check(sendTimeout(views[0], SCI_GETTECHNOLOGY) == 1 && sendTimeout(views[1], SCI_GETTECHNOLOGY) == 1 &&
		sendTimeout(views[0], SCI_GETFONTQUALITY) == 1, "switch_to_directwrite", "tech/quality per view: " + techs(views));

	chooseRendering(hCombo, 3);
	check(sendTimeout(views[0], SCI_GETTECHNOLOGY) == 3 && sendTimeout(views[1], SCI_GETTECHNOLOGY) == 3,
		"switch_to_directwrite_dc", "tech/quality per view: " + techs(views));

	// a view whose technology was changed by someone else (a plugin) is left alone
	sendTimeout(views[1], SCI_SETTECHNOLOGY, 2);
	chooseRendering(hCombo, 0);
	check(sendTimeout(views[0], SCI_GETTECHNOLOGY) == 0 && sendTimeout(views[1], SCI_GETTECHNOLOGY) == 2,
		"other_technology_left_alone", "main follows to GDI, sub view kept its own DirectWrite retain: " + techs(views));
	sendTimeout(views[1], SCI_SETTECHNOLOGY, 0);

	// right-to-left text: DirectWrite is refused, nothing changes and the combo shows GDI again
	::SendMessageW(hMain, WM_COMMAND, IDM_EDIT_RTL, 0);
	::Sleep(500);
	chooseRendering(hCombo, 1);
	HWND hMsg = findTop(nullptr, L"Cannot use DirectWrite");
	check(hMsg != nullptr && sendTimeout(views[0], SCI_GETTECHNOLOGY) == 0, "rtl_refused",
		std::string("message box ") + (hMsg ? "shown" : "NOT shown") + ", tech/quality: " + techs(views));
	if (hMsg)
		::PostMessageW(hMsg, WM_COMMAND, IDOK, 0);
	::Sleep(800);
	// once the message is closed, the combo box shows the rendering mode in use again
	const LRESULT sel = ::SendMessageW(hCombo, CB_GETCURSEL, 0, 0);
	check(sel == 0 && sendTimeout(views[0], SCI_GETTECHNOLOGY) == 0, "rtl_combo_restored",
		"combo index " + std::to_string(sel) + " (GDI), tech/quality: " + techs(views));
	::SendMessageW(hMain, WM_COMMAND, IDM_EDIT_LTR, 0);
	::Sleep(500);
	chooseRendering(hCombo, 1);
	check(sendTimeout(views[0], SCI_GETTECHNOLOGY) == 1 && sendTimeout(views[0], SCI_GETFONTQUALITY) == 1,
		"after_ltr_directwrite", "tech/quality per view: " + techs(views));

	chooseRendering(hCombo, 0);
	::PostMessageW(hPref, WM_CLOSE, 0, 0);
	::Sleep(800);
	::PostMessageW(hMain, WM_CLOSE, 0, 0);
	if (::WaitForSingleObject(g_pi.hProcess, 20000) != WAIT_OBJECT_0) {
		check(false, "exit", "Notepad++ did not exit");
		::TerminateProcess(g_pi.hProcess, 99);
	}
	printf("TECHSWITCH_SUMMARY\tfail=%d\n", g_fail);
	return 0;
}
