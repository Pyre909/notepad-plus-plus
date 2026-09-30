# bmpstat.py FILE... : distinct colours and colour-fringe pixels of 24-bit BMP captures
import struct, sys
for path in sys.argv[1:]:
    d = open(path, "rb").read()
    off, = struct.unpack_from("<I", d, 10)
    w, h = struct.unpack_from("<ii", d, 18)
    row = ((w * 3 + 3) // 4) * 4
    colors, fringe, gray = set(), 0, 0
    for y in range(abs(h)):
        base = off + y * row
        for x in range(w):
            b, g, r = d[base + 3 * x], d[base + 3 * x + 1], d[base + 3 * x + 2]
            colors.add((r, g, b))
            spread = max(r, g, b) - min(r, g, b)
            if spread > 40:
                fringe += 1
            elif 40 < r < 215 and spread <= 8:
                gray += 1
    print("PIXELS\t%s\tcolours=%d\tcolour-fringe px=%d\tmid-grey px=%d" % (path.rsplit("/", 1)[-1], len(colors), fringe, gray))
