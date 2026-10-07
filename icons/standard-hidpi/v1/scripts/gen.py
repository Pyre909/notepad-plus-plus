# Generates the high-DPI standard toolbar icons: one description per icon on a 32 grid, snapped to whole pixels for each
# master grid (16, 20, 24 and 32; 40 and 48 are 20 and 24 doubled). Writes src<G>/<name>.svg. Style: one outline colour
# per material, light from the top left, 1-pixel outlines on half-pixel coordinates. The letters are drawn as paths
# (no font).
import os, math

ROOT = os.path.dirname(os.path.abspath(__file__))
GRIDS = (16, 20, 24, 32)

# ---- palette: light and dark gradient stops, and the outline of each material
MAT = {
	'page':   ('#FFFFFF', '#E4E4E4', '#6A6A6A'),
	'doc':    ('#F4F8FE', '#BCD4F2', '#2F5A9C'),
	'disk':   ('#B8CEF0', '#5A86C6', '#2F5A9C'),
	'title':  ('#B4CFF2', '#6B94CE', '#2F5A9C'),
	'green':  ('#BFE6B5', '#5B9F52', '#33702D'),
	'orange': ('#FFB27A', '#C94E12', '#8E3408'),
	'gold':   ('#FCE49A', '#D99A26', '#8E6010'),
	'red':    ('#FF7A6A', '#C40000', '#7E0000'),
	'folder': ('#FFF3BC', '#E9A93E', '#A8691A'),
	'pink':   ('#FDF3F3', '#DE9C9C', '#A34444'),
	'steel':  ('#E8EEF3', '#8AA4B6', '#4B6578'),
	'metal':  ('#F6F6F6', '#A4A4A4', '#4A4A4A'),
	'dark':   ('#9AA4AE', '#47505A', '#22282E'),
	'stop':   ('#5A5A5A', '#050505', '#000000'),
	'glass':  ('#F7FBFF', '#B3D0F2', '#4F7DB8'),
	'wood':   ('#F2CF92', '#B47E38', '#7A4E18'),
	'blueink':('#8EC0F4', '#2E6FCB', '#1C4E9C'),
	'redink': ('#FF8A80', '#D0281E', '#8A1610'),
}

class Icon:
	def __init__(self, G):
		self.G = G
		self.k = G / 32.0
		self.defs = {}
		self.body = []

	def s(self, v):  # a 32-grid coordinate snapped to a whole pixel of this grid
		return int(math.floor(v * self.k + 0.5))

	def h(self, v):  # a 32-grid coordinate snapped to a pixel centre (for 1-pixel lines and outlines)
		return self.s(v) + .5

	def px(self, v):  # a 32-grid width in whole pixels, at least 1
		return max(1, int(round(v * self.k)))

	def grad(self, mat, kind='diag'):
		gid = f'{mat}_{kind}'
		if gid not in self.defs:
			a, b, _ = MAT[mat]
			if kind == 'radial':
				self.defs[gid] = f'<radialGradient id="{gid}" cx="0.38" cy="0.32" r="0.75"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></radialGradient>'
			else:
				x2, y2 = {'diag': (1, 1), 'vert': (0, 1), 'horiz': (1, 0)}[kind]
				self.defs[gid] = f'<linearGradient id="{gid}" x1="0" y1="0" x2="{x2}" y2="{y2}"><stop offset="0" stop-color="{a}"/><stop offset="1" stop-color="{b}"/></linearGradient>'
		return f'url(#{gid})'

	def add(self, svg):
		self.body.append(svg)

	# ---- shapes: arguments in 32-grid edge coordinates (x0, y0 inclusive, x1, y1 exclusive)
	def rect(self, x0, y0, x1, y1, mat, kind='diag', fill=None):
		a, b, c, d = self.s(x0), self.s(y0), self.s(x1), self.s(y1)
		c = max(c, a + 2); d = max(d, b + 2)
		self.add(f'<rect x="{a + .5}" y="{b + .5}" width="{c - a - 1}" height="{d - b - 1}" fill="{fill or self.grad(mat, kind)}" stroke="{MAT[mat][2]}"/>')

	def bar(self, x0, y0, x1, y1, color):  # a filled rectangle without outline, snapped, at least 1 pixel
		a, b, c, d = self.s(x0), self.s(y0), self.s(x1), self.s(y1)
		c = max(c, a + 1); d = max(d, b + 1)
		self.add(f'<rect x="{a}" y="{b}" width="{c - a}" height="{d - b}" fill="{color}"/>')

	def page(self, x0, y0, x1, y1, fold, mat='page'):
		a, b, c, d = self.h(x0), self.h(y0), self.s(x1) - .5, self.s(y1) - .5
		f = max(2, self.s(fold))
		self.add(f'<path d="M{a},{b} H{c - f} L{c},{b + f} V{d} H{a} Z" fill="{self.grad(mat, "vert" if mat == "page" else "diag")}" stroke="{MAT[mat][2]}" stroke-linejoin="round"/>')
		self.add(f'<path d="M{c - f},{b} V{b + f} H{c}" fill="{MAT[mat][1]}" fill-opacity="0.55" stroke="{MAT[mat][2]}" stroke-linejoin="round"/>')

	def badge(self, cx, cy, r, mat, sign):
		# a round badge with a plus or a minus; its centre and the sign's bars on whole pixels
		x, y = self.s(cx), self.s(cy)
		rr = self.s(r) - .5
		self.add(f'<circle cx="{x}" cy="{y}" r="{rr}" fill="{self.grad(mat, "radial")}" stroke="{MAT[mat][2]}"/>')
		t = 2 if self.G <= 24 else 4
		ln = max(t + 2, int(rr * 1.25) // 2 * 2)
		self.add(f'<rect x="{x - ln / 2}" y="{y - t / 2}" width="{ln}" height="{t}" fill="#FFFFFF"/>')
		if sign == '+':
			self.add(f'<rect x="{x - t / 2}" y="{y - ln / 2}" width="{t}" height="{ln}" fill="#FFFFFF"/>')

	def window(self, x0, y0, x1, y1, title, fill='#FFFFFF'):
		self.rect(x0, y0, x1, y1, 'title', fill=fill)
		a, b, c = self.s(x0), self.s(y0), self.s(x1)
		h = max(3, self.s(title))
		self.add(f'<rect x="{a + .5}" y="{b + .5}" width="{c - a - 1}" height="{h - 1}" fill="{self.grad("title", "vert")}" stroke="{MAT["title"][2]}"/>')

	def floppy(self, x0, y0, x1, y1):
		a, b, c, d = self.s(x0), self.s(y0), self.s(x1), self.s(y1)
		w, h = c - a, d - b
		cut = max(1, round(w * 0.12))
		self.add(f'<path d="M{a + .5},{b + .5} H{c - .5 - cut} L{c - .5},{b + .5 + cut} V{d - .5} H{a + .5} Z" fill="{self.grad("disk")}" stroke="{MAT["disk"][2]}" stroke-linejoin="round"/>')
		sx0, sx1, sy1 = a + round(w * 0.22), c - round(w * 0.22), b + max(3, round(h * 0.38))
		self.add(f'<rect x="{sx0 + .5}" y="{b + .5}" width="{max(1, sx1 - sx0 - 1)}" height="{sy1 - b - 1}" fill="#FFFFFF" stroke="{MAT["disk"][2]}"/>')
		if w >= 9:
			slw = max(1, round(w * 0.12))
			self.add(f'<rect x="{sx1 - 1 - slw - max(1, round(w * 0.06))}" y="{b + 2}" width="{slw}" height="{max(1, sy1 - b - 3)}" fill="#4A78BE"/>')
		lx0, lx1, ly0 = a + round(w * 0.16), c - round(w * 0.16), b + round(h * 0.55)
		self.add(f'<rect x="{lx0 + .5}" y="{ly0 + .5}" width="{max(1, lx1 - lx0 - 1)}" height="{max(1, d - ly0 - 1)}" fill="#F4F7FC" stroke="{MAT["disk"][2]}"/>')
		if d - ly0 >= 7:
			gh = max(1, round(h * 0.08)); gap = max(1, round(h * 0.06))
			gy = ly0 + max(2, round((d - ly0 - 2 * gh - gap) / 2))
			self.add(f'<rect x="{lx0 + 2}" y="{gy}" width="{lx1 - lx0 - 4}" height="{gh}" fill="#7DBE52"/>')
			self.add(f'<rect x="{lx0 + 2}" y="{gy + gh + gap}" width="{lx1 - lx0 - 4}" height="{gh}" fill="#7DBE52"/>')

	def frame(self):  # the macro buttons' frame: 1/16 of the size, as in the originals
		a, c = self.s(3), self.s(29)
		t = 2 if self.G >= 32 else 1
		self.add(f'<rect x="{a + t / 2}" y="{a + t / 2}" width="{c - a - t}" height="{c - a - t}" fill="none" stroke="#6E6E6E" stroke-width="{t}"/>')

	def poly(self, pts, mat, kind='diag'):  # points already in pixels of this grid
		d = 'M' + ' L'.join(f'{x:g},{y:g}' for x, y in pts) + ' Z'
		self.add(f'<path d="{d}" fill="{self.grad(mat, kind)}" stroke="{MAT[mat][2]}" stroke-linejoin="round"/>')

	def spoly(self, pts, mat, kind='diag'):  # 32-grid points snapped to pixel centres
		self.poly([(self.h(x), self.h(y)) for x, y in pts], mat, kind)

	def stroke2(self, d, mat, width):
		# a stroked shape with an outline: the outline colour about 1 pixel wider underneath (d in 32-grid units, scaled)
		w = max(1.0, width * self.k)
		g = f'<g transform="scale({self.k:g})">'
		self.add(f'{g}<path d="{d}" fill="none" stroke="{MAT[mat][2]}" stroke-width="{(w + 1.2) / self.k:.3f}" stroke-linecap="round" stroke-linejoin="round"/></g>')
		self.add(f'{g}<path d="{d}" fill="none" stroke="{self.grad(mat, "vert")}" stroke-width="{w / self.k:.3f}" stroke-linecap="round" stroke-linejoin="round"/></g>')

	def svg(self):
		G = self.G
		defs = ('<defs>' + ''.join(self.defs.values()) + '</defs>\n') if self.defs else ''
		return f'<svg xmlns="http://www.w3.org/2000/svg" width="{G}" height="{G}" viewBox="0 0 {G} {G}">\n{defs}' + '\n'.join(self.body) + '\n</svg>\n'

# ---- letters drawn as strokes (32-grid units): an italic b, a and f, and braces
def letter_b(x, y, h):
	u = h / 16.0
	P = lambda px, py: f'{x + px * u:.2f},{y + py * u:.2f}'
	return f'M{P(6.5, 0)} L{P(2.5, 16)} M{P(3.6, 11.5)} C{P(5, 7)} {P(12, 6.5)} {P(12, 10.5)} C{P(12, 15)} {P(6, 17)} {P(2.8, 15)}'

def letter_a(x, y, h):
	u = h / 16.0
	P = lambda px, py: f'{x + px * u:.2f},{y + py * u:.2f}'
	return (f'M{P(10.5, 8.5)} C{P(8, 6.2)} {P(2.5, 7.5)} {P(2.2, 12.2)} C{P(2, 15.8)} {P(6.5, 16.3)} {P(9.8, 12.2)} '
		f'M{P(12.2, 6.8)} L{P(10.4, 14.6)} C{P(10.1, 16.2)} {P(11.6, 16.6)} {P(13.2, 15)}')

def letter_f(x, y, h):
	u = h / 16.0
	P = lambda px, py: f'{x + px * u:.2f},{y + py * u:.2f}'
	return f'M{P(12, 1.5)} C{P(10, -0.5)} {P(7.5, 1)} {P(7, 4)} L{P(4.5, 15)} C{P(4, 17.5)} {P(2, 18)} {P(0.5, 17)} M{P(3.5, 6)} L{P(10.5, 6)}'

def braces(x, y, h):
	u = h / 16.0
	P = lambda px, py: f'{x + px * u:.2f},{y + py * u:.2f}'
	left = f'M{P(4.5, 0)} C{P(2.2, 0)} {P(2.5, 1.5)} {P(2.5, 3.5)} L{P(2.5, 6)} C{P(2.5, 7.3)} {P(1.6, 8)} {P(0, 8)} C{P(1.6, 8)} {P(2.5, 8.7)} {P(2.5, 10)} L{P(2.5, 12.5)} C{P(2.5, 14.5)} {P(2.2, 16)} {P(4.5, 16)}'
	right = f'M{P(7, 0)} C{P(9.3, 0)} {P(9, 1.5)} {P(9, 3.5)} L{P(9, 6)} C{P(9, 7.3)} {P(9.9, 8)} {P(11.5, 8)} C{P(9.9, 8)} {P(9, 8.7)} {P(9, 10)} L{P(9, 12.5)} C{P(9, 14.5)} {P(9.3, 16)} {P(7, 16)}'
	return left + ' ' + right

# ---- the icons, each drawn with 32-grid coordinates
def newFile(i):
	i.page(3, 1, 28, 31, 7); i.badge(23, 24, 8, 'green', '+')

def closeFile(i):
	i.page(3, 1, 28, 31, 7)
	for y, x1 in ((7, 18), (11, 22), (15, 20), (19, 15)):
		i.bar(7, y, x1, y + 1.5, '#8E8E8E')
	i.badge(23, 24, 8, 'orange', '-')

def closeAll(i):
	for o in (0, 4, 8):
		i.page(1 + o, 1 + o * 0.75, 19 + o, 24 + o * 0.75, 5)
	i.badge(23, 24, 8, 'orange', '-')

def openFile(i):
	i.page(12, 0, 31, 23, 6, 'doc')
	a, b, c, d = i.h(1), i.h(13), i.s(24) - .5, i.s(31) - .5
	tab = i.h(8)
	i.add(f'<path d="M{a},{b} H{tab} L{tab + 2},{b + 2} H{c} V{d} H{a} Z" fill="{i.grad("folder", "vert")}" stroke="{MAT["folder"][2]}" stroke-linejoin="round"/>')
	y0 = i.h(19)
	i.add(f'<path d="M{a},{d} L{a + i.s(2)},{y0} H{i.s(26) - .5} L{c},{d} Z" fill="{i.grad("folder", "vert")}" stroke="{MAT["folder"][2]}" stroke-linejoin="round"/>')

def saveFile(i):
	i.floppy(2, 2, 30, 30)

def saveAll(i):
	for o in (0, 5, 10): i.floppy(1 + o, 1 + o, 21 + o, 21 + o)

def print_(i):
	i.page(8, 1, 25, 15, 4, 'doc')
	i.rect(1, 13, 31, 26, 'metal', 'vert')
	i.bar(2, 14, 30, 17, '#FAFAFA')           # the top face, lit
	i.bar(3, 19, 29, 20.5, '#5E5E5E')          # the paper slot
	i.bar(25, 15, 28, 16.5, '#4FA838')         # the light
	i.rect(6, 25, 26, 31, 'doc', 'vert')

def cut(i):
	k = i.k
	# open scissors leaning right, as the original: blades from the pivot up to the top right, handles at the bottom left
	i.spoly([(21, 1), (23.5, 2.5), (14, 19), (12, 17.5)], 'steel', 'horiz')
	i.spoly([(28.5, 6), (30, 8.5), (14.5, 19.5), (13.5, 16.5)], 'steel', 'horiz')
	r = i.s(3.5) + .5
	for cx, cy in ((7.5, 23), (16, 26.5)):
		x, y = i.s(cx), i.s(cy)
		w = 2 if i.G >= 32 else 1
		i.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="{MAT["redink"][2]}" stroke-width="{w + 1}"/>')
		i.add(f'<circle cx="{x}" cy="{y}" r="{r}" fill="none" stroke="#D84A3C" stroke-width="{w}"/>')

def docpair(i, a, b):
	i.page(*a, 5, 'doc'); i.page(*b, 5, 'doc')

def copy(i):
	docpair(i, (1, 1, 19, 23), (12, 9, 31, 31))

def paste(i):
	i.rect(1, 3, 23, 31, 'wood')
	i.rect(4, 6, 20, 28, 'wood', fill='#FBF4E6')
	i.rect(7, 1, 17, 6, 'metal', 'vert')
	i.page(13, 12, 31, 31, 5, 'doc')

def band(i, mirror):
	# undo: the band runs right from the top left, turns down, comes back left and ends in an arrowhead pointing left
	G, s = i.G, i.s
	T = s(5); Ro = s(10); x0 = s(5) + .5; yt = s(3) + .5
	cx = G - .5 - Ro - s(1); cy = yt + Ro
	xb = s(12) + .5; mid = cy + Ro - T / 2.0; H = s(14) / 2.0; L = s(10)
	Ri = Ro - T
	f = (lambda x, y: (G - x, G - y)) if mirror else (lambda x, y: (x, y))  # redo: turned half a turn
	def P(x, y):
		a, b = f(x, y); return f'{a:g},{b:g}'
	d = (f'M{P(x0, yt)} L{P(cx, yt)} A{Ro},{Ro} 0 0 1 {P(cx, cy + Ro)} L{P(xb, cy + Ro)} L{P(xb, mid + H)} L{P(xb - L, mid)} '
		f'L{P(xb, mid - H)} L{P(xb, cy + Ro - T)} L{P(cx, cy + Ro - T)} A{Ri},{Ri} 0 0 0 {P(cx, yt + T)} L{P(x0, yt + T)} Z')
	i.add(f'<path d="{d}" fill="{i.grad("green", "vert")}" stroke="{MAT["green"][2]}" stroke-linejoin="round"/>')

def undo(i): band(i, False)
def redo(i): band(i, True)

def find(i):
	i.rect(5, 4, 13, 13, 'dark', 'horiz'); i.rect(19, 4, 27, 13, 'dark', 'horiz')
	i.rect(12, 9, 20, 17, 'dark', 'vert')
	i.rect(2, 11, 14, 29, 'dark', 'horiz'); i.rect(18, 11, 30, 29, 'dark', 'horiz')
	i.rect(4, 21, 12, 27, 'glass', 'diag'); i.rect(20, 21, 28, 27, 'glass', 'diag')

def findReplace(i):
	i.stroke2(letter_b(1, 0.5, 17), 'blueink', 2.6)
	i.stroke2(letter_a(14, 13, 18), 'blueink', 2.6)
	i.stroke2('M10.5,12.5 L15.5,17.5', 'green', 1.8)
	i.poly([(18.6 * i.k, 14.3 * i.k), (19.2 * i.k, 21.2 * i.k), (12.3 * i.k, 20.8 * i.k)], 'green')

def magnifier(i, sign):
	k, s = i.k, i.s
	w = i.px(5)
	x1, y1, x2, y2 = s(18.5), s(20.5), s(28), s(30)
	i.add(f'<path d="M{x1},{y1} L{x2},{y2}" stroke="{MAT["wood"][2]}" stroke-width="{w + 2}" stroke-linecap="round"/>')
	i.add(f'<path d="M{x1},{y1} L{x2},{y2}" stroke="{i.grad("wood")}" stroke-width="{w}" stroke-linecap="round"/>')
	cx, cy, r = s(12), s(13), s(9.5) - .5
	i.add(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{i.grad("glass", "radial")}" stroke="{MAT["glass"][2]}"/>')
	i.add(f'<path d="M{6.5 * k:.2f},{11 * k:.2f} A{6 * k:.2f},{6 * k:.2f} 0 0 1 {11 * k:.2f},{6.5 * k:.2f}" fill="none" stroke="#FFFFFF" stroke-width="{max(1, round(1.4 * k))}" stroke-linecap="round"/>')
	if sign == '+':
		t = s(4); c0x, c0y = s(19), s(7); L = s(12); m = (L - t) // 2
		i.add(f'<path d="M{c0x + m + .5},{c0y + .5} h{t - 1} v{m} h{m} v{t - 1} h-{m} v{m} h-{t - 1} v-{m} h-{m} v-{t - 1} h{m} Z" fill="{i.grad("green", "vert")}" stroke="{MAT["green"][2]}" stroke-linejoin="round"/>')
	else:
		i.rect(17, 10, 31, 15, 'red', 'vert')

def zoomIn(i): magnifier(i, '+')
def zoomOut(i): magnifier(i, '-')

def syncLock(i, vertical):
	i.window(1, 2, 27, 28, 5, fill='#D2E2F5')
	if vertical:
		i.rect(4, 8, 14, 26, 'title', fill='#FFFFFF'); i.rect(15, 8, 25, 26, 'title', fill='#FFFFFF')
	else:
		i.rect(4, 8, 25, 16, 'title', fill='#FFFFFF'); i.rect(4, 17, 25, 26, 'title', fill='#FFFFFF')
	s = i.s
	w = i.px(2.6)
	x0, x1, top, base = s(20) + (.5 if w % 2 else 0), s(29) - (.5 if w % 2 else 0), s(12), s(20)
	r = (x1 - x0) / 2
	i.add(f'<path d="M{x0},{base} V{top + r} A{r},{r} 0 0 1 {x1},{top + r} V{base}" fill="none" stroke="#6E6E6E" stroke-width="{w}"/>')
	i.rect(16, 19, 32, 31, 'gold', 'vert')
	i.bar(23, 22.5, 25, 27.5, MAT['gold'][2])

def syncV(i): syncLock(i, True)
def syncH(i): syncLock(i, False)

def wrap(i):
	for y, x1 in ((3, 23), (8, 23), (13, 15)):
		i.bar(1, y, x1, y + 3, '#4A4A4A')
	s = i.s
	t = 2 if i.G <= 24 else 3
	x0, y0, x1, y1 = s(19), s(19), s(29), s(27)
	i.add(f'<path d="M{x0},{y0 + t / 2} H{x1 - t / 2} V{y1 + t / 2} H{s(23)}" fill="none" stroke="{MAT["doc"][2]}" stroke-width="{t}"/>')
	ah = s(5)
	i.poly([(s(23) + .5, y1 + t / 2 - ah), (s(23) - ah + .5, y1 + t / 2), (s(23) + .5, y1 + t / 2 + ah)], 'blueink')
	i.rect(1, 24, 17, 30, 'doc', 'vert')

def allChars(i):
	s = i.s
	a, top, bot = s(8) + .5, s(3) + .5, s(30) - .5
	x1, x2, x3, x4 = s(15) + .5, s(19) - .5, s(21) + .5, s(25) - .5
	r = s(6.5); y = top + 2 * r
	i.add(f'<path d="M{x4},{top} H{a + r} A{r},{r} 0 0 0 {a + r},{y} H{x1} V{bot} H{x2} V{s(7) + .5} H{x3} V{bot} H{x4} Z" fill="{i.grad("blueink")}" stroke="{MAT["blueink"][2]}" stroke-linejoin="round"/>')

def indentGuide(i):
	B, R = '#1A3CFF', '#FF2020'
	rows = ((2, (1, 10), (14, 31)), (7, None, (14, 23)), (12, None, (14, 31)), (17, None, (14, 27)), (22, (1, 10), (14, 31)), (27, (1, 5), (14, 17)))
	for y, l, rr in rows:
		if l: i.bar(l[0], y, l[1], y + 3, B)
		i.bar(rr[0], y, rr[1], y + 3, B)
	for y in (7, 12, 17) if i.G >= 24 else (7, 17):  # at 16 and 20 pixels three dots would touch
		i.bar(5, y, 8, y + 3, R)

def monitoring(i):
	k = i.k
	i.add(f'<path d="M{1 * k:.2f},{16 * k:.2f} C{5 * k:.2f},{4.5 * k:.2f} {27 * k:.2f},{4.5 * k:.2f} {31 * k:.2f},{16 * k:.2f} C{27 * k:.2f},{27.5 * k:.2f} {5 * k:.2f},{27.5 * k:.2f} {1 * k:.2f},{16 * k:.2f} Z" fill="#FFFBF0" stroke="#8C6C44"/>')
	c = i.s(16); r = i.s(8) - .5
	i.add(f'<circle cx="{c}" cy="{c}" r="{r}" fill="{i.grad("glass", "radial")}" stroke="#3E6290"/>')
	i.add(f'<circle cx="{c}" cy="{c}" r="{i.s(4.5)}" fill="#4C6F94"/>')
	i.add(f'<circle cx="{c}" cy="{c}" r="{max(1, i.s(2.6))}" fill="#141414"/>')
	i.add(f'<circle cx="{13.6 * k:.2f}" cy="{13.4 * k:.2f}" r="{1.5 * k:.2f}" fill="#FFFFFF"/>')

def fileBrowser(i):
	a, b, c, d = i.h(1), i.h(4), i.s(31) - .5, i.s(29) - .5
	tab = i.h(11)
	i.add(f'<path d="M{a},{b} H{tab} L{tab + 2},{b + 2} H{c} V{d} H{a} Z" fill="{i.grad("pink", "vert")}" stroke="{MAT["pink"][2]}" stroke-linejoin="round"/>')
	i.rect(1, 11, 31, 29, 'pink', 'vert')
	i.bar(3, 13, 29, 14, '#FFFFFF')

def funcList(i):
	i.page(5, 1, 29, 31, 7)
	i.stroke2(letter_f(3, 6, 21), 'redink', 2.8)
	if i.G >= 24:
		w = 1.6 if i.G >= 32 else 1.4
		i.add(f'<g transform="scale({i.k:g})"><path d="{braces(15, 11, 17)}" fill="none" stroke="#5E5E5E" stroke-width="{w / i.k:.3f}" stroke-linecap="round"/></g>')

def docList(i):
	i.window(1, 2, 28, 29, 5)
	i.page(8, 8, 22, 26, 4, 'doc'); i.page(15, 13, 30, 31, 4, 'doc')

def docMap(i):
	s, k = i.s, i.k
	i.bar(2, 2, 30, 30, '#EFE78E')
	i.add(f'<path d="M{15 * k:.2f},{2 * k:.2f} H{30 * k:.2f} V{19 * k:.2f} C{25 * k:.2f},{18 * k:.2f} {19 * k:.2f},{13 * k:.2f} {15 * k:.2f},{2 * k:.2f} Z" fill="#7DAEE6"/>')
	i.add(f'<path d="M{2 * k:.2f},{19 * k:.2f} C{7 * k:.2f},{16 * k:.2f} {10 * k:.2f},{22 * k:.2f} {14 * k:.2f},{20 * k:.2f} C{19 * k:.2f},{18 * k:.2f} {21 * k:.2f},{25 * k:.2f} {24 * k:.2f},{30 * k:.2f} H{2 * k:.2f} Z" fill="#86B866"/>')
	w = 2 if i.G >= 24 else 1
	i.add(f'<path d="M{5 * k:.2f},{3 * k:.2f} L{12 * k:.2f},{13 * k:.2f} L{16 * k:.2f},{24 * k:.2f} L{18 * k:.2f},{30 * k:.2f} M{12 * k:.2f},{13 * k:.2f} L{25 * k:.2f},{22 * k:.2f}" fill="none" stroke="#D02A2A" stroke-width="{w}" stroke-linecap="round" stroke-linejoin="round"/>')
	t = max(1, round(i.G / 16))
	a, c = s(2), s(30)
	i.add(f'<rect x="{a + t / 2}" y="{a + t / 2}" width="{c - a - t}" height="{c - a - t}" fill="none" stroke="#4C4C6C" stroke-width="{t}"/>')

def udl(i):
	i.window(1, 2, 31, 29, 5)
	i.spoly([(19.5, 8.5), (9.5, 19.5), (15.5, 19.5), (11.5, 29.5), (24.5, 16.5), (18, 16.5), (22.5, 8.5)], 'gold')

def startRecord(i):
	i.frame()
	c = i.G / 2
	i.add(f'<circle cx="{c}" cy="{c}" r="{i.s(9.5) - .5}" fill="{i.grad("red", "radial")}" stroke="{MAT["red"][2]}"/>')

def stopRecord(i):
	i.frame(); i.rect(8, 8, 24, 24, 'stop')

def playRecord(i):
	i.frame()
	i.spoly([(11, 7.5), (24.5, 16), (11, 24.5)], 'blueink')

def playRecord_m(i):
	i.frame()
	i.spoly([(6.5, 7.5), (16.5, 16), (6.5, 24.5)], 'blueink')
	i.spoly([(14.5, 7.5), (25.5, 16), (14.5, 24.5)], 'blueink')

def saveRecord(i):
	i.window(1, 1, 26, 24, 5)
	for y in (8, 12, 16, 20) if i.G >= 32 else (8, 13, 18):
		i.bar(4, y, 9, y + 2, '#9CBCE8'); i.bar(11, y, 23 if y < 16 else 15, y + 2, '#9CBCE8')
	i.floppy(14, 14, 31, 31)

ICONS = {
	'newFile': newFile, 'openFile': openFile, 'saveFile': saveFile, 'saveAll': saveAll, 'closeFile': closeFile,
	'closeAll': closeAll, 'print': print_, 'cut': cut, 'copy': copy, 'paste': paste, 'undo': undo, 'redo': redo,
	'find': find, 'findReplace': findReplace, 'zoomIn': zoomIn, 'zoomOut': zoomOut, 'syncV': syncV, 'syncH': syncH,
	'wrap': wrap, 'allChars': allChars, 'indentGuide': indentGuide, 'udl': udl, 'docMap': docMap, 'docList': docList,
	'funcList': funcList, 'fileBrowser': fileBrowser, 'monitoring': monitoring, 'startRecord': startRecord,
	'stopRecord': stopRecord, 'playRecord': playRecord, 'playRecord_m': playRecord_m, 'saveRecord': saveRecord,
}

if __name__ == '__main__':
	for G in GRIDS:
		d = os.path.join(ROOT, f'src{G}'); os.makedirs(d, exist_ok=True)
		for name, fn in ICONS.items():
			i = Icon(G); fn(i)
			with open(os.path.join(d, name + '.svg'), 'w', encoding='utf-8', newline='\n') as f:
				f.write(i.svg())
	print(len(ICONS), 'icons x', len(GRIDS), 'grids')
