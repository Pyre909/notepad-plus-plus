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


#pragma once

#include <windows.h>

#include <vector>

#include "Buffer.h"
#include "ImageListSet.h"
#include "NppConstants.h"
#include "ScintillaEditView.h"
#include "TabBar.h"
#include "Window.h"
#include "resource.h"

// file state icons of the tabs (also used by the Document List)
inline constexpr int docTabIconIDs[] = { IDI_SAVED_ICON, IDI_UNSAVED_ICON, IDI_READONLY_ICON, IDI_READONLYSYS_ICON, IDI_MONITORING_ICON };
inline constexpr int docTabIconIDs_darkMode[] = { IDI_SAVED_DM_ICON, IDI_UNSAVED_DM_ICON, IDI_READONLY_DM_ICON, IDI_READONLYSYS_DM_ICON, IDI_MONITORING_DM_ICON };
inline constexpr int docTabIconIDs_alt[] = { IDI_SAVED_ALT_ICON, IDI_UNSAVED_ALT_ICON, IDI_READONLY_ALT_ICON, IDI_READONLYSYS_ALT_ICON, IDI_MONITORING_ICON };


class DocTabView : public TabBarPlus
{
public:
	DocTabView() : TabBarPlus(), _pView(nullptr) {}
	~DocTabView() override {}

	void init(HINSTANCE hInst, HWND parent, ScintillaEditView * pView, unsigned char indexChoice, unsigned char buttonsStatus);

	void createIconSets();

	void changeIconSet(unsigned char choice) {
		if (choice >= _pIconListVector.size())
			return;
		_iconListIndexChoice = choice;
		TabBar::setImageList(_pIconListVector[_iconListIndexChoice]->getHandle());
	}

	void addBuffer(BufferID buffer);
	void closeBuffer(BufferID buffer);
	void bufferUpdated(const Buffer* buffer, int mask);

	bool activateBuffer(BufferID buffer);

	BufferID activeBuffer();
	BufferID findBufferByName(const wchar_t * fullfilename);	//-1 if not found, something else otherwise

	int getIndexByBuffer(BufferID id);
	BufferID getBufferByIndex(size_t index);

	void setBuffer(size_t index, BufferID id);

	void reSizeTo(RECT & rc) override;

	void resizeIconsDpi() {
		// resized in place: the Document List can share them
		const int newSize = dpiManager().scale(g_TabIconSize);
		for (IconList* const i : _pIconListVector)
		{
			i->resize(newSize);
		}

		if (_iconListIndexChoice < 0 || static_cast<size_t>(_iconListIndexChoice) >= _pIconListVector.size())
			_iconListIndexChoice = 0;

		TabBar::setImageList(_pIconListVector[_iconListIndexChoice]->getHandle());
	}

	const ScintillaEditView* getScintillaEditView() const {
		return _pView;
	}

	static void setIndividualTabColour(BufferID bufferId, int colorId);
	int getIndividualTabColourId(int tabIndex) override;
	
	HIMAGELIST getImgLst(UINT index) {
		if (index >= _pIconListVector.size())
			index = 0;
		return _pIconListVector[index]->getHandle();
	}

private :
	ScintillaEditView *_pView = nullptr;

	IconList _docTabIconList;
	IconList _docTabIconListAlt;
	IconList _docTabIconListDarkMode;

	std::vector<IconList *> _pIconListVector;
	int _iconListIndexChoice = -1;

	using Window::init;
	using TabBar::init;
};
