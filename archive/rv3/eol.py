import subprocess
ROOT = '/home/user/notepad-plus-plus/.claude/worktrees/agent-a5d268481b09588b6/'
names = subprocess.check_output(['git', '-C', ROOT, 'diff', '--name-only']).decode().split()
for n in names:
    b = open(ROOT + n, 'rb').read()
    lines = b.split(b'\n')
    crlf = sum(1 for l in lines if l.endswith(b'\r'))
    lf = len(lines) - 1 - crlf if not b.endswith(b'\n') else len(lines) - 1 - crlf
    head = subprocess.check_output(['git', '-C', ROOT, 'show', 'HEAD:' + n])
    hl = head.split(b'\n')
    hcrlf = sum(1 for l in hl if l.endswith(b'\r'))
    mixed = crlf != 0 and lf != 0
    print('%-80s crlf=%d lf=%d head_crlf=%d %s' % (n, crlf, lf, hcrlf, 'MIXED' if mixed else ''))
