#!/bin/bash
# Rebuild the binary-cloud wallpaper at native ultrawide resolution.
# Usage: ./generate.sh [--install]
set -euo pipefail
cd "$(dirname "$0")"

OUT=binary-cloud-3440x1440.png
DEST=~/.config/omarchy/backgrounds/tokyo-night/$OUT

python3 generate.py 3440 1440 > binary-cloud.svg
rsvg-convert binary-cloud.svg -o "$OUT"
echo "wrote $PWD/$OUT"

if [[ ${1:-} == --install ]]; then
  mkdir -p "$(dirname "$DEST")"
  cp "$OUT" "$DEST"
  omarchy theme bg set "$DEST"
  echo "installed and activated: $DEST"
fi
