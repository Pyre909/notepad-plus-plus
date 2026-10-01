import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad')
from edit import rep
f = 'PowerEditor/src/ScintillaComponent/ScintillaEditView.cpp'
rep(f, '''// DirectWrite font quality matching the Windows "Smooth edges of screen fonts" & ClearType settings
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

''', '')
rep(f, '''		default: // textAntialiasingFollowWindows
			// GDI's default quality already follows the system setting (and Xft/fontconfig under WINE),
			// DirectWrite's default antialiasing doesn't reliably, so it gets the system setting explicitly
			fontQuality = (execute(SCI_GETTECHNOLOGY) == SC_TECHNOLOGY_DEFAULT) ? SC_EFF_QUALITY_DEFAULT : getSystemFontQuality();
	}''', '''		default: // textAntialiasingFollowWindows: the default quality, as Notepad++ always did
			// (GDI follows the Windows font smoothing, DirectWrite uses the monitor's ClearType parameters)
			break;
	}''')
rep(f, '''	// DirectWrite's enhanced contrast only darkens dark text (it's reduced to nothing for light text),
	// light text (on dark themes) gets heavier with a higher gamma, which would make dark text lighter:
	// so light text gets its own gamma, never lower than the monitor's one (0) even with the Windows setting,
	// as the ClearType gamma of Windows (1.2-1.4) makes light text thinner than the monitor's one (1.8-2.2)
	struct TextContrastParams
	{
		int _enhancedContrast = SC_FONTRENDERING_DEFAULT;          // in hundredths, for ClearType
		int _grayscaleEnhancedContrast = SC_FONTRENDERING_DEFAULT; // in hundredths, for grayscale antialiasing
		int _lightTextGamma = 0;                                   // in thousandths, 0: monitor's gamma
	};
	static constexpr TextContrastParams textContrastParams[]{ // indexed by textContrast
		{},                 // textContrastWindows
''', '''	// DirectWrite's enhanced contrast only darkens dark text (it's reduced to nothing for light text),
	// light text (on dark themes) gets heavier with a higher gamma, which would make dark text lighter:
	// so the higher contrasts give light text its own gamma
	struct TextContrastParams
	{
		int _enhancedContrast = SC_FONTRENDERING_DEFAULT;          // in hundredths, for ClearType
		int _grayscaleEnhancedContrast = SC_FONTRENDERING_DEFAULT; // in hundredths, for grayscale antialiasing
		int _lightTextGamma = SC_FONTRENDERING_DEFAULT;            // in thousandths
	};
	static constexpr TextContrastParams textContrastParams[]{ // indexed by textContrast
		{},                 // textContrastWindows: the Windows parameters, as Notepad++ always did
''')
f = 'PowerEditor/src/NppBigSwitch.cpp'
rep(f, '''			ScintillaEditView::sendMessageToAll(WM_SETTINGCHANGE, wParam, lParam);

			// keep the "Follow Windows" text antialiasing in sync with the Windows font smoothing (Scintilla updates the other parameters)
			if ((wParam == SPI_SETFONTSMOOTHING || wParam == SPI_SETFONTSMOOTHINGTYPE) &&
				(nppParam.getSVP()._textAntialiasing == textAntialiasingFollowWindows))
			{
				ScintillaEditView::applyTextRenderingSettingsToAll();
			}
''', '''			ScintillaEditView::sendMessageToAll(WM_SETTINGCHANGE, wParam, lParam);
''')
