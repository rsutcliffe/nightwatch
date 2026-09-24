# Nightwatch: product overview

*As of 24 September 2026, version 0.2.0 "Men at Arms". Open source, MIT licence. https://github.com/rsutcliffe/nightwatch*

## What it is

Nightwatch is a silent macOS menu-bar app for amateur astronomers and astrophotographers. It answers two questions without being opened: will tonight be clear enough for a long imaging session, and what is worth pointing at. It runs on any Mac on macOS 14 or later, builds with the Command Line Tools alone, needs no account and no API key, and keeps every calculation on the machine.

It was built for a DwarfLab DWARF Mini owner in Sheffield, but it is telescope-agnostic: any instrument is described by its field of view.

## Who it is for

- An imager with a smart telescope or a camera and lens, who wants to be told when a night is worth the effort rather than reading forecast charts every evening.
- A UK observer, where clear nights are scarce and a missed one costs more than a false alarm.
- Anyone who wants a quiet, keyless, offline-capable tool rather than a subscription app.

## How it decides

Every 30 minutes Nightwatch fetches two forecasts for the active site: Open-Meteo for cloud, dew point, wind and visibility, and 7Timer for seeing and transparency. It computes astronomical darkness, Moon phase and position, planet positions and target visibility locally with Astronomy Engine.

A night qualifies under the default go rule when there is a contiguous run of at least 3 hours inside astronomical darkness with total cloud at or under 25 percent. Both figures are adjustable, as is a minimum target altitude. Each night gets a score from cloud, Moon, seeing, transparency and wind, so the app ranks nights and sites, not only passes them.

Nothing leaves the Mac except the two forecast requests, thumbnail fetches, and the comet and ISS element downloads.

## What it shows

**Menu-bar icon.** A star whose state says whether a window is coming, open, or unknown (stale forecast).

**Popover.** Site name and Bortle class, tonight's score, the clear window or "Nothing to see here", an hourly cloud strip, six tiles (dark hours, Moon with a real NASA phase image, seeing, wind, dew or frost risk, transparency), the best three targets with thumbnails, one line naming a nearby dark site when it beats home by 20 points or more, the last update time, and a refresh button.

**Targets window.** Everything above the horizon during tonight's window, grouped into nebulae, galaxies, star clusters, planets and Moon, events, constellations, and dark sites. Deep-sky cards carry DSS2 sky-survey thumbnails and a fits-frame badge relative to the chosen field of view (fits, mosaic, or small). Planets and the Moon use real photographs. Events cover meteor showers, eclipses, conjunctions, comets and ISS passes. Filters: fits my field of view, include Moon-washed, and search.

**Dark sites.** Certified places (DarkSky International parks, reserves, sanctuaries and communities, plus 25 UK Dark Sky Discovery Sites near Sheffield) from a bundled list of 76, and up to five computed dark spots from a bundled light-pollution grid, all within a user-set radius (5 to 300 km or miles, default 50). Each card shows distance, bearing, darkness band or Bortle class, tonight's clear window and score. Forecasts are fetched for the nearest eight. "Use as beat" makes a site the active site for the whole app.

**Settings.** Sites (automatic via Location Services or manual, with Bortle class), telescope preset or field of view in degrees, go rule, alert options and quiet hours, dark-site radius and unit, wording, launch at login.

## Alerts

All alerts are macOS notifications and all are derived from local sunset at the active site, so they are correct in either hemisphere and any time zone.

- Evening heads-up, one hour before sunset, when tonight qualifies.
- Tomorrow preview.
- A nudge 30 minutes before the window opens.
- Stand-down if the forecast turns and the night no longer qualifies.
- Quiet hours, default 00:00 to 07:00.
- Nothing fires from a forecast older than six hours.

## Telescope presets

| Preset | Field of view |
| --- | --- |
| DwarfLab DWARF Mini | 2.1 x 1.2 degrees |
| DwarfLab DWARF 3 | 2.93 x 1.65 degrees |
| ZWO Seestar S50 | 1.29 x 0.73 degrees |
| APS-C camera, 200 mm lens | 6.7 x 4.5 degrees |
| Custom | any width and height in degrees |

## Data sources

All keyless. Full attributions in `NOTICE`.

| Purpose | Source | Licence |
| --- | --- | --- |
| Cloud, dew point, wind, visibility | Open-Meteo | CC BY 4.0 |
| Seeing, transparency | 7Timer (Shanghai Astronomical Observatory) | Non-commercial use |
| Ephemeris | Astronomy Engine (vendored C) | MIT |
| Deep-sky catalogue | OpenNGC | CC BY-SA 4.0 |
| Constellation figures | d3-celestial | BSD-3 |
| Thumbnails | CDS hips2fits, DSS2 | DSS images copyright AAO, SERC, Caltech, AURA |
| Comets | IAU Minor Planet Center | Public |
| ISS passes | CelesTrak elements, SatelliteKit SGP4 | MIT |
| Meteor showers | International Meteor Organization calendar | Compiled |
| Moon image | NASA SVS Dial-a-Moon | Public domain |
| Planet photographs | NASA missions via Wikimedia Commons | Public domain |
| Certified dark-sky places | DarkSky International, UK Dark Sky Discovery Sites, coordinates from Wikidata | CC0 coordinates |
| Light-pollution grid | NOAA/NASA EOG VIIRS annual composite, Natural Earth land mask | CC BY 4.0, public domain |

## Architecture

- Swift package, no Xcode project. Three targets: `CAstronomyEngine` (vendored C), `SkyCore` (all logic and bundled data, fully tested), `Nightwatch` (the SwiftUI menu-bar app).
- Builds and installs with `scripts/build-app.sh`; tests run with `scripts/test.sh` (99 Swift Testing tests at 0.2.0).
- Caches under `~/Library/Caches/Nightwatch`. Settings in `~/Library/Application Support/Nightwatch/config.json`, a plain JSON file which can be symlinked into iCloud Drive to share across Macs.
- Data-building scripts in Python: `build-lp-grid.py` (VIIRS GeoTIFF to a 6.4 MB UK grid with sea masked and 7 x 7 smoothing) and `build-certified.py` (Wikidata plus a hand-verified curated list).

## Tone

The app carries a light Terry Pratchett City Watch flavour in its wording (Patrol, Beat, "All's well", "Nothing to see here. Move along."), with a plain-wording toggle in Settings for anyone who would rather not.

## What it is not

- It does not control a telescope. It tells you when and what; the DwarfLab or Seestar app does the rest.
- It is Mac-only. There is no iPhone app or widget yet.
- It is not a forecast provider. It reads two public forecasts and applies a rule; it does not claim better accuracy than its sources.
- It is non-commercial: 7Timer's terms rule out a paid product without replacing that source.

## Releases

Tags follow the City Watch novels.

| Version | Name | Date | Contents |
| --- | --- | --- | --- |
| 0.1.0 | Guards! Guards! | 23 September 2026 | Forecasts, go rule, alerts, popover, target browser, presets, Discworld flavour |
| 0.2.0 | Men at Arms | 24 September 2026 | Dark-sky sites: certified list, light-pollution grid, per-site forecasts, use as beat |
| 0.3 | Feet of Clay | under discussion | see the product direction synthesis |

## Install

    xcode-select --install
    git clone https://github.com/rsutcliffe/nightwatch.git && cd nightwatch
    scripts/build-app.sh

Grant Location Services when asked, or add a site in Settings. Allow notifications in System Settings.
