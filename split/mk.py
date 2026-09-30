#!/usr/bin/env python3
# mk.py FEATURE WORKTREE : writes the files of FEATURE (fs, fw, tr, trl, dpi) into WORKTREE (checked out at upstream/master,
# or at the tr branch for trl). Selections come from spec.py; MANUAL files are built here.
import subprocess, sys, os, re
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from spec import SPEC, NL
REPO = '/home/user/notepad-plus-plus'
SUB = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'sub.py')
def git(*a):
    return subprocess.run(['git', '-C', REPO, *a], capture_output=True, check=True).stdout
def head(path):
    return git('show', f'HEAD:{path}').decode('utf-8')
def master(path):
    return git('show', f'upstream/master:{path}').decode('utf-8')
def subset(path, sel):
    tmp = '/tmp/_mk_subset'
    subprocess.run(['python3', SUB, 'build', path, sel, tmp], check=True)
    return open(tmp, 'rb').read().decode('utf-8')
def crlf(text):
    return '\r\n' in text
def rep(text, old, new, count=1):
    if crlf(text):
        old = old.replace('\r\n', '\n').replace('\n', '\r\n'); new = new.replace('\r\n', '\n').replace('\n', '\r\n')
    n = text.count(old)
    assert n == count, (n, old[:100])
    return text.replace(old, new)
def between(text, start, end):
    # the text from start (included) to end (excluded), from HEAD
    i = text.index(start); j = text.index(end, i)
    return text[i:j]
def write(wt, path, text):
    p = os.path.join(wt, path)
    os.makedirs(os.path.dirname(p), exist_ok=True)
    open(p, 'wb').write(text.encode('utf-8'))

D2D = 'scintilla/win32/SurfaceD2D.cxx'
def d2d_tr():
    h = head(D2D)
    t = subset(D2D, '2,7,11-30')
    anchor = 'struct FontDirectWrite : public FontWin {\n'
    measuring = between(h, '// N++: measuring mode selected by the FontQuality bits', '// N++: the DirectWrite family, weight, stretch and style')
    t = rep(t, anchor, measuring + anchor)
    t = rep(t, '\tCharacterSet characterSet = CharacterSet::Ansi;\n\tstatic constexpr FLOAT minimalAscent',
        '\tCharacterSet characterSet = CharacterSet::Ansi;\n'
        '\tDWRITE_MEASURING_MODE measuringMode = DWRITE_MEASURING_MODE_NATURAL;\t// N++: used for every layout of this font\n'
        '\tFLOAT emSize = 1.0f;\t// N++: in DIPs\n'
        '\tstatic constexpr FLOAT minimalAscent')
    t = rep(t, '\t\tconst FLOAT fHeight = static_cast<FLOAT>(fp.size);\n',
        '\t\tFLOAT fHeight = static_cast<FLOAT>(fp.size);\n'
        '\t\tif (measuringMode != DWRITE_MEASURING_MODE_NATURAL) {\n'
        '\t\t\t// N++: whole pixel em size like GDI\'s integer font height (13 px, not 13.33 px, for 10 points at 96 DPI)\n'
        '\t\t\tfHeight = std::max(1.0f, std::round(fHeight));\n'
        '\t\t}\n'
        '\t\temSize = fHeight;\t// N++\n')
    t = rep(t, '\t\tcharacterSet = other.characterSet;\n',
        '\t\tcharacterSet = other.characterSet;\n\t\tmeasuringMode = other.measuringMode;\t// N++\n\t\temSize = other.emSize;\t// N++\n')
    return t
def d2d_fw():
    h = head(D2D)
    t = subset(D2D, '4,5,6,10,31')
    anchor = 'struct FontDirectWrite : public FontWin {\n'
    gdi = between(h, '// N++: the DirectWrite family, weight, stretch and style', anchor)
    t = rep(t, anchor, gdi + anchor)
    t = rep(t, '\tCharacterSet characterSet = CharacterSet::Ansi;\n\tstatic constexpr FLOAT minimalAscent',
        '\tCharacterSet characterSet = CharacterSet::Ansi;\n'
        '\tFLOAT emSize = 1.0f;\t// N++: in DIPs\n'
        '\tstd::wstring gdiFaceName;\t// N++: GDI family name matched to a DirectWrite family (see MatchGdiFamilyName), for HFont()\n'
        '\tLONG gdiWeight = FW_NORMAL;\t// N++: weight requested with gdiFaceName\n'
        '\tBYTE gdiItalic = FALSE;\t// N++: italic requested with gdiFaceName\n'
        '\tstatic constexpr FLOAT minimalAscent')
    match_block = between(h, '\t\t// N++: a GDI family name of a weight or stretch ("Fira Code Light")', '\t\tHRESULT hr = pIDWriteFactory->CreateTextFormat(wsFamily.c_str()')
    t = rep(t, '\t\tconst FLOAT fHeight = static_cast<FLOAT>(fp.size);\n'
               '\t\tconst DWRITE_FONT_STYLE style = fp.italic ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL;\n'
               '\t\tHRESULT hr = pIDWriteFactory->CreateTextFormat(wsFace.c_str(), nullptr,\n'
               '\t\t\tstatic_cast<DWRITE_FONT_WEIGHT>(fp.weight),\n',
               '\t\tconst FLOAT fHeight = static_cast<FLOAT>(fp.size);\n'
               '\t\temSize = fHeight;\t// N++\n'
               '\t\tDWRITE_FONT_STYLE style = fp.italic ? DWRITE_FONT_STYLE_ITALIC : DWRITE_FONT_STYLE_NORMAL;\n'
               + match_block +
               '\t\tHRESULT hr = pIDWriteFactory->CreateTextFormat(wsFamily.c_str(), nullptr,\n'
               '\t\t\tstatic_cast<DWRITE_FONT_WEIGHT>(weight),\n')
    t = rep(t, '\tFontDirectWrite(const FontDirectWrite &other) noexcept {\n',
        '\t// N++: not noexcept as gdiFaceName is copied\n\tFontDirectWrite(const FontDirectWrite &other) {\n')
    t = rep(t, '\t\tcharacterSet = other.characterSet;\n',
        '\t\tcharacterSet = other.characterSet;\n\t\temSize = other.emSize;\t// N++\n'
        '\t\tgdiFaceName = other.gdiFaceName;\t// N++\n\t\tgdiWeight = other.gdiWeight;\t// N++\n\t\tgdiItalic = other.gdiItalic;\t// N++\n')
    return t

RC = 'PowerEditor/src/WinControls/Preference/preference.rc'
DPI_CHECK_HEAD = '    CONTROL         "Per-monitor DPI awareness (experimental, restart required)",IDC_CHECK_PERMONITORDPIAWARENESS,"Button",BS_AUTOCHECKBOX | WS_TABSTOP,37,187,330,10\n'
def rc_tr():
    t = subset(RC, 'all')
    return rep(t, DPI_CHECK_HEAD, '')
def rc_dpi():
    t = master(RC)
    anchor = '    RTEXT           "Workspace file ext.:",IDC_WORKSPACEFILEEXT_STATIC,270,143,108,8\n'
    return rep(t, anchor, anchor + '    CONTROL         "Per-monitor DPI awareness (experimental, restart required)",IDC_CHECK_PERMONITORDPIAWARENESS,"Button",BS_AUTOCHECKBOX | BS_MULTILINE | BS_TOP | WS_TABSTOP,270,160,180,20\n')

def translations():
    files = [f for f in git('diff', '--name-only', 'upstream/master', 'HEAD', '--', NL).decode().split()
             if not os.path.basename(f).startswith('english')]
    return files
def tr_translation(path):
    h, m = head(path), master(path)
    old = re.search(r'<Item id="6363" name="([^"]*)"/>', m).group(1)
    new = re.search(r'<Item id="6363" name="([^"]*)"/>', h).group(1)
    return h.replace(f'<Item id="6363" name="{new}"/>', f'<Item id="6363" name="{old}"/>', 1)

def main(feature, wt):
    if feature == 'trl':
        for f in translations():
            write(wt, f, head(f))
        return
    spec = dict(SPEC[feature])
    if feature == 'dpi':
        assigned = set()
        for s in SPEC.values(): assigned |= set(s)
        for f in git('diff', '--name-only', 'upstream/master', 'HEAD').decode().split():
            if f not in assigned and not f.startswith(NL):
                spec[f] = 'all'
    for f, sel in spec.items():
        if sel == 'MANUAL':
            text = {('tr', D2D): d2d_tr, ('fw', D2D): d2d_fw, ('tr', RC): rc_tr, ('dpi', RC): rc_dpi}[(feature, f)]()
        else:
            text = subset(f, sel)
        write(wt, f, text)
    if feature == 'tr':
        for f in translations():
            write(wt, f, tr_translation(f))

main(sys.argv[1], sys.argv[2])
