"""Extract the phoenix as an RGBA cutout.

Green is the clean discriminator (bird <=0.40, sunburst >=0.69); luminance
overlaps badly on the bright head. Close -> fill holes -> keep the largest blob,
which drops the detached sunburst rays.
"""
import numpy as np
from PIL import Image, ImageFilter
from scipy import ndimage

import os
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'screensaver', 'solfuglen-source.png')
rgb = Image.open(SRC).convert('RGB')
a = np.asarray(rgb).astype(np.float32) / 255.0

m = Image.fromarray(((a[..., 1] < 0.50) * 255).astype(np.uint8), 'L')
m = m.filter(ImageFilter.MaxFilter(9)).filter(ImageFilter.MinFilter(9))
b = np.asarray(m) > 127

b = ndimage.binary_fill_holes(b)
lab, n = ndimage.label(b)
sizes = ndimage.sum(b, lab, range(1, n + 1))
biggest = (lab == (int(np.argmax(sizes)) + 1))
print(f'{n} blobs; kept {100*biggest.mean():.1f}% of frame, dropped {100*(b & ~biggest).mean():.2f}% stray rays')

alpha = np.asarray(
    Image.fromarray((biggest * 255).astype(np.uint8), 'L').filter(ImageFilter.GaussianBlur(1.2))
).astype(np.float32)

ys, xs = np.where(biggest)
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
alpha = alpha[y0:y1, x0:x1]

# The source frame guillotines the wing tips and the tail. Ramp the alpha off at
# those edges so they dissolve into the scene instead of ending on a straight cut.
h, w = alpha.shape
def ramp_edge(n, reverse=False):
    t = np.linspace(0, 1, n, dtype=np.float32) ** 0.7
    return t[::-1] if reverse else t
top = int(h * 0.13)
alpha[:top] *= ramp_edge(top)[:, None]
bot = int(h * 0.10)
alpha[h - bot:] *= ramp_edge(bot, reverse=True)[:, None]

out = np.dstack([np.asarray(rgb)[y0:y1, x0:x1], alpha.astype(np.uint8)])
Image.fromarray(out, 'RGBA').save('phoenix.png')
print('phoenix.png', out.shape[1], 'x', out.shape[0])
