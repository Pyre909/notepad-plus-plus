#!/usr/bin/env python3
# sub.py list FILE                 : -U0 hunks of upstream/master..HEAD for FILE, numbered
# sub.py build FILE SEL OUT        : upstream/master's FILE with only the -U0 hunks SEL (e.g. "0,2-5" or "all" or "none") applied -> OUT
# Hunks are applied by their old line numbers on the upstream blob, so any subset is exact (no fuzz).
import subprocess, sys, re
REPO = '/home/user/notepad-plus-plus'
BASE, HEAD = 'upstream/master', 'HEAD'
def git(*a):
    return subprocess.run(['git', '-C', REPO, *a], capture_output=True, check=True).stdout
def hunks(path):
    out = git('diff', '-U0', '--no-color', BASE, HEAD, '--', path).decode('utf-8', 'surrogateescape')
    hs, cur = [], None
    for l in out.splitlines(keepends=True):
        m = re.match(r'@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@', l)
        if m:
            os_, ol = int(m.group(1)), int(m.group(2) if m.group(2) is not None else 1)
            cur = {'old_start': os_, 'old_len': ol, 'minus': [], 'plus': [], 'head': l}
            hs.append(cur)
        elif cur is not None:
            if l.startswith('-'): cur['minus'].append(l[1:])
            elif l.startswith('+'): cur['plus'].append(l[1:])
    return hs
def parse_sel(sel, n):
    if sel == 'all': return set(range(n))
    if sel in ('none', ''): return set()
    s = set()
    for part in sel.split(','):
        if '-' in part:
            a, b = part.split('-'); s |= set(range(int(a), int(b) + 1))
        else:
            s.add(int(part))
    return s
cmd, path = sys.argv[1], sys.argv[2]
hs = hunks(path)
if cmd == 'list':
    for i, h in enumerate(hs):
        print(f'#{i} -{h["old_start"]},{h["old_len"]} (+{len(h["plus"])} -{len(h["minus"])})')
        for l in (['-' + x for x in h['minus'][:2]] + ['+' + x for x in h['plus'][:3]]):
            print('     ' + l.rstrip('\r\n')[:140])
elif cmd == 'build':
    sel = parse_sel(sys.argv[3], len(hs))
    try:
        base = git('show', f'{BASE}:{path}').decode('utf-8', 'surrogateescape').splitlines(keepends=True)
    except subprocess.CalledProcessError:
        base = []
    out, pos = [], 0  # pos: 0-based index in base
    for i, h in enumerate(hs):
        if i not in sel: continue
        # for a pure insertion (old_len 0), old_start is the line after which to insert
        start = h['old_start'] - 1 if h['old_len'] > 0 else h['old_start']
        out += base[pos:start]
        removed = base[start:start + h['old_len']]
        assert removed == h['minus'], (path, i, removed[:2], h['minus'][:2])
        out += h['plus']
        pos = start + h['old_len']
    out += base[pos:]
    open(sys.argv[4], 'wb').write(''.join(out).encode('utf-8', 'surrogateescape'))
