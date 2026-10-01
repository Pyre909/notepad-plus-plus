import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
f = 'PowerEditor/src/WinControls/StatusBar/StatusBar.cpp'
rep(f, '''			pStatusBarInfo->closeTheme();
			LOGFONT lf{ DPIManagerV2::getDefaultGUIFontForDpi(::GetParent(hWnd), DPIManagerV2::FontType::status) };
			pStatusBarInfo->setFont(::CreateFontIndirect(&lf));
			
			if (uMsg != WM_THEMECHANGED)
			{
				// the control computes its height with its font (the parent relayouts it after the DPI change)
				::DefSubclassProc(hWnd, WM_SETFONT, reinterpret_cast<WPARAM>(pStatusBarInfo->_hFont), FALSE);
				return 0;
			}
			break;''', '''			pStatusBarInfo->closeTheme();
			LOGFONT lf{ DPIManagerV2::getDefaultGUIFontForDpi(::GetParent(hWnd), DPIManagerV2::FontType::status) };
			HFONT hFont = ::CreateFontIndirect(&lf);

			// the control computes its height with its font (the parent relayouts it after the DPI change),
			// once it has it, it gets the new one before the previous one is deleted
			const bool isControlFont = (pStatusBarInfo->_hFont != nullptr) &&
				(reinterpret_cast<HFONT>(::DefSubclassProc(hWnd, WM_GETFONT, 0, 0)) == pStatusBarInfo->_hFont);
			if ((uMsg != WM_THEMECHANGED) || isControlFont)
			{
				::DefSubclassProc(hWnd, WM_SETFONT, reinterpret_cast<WPARAM>(hFont), FALSE);
			}
			pStatusBarInfo->setFont(hFont);

			if (uMsg != WM_THEMECHANGED)
			{
				return 0;
			}
			break;''')
