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


#include "dpiManagerV2.h"

#include <windows.h>

#include <commctrl.h>

#include <string_view>

// Pyre909 build: Windows 10 version 1809 or later: the DPI functions of user32 (Windows 10 1607) are called directly,
// not looked up at run time with fallbacks for older Windows

static bool _isPerMonitorV2Active = false;

int DPIManagerV2::getSystemMetricsForDpi(int nIndex, UINT dpi)
{
	return ::GetSystemMetricsForDpi(nIndex, dpi);
}

int DPIManagerV2::getSystemMetricsForWindow(int nIndex, HWND hWnd)
{
	// a window that isn't per-monitor DPI aware has the system DPI: the metrics Windows scales for the process
	const UINT dpi = getDpiForWindow(hWnd);
	return (dpi == getDpiForSystem()) ? ::GetSystemMetrics(nIndex) : getSystemMetricsForDpi(nIndex, dpi);
}

bool DPIManagerV2::isValidDpiAwarenessContext(DPI_AWARENESS_CONTEXT value)
{
	return ::IsValidDpiAwarenessContext(value) == TRUE;
}

DPI_AWARENESS_CONTEXT DPIManagerV2::setThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT dpiContext)
{
	if (DPIManagerV2::isValidDpiAwarenessContext(dpiContext))
	{
		return ::SetThreadDpiAwarenessContext(dpiContext);
	}
	return nullptr;
}

bool DPIManagerV2::enablePerMonitorV2ForThread()
{
	if (DPIManagerV2::setThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2) != nullptr)
	{
		_isPerMonitorV2Active = true;
	}
	return _isPerMonitorV2Active;
}

bool DPIManagerV2::isPerMonitorV2Active()
{
	return _isPerMonitorV2Active;
}

DPI_AWARENESS_CONTEXT DPIManagerV2::getWindowDpiAwarenessContext(HWND hWnd)
{
	if (hWnd != nullptr)
	{
		return ::GetWindowDpiAwarenessContext(hWnd);
	}
	return nullptr;
}

bool DPIManagerV2::adjustWindowRectExForDpi(LPRECT lpRect, DWORD dwStyle, BOOL bMenu, DWORD dwExStyle, UINT dpi)
{
	return ::AdjustWindowRectExForDpi(lpRect, dwStyle, bMenu, dwExStyle, dpi) == TRUE;
}

UINT DPIManagerV2::getDpiForSystem()
{
	return ::GetDpiForSystem();
}

UINT DPIManagerV2::getDpiForWindow(HWND hWnd)
{
	if (hWnd != nullptr)
	{
		if (const auto dpi = ::GetDpiForWindow(hWnd); dpi > 0)
		{
			return dpi;
		}
	}
	return DPIManagerV2::getDpiForSystem();
}

void DPIManagerV2::setPositionDpi(LPARAM lParam, HWND hWnd, UINT flags)
{
	const auto prcNewWindow = reinterpret_cast<RECT*>(lParam);

	::SetWindowPos(hWnd,
		nullptr,
		prcNewWindow->left,
		prcNewWindow->top,
		prcNewWindow->right - prcNewWindow->left,
		prcNewWindow->bottom - prcNewWindow->top,
		flags);
}

LOGFONT DPIManagerV2::getDefaultGUIFontForDpi(UINT dpi, FontType type)
{
	LOGFONT lf{};
	NONCLIENTMETRICS ncm{};
	ncm.cbSize = sizeof(NONCLIENTMETRICS);

	if (::SystemParametersInfoForDpi(SPI_GETNONCLIENTMETRICS, sizeof(NONCLIENTMETRICS), &ncm, 0, dpi) == TRUE)
	{
		switch (type)
		{
			case FontType::menu:
			{
				lf = ncm.lfMenuFont;
				break;
			}

			case FontType::status:
			{
				lf = ncm.lfStatusFont;
				break;
			}

			case FontType::message:
			{
				lf = ncm.lfMessageFont;
				break;
			}

			case FontType::caption:
			{
				lf = ncm.lfCaptionFont;
				break;
			}

			case FontType::smcaption:
			{
				lf = ncm.lfSmCaptionFont;
				break;
			}
		}
	}
	else // should not happen, fallback
	{
		auto* hf = static_cast<HFONT>(::GetStockObject(DEFAULT_GUI_FONT));
		::GetObjectW(hf, sizeof(LOGFONT), &lf);
		lf.lfHeight = scaleFont(lf.lfHeight, dpi);
	}

	return lf;
}

LOGFONT DPIManagerV2::getIconTitleFontForDpi(UINT dpi)
{
	LOGFONT lf{};
	if (::SystemParametersInfoForDpi(SPI_GETICONTITLELOGFONT, sizeof(LOGFONT), &lf, 0, dpi) == TRUE)
	{
		return lf;
	}
	return getDefaultGUIFontForDpi(dpi); // should not happen, fallback
}

void DPIManagerV2::replaceWindowFont(HWND hWnd, const LOGFONT& lf, UniqueFont& font)
{
	if (UniqueFont newFont{ ::CreateFontIndirect(&lf) })
	{
		::SendMessage(hWnd, WM_SETFONT, reinterpret_cast<WPARAM>(newFont.get()), TRUE);
		font = std::move(newFont); // the previous one deleted
	}
}

LOGFONT DPIManagerV2::getDefaultGUIFontForDpi(UINT dpi, WORD fontSize, FontType type)
{
	auto lf = getDefaultGUIFontForDpi(dpi, type);
	lf.lfHeight = scaleFont(fontSize, dpi);
	return lf;
}

void DPIManagerV2::loadIcon(HINSTANCE hinst, const wchar_t* pszName, int cx, int cy, HICON* phico, UINT fuLoad)
{
	if (::LoadIconWithScaleDown(hinst, pszName, cx, cy, phico) != S_OK)
	{
		*phico = static_cast<HICON>(::LoadImage(hinst, pszName, IMAGE_ICON, cx, cy, fuLoad));
	}
}

DWORD DPIManagerV2::getTextScaleFactor()
{
	static constexpr DWORD defaultVal = 100;
	DWORD data = defaultVal;
	DWORD dwBufSize = sizeof(data);
	static constexpr LPCWSTR lpSubKey = L"Software\\Microsoft\\Accessibility";
	static constexpr LPCWSTR lpValue = L"TextScaleFactor";

	if (::RegGetValueW(HKEY_CURRENT_USER, lpSubKey, lpValue, RRF_RT_REG_DWORD, nullptr, &data, &dwBufSize) == ERROR_SUCCESS)
	{
		return data;
	}
	return defaultVal;
}

static TEXTMETRIC getFontMetrics(HWND hWnd, HFONT hFont)
{
	HDC hdc = ::GetDC(hWnd);
	auto hOldFont = ::SelectObject(hdc, hFont);

	TEXTMETRIC tm{};
	::GetTextMetricsW(hdc, &tm);

	::SelectObject(hdc, hOldFont);
	::ReleaseDC(hWnd, hdc);

	return tm;
}

int DPIManagerV2::getFontAdjustedHeight(HWND hWnd, HFONT hFont) noexcept
{
	const TEXTMETRIC tm = getFontMetrics(hWnd, hFont);
	return tm.tmHeight + tm.tmExternalLeading + 4;
}

int DPIManagerV2::getFontHeight(HWND hWnd, HFONT hFont) noexcept
{
	return getFontMetrics(hWnd, hFont).tmHeight;
}

static int getFontAvgWidth(HWND hWnd, HFONT hFont, std::wstring_view str)
{
	HDC hdc = ::GetDC(hWnd);
	auto hOldFont = ::SelectObject(hdc, hFont);

	SIZE sz{};

	const auto len = static_cast<int>(str.length());
	::GetTextExtentPoint32W(hdc, str.data(), len, &sz);

	::SelectObject(hdc, hOldFont);
	::ReleaseDC(hWnd, hdc);

	return (sz.cx / (len / 2) + 1) / 2;
}

int DPIManagerV2::getFontAvgAlphaWidth(HWND hWnd, HFONT hFont) noexcept
{
	static constexpr std::wstring_view alpha = L"abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ";
	return getFontAvgWidth(hWnd, hFont, alpha);
}

int DPIManagerV2::getFontDigitWidth(HWND hWnd, HFONT hFont) noexcept
{
	static constexpr std::wstring_view digit = L"1234567890";
	return getFontAvgWidth(hWnd, hFont, digit);
}

