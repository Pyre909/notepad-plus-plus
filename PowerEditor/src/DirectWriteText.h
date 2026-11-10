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

#include <windows.h>

// Pyre909 build: the text Notepad++ draws itself (the tab bar's, the panels' captions and tabs, the status bar's in dark
// mode, the Ctrl+Tab list's) drawn with DirectWrite as the editor's is, with its Text Rendering settings (antialiasing,
// contrast, DirectWrite mode), while the editor is drawn with DirectWrite; laid out with GDI's widths, so that it fits
// where GDI measured it. DrawText's arguments and result: the DC's font, text colour and background mode. What it doesn't
// draw the same way is left to DrawText: GDI rendering, no DirectWrite (Wine), a rotated, underlined, struck out or
// condensed font (vertical tabs), a right-to-left DC, a scaled or transformed DC (a shifted one is drawn), more than one
// line or a line break, '&' prefixes, tabs, word and path ellipses, DT_CALCRECT.
int drawUiText(HDC hdc, const wchar_t* text, int length, RECT* rect, UINT format);
