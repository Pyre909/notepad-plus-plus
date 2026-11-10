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


#pragma once

#include <string>
#include <vector>
#include "Scintilla.h"

// The font parameters of a Scintilla style: SCI_STYLESETFONT, SCI_STYLESETWEIGHT, SCI_STYLESETSTRETCH and SCI_STYLESETITALIC
struct ScintillaFont
{
	std::wstring _name;
	int _weight = SC_WEIGHT_NORMAL;
	int _stretch = SC_STRETCH_NORMAL;
	bool _isItalic = false;

	bool operator==(const ScintillaFont&) const = default;
};

// The fonts of the font lists are named by their GDI family name, and GDI names a family per weight or stretch beyond
// regular and bold: "Fira Code Light" is the Light weight of the family DirectWrite only knows as "Fira Code", so that
// DirectWrite draws such a name with a fallback font. Returns the font parameters Scintilla draws a font of the font
// lists with, bold and italic as chosen by the user, for a technology (SC_TECHNOLOGY_*):
// - with DirectWrite, the DirectWrite family of the font, with its weight, stretch and style, the bold weight being
//   relative to its weight as GDI emboldens it: the bold of "Fira Code Light" is "Fira Code" SemiBold,
// - with GDI, a GDI family name and weight.
// Pyre909 build: bold is boldWeight for a regular font (Preferences > Fonts), as many steps heavier for a font of another
// weight ("Fira Code Light" bold SemiBold with Bold, Medium with SemiBold)
ScintillaFont getScintillaFont(const std::wstring& fontName, bool isBold, bool isItalic, int technology, int boldWeight = SC_WEIGHT_BOLD);

// Pyre909 build: an OpenType feature of a font, its tag ("ss01") and the font's own name for it if it has one (stylistic
// sets and character variants: "Script variant [italic only]")
struct FontFeature
{
	std::wstring _tag;
	std::wstring _name;
};

// Pyre909 build: the OpenType substitution and positioning features of the fonts of a font family (a name of the font lists),
// all its weights and styles together (a stylistic set can be in the italic fonts only), sorted by tag; none if DirectWrite
// doesn't know it
std::vector<FontFeature> getFontFeatures(const std::wstring& fontName);
