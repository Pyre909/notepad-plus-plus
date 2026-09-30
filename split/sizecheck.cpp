// sizecheck: opens Style Configurator of a notepad++.exe and reports the font size combo box:
// its items and the size selected for the selected style (Global Styles > Default Style at opening).
// Usage: sizecheck.exe EXE SETTINGSDIR
#include <windows.h>
#include <cstdio>
#include <string>
#include <vector>

static PROCESS_INFORMATION g_pi{};

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

static HWND waitFor(DWORD ms, bool (*pred)(HWND)) {
	const DWORD end = ::GetTickCount() + ms;
	do {
		for (HWND h : topWindows())
			if (pred(h))
				return h;
		::Sleep(200);
	} while (::GetTickCount() < end);
	return nullptr;
}

static std::string comboText(HWND hCombo, LRESULT i) {
	wchar_t buf[64]{};
	if (i < 0 || ::SendMessageW(hCombo, CB_GETLBTEXTLEN, i, 0) >= 64)
		return "(none)";
	::SendMessageW(hCombo, CB_GETLBTEXT, i, reinterpret_cast<LPARAM>(buf));
	char out[128]{};
	::WideCharToMultiByte(CP_UTF8, 0, buf, -1, out, sizeof(out), nullptr, nullptr);
	return out;
}

int wmain(int argc, wchar_t **argv) {
	if (argc < 3) {
		fprintf(stderr, "usage: sizecheck.exe EXE SETTINGSDIR\n");
		return 64;
	}
	std::wstring cmd = L"\"" + std::wstring(argv[1]) + L"\" -multiInst -nosession -noPlugin \"-settingsDir=" + argv[2] + L"\"";
	std::vector<wchar_t> buf(cmd.begin(), cmd.end());
	buf.push_back(0);
	STARTUPINFOW si{};
	si.cb = sizeof(si);
	if (!::CreateProcessW(nullptr, buf.data(), nullptr, nullptr, FALSE, 0, nullptr, nullptr, &si, &g_pi)) {
		printf("SIZECHECK\tlaunch\tFAIL\n");
		return 2;
	}
	::WaitForInputIdle(g_pi.hProcess, 30000);
	HWND hMain = waitFor(60000, [](HWND h) {
		wchar_t cls[64]{};
		::GetClassNameW(h, cls, 64);
		return wcscmp(cls, L"Notepad++") == 0;
	});
	if (!hMain) {
		printf("SIZECHECK\tmain_window\tFAIL\n");
		::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	constexpr int IDM_LANGSTYLE_CONFIG_DLG = 46001;
	constexpr int IDC_FONTSIZE_COMBO = 2203;
	::PostMessageW(hMain, WM_COMMAND, IDM_LANGSTYLE_CONFIG_DLG, 0);
	HWND hDlg = waitFor(30000, [](HWND h) { return ::GetDlgItem(h, 2203) != nullptr; });
	if (!hDlg) {
		printf("SIZECHECK\tstyle_configurator\tFAIL\n");
		::TerminateProcess(g_pi.hProcess, 99);
		return 2;
	}
	::Sleep(1000);
	HWND hSize = ::GetDlgItem(hDlg, IDC_FONTSIZE_COMBO);
	const LRESULT count = ::SendMessageW(hSize, CB_GETCOUNT, 0, 0);
	std::string items;
	for (LRESULT i = 0; i < count; ++i)
		items += "[" + comboText(hSize, i) + "]";
	const LRESULT sel = ::SendMessageW(hSize, CB_GETCURSEL, 0, 0);
	printf("SIZECHECK\titems\t%s\n", items.c_str());
	printf("SIZECHECK\tselected\tindex=%ld text=%s\n", static_cast<long>(sel), comboText(hSize, sel).c_str());
	::PostMessageW(hDlg, WM_CLOSE, 0, 0);
	::Sleep(500);
	::PostMessageW(hMain, WM_CLOSE, 0, 0);
	if (::WaitForSingleObject(g_pi.hProcess, 20000) != WAIT_OBJECT_0)
		::TerminateProcess(g_pi.hProcess, 99);
	return 0;
}
