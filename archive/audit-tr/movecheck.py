import subprocess, xml.etree.ElementTree as ET
repo='/home/user/notepad-plus-plus'
files=subprocess.check_output(['git','-C',repo,'diff','--name-only','f185646','HEAD','--','PowerEditor/installer/nativeLang/']).decode().split()
def load(rev,p):
    return ET.fromstring(subprocess.check_output(['git','-C',repo,'show',f'{rev}:{p}']))
def get(root,node):
    n=root.find(f'.//Dialog/Preference/{node}')
    c=n.find("ComboBox[@id='6362']")
    i=n.find("Item[@id='6363']")
    return ([e.get('name') for e in c.findall('Element')] if c is not None else None, i.get('name') if i is not None else None)
for p in files:
    b=load('f185646',p); h=load('HEAD',p)
    bm=get(b,'MISC'); hm=get(h,'MISC'); hs=get(h,'Scintillas'); bs=get(b,'Scintillas')
    ok = (bm==hs) and hm==(None,None) and bs==(None,None)
    print(p.split('/')[-1], 'OK' if ok else f'MISMATCH base MISC={bm} head Sci={hs} head MISC={hm}', '| label:', hs[1])
    # also make sure nothing else changed in Scintillas/MISC besides these
    for node in ('Scintillas','MISC'):
        def sig(root):
            n=root.find(f'.//Dialog/Preference/{node}')
            return sorted((e.tag,e.get('id'),e.get('name'),tuple(x.get('name') for x in e)) for e in n if e.get('id') not in ('6362','6363','6280','6281','6282','6283','6284','6285','6286','6215','6367'))
        if sig(b)!=sig(h): print('   other change in',node)
