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
#include <tuple>
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

	// The font of a GDI family closest to a weight, of the italic or upright ones as asked, else of all (weight 0 if none);
	// ties are the lighter weight
	GdiFamilyMember getClosestMember(const std::vector<GdiFamilyMember>& members, LONG weight, bool isItalic)
	{
		GdiFamilyMember closest;
		for (const bool isAnyStyle : { false, true })
		{
			for (const GdiFamilyMember& member : members)
			{
				if (isAnyStyle || (member._isItalic == isItalic))
				{
					const LONG distance = std::abs(member._weight - weight);
					const LONG closestDistance = std::abs(closest._weight - weight);
					if ((closest._weight == 0) || (distance < closestDistance) || ((distance == closestDistance) && (member._weight < closest._weight)))
						closest = member;
				}
			}
			if (closest._weight != 0)
				break;
		}
		return closest;
	}

	struct DirectWrite
	{
		ComPtr<IDWriteFactory> _factory;
		ComPtr<IDWriteFontCollection> _systemFonts;
		ComPtr<IDWriteGdiInterop> _gdiInterop;
	};

	// DirectWrite, loaded when first needed: no system fonts if it's unavailable
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
				(FAILED(dw._factory->GetSystemFontCollection(dw._systemFonts.GetAddressOf(), FALSE)) ||
				FAILED(dw._factory->GetGdiInterop(dw._gdiInterop.GetAddressOf()))))
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

	// The DirectWrite font of a GDI family name DirectWrite doesn't know as a family name; none for the usual family names,
	// the same for both, and for the names of no installed font. It's the font the GDI mapping of DirectWrite gives for the
	// regular font of the GDI family (its upright font of weight closest to normal), asked at the weight and style GDI
	// knows it by so that it's not a bold or oblique simulation of it.
	std::optional<DWriteFont> findDWriteFont(const std::wstring& gdiFamilyName)
	{
		const DirectWrite& directWrite = getDirectWrite();
		UINT32 index = 0;
		BOOL exists = FALSE;
		if (!directWrite._systemFonts || FAILED(directWrite._systemFonts->FindFamilyName(gdiFamilyName.c_str(), &index, &exists)) || exists)
			return std::nullopt;

		const GdiFamilyMember regular = getClosestMember(getGdiFamilyMembers(gdiFamilyName), FW_NORMAL, false);
		if (regular._weight == 0)
			return std::nullopt;

		LOGFONT lf{};
		gdiFamilyName.copy(lf.lfFaceName, LF_FACESIZE - 1);
		lf.lfWeight = regular._weight;
		lf.lfItalic = regular._isItalic ? TRUE : FALSE;
		lf.lfCharSet = DEFAULT_CHARSET;
		ComPtr<IDWriteFont> font;
		ComPtr<IDWriteFontFamily> family;
		ComPtr<IDWriteLocalizedStrings> familyNames;
		if (FAILED(directWrite._gdiInterop->CreateFontFromLOGFONT(&lf, font.GetAddressOf())) ||
			(font->GetSimulations() != DWRITE_FONT_SIMULATIONS_NONE) ||
			FAILED(font->GetFontFamily(family.GetAddressOf())) || FAILED(family->GetFamilyNames(familyNames.GetAddressOf())))
			return std::nullopt;

		DWriteFont dwFont{ getLocalizedString(familyNames.Get()), font->GetWeight(), font->GetStretch(), font->GetStyle() };
		if (dwFont._family.empty())
			return std::nullopt;
		return dwFont;
	}

	// The DirectWrite fonts of the GDI family names, kept for the session as the font lists are
	const std::optional<DWriteFont>& getDWriteFontOfGdiFamily(const std::wstring& gdiFamilyName)
	{
		static std::map<std::wstring, std::optional<DWriteFont>> fonts;
		auto it = fonts.find(gdiFamilyName);
		if (it == fonts.end())
			it = fonts.emplace(gdiFamilyName, findDWriteFont(gdiFamilyName)).first;
		return it->second;
	}

	// The weight of the DirectWrite family drawing a weight of a GDI family name, relative to the weight of its font as GDI
	// emboldens it: bold of "Fira Code Light" is "Fira Code" SemiBold; at most extra black, the heaviest weight (DirectWrite
	// refuses weights above 999, Scintilla bug #2520)
	int getRelativeWeight(const DWriteFont& dwFont, int weight)
	{
		return std::clamp(static_cast<int>(dwFont._weight) + weight - SC_WEIGHT_NORMAL, 1, static_cast<int>(DWRITE_FONT_WEIGHT_EXTRA_BLACK));
	}

	// Pyre909 build: GDI draws the fonts of a weight with the fonts DirectWrite draws (see getGdiFont)

	// The weight GDI knows the font of a family closest to a weight by, which may differ from DirectWrite's (a static
	// hairline font), so that GDI selects it without emboldening it
	int getGdiMemberWeight(const std::wstring& familyName, int weight, bool isItalic)
	{
		const LONG closest = getClosestMember(getGdiFamilyMembers(familyName), weight, isItalic)._weight;
		return (closest != 0) ? closest : weight;
	}

	// The GDI family name and weight of the font DirectWrite draws a font of the font lists with, e.g. bold of
	// "Cascadia Code SemiBold" with "Cascadia Code" Bold, as GDI doesn't embolden a variable font's semibold instance
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
			return false; // no heavier font for bold: GDI emboldens the font of the name

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

	// The GDI font parameters of a font of the font lists, bold and italic as chosen. The weights of a family are relative
	// to its regular weight, as with DirectWrite: the fonts of a GDI family of a weight ("Fira Code Light", "Cascadia Code
	// SemiBold") are drawn with the font DirectWrite draws, else the weight is relative, as GDI emboldens a font asked much
	// heavier than it is (the regular weight asked for a light family would draw it as a fake bold). A style that isn't
	// bold keeps at most the normal weight so that it isn't read as bold (SCI_STYLEGETBOLD): GDI draws its font anyway.
	ScintillaFont findGdiFont(const ScintillaFont& requested)
	{
		ScintillaFont font = requested;
		const bool isBold = font._weight > SC_WEIGHT_NORMAL;
		const std::vector<GdiFamilyMember>& members = getGdiFamilyMembers(font._name);
		const LONG regular = getClosestMember(members, FW_NORMAL, false)._weight;
		const bool hasHeavierFont = std::any_of(members.begin(), members.end(), [regular](const GdiFamilyMember& member) { return member._weight > regular; });
		if ((regular <= 0) || ((regular == FW_NORMAL) && (!isBold || hasHeavierFont)))
			return font; // the usual case, a family of regular weight with its bold: GDI's own weights

		if (!setGdiFontOfDWriteFont(font))
		{
			// bold is never asked lighter than bold: some GDI implementations (Wine) embolden only for a heavy weight asked
			const int relative = regular + font._weight - FW_NORMAL;
			font._weight = std::clamp(isBold ? std::max(relative, font._weight) : relative, 1, 999);
		}
		if (!isBold)
			font._weight = std::min(font._weight, static_cast<int>(SC_WEIGHT_NORMAL));
		return font;
	}

	// The GDI font parameters of the fonts of the font lists, kept for the session as the font lists are
	const ScintillaFont& getGdiFont(const ScintillaFont& requested)
	{
		static std::map<std::tuple<std::wstring, int, bool>, ScintillaFont> fonts;
		const auto key = std::make_tuple(requested._name, requested._weight, requested._isItalic);
		auto it = fonts.find(key);
		if (it == fonts.end())
			it = fonts.emplace(key, findGdiFont(requested)).first;
		return it->second;
	}
}

ScintillaFont getScintillaFont(const std::wstring& fontName, bool isBold, bool isItalic, int technology)
{
	ScintillaFont font{ fontName, isBold ? SC_WEIGHT_BOLD : SC_WEIGHT_NORMAL, SC_STRETCH_NORMAL, isItalic };
	if (fontName.empty() || (fontName.length() >= LF_FACESIZE))
		return font; // not a GDI family name
	if (technology == SC_TECHNOLOGY_DEFAULT)
		return getGdiFont(font); // Pyre909 build: the fonts of a weight drawn with the fonts DirectWrite draws

	if (const std::optional<DWriteFont>& dwFont = getDWriteFontOfGdiFamily(fontName))
	{
		font._name = dwFont->_family;
		font._weight = getRelativeWeight(*dwFont, font._weight);
		font._stretch = dwFont->_stretch;
		font._isItalic = isItalic || (dwFont->_style != DWRITE_FONT_STYLE_NORMAL);
	}
	return font;
}
