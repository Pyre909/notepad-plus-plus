import struct, sys

def tables(data, off=0):
    numTables = struct.unpack('>H', data[off+4:off+6])[0]
    t = {}
    for i in range(numTables):
        rec = data[off+12+16*i: off+28+16*i]
        tag, cs, o, l = struct.unpack('>4sIII', rec)
        t[tag.decode('latin1')] = (o, l)
    return t

def gasp(path):
    data = open(path, 'rb').read()
    offs = [0]
    if data[:4] == b'ttcf':
        n = struct.unpack('>I', data[8:12])[0]
        offs = list(struct.unpack('>%dI' % n, data[12:12+4*n]))
    out = []
    for off in offs:
        t = tables(data, off)
        name = ''
        if 'gasp' not in t:
            out.append((off, None, 'no gasp', 'glyf' in t, 'CFF ' in t))
            continue
        o, l = t['gasp']
        ver, n = struct.unpack('>HH', data[o:o+4])
        ranges = [struct.unpack('>HH', data[o+4+4*i:o+8+4*i]) for i in range(n)]
        head = t.get('head')
        upem = struct.unpack('>H', data[head[0]+18:head[0]+20])[0] if head else None
        out.append((off, ver, [(m, hex(f)) for m, f in ranges], 'fpgm' in t, 'prep' in t, upem))
    return out

for p in sys.argv[1:]:
    print(p, gasp(p))
