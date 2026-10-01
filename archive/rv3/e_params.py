import sys
sys.path.insert(0, '/tmp/claude-0/-home-user-notepad-plus-plus/a7777ee2-9a03-5e58-a0f7-c6d7e0ee6ba1/scratchpad/rv3')
from myrep import rep

rep('PowerEditor/src/Parameters.cpp', [
('''			int h = NppXml::intAttribute(childNode, "height", FWI_PANEL_WH_DEFAULT);
			const RECT posFromConfig{ x, y, w, h };

			if (!isWindowVisibleOnAnyMonitor(RECT{ x,y,w,h }))
			{
				// reset to adjusted factory defaults
				// (and the panel will automatically be on the current primary monitor due to the x,y == 0,0)
				x = 0;
				y = 0;
				w = _nppGUI._dockingData._minFloatingPanelSize.cx;
				h = _nppGUI._dockingData._minFloatingPanelSize.cy + FWI_PANEL_WH_DEFAULT;
			}

			_nppGUI._dockingData._floatingWindowInfo.emplace_back(cont, x, y, w, h);
			_nppGUI._dockingData._floatingWindowInfo.back()._posFromConfig = posFromConfig;
		}
	}
''',
'''			int h = NppXml::intAttribute(childNode, "height", FWI_PANEL_WH_DEFAULT);

			_nppGUI._dockingData._floatingWindowInfo.emplace_back(cont, x, y, w, h);
		}
	}
	validateFloatingWindowsPositions();
'''),
('''// The positions are validated by feedDockingManager() in the coordinates of the DPI awareness of the loading time (system DPI aware).
// After a switch to the per-monitor DPI awareness, the physical coordinates must be validated instead.
void NppParameters::validateFloatingWindowsPositions()
{
	for (FloatingWindowInfo& fwi : _nppGUI._dockingData._floatingWindowInfo)
	{
		if (isWindowVisibleOnAnyMonitor(fwi._posFromConfig))
		{
			fwi._pos = fwi._posFromConfig;
		}
		else
		{
			// reset to adjusted factory defaults, as feedDockingManager() does
			fwi._pos = RECT{ 0, 0, _nppGUI._dockingData._minFloatingPanelSize.cx, _nppGUI._dockingData._minFloatingPanelSize.cy + FWI_PANEL_WH_DEFAULT };
		}
	}
}
''',
'''// in the coordinates of the current DPI awareness: at load (system DPI aware), again after a switch to the per-monitor one
void NppParameters::validateFloatingWindowsPositions()
{
	for (FloatingWindowInfo& fwi : _nppGUI._dockingData._floatingWindowInfo)
	{
		if (isWindowVisibleOnAnyMonitor(fwi._posFromConfig))
		{
			fwi._pos = fwi._posFromConfig;
		}
		else
		{
			// reset to adjusted factory defaults
			// (and the panel will automatically be on the current primary monitor due to the x,y == 0,0)
			fwi._pos = RECT{ 0, 0, _nppGUI._dockingData._minFloatingPanelSize.cx, _nppGUI._dockingData._minFloatingPanelSize.cy + FWI_PANEL_WH_DEFAULT };
		}
	}
}
'''),
])
