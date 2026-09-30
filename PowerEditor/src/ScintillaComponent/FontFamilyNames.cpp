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


#include <windows.h>
#include <dwrite.h>
#include <wrl/client.h>
#include <algorithm>
#include <cstdlib>
#include <map>
#include <optional>
#include <vector>
#include "FontFamilyNames.h"

using Microsoft::WRL::ComPtr;

namespace
{
	// A font of a GDI family, by the weight GDI knows it by
	struct GdiFamilyMember
	{
		LONG _weight = 0;
		bool _isItalic = false;
	};

	int CALLBACK enumGdiFamilyMembers(const LOGFONT* plf, const TEXTMETRIC*, DWORD fontType, LPARAM lParam)
	{
		// raster fonts ("Fixedsys") are left out: DirectWrite doesn't know them, and they're drawn as they are
		if ((plf->lfWeight > 0) && !(fontType & RASTER_FONTTYPE))
			reinterpret_cast<std::vector<GdiFamilyMember>*>(lParam)->push_back({ plf->lfWeight, plf->lfItalic != 0 });
		return TRUE;
	}

	// The fonts of a GDI family (none if it's not installed or a raster font), kept for the session as the font lists are
	const std::vector<GdiFamilyMember>& getGdiFamilyMembers(const std::wstring& familyName)
	{
		static std::map<std::wstring, std::vector<GdiFamilyMember>> families;
		auto it = families.find(familyName);
		if (it == families.end())
		{
			std::vector<GdiFamilyMember> members;
			LOGFONT lf{};
			familyName.copy(lf.lfFaceName, LF_FACESIZE - 1);
			lf.lfCharSet = DEFAULT_CHARSET;
			HDC hDC = ::GetDC(nullptr);
			::EnumFontFamiliesEx(hDC, &lf, enumGdiFamilyMembers, reinterpret_cast<LPARAM>(&members), 0);
			::ReleaseDC(nullptr, hDC);
			it = families.emplace(familyName, std::move(members)).first;
		}
		return it->second;
	}

	// The weight of the font of a family closest to a weight, of the italic or upright ones as asked, else of all (0 if none);
	// ties are the lighter weight
	LONG getClosestWeight(const std::vector<GdiFamilyMember>& members, LONG weight, bool isItalic)
	{
		LONG closest = 0;
		for (const bool isAnyStyle : { false, true })
		{
			for (const GdiFamilyMember& member : members)
			{
				if (isAnyStyle || (member._isItalic == isItalic))
				{
					const LONG distance = std::abs(member._weight - weight);
					const LONG closestDistance = std::abs(closest - weight);
					if ((closest == 0) || (distance < closestDistance) || ((distance == closestDistance) && (member._weight < closest)))
						closest = member._weight;
				}
			}
			if (closest != 0)
				break;
		}
		return closest;
	}

	// The weight GDI knows the font of a family closest to a weight by, which may differ from DirectWrite's
	// (a static hairline font: 1 for GDI, 100 for DirectWrite), so that GDI selects it without emboldening it
	int getGdiMemberWeight(const std::wstring& familyName, int weight, bool isItalic)
	{
		const LONG closest = getClosestWeight(getGdiFamilyMembers(familyName), weight, isItalic);
		return (closest != 0) ? closest : weight;
	}

	struct DirectWrite
	{
		ComPtr<IDWriteFactory> _factory;
		ComPtr<IDWriteFontCollection> _systemFonts;
	};

	// DirectWrite, loaded when first needed: null if it's unavailable
	const DirectWrite& getDirectWrite()
	{
		static const DirectWrite directWrite = []() {
			DirectWrite dw;
			using PFN_DWRITECREATEFACTORY = HRESULT(WINAPI*)(DWRITE_FACTORY_TYPE, REFIID, IUnknown**);
			HMODULE hDWrite = ::LoadLibraryEx(L"dwrite.dll", nullptr, LOAD_LIBRARY_SEARCH_SYSTEM32);
			FARPROC proc = hDWrite ? ::GetProcAddress(hDWrite, "DWriteCreateFactory") : nullptr;
			auto pfnCreateFactory = reinterpret_cast<PFN_DWRITECREATEFACTORY>(reinterpret_cast<INT_PTR>(proc));
			if (pfnCreateFactory &&
				SUCCEEDED(pfnCreateFactory(DWRITE_FACTORY_TYPE_SHARED, __uuidof(IDWriteFactory), reinterpret_cast<IUnknown**>(dw._factory.GetAddressOf()))) &&
				FAILED(dw._factory->GetSystemFontCollection(dw._systemFonts.GetAddressOf(), FALSE)))
			{
				dw._systemFonts.Reset();
			}
			return dw;
		}();
		return directWrite;
	}

	// A font as DirectWrite knows it
	struct DWriteFont
	{
		std::wstring _family;
		DWRITE_FONT_WEIGHT _weight = DWRITE_FONT_WEIGHT_NORMAL;
		DWRITE_FONT_STRETCH _stretch = DWRITE_FONT_STRETCH_NORMAL;
		DWRITE_FONT_STYLE _style = DWRITE_FONT_STYLE_NORMAL;
	};

	// The first string (the en-us one if any) of localized strings
	std::wstring getLocalizedString(IDWriteLocalizedStrings* pStrings)
	{
		UINT32 index = 0;
		BOOL exists = FALSE;
		if (FAILED(pStrings->FindLocaleName(L"en-us", &index, &exists)) || !exists)
			index = 0;
		UINT32 length = 0;
		if (FAILED(pStrings->GetStringLength(index, &length)))
			return {};
		std::wstring value(length + 1, L'\0');
		if (FAILED(pStrings->GetString(index, value.data(), length + 1)))
			return {};
		value.resize(length);
		return value;
	}

	// Whether a font has a string, or one GDI truncates to it: GDI family names are at most 31 characters
	// ("Bahnschrift SemiBold SemiConden" for "Bahnschrift SemiBold SemiCondensed")
	bool hasInformationalString(IDWriteFont* pFont, DWRITE_INFORMATIONAL_STRING_ID id, const std::wstring& value)
	{
		ComPtr<IDWriteLocalizedStrings> strings;
		BOOL exists = FALSE;
		if (FAILED(pFont->GetInformationalStrings(id, strings.GetAddressOf(), &exists)) || !exists || !strings)
			return false;
		const bool isTruncated = value.length() == (LF_FACESIZE - 1);
		for (UINT32 i = 0; i < strings->GetCount(); ++i)
		{
			UINT32 length = 0;
			if (SUCCEEDED(strings->GetStringLength(i, &length)) && ((length == value.length()) || (isTruncated && (length > value.length()))))
			{
				std::wstring s(length + 1, L'\0');
				if (SUCCEEDED(strings->GetString(i, s.data(), length + 1)) && (::_wcsnicmp(s.c_str(), value.c_str(), value.length()) == 0))
					return true;
			}
		}
		return false;
	}

	DWriteFont getDWriteFont(IDWriteFont* pFont)
	{
		DWriteFont dwFont;
		ComPtr<IDWriteFontFamily> family;
		ComPtr<IDWriteLocalizedStrings> familyNames;
		if (SUCCEEDED(pFont->GetFontFamily(family.GetAddressOf())) && SUCCEEDED(family->GetFamilyNames(familyNames.GetAddressOf())))
			dwFont._family = getLocalizedString(familyNames.Get());
		dwFont._weight = pFont->GetWeight();
		dwFont._stretch = pFont->GetStretch();
		dwFont._style = pFont->GetStyle();
		return dwFont;
	}

	// The font of a family whose Win32 family name (name ID 1) is a GDI family name: its regular font, else its lightest
	// upright one (the simulated bold and oblique fonts of DirectWrite are ignored)
	void matchFamilyFonts(IDWriteFontFamily* pFamily, const std::wstring& gdiFamilyName, std::optional<DWriteFont>& best, bool& isBestRegular)
	{
		for (UINT32 i = 0; i < pFamily->GetFontCount(); ++i)
		{
			ComPtr<IDWriteFont> font;
			if (FAILED(pFamily->GetFont(i, font.GetAddressOf())) || (font->GetSimulations() != DWRITE_FONT_SIMULATIONS_NONE) ||
				!hasInformationalString(font.Get(), DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES, gdiFamilyName))
				continue;
			const bool isRegular = hasInformationalString(font.Get(), DWRITE_INFORMATIONAL_STRING_WIN32_SUBFAMILY_NAMES, L"Regular");
			const bool isUpright = font->GetStyle() == DWRITE_FONT_STYLE_NORMAL;
			if (!best || (isRegular && !isBestRegular) ||
				(!isBestRegular && isUpright && ((best->_style != DWRITE_FONT_STYLE_NORMAL) || (font->GetWeight() < best->_weight))))
			{
				DWriteFont dwFont = getDWriteFont(font.Get());
				if (!dwFont._family.empty())
				{
					best = std::move(dwFont);
					isBestRegular = isRegular;
				}
			}
		}
	}

	// The DirectWrite font of a GDI family name that DirectWrite doesn't know as a family name, or knows with no font of
	// a regular weight; none for the usual family names, the same for GDI and DirectWrite
	std::optional<DWriteFont> findDWriteFont(const std::wstring& gdiFamilyName)
	{
		IDWriteFontCollection* pSystemFonts = getDirectWrite()._systemFonts.Get();
		UINT32 index = 0;
		BOOL exists = FALSE;
		if (!pSystemFonts || FAILED(pSystemFonts->FindFamilyName(gdiFamilyName.c_str(), &index, &exists)))
			return std::nullopt;

		if (exists)
		{
			// A DirectWrite family name, used as is unless all its upright fonts are much lighter or heavier than regular,
			// or DirectWrite fake-bolds it for the regular weight: its weights are then relative to its font closest to
			// regular, as for GDI (see setGdiFont). E.g. the family of a static font of a weight whose name DirectWrite
			// doesn't parse as one ("X Hairline"), which DirectWrite fake-bolds for the regular weight, or of a semibold
			// font only, whose bold would be drawn as is.
			ComPtr<IDWriteFontFamily> family;
			ComPtr<IDWriteFont> font;
			if (FAILED(pSystemFonts->GetFontFamily(index, family.GetAddressOf())) ||
				FAILED(family->GetFirstMatchingFont(DWRITE_FONT_WEIGHT_NORMAL, DWRITE_FONT_STRETCH_NORMAL, DWRITE_FONT_STYLE_NORMAL, font.GetAddressOf())))
				return std::nullopt;
			const bool isFakeBold = (font->GetSimulations() & DWRITE_FONT_SIMULATIONS_BOLD) != 0;
			std::optional<DWriteFont> regular;
			for (UINT32 i = 0; i < family->GetFontCount(); ++i)
			{
				ComPtr<IDWriteFont> member;
				if (SUCCEEDED(family->GetFont(i, member.GetAddressOf())) &&
					(member->GetSimulations() == DWRITE_FONT_SIMULATIONS_NONE) && (member->GetStyle() == DWRITE_FONT_STYLE_NORMAL))
				{
					const int weight = member->GetWeight();
					const int distance = std::abs(weight - DWRITE_FONT_WEIGHT_NORMAL);
					const int regularDistance = regular ? std::abs(regular->_weight - DWRITE_FONT_WEIGHT_NORMAL) : 0;
					if (!regular || (distance < regularDistance) || ((distance == regularDistance) && (weight < regular->_weight)))
						regular = DWriteFont{ gdiFamilyName, member->GetWeight(), member->GetStretch(), DWRITE_FONT_STYLE_NORMAL };
				}
			}
			constexpr int relativeDistance = 200; // a family whose regular weight is within this of normal is used as is
			if (regular && !isFakeBold && (std::abs(regular->_weight - DWRITE_FONT_WEIGHT_NORMAL) < relativeDistance))
				return std::nullopt;
			return regular;
		}

		// A name GDI doesn't know either (a font not installed) is the Win32 family name of no font
		if (getGdiFamilyMembers(gdiFamilyName).empty())
			return std::nullopt;

		// The fonts whose Win32 family name it is: in the family named by the start of the name first ("MonoLisaCode"
		// for "MonoLisaCode ExtraLight"), else in all the families. Named instances of variable fonts are fonts of their
		// family there too.
		std::optional<DWriteFont> best;
		bool isBestRegular = false;
		for (size_t pos = gdiFamilyName.rfind(L' '); (pos != std::wstring::npos) && (pos > 0); pos = gdiFamilyName.rfind(L' ', pos - 1))
		{
			ComPtr<IDWriteFontFamily> family;
			if (SUCCEEDED(pSystemFonts->FindFamilyName(gdiFamilyName.substr(0, pos).c_str(), &index, &exists)) && exists &&
				SUCCEEDED(pSystemFonts->GetFontFamily(index, family.GetAddressOf())))
			{
				matchFamilyFonts(family.Get(), gdiFamilyName, best, isBestRegular);
				if (best)
					return best;
			}
		}
		for (UINT32 i = 0; (i < pSystemFonts->GetFontFamilyCount()) && !isBestRegular; ++i)
		{
			ComPtr<IDWriteFontFamily> family;
			if (SUCCEEDED(pSystemFonts->GetFontFamily(i, family.GetAddressOf())))
				matchFamilyFonts(family.Get(), gdiFamilyName, best, isBestRegular);
		}
		if (best)
			return best;

		// Else the GDI font mapping of DirectWrite, unless it's a simulation: it emboldens the fonts of a GDI family much
		// lighter than the regular weight asked (e.g. "MonoLisaCode ExtraLight" as a simulated bold of weight 700)
		ComPtr<IDWriteGdiInterop> gdiInterop;
		if (SUCCEEDED(getDirectWrite()._factory->GetGdiInterop(gdiInterop.GetAddressOf())))
		{
			LOGFONT lf{};
			gdiFamilyName.copy(lf.lfFaceName, LF_FACESIZE - 1);
			lf.lfWeight = FW_NORMAL;
			lf.lfCharSet = DEFAULT_CHARSET;
			ComPtr<IDWriteFont> font;
			if (SUCCEEDED(gdiInterop->CreateFontFromLOGFONT(&lf, font.GetAddressOf())) && (font->GetSimulations() == DWRITE_FONT_SIMULATIONS_NONE))
			{
				DWriteFont dwFont = getDWriteFont(font.Get());
				if (!dwFont._family.empty())
					return dwFont;
			}
		}
		return std::nullopt;
	}

	// The DirectWrite fonts of the GDI family names: the font lists, and so the names used, are known at startup,
	// the fonts are kept for the session
	const std::optional<DWriteFont>& getDWriteFontOfGdiFamily(const std::wstring& gdiFamilyName)
	{
		static std::map<std::wstring, std::optional<DWriteFont>> fonts;
		auto it = fonts.find(gdiFamilyName);
		if (it == fonts.end())
			it = fonts.emplace(gdiFamilyName, findDWriteFont(gdiFamilyName)).first;
		return it->second;
	}

	// The weight of the DirectWrite family drawing a weight of a GDI family name, relative to the weight of its font
	// (at most extra black: heavier weights are refused by some DirectWrite implementations, drawing nothing)
	int getRelativeWeight(const DWriteFont& dwFont, int weight)
	{
		return std::clamp(dwFont._weight + weight - SC_WEIGHT_NORMAL, 1, static_cast<int>(DWRITE_FONT_WEIGHT_EXTRA_BLACK));
	}

	// GDI: the Win32 family name and weight of the font DirectWrite draws a GDI family name of a weight with, so that GDI
	// draws the same font, e.g. bold of "Cascadia Code SemiBold" with "Cascadia Code" Bold, as GDI doesn't embolden a
	// variable font's semibold instance
	bool setGdiFontOfDWriteFont(ScintillaFont& font)
	{
		const std::optional<DWriteFont>& dwFont = getDWriteFontOfGdiFamily(font._name);
		IDWriteFontCollection* pSystemFonts = getDirectWrite()._systemFonts.Get();
		if (!dwFont || !pSystemFonts)
			return false;
		UINT32 index = 0;
		BOOL exists = FALSE;
		ComPtr<IDWriteFontFamily> family;
		ComPtr<IDWriteFont> drawnFont;
		const DWRITE_FONT_STYLE style = font._isItalic ? DWRITE_FONT_STYLE_ITALIC : dwFont->_style;
		if (FAILED(pSystemFonts->FindFamilyName(dwFont->_family.c_str(), &index, &exists)) || !exists ||
			FAILED(pSystemFonts->GetFontFamily(index, family.GetAddressOf())) ||
			FAILED(family->GetFirstMatchingFont(static_cast<DWRITE_FONT_WEIGHT>(getRelativeWeight(*dwFont, font._weight)), dwFont->_stretch, style, drawnFont.GetAddressOf())))
			return false;
		if ((font._weight > SC_WEIGHT_NORMAL) && (drawnFont->GetSimulations() == DWRITE_FONT_SIMULATIONS_NONE) && (drawnFont->GetWeight() <= dwFont->_weight))
			return false; // no heavier font for bold: GDI emboldens the font of the name (see setGdiFont)

		ComPtr<IDWriteLocalizedStrings> names;
		exists = FALSE;
		if (FAILED(drawnFont->GetInformationalStrings(DWRITE_INFORMATIONAL_STRING_WIN32_FAMILY_NAMES, names.GetAddressOf(), &exists)) || !exists || !names)
			return false;
		std::wstring name = getLocalizedString(names.Get());
		if (name.empty())
			return false;
		if (name.length() >= LF_FACESIZE)
			name.resize(LF_FACESIZE - 1); // truncated as GDI does
		font._name = name;
		font._isItalic = drawnFont->GetStyle() != DWRITE_FONT_STYLE_NORMAL;
		if (drawnFont->GetSimulations() & DWRITE_FONT_SIMULATIONS_BOLD)
			font._weight = drawnFont->GetWeight(); // of its simulation: GDI emboldens it too
		else
			font._weight = getGdiMemberWeight(name, drawnFont->GetWeight(), font._isItalic);
		return true;
	}

	// GDI: the weights of a family are relative to its regular weight, as with DirectWrite. GDI family names of a weight
	// ("Fira Code Light", "Cascadia Code SemiBold") are drawn with the font DirectWrite draws. Else the weight asked of the
	// family is relative to its regular weight: GDI emboldens a font by simulation only when the weight asked is much
	// heavier than its weight, so the regular weight asked for the family of a light weight would draw it as a fake bold.
	// Bold is never asked lighter than bold: some GDI implementations (Wine) embolden only for a heavy weight asked.
	void setGdiFont(ScintillaFont& font)
	{
		// the weight of the family's regular font: its upright font of weight closest to normal
		const std::vector<GdiFamilyMember>& members = getGdiFamilyMembers(font._name);
		const LONG regular = getClosestWeight(members, FW_NORMAL, false);
		const bool hasHeavierFont = std::any_of(members.begin(), members.end(), [regular](const GdiFamilyMember& member) { return member._weight > regular; });
		if ((regular <= 0) || ((regular == FW_NORMAL) && ((font._weight <= FW_NORMAL) || hasHeavierFont)))
			return; // the usual case, a family of regular weight with its bold: GDI's own weights

		if (setGdiFontOfDWriteFont(font))
			return;

		const int relative = regular + font._weight - FW_NORMAL;
		font._weight = std::clamp((font._weight > FW_NORMAL) ? std::max(relative, font._weight) : relative, 1, 999);
	}
}

ScintillaFont getScintillaFont(const std::wstring& fontName, bool isBold, bool isItalic, int technology)
{
	ScintillaFont font{ fontName, isBold ? SC_WEIGHT_BOLD : SC_WEIGHT_NORMAL, SC_STRETCH_NORMAL, isItalic };
	if (fontName.empty() || (fontName.length() >= LF_FACESIZE))
		return font; // not a GDI family name

	if (technology == SC_TECHNOLOGY_DEFAULT)
	{
		setGdiFont(font);
	}
	else if (const std::optional<DWriteFont>& dwFont = getDWriteFontOfGdiFamily(fontName))
	{
		font._name = dwFont->_family;
		font._weight = getRelativeWeight(*dwFont, font._weight);
		font._stretch = dwFont->_stretch;
		font._isItalic = isItalic || (dwFont->_style != DWRITE_FONT_STYLE_NORMAL);
	}
	return font;
}
