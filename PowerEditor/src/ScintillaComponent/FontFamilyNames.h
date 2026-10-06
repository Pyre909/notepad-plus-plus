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
ScintillaFont getScintillaFont(const std::wstring& fontName, bool isBold, bool isItalic, int technology);
