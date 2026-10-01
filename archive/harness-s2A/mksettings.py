"""mksettings.py TEMPLATE OUTDIR PMV2(yes|no) DATADIR [float]
Settings dir whose config.xml docks FaW left, Function List right, Project Panel 1 bottom (or floating with 'float'),
with a FaW root folder and a Project Panel 1 workspace, and the per-monitor DPI awareness setting."""
import os
import re
import sys

template, out, pmv2, data = sys.argv[1:5]
floating = len(sys.argv) > 5 and sys.argv[5] == "float"
win = "Z:" + data.replace("/", "\\")
os.makedirs(out, exist_ok=True)
s = open(template, encoding="utf-8").read()
s = re.sub(r'perMonitorDpiAwareness="[a-z]+"', 'perMonitorDpiAwareness="%s"' % pmv2, s)
if floating:
    # FloatingWindow: width/height are the right/bottom coordinates
    dlgs = '''<FloatingWindow cont="4" x="700" y="330" width="1060" height="720" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44085" curr="0" prev="-1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44084" curr="1" prev="-1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44081" curr="4" prev="3" isVisible="no" />
            <ActiveTabs cont="4" activeTab="0" />'''
else:
    dlgs = '''<PluginDlg pluginName="Notepad++::InternalFunction" id="44085" curr="0" prev="-1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44084" curr="1" prev="-1" isVisible="no" />
            <PluginDlg pluginName="Notepad++::InternalFunction" id="44081" curr="3" prev="-1" isVisible="no" />'''
dock = '''<GUIConfig name="DockingManager" leftWidth="260" rightWidth="260" topHeight="200" bottomHeight="250">
            %s
            <ActiveTabs cont="0" activeTab="-1" />
            <ActiveTabs cont="1" activeTab="-1" />
            <ActiveTabs cont="2" activeTab="-1" />
            <ActiveTabs cont="3" activeTab="-1" />
        </GUIConfig>''' % dlgs
s, n = re.subn(r'<GUIConfig name="DockingManager".*?</GUIConfig>', lambda m: dock, s, flags=re.S)
assert n == 1
s, n = re.subn(r'<ProjectPanel id="0" workSpaceFile="[^"]*" />', lambda m: '<ProjectPanel id="0" workSpaceFile="%s\\demo.workspace" />' % win, s)
assert n == 1
s = re.sub(r'\s*<FileBrowser.*?</FileBrowser>', '', s, flags=re.S)
fb = '    <FileBrowser latestSelectedItem="">\n        <root foldername="%s\\ws" />\n    </FileBrowser>\n</NotepadPlus>' % win
s, n = re.subn(r'</NotepadPlus>', lambda m: fb, s)
assert n == 1
open(os.path.join(out, "config.xml"), "w", encoding="utf-8").write(s)
print(out, "pmv2=%s float=%s" % (pmv2, floating))
