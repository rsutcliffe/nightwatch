import os, struct, subprocess, sys, tempfile, unittest
import numpy as np, tifffile

HERE = os.path.dirname(os.path.abspath(__file__))

def make_tiff(path):
    # 20 rows x 30 cols, 0.5 degree cells, north-up, top-left corner at lat 60, lon -10 (GeoTIFF tie point)
    a = np.zeros((20, 30), dtype=np.float32)
    a[0, 0] = 40.0          # NW corner cell, lat 59.75 lon -9.75
    a[19, 29] = 0.1         # SE corner cell, lat 50.25 lon 4.75
    a[10, 10] = np.nan
    tags = [(33550, 'd', 3, (0.5, 0.5, 0.0), True),                       # ModelPixelScaleTag
            (33922, 'd', 6, (0.0, 0.0, 0.0, -10.0, 60.0, 0.0), True)]       # ModelTiepointTag
    tifffile.imwrite(path, a, extratags=tags)

class BuildLPGrid(unittest.TestCase):
    def test_crops_and_flips(self):
        with tempfile.TemporaryDirectory() as d:
            tif = os.path.join(d, 'viirs.tif'); out = os.path.join(d, 'x.lpgrid')
            make_tiff(tif)
            subprocess.check_call([sys.executable, os.path.join(HERE, 'build-lp-grid.py'), tif, '--bbox', '50,-10,60,5', '--cell', '0.5', '--out', out])
            b = open(out, 'rb').read()
            self.assertEqual(b[:4], b'LPG1')
            south, west, cell = struct.unpack('<fff', b[4:16]); rows, cols = struct.unpack('<HH', b[16:20])
            self.assertAlmostEqual(south, 50.0, 5); self.assertAlmostEqual(west, -10.0, 5); self.assertAlmostEqual(cell, 0.5, 5)
            self.assertEqual((rows, cols), (20, 30))
            vals = np.frombuffer(b[20:], dtype='<f4').reshape(rows, cols)
            self.assertEqual(vals[rows - 1, 0], 40.0)        # NW cell ends up in the top (northern) row of a south-first array
            self.assertAlmostEqual(float(vals[0, cols - 1]), 0.1, 5)   # SE cell in row 0
            self.assertTrue(np.isnan(vals[9, 10]))            # nan preserved, flipped row index 19-10

    def test_downsamples_by_mean_of_valid(self):
        with tempfile.TemporaryDirectory() as d:
            tif = os.path.join(d, 'viirs.tif'); out = os.path.join(d, 'x.lpgrid')
            make_tiff(tif)
            subprocess.check_call([sys.executable, os.path.join(HERE, 'build-lp-grid.py'), tif, '--bbox', '50,-10,60,5', '--cell', '1.0', '--out', out])
            b = open(out, 'rb').read(); rows, cols = struct.unpack('<HH', b[16:20])
            self.assertEqual((rows, cols), (10, 15))
            vals = np.frombuffer(b[20:], dtype='<f4').reshape(rows, cols)
            self.assertAlmostEqual(float(vals[rows - 1, 0]), 10.0, 5)   # 40 + 0 + 0 + 0 over 4 cells

if __name__ == '__main__':
    unittest.main()
