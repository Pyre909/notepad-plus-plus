#!/usr/bin/env python3
# hunks.py list FILE            : hunks of `git diff upstream/master HEAD -- FILE`, numbered
# hunks.py show FILE N          : full text of hunk N
# hunks.py patch FILE N,N,...   : a patch with only these hunks (to stdout), for git apply
import subprocess, sys, re
REPO = '/home/user/notepad-plus-plus'
def diff(path):
    out = subprocess.run(['git', '-C', REPO, 'diff', '-U3', 'upstream/master', 'HEAD', '--', path],
                         capture_output=True).stdout.decode('utf-8', 'surrogateescape')
    lines = out.splitlines(keepends=True)
    header, hunks, cur = [], [], None
    for l in lines:
        if l.startswith('@@'):
            cur = [l]; hunks.append(cur)
        elif cur is None:
            header.append(l)
        else:
            cur.append(l)
    return header, hunks
cmd, path = sys.argv[1], sys.argv[2]
header, hunks = diff(path)
if cmd == 'list':
    for i, h in enumerate(hunks):
        changed = [l.rstrip('\r\n') for l in h[1:] if l[:1] in '+-']
        print(f'#{i} {h[0].strip()[:60]}  (+{sum(1 for l in changed if l[0]=="+")} -{sum(1 for l in changed if l[0]=="-")})')
        for l in changed[:4]:
            print('     ' + l[:150])
elif cmd == 'show':
    sys.stdout.write(''.join(hunks[int(sys.argv[3])]))
elif cmd == 'patch':
    sel = [int(x) for x in sys.argv[3].split(',') if x != '']
    sys.stdout.buffer.write((''.join(header) + ''.join(''.join(hunks[i]) for i in sel)).encode('utf-8', 'surrogateescape'))
