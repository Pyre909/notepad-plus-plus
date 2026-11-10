// This file is part of Notepad++ project
// Copyright (C)2026 Don HO <don.h@free.fr>

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
// along with this program.  If not, see <https://www.gnu.org/licenses/>.


#include "DirectWriteText.h"

#include <d2d1.h>
#include <dwrite_1.h>
#include <wrl/client.h>

#include <algorithm>
#include <array>
#include <cwchar>
#include <map>
#include <string>
#include <string_view>

#include "NppConstants.h"
#include "Parameters.h"

using Microsoft::WRL::ComPtr;

// Pyre909 build: see DirectWriteText.h
namespace
{
	// Windows' font smoothing, read at the first draw after a WM_SETTINGCHANGE (uiTextSettingsChanged)
	struct WindowsSmoothing
	{
		BOOL _isOn = TRUE;
		UINT _type = FE_FONTSMOOTHINGCLEARTYPE;
		UINT _contrast = 0;
		bool _isRead = false;
	};
	WindowsSmoothing windowsSmoothing;

	// A GDI font as text formats are kept for it: no allocation to look one up
	struct UiFontKey
	{
		std::array<wchar_t, LF_FACESIZE> _faceName{};
		LONG _height = 0;
		LONG _weight = 0;
		BYTE _italic = 0;
		BYTE _charSet = 0;

		explicit UiFontKey(const LOGFONT& lf) : _height(lf.lfHeight), _weight(lf.lfWeight), _italic(lf.lfItalic), _charSet(lf.lfCharSet)
		{
			std::copy(std::begin(lf.lfFaceName), std::end(lf.lfFaceName), _faceName.begin());
		}
		auto operator<=>(const UiFontKey&) const = default;
	};

	// A text format of a GDI font, with GDI's line (its height and ascent) and ellipsis
	struct UiTextFormat
	{
		ComPtr<IDWriteTextFormat> _format;
		ComPtr<IDWriteInlineObject> _ellipsis;
		LONG _lineHeight = 0;
	};

	// Direct2D and DirectWrite, loaded when first needed (no factories if they're unavailable), a render target bound to
	// the DCs drawn into, the text formats of the fonts drawn with and the rendering parameters of the settings
	class UiTextRenderer final
	{
	public:
		static UiTextRenderer& instance()
		{
			static UiTextRenderer renderer;
			return renderer;
		}

		bool isAvailable() const { return _d2dFactory && _dwFactory && _gdiInterop; }

		bool draw(HDC hdc, const wchar_t* text, int length, const RECT& rect, UINT format, int& result);

	private:
		UiTextRenderer();

		const UiTextFormat* getFormat(HDC hdc, const LOGFONT& lf);
		bool updateRendering(HMONITOR hMonitor);
		bool bind(HDC hdc, const RECT& bound);

		ComPtr<ID2D1Factory> _d2dFactory;
		ComPtr<IDWriteFactory1> _dwFactory;
		ComPtr<IDWriteGdiInterop> _gdiInterop;
		ComPtr<ID2D1DCRenderTarget> _target;
		ComPtr<ID2D1SolidColorBrush> _brush;
		std::map<UiFontKey, UiTextFormat> _formats;
		std::wstring _localeName;

		// the settings and monitor the rendering parameters were made for, and those of dark and light text
		int _renderingKey = -1;
		HMONITOR _renderingMonitor = nullptr;
		D2D1_TEXT_ANTIALIAS_MODE _antialiasMode = D2D1_TEXT_ANTIALIAS_MODE_DEFAULT;
		ComPtr<IDWriteRenderingParams> _darkTextParams;
		ComPtr<IDWriteRenderingParams> _lightTextParams;
	};

	UiTextRenderer::UiTextRenderer()
	{
		using PFN_D2D1CREATEFACTORY = HRESULT(WINAPI*)(D2D1_FACTORY_TYPE, REFIID, const D2D1_FACTORY_OPTIONS*, void**);
		using PFN_DWRITECREATEFACTORY = HRESULT(WINAPI*)(DWRITE_FACTORY_TYPE, REFIID, IUnknown**);
		HMODULE hD2D = ::LoadLibraryEx(L"d2d1.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
		HMODULE hDWrite = ::LoadLibraryEx(L"dwrite.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
		auto pfnD2D = reinterpret_cast<PFN_D2D1CREATEFACTORY>(reinterpret_cast<INT_PTR>(hD2D ? ::GetProcAddress(hD2D, "D2D1CreateFactory") : nullptr));
		auto pfnDWrite = reinterpret_cast<PFN_DWRITECREATEFACTORY>(reinterpret_cast<INT_PTR>(hDWrite ? ::GetProcAddress(hDWrite, "DWriteCreateFactory") : nullptr));
		if (!pfnD2D || !pfnDWrite ||
			FAILED(pfnD2D(D2D1_FACTORY_TYPE_SINGLE_THREADED, __uuidof(ID2D1Factory), nullptr, reinterpret_cast<void**>(_d2dFactory.GetAddressOf()))) ||
			FAILED(pfnDWrite(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory1), reinterpret_cast<IUnknown**>(_dwFactory.GetAddressOf()))) ||
			FAILED(_dwFactory->GetGdiInterop(_gdiInterop.GetAddressOf())))
		{
			_d2dFactory.Reset();
			_dwFactory.Reset();
			_gdiInterop.Reset();
			return;
		}
		wchar_t localeName[LOCALE_NAME_MAX_LENGTH]{};
		if (::GetUserDefaultLocaleName(localeName, LOCALE_NAME_MAX_LENGTH) > 0)
			_localeName = localeName;
		_localeName = _localeName.substr(0, _localeName.find(L'_')); // "zh-TW_radstr": a sort order DirectWrite doesn't know
	}

	// The text format of the DC's font (selected in it: lf): its DirectWrite font (none for a raster font), its em height and
	// GDI's line, from the DC's text metrics (MM_TEXT: the same for every DC the font is selected in)
	const UiTextFormat* UiTextRenderer::getFormat(HDC hdc, const LOGFONT& lf)
	{
		const UiFontKey key(lf);
		if (const auto it = _formats.find(key); it != _formats.end())
			return it->second._format ? &it->second : nullptr;

		constexpr size_t maxFormats = 32;
		if (_formats.size() >= maxFormats)
			_formats.clear();
		UiTextFormat& format = _formats[key];
		TEXTMETRIC tm{};
		if (!::GetTextMetrics(hdc, &tm))
			return nullptr;
		ComPtr<IDWriteFont> font;
		ComPtr<IDWriteFontFamily> family;
		ComPtr<IDWriteLocalizedStrings> names;
		if (FAILED(_gdiInterop->CreateFontFromLOGFONT(&lf, font.GetAddressOf())) ||
			FAILED(font->GetFontFamily(family.GetAddressOf())) || FAILED(family->GetFamilyNames(names.GetAddressOf())))
			return nullptr;
		UINT32 index = 0;
		BOOL exists = FALSE;
		if (FAILED(names->FindLocaleName(L"en-us", &index, &exists)) || !exists)
			index = 0;
		UINT32 nameLength = 0;
		if (FAILED(names->GetStringLength(index, &nameLength)))
			return nullptr;
		std::wstring familyName(nameLength + 1, L'\0');
		if (FAILED(names->GetString(index, familyName.data(), nameLength + 1)))
			return nullptr;
		familyName.resize(nameLength);

		const FLOAT emHeight = static_cast<FLOAT>(tm.tmHeight - tm.tmInternalLeading);
		ComPtr<IDWriteTextFormat> textFormat;
		if ((emHeight <= 0) || FAILED(_dwFactory->CreateTextFormat(familyName.c_str(), nullptr, font->GetWeight(), font->GetStyle(),
			font->GetStretch(), emHeight, _localeName.c_str(), textFormat.GetAddressOf())))
			return nullptr;
		// one line of GDI's height, its baseline at GDI's ascent: the text where DrawText puts it
		textFormat->SetWordWrapping(DWRITE_WORD_WRAPPING_NO_WRAP);
		textFormat->SetParagraphAlignment(DWRITE_PARAGRAPH_ALIGNMENT_NEAR);
		textFormat->SetLineSpacing(DWRITE_LINE_SPACING_METHOD_UNIFORM, static_cast<FLOAT>(tm.tmHeight), static_cast<FLOAT>(tm.tmAscent));
		_dwFactory->CreateEllipsisTrimmingSign(textFormat.Get(), format._ellipsis.GetAddressOf());
		format._format = textFormat;
		format._lineHeight = tm.tmHeight;
		return &format;
	}

	// The rendering parameters of Preferences > Editing 1's Text Rendering as the editor makes them (ScintillaWin's
	// UpdateRenderingParams, FontRenderingOverrides::Apply): the monitor's parameters, the ClearType Tuner's gamma when
	// ClearType is chosen, the monitor's DirectWrite mode for Automatic, light text with its own gamma when a contrast is
	// chosen. Made again when the settings, Windows' font smoothing or the monitor change.
	bool UiTextRenderer::updateRendering(HMONITOR hMonitor)
	{
		const ScintillaViewParams& svp = NppParameters::getInstance().getSVP();
		if (!windowsSmoothing._isRead)
		{
			windowsSmoothing = {};
			::SystemParametersInfo(SPI_GETFONTSMOOTHING, 0, &windowsSmoothing._isOn, 0);
			::SystemParametersInfo(SPI_GETFONTSMOOTHINGTYPE, 0, &windowsSmoothing._type, 0);
			::SystemParametersInfo(SPI_GETFONTSMOOTHINGCONTRAST, 0, &windowsSmoothing._contrast, 0);
			windowsSmoothing._isRead = true;
		}
		const BOOL isSmoothingOn = windowsSmoothing._isOn;
		const UINT smoothingType = windowsSmoothing._type;
		const UINT windowsContrast = windowsSmoothing._contrast;
		const int key = (((svp._textAntialiasing * 8 + svp._textRenderingMode) * 8 + svp._textContrast) * 2 + (isSmoothingOn ? 1 : 0)) * 4 +
			static_cast<int>(smoothingType & 3) + static_cast<int>(windowsContrast) * 4096;
		if ((key == _renderingKey) && (hMonitor == _renderingMonitor) && _darkTextParams && _lightTextParams)
			return true;

		switch (svp._textAntialiasing)
		{
			case textAntialiasingFollowWindows:
				_antialiasMode = !isSmoothingOn ? D2D1_TEXT_ANTIALIAS_MODE_ALIASED :
					((smoothingType == FE_FONTSMOOTHINGSTANDARD) ? D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE : D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE);
				break;
			case textAntialiasingGrayscale:
				_antialiasMode = D2D1_TEXT_ANTIALIAS_MODE_GRAYSCALE;
				break;
			case textAntialiasingNone:
				_antialiasMode = D2D1_TEXT_ANTIALIAS_MODE_ALIASED;
				break;
			default:
				_antialiasMode = D2D1_TEXT_ANTIALIAS_MODE_CLEARTYPE;
				break;
		}

		ComPtr<IDWriteRenderingParams> monitor;
		ComPtr<IDWriteRenderingParams1> monitor1;
		if (FAILED(_dwFactory->CreateMonitorRenderingParams(hMonitor, monitor.GetAddressOf())) || FAILED(monitor.As(&monitor1)))
			return false;
		const FLOAT monitorGamma = monitor1->GetGamma();
		const bool isClearTypeChosen = (svp._textAntialiasing == textAntialiasingClearType) || (svp._textAntialiasing == textAntialiasingClearTypeLessColor);
		const FLOAT baseGamma = (isClearTypeChosen && (windowsContrast >= 1000) && (windowsContrast <= 2200)) ?
			static_cast<FLOAT>(windowsContrast) / 1000.0f : monitorGamma;

		static constexpr DWRITE_RENDERING_MODE renderingModes[]{ // indexed by textRenderingMode; Automatic: the monitor's
			DWRITE_RENDERING_MODE_DEFAULT, DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL,
			DWRITE_RENDERING_MODE_CLEARTYPE_NATURAL_SYMMETRIC, DWRITE_RENDERING_MODE_CLEARTYPE_GDI_CLASSIC
		};
		const DWRITE_RENDERING_MODE renderingMode = (svp._textRenderingMode == textRenderingModeAutomatic) ? monitor1->GetRenderingMode() :
			renderingModes[std::clamp(static_cast<int>(svp._textRenderingMode), 0, 3)];
		struct Contrast { FLOAT _enhanced; FLOAT _grayscaleEnhanced; FLOAT _lightTextGamma; };
		static constexpr Contrast contrasts[]{ // indexed by textContrast; Follow Windows: the monitor's (see applyTextRenderingSettings)
			{ 0.0f, 0.0f, 0.0f }, { 1.0f, 1.5f, 2.0f }, { 2.0f, 2.5f, 2.2f }, { 3.0f, 3.5f, 2.2f }
		};
		const bool isWindowsContrast = svp._textContrast == textContrastFollowWindows;
		const Contrast& contrast = contrasts[std::clamp(static_cast<int>(svp._textContrast), 0, 3)];
		const FLOAT enhanced = isWindowsContrast ? monitor1->GetEnhancedContrast() : contrast._enhanced;
		const FLOAT grayscaleEnhanced = isWindowsContrast ? monitor1->GetGrayscaleEnhancedContrast() : contrast._grayscaleEnhanced;
		const FLOAT clearTypeLevel = (svp._textAntialiasing == textAntialiasingClearTypeLessColor) ? 0.5f : monitor1->GetClearTypeLevel();
		const FLOAT lightTextGamma = isWindowsContrast ? baseGamma : std::max(baseGamma, std::max(monitorGamma, contrast._lightTextGamma));
		ComPtr<IDWriteRenderingParams1> darkText;
		ComPtr<IDWriteRenderingParams1> lightText;
		if (FAILED(_dwFactory->CreateCustomRenderingParams(baseGamma, enhanced, grayscaleEnhanced, clearTypeLevel, monitor1->GetPixelGeometry(),
				renderingMode, darkText.GetAddressOf())) ||
			FAILED(_dwFactory->CreateCustomRenderingParams(lightTextGamma, enhanced, grayscaleEnhanced, clearTypeLevel, monitor1->GetPixelGeometry(),
				renderingMode, lightText.GetAddressOf())))
			return false;
		_darkTextParams = darkText;
		_lightTextParams = lightText;
		_renderingKey = key;
		_renderingMonitor = hMonitor;
		return true;
	}

	// The render target bound to a part of a DC (it copies the DC's pixels in and out: the text on what's drawn there)
	bool UiTextRenderer::bind(HDC hdc, const RECT& bound)
	{
		if (!_target)
		{
			// software: a few lines of text, no copies to and from the graphics card; no alpha, for ClearType
			const D2D1_RENDER_TARGET_PROPERTIES properties = D2D1::RenderTargetProperties(D2D1_RENDER_TARGET_TYPE_SOFTWARE,
				D2D1::PixelFormat(DXGI_FORMAT_B8G8R8A8_UNORM, D2D1_ALPHA_MODE_IGNORE), 96.0f, 96.0f);
			if (FAILED(_d2dFactory->CreateDCRenderTarget(&properties, _target.GetAddressOf())))
				return false;
			_brush.Reset();
		}
		if (!_brush && FAILED(_target->CreateSolidColorBrush(D2D1::ColorF(0.0f, 0.0f, 0.0f), _brush.GetAddressOf())))
			return false;
		return SUCCEEDED(_target->BindDC(hdc, &bound));
	}

	// Draws in device coordinates (the DC's origins at 0): the rectangle given in them
	bool UiTextRenderer::draw(HDC hdc, const wchar_t* text, int length, const RECT& rect, UINT format, int& result)
	{
		LOGFONT lf{};
		const auto hFont = static_cast<HFONT>(::GetCurrentObject(hdc, OBJ_FONT));
		if (!hFont || (::GetObject(hFont, sizeof(lf), &lf) == 0))
			return false;
		// a font DirectWrite would draw otherwise: rotated (vertical tabs), underlined, struck out, condensed or expanded
		if ((lf.lfEscapement != 0) || (lf.lfOrientation != 0) || lf.lfUnderline || lf.lfStrikeOut || (lf.lfWidth != 0))
			return false;
		const UiTextFormat* pFormat = getFormat(hdc, lf);
		HWND hWnd = ::WindowFromDC(hdc); // none for a memory DC (double buffering): the active window's monitor
		const HMONITOR hMonitor = ::MonitorFromWindow(hWnd ? hWnd : ::GetActiveWindow(), MONITOR_DEFAULTTOPRIMARY);
		if (!pFormat || !updateRendering(hMonitor))
			return false;

		const COLORREF textColor = ::GetTextColor(hdc);
		const FLOAT red = GetRValue(textColor) / 255.0f;
		const FLOAT green = GetGValue(textColor) / 255.0f;
		const FLOAT blue = GetBValue(textColor) / 255.0f;
		const bool isLightText = (0.25f * red + 0.5f * green + 0.25f * blue) >= 0.5f; // as the editor's (SurfaceD2D)

		IDWriteTextFormat* pTextFormat = pFormat->_format.Get();
		pTextFormat->SetTextAlignment((format & DT_CENTER) ? DWRITE_TEXT_ALIGNMENT_CENTER :
			((format & DT_RIGHT) ? DWRITE_TEXT_ALIGNMENT_TRAILING : DWRITE_TEXT_ALIGNMENT_LEADING));
		const DWRITE_TRIMMING trimming{ (format & DT_END_ELLIPSIS) ? DWRITE_TRIMMING_GRANULARITY_CHARACTER : DWRITE_TRIMMING_GRANULARITY_NONE, 0, 0 };
		pTextFormat->SetTrimming(&trimming, (format & DT_END_ELLIPSIS) ? pFormat->_ellipsis.Get() : nullptr);

		// the line where DrawText puts it, in whole pixels
		const LONG lineHeight = pFormat->_lineHeight;
		LONG lineTop = rect.top;
		if (format & DT_VCENTER)
			lineTop = rect.top + (rect.bottom - rect.top - lineHeight) / 2;
		else if (format & DT_BOTTOM)
			lineTop = rect.bottom - lineHeight;
		result = (format & (DT_VCENTER | DT_BOTTOM)) ? (lineTop + lineHeight - rect.top) : lineHeight; // as DrawText's

		// laid out with GDI's widths (GDI-compatible, whole pixels), as Notepad++ and Windows measure this text (tab widths,
		// the caption's tooltip, the status bar's parts): it fits where GDI's fits
		ComPtr<IDWriteTextLayout> layout;
		const FLOAT layoutWidth = static_cast<FLOAT>(std::max<LONG>(rect.right - rect.left, 0));
		if (FAILED(_dwFactory->CreateGdiCompatibleTextLayout(text, static_cast<UINT32>(length), pTextFormat, layoutWidth,
			static_cast<FLOAT>(lineHeight), 1.0f, nullptr, FALSE, layout.GetAddressOf())))
			return false;
		DWRITE_TEXT_METRICS metrics{};
		layout->GetMetrics(&metrics);

		// drawn within the rectangle, or around it with DT_NOCLIP, within what the DC shows
		RECT bound = rect;
		if (format & DT_NOCLIP)
		{
			bound.left = std::min<LONG>(rect.left, rect.left + static_cast<LONG>(metrics.left) - 1);
			bound.right = std::max<LONG>(rect.right, rect.left + static_cast<LONG>(metrics.left + metrics.widthIncludingTrailingWhitespace) + 2);
			bound.top = std::min(rect.top, lineTop);
			bound.bottom = std::max(rect.bottom, lineTop + lineHeight);
		}
		RECT clipBox{};
		if ((::GetClipBox(hdc, &clipBox) == ERROR) || !::IntersectRect(&bound, &bound, &clipBox))
			return true; // nothing shown

		// an opaque background, as DrawText fills it: the text's cells
		if (::GetBkMode(hdc) == OPAQUE)
		{
			RECT cells{ rect.left + static_cast<LONG>(metrics.left), lineTop,
				rect.left + static_cast<LONG>(metrics.left + metrics.widthIncludingTrailingWhitespace + 0.999f), lineTop + lineHeight };
			if (::IntersectRect(&cells, &cells, &bound))
				::ExtTextOut(hdc, 0, 0, ETO_OPAQUE, &cells, nullptr, 0, nullptr);
		}

		for (int attempt = 0; attempt < 2; ++attempt)
		{
			if (!bind(hdc, bound))
				return false;
			_brush->SetColor(D2D1::ColorF(red, green, blue));
			_target->SetTextAntialiasMode(_antialiasMode);
			_target->SetTextRenderingParams(isLightText ? _lightTextParams.Get() : _darkTextParams.Get());
			_target->BeginDraw();
			const D2D1_POINT_2F origin{ static_cast<FLOAT>(rect.left - bound.left), static_cast<FLOAT>(lineTop - bound.top) };
			constexpr auto enableColorFont = static_cast<D2D1_DRAW_TEXT_OPTIONS>(0x00000004); // D2D1_DRAW_TEXT_OPTIONS_ENABLE_COLOR_FONT: emoji
			_target->DrawTextLayout(origin, layout.Get(), _brush.Get(), enableColorFont);
			const HRESULT hr = _target->EndDraw();
			if (hr != static_cast<HRESULT>(D2DERR_RECREATE_TARGET))
				return SUCCEEDED(hr);
			_target.Reset(); // made again, and drawn again
		}
		return false;
	}

	// What drawUiText leaves to DrawText, but for the DC (see drawUiText)
	bool isDrawnByDirectWrite(const wchar_t* text, int length, UINT format)
	{
		const writeTechnologyEngine technology = NppParameters::getInstance().getNppGUI()._writeTechnologyEngine;
		if ((technology == defaultTechnology) || (technology == directWriteTechnologyUnavailable))
			return false; // the editor drawn with GDI: GDI here too

		constexpr UINT unsupported = DT_CALCRECT | DT_EXPANDTABS | DT_TABSTOP | DT_EXTERNALLEADING | DT_INTERNAL | DT_WORDBREAK |
			DT_PATH_ELLIPSIS | DT_WORD_ELLIPSIS | DT_MODIFYSTRING | DT_RTLREADING | DT_EDITCONTROL | DT_HIDEPREFIX | DT_PREFIXONLY;
		if (!(format & DT_SINGLELINE) || (format & unsupported))
			return false;
		// a mnemonic's underline; a tab; a line break, which DrawText doesn't make on a single line and DirectWrite always does
		const std::wstring_view textView(text, static_cast<size_t>(length));
		if ((!(format & DT_NOPREFIX) && (textView.find(L'&') != std::wstring_view::npos)) ||
			(textView.find_first_of(L"\t\r\n\v\f\u0085  ") != std::wstring_view::npos))
			return false;
		return UiTextRenderer::instance().isAvailable();
	}
}

void uiTextSettingsChanged()
{
	windowsSmoothing._isRead = false;
}

int drawUiText(HDC hdc, const wchar_t* text, int length, RECT* rect, UINT format)
{
	if ((hdc == nullptr) || (text == nullptr) || (rect == nullptr))
		return ::DrawText(hdc, text, length, rect, format);
	if (length < 0)
		length = static_cast<int>(std::wcslen(text));
	if ((length == 0) || !isDrawnByDirectWrite(text, length, format))
		return ::DrawText(hdc, text, length, rect, format);

	// a DC whose coordinates are its pixels, left to right, or only shifted (buffered painting moves its origin to the
	// part painted): drawn in its pixels, its origins at 0 meanwhile
	POINT viewportOrigin{};
	POINT windowOrigin{};
	XFORM transform{};
	if ((::GetLayout(hdc) & LAYOUT_RTL) || (::GetMapMode(hdc) != MM_TEXT) || !::GetViewportOrgEx(hdc, &viewportOrigin) || !::GetWindowOrgEx(hdc, &windowOrigin))
		return ::DrawText(hdc, text, length, rect, format);
	if ((::GetGraphicsMode(hdc) == GM_ADVANCED) && (!::GetWorldTransform(hdc, &transform) || (transform.eM11 != 1.0f) ||
		(transform.eM12 != 0.0f) || (transform.eM21 != 0.0f) || (transform.eM22 != 1.0f) || (transform.eDx != 0.0f) || (transform.eDy != 0.0f)))
		return ::DrawText(hdc, text, length, rect, format);
	const POINT offset{ viewportOrigin.x - windowOrigin.x, viewportOrigin.y - windowOrigin.y };
	const bool isShifted = (viewportOrigin.x != 0) || (viewportOrigin.y != 0) || (windowOrigin.x != 0) || (windowOrigin.y != 0);
	if (isShifted)
	{
		::SetViewportOrgEx(hdc, 0, 0, nullptr);
		::SetWindowOrgEx(hdc, 0, 0, nullptr);
	}
	const RECT deviceRect{ rect->left + offset.x, rect->top + offset.y, rect->right + offset.x, rect->bottom + offset.y };
	int result = 0;
	const bool isDrawn = UiTextRenderer::instance().draw(hdc, text, length, deviceRect, format, result);
	if (isShifted)
	{
		::SetViewportOrgEx(hdc, viewportOrigin.x, viewportOrigin.y, nullptr);
		::SetWindowOrgEx(hdc, windowOrigin.x, windowOrigin.y, nullptr);
	}
	return isDrawn ? result : ::DrawText(hdc, text, length, rect, format);
}
