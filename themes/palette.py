"""The two palettes (version 2), specified in OKLCH: change a number here and the hex values follow.

Version 1 solved each colour for the highest contrast its hue allowed. It was legible but looked off: neon cyan
next to pastel pink in the dark theme, olive and brown in the light theme, seven hues pulling in every
direction. Version 2 is designed for harmony first, with legibility as a hard floor:
- all syntax colours of a theme share one lightness, and their chroma is held below the sRGB gamut edge
  (gamut_frac), so no colour looks neon or washed out next to another;
- every role keeps its hue in both themes; only the light theme's numbers sit a little lighter, because orange
  turns brown when darkened (dark yellow and brown are the least liked colours: Palmer & Schloss 2010);
- the neutrals (background, text, comments) share one slight tint per theme.
The floors (WCAG 2 AA and APCA, for readers aged 32 and 70) are checked by check.py and listed by
`python3 palette.py`."""
from colormath import *

ROLES = ('keyword', 'function', 'type', 'string', 'number', 'special', 'error')
HUES = {'keyword': 300, 'function': 252, 'type': 200, 'string': 142, 'number': 55, 'special': 340, 'error': 25}

SPEC = {
    'dark': {   # slate
        'bg': (0.255, 0.014, 262), 'text': (0.890, 0.012, 262), 'comment': (0.730, 0.020, 262),
        'accent_L': 0.80, 'accent_C': 0.11, 'gamut_frac': 0.80, 'hues': dict(HUES),
        'C': {'type': 0.095},                       # cyan carries more apparent saturation (and H-K) per unit chroma
    },
    'light': {  # soft paper
        'bg': (0.978, 0.006, 85), 'text': (0.270, 0.012, 262), 'comment': (0.530, 0.016, 262),
        'accent_L': 0.50, 'accent_C': 0.15, 'gamut_frac': 0.85, 'hues': dict(HUES, number=50),
        'L': {'number': 0.53}, 'C': {'number': 0.135}, 'frac': {'number': 0.95},   # orange, not brown
    },
}

def max_chroma(L, h):
    from colormath import _in_gamut
    lo, hi = 0.0, 0.4
    for _ in range(30):
        m = (lo + hi) / 2
        lo, hi = (m, hi) if _in_gamut(L, m, h)[0] else (lo, m)
    return lo

def accent(s, role, L=None):
    h = s['hues'][role]
    L = s.get('L', {}).get(role, s['accent_L']) if L is None else L
    C = min(s.get('C', {}).get(role, s['accent_C']), s.get('frac', {}).get(role, s['gamut_frac']) * max_chroma(L, h))
    return oklch_to_hex(L, C, h)

def build(mode):
    s = SPEC[mode]
    p = {k: oklch_to_hex(*s[k]) for k in ('bg', 'text', 'comment')}
    for r in ROLES:
        p[r] = accent(s, r)
    L, C, H = s['bg']
    tL, tC, tH = s['text']
    if mode == 'dark':
        p['margin_bg'] = oklch_to_hex(L - 0.020, C, H)
        p['line_bg'] = oklch_to_hex(L + 0.035, C, H)
        p['sel_bg'] = oklch_to_hex(0.385, 0.055, 255)
        p['multisel_bg'] = oklch_to_hex(0.340, 0.040, 255)
        p['linenum'] = oklch_to_hex(0.580, 0.015, tH)
        p['guide'] = oklch_to_hex(0.345, 0.012, tH)
        p['whitespace'] = oklch_to_hex(0.460, 0.012, tH)
        p['caret'] = oklch_to_hex(0.870, 0.090, 252)
        p['brace'] = oklch_to_hex(0.900, 0.110, 90)
        p['error_bg'] = oklch_to_hex(L + 0.045, 0.045, 25)
        p['added_bg'] = oklch_to_hex(L + 0.040, 0.040, 142)
        mark_L, mark_C = 0.58, 0.13      # highlight fills: text stays above 6.5:1 on them
        p['ansi_yellow'] = oklch_to_hex(0.82, 0.11, 90)
    else:
        p['margin_bg'] = oklch_to_hex(L - 0.022, C + 0.002, H)
        p['line_bg'] = oklch_to_hex(L - 0.022, C + 0.003, H)
        p['sel_bg'] = oklch_to_hex(0.900, 0.050, 255)
        p['multisel_bg'] = oklch_to_hex(0.910, 0.035, 255)
        p['linenum'] = oklch_to_hex(0.600, 0.012, tH)
        p['guide'] = oklch_to_hex(0.880, 0.008, H)
        p['whitespace'] = oklch_to_hex(0.780, 0.010, H)
        p['caret'] = oklch_to_hex(0.420, 0.150, 252)
        p['brace'] = oklch_to_hex(0.470, 0.170, 20)
        p['error_bg'] = oklch_to_hex(L - 0.040, 0.030, 25)
        p['added_bg'] = oklch_to_hex(L - 0.040, 0.040, 142)
        mark_L, mark_C = 0.82, 0.12
        p['ansi_yellow'] = p['number']                 # yellow on paper would be olive: use the orange
    # terminal colours (ANSI escape sequences, error lists): the syntax colour of the same hue
    p.update(ansi_red=p['error'], ansi_green=p['string'], ansi_blue=p['function'], ansi_magenta=p['special'],
             ansi_cyan=p['type'])
    # find/mark highlights (rounded boxes under the text at alpha 100/255), in the palette's hues
    for k, h in {'smart': 142, 'find': 25, 'incremental': 252, 'tagmatch': 300, 'tagattr': 85,
                 'mark1': 200, 'mark2': 55, 'mark3': 340, 'mark4': 280, 'mark5': 120}.items():
        p[k] = oklch_to_hex(mark_L, mark_C, h)
    return p

ALPHA = 100 / 255
TEXT_ROLES = ['text', 'keyword', 'function', 'type', 'string', 'number', 'special', 'error', 'comment']
SYNTAX = ['keyword', 'function', 'type', 'string', 'number', 'special', 'error']
MARKS = ['smart', 'find', 'incremental', 'tagmatch', 'tagattr', 'mark1', 'mark2', 'mark3', 'mark4', 'mark5']

def report(mode, p):
    out = [f'## {mode}: background #{p["bg"]}', '',
           '| Role | Colour | OKLCH L C h | of max chroma | WCAG (worse reader) | APCA Lc at 32 | Lc at 70 | on current line | on selection | worst on a highlight |',
           '|---|---|---|---|---|---|---|---|---|---|']
    for r in TEXT_ROLES:
        L, C, h = oklch(p[r])
        worst = min(lc(p[r], blend(p[m], p['bg'], ALPHA)) for m in MARKS)
        out.append(f'| {r} | #{p[r]} | {L:.3f} {C:.3f} {h:.0f} | {C / max(max_chroma(L, h), 1e-6):.0%} '
                   f'| {wcag_worst(p[r], p["bg"]):.1f}:1 | {abs(apca(p[r], p["bg"])):.1f} '
                   f'| {abs(apca(p[r], p["bg"], AGE70_WEIGHTS)):.1f} | {lc(p[r], p["line_bg"]):.1f} '
                   f'| {lc(p[r], p["sel_bg"]):.1f} | {worst:.1f} |')
    out += ['', 'Other: ' + ', '.join(f'{k} #{p[k]} ({wcag_worst(p[k], p["margin_bg"] if k == "linenum" else p["bg"]):.1f}:1)'
                                       for k in ['linenum', 'guide', 'whitespace', 'caret', 'brace'])]
    out += ['', '| Vision | nearest syntax colour to text (ΔE_OK) | closest syntax pair (ΔE_OK) |', '|---|---|---|']
    for kind in ['normal', 'protan', 'deutan', 'tritan']:
        sim = {r: simulate(p[r], kind) for r in TEXT_ROLES}
        vs_text = min((de_ok(sim[r], sim['text']), r) for r in SYNTAX)
        pairs = min((de_ok(sim[a], sim[b]), f'{a}/{b}') for i, a in enumerate(SYNTAX) for b in SYNTAX[i + 1:])
        out.append(f'| {kind} | {vs_text[0]:.3f} ({vs_text[1]}) | {pairs[1]} {pairs[0]:.3f} |')
    kb = {kind: de_ok(simulate(p['keyword'], kind), simulate(p['string'], kind)) for kind in ['normal', 'protan', 'deutan', 'tritan']}
    out += ['', 'keyword vs string ΔE_OK: ' + ', '.join(f'{k} {v:.3f}' for k, v in kb.items()),
            '', 'WCAG and the contrast columns after "Lc at 70" are for the worse-off of two readers, aged 32 and 70.']
    return '\n'.join(out)

if __name__ == '__main__':
    for mode in ('dark', 'light'):
        print(report(mode, build(mode)))
        print()
