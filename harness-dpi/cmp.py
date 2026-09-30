import sys
from PIL import Image, ImageChops


def cmp(a, b):
    A = Image.open(a).convert("RGB")
    B = Image.open(b).convert("RGB")
    if A.size != B.size:
        return "size %s vs %s" % (A.size, B.size)
    d = ImageChops.difference(A, B)
    bbox = d.getbbox()
    n = sum(1 for p in d.getdata() if p != (0, 0, 0))
    return "identical" if not bbox else "%d px differ bbox %s" % (n, bbox)


for pair in sys.argv[1:]:
    a, b = pair.split(",")
    print("%-70s %s" % (pair, cmp(a, b)))
