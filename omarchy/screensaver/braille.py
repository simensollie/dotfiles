#!/usr/bin/env python3
"""Image -> braille text. Dithers tonally instead of hard-thresholding, so the
phoenix keeps its internal feather structure instead of collapsing to a blob."""
import argparse
from PIL import Image, ImageOps, ImageFilter, ImageEnhance

DOTS = ((0x01, 0x08), (0x02, 0x10), (0x04, 0x20), (0x40, 0x80))  # [row][col] -> bit

p = argparse.ArgumentParser()
p.add_argument('image')
p.add_argument('--cols', type=int, default=128)
p.add_argument('--rows', type=int, default=33)
p.add_argument('--gamma', type=float, default=1.0)      # <1 darkens ink, >1 spreads it
p.add_argument('--contrast', type=float, default=1.0)
p.add_argument('--black', type=float, default=0.0)     # ink below this fraction -> nothing
p.add_argument('--white', type=float, default=1.0)     # ink above this -> solid
p.add_argument('--ordered', action='store_true')       # regular halftone instead of noise
p.add_argument('--cell-aspect', type=float, default=1.10)  # braille subcell h/w in the terminal
p.add_argument('--fade-bottom', type=float, default=0.0)   # dissolve the last N% of rows into embers
p.add_argument('--despeckle', action='store_true')         # drop cells with no inked neighbour
p.add_argument('--edges', action='store_true')
p.add_argument('--no-dither', action='store_true')
p.add_argument('--no-invert', action='store_true')
a = p.parse_args()

img = Image.open(a.image).convert('L')
if a.edges:
    img = img.filter(ImageFilter.FIND_EDGES).filter(ImageFilter.MaxFilter(3))
elif not a.no_invert:
    img = ImageOps.invert(img)                          # dark subject -> bright ink
img = ImageOps.autocontrast(img, cutoff=1)
if a.contrast != 1.0:
    img = ImageEnhance.Contrast(img).enhance(a.contrast)

# fit inside the cell budget while preserving aspect (a braille subcell is ~10% taller than wide)
box_w, box_h = a.cols * 2, a.rows * 4
sw, sh = img.size
scale = min(box_w / sw, box_h / (sh / a.cell_aspect))
W, H = max(2, int(round(sw * scale))), max(4, int(round(sh * scale / a.cell_aspect)))
img = img.resize((W, H), Image.LANCZOS)
a.cols, a.rows = -(-W // 2), -(-H // 4)
canvas = Image.new('L', (a.cols * 2, a.rows * 4), 0)
canvas.paste(img, (0, 0))
img = canvas

lut = []
for v in range(256):
    x = (v / 255.0 - a.black) / max(1e-6, a.white - a.black)
    x = min(1.0, max(0.0, x)) ** (1.0 / a.gamma)
    lut.append(int(round(255 * x)))
img = img.point(lut)

if a.fade_bottom > 0:
    # ramp the tail off so it disperses into embers instead of ending on the source's hard edge
    px_ = img.load()
    W_, H_ = img.size
    start = int(H_ * (1 - a.fade_bottom))
    for y in range(start, H_):
        k = 1.0 - 0.92 * ((y - start) / max(1, H_ - 1 - start)) ** 0.8
        for x in range(W_):
            px_[x, y] = int(px_[x, y] * k)

if a.ordered:
    BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]
    src, bw = img.load(), Image.new('1', img.size)
    dst = bw.load()
    for y in range(img.size[1]):
        for x in range(img.size[0]):
            dst[x, y] = 255 if src[x, y] / 255.0 > (BAYER[y % 4][x % 4] + 0.5) / 16.0 else 0
else:
    bw = img.convert('1', dither=Image.NONE if a.no_dither else Image.FLOYDSTEINBERG)
px = bw.load()

lines = []
for cy in range(a.rows):
    line = []
    for cx in range(a.cols):
        code = 0
        for dy in range(4):
            for dx in range(2):
                if px[cx * 2 + dx, cy * 4 + dy]:
                    code |= DOTS[dy][dx]
        line.append(' ' if code == 0 else chr(0x2800 + code))
    lines.append(line)

if a.despeckle:
    grid = [[c != ' ' for c in row] for row in lines]
    for y, row in enumerate(lines):
        for x, ch in enumerate(row):
            if ch == ' ':
                continue
            near = any(grid[j][i]
                       for j in range(max(0, y - 1), min(a.rows, y + 2))
                       for i in range(max(0, x - 1), min(a.cols, x + 2))
                       if (i, j) != (x, y))
            if not near:
                row[x] = ' '

print('\n'.join(''.join(r).rstrip() for r in lines).strip('\n'))
