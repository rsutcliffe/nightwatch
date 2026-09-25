#!/bin/zsh
# Imports the constellation artwork into Resources/Constellations as <IAU code>-figure.heic and <IAU code>-plot.heic:
# 512 px (enough for the 260 pt detail view on a Retina screen), HEIC at quality 80 with transparency.
# usage: scripts/import-constellations.sh <folder holding manifest.json, figure/ and plot/>
# The manifest lists {code, figure, plot} for all 88 constellations. Re-run it after regenerating any artwork.
set -euo pipefail
cd "$(dirname "$0")/.."
SRC="${1:?usage: scripts/import-constellations.sh <artwork folder with manifest.json>}"
OUT=Resources/Constellations
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir -p "$OUT"
# Tab-separated, so a file name with a space in it stays whole.
python3 -c 'import json,sys; [print(c["code"], c["figure"], c["plot"], sep="\t") for c in json.load(open(sys.argv[1]))]' "$SRC/manifest.json" |
while IFS=$'\t' read -r code figure plot; do
  for layer in figure plot; do
    file=${(P)layer}
    sips -Z 512 "$SRC/$file" --out "$TMP/$code-$layer.png" >/dev/null
    sips -s format heic -s formatOptions 80 "$TMP/$code-$layer.png" --out "$OUT/$code-$layer.heic" >/dev/null
  done
done
echo "Imported $(ls "$OUT"/*-figure.heic | wc -l | tr -d ' ') constellations into $OUT ($(du -sh "$OUT" | cut -f1))"
