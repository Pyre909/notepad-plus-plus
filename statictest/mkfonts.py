# Synthetic static font sets built from Fira Code Regular, each weight with outlines scaled to a different
# height (so each weight has a distinct ink): the naming of static fonts as fontmake and foundries make them.
import sys
from fontTools.ttLib import TTFont
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.pens.transformPen import TransformPen
from fontTools.pens.recordingPen import DecomposingRecordingPen

SRC = '/usr/share/fonts/truetype/firacode/FiraCode-Regular.ttf'
WEIGHTS = [('Hairline', 1), ('Thin', 100), ('ExtraLight', 200), ('Light', 300), ('Regular', 400),
           ('Medium', 500), ('SemiBold', 600), ('Bold', 700), ('ExtraBold', 800), ('Black', 900)]

def make(family, style, weight, scale, italic, typographic, out, regularBit=True, boldFlag=False, widthClass=5):
    f = TTFont(SRC)
    gs = f.getGlyphSet()
    glyf = f['glyf']
    shear = 0.2 if italic else 0.0
    newglyphs = {}
    for name in f.getGlyphOrder():
        rec = DecomposingRecordingPen(gs)
        gs[name].draw(rec)
        pen = TTGlyphPen(None)
        rec.replay(TransformPen(pen, (1, 0, shear, scale, 0, 0)))
        newglyphs[name] = pen.glyph()
    for name, g in newglyphs.items():
        glyf[name] = g
    for t in ('fpgm', 'prep', 'cvt ', 'hdmx', 'LTSH', 'VDMX', 'GSUB', 'GPOS', 'GDEF'):
        if t in f:
            del f[t]
    ribbi = style in ('Regular', 'Bold')
    sub = ('Italic' if italic else 'Regular') if not ribbi else (style + (' Italic' if italic else '') if style == 'Bold' else ('Italic' if italic else 'Regular'))
    fam1 = family if ribbi else f'{family} {style}'
    tsub = (style if style != 'Regular' or not italic else '') + (' Italic' if italic else '')
    tsub = tsub.strip() or 'Regular'
    full = f'{family} {tsub}' if tsub != 'Regular' else family
    name = f['name']
    name.names = []
    for nid, s in ((1, fam1), (2, sub), (3, f'synthetic;{full}'), (4, full), (6, (family + '-' + tsub).replace(' ', ''))):
        name.setName(s, nid, 3, 1, 0x409)
    if typographic:
        name.setName(family, 16, 3, 1, 0x409)
        name.setName(tsub, 17, 3, 1, 0x409)
    os2 = f['OS/2']
    os2.usWeightClass = weight
    os2.usWidthClass = widthClass
    sel = os2.fsSelection & ~0b1100001
    if italic: sel |= 1
    if style == 'Bold' or boldFlag: sel |= 1 << 5
    if not italic and style != 'Bold' and regularBit: sel |= 1 << 6 if style == 'Regular' or not ribbi else 0
    os2.fsSelection = sel
    f['head'].macStyle = (1 if style == 'Bold' or boldFlag else 0) | (2 if italic else 0)
    f['post'].italicAngle = -11.3 if italic else 0
    f.save(out)
    print(f'{out}: id1="{fam1}" id2="{sub}" wt={weight} scale={scale:.2f}' + (f' id16="{family}" id17="{tsub}"' if typographic else ''))

import sys
scale = lambda i: 0.55 + 0.05 * i
only = sys.argv[1:] 
def want(fam): return not only or fam in only
if want('TestMono'):
    for i, (s, w) in enumerate(WEIGHTS):
        make('TestMono', s, w, scale(i), False, True, f'fonts/TestMono-{s}.ttf')
    for s, w, i in (('ExtraLight', 200, 2), ('Regular', 400, 4)):
        make('TestMono', s, w, scale(i), True, True, f'fonts/TestMono-{s}Italic.ttf')
if want('TestDup'):
    for i, (s, w) in enumerate(WEIGHTS):
        make('TestDup', s, 100 if s == 'Hairline' else w, scale(i), False, True, f'fonts/TestDup-{s}.ttf')
if want('TestOld'):
    for i, (s, w) in enumerate(WEIGHTS):
        if s in ('Hairline', 'ExtraLight', 'Regular', 'Bold'):
            make('TestOld', s, w, scale(i), False, False, f'fonts/TestOld-{s}.ttf')
# TestHeavy: modern naming without the REGULAR selection bit on its non RIBBI fonts
if want('TestHeavy'):
    for i, (s, w) in enumerate(WEIGHTS):
        if s in ('Regular', 'Medium', 'SemiBold', 'Bold', 'ExtraBold', 'Black'):
            make('TestHeavy', s, w, scale(i), False, True, f'fonts/TestHeavy-{s}.ttf', regularBit=False, boldFlag=w > 500)
# TestSemi: a legacy family of a semibold font only (a DirectWrite family used as is)
if want('TestSemi'):
    make('TestSemi', 'Regular', 600, scale(6), False, False, 'fonts/TestSemi-Regular.ttf', regularBit=False, boldFlag=True)
# TestLongName: semi condensed fonts whose Win32 family names are longer than GDI's 31 characters
if want('TestLongName'):
    for s, w, i in (('Light SemiCondensed', 300, 3), ('SemiCondensed', 400, 4), ('SemiBold SemiCondensed', 600, 6)):
        make('TestLongName', s, w, scale(i), False, True, f'fonts/TestLongName-{s.replace(" ", "")}.ttf', regularBit=False, boldFlag=w > 500, widthClass=4)
