"""vision-report.md: what an older reader and the Helmholtz-Kohlrausch effect do to the two palettes.

Needs colour-science (pip install colour-science); the themes themselves don't. Run from themes/:
python3 vision/report.py > vision-report.md"""
import os, sys, warnings
warnings.filterwarnings('ignore')
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, colour
from colormath import hex_to_rgb, apca, AGE70_WEIGHTS
from palette import build
import agelens

ROLES = ('text', 'keyword', 'type', 'string', 'number', 'function', 'special', 'comment', 'error')
XYZ_W = colour.xy_to_XYZ(colour.CCS_ILLUMINANTS['CIE 1931 2 Degree Standard Observer']['D65']) * 100
SURROUND = colour.VIEWING_CONDITIONS_HELLWIG2022['Average']
L_A = 120 * 0.2   # a 120 cd/m2 display white, 20% adapting luminance

def hellwig(h, bg):
    """CAM16 lightness J and its Helmholtz-Kohlrausch extension J_HK (Hellwig, Stolitzka & Fairchild 2022)."""
    Yb = max(colour.sRGB_to_XYZ(np.array(hex_to_rgb(bg)))[1] * 100, 1.0)
    s = colour.XYZ_to_Hellwig2022(colour.sRGB_to_XYZ(np.array(hex_to_rgb(h))) * 100, XYZ_W, L_A, Yb, SURROUND)
    return float(s.J), float(s.J_HK)

def weights_rows():
    out = ['| Age | R | G | B (white-LED LCD model) | B (Apple Studio Display, CCFL) | B (CRT) |', '|---|---|---|---|---|---|']
    for age in (20, 32, 45, 60, 70, 80):
        k = agelens.weights(age)
        out.append(f'| {age} | {k[0]:.4f} | {k[1]:.4f} | {k[2]:.4f} | {agelens.weights(age, "Apple Studio Display")[2]:.4f} '
                   f'| {agelens.weights(age, "Typical CRT Brainard 1997")[2]:.4f} |')
    return out

def palette_rows(mode):
    p = build(mode)
    k80 = agelens.weights(80)
    tJ, tJHK = hellwig(p['text'], p['bg'])
    out = [f'### {mode}', '',
           '| Role | Colour | Lc at 32 | Lc at 70 | Lc at 80 | J | J_HK | J_HK - J | gap to text in J_HK |',
           '|---|---|---|---|---|---|---|---|---|']
    for r in ROLES:
        J, JHK = hellwig(p[r], p['bg'])
        out.append(f'| {r} | #{p[r]} | {abs(apca(p[r], p["bg"])):.1f} | {abs(apca(p[r], p["bg"], AGE70_WEIGHTS)):.1f} '
                   f'| {abs(apca(p[r], p["bg"], k80)):.1f} | {J:.1f} | {JHK:.1f} | {JHK - J:+.1f} | {abs(tJHK - JHK):.1f} |')
    return out + ['']

if __name__ == '__main__':
    print('## Luminance weights of the display primaries by age', '')
    print('\n'.join(weights_rows()), '')
    print('## The palettes for readers of 32, 70 and 80, and with the Helmholtz-Kohlrausch effect', '')
    for mode in ('dark', 'light'):
        print('\n'.join(palette_rows(mode)))
