#!/usr/bin/env python3
"""Crop and downsample a VIIRS Nighttime Lights GeoTIFF into Nightwatch's .lpgrid format.

Usage:
  python3 -m venv .venv && .venv/bin/pip install -r scripts/requirements-data.txt
  curl -fsSLO https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_land.geojson
  .venv/bin/python scripts/build-lp-grid.py VNL_*_average_masked*.tif --bbox 49.8,-8.7,60.9,1.8 --cell 0.01 \
      --smooth 7 --land ne_10m_land.geojson --out Sources/SkyCore/Resources/lightpollution/gb.lpgrid

The VIIRS annual composite (NOAA/NASA Earth Observation Group, CC BY 4.0) is downloaded once with a free EOG
account from https://eogdata.mines.edu/products/vnl/ . Output: 20-byte header (LPG1, south, west, cell, rows, cols),
then rows x cols float32 little-endian, row 0 southernmost, NaN = no data. The "average_masked" product stores masked
and unlit cells as 0 (no NaN), which reads as very dark; the 2025 file is 33601 x 86401 float32, uncompressed, 15 arc-second cells.

Most of Britain is exactly 0 in that product, sea included, so two passes follow the downsampling:
  --land PATH  GeoJSON land polygons (Natural Earth 10 m land, public domain); cells whose centre is not on land become
               NaN, so the sea is never offered as a dark spot.
  --smooth N   NaN-aware box mean over N x N output cells (default 7, 1 disables); a cell's value reflects the glow of its
               surroundings, so a masked zero beside a town no longer reads as darkest. NaN cells stay NaN.
"""
import argparse, struct, sys
import json
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

def smooth(a, n):
    """Box mean over n x n cells, ignoring NaN; cells that were NaN stay NaN."""
    if n <= 1: return a
    lo, hi = n // 2, n - 1 - n // 2
    valid = ~np.isnan(a)
    def box(x):
        c = np.pad(np.pad(x, ((lo, hi), (lo, hi))).cumsum(0).cumsum(1), ((1, 0), (1, 0)))
        return c[n:, n:] - c[:-n, n:] - c[n:, :-n] + c[:-n, :-n]
    total, count = box(np.where(valid, a, 0).astype(np.float64)), box(valid.astype(np.float64))
    with np.errstate(invalid='ignore', divide='ignore'):
        out = (total / count).astype(np.float32)
    out[~valid] = np.nan
    return out

def land_mask(path, south, west, cell, rows, cols):
    """True where the cell centre lies on a land polygon; row 0 south, as in the output."""
    import shapely
    geoms = np.array([shapely.geometry.shape(f['geometry']) for f in json.load(open(path))['features']])
    north, east = south + rows * cell, west + cols * cell
    land = shapely.union_all(shapely.clip_by_rect(geoms, west - cell, south - cell, east + cell, north + cell))
    shapely.prepare(land)
    lat = south + (np.arange(rows) + 0.5) * cell
    lon = west + (np.arange(cols) + 0.5) * cell
    x, y = np.meshgrid(lon, lat)
    return shapely.contains_xy(land, x, y)

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('tif'); ap.add_argument('--bbox', required=True, help='south,west,north,east in degrees')
    ap.add_argument('--cell', type=float, required=True, help='output cell size in degrees')
    ap.add_argument('--out', required=True)
    ap.add_argument('--smooth', type=int, default=7, help='box mean over N x N output cells after downsampling; 1 disables')
    ap.add_argument('--land', help='GeoJSON land polygons; cells whose centre is not on land are written as NaN')
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
    if a.land: out[~land_mask(a.land, grid_south, grid_west, cell, rows, cols)] = np.nan
    out = smooth(out, a.smooth)
    with open(a.out, 'wb') as fh:
        fh.write(b'LPG1'); fh.write(struct.pack('<fff', grid_south, grid_west, cell)); fh.write(struct.pack('<HH', rows, cols))
        fh.write(out.astype('<f4').tobytes())
    print(f'wrote {a.out}: {rows} x {cols} cells of {cell:.4f} deg, south {grid_south:.4f} west {grid_west:.4f}, '
          f'smooth {a.smooth}, {int(np.isnan(out).sum())} NaN cells')

if __name__ == '__main__':
    main()
