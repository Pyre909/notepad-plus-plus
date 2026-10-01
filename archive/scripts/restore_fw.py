import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
root = sys.argv[1]
f = root + '/PowerEditor/src/ScintillaComponent/ScintillaEditView.cpp'
rep(f, '''void ScintillaEditView::applyTextRenderingSettings() const
{''', '''// DirectWrite font quality matching the Windows "Smooth edges of screen fonts" & ClearType settings
static int getSystemFontQuality()
{
	BOOL isFontSmoothingOn = FALSE;
	if (!::SystemParametersInfo(SPI_GETFONTSMOOTHING, 0, &isFontSmoothingOn, 0))
		return SC_EFF_QUALITY_DEFAULT;

	if (!isFontSmoothingOn)
		return SC_EFF_QUALITY_NON_ANTIALIASED;

	UINT fontSmoothingType = 0;
	if (!::SystemParametersInfo(SPI_GETFONTSMOOTHINGTYPE, 0, &fontSmoothingType, 0))
		return SC_EFF_QUALITY_DEFAULT;

	// DirectWrite's default quality draws ClearType with the monitor's parameters, as Notepad++ always did
	// (SC_EFF_QUALITY_LCD_OPTIMIZED would use the ClearType Tuner gamma of GDI: the "ClearType" setting)
	return (fontSmoothingType == FE_FONTSMOOTHINGCLEARTYPE) ? SC_EFF_QUALITY_DEFAULT : SC_EFF_QUALITY_ANTIALIASED;
}

void ScintillaEditView::applyTextRenderingSettings() const
{''')
rep(f, '''		default: // textAntialiasingFollowWindows: the default quality, as Notepad++ always did
			// (GDI follows the Windows font smoothing, DirectWrite uses the monitor's ClearType parameters)
			break;
	}''', '''		default: // textAntialiasingFollowWindows
			// GDI's default quality already follows the Windows font smoothing, DirectWrite's default antialiasing
			// ignores it (smoothing off or Standard), so DirectWrite gets the Windows setting explicitly
			fontQuality = (execute(SCI_GETTECHNOLOGY) == SC_TECHNOLOGY_DEFAULT) ? SC_EFF_QUALITY_DEFAULT : getSystemFontQuality();
	}''')
f = root + '/PowerEditor/src/NppBigSwitch.cpp'
rep(f, '''			ScintillaEditView::sendMessageToAll(WM_SETTINGCHANGE, wParam, lParam);

			return ::DefWindowProc(hwnd, message, wParam, lParam);''', '''			ScintillaEditView::sendMessageToAll(WM_SETTINGCHANGE, wParam, lParam);

			// keep the "Follow Windows" text antialiasing in sync with the Windows font smoothing (Scintilla updates the other parameters)
			if ((wParam == SPI_SETFONTSMOOTHING || wParam == SPI_SETFONTSMOOTHINGTYPE) &&
				(nppParam.getSVP()._textAntialiasing == textAntialiasingFollowWindows))
			{
				ScintillaEditView::applyTextRenderingSettingsToAll();
			}

			return ::DefWindowProc(hwnd, message, wParam, lParam);''')
