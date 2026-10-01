import sys
ROOT = '/home/user/notepad-plus-plus/.claude/worktrees/agent-a5d268481b09588b6/'


def rep(path, pairs):
    p = ROOT + path
    b = open(p, 'rb').read()
    crlf = b'\r\n' in b
    for o, n in pairs:
        o = o.encode('utf-8')
        n = n.encode('utf-8')
        if crlf:
            o = o.replace(b'\n', b'\r\n')
            n = n.replace(b'\n', b'\r\n')
        c = b.count(o)
        if c != 1:
            raise SystemExit('%s: expected 1 match, got %d for:\n%s' % (path, c, o.decode('utf-8', 'replace')[:300]))
        b = b.replace(o, n)
    open(p, 'wb').write(b)
    print('ok', path)
