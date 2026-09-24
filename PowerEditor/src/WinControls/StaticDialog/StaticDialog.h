// This file is part of Notepad++ project
// Copyright (C)2024 Don HO <don.h@free.fr>

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

#include <vector>

#include "Window.h"
#include "dpiManagerV2.h"

enum class PosAlign { left, right, top, bottom };

#pragma pack(push, 1)
struct DLGTEMPLATEEX
{
	WORD   dlgVer = 0;
	WORD   signature = 0;
	DWORD  helpID = 0;
	DWORD  exStyle = 0;
	DWORD  style = 0;
	WORD   cDlgItems = 0;
	short  x = 0;
	short  y = 0;
	short  cx = 0;
	short  cy = 0;
	// The structure has more fields but are variable length
	//sz_Or_Ord menu;
	//sz_Or_Ord windowClass;
	//WCHAR  title[titleLen];
	//WORD   pointsize;
	//WORD   weight;
	//BYTE   italic;
	//BYTE   charset;
	//WCHAR  typeface[stringLen];
};
#pragma pack(pop)

class StaticDialog : public Window
{
public :
	~StaticDialog() override;

	virtual void create(int dialogID, bool isRTL = false, bool msgDestParent = true, WORD fontSize = 8);

	virtual bool isCreated() const {
		return (_hSelf != nullptr);
	}

	void getMappedChildRect(HWND hChild, RECT& rcChild) const;
	void getMappedChildRect(int idChild, RECT& rcChild) const;
	void redrawDlgItem(const int nIDDlgItem, bool forceUpdate = false) const;

	void goToCenter(UINT swpFlags = SWP_SHOWWINDOW);
	bool moveForDpiChange();

	void display(bool toShow = true) const override;
	void displayEnhanced(bool toShow) const;

	RECT getViewablePositionRect(RECT testPositionRc) const;

	POINT getTopPoint(HWND hwnd, bool isLeft = true) const;

	bool isCheckedOrNot(int checkControlID) const
	{
		return (BST_CHECKED == ::SendMessage(::GetDlgItem(_hSelf, checkControlID), BM_GETCHECK, 0, 0));
	}

	void setChecked(int checkControlID, bool checkOrNot = true) const
	{
		::SendDlgItemMessage(_hSelf, checkControlID, BM_SETCHECK, checkOrNot ? BST_CHECKED : BST_UNCHECKED, 0);
	}

	void setDpi() {
		_dpiManager.setDpi(_hSelf);
	}

	void setPositionDpi(LPARAM lParam, UINT flags = SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE) {
		DPIManagerV2::setPositionDpi(lParam, _hSelf, flags);
	}

	void destroy() override;

	DPIManagerV2& dpiManager() { return _dpiManager; }

protected:
	RECT _rc{};
	DPIManagerV2 _dpiManager;

	static intptr_t CALLBACK dlgProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam);
	virtual intptr_t CALLBACK run_dlgProc(UINT message, WPARAM wParam, LPARAM lParam) = 0;

	HWND myCreateDialogIndirectParam(int dialogID, bool isRTL, WORD fontSize, DLGPROC myDlgProc = StaticDialog::dlgProc);
	INT_PTR myCreateDialogBoxIndirectParam(int dialogID, bool isRTL, WORD fontSize = 8);
};

// Per-monitor DPI awareness (opt-in): the layout of dialogs (the positions and sizes of their controls, the fonts), saved
// for a DPI to be applied again for another DPI the way the dialog manager lays out a dialog template: fonts of the same
// point size, positions and sizes in the dialog units of the dialog font. Applying it is absolute: the result doesn't
// depend on what the dialog manager may have rescaled already (a child dialog of a window which isn't a dialog, e.g. a
// dialog docked in the main window or in a rebar, only receives WM_DPICHANGED_AFTERPARENT).
class DialogDpiLayout final
{
public:
	DialogDpiLayout() = default;
	DialogDpiLayout(const DialogDpiLayout&) = delete;
	DialogDpiLayout& operator=(const DialogDpiLayout&) = delete;
	~DialogDpiLayout();

	// saves the client size of hDlg, the positions and sizes of its direct children (in its client coordinates) and their
	// fonts, for dpi. Several dialogs (e.g. a dialog and its child dialogs) can be saved, for the same DPI.
	void save(HWND hDlg, UINT dpi);

	bool isSaved() const {
		return _dpi != 0;
	}

	// DPI of the saved layout
	UINT getDpi() const {
		return _dpi;
	}

	// moves and resizes the saved windows, and sets them their font, for dpi
	void apply(UINT dpi);

	// client size of a saved dialog, for the DPI of the last apply() (before it, the saved size)
	SIZE getClientSize(HWND hDlg) const;

private:
	struct SavedFont
	{
		HFONT _hFont = nullptr; // the font when saved, only to recognize a font shared by several windows
		LOGFONT _lf{};
	};

	struct Dlg
	{
		HWND _hDlg = nullptr;
		int _iFont = -1; // index in _fonts of the dialog font, -1 if none
		SIZE _baseUnits{}; // dialog base units of the dialog font for the saved DPI, 0 if unknown (then scaled with the DPI)
		SIZE _size{}; // client size for the saved DPI
		SIZE _sizeForDpi{}; // client size for the last applied DPI
	};

	struct Ctrl
	{
		HWND _hWnd = nullptr;
		size_t _iDlg = 0; // index in _dlgs of its dialog
		RECT _rc{}; // in pixels for the saved DPI
		int _iFont = -1; // index in _fonts, -1 when the font isn't set (child dialog, system font)
	};

	std::vector<SavedFont> _fonts;
	std::vector<Dlg> _dlgs;
	std::vector<Ctrl> _ctrls;
	std::vector<HFONT> _fontsForDpi; // created for the last applied DPI and set to the controls
	UINT _dpi = 0;

	int saveFont(HFONT hFont);
};
