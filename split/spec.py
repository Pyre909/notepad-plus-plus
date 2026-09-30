# Per-PR selection of the -U0 hunks of upstream/master..HEAD (see sub.py). 'all' = the whole HEAD file.
# MANUAL entries are built by mk.py.
NL = 'PowerEditor/installer/nativeLang/'
SPEC = {
    'fs': {
        'PowerEditor/src/MISC/Common/NppConstants.h': '1',
        'PowerEditor/src/WinControls/ColourPicker/WordStyleDlg.cpp': 'all',
    },
    'fw': {
        'scintilla/win32/SurfaceGDI.cxx': 'all',
        'scintilla/win32/SurfaceGDI.h': 'all',
        'scintilla/win32/ScintillaWin.cxx': '0,2',
        'scintilla/win32/SurfaceD2D.cxx': 'MANUAL',
    },
    'tr': {
        'scintilla/include/Scintilla.h': 'all',
        'scintilla/include/ScintillaMessages.h': 'all',
        'scintilla/win32/SurfaceD2D.h': 'all',
        'scintilla/win32/ListBox.cxx': 'all',
        'scintilla/win32/ScintillaWin.cxx': '1,3-18',
        'scintilla/win32/SurfaceD2D.cxx': 'MANUAL',
        'PowerEditor/src/MISC/Common/NppConstants.h': '0',
        'PowerEditor/src/Parameters.cpp': '0,3,4,8,11',
        'PowerEditor/src/Parameters.h': '3',
        'PowerEditor/src/NppBigSwitch.cpp': '0,1',
        'PowerEditor/src/Notepad_plus.cpp': '2',
        'PowerEditor/src/ScintillaComponent/ScintillaEditView.h': '0,1,2,5',
        'PowerEditor/src/ScintillaComponent/ScintillaEditView.cpp': '0,2,3,4,5,6',
        'PowerEditor/src/WinControls/Preference/preferenceDlg.cpp': '0-7,10',
        'PowerEditor/src/WinControls/Preference/preferenceDlg.h': 'all',
        'PowerEditor/src/WinControls/Preference/preference.rc': 'MANUAL',
        'PowerEditor/src/WinControls/Preference/preference_rc.h': '0,1',
        'PowerEditor/src/WinControls/AboutDlg/AboutDlg.cpp': '0',
        NL + 'english.xml': '0,1,2,3,5',
        NL + 'english_customizable.xml': '0,1,2,3,5',
        # the 29 translations: MANUAL (node moves only, see mk.py)
    },
    'dpi': {
        'PowerEditor/src/Parameters.cpp': '1,2,5,6,7,9,10',
        'PowerEditor/src/Parameters.h': '0,1,2,4',
        'PowerEditor/src/NppBigSwitch.cpp': '2,3',
        'PowerEditor/src/Notepad_plus.cpp': '0,1,3-14',
        'PowerEditor/src/ScintillaComponent/ScintillaEditView.h': '3,4,6',
        'PowerEditor/src/ScintillaComponent/ScintillaEditView.cpp': '1,7-12',
        'PowerEditor/src/WinControls/Preference/preferenceDlg.cpp': '8,9',
        'PowerEditor/src/WinControls/Preference/preference.rc': 'MANUAL',
        'PowerEditor/src/WinControls/Preference/preference_rc.h': '2',
        'PowerEditor/src/WinControls/AboutDlg/AboutDlg.cpp': '1-5',
        NL + 'english.xml': '4',
        NL + 'english_customizable.xml': '4',
        # + every other changed file: 'all' (see mk.py)
    },
}
