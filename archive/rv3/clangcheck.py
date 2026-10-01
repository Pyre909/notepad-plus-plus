import os
import re
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor

ROOT = '/home/user/notepad-plus-plus/.claude/worktrees/agent-a5d268481b09588b6/'
GCC = ROOT + 'PowerEditor/gcc'
HERE = os.path.dirname(os.path.abspath(__file__))
BASE = sys.argv[1] if len(sys.argv) > 1 else 'master'

toks = shlex.split(open(os.path.join(HERE, 'cmd.txt')).read().strip())
flags = []
i = 1
while i < len(toks):
    t = toks[i]
    if t in ('-include', '-isystem'):
        flags += [t, toks[i + 1]]
        i += 2
        continue
    if t.startswith('-I') or t.startswith('-D') or t.startswith('-std='):
        flags.append(t)
    i += 1

extra = ['--target=x86_64-w64-mingw32', '-fsyntax-only', '-Wshadow-all', '-Wsign-compare', '-Wunreachable-code',
         '-Wall', '-Wextra', '-Wno-unknown-pragmas', '-Wno-unused-command-line-argument', '-ferror-limit=0']

# changed lines vs BASE
diff = subprocess.check_output(['git', '-C', ROOT, 'diff', '-U0', BASE, '--', 'PowerEditor/src']).decode('utf-8', 'replace')
changed = {}
cur = None
for line in diff.splitlines():
    if line.startswith('+++ '):
        p = line[4:]
        cur = p[2:] if p.startswith('b/') else None
        if cur:
            changed.setdefault(cur, set())
    elif line.startswith('@@') and cur:
        m = re.search(r'\+(\d+)(?:,(\d+))?', line)
        start = int(m.group(1))
        n = int(m.group(2)) if m.group(2) is not None else 1
        changed[cur].update(range(start, start + n))

cpps = [f for f in changed if f.endswith('.cpp')]


def run(f):
    src = os.path.relpath(ROOT + f, GCC)
    r = subprocess.run(['clang++'] + extra + flags + [src], cwd=GCC, capture_output=True, text=True, errors='replace')
    return f, r.stderr


diag = re.compile(r'^(.*?):(\d+):(\d+): (warning|error): (.*)$')
found = {}
errors = []
with ThreadPoolExecutor(4) as ex:
    for f, err in ex.map(run, cpps):
        for l in err.splitlines():
            m = diag.match(l)
            if not m:
                continue
            path = os.path.normpath(os.path.join(GCC, m.group(1)))
            rel = os.path.relpath(path, ROOT)
            ln = int(m.group(2))
            if m.group(4) == 'error':
                errors.append((f, l))
            if rel in changed and ln in changed[rel]:
                found.setdefault((rel, ln, m.group(5)), f)

print('files checked:', len(cpps))
print('errors:', len(errors))
for e in errors[:20]:
    print('  ', e)
print('warnings on lines changed vs %s: %d' % (BASE, len(found)))
for (rel, ln, msg), f in sorted(found.items()):
    print('  %s:%d: %s' % (rel, ln, msg))
