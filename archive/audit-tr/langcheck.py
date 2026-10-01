import os, re, sys, subprocess
import xml.etree.ElementTree as ET
repo='/home/user/notepad-plus-plus'
d=os.path.join(repo,'PowerEditor/installer/nativeLang')
changed=set(os.path.basename(p) for p in subprocess.check_output(['git','-C',repo,'diff','--name-only','f185646','HEAD','--','PowerEditor/installer/nativeLang/']).decode().split())
# control ids per dialog from preference.rc
rc=open(os.path.join(repo,'PowerEditor/src/WinControls/Preference/preference.rc'),encoding='utf-8',errors='replace').read()
hdr=open(os.path.join(repo,'PowerEditor/src/WinControls/Preference/preference_rc.h'),encoding='utf-8',errors='replace').read()
defs={}
for m in re.finditer(r'#define\s+(\w+)\s+\(?\s*([\w+ ]+?)\s*\)?\s*$',hdr,re.M):
    defs[m.group(1)]=m.group(2)
def ev(s):
    s=s.strip()
    if s.isdigit(): return int(s)
    if '+' in s: return sum(ev(x) for x in s.split('+'))
    if s in defs: return ev(defs[s])
    return None
dlgs={}
for m in re.finditer(r'^(\w+)\s+DIALOGEX.*?^BEGIN(.*?)^END',rc,re.M|re.S):
    ids={}
    for line in m.group(2).splitlines():
        l=line.strip()
        if not l or l.startswith('//'): continue
        mm=re.match(r'(\w+)\s+(.*)',l)
        kind=mm.group(1)
        rest=mm.group(2)
        # find identifier token
        if kind=='CONTROL' or kind in ('LTEXT','RTEXT','CTEXT','GROUPBOX','PUSHBUTTON','DEFPUSHBUTTON'):
            toks=re.findall(r'"[^"]*"|[^,]+',rest)
            idt=toks[1].strip()
        else:
            idt=rest.split(',')[0].strip()
        v=ev(idt)
        ids[v]=(kind,idt)
    dlgs[m.group(1)]=ids
ed=dlgs['IDD_PREFERENCE_SUB_EDITING']; misc=dlgs['IDD_PREFERENCE_SUB_MISC']
combo_counts={6362:5,6282:5,6284:5,6286:4}
for f in sorted(os.listdir(d)):
    if not f.endswith('.xml'): continue
    p=os.path.join(d,f)
    try:
        t=ET.parse(p)
    except Exception as e:
        print(f,'PARSE ERROR',e); continue
    root=t.getroot()
    pref=root.find('.//Dialog/Preference')
    if pref is None: print(f,'no Preference'); continue
    for node,dlg in (('Scintillas',ed),('MISC',misc)):
        n=pref.find(node)
        if n is None: print(f,node,'missing'); continue
        combos=[(int(c.get('id')),len(c.findall('Element'))) for c in n.findall('ComboBox')]
        items=[int(c.get('id')) for c in n.findall('Item')]
        issues=[]
        for i,(cid,cnt) in enumerate(combos):
            if cid not in dlg:
                later=[c for c,_ in combos[i+1:]]
                issues.append(f'combo {cid} not in dialog -> aborts {later}')
            elif cid in combo_counts and cnt!=combo_counts[cid]:
                issues.append(f'combo {cid} has {cnt} elements (code {combo_counts[cid]})')
        dups=set(x for x in items if items.count(x)>1)
        if dups: issues.append(f'dup items {dups}')
        cdups=set(c for c,_ in combos if [x for x,_ in combos].count(c)>1)
        if cdups: issues.append(f'dup combos {cdups}')
        missing_items=[x for x in items if x not in dlg]
        if missing_items: issues.append(f'items not in dialog {missing_items}')
        tag='*' if f in changed else ' '
        print(tag,f,node,'combos',combos,'|',('; '.join(issues)) if issues else 'ok')
