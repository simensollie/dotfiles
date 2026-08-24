#!/bin/bash
# Rebuild the Solfuglen screensaver art from the source logo.
# Usage: ./generate.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

COLS=120 ROWS=26          # ROWS is the real budget: the 1080p monitor gives ~34 rows total
GAMMA=0.60                # lower = sparser ink
BLACK=0.32                # background cutoff; raise to kill more of the sunburst
FADE=0.20                 # fraction of the tail that dissolves into embers

magick solfuglen-source.png -crop 1254x1075+0+40 +repage build-crop.png
python3 braille.py build-crop.png --cols $COLS --rows $ROWS \
  --gamma $GAMMA --black $BLACK --fade-bottom $FADE --despeckle > build-bird.txt

magick -background white -fill black -font /usr/share/fonts/noto/NotoSans-Black.ttf \
  -pointsize 260 -kerning 34 label:"SOLFUGLEN" -bordercolor white -border 16 build-word-src.png
python3 braille.py build-word-src.png --cols 74 --rows 6 --no-dither --black 0.35 > build-word.txt

python3 - <<'PY'
bird = [l for l in open('build-bird.txt').read().split('\n') if l.strip()]
word = [l for l in open('build-word.txt').read().split('\n') if l.strip()]
width = max(max(len(l) for l in bird), max(len(l) for l in word))
def centre(rows):
    pad = (width - max(len(l) for l in rows)) // 2
    return [(' ' * pad + l).rstrip() for l in rows]
open('screensaver.txt', 'w').write('\n'.join(centre(bird) + [''] + centre(word)) + '\n')
print(f'{width} cols x {len(centre(bird)) + 1 + len(centre(word))} rows')
PY

python3 preview.py screensaver.txt preview.png
echo "preview -> $PWD/preview.png"

if [[ ${1:-} == --install ]]; then
  dest=~/.config/omarchy/branding/screensaver.txt
  cp "$dest" "$dest.bak.$(date +%Y%m%d-%H%M%S)"
  cp screensaver.txt "$dest"
  echo "installed -> $dest"
fi
