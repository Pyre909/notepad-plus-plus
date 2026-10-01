import re, glob, os
NBSP = ' '
special = {
    'swedish.xml': 'Renderingsläge:',
    'tamil.xml': 'Rendering mode:',
    'turkish.xml': 'Görselleştirme Modu:',
    'french.xml': 'Mode de rendu :',
    'corsican.xml': 'Modu di restituzione' + NBSP + ':',
    'hongKongCantonese.xml': '渲染模式：',
    'taiwaneseMandarin.xml': '繪製模式：',
}
for f in sorted(glob.glob('PowerEditor/installer/nativeLang/*.xml')):
    base = os.path.basename(f)
    if base.startswith('english'):
        continue
    data = open(f, 'rb').read()
    text = data.decode('utf-8')
    items = re.findall(r'<Item id="6363" name="([^"]*)"/>', text)
    if not items:
        continue
    assert len(items) == 1, (base, items)
    old = items[0]
    new = special.get(base, old[0].upper() + old[1:] + ':')
    text2 = text.replace(f'<Item id="6363" name="{old}"/>', f'<Item id="6363" name="{new}"/>', 1)
    open(f, 'wb').write(text2.encode('utf-8'))
    print(f'{base:28} {old!r:32} -> {new!r}')
