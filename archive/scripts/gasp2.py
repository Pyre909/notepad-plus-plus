import struct, sys
def tables(data, off=0):
    n = struct.unpack('>H', data[off+4:off+6])[0]
    t = {}
    for i in range(n):
        tag, cs, o, l = struct.unpack('>4sIII', data[off+12+16*i: off+28+16*i])
        t[tag.decode('latin1')] = (o, l)
    return t
def flags(f):
    s=[]
    if f&1: s.append('GRIDFIT')
    if f&2: s.append('DOGRAY')
    if f&4: s.append('SYM_GRIDFIT')
    if f&8: s.append('SYM_SMOOTH')
    return '|'.join(s) or 'none'
for p in sys.argv[1:]:
    data=open(p,'rb').read(); t=tables(data)
    kind = 'CFF2' if 'CFF2' in t else ('CFF' if 'CFF ' in t else 'glyf')
    hint = 'fpgm' in t or 'prep' in t
    if 'gasp' in t:
        o,l=t['gasp']; ver,n=struct.unpack('>HH',data[o:o+4])
        r=[struct.unpack('>HH',data[o+4+4*i:o+8+4*i]) for i in range(n)]
        g='v%d '%ver+', '.join('<=%d:%s'%(m,flags(f)) for m,f in r)
    else: g='NO gasp'
    print('%-60s %-5s hinted=%s  %s'%(p.split('/')[-1],kind,hint,g))
