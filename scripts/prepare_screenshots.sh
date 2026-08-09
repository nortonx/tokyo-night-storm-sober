#!/usr/bin/env bash
# Normalise raw window captures into Web Store compliant screenshots.
#
# The store requires exactly 1280x800 (or 640x400), 16:10, square corners, no
# padding, full bleed. Two things routinely break that:
#
#   1. Compositor window captures include the rounded corners and drop shadow as
#      transparency, which is padding and non-square corners.
#   2. On a scaled display a 1280x800 window is captured at 1920x1200 or larger.
#
# This trims the transparent border, flattens away any remaining alpha, then
# fits to exactly 1280x800. Downscaling from a larger capture is preferred: it
# supersamples, so text stays crisp.
#
# Usage: scripts/prepare_screenshots.sh <raw-image>...
# Writes store/screenshots/NN-<name>.png

set -euo pipefail
cd "$(dirname "$0")/.."

OUT=store/screenshots
mkdir -p "$OUT"

if [ $# -eq 0 ]; then
  echo "usage: $0 <raw-image>..." >&2
  exit 1
fi

command -v magick >/dev/null || { echo "ImageMagick (magick) not found" >&2; exit 1; }

i=0
for src in "$@"; do
  [ -f "$src" ] || { echo "no such file: $src" >&2; exit 1; }
  i=$((i + 1))
  base=$(basename "${src%.*}" | tr '[:upper:] ' '[:lower:]-')
  dst=$(printf '%s/%02d-%s.png' "$OUT" "$i" "$base")

  before=$(magick identify -format '%wx%h' "$src")

  magick "$src" \
    -bordercolor none -trim +repage \
    -background '#181b28' -alpha remove -alpha off \
    -resize 1280x800^ -gravity center -extent 1280x800 \
    -type TrueColor -strip "$dst"

  after=$(magick identify -format '%wx%h %[channels]' "$dst")
  printf '  %-28s %-12s -> %s  %s\n' "$(basename "$src")" "$before" "$after" "$dst"
done

echo
count=$(find "$OUT" -name '*.png' | wc -l)
if [ "$count" -gt 5 ]; then
  echo "  $count screenshots; the store accepts at most 5" >&2
  exit 1
fi
echo "  $count screenshot(s) ready, 1280x800, no alpha"
