"""Make settings dirs whose config.xml has 2 floating panels (one visible, one off-screen) and the DPI setting on/off."""
import os
import re
import sys

base = sys.argv[1]  # existing config.xml
for name, pmv2 in (("set-float-off", "no"), ("set-float-on", "yes")):
    out = os.path.join(os.path.dirname(os.path.dirname(base)), name)
    os.makedirs(out, exist_ok=True)
    s = open(base, encoding="utf-8").read()
    s = re.sub(r'perMonitorDpiAwareness="[a-z]+"', 'perMonitorDpiAwareness="%s"' % pmv2, s)
    dock = '''<GUIConfig name="DockingManager" leftWidth="200" rightWidth="200" topHeight="200" bottomHeight="200">
            <FloatingWindow cont="4" x="600" y="300" width="900" height="550" />
            <FloatingWindow cont="5" x="5000" y="5000" width="5300" height="5250" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44084" curr="4" prev="1" isVisible="yes" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44080" curr="5" prev="1" isVisible="yes" />
            <ActiveTabs cont="0" activeTab="-1" />
            <ActiveTabs cont="1" activeTab="-1" />
            <ActiveTabs cont="2" activeTab="-1" />
            <ActiveTabs cont="3" activeTab="-1" />
            <ActiveTabs cont="4" activeTab="0" />
            <ActiveTabs cont="5" activeTab="0" />
        </GUIConfig>'''
    s, n = re.subn(r'<GUIConfig name="DockingManager".*?</GUIConfig>', dock, s, flags=re.S)
    assert n == 1
    open(os.path.join(out, "config.xml"), "w", encoding="utf-8").write(s)
    print(out, pmv2)
