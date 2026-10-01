# Splits tickets.json into the themed reading files used for the survey (MAINTAINER-SURVEY.md).
import json, re
rows = json.load(open('tickets.json'))
def fmt(r):
    out = [f"\n######## {r['tracker']} #{r['num']} | {r['date']} | status={r['status']} | by {r['reporter']} | labels={','.join(r['labels'])}",
           f"SUMMARY: {r['summary']}"]
    if r['atts']: out.append(f"ATTACHMENTS: {', '.join(r['atts'])}")
    out.append(f"DESCRIPTION: {(r['desc'] or '').strip()[:1800]}")
    for a,d,txt in r['posts']:
        t = txt.strip()
        if t.startswith('- **') and len(t) < 300: continue   # metadata-only change
        lim = 2500 if a == 'nyamatongwe' else 900
        out.append(f"--- {a} {d}: {t[:lim]}")
    return '\n'.join(out)
render = re.compile(r'directwrite|direct2d|d2d|gdi\b|cleartype|antialias|font|render|technology|dpi|gamma|contrast|hint|win32', re.I)
groups = {
 'A-zufuliu': [r for r in rows if r['reporter']=='zufuliu'],
 'B-other-features': [r for r in rows if r['tracker']=='feature-requests' and r['reporter']!='zufuliu' and not render.search(r['summary']+' '+' '.join(r['labels']))],
 'C-other-bugs': [r for r in rows if r['tracker']=='bugs' and r['reporter']!='zufuliu' and not render.search(r['summary']+' '+' '.join(r['labels']))
                  and (r['status'] in ('closed-rejected','closed-wont-fix','closed-invalid','open-wont-fix','open-rejected','closed-works-for-me') or any(re.search(r'\.(patch|diff|zip)$',a,re.I) for a in r['atts']))],
 'D-rendering-fonts-win32': [r for r in rows if r['reporter']!='zufuliu' and render.search(r['summary']+' '+' '.join(r['labels']))],
}
for name, rs in groups.items():
    rs.sort(key=lambda r:(r['tracker'], r['num']))
    txt = '\n'.join(fmt(r) for r in rs)
    open(f'theme-{name}.txt','w').write(txt)
    print(name, len(rs), 'tickets', len(txt)//1024, 'KB')
