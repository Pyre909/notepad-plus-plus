"""The two palettes, specified as perceptual targets (APCA Lc against the background) plus OKLCH hue and chroma.
Every colour is solved for, not picked: change a target here and the hex values follow."""
from colormath import *

# Syntax roles: (OKLCH hue, chroma, highest Lc, lowest Lc). Each gets the highest contrast at which its hue keeps
# that chroma inside sRGB: in 10 pt screenshots, colours under about C 0.10 read as plain text (thin strokes carry
# little colour), and sRGB holds little chroma near white (dark theme) or near black (light theme) for some hues.
# Light text on dark leaves room for yellow, green and cyan; dark text on light for blue, violet, magenta and red.
SPEC = {
    'dark': {
        'bg': (0.225, 0.008, 255),          # OKLCH, not solved: a dark grey, not black
        'text': (90, 0.010, 255),           # (Lc, chroma, hue)
        'comment': (64, 0.025, 250),        # cool grey: set apart by lightness, not hue
        'keyword':  (330, 0.13, 75, 65),    # pink-magenta (bold where the lexer bolds it)
        'type':     (200, 0.12, 71, 65),    # cyan, capped: with H-K it would look almost as light as text
        'string':   (145, 0.13, 75, 65),    # green
        'number':   (55, 0.12, 75, 62),     # orange
        'function': (95, 0.12, 78, 65),     # yellow
        'special':  (275, 0.10, 72, 62),    # periwinkle: preprocessor, macros, variables, labels
        'error':    (25, 0.12, 72, 60),     # red, on a red-tinted background
    },
    'light': {
        'bg': (0.985, 0.004, 90),
        'text': (98, 0.010, 255),
        'comment': (70, 0.025, 250),
        'keyword':  (335, 0.17, 85, 75),    # magenta
        'type':     (255, 0.15, 82, 72),    # blue
        'string':   (145, 0.13, 82, 72),    # green
        'number':   (40, 0.14, 82, 72),     # rust
        'function': (85, 0.10, 78, 70),     # ochre
        'special':  (295, 0.15, 82, 72),    # violet
        'error':    (25, 0.17, 82, 72),     # red
    },
}

def max_chroma(L, h):
    from colormath import _in_gamut
    lo, hi = 0.0, 0.4
    for _ in range(30):
        m = (lo + hi) / 2
        lo, hi = (m, hi) if _in_gamut(L, m, h)[0] else (lo, m)
    return lo

def solve_role(bg, h, C, lc_max, lc_min):
    """Steps contrast down from lc_max until chroma C fits in sRGB at that lightness."""
    lc = lc_max
    while True:
        L = solve_L(lc, bg, C, h)
        c = min(C, max_chroma(L, h))
        if c >= C - 1e-4 or lc <= lc_min:
            return oklch_to_hex(L, c, h)
        lc -= 0.5

def build(mode):
    s = SPEC[mode]
    bg = oklch_to_hex(*s['bg'])
    p = {'bg': bg}
    for role, spec in s.items():
        if role == 'bg':
            continue
        if len(spec) == 3:
            lc, c, h = spec
            p[role] = color_for(lc, bg, c, h)
        else:
            p[role] = solve_role(bg, *spec)
    L, C, H = s['bg']
    if mode == 'dark':
        p['margin_bg'] = oklch_to_hex(L - 0.02, C, H)
        p['line_bg'] = oklch_to_hex(L + 0.04, 0.012, H)
        p['sel_bg'] = oklch_to_hex(0.36, 0.060, 255)
        p['linenum'] = color_for(50, p['margin_bg'], 0.010, 255)
        p['guide'] = color_for(18, bg, 0.010, 255)
        p['whitespace'] = color_for(30, bg, 0.010, 255)
        p['caret'] = color_for(95, bg, 0.080, 255)
        p['brace'] = color_for(95, bg, 0.120, 85)
        p['error_bg'] = oklch_to_hex(L + 0.03, 0.040, 25)
        p['added_bg'] = oklch_to_hex(L + 0.03, 0.035, 145)
        p['multisel_bg'] = oklch_to_hex(0.31, 0.045, 255)
    else:
        p['margin_bg'] = oklch_to_hex(L - 0.025, C, H)
        p['line_bg'] = oklch_to_hex(L - 0.025, 0.010, 255)
        p['sel_bg'] = oklch_to_hex(0.895, 0.050, 255)
        p['linenum'] = color_for(55, p['margin_bg'], 0.010, 255)
        p['guide'] = color_for(18, bg, 0.010, 255)
        p['whitespace'] = color_for(30, bg, 0.010, 255)
        p['caret'] = color_for(95, bg, 0.200, 260)
        p['brace'] = color_for(95, bg, 0.160, 40)
        p['error_bg'] = oklch_to_hex(L - 0.035, 0.035, 25)
        p['added_bg'] = oklch_to_hex(L - 0.035, 0.035, 145)
        p['multisel_bg'] = oklch_to_hex(0.925, 0.035, 255)
    # terminal colours (ANSI escape sequences, error lists): by hue, at this theme's contrast and chroma limits
    ansi = {'dark': {'red': (25, 0.12, 72, 60), 'green': (145, 0.13, 75, 65), 'yellow': (95, 0.12, 78, 65),
                     'blue': (265, 0.10, 72, 60), 'magenta': (330, 0.13, 75, 65), 'cyan': (200, 0.12, 75, 65)},
            'light': {'red': (25, 0.17, 82, 72), 'green': (145, 0.13, 82, 72), 'yellow': (85, 0.10, 78, 70),
                      'blue': (255, 0.15, 82, 72), 'magenta': (335, 0.17, 85, 75), 'cyan': (195, 0.09, 76, 62)}}
    for name, spec in ansi[mode].items():
        p['ansi_' + name] = solve_role(bg, *spec)
    # find/mark highlights: Notepad++ draws them as rounded boxes under the text at alpha 100/255
    hues = {'smart': 145, 'find': 25, 'incremental': 255, 'tagmatch': 305, 'tagattr': 85,
            'mark1': 195, 'mark2': 60, 'mark3': 0, 'mark4': 285, 'mark5': 120}
    for k, h in hues.items():
        p[k] = oklch_to_hex(0.70 if mode == 'dark' else 0.78, 0.15 if mode == 'dark' else 0.17, h)
    return p

ALPHA = 100 / 255
TEXT_ROLES = ['text', 'keyword', 'type', 'string', 'number', 'special', 'function', 'comment', 'error']
SYNTAX = ['keyword', 'type', 'string', 'number', 'special', 'function', 'comment', 'error']
MARKS = ['smart', 'find', 'incremental', 'tagmatch', 'tagattr', 'mark1', 'mark2', 'mark3', 'mark4', 'mark5']

def report(mode, p):
    out = [f'## {mode}: background #{p["bg"]}', '',
           '| Role | Colour | OKLCH L C h | Lc at 32 | Lc at 70 | WCAG | on current line | on selection | worst on a find/mark highlight |',
           '|---|---|---|---|---|---|---|---|---|']
    for r in TEXT_ROLES:
        L, C, h = oklch(p[r])
        worst = min(lc(p[r], blend(p[m], p['bg'], ALPHA)) for m in MARKS)
        out.append(f'| {r} | #{p[r]} | {L:.3f} {C:.3f} {h:.0f} | {abs(apca(p[r], p["bg"])):.1f} '
                   f'| {abs(apca(p[r], p["bg"], AGE70_WEIGHTS)):.1f} | {wcag(p[r], p["bg"]):.1f}:1 '
                   f'| {lc(p[r], p["line_bg"]):.1f} | {lc(p[r], p["sel_bg"]):.1f} | {worst:.1f} |')
    out += ['', 'Other: ' + ', '.join(f'{k} #{p[k]} (Lc {lc(p[k], p["margin_bg"] if k == "linenum" else p["bg"]):.0f})'
                                       for k in ['linenum', 'guide', 'whitespace', 'caret', 'brace'])]
    # colour-vision deficiency: distance of each syntax colour from plain text, and the closest pair
    out += ['', '| Vision | min ΔE_OK syntax vs text | closest syntax pair (ΔE_OK) |', '|---|---|---|']
    for kind in ['normal', 'protan', 'deutan', 'tritan']:
        sim = {r: simulate(p[r], kind) for r in TEXT_ROLES}
        vs_text = min((de_ok(sim[r], sim['text']), r) for r in SYNTAX)
        pairs = min((de_ok(sim[a], sim[b]), f'{a}/{b}') for i, a in enumerate(SYNTAX) for b in SYNTAX[i + 1:])
        out.append(f'| {kind} | {vs_text[0]:.3f} ({vs_text[1]}) | {pairs[1]} {pairs[0]:.3f} |')
    kb = {kind: de_ok(simulate(p['keyword'], kind), simulate(p['string'], kind)) for kind in ['normal', 'protan', 'deutan', 'tritan']}
    out.append('')
    out.append('keyword vs string ΔE_OK: ' + ', '.join(f'{k} {v:.3f}' for k, v in kb.items()))
    out += ['', 'Contrast columns after Lc at 70 are for the worse-off of the two readers (32 and 70).']
    return '\n'.join(out)

if __name__ == '__main__':
    for mode in ('dark', 'light'):
        print(report(mode, build(mode)))
        print()
