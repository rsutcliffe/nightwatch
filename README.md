# Nightwatch

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

## Settings sync

Settings live in `~/Library/Application Support/Nightwatch/config.json`. Symlink it into iCloud Drive or any synced folder to share across Macs.

## Data sources and licences

See `NOTICE`. Weather data by Open-Meteo.com (CC BY 4.0). 7Timer data is for non-commercial use. OpenNGC is CC BY-SA 4.0. DSS images are copyright AAO, SERC, Caltech and AURA, served by CDS hips2fits.

## Release names

Tags follow the City Watch novels: 0.1 Guards! Guards!, 0.2 Men at Arms, 0.3 Feet of Clay, 0.4 Jingo, 0.5 The Fifth Elephant, 1.0 Night Watch.
