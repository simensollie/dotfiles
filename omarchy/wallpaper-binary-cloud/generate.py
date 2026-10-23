#!/usr/bin/env python3
"""Redraw the binary-cloud wallpaper as crisp vector art at any resolution.

The original is a 2560x1080 JPEG; this rebuilds it from its geometry so it
stays sharp on a 3440x1440 ultrawide (or anything else).
Usage: generate.py [width] [height] > out.svg
"""
import sys

W = int(sys.argv[1]) if len(sys.argv) > 1 else 3440
H = int(sys.argv[2]) if len(sys.argv) > 2 else 1440

BG, FRONT, BACK, DIGIT = "#374A72", "#D2E1FF", "#9BB2DC", "#8CC6EE"

# Geometry is measured on a 1600x675 preview of the original; scale it so the
# art keeps the same share of the screen height, centred horizontally.
s = H / 675
cx0 = 800  # horizontal centre of the art in preview coordinates
X = lambda x: W / 2 + (x - cx0) * s
Y = lambda y: y * s
R = lambda r: r * s

def circle(x, y, r, fill):
    return f'<circle cx="{X(x):.1f}" cy="{Y(y):.1f}" r="{R(r):.1f}" fill="{fill}"/>'

def pill(x1, x2, y1, y2, fill):
    h = y2 - y1
    return (f'<rect x="{X(x1):.1f}" y="{Y(y1):.1f}" width="{R(x2 - x1):.1f}" '
            f'height="{R(h):.1f}" rx="{R(h / 2):.1f}" fill="{fill}"/>')

def block(x1, x2, y1, y2, fill):
    # Fills the dips between bumps so they merge into one silhouette.
    return (f'<rect x="{X(x1):.1f}" y="{Y(y1):.1f}" width="{R(x2 - x1):.1f}" '
            f'height="{R(y2 - y1):.1f}" fill="{fill}"/>')

parts = []
# Back cloud peeks out to the right of the front one.
parts += [circle(862, 115, 42, BACK), circle(912, 145, 22, BACK),
          pill(850, 961, 150, 180, BACK), block(862, 900, 130, 165, BACK)]
# Front cloud.
parts += [circle(722, 133, 40, FRONT), circle(805, 118, 60, FRONT),
          circle(875, 150, 26, FRONT), block(722, 875, 133, 180, FRONT),
          pill(645, 940, 160, 197, FRONT)]

# Binary rain: 5 columns alternating 0/1, rows until off-screen.
cols = [713, 755.5, 798, 840.5, 883]
row0, pitch = 228, 35.3
dw, dh = 13, 23  # digit box in preview units
sw = R(1.35)
rows = int((675 - row0) / pitch) + 2
for r in range(rows):
    yc = row0 + r * pitch
    for c, xc in enumerate(cols):
        one = (r + c) % 2 == 1
        if one:
            x = X(xc + 1)
            parts.append(
                f'<path d="M{x - R(4):.1f},{Y(yc - dh / 2 + 3):.1f} L{x:.1f},{Y(yc - dh / 2):.1f} '
                f'L{x:.1f},{Y(yc + dh / 2):.1f}" fill="none" stroke="{DIGIT}" '
                f'stroke-width="{sw:.2f}" stroke-linecap="round" stroke-linejoin="round"/>')
        else:
            parts.append(
                f'<rect x="{X(xc - dw / 2):.1f}" y="{Y(yc - dh / 2):.1f}" width="{R(dw):.1f}" '
                f'height="{R(dh):.1f}" rx="{R(dw / 2):.1f}" fill="none" stroke="{DIGIT}" '
                f'stroke-width="{sw:.2f}"/>')

print(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
print(f'<rect width="100%" height="100%" fill="{BG}"/>')
print("\n".join(parts))
print("</svg>")
