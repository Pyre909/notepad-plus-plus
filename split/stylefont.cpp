// stylefont: the font parameters Notepad++ sets its styles with (see ScintillaEditView::setSpecialStyle).
// Starts Notepad++ with a settings dir whose stylers.xml sets the fonts (see stylefont.sh), opens a C++ file and prints,
// for styles of the main view, SCI_STYLEGETFONT / WEIGHT / STRETCH / ITALIC and the technology; with "switch", also
// after choosing another rendering mode in Preferences (a build that applies it at once).
// Usage: stylefont.exe EXE SETTINGSDIR FILE [switch]
#include <windows.h>
#include <cstdio>
#include <string>
#include <vector>

static PROCESS_INFORMATION g_pi{};

constexpr UINT SCI_STYLEGETFONT = 2486;
constexpr UINT SCI_STYLEGETWEIGHT = 2064;
constexpr UINT SCI_STYLEGETSTRETCH = 2259;
constexpr UINT SCI_STYLEGETITALIC = 2484;
constexpr UINT SCI_GETTECHNOLOGY = 2631;
constexpr int IDC_COMBO_SC_TECHNOLOGY_CHOICE = 6362;
constexpr int IDM_SETTING_PREFERENCE = 48011;

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

// the main edit view: the first visible Scintilla child of the main window
static HWND mainView(HWND hMain) {
	struct Find { HWND h; } f{ nullptr };
	::EnumChildWindows(hMain, [](HWND h, LPARAM lp) -> BOOL {
		wchar_t cls[64]{};
		::GetClassNameW(h, cls, 64);
		if (wcscmp(cls, L"Scintilla") == 0 && ::IsWindowVisible(h)) {
			reinterpret_cast<Find *>(lp)->h = h;
			return FALSE;
		}
		return TRUE;
	}, reinterpret_cast<LPARAM>(&f));
	return f.h;
}

// the text of a message returning a string: the process is another one, so read through a shared buffer
static std::string styleFont(HWND hSci, int style) {
	DWORD_PTR len = 0;
	if (!::SendMessageTimeoutW(hSci, SCI_STYLEGETFONT, style, 0, SMTO_ABORTIFHUNG, 5000, &len) || len > 200)
		return "?";
	void *remote = ::VirtualAllocEx(g_pi.hProcess, nullptr, 256, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
	std::string s(256, '\0');
	DWORD_PTR r = 0;
	::SendMessageTimeoutW(hSci, SCI_STYLEGETFONT, style, reinterpret_cast<LPARAM>(remote), SMTO_ABORTIFHUNG, 5000, &r);
	SIZE_T read = 0;
	::ReadProcessMemory(g_pi.hProcess, remote, s.data(), 256, &read);
	::VirtualFreeEx(g_pi.hProcess, remote, 0, MEM_RELEASE);
	s.resize(strnlen(s.c_str(), 256));
	return s;
}

static LRESULT get(HWND h, UINT msg, WPARAM w) {
	DWORD_PTR r = static_cast<DWORD_PTR>(-99);
	::SendMessageTimeoutW(h, msg, w, 0, SMTO_ABORTIFHUNG, 5000, &r);
	return static_cast<LRESULT>(r);
}

static void dump(HWND hSci, const char *when) {
	const LRESULT tech = get(hSci, SCI_GETTECHNOLOGY, 0);
	static const struct { int id; const char *name; } styles[] = {
		{ 32, "STYLE_DEFAULT (Default Style)" }, { 11, "DEFAULT (no font, regular)" }, { 5, "INSTRUCTION WORD (no font, bold)" },
		{ 1, "COMMENT (no font, italic)" }, { 4, "NUMBER (own font, no font style)" }, { 6, "STRING (own font, bold)" },
		{ 33, "LINE NUMBER (no font, regular)" },
	};
	for (const auto &st : styles)
		printf("STYLEFONT\t%s\ttech=%ld\t%-34s\tfont=\"%s\"\tweight=%ld\tstretch=%ld\titalic=%ld\n", when, static_cast<long>(tech), st.name,
			styleFont(hSci, st.id).c_str(), static_cast<long>(get(hSci, SCI_STYLEGETWEIGHT, st.id)),
			static_cast<long>(get(hSci, SCI_STYLEGETSTRETCH, st.id)), static_cast<long>(get(hSci, SCI_STYLEGETITALIC, st.id)));
	fflush(stdout);
}

int wmain(int argc, wchar_t **argv) {
	if (argc < 4) {
		fprintf(stderr, "usage: stylefont.exe EXE SETTINGSDIR FILE [switch]\n");
		return 64;
	}
	std::wstring cmd = L"\"" + std::wstring(argv[1]) + L"\" -multiInst -nosession -noPlugin \"-settingsDir=" + argv[2] + L"\" \"" + argv[3] + L"\"";
	std::vector<wchar_t> buf(cmd.begin(), cmd.end());
	buf.push_back(0);
	STARTUPINFOW si{};
	si.cb = sizeof(si);
	if (!::CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &g_pi))
		return 2;
	::WaitForInputIdle(g_pi.hProcess, 30000);
	HWND hMain = nullptr;
	for (int i = 0; i < 300 && !hMain; ++i) {
		::Sleep(200);
		for (HWND h : topWindows()) {
			wchar_t c[64]{};
			::GetClassNameW(h, c, 64);
			if (wcscmp(c, L"Notepad++") == 0)
				hMain = h;
		}
	}
	::Sleep(1500);
	HWND hSci = hMain ? mainView(hMain) : nullptr;
	if (!hSci) {
		printf("STYLEFONT\tFAIL\tmain view not found\n");
		::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	dump(hSci, "start");

	if (argc > 4 && wcscmp(argv[4], L"switch") == 0) {
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
		if (hCombo) {
			const LRESULT other = get(hSci, SCI_GETTECHNOLOGY, 0) == 0 ? 1 : 0;
			::SendMessageW(hCombo, CB_SETCURSEL, other, 0);
			::PostMessageW(::GetParent(hCombo), WM_COMMAND, MAKEWPARAM(IDC_COMBO_SC_TECHNOLOGY_CHOICE, CBN_SELCHANGE), reinterpret_cast<LPARAM>(hCombo));
			::Sleep(1500);
			dump(hSci, "switched");
			::SendMessageW(hCombo, CB_SETCURSEL, other ? 0 : 1, 0);
			::PostMessageW(::GetParent(hCombo), WM_COMMAND, MAKEWPARAM(IDC_COMBO_SC_TECHNOLOGY_CHOICE, CBN_SELCHANGE), reinterpret_cast<LPARAM>(hCombo));
			::Sleep(1500);
			dump(hSci, "back");
			::PostMessageW(hPref, WM_CLOSE, 0, 0);
			::Sleep(800);
		} else {
			printf("STYLEFONT\tFAIL\tRendering mode combo box not found\n");
		}
	}
	::PostMessageW(hMain, WM_CLOSE, 0, 0);
	if (::WaitForSingleObject(g_pi.hProcess, 20000) != WAIT_OBJECT_0)
		::TerminateProcess(g_pi.hProcess, 99);
	return 0;
}
