#!/usr/bin/env python3
"""Solfuglen synthwave wallpaper, in the style of Omarchy's 1-quattro.jpg:
gradient sunset sky, banded retro sun, layered ridges, mirrored lake, scanlines.

Usage: scene.py [WIDTH HEIGHT [OUT]]
"""
import sys
import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = (int(sys.argv[1]), int(sys.argv[2])) if len(sys.argv) > 2 else (1600, 900)
OUT = sys.argv[3] if len(sys.argv) > 3 else 'scene.png'
K = W / 3840.0                       # scale relative to the 4K master
rng = np.random.default_rng(20260825)

HORIZON = 0.660
SUN_CX, SUN_CY, SUN_R = 0.50, 0.400, 0.250
FONT = '/usr/share/fonts/noto/NotoSans-Black.ttf'

def ramp(stops, n):
    pos = np.array([p for p, _ in stops], np.float32)
    col = np.array([c for _, c in stops], np.float32)
    t = np.linspace(0, 1, n, dtype=np.float32)
    return np.stack([np.interp(t, pos, col[:, i]) for i in range(3)], 1)

def ridge(base, amp, seed, rough=0.55):
    """1D midpoint displacement -> jagged mountain profile."""
    g = np.random.default_rng(seed)
    pts, n, a = np.array([base + g.uniform(-amp, amp)] * 2), 1, amp
    while n < 512:
        mid = (pts[:-1] + pts[1:]) / 2 + g.uniform(-a, a, len(pts) - 1)
        out = np.empty(len(pts) + len(mid))
        out[0::2], out[1::2] = pts, mid
        pts, n, a = out, n * 2, a * rough
    return np.interp(np.linspace(0, len(pts) - 1, W), np.arange(len(pts)), pts)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
hy = HORIZON * H
cx, cy, r = SUN_CX * W, SUN_CY * H, SUN_R * W

# ------------------------------------------------------------ sky and water
img = np.repeat(ramp([
    (0.00, (18, 5, 38)), (0.18, (64, 15, 78)), (0.36, (140, 28, 104)),
    (0.52, (216, 48, 110)), (0.61, (252, 96, 104)), (0.6599, (255, 172, 92)),
    (0.66, (198, 74, 100)), (0.73, (96, 24, 70)), (1.00, (20, 5, 34)),
], H)[:, None, :], W, axis=1)

# ------------------------------------------------------------------ clouds
# drawn before the sun so the disc stays clean; magenta over gold reads muddy
def cloud_layer():
    layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(layer)
    pal = ramp([(0, (196, 74, 150)), (0.55, (255, 118, 116)), (1, (255, 200, 130))], 100)
    for _ in range(90):
        t = rng.random() ** 1.5
        cyy, cxx = t * hy * 0.94, rng.uniform(-0.1, 1.1) * W
        ln, th = rng.uniform(0.04, 0.24) * W, rng.uniform(0.003, 0.010) * H
        c = tuple(int(v) for v in pal[int(min(cyy / hy, 0.999) * 99)])
        dr.ellipse([cxx - ln, cyy - th, cxx + ln, cyy + th], fill=c + (int(rng.uniform(70, 150)),))
    return layer.filter(ImageFilter.GaussianBlur(max(1.5, 7 * K * 4)))

sky_img = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), 'RGB').convert('RGBA')
img = np.asarray(Image.alpha_composite(sky_img, cloud_layer()).convert('RGB')).astype(np.float32)

# ---------------------------------------------------------------- retro sun
d = np.hypot(xx - cx, yy - cy)
aa = max(1.2, 2.0 * K * 4)
disc_a = np.clip((r - d) / aa, 0, 1) * (yy < hy)      # soft rim
disc = disc_a > 0
sun_col = ramp([(0.0, (255, 216, 88)), (0.34, (255, 158, 58)),
                (0.70, (255, 92, 96)), (1.0, (238, 48, 132))], int(2 * r) + 2)
sun_rgb = sun_col[np.clip((yy - (cy - r)).astype(np.int32), 0, len(sun_col) - 1)]

band = np.zeros((H, W), bool)          # horizontal slices, thickening downward
y, gap, solid = cy - 0.02 * r, 0.012 * r, 0.085 * r
while y < cy + r:
    band |= (yy >= y) & (yy < y + gap)
    y += gap + solid
    gap *= 1.44
    solid *= 0.90
lit = disc & ~band
w_ = disc_a[lit][..., None]
img[lit] = img[lit] * (1 - w_) + sun_rgb[lit] * w_
gapc = np.array([120, 24, 78], np.float32)
w_ = disc_a[disc & band][..., None] * 0.70
img[disc & band] = img[disc & band] * (1 - w_) + gapc * w_

glow = np.exp(-((d / (r * 1.35)) ** 2)) * 0.42
img += glow[..., None] * np.array([255, 128, 96], np.float32)

# ------------------------------------------------------------------ ridges
for prof, col, op in [
    (ridge(hy - 0.150 * H, 0.085 * H, 11), (128, 42, 116), 0.62),
    (ridge(hy - 0.086 * H, 0.060 * H, 27), (74, 21, 80), 0.86),
    (ridge(hy - 0.030 * H, 0.034 * H, 43), (34, 10, 46), 1.00),
]:
    m = (yy >= prof[None, :]) & (yy < hy)
    img[m] = img[m] * (1 - op) + np.array(col, np.float32) * op

# ------------------------------------------------------------------- water
water = yy >= hy
depth = np.clip((yy - hy) / (H - hy), 0, 1)
col = np.exp(-(((xx - cx) / (r * 0.55)) ** 2))                  # reflection column
ripple = np.sin(yy * (0.42 / max(K * 4, 0.3)) + np.sin(xx * 0.006) * 3.2 + depth * 6)
stripe = np.clip((ripple - 0.34) * 1.25, 0, 1)
refl = col * stripe * np.exp(-depth * 3.4) * 0.92
glint = (rng.random((H, W)) > 0.9993) * np.exp(-depth * 2.2)
glint = np.asarray(Image.fromarray((glint * 255).astype(np.uint8)).filter(
    ImageFilter.GaussianBlur(max(1.0, 2 * K * 4)))) / 255.0
add = (refl + glint * 0.9)[..., None] * np.array([255, 168, 104], np.float32)
img[water] += add[water]

shore = ridge(H * 0.945, 0.026 * H, 91, rough=0.62)
img[yy >= shore[None, :]] = np.array([14, 4, 26], np.float32)
img = np.clip(img, 0, 255)

base = Image.fromarray(img.astype(np.uint8), 'RGB').convert('RGBA')

# ----------------------------------------------------------------- phoenix
bird = Image.open('phoenix.png').convert('RGBA')
bh = int(0.560 * H)
bird = bird.resize((max(1, int(bird.width * bh / bird.height)), bh), Image.LANCZOS)
bx, by = int(cx - bird.width / 2), int(0.185 * H)

halo = Image.new('RGBA', (W, H), (0, 0, 0, 0))
halo.paste(Image.new('RGBA', bird.size, (255, 96, 56, 190)), (bx, by), bird)
base = Image.alpha_composite(base, halo.filter(ImageFilter.GaussianBlur(max(6, 38 * K * 4))))
base.paste(bird, (bx, by), bird)

# ------------------------------------------------------- bird reflection
water_top = int(hy)
rf = bird.transpose(Image.FLIP_TOP_BOTTOM)
rf = rf.resize((rf.width, max(1, int(rf.height * 0.42))), Image.LANCZOS)
ra = np.asarray(rf).astype(np.float32)
for i in range(ra.shape[0]):                      # per-row horizontal wobble
    sh = int(round(np.sin(i * 0.16 + 0.7) * (3.2 + i * 0.05) * max(K * 4, 0.4)))
    ra[i] = np.roll(ra[i], sh, axis=0)
ra[..., 3] *= np.linspace(0.42, 0.0, ra.shape[0], dtype=np.float32)[:, None] ** 1.25
rf = Image.fromarray(np.clip(ra, 0, 255).astype(np.uint8), 'RGBA').filter(
    ImageFilter.GaussianBlur(max(1.0, 2.4 * K * 4)))
refl_layer = Image.new('RGBA', (W, H), (0, 0, 0, 0))
refl_layer.paste(rf, (bx, water_top), rf)
base = Image.alpha_composite(base, refl_layer)

# --------------------------------------------------------------- embers
spark = Image.new('RGBA', (W, H), (0, 0, 0, 0))
ds = ImageDraw.Draw(spark)
for _ in range(300):
    sx = cx + rng.normal(0, 0.085 * W)
    sy = by + bird.height * (0.72 + abs(rng.normal(0, 0.22)))
    if not (0 < sx < W and 0 < sy < H):
        continue
    rr = rng.uniform(0.9, 3.0) * max(K * 4, 0.55)
    ds.ellipse([sx - rr, sy - rr, sx + rr, sy + rr],
               fill=(255, int(rng.uniform(130, 225)), 96, int(rng.uniform(110, 235))))
base = Image.alpha_composite(base, spark.filter(ImageFilter.GaussianBlur(max(0.7, 1.4 * K * 4))))

# --------------------------------------------------------------- banner
bn = Image.new('RGBA', (W, H), (0, 0, 0, 0))
db = ImageDraw.Draw(bn)
bw, bh2 = int(0.255 * W), int(0.105 * H)
bx0, by0 = int(0.705 * W), int(0.760 * H)
post = max(2, int(0.0035 * W))
for px in (bx0 + int(bw * 0.045), bx0 + bw - int(bw * 0.045)):
    db.rectangle([px - post, by0 - int(bh2 * 0.10), px + post, by0 + int(bh2 * 1.55)],
                 fill=(24, 8, 36, 255))
db.rectangle([bx0, by0, bx0 + bw, by0 + bh2], fill=(22, 7, 34, 232))
db.rectangle([bx0, by0, bx0 + bw, by0 + bh2], outline=(255, 108, 150, 200),
             width=max(1, int(0.0012 * W)))
fs = int(bh2 * 0.40)
font = ImageFont.truetype(FONT, fs)
tw = db.textlength('SOLFUGLEN', font=font)
tx, ty = bx0 + (bw - tw) / 2, by0 + bh2 * 0.13
db.text((tx, ty), 'SOLFUGLEN', font=font, fill=(255, 150, 180, 255))
for i in range(4):                     # speed lines, as on the quattro banner
    ly = by0 + bh2 * (0.66 + i * 0.075)
    db.line([bx0 + bw * 0.10, ly, bx0 + bw * 0.90, ly],
            fill=(255, 108, 150, 190), width=max(1, int(0.0016 * W)))
base = Image.alpha_composite(base, bn)

# ---------------------------------------------------------------- finish
a = np.asarray(base.convert('RGB')).astype(np.float32)
a *= (1.0 - 0.05 * (np.sin(yy * np.pi / max(1.5, 2.0 * K * 4)) * 0.5 + 0.5))[..., None]
a *= np.clip(1.0 - 0.32 * ((((xx / W - .5) ** 2 + (yy / H - .5) ** 2) / .5) ** 1.3), 0, 1)[..., None]
g = a @ np.array([.299, .587, .114], np.float32)
a = np.clip(g[..., None] + (a - g[..., None]) * 1.14, 0, 255)     # saturation
a = np.clip((a / 255.0) ** 0.92 * 255.0 + rng.normal(0, 2.2, a.shape), 0, 255)
Image.fromarray(a.astype(np.uint8), 'RGB').save(OUT)
print('wrote', OUT, W, 'x', H)
