#!/usr/bin/env python3
"""Render braille/box text exactly as the screensaver terminal would: white on black,
JetBrains Mono at the screensaver's cell metrics."""
import sys
from PIL import Image, ImageDraw, ImageFont

text, out = sys.argv[1], sys.argv[2]
label = sys.argv[3] if len(sys.argv) > 3 else ''
lines = open(text).read().split('\n')
SIZE = 24
font = ImageFont.truetype('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf', SIZE)
CW = font.getlength('M')
CH = int(SIZE * 1.32)
cols = max(len(l) for l in lines)
img = Image.new('RGB', (int(CW * cols) + 20, CH * len(lines) + 40), '#000')
d = ImageDraw.Draw(img)
for i, l in enumerate(lines):
    d.text((10, 20 + i * CH), l, font=font, fill='#ffb055')
if label:
    d.text((10, 2), label, font=ImageFont.truetype(
        '/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Bold.ttf', 16), fill='#4488ff')
img.save(out)
