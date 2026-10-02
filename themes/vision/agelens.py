"""Luminance weights of the display's R, G, B for an observer of a given age (CIE 170-1:2006 lens model).

Only the ocular media change with age in CIE 2006: D(age) = D1 * (1 + 0.02 (age - 32)) + D2 up to 60,
D1 * (1.56 + 0.0667 (age - 60)) + D2 above. Cone fundamentals at age a are the 32-year-old ones (Stockman &
Sharpe 2000 = CIE 2006, 2 deg) times 10^-(D1 * (factor(a) - 1)). Luminance is the CIE 2006 2-deg combination
0.68990272 l + 0.34832189 m. The sRGB luminance weights are scaled by each primary's change in luminance and
renormalised so white stays white (the eye adapts to the display white)."""
import warnings; warnings.filterwarnings('ignore')
import numpy as np, colour

WL = np.arange(390, 781, 5)
_raw = open(__file__.rsplit('/', 1)[0] + '/asano_cie2006_docul.dat').read().replace('\r', '\n')
D1 = np.array([float(r.split(',')[0]) for r in _raw.split('\n') if r.strip()])   # age-dependent part, 390-780/5

def _lens_factor(age):
    return 1 + 0.02 * (age - 32) if age <= 60 else 1.56 + 0.0667 * (age - 60)

def _V(age):
    lms = colour.MSDS_CMFS['Stockman & Sharpe 2 Degree Cone Fundamentals'].copy().align(colour.SpectralShape(390, 780, 5))
    l, m = lms.values[:, 0], lms.values[:, 1]
    t = 10 ** (-D1 * (_lens_factor(age) - 1))
    return (0.68990272 * l + 0.34832189 * m) * t

def _gauss(peak, fwhm):
    s = fwhm / 2.3548
    return np.exp(-0.5 * ((WL - peak) / s) ** 2)

def primaries(name):
    if name == 'LED LCD (model)':  # blue LED, broad green/red through colour filters (rough model)
        return np.stack([_gauss(615, 50), _gauss(535, 60), _gauss(448, 20)], axis=1)
    msds = colour.MSDS_DISPLAY_PRIMARIES[name].copy().align(colour.SpectralShape(390, 780, 5))
    return msds.values

SRGB_K = np.array([0.2126729, 0.7151522, 0.0721750])

def weights(age, display='LED LCD (model)'):
    P = primaries(display)
    r = (P * _V(age)[:, None]).sum(0) / (P * _V(32)[:, None]).sum(0)
    k = SRGB_K * r
    return k / k.sum()

if __name__ == '__main__':
    for d in ('LED LCD (model)', 'Apple Studio Display', 'Typical CRT Brainard 1997'):
        print(d)
        for age in (20, 32, 45, 60, 70, 80):
            print(f'  age {age}: R G B weights', np.round(weights(age, d), 4), ' lens factor', round(_lens_factor(age), 2))
