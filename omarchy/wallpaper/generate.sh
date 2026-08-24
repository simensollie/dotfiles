#!/bin/bash
# Rebuild the Solfuglen synthwave wallpaper.
# Usage: ./generate.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

OUT=solfuglen-synthwave.jpg
DEST=~/.config/omarchy/backgrounds/tokyo-night/$OUT

python3 hero.py                      # phoenix.png: RGBA cutout of the logo
python3 scene.py 1600 900 preview.png
python3 scene.py 3840 2160 master.png
magick master.png -quality 94 -sampling-factor 4:4:4 "$OUT"
rm -f master.png
echo "wrote $PWD/$OUT (preview: preview.png)"

if [[ ${1:-} == --install ]]; then
  mkdir -p "$(dirname "$DEST")"
  cp "$OUT" "$DEST"
  omarchy theme bg set "$DEST"
  echo "installed and activated: $DEST"
fi
