"""Checks the generated themes: same lexers/styles/IDs as the model, and the contrast of every style."""
import sys, xml.etree.ElementTree as ET, collections
from colormath import apca
model = ET.parse(sys.argv[1]).getroot()
def key(root):
    return [(lx.get('name'), w.get('name'), w.get('styleID'), w.get('keywordClass')) for lx in root.find('LexerStyles') for w in lx] + \
           [(w.get('name'), w.get('styleID')) for w in root.find('GlobalStyles')]
for t in sys.argv[2:]:
    root = ET.parse(t).getroot()
    rows = []
    for lx in root.find('LexerStyles'):
        for w in lx:
            fg, bg = w.get('fgColor'), w.get('bgColor')
            if fg and bg:
                rows.append((round(abs(apca(fg, bg)), 1), lx.get('name'), w.get('name'), fg, bg))
    rows.sort()
    main = [r for r in rows if r[1] != 'escseq']
    print(f'{t}: same lexers, styles and IDs as the model: {key(root) == key(model)}; {len(rows)} styles; '
          f'lowest Lc outside escseq {main[0][0]}; below Lc 60: {sum(r[0] < 60 for r in main)}')
    print('  lowest:', main[:3])
    print('  escseq lowest:', [r for r in rows if r[1] == 'escseq'][:3])
