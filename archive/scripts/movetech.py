#!/usr/bin/env python3
# Moves the Scintilla rendering technology translations (ComboBox 6362 & Item 6363)
# from <MISC> to <Scintillas> (Preferences > Editing 1) in the nativeLang files,
# keeping each file's bytes otherwise identical (encoding, line endings, indentation).
import re
import sys
import xml.etree.ElementTree as ET

def block(text, start_pat, end_tag):
    m = re.search(start_pat, text)
    if not m:
        return None
    end = text.index(end_tag, m.end()) + len(end_tag)
    return m.start(), end

def line_span(text, start, end):
    # extend to the whole lines (leading indentation and trailing newline)
    ls = text.rfind('\n', 0, start) + 1
    le = text.index('\n', end) + 1
    return ls, le

def move(path, dry_run=False):
    raw = open(path, 'rb').read()
    text = raw.decode('utf-8')
    misc = block(text, r'<MISC\b[^>]*>', '</MISC>')
    scin = block(text, r'<Scintillas\b[^>]*>', '</Scintillas>')
    if not misc or not scin:
        return 'no MISC/Scintillas'
    m0, m1 = misc
    misc_text = text[m0:m1]
    pieces = []
    cm = re.search(r'<ComboBox id="6362">', misc_text)
    if cm:
        s = m0 + cm.start()
        e = text.index('</ComboBox>', s) + len('</ComboBox>')
        pieces.append(line_span(text, s, e))
    im = re.search(r'<Item id="6363"[^>]*/>', misc_text)
    if im:
        s = m0 + im.start()
        pieces.append(line_span(text, s, m0 + im.end()))
    if not pieces:
        return 'nothing to move'
    pieces.sort()
    moved = ''.join(text[s:e] for s, e in pieces)
    out = text
    for s, e in reversed(pieces):
        out = out[:s] + out[e:]
    # insert before the </Scintillas> line
    sc_end = out.index('</Scintillas>', out.index('<Scintillas'))
    ins = out.rfind('\n', 0, sc_end) + 1
    out = out[:ins] + moved + out[ins:]

    # checks: well-formed, same number of elements, nodes moved
    before, after = ET.fromstring(raw), ET.fromstring(out.encode('utf-8'))
    assert len(list(before.iter())) == len(list(after.iter())), path
    for node in after.iter('MISC'):
        assert node.find("ComboBox[@id='6362']") is None and node.find("Item[@id='6363']") is None, path
    sc = next(after.iter('Scintillas'))
    if cm:
        assert sc.find("ComboBox[@id='6362']") is not None, path
    if im:
        assert sc.find("Item[@id='6363']") is not None, path
    if not dry_run:
        open(path, 'wb').write(out.encode('utf-8'))
    return 'moved %d' % len(pieces)

if __name__ == '__main__':
    dry = sys.argv[1] == '-n'
    for p in sys.argv[2 if dry else 1:]:
        print(p, move(p, dry))
