"""Make the settings dirs from seed-set/config.xml: set-docked (Document List left, Character Panel right, Clipboard History
bottom) and set-float (Document List and Character Panel floating, Clipboard History bottom), with the Path column of the
Document List; perMonitorDpiAwareness stays "no"."""
import os
import re
import shutil

here = os.path.dirname(os.path.abspath(__file__))
seed = os.path.join(here, "seed-set")
docks = {
    "set-docked": '''<GUIConfig name="DockingManager" leftWidth="220" rightWidth="230" topHeight="200" bottomHeight="150">
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44070" curr="0" prev="-1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="42051" curr="1" prev="-1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="42052" curr="3" prev="-1" isVisible="no" />
            <ActiveTabs cont="0" activeTab="0" />
            <ActiveTabs cont="1" activeTab="0" />
            <ActiveTabs cont="2" activeTab="-1" />
            <ActiveTabs cont="3" activeTab="0" />
        </GUIConfig>''',
    "set-float": '''<GUIConfig name="DockingManager" leftWidth="220" rightWidth="230" topHeight="200" bottomHeight="150">
            <FloatingWindow cont="4" x="1110" y="10" width="1390" height="430" />
            <FloatingWindow cont="5" x="1110" y="450" width="1560" height="850" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44070" curr="4" prev="0" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="42051" curr="5" prev="1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="42052" curr="3" prev="-1" isVisible="no" />
            <ActiveTabs cont="0" activeTab="-1" />
            <ActiveTabs cont="1" activeTab="-1" />
            <ActiveTabs cont="2" activeTab="-1" />
            <ActiveTabs cont="3" activeTab="0" />
            <ActiveTabs cont="4" activeTab="0" />
            <ActiveTabs cont="5" activeTab="0" />
        </GUIConfig>''',
}
for name, dock in docks.items():
    out = os.path.join(here, "cfg", name)
    shutil.rmtree(out, ignore_errors=True)
    shutil.copytree(seed, out)
    p = os.path.join(out, "config.xml")
    s = open(p, encoding="utf-8").read()
    s, n = re.subn(r'<GUIConfig name="DockingManager".*?</GUIConfig>', dock, s, flags=re.S)
    assert n == 1
    s, n = re.subn(r'fileSwitcherWithoutPathColumn="[a-z]+"', 'fileSwitcherWithoutPathColumn="no"', s)
    assert n == 1
    s, n = re.subn(r'fileSwitcherPathWidth="[0-9]+"', 'fileSwitcherPathWidth="60"', s)
    assert n == 1
    assert 'perMonitorDpiAwareness="no"' in s
    open(p, "w", encoding="utf-8").write(s)
    print(out)
