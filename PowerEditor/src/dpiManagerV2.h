// This file is part of Notepad++ project
// Copyright (c) 2024 ozone10 and Notepad++ team

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// at your option any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <https://www.gnu.org/licenses/>.


#pragma once
#include <windows.h>

#ifndef WM_DPICHANGED
#define WM_DPICHANGED 0x02E0
#endif

#ifndef WM_DPICHANGED_BEFOREPARENT
#define WM_DPICHANGED_BEFOREPARENT 0x02E2
#endif

#ifndef WM_DPICHANGED_AFTERPARENT
#define WM_DPICHANGED_AFTERPARENT 0x02E3
#endif

#ifndef WM_GETDPISCALEDSIZE
#define WM_GETDPISCALEDSIZE 0x02E4
#endif

class DPIManagerV2
{
public:
	DPIManagerV2() {
		setDpiWithSystem();
	}
	virtual ~DPIManagerV2() = default;

	enum class FontType { menu, status, message, caption, smcaption };

	static void initDpiAPI();

	static int getSystemMetricsForDpi(int nIndex, UINT dpi);
	int getSystemMetricsForDpi(int nIndex) const {
		return getSystemMetricsForDpi(nIndex, _dpi);
	}

	// the metric for the DPI of hWnd with the per-monitor DPI awareness, ::GetSystemMetrics() otherwise
	static int getSystemMetricsForWindow(int nIndex, HWND hWnd);

	[[nodiscard]] static bool isValidDpiAwarenessContext(DPI_AWARENESS_CONTEXT value);
	// includes check for `DPI_AWARENESS_CONTEXT dpiContext` via `isValidDpiAwarenessContext`
	static DPI_AWARENESS_CONTEXT setThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT dpiContext);

	// opt-in per-monitor v2 DPI awareness of the GUI thread, set before any window is created (Windows 10 1703+)
	static bool enablePerMonitorV2ForThread();
	[[nodiscard]] static bool isPerMonitorV2Active();

	static bool adjustWindowRectExForDpi(LPRECT lpRect, DWORD dwStyle, BOOL bMenu, DWORD dwExStyle, UINT dpi);

	static UINT getDpiForSystem();
	static UINT getDpiForWindow(HWND hWnd);
	static UINT getDpiForParent(HWND hWnd) {
		return getDpiForWindow(::GetParent(hWnd));
	}

	void setDpiWithSystem() {
		_dpi = getDpiForSystem();
	}

	// parameter is WPARAM
	void setDpiWP(WPARAM wParam) {
		_dpi = LOWORD(wParam);
	}

	void setDpi(UINT newDpi) {
		_dpi = newDpi;
	}

	void setDpi(HWND hWnd) {
		setDpi(getDpiForWindow(hWnd));
	}

	void setDpiWithParent(HWND hWnd) {
		setDpi(::GetParent(hWnd));
	}

	UINT getDpi() const {
		return _dpi;
	}

	static void setPositionDpi(LPARAM lParam, HWND hWnd, UINT flags = SWP_NOZORDER | SWP_NOACTIVATE);

	static int scale(int x, UINT toDpi, UINT fromDpi) {
		return MulDiv(x, toDpi, fromDpi);
	}

	static int scale(int x, UINT dpi) {
		return scale(x, dpi, USER_DEFAULT_SCREEN_DPI);
	}

	static int unscale(int x, UINT dpi) {
		return scale(x, USER_DEFAULT_SCREEN_DPI, dpi);
	}

	static int scale(int x, HWND hWnd) {
		return scale(x, getDpiForWindow(hWnd), USER_DEFAULT_SCREEN_DPI);
	}

	static int unscale(int x, HWND hWnd) {
		return scale(x, USER_DEFAULT_SCREEN_DPI, getDpiForWindow(hWnd));
	}

	// for the legacy sizes in pixels of the system DPI (not scaled from 96 DPI)
	static int scaleFromSystemDpi(int x, UINT dpi) {
		return scale(x, dpi, getDpiForSystem());
	}

	// x unchanged without the per-monitor DPI awareness (even in a per-monitor DPI aware dialog)
	static int scaleFromSystemDpiForWindow(int x, HWND hWnd) {
		return isPerMonitorV2Active() ? scaleFromSystemDpi(x, getDpiForWindow(hWnd)) : x;
	}

	int scale(int x) const {
		return scale(x, _dpi);
	}

	int unscale(int x) const {
		return unscale(x, _dpi);
	}

	static int scaleFont(int pt, UINT dpi) {
		return -(scale(pt, dpi, 72));
	}

	static int scaleFont(int pt, HWND hWnd) {
		return -(scale(pt, getDpiForWindow(hWnd), 72));
	}

	int scaleFont(int pt) const {
		return scaleFont(pt, _dpi);
	}

	static LOGFONT getDefaultGUIFontForDpi(UINT dpi, FontType type = FontType::message);
	static LOGFONT getDefaultGUIFontForDpi(HWND hWnd, FontType type = FontType::message) {
		return getDefaultGUIFontForDpi(getDpiForWindow(hWnd), type);
	}
	LOGFONT getDefaultGUIFontForDpi(FontType type = FontType::message) const {
		return getDefaultGUIFontForDpi(_dpi, type);
	}

	// default font of the list view, tree view and toolbar controls
	static LOGFONT getIconTitleFontForDpi(UINT dpi);
	// sets a font created from lf to hWnd, then replaces hFont (the previous one, deleted) with it
	static void replaceWindowFont(HWND hWnd, const LOGFONT& lf, HFONT& hFont);

	static void loadIcon(HINSTANCE hinst, const wchar_t* pszName, int cx, int cy, HICON* phico, UINT fuLoad = LR_DEFAULTCOLOR);

	[[nodiscard]] static DWORD getTextScaleFactor();

	[[nodiscard]] static int scaleFontForFactor(int pt, UINT textScaleFactor) {
		static constexpr UINT defaultFontScaleFactor = 100;
		return scale(pt, textScaleFactor, defaultFontScaleFactor);
	}

	[[nodiscard]] static int scaleFontForFactor(int pt) {
		static const int scaleFactor = DPIManagerV2::getTextScaleFactor();
		return scaleFontForFactor(pt, scaleFactor);
	}

private:
	UINT _dpi = USER_DEFAULT_SCREEN_DPI;
};
