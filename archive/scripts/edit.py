# edit.py: exact replacements preserving the file's line endings (CRLF files stay CRLF)
import sys
def rep(path, old, new, count=1):
    data = open(path, 'rb').read()
    crlf = b'\r\n' in data
    text = data.decode('utf-8')
    if crlf:
        old = old.replace('\r\n', '\n').replace('\n', '\r\n')
        new = new.replace('\r\n', '\n').replace('\n', '\r\n')
    n = text.count(old)
    if n != count:
        raise SystemExit(f'{path}: found {n} (expected {count}): {old[:80]!r}')
    text = text.replace(old, new)
    open(path, 'wb').write(text.encode('utf-8'))
