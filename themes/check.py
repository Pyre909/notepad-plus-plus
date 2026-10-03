"""Checks the generated themes: same lexers, styles and IDs as the model, and the contrast of every style
(WCAG 2 for the worse-off of two readers aged 32 and 70; APCA Lc for comments and for everything else)."""
import sys, xml.etree.ElementTree as ET
from colormath import lc, wcag_worst
model = ET.parse(sys.argv[1]).getroot()
def key(root):
    return [(lx.get('name'), w.get('name'), w.get('styleID'), w.get('keywordClass')) for lx in root.find('LexerStyles') for w in lx] + \
           [(w.get('name'), w.get('styleID')) for w in root.find('GlobalStyles')]
for t in sys.argv[2:]:
    root = ET.parse(t).getroot()
    comment = next(w.get('fgColor') for lx in root.find('LexerStyles') if lx.get('name') == 'cpp'
                   for w in lx if w.get('name') == 'COMMENT')
    rows = [(wcag_worst(w.get('fgColor'), w.get('bgColor')), lc(w.get('fgColor'), w.get('bgColor')), lx.get('name'),
             w.get('name'), w.get('fgColor'), w.get('bgColor'))
            for lx in root.find('LexerStyles') for w in lx if w.get('fgColor') and w.get('bgColor')]
    low = sorted(rows)[:3]
    code = [r for r in rows if r[4] != comment]
    comments = [r for r in rows if r[4] == comment]
    print(f'{t}: same lexers, styles and IDs as the model: {key(root) == key(model)}; {len(rows)} styles; '
          f'below WCAG 4.5:1: {sum(r[0] < 4.5 for r in rows)}; lowest WCAG {low[0][0]:.2f}:1 ({low[0][2]} {low[0][3]}); '
          f'lowest Lc, code {min(r[1] for r in code):.1f}, comments {min(r[1] for r in comments):.1f}')
