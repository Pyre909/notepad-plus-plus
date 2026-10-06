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

	// The fonts of a GDI family (none if it's not installed or a raster font)
	std::vector<GdiFamilyMember> getGdiFamilyMembers(const std::wstring& familyName)
	{
		std::vector<GdiFamilyMember> members;
		LOGFONT lf{};
		familyName.copy(lf.lfFaceName, LF_FACESIZE - 1);
		lf.lfCharSet = DEFAULT_CHARSET;
		HDC hDC = ::GetDC(nullptr);
		::EnumFontFamiliesEx(hDC, &lf, enumGdiFamilyMembers, reinterpret_cast<LPARAM>(&members), 0);
		::ReleaseDC(nullptr, hDC);
		return members;
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
		if (dwFont._family.empty() || (dwFont._stretch < DWRITE_FONT_STRETCH_ULTRA_CONDENSED) || (dwFont._stretch > DWRITE_FONT_STRETCH_ULTRA_EXPANDED))
			return std::nullopt; // not a font DirectWrite can be asked for by these parameters
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

	// The weight of the DirectWrite family drawing a weight of a GDI family name, relative to the weight of its font: bold
	// is 300 heavier, as bold is to regular, about as heavy as GDI emboldens a light or medium font (bold of "Fira Code
	// Light" is "Fira Code" SemiBold); at most extra black, the heaviest weight (DirectWrite refuses weights above 999,
	// Scintilla bug #2520)
	int getRelativeWeight(const DWriteFont& dwFont, int weight)
	{
		return std::clamp(static_cast<int>(dwFont._weight) + weight - SC_WEIGHT_NORMAL, 1, static_cast<int>(DWRITE_FONT_WEIGHT_EXTRA_BLACK));
	}
}

ScintillaFont getScintillaFont(const std::wstring& fontName, bool isBold, bool isItalic, int technology)
{
	ScintillaFont font{ fontName, isBold ? SC_WEIGHT_BOLD : SC_WEIGHT_NORMAL, SC_STRETCH_NORMAL, isItalic };
	if (fontName.empty() || (fontName.length() >= LF_FACESIZE))
		return font; // not a GDI family name
	if (technology == SC_TECHNOLOGY_DEFAULT)
		return font; // GDI knows its family names

	if (const std::optional<DWriteFont>& dwFont = getDWriteFontOfGdiFamily(fontName))
	{
		font._name = dwFont->_family;
		font._weight = getRelativeWeight(*dwFont, font._weight);
		font._stretch = dwFont->_stretch;
		font._isItalic = isItalic || (dwFont->_style != DWRITE_FONT_STYLE_NORMAL);
	}
	return font;
}
