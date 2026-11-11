# Generates the tab bar's icons (Pyre909 build, 2026-11-10): line drawings, sharp at every scale. The document states
# (saved, unsaved, read-only, read-only by the file's attribute, monitoring, and the "alternate icons" set) on a 16 grid,
# 16 to 48 pixels; the close and pin buttons on an 11 grid, 11 to 33 pixels. One SVG per icon and size, its strokes a
# whole number of pixels (1, 2 or 3 by size) and its straight edges snapped to whole pixels. Writes svg/<name>-<size>.svg.
import math, os

ROOT = os.path.dirname(os.path.abspath(__file__))
DOC_SIZES = (16, 20, 24, 28, 32, 40, 48)
BTN_SIZES = (11, 14, 17, 19, 22, 28, 33)

# colours: one per meaning, as the icons they replace (blue saved, red unsaved, grey read-only, the pink close box...)
BLUE = '#1F5FAD'
RED = '#C2410C'
GREY = '#6B7280'
GREEN = '#2F7A2F'
AMBER = '#9A5B08'
INK = '#4B4F57'


class Icon:
	def __init__(self, size, base):
		self.size, self.base = size, base
		self.k = size / base
		self.w = 1 if self.k < 1.45 else (2 if self.k < 2.4 else 3)  # the stroke, in pixels
		self.sw = self.w / self.k                                    # in grid units
		self.body = []

	# grid coordinates snapped for a stroke: L an edge the stroke lies after (left, top), R before (right, bottom), C a
	# line's centre; all returned in grid units
	def px(self, v):
		return math.floor(v * self.k + 0.5)

	def L(self, v):
		return (self.px(v) + self.w / 2) / self.k

	def R(self, v):
		return (self.px(v) - self.w / 2) / self.k

	def C(self, v):
		p = v * self.k
		return ((math.floor(p) + 0.5) if self.w % 2 else math.floor(p + 0.5)) / self.k

	def add(self, svg):
		self.body.append(svg)

	def path(self, d, colour, fill='none', width=None, cap='round'):
		self.add(f'<path d="{d}" fill="{fill}" stroke="{colour}" stroke-width="{(width or self.w) / self.k:.4f}" '
			f'stroke-linecap="{cap}" stroke-linejoin="round"/>')

	def svg(self):
		return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{self.size}" height="{self.size}" '
			f'viewBox="0 0 {self.size} {self.size}"><g transform="scale({self.k:.6f})">' + ''.join(self.body) + '</g></svg>')


def f(v):
	return f'{v:.4f}'.rstrip('0').rstrip('.')


# ---- document states (16 grid)
def floppy(i, colour, centre='hub'):
	# the body with its cut corner, the shutter at the top, and a hub (or an F: the file's own read-only attribute)
	l, t, r, b = i.L(2), i.L(2), i.R(14), i.R(14)
	notch = max(2, i.px(3)) / i.k
	i.path(f'M{f(l)},{f(t)} H{f(r - notch)} L{f(r)},{f(t + notch)} V{f(b)} H{f(l)} Z', colour)
	sl, sr, sb = i.L(5), i.R(10.5), i.R(6.5)
	i.path(f'M{f(sl)},{f(t)} V{f(sb)} H{f(sr)} V{f(t)}', colour)
	if centre == 'hub':
		# a small label, centred, on whole pixels (a circle blurs at 16 px)
		hl, hr, ht, hb = i.L(5.75), i.R(10.25), i.L(8.75), i.R(12.25)
		i.add(f'<rect x="{f(hl)}" y="{f(ht)}" width="{f(hr - hl)}" height="{f(hb - ht)}" rx="{f(0.5)}" fill="none" '
			f'stroke="{colour}" stroke-width="{f(i.sw)}"/>')
	else:
		letter_f(i, colour, 6.5, 8.25, 12.5)


def letter_f(i, colour, x, top, bottom):
	# an F on pixel rows: its stem, its top bar three pixels long (at 16 px), its middle bar two
	sx, ty, my, by = i.C(x), i.C(top), i.C(top + (bottom - top) * 0.5), i.C(bottom)
	i.path(f'M{f(sx)},{f(by)} V{f(ty)} H{f(i.C(x + 3))} M{f(sx)},{f(my)} H{f(i.C(x + 2))}', colour, cap='square')


def eye(i, colour):
	i.path('M1.5,8 C4,3.6 12,3.6 14.5,8 C12,12.4 4,12.4 1.5,8 Z', colour)
	i.add(f'<circle cx="8" cy="8" r="2.1" fill="{colour}" fill-opacity="0.18" stroke="{colour}" stroke-width="{f(i.sw)}"/>')


def check(i, colour):
	i.path('M3.25,8.5 L6.5,11.75 L12.75,4.5', colour, width=max(2, i.w))


def pencil(i, colour):
	# from the bottom left (its point) up to the right (its end), the ferrule across it
	i.path('M2.5,13.5 L3.25,10.5 L10.75,3 Q12,1.75 13.25,3 Q14.5,4.25 13.25,5.5 L5.75,13 Z', colour)
	i.path('M9.5,4.25 L12,6.75', colour)
	i.path('M3.25,10.5 L5.75,13', colour)


def lock(i, colour, mark='keyhole'):
	l, t, r, b = i.L(3), i.L(7.5), i.R(13), i.R(14.5)
	i.add(f'<rect x="{f(l)}" y="{f(t)}" width="{f(r - l)}" height="{f(b - t)}" rx="{f(min(1.25, (r - l) / 4))}" fill="none" '
		f'stroke="{colour}" stroke-width="{f(i.sw)}"/>')
	sl, sr = i.C(5.5), i.C(10.5)
	i.path(f'M{f(sl)},{f(t)} V5 A{f((sr - sl) / 2)},{f((sr - sl) / 2)} 0 0 1 {f(sr)},5 V{f(t)}', colour)
	if mark == 'keyhole':
		# an even width, centred on the body's middle (a whole pixel boundary)
		kw = i.w if i.w % 2 == 0 else i.w + 1
		x = i.px(8) / i.k
		i.path(f'M{f(x)},{f(i.L(9.75))} V{f(i.R(12.5))}', colour, width=kw, cap='butt')
	else:
		letter_f(i, colour, 6.5, 9.25, 13)


DOCS = {
	'saved': lambda i: floppy(i, BLUE),
	'unsaved': lambda i: floppy(i, RED),
	'readonly': lambda i: floppy(i, GREY),
	'readonly_sys': lambda i: floppy(i, GREY, 'F'),
	'monitoring': lambda i: eye(i, GREEN),
	'saved_alt': lambda i: check(i, GREEN),
	'unsaved_alt': lambda i: pencil(i, RED),
	'readonly_alt': lambda i: lock(i, AMBER),
	'readonly_sys_alt': lambda i: lock(i, AMBER, 'F'),
}


# ---- buttons (11 grid)
def close_box(i, fill, border, cross):
	l, t, r, b = i.L(0), i.L(0), i.R(11), i.R(11)
	i.add(f'<rect x="{f(l)}" y="{f(t)}" width="{f(r - l)}" height="{f(b - t)}" rx="{f(2.25)}" fill="{fill}" stroke="{border}" '
		f'stroke-width="{f(i.sw)}"/>')
	a, z = i.C(3.5), i.C(7.5)
	if i.w % 2 == 0:  # an even stroke: its ends on whole pixels too
		a, z = i.px(3.5) / i.k, i.px(7.5) / i.k
	i.path(f'M{f(a)},{f(a)} L{f(z)},{f(z)} M{f(z)},{f(a)} L{f(a)},{f(z)}', cross)


def pin(i, colour, pinned):
	# upright when pinned (filled), tilted when not; upright too below 17 px (a tilted pin blurs at 11 and 14 px: there
	# the colour and the fill tell them apart)
	shape = ('M3.25,1.5 H7.75 M4,1.5 V4.25 L2.5,6.5 H8.5 L7,4.25 V1.5 M5.5,6.5 V10')
	head_fill = '#D6E6F7' if pinned else 'none'
	g = '' if (pinned or i.size < 17) else ' transform="rotate(45 5.5 5.5)"'
	i.add(f'<g{g}><path d="M4,1.5 V4.25 L2.5,6.5 H8.5 L7,4.25 V1.5 Z" fill="{head_fill}" stroke="none"/>'
		f'<path d="{shape}" fill="none" stroke="{colour}" stroke-width="{f(i.sw)}" stroke-linecap="round" stroke-linejoin="round"/></g>')


BUTTONS = {
	'closeTabButton': lambda i: close_box(i, '#F7DBE2', '#E3A1B3', '#A32D2D'),
	'closeTabButton_hoverOnTab': lambda i: close_box(i, '#EDEDED', '#CDCDCD', '#757575'),
	'closeTabButton_hoverIn': lambda i: close_box(i, '#D9443A', '#B8322A', '#FFFFFF'),
	'closeTabButton_push': lambda i: close_box(i, '#A32D2D', '#82201F', '#FFFFFF'),
	'pinTabButton': lambda i: pin(i, INK, False),
	'pinTabButton_pinned': lambda i: pin(i, BLUE, True),
}


def main():
	out = os.path.join(ROOT, 'svg')
	os.makedirs(out, exist_ok=True)
	for group, base, sizes in ((DOCS, 16, DOC_SIZES), (BUTTONS, 11, BTN_SIZES)):
		for name, draw in group.items():
			for size in sizes:
				icon = Icon(size, base)
				draw(icon)
				with open(os.path.join(out, f'{name}-{size}.svg'), 'w', encoding='utf-8', newline='\n') as fh:
					fh.write(icon.svg())
	print(f'{len(DOCS) * len(DOC_SIZES) + len(BUTTONS) * len(BTN_SIZES)} SVGs')


if __name__ == '__main__':
	main()
