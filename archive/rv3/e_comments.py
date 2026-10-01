import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/WinControls/DocumentMap/documentMap.cpp', [
('''		// per-monitor DPI awareness (opt-in): a floating map can be on a monitor whose DPI isn't the DPI of the edit view,
		// the texts of both are scaled for their DPI
''',
'''		// a floating map can have another DPI than the edit view, the texts of both are scaled for their DPI
'''),
('''	// Per-monitor DPI awareness (opt-in): the map view, a child of this dialog, receives WM_DPICHANGED_AFTERPARENT after it
	// and scales its text for the new DPI: the wrapping of the map and the view zone are computed again afterwards, also after
	// the relayout of a docked map (the main window has posted NPPM_INTERNAL_DPICHANGEDRELAYOUT before)
''',
'''	// the map view gets WM_DPICHANGED_AFTERPARENT after this dialog: the map is wrapped again afterwards,
	// also after the relayout of a docked map (NPPM_INTERNAL_DPICHANGEDRELAYOUT has been posted before)
'''),
])

rep('PowerEditor/src/ScintillaComponent/UserDefineDialog.cpp', [
('''    // Per-monitor DPI awareness (opt-in): docked, the dialog has the DPI of the main window (it can have been floating on a monitor of another DPI)
''',
'''    // docked, the dialog has the DPI of the main window (it can have been floating on a monitor of another DPI)
'''),
('''            // Per-monitor DPI awareness (opt-in): layout of the dialog and of its tabs (not scrolled) for its DPI
''',
'''            // layout of the dialog and of its tabs (not scrolled) for its DPI
'''),
('''            // Per-monitor DPI awareness (opt-in): docked, the dialog is a child of the main window, whose DPI has changed
''',
'''            // docked, the dialog is a child of the main window, whose DPI has changed
'''),
])

rep('PowerEditor/src/ScintillaComponent/UserDefineDialog.h', [
('''	// Per-monitor DPI awareness (opt-in): layout of the dialog and of its tabs for the DPI it was created with,
	// the docked dialog (a child of the main window) follows the DPI changes of the main window
''',
'''	// per-monitor DPI awareness: layout of the dialog and of its tabs for the DPI it was created with
'''),
])

rep('PowerEditor/src/ScintillaComponent/FindReplaceDlg.cpp', [
('''	// Per-monitor DPI awareness (opt-in): layout of the dialog for its DPI, to follow the DPI changes of the main window
''',
'''	// layout of the dialog for its DPI, to follow the DPI changes of the main window
'''),
('''			// Per-monitor DPI awareness (opt-in): the DPI of the main window has changed
''',
'''			// the DPI of the main window has changed
'''),
('''	// the window is scaled for the DPI of the caller window: with the per-monitor DPI awareness of the GUI thread,
	// this thread must be per-monitor DPI aware too, otherwise its window would be scaled twice
''',
'''	// the window is scaled for the DPI of the caller window: like the GUI thread, otherwise it would be scaled twice
'''),
])

rep('PowerEditor/src/ScintillaComponent/FindReplaceDlg.h', [
('''	// Per-monitor DPI awareness (opt-in): layout of the dialog for the DPI it was created with,
	// the dialog (in the bottom rebar of the main window) follows the DPI changes of the main window
''',
'''	// per-monitor DPI awareness: layout of the dialog (in the rebar of the main window) for the DPI it was created with
'''),
])
