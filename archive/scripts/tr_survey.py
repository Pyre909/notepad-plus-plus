import re, glob, os
# labels in <Scintillas> of english ending with ':'
def scint(path):
    t = open(path, encoding='utf-8').read()
    m = re.search(r'<Scintillas\b.*?</Scintillas>', t, re.S)
    return m.group(0) if m else ''
eng = scint('PowerEditor/installer/nativeLang/english.xml')
colon_ids = re.findall(r'<Item id="(\d+)" name="([^"]*:)"', eng)
print('english colon labels:', colon_ids[:12])
for f in sorted(glob.glob('PowerEditor/installer/nativeLang/*.xml')):
    s = scint(f)
    m = re.search(r'<Item id="6363" name="([^"]*)"', s)
    if not m or os.path.basename(f).startswith('english'):
        continue
    samples = []
    for i, _ in colon_ids[:6]:
        mm = re.search(r'<Item id="%s" name="([^"]*)"' % i, s)
        if mm: samples.append(mm.group(1))
    print(f'{os.path.basename(f):28} 6363={m.group(1)!r:34} samples={samples[:4]}')
