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
#include <ranges>
#include <set>
#include <string>
#include <tuple>
#include <utility>
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
		auto distance = [weight](const GdiFamilyMember& m) { return std::pair(std::abs(m._weight - weight), m._weight); };
		auto sameStyle = members | std::views::filter([isItalic](const GdiFamilyMember& m) { return m._isItalic == isItalic; });
		if (const auto it = std::ranges::min_element(sameStyle, {}, distance); it != sameStyle.end())
			return *it;
		if (const auto it = std::ranges::min_element(members, {}, distance); it != members.end())
			return *it;
		return {};
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
		if (dwFont._family.empty() || (dwFont._family.length() >= LF_FACESIZE) // Scintilla copies the name into a LOGFONT too
			|| (dwFont._stretch < DWRITE_FONT_STRETCH_ULTRA_CONDENSED) || (dwFont._stretch > DWRITE_FONT_STRETCH_ULTRA_EXPANDED))
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
		const std::vector<GdiFamilyMember> members = getGdiFamilyMembers(font._name);
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

	// Pyre909 build: whether a bold weight draws a family heavier than its regular font: Medium of a family of Regular and
	// Bold (Consolas) is its Regular. With DirectWrite, as it matches weights (Medium of Cascadia Code, a variable font, is
	// its SemiBold); with GDI, the family's font of the closest weight (findGdiFont: Cascadia Code's Regular, GDI's family
	// being Regular and Bold), or DirectWrite's for a family of a weight ("Fira Code Light", drawn with DirectWrite's
	// font). True if the family isn't known: as asked.
	bool isBoldWeightHeavier(const std::wstring& fontName, int weight, bool isItalic, bool isGdi)
	{
		static std::map<std::tuple<std::wstring, int, bool, bool>, bool> answers;
		const auto key = std::make_tuple(fontName, weight, isItalic, isGdi);
		if (const auto it = answers.find(key); it != answers.end())
			return it->second;

		bool isHeavier = true;
		const std::optional<DWriteFont>& dwFont = getDWriteFontOfGdiFamily(fontName);
		if (isGdi && !dwFont)
		{
			const std::vector<GdiFamilyMember> members = getGdiFamilyMembers(fontName);
			const LONG regularWeight = getClosestMember(members, FW_NORMAL, isItalic)._weight;
			isHeavier = (regularWeight <= 0) || (getClosestMember(members, weight, isItalic)._weight > regularWeight);
			answers.emplace(key, isHeavier);
			return isHeavier;
		}

		IDWriteFontCollection* pSystemFonts = getDirectWrite()._systemFonts.Get();
		const DWriteFont regular = dwFont ? *dwFont : DWriteFont{ fontName };
		const DWRITE_FONT_STYLE style = isItalic ? DWRITE_FONT_STYLE_ITALIC : regular._style;
		const auto boldWeight = static_cast<DWRITE_FONT_WEIGHT>(getRelativeWeight(regular, weight));
		UINT32 index = 0;
		BOOL exists = FALSE;
		ComPtr<IDWriteFontFamily> family;
		ComPtr<IDWriteFont> regularFont;
		ComPtr<IDWriteFont> boldFont;
		if (pSystemFonts && SUCCEEDED(pSystemFonts->FindFamilyName(regular._family.c_str(), &index, &exists)) && exists &&
			SUCCEEDED(pSystemFonts->GetFontFamily(index, family.GetAddressOf())) &&
			SUCCEEDED(family->GetFirstMatchingFont(regular._weight, regular._stretch, style, regularFont.GetAddressOf())) &&
			SUCCEEDED(family->GetFirstMatchingFont(boldWeight, regular._stretch, style, boldFont.GetAddressOf())))
		{
			isHeavier = (boldFont->GetWeight() > regularFont->GetWeight()) || (boldFont->GetSimulations() & DWRITE_FONT_SIMULATIONS_BOLD);
		}
		answers.emplace(key, isHeavier);
		return isHeavier;
	}
}

ScintillaFont getScintillaFont(const std::wstring& fontName, bool isBold, bool isItalic, int technology, int boldWeight)
{
	// Pyre909 build: a bold weight lighter than bold that would draw the regular font is bold
	if (isBold && (boldWeight < SC_WEIGHT_BOLD) && !fontName.empty() && (fontName.length() < LF_FACESIZE) &&
		!isBoldWeightHeavier(fontName, boldWeight, isItalic, technology == SC_TECHNOLOGY_DEFAULT))
		boldWeight = SC_WEIGHT_BOLD;

	ScintillaFont font{ fontName, isBold ? boldWeight : SC_WEIGHT_NORMAL, SC_STRETCH_NORMAL, isItalic };
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

// Pyre909 build: the OpenType features of a font family, read from its fonts' GSUB and GPOS tables, the names of the
// stylistic sets and character variants from their name tables
namespace
{
	// A big-endian 16-bit value of a font table, false past its end
	bool readU16(const BYTE* data, UINT32 size, size_t offset, UINT16& value)
	{
		if ((data == nullptr) || (offset + 2 > size))
			return false;
		value = static_cast<UINT16>((data[offset] << 8) | data[offset + 1]);
		return true;
	}

	// A table of a font face, released with it
	class FontTable
	{
	public:
		FontTable(IDWriteFontFace* face, UINT32 tag) : _face(face)
		{
			BOOL exists = FALSE;
			if (FAILED(face->TryGetFontTable(tag, reinterpret_cast<const void**>(&_data), &_size, &_context, &exists)) || !exists)
			{
				_data = nullptr;
				_size = 0;
			}
		}
		~FontTable()
		{
			if (_context != nullptr)
				_face->ReleaseFontTable(_context);
		}
		FontTable(const FontTable&) = delete;
		FontTable& operator=(const FontTable&) = delete;

		const BYTE* data() const { return _data; }
		UINT32 size() const { return _size; }

	private:
		IDWriteFontFace* _face = nullptr;
		const BYTE* _data = nullptr;
		UINT32 _size = 0;
		void* _context = nullptr;
	};

	// A string of a name table, the Windows platform's (Unicode), English (United States) first; empty if none
	std::wstring getNameTableString(const FontTable& names, UINT16 nameId)
	{
		const BYTE* data = names.data();
		const UINT32 size = names.size();
		UINT16 count = 0;
		UINT16 stringOffset = 0;
		if (!readU16(data, size, 2, count) || !readU16(data, size, 4, stringOffset))
			return {};
		std::wstring found;
		bool isEnglish = false;
		for (UINT16 i = 0; i < count; ++i)
		{
			const size_t record = 6 + static_cast<size_t>(i) * 12;
			UINT16 platform = 0;
			UINT16 encoding = 0;
			UINT16 language = 0;
			UINT16 id = 0;
			UINT16 length = 0;
			UINT16 offset = 0;
			if (!readU16(data, size, record, platform) || !readU16(data, size, record + 2, encoding) ||
				!readU16(data, size, record + 4, language) || !readU16(data, size, record + 6, id) ||
				!readU16(data, size, record + 8, length) || !readU16(data, size, record + 10, offset))
				break;
			if ((id != nameId) || (platform != 3) || ((encoding != 1) && (encoding != 10)) || (!found.empty() && (isEnglish || (language != 0x409))))
				continue;
			const size_t start = static_cast<size_t>(stringOffset) + offset;
			if (start + length > size)
				continue;
			found.clear();
			for (size_t j = 0; j + 1 < length; j += 2)
				found.push_back(static_cast<wchar_t>((data[start + j] << 8) | data[start + j + 1]));
			isEnglish = (language == 0x409);
		}
		return found;
	}

	// The features of a GSUB or GPOS table, a stylistic set or character variant with its name (its feature parameters'
	// name ID) if it has one
	void addFeatures(const FontTable& layout, const FontTable& names, std::map<std::wstring, std::wstring>& features)
	{
		const BYTE* data = layout.data();
		const UINT32 size = layout.size();
		UINT16 featureList = 0;
		UINT16 count = 0;
		if (!readU16(data, size, 6, featureList) || (featureList == 0) || !readU16(data, size, featureList, count))
			return; // no feature list (offset 0)
		for (UINT16 i = 0; i < count; ++i)
		{
			const size_t record = static_cast<size_t>(featureList) + 2 + static_cast<size_t>(i) * 6;
			UINT16 featureOffset = 0;
			if (!readU16(data, size, record + 4, featureOffset))
				break;
			std::wstring tag;
			for (size_t j = 0; j < 4; ++j)
				tag.push_back(static_cast<wchar_t>(data[record + j])); // in the table: record + 4 was read
			while (!tag.empty() && (tag.back() == L' '))
				tag.pop_back();
			if (tag.empty() || !std::all_of(tag.begin(), tag.end(), [](wchar_t ch) { return (ch > 0x20) && (ch <= 0x7E); }))
				continue;
			std::wstring& name = features[tag];
			const size_t feature = static_cast<size_t>(featureList) + featureOffset;
			UINT16 params = 0;
			UINT16 nameId = 0;
			if (name.empty() && (tag.starts_with(L"ss") || tag.starts_with(L"cv")) && readU16(data, size, feature, params) &&
				(params != 0) && readU16(data, size, feature + params + 2, nameId) && (nameId != 0))
				name = getNameTableString(names, nameId);
		}
	}
}

std::vector<FontFeature> getFontFeatures(const std::wstring& fontName)
{
	const DirectWrite& dw = getDirectWrite();
	if (!dw._systemFonts || fontName.empty())
		return {};
	const ScintillaFont font = getScintillaFont(fontName, false, false, SC_TECHNOLOGY_DIRECTWRITE);
	UINT32 index = 0;
	BOOL exists = FALSE;
	ComPtr<IDWriteFontFamily> family;
	if (FAILED(dw._systemFonts->FindFamilyName(font._name.c_str(), &index, &exists)) || !exists ||
		FAILED(dw._systemFonts->GetFontFamily(index, family.GetAddressOf())))
		return {};

	// kept for the session, as the font lists are: read again at each showing of Preferences > Fonts otherwise
	static std::map<std::wstring, std::vector<FontFeature>> familyFeatures;
	if (const auto it = familyFeatures.find(font._name); it != familyFeatures.end())
		return it->second;

	std::map<std::wstring, std::wstring> features;
	std::set<std::string> facesRead; // a font file's face read once: a variable font's named instances share it
	constexpr UINT32 maxFonts = 64; // MonoLisa: 20 (10 weights, upright and italic)
	const UINT32 fontCount = std::min(family->GetFontCount(), maxFonts);
	for (UINT32 i = 0; i < fontCount; ++i)
	{
		ComPtr<IDWriteFont> dwFont;
		ComPtr<IDWriteFontFace> face;
		if (FAILED(family->GetFont(i, dwFont.GetAddressOf())) || (dwFont->GetSimulations() != DWRITE_FONT_SIMULATIONS_NONE) ||
			FAILED(dwFont->CreateFontFace(face.GetAddressOf())))
			continue;
		UINT32 fileCount = 1;
		ComPtr<IDWriteFontFile> file;
		const void* fileKey = nullptr;
		UINT32 fileKeySize = 0;
		if (SUCCEEDED(face->GetFiles(&fileCount, file.GetAddressOf())) && file && SUCCEEDED(file->GetReferenceKey(&fileKey, &fileKeySize)))
		{
			std::string faceKey(static_cast<const char*>(fileKey), fileKeySize);
			faceKey += std::to_string(face->GetIndex());
			if (!facesRead.insert(std::move(faceKey)).second)
				continue;
		}
		const FontTable names(face.Get(), DWRITE_MAKE_OPENTYPE_TAG('n', 'a', 'm', 'e'));
		addFeatures(FontTable(face.Get(), DWRITE_MAKE_OPENTYPE_TAG('G', 'S', 'U', 'B')), names, features);
		addFeatures(FontTable(face.Get(), DWRITE_MAKE_OPENTYPE_TAG('G', 'P', 'O', 'S')), names, features);
	}
	std::vector<FontFeature> result;
	for (auto& [tag, name] : features)
		result.push_back({ tag, name });
	familyFeatures.emplace(font._name, result);
	return result;
}
