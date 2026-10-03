"""Colour maths for theme design: sRGB, OKLab/OKLCH, APCA, WCAG 2, colour-vision-deficiency simulation."""
import math

def srgb_to_lin(c):  # c in 0..1
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def lin_to_srgb(c):
    return 12.92 * c if c <= 0.0031308 else 1.055 * c ** (1 / 2.4) - 0.055

def hex_to_rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))

def rgb_to_hex(rgb):
    return ''.join(f'{round(max(0, min(1, c)) * 255):02X}' for c in rgb)

# OKLab (Ottosson 2020)
def lin_to_oklab(r, g, b):
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = (math.copysign(abs(x) ** (1 / 3), x) for x in (l, m, s))
    return (0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s)

def oklab_to_lin(L, a, b):
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return (4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
            -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
            -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)

def hex_to_oklab(h):
    return lin_to_oklab(*(srgb_to_lin(c) for c in hex_to_rgb(h)))

def _in_gamut(L, C, h):
    lin = oklab_to_lin(L, C * math.cos(math.radians(h)), C * math.sin(math.radians(h)))
    return all(-1e-7 <= x <= 1 + 1e-7 for x in lin), lin

def oklch_to_hex(L, C, h):
    """OKLCH -> hex; lowers chroma until the colour fits sRGB (keeps lightness and hue)."""
    ok, lin = _in_gamut(L, C, h)
    if not ok:
        lo, hi = 0.0, C
        for _ in range(40):
            mid = (lo + hi) / 2
            if _in_gamut(L, mid, h)[0]:
                lo = mid
            else:
                hi = mid
        lin = _in_gamut(L, lo, h)[1]
    return rgb_to_hex(tuple(lin_to_srgb(max(0, min(1, x))) for x in lin))

def oklch(hexcol):
    L, a, b = hex_to_oklab(hexcol)
    return L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360

def de_ok(h1, h2):
    return math.dist(hex_to_oklab(h1), hex_to_oklab(h2))

# WCAG 2.x contrast ratio
WCAG_WEIGHTS = (0.2126, 0.7152, 0.0722)

def rel_lum(h, k=WCAG_WEIGHTS):
    r, g, b = (srgb_to_lin(c) for c in hex_to_rgb(h))
    return k[0] * r + k[1] * g + k[2] * b

def wcag(fg, bg, k=WCAG_WEIGHTS):
    a, b = rel_lum(fg, k), rel_lum(bg, k)
    return (max(a, b) + 0.05) / (min(a, b) + 0.05)

# APCA-W3 0.0.98G-4g (Somers): Lc, positive = dark text on light, negative = light text on dark
SRGB_WEIGHTS = (0.2126729, 0.7151522, 0.0721750)
# The same for a 70-year-old: the lens of the eye absorbs more short-wavelength light with age, so the blue
# primary adds less to luminance. CIE 170-1:2006 lens model on a white-LED LCD's primaries, renormalised so the
# display white stays white; computed by vision/agelens.py (about 40% less weight on blue than at 32).
AGE70_WEIGHTS = (0.2534, 0.7024, 0.0443)

def _apca_y(h, k=SRGB_WEIGHTS):
    r, g, b = hex_to_rgb(h)
    y = k[0] * r ** 2.4 + k[1] * g ** 2.4 + k[2] * b ** 2.4
    return y if y > 0.022 else y + (0.022 - y) ** 1.414

def apca(fg, bg, k=SRGB_WEIGHTS):
    yt, yb = _apca_y(fg, k), _apca_y(bg, k)
    if abs(yb - yt) < 0.0005:
        return 0.0
    if yb > yt:
        s = (yb ** 0.56 - yt ** 0.57) * 1.14
        return 0.0 if s < 0.1 else (s - 0.027) * 100
    s = (yb ** 0.65 - yt ** 0.62) * 1.14
    return 0.0 if s > -0.1 else (s + 0.027) * 100

def lc(fg, bg):
    """Contrast for the worse-off of two readers, aged 32 (standard) and 70: |Lc|."""
    return min(abs(apca(fg, bg)), abs(apca(fg, bg, AGE70_WEIGHTS)))

def wcag_worst(fg, bg):
    """WCAG 2 ratio for the worse-off of the same two readers."""
    return min(wcag(fg, bg), wcag(fg, bg, AGE70_WEIGHTS))

# Colour-vision deficiency, Machado, Oliveira & Fernandes 2009, severity 1.0, applied to linear RGB
CVD = {
    'protan': ((0.152286, 1.052583, -0.204868), (0.114503, 0.786281, 0.099216), (-0.003882, -0.048116, 1.051998)),
    'deutan': ((0.367322, 0.860646, -0.227968), (0.280085, 0.672501, 0.047413), (-0.011820, 0.042940, 0.968881)),
    'tritan': ((1.255528, -0.076749, -0.178779), (-0.078411, 0.930809, 0.147602), (0.004733, 0.691367, 0.303900)),
}

def simulate(h, kind):
    if kind == 'normal':
        return h
    lin = [srgb_to_lin(c) for c in hex_to_rgb(h)]
    m = CVD[kind]
    out = [sum(m[i][j] * lin[j] for j in range(3)) for i in range(3)]
    return rgb_to_hex(tuple(lin_to_srgb(max(0, min(1, x))) for x in out))

def blend(fg, bg, alpha):
    """Source-over in sRGB values, as GDI/D2D blend an indicator fill."""
    f, b = hex_to_rgb(fg), hex_to_rgb(bg)
    return rgb_to_hex(tuple(alpha * x + (1 - alpha) * y for x, y in zip(f, b)))

def solve_L(target_lc, bg, C, h, lo=0.0, hi=1.0):
    """OKLab lightness giving |Lc| = target against bg for both readers (see lc), for a hue and chroma."""
    dark_bg = _apca_y(bg) < 0.18
    for _ in range(50):
        mid = (lo + hi) / 2
        contrast = lc(oklch_to_hex(mid, C, h), bg)
        # on a dark background contrast grows with L; on a light one it shrinks
        if (contrast < target_lc) == dark_bg:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2

def color_for(target_lc, bg, C, h):
    return oklch_to_hex(solve_L(target_lc, bg, C, h), C, h)
