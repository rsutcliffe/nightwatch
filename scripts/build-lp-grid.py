#!/usr/bin/env python3
"""Crop and downsample a VIIRS Nighttime Lights GeoTIFF into Nightwatch's .lpgrid format.

Usage:
  python3 -m venv .venv && .venv/bin/pip install -r scripts/requirements-data.txt
  .venv/bin/python scripts/build-lp-grid.py VNL_*_average_masked*.tif --bbox 49.8,-8.7,60.9,1.8 --cell 0.01 --out Sources/SkyCore/Resources/lightpollution/gb.lpgrid

The VIIRS annual composite (NOAA/NASA Earth Observation Group, CC BY 4.0) is downloaded once with a free EOG
account from https://eogdata.mines.edu/products/vnl/ . Output: 20-byte header (LPG1, south, west, cell, rows, cols),
then rows x cols float32 little-endian, row 0 southernmost, NaN = no data. The "average_masked" product stores masked
and unlit cells as 0 (no NaN), which reads as very dark; the 2025 file is 33601 x 86401 float32, uncompressed, 15 arc-second cells.
"""
import argparse, struct, sys
import numpy as np, tifffile

MAX_WINDOW_BYTES = 2 * 1024 ** 3  # 2 GiB; the crop happens before downsampling, so this guards the raw window.

def check_limits(window_rows, window_cols, rows, cols):
    window_bytes = window_rows * window_cols * 4
    if window_bytes > MAX_WINDOW_BYTES:
        sys.exit(f'crop window {window_rows} x {window_cols} pixels ({window_bytes / 1024**3:.2f} GiB) exceeds the '
                  '2 GiB limit; use a smaller bbox or a larger --cell')
    if rows > 65535 or cols > 65535:
        sys.exit(f'grid {rows} x {cols} exceeds the 65535-cell limit of the lpgrid header; use a larger --cell or a smaller bbox')

def geo(tif):
    p = tif.pages[0]
    scale = p.tags['ModelPixelScaleTag'].value
    tie = p.tags['ModelTiepointTag'].value
    sx, sy = float(scale[0]), float(scale[1])
    # The tie point maps raster point (I, J) to (X, Y). EOG's VIIRS files use (0.5, 0.5) -> (-180, 75), the centre of
    # pixel (0, 0); other writers use (0, 0) for the corner. Shift to the top-left corner of pixel (0, 0) either way.
    lon0 = float(tie[3]) - float(tie[0]) * sx
    lat0 = float(tie[4]) + float(tie[1]) * sy
    return lon0, lat0, sx, sy

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('tif'); ap.add_argument('--bbox', required=True, help='south,west,north,east in degrees')
    ap.add_argument('--cell', type=float, required=True, help='output cell size in degrees')
    ap.add_argument('--out', required=True)
    a = ap.parse_args()
    south, west, north, east = (float(x) for x in a.bbox.split(','))
    with tifffile.TiffFile(a.tif) as tif:
        lon0, lat0, sx, sy = geo(tif)
        page = tif.pages[0]
        h, w = page.shape[:2]
        r0 = max(0, int((lat0 - north) / sy)); r1 = min(h, int(np.ceil((lat0 - south) / sy)))
        c0 = max(0, int((west - lon0) / sx)); c1 = min(w, int(np.ceil((east - lon0) / sx)))
        if r0 >= r1 or c0 >= c1: sys.exit('bbox does not intersect the raster')
    f = max(1, int(round(a.cell / sx)))
    window_rows, window_cols = r1 - r0, c1 - c0
    rows, cols = window_rows // f, window_cols // f
    check_limits(window_rows, window_cols, rows, cols)
    # The global file is 11.6 GB uncompressed; read only the window through a memory map (verified memmappable 2026-09-23).
    m = tifffile.memmap(a.tif)
    arr = np.array(m[r0:r1, c0:c1], dtype=np.float32)               # north-up window
    arr = arr[:rows * f, :cols * f].reshape(rows, f, cols, f)
    with np.errstate(invalid='ignore'):
        out = np.nanmean(arr, axis=(1, 3)).astype(np.float32)        # mean of valid cells, NaN where none
    out = out[::-1, :]                                              # row 0 becomes the southern row
    cell = sx * f
    grid_south = lat0 - sy * (r0 + rows * f)
    grid_west = lon0 + sx * c0
    with open(a.out, 'wb') as fh:
        fh.write(b'LPG1'); fh.write(struct.pack('<fff', grid_south, grid_west, cell)); fh.write(struct.pack('<HH', rows, cols))
        fh.write(out.astype('<f4').tobytes())
    print(f'wrote {a.out}: {rows} x {cols} cells of {cell:.4f} deg, south {grid_south:.4f} west {grid_west:.4f}')

if __name__ == '__main__':
    main()
