// This file is part of Notepad++ project
// Copyright (C)2021 Don HO <don.h@free.fr>

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


#include "ansiCharPanel.h"

#include <iterator>

#include "ScintillaEditView.h"
#include "localization.h"

using namespace std;

// default widths of the columns (Value, Hex, Character, HTML Name, HTML Decimal, HTML Hexadecimal), for 96 DPI
static constexpr int columnWidths[] = { 45, 45, 70, 90, 100, 120 };

AnsiCharPanel::~AnsiCharPanel()
{
	if (_hFontDpi != nullptr)
		::DeleteObject(_hFontDpi);
}

void AnsiCharPanel::switchEncoding()
{
	int codepage = (*_ppEditView)->getCurrentBuffer()->getEncoding();
	_listView.resetValues(codepage);
}

intptr_t CALLBACK AnsiCharPanel::run_dlgProc(UINT message, WPARAM wParam, LPARAM lParam)
{
	switch (message)
	{
		case WM_INITDIALOG :
		{
			NppParameters& nppParam = NppParameters::getInstance();
			NativeLangSpeaker *pNativeSpeaker = nppParam.getNativeLangSpeaker();
			wstring valStr = pNativeSpeaker->getAttrNameStr(L"Value", "AsciiInsertion", "ColumnVal");
			wstring hexStr = pNativeSpeaker->getAttrNameStr(L"Hex", "AsciiInsertion", "ColumnHex");
			wstring charStr = pNativeSpeaker->getAttrNameStr(L"Character", "AsciiInsertion", "ColumnChar");
			wstring htmlNameStr = pNativeSpeaker->getAttrNameStr(L"HTML Name", "AsciiInsertion", "ColumnHtmlName");
			wstring htmlNumberStr = pNativeSpeaker->getAttrNameStr(L"HTML Decimal", "AsciiInsertion", "ColumnHtmlNumber");
			wstring htmlHexNbStr = pNativeSpeaker->getAttrNameStr(L"HTML Hexadecimal", "AsciiInsertion", "ColumnHtmlHexNb");

			StaticDialog::setDpi();

			_listView.addColumn(columnInfo(valStr, _dpiManager.scale(columnWidths[0])));
			_listView.addColumn(columnInfo(hexStr, _dpiManager.scale(columnWidths[1])));
			_listView.addColumn(columnInfo(charStr, _dpiManager.scale(columnWidths[2])));
			_listView.addColumn(columnInfo(htmlNameStr, _dpiManager.scale(columnWidths[3])));
			_listView.addColumn(columnInfo(htmlNumberStr, _dpiManager.scale(columnWidths[4])));
			_listView.addColumn(columnInfo(htmlHexNbStr, _dpiManager.scale(columnWidths[5])));

			_listView.init(_hInst, _hSelf);

			// the default font of the list view is for the system DPI
			if (DPIManagerV2::isPerMonitorV2Active() && (_dpiManager.getDpi() != DPIManagerV2::getDpiForSystem()))
			{
				DPIManagerV2::replaceWindowFont(_listView.getHSelf(), DPIManagerV2::getIconTitleFontForDpi(_dpiManager.getDpi()), _hFontDpi);
			}

			int codepage = (*_ppEditView)->getCurrentBuffer()->getEncoding();
			_listView.setValues(codepage==-1?0:codepage);
			_listView.display();

			NppDarkMode::autoSubclassAndThemeChildControls(_hSelf);
			NppDarkMode::autoSubclassAndThemeWindowNotify(_hSelf);

			return TRUE;
		}

		case NPPM_INTERNAL_REFRESHDARKMODE:
		{
			NppDarkMode::autoThemeChildControls(_hSelf);
			return TRUE;
		}

		case WM_NOTIFY:
		{
			switch (reinterpret_cast<LPNMHDR>(lParam)->code)
			{
				case DMN_CLOSE:
				{
					::SendMessage(_hParent, WM_COMMAND, IDM_EDIT_CHAR_PANEL, 0);

					return TRUE;
				}

				case NM_DBLCLK:
				{
					LPNMITEMACTIVATE lpnmitem = (LPNMITEMACTIVATE) lParam;
					LVHITTESTINFO pInfo{};
					pInfo.pt = lpnmitem->ptAction;
					ListView_SubItemHitTest(_listView.getHSelf(), &pInfo);

					int i = pInfo.iItem;
					int j = pInfo.iSubItem;
					wchar_t buffer[10]{};
					LVITEM item{};
					item.mask = LVIF_TEXT | LVIF_PARAM;
					item.iItem = i;
					item.iSubItem = j;
					item.cchTextMax = 10;
					item.pszText = buffer;
					ListView_GetItem(_listView.getHSelf(), &item);

					if (i == -1)
						return TRUE;

					if (j != 2)
						insertString(item.pszText);
					else
						insertChar(static_cast<unsigned char>(i));
					
					return TRUE;
				}

				case LVN_KEYDOWN:
				{
					switch (((LPNMLVKEYDOWN)lParam)->wVKey)
					{
						case VK_RETURN:
						{
							int i = _listView.getSelectedIndex();

							if (i == -1)
								return TRUE;

							insertChar(static_cast<unsigned char>(i));
							return TRUE;
						}
						default:
							break;
					}
				}
				break;

				default:
					break;
			}
		}
		return TRUE;

		case WM_SIZE:
		{
			checkDpiChange();

			int width = LOWORD(lParam);
			int height = HIWORD(lParam);
			::MoveWindow(_listView.getHSelf(), 0, 0, width, height, TRUE);
			break;
		}

		default :
			return DockingDlgInterface::run_dlgProc(message, wParam, lParam);
	}
	return DockingDlgInterface::run_dlgProc(message, wParam, lParam);
}

void AnsiCharPanel::onDpiChanged(UINT prevDpi)
{
	HWND hList = _listView.getHSelf();
	if (hList == nullptr)
		return;

	const UINT dpi = _dpiManager.getDpi();

	// the list view sizes its header and its rows with its font
	DPIManagerV2::replaceWindowFont(hList, DPIManagerV2::getIconTitleFontForDpi(dpi), _hFontDpi);

	// the columns: the default width for the new DPI, or the width set by the user rescaled
	const int nbColumns = static_cast<int>(std::size(columnWidths));
	for (int i = 0; i < nbColumns; ++i)
	{
		const int width = ListView_GetColumnWidth(hList, i);
		const int newWidth = (width == DPIManagerV2::scale(columnWidths[i], prevDpi)) ?
			DPIManagerV2::scale(columnWidths[i], dpi) : DPIManagerV2::scale(width, dpi, prevDpi);
		ListView_SetColumnWidth(hList, i, newWidth);
	}

	_listView.redraw(true);
}

void AnsiCharPanel::insertChar(unsigned char char2insert) const
{
	char charStr[2]{};
	charStr[0] = char2insert;
	charStr[1] = '\0';
	wchar_t wCharStr[10]{};
	char multiByteStr[10]{};
	int codepage = (*_ppEditView)->getCurrentBuffer()->getEncoding();
	if (codepage == -1)
	{
		bool isUnicode = ((*_ppEditView)->execute(SCI_GETCODEPAGE) == SC_CP_UTF8);
		if (isUnicode)
		{
			MultiByteToWideChar(0, 0, charStr, -1, wCharStr, _countof(wCharStr));
			WideCharToMultiByte(CP_UTF8, 0, wCharStr, -1, multiByteStr, sizeof(multiByteStr), NULL, NULL);
		}
		else // ANSI
		{
			multiByteStr[0] = charStr[0];
			multiByteStr[1] = charStr[1];
		}
	}
	else
	{
		MultiByteToWideChar(codepage, 0, charStr, -1, wCharStr, _countof(wCharStr));
		WideCharToMultiByte(CP_UTF8, 0, wCharStr, -1, multiByteStr, sizeof(multiByteStr), NULL, NULL);
	}
	(*_ppEditView)->execute(SCI_REPLACESEL, 0, reinterpret_cast<LPARAM>(""));
	size_t len = (char2insert < 128) ? 1 : strlen(multiByteStr);
	(*_ppEditView)->execute(SCI_ADDTEXT, len, reinterpret_cast<LPARAM>(multiByteStr));
	(*_ppEditView)->grabFocus();
}

void AnsiCharPanel::insertString(LPWSTR string2insert) const
{
	char multiByteStr[10]{};
	int codepage = (*_ppEditView)->getCurrentBuffer()->getEncoding();
	if (codepage == -1)
	{
		bool isUnicode = ((*_ppEditView)->execute(SCI_GETCODEPAGE) == SC_CP_UTF8);
		if (isUnicode)
		{
			WideCharToMultiByte(CP_UTF8, 0, string2insert, -1, multiByteStr, sizeof(multiByteStr), NULL, NULL);
		}
		else // ANSI
		{
			wcstombs(multiByteStr, string2insert, 10);
		}
	}
	else
	{
		WideCharToMultiByte(CP_UTF8, 0, string2insert, -1, multiByteStr, sizeof(multiByteStr), NULL, NULL);
	}

	(*_ppEditView)->execute(SCI_REPLACESEL, 0, reinterpret_cast<LPARAM>(""));
	size_t len = strlen(multiByteStr);
	(*_ppEditView)->execute(SCI_ADDTEXT, len, reinterpret_cast<LPARAM>(multiByteStr));
	(*_ppEditView)->grabFocus();
}
