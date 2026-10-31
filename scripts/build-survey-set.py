#!/usr/bin/env python3
"""Builds the survey picture set: one 480x274 WebP per target the app can list, framed as the app frames a card for the default
2.1 x 1.2 degree field of view (or 1.5 x the object, when that is bigger), so the files are a drop-in for what hips2fits returns.

    python3 scripts/build-survey-set.py [--out build/survey-set] [--limit N] [--source auto|cds|skyview] [--delay 3]

Written 31 October 2026 after CDS's hips2fits went unreachable. Sources:
  cds      hips2fits colour DSS2 (what the app uses): one request per target.
  skyview  NASA SkyView DSS2 Red, greyscale, fetched at twice the size and shrunk here. One shared NASA service: strictly one request at a
           time, a pause between, and a longer wait when it answers "Too Many Processes" (a 200 with a web page). First run, 31 October 2026: 300 targets in well under a day. Measured 31 October 2026:
           about 75 s a target, so ~40 hours for the whole set; a Red + Blue merge was tried and rejected (each band is stretched on its own,
           so the colours came out blue or orange, and plate edges showed). Use it for a few hundred of the brightest targets at most.
  auto     cds, and skyview for the rest once cds fails.
Resumable: files already in --out are skipped. Brightest targets first, so a partial run holds the most useful ones.
Needs Pillow. Writes <out>/<id>.webp and <out>/manifest.json (sizes, totals).
"""
import argparse, csv, io, json, sys, time, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image, ImageOps

ROOT = Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Sources/SkyCore/Resources/catalog"
GROUPS = {"G": "galaxies", "GPair": "galaxies", "GTrpl": "galaxies", "GGroup": "galaxies",
          "OCl": "clusters", "GCl": "clusters", "Cl+N": "clusters", "*Ass": "clusters",
          "PN": "nebulae", "HII": "nebulae", "EmN": "nebulae", "Neb": "nebulae", "RfN": "nebulae", "SNR": "nebulae", "DrkN": "nebulae"}
SIZE_CORRECTIONS = {"NGC7000": 120.0}   # Catalog.sizeCorrections
FOV_W, FOV_H, WIDTH = 2.1, 1.2, 480     # the DWARF Mini's field, Nightwatch's default
HEIGHT = int(WIDTH * FOV_H / FOV_W)     # as Thumbnails.url
UA = "Nightwatch-survey-set/1 (https://github.com/rsutcliffe/nightwatch)"


def sexagesimal(s):
    sign = -1 if s.startswith("-") else 1
    p = [float(x) for x in s.lstrip("+-").split(":")]
    return sign * (p[0] + p[1] / 60 + p[2] / 3600)


def targets():
    """The objects the app lists (Planner: magnitude 12 or brighter; nebulae and cluster-plus-nebula without one are kept)."""
    out = []
    for name in ("NGC.csv", "addendum.csv"):
        for r in csv.DictReader(open(CATALOG / name, encoding="utf-8"), delimiter=";"):
            if r["Type"] not in GROUPS or not r["RA"] or not r["Dec"]:
                continue
            v = r["V-Mag"] or r["B-Mag"]
            mag = float(v) if v else None
            if mag is not None:
                if mag > 12: continue
            elif GROUPS[r["Type"]] != "nebulae" and r["Type"] != "Cl+N":
                continue
            size = SIZE_CORRECTIONS.get(r["Name"]) or (float(r["MajAx"]) if r["MajAx"] else None)
            fov = max(FOV_W, (size or 0) / 60 * 1.5, 0.05)
            out.append({"id": r["Name"], "ra": sexagesimal(r["RA"]) * 15, "dec": sexagesimal(r["Dec"]), "fov": fov, "mag": mag if mag is not None else 99})
    out.sort(key=lambda t: t["mag"])
    return out


def get(url, timeout=60):
    with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": UA}), timeout=timeout) as r:
        return r.read()


def is_jpeg(b): return b[:2] == b"\xff\xd8"


def from_cds(t):
    q = urllib.parse.urlencode({"hips": "CDS/P/DSS2/color", "ra": "%.5f" % t["ra"], "dec": "%.5f" % t["dec"], "fov": "%.3f" % t["fov"],
                                "width": WIDTH, "height": HEIGHT, "projection": "TAN", "format": "jpg"})
    data = get("https://alasky.cds.unistra.fr/hips-image-services/hips2fits?" + q, timeout=30)
    if not is_jpeg(data): raise ValueError("not a JPEG")
    return Image.open(io.BytesIO(data)).convert("RGB")


def skyview_band(t, survey, delay, tries=6):
    w, h = WIDTH * 2, HEIGHT * 2
    q = urllib.parse.urlencode({"Position": "%.5f,%.5f" % (t["ra"], t["dec"]), "Survey": survey, "Pixels": "%d,%d" % (w, h),
                                "Size": "%.4f,%.4f" % (t["fov"], t["fov"] * HEIGHT / WIDTH), "Projection": "Tan", "Return": "JPEG", "Scaling": "Sqrt"},
                               quote_via=urllib.parse.quote)
    for attempt in range(tries):
        try:
            data = get("https://skyview.gsfc.nasa.gov/current/cgi/runquery.pl?" + q)
            if is_jpeg(data):
                # Sqrt, then a stretch of our own: SkyView's default (log) washed 16 of the first 300 out to near-white (31 October 2026),
                # and plates differ in exposure, so every picture is stretched to its own range.
                grey = Image.open(io.BytesIO(data)).convert("L").resize((WIDTH, HEIGHT), Image.LANCZOS)
                return ImageOps.autocontrast(grey, cutoff=(0.5, 0.05))
        except Exception as e:
            print("   ", survey, "error:", e, file=sys.stderr)
        time.sleep(delay * (attempt + 2) * 2)   # busy: wait longer each time
    raise ValueError("SkyView stayed busy for " + survey)


def from_skyview(t, delay):
    return skyview_band(t, "DSS2 Red", delay).convert("RGB")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default=str(ROOT / "build/survey-set"))
    ap.add_argument("--limit", type=int)
    ap.add_argument("--source", choices=["auto", "cds", "skyview"], default="auto")
    ap.add_argument("--delay", type=float, default=3.0, help="seconds between requests to SkyView")
    ap.add_argument("--quality", type=int, default=65)
    a = ap.parse_args()
    out = Path(a.out); out.mkdir(parents=True, exist_ok=True)
    todo = targets()[: a.limit]
    source, done, failed = a.source, 0, []
    print(f"{len(todo)} targets, {WIDTH}x{HEIGHT}, source {source}", flush=True)
    for i, t in enumerate(todo, 1):
        f = out / (t["id"] + ".webp")
        if f.exists(): continue
        try:
            if source in ("auto", "cds"):
                try: img = from_cds(t)
                except Exception as e:
                    if source == "cds": raise
                    print("CDS unreachable, using SkyView:", e, flush=True); source = "skyview"; img = from_skyview(t, a.delay); time.sleep(a.delay)
            else:
                img = from_skyview(t, a.delay); time.sleep(a.delay)
            img.save(f, "WEBP", quality=a.quality, method=6)
            done += 1
            print(f"[{i}/{len(todo)}] {t['id']} {f.stat().st_size} B", flush=True)
        except Exception as e:
            failed.append(t["id"]); print(f"[{i}/{len(todo)}] {t['id']} FAILED: {e}", flush=True)
    files = sorted(out.glob("*.webp"))
    sizes = {p.stem: p.stat().st_size for p in files}
    manifest = {"width": WIDTH, "height": HEIGHT, "fovWidthDeg": FOV_W, "fovHeightDeg": FOV_H, "count": len(sizes),
                "totalBytes": sum(sizes.values()), "failed": failed, "bytes": sizes}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))
    n = max(1, len(sizes))
    print(f"{len(sizes)} files, {manifest['totalBytes'] / 1e6:.1f} MB, mean {manifest['totalBytes'] // n} B; {len(failed)} failed", flush=True)
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
