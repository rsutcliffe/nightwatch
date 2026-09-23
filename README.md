# Nightwatch

![The Moon, first quarter, photographed with a DWARF Mini](docs/images/moon-dwarf-mini.jpg)

*The Moon, DWARF Mini, Richard Sutcliffe.*

Silent macOS menu-bar app: tells you when tonight is clear enough for a long imaging session, and what to point at.

## Build and install (any Mac, macOS 14+, no Xcode needed)

    xcode-select --install        # Command Line Tools, once
    git clone https://github.com/rsutcliffe/nightwatch.git && cd nightwatch
    scripts/fetch-data.sh         # optional: only to refresh the bundled catalogue; the data is committed
    scripts/build-app.sh          # builds, signs ad hoc, installs to /Applications, launches

## Tests

    scripts/test.sh

## What it does

- Every 30 minutes it fetches Open-Meteo (cloud, dew point, wind, visibility) and 7Timer (seeing, transparency) for your site.
- It computes astronomical darkness, Moon, planets and target visibility locally with Astronomy Engine. Nothing leaves your Mac except those two forecast requests, thumbnail fetches from CDS, and comet/ISS element downloads.
- A night qualifies when there is a contiguous run of at least 3 hours inside astronomical darkness with total cloud at or under 25 % (all adjustable).
- Alerts: a heads-up one hour before local sunset, a nudge 30 minutes before the window opens, and a stand-down if the forecast turns. Quiet hours default to 00:00–07:00. Nothing fires from a forecast older than six hours.
- The target browser groups what is up during the window into nebulae, galaxies, star clusters, planets and Moon, events (meteor showers, eclipses, conjunctions, comets, ISS passes) and constellations, with DSS2 thumbnails and a fits-frame badge relative to your field of view.

## Telescope

Any. Pick a preset (DWARF Mini, DWARF 3, Seestar S50, APS-C at 200 mm) or type your field of view in degrees.

## Dark-sky sites

The Targets window's "Dark sites" group lists two kinds of place: certified sites (DarkSky International parks, reserves, sanctuaries and communities, plus the UK Dark Sky Discovery Sites) from a bundled list of 51 places compiled from Wikidata and hand-verified UK and Ireland entries, and up to five computed "dark spots" from a bundled light-pollution grid. Each card shows distance, bearing, a darkness band or Bortle class, tonight's clear window and a score. Forecasts are fetched for the nearest eight sites. "Use as beat" saves the site under Beats and makes it the active site. When a listed site scores 20 or more above home, the popover shows one line naming it.

Settings › Dark sites turns the group on or off and sets the search radius, 5 to 300 km (default 50), in kilometres or miles.

The bands (Very dark, Dark, Rural, Suburban, Bright) are Nightwatch's own thresholds on VIIRS upward radiance (under 0.25, 0.25 to 1, 1 to 5, 5 to 20, 20 and over nW/cm²/sr) — a heuristic, not a Bortle class. Certified places show a Bortle class only when the source states one.

To build a grid for another region, register for a free account at https://eogdata.mines.edu/products/vnl/, download the latest annual "average_masked" GeoTIFF (about 11 GB unpacked), then run:

    python3 -m venv .venv && .venv/bin/pip install -r scripts/requirements-data.txt
    .venv/bin/python scripts/build-lp-grid.py /path/to/VNL_*average_masked*.tif --bbox SOUTH,WEST,NORTH,EAST --cell 0.01 --out Sources/SkyCore/Resources/lightpollution/<region>.lpgrid

The bundled UK grid (`gb.lpgrid`, bbox 49.8,-8.7,60.9,1.8) is 1,332 × 1,260 cells at 0.00833° (about 0.9 km), 6.4 MB. The script rounds `--cell` to a whole multiple of the source's 15-arc-second pixels, so `--cell 0.01` produces 0.00833° cells. The app loads every `.lpgrid` file in that folder. Keep rows and columns under 65,535: use a larger `--cell` for big regions.

Certified by DarkSky International or the UK Dark Sky Discovery Sites programme; coordinates from Wikidata (CC0). Light-pollution grid derived from the NOAA/NASA Earth Observation Group VIIRS Nighttime Lights annual composite, CC BY 4.0.

## Settings sync

Settings live in `~/Library/Application Support/Nightwatch/config.json`. Symlink it into iCloud Drive or any synced folder to share across Macs.

## Data sources and licences

See `NOTICE`. Weather data by Open-Meteo.com (CC BY 4.0). 7Timer data is for non-commercial use. OpenNGC is CC BY-SA 4.0. DSS images are copyright AAO, SERC, Caltech and AURA, served by CDS hips2fits. Dark-sky site attributions are in "Dark-sky sites" above.

## Release names

Tags follow the City Watch novels: 0.1 Guards! Guards!, 0.2 Men at Arms, 0.3 Feet of Clay, 0.4 Jingo, 0.5 The Fifth Elephant, 1.0 Night Watch.
