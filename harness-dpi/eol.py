"""Per file of a unified diff: added lines with / without CR, and whether the file (worktree) is CRLF."""
import sys

diff, root = sys.argv[1], sys.argv[2]
cur = None
stats = {}
for raw in open(diff, "rb").read().split(b"\n"):
    if raw.startswith(b"+++ b/"):
        cur = raw[6:].decode().rstrip("\r")
        stats[cur] = [0, 0]
    elif raw.startswith(b"+") and not raw.startswith(b"+++") and cur:
        stats[cur][0 if raw.endswith(b"\r") else 1] += 1
for f, (cr, lf) in stats.items():
    data = open(root + "/" + f, "rb").read()
    crlf = data.count(b"\r\n")
    lfonly = data.count(b"\n") - crlf
    print("%-65s added: %2d CRLF %2d LF | file: %5d CRLF %5d LF-only" % (f, cr, lf, crlf, lfonly))
