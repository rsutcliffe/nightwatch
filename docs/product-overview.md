# Nightwatch: product overview

*As of 25 September 2026, version 0.6.0 "Night Watch". Open source, MIT licence. https://github.com/rsutcliffe/nightwatch*

## What it is

Nightwatch is a silent macOS menu-bar app for amateur astronomers and astrophotographers. It answers two questions without being opened: will tonight be clear enough for a long imaging session, and what is worth pointing at. It runs on any Mac on macOS 14 or later, builds with the Command Line Tools alone, needs no account and no API key in its plain form, and keeps every calculation on the machine. Signed with an Apple Developer certificate, it reads Apple Weather instead of Open-Meteo.

It was built for a DwarfLab DWARF Mini owner in the UK, but it is telescope-agnostic: any instrument is described by its field of view.

## Who it is for

- An imager with a smart telescope or a camera and lens, who wants to be told when a night is worth the effort rather than reading forecast charts every evening.
- A UK observer, where clear nights are scarce and a missed one costs more than a false alarm.
- Anyone who wants a quiet, keyless, offline-capable tool rather than a subscription app.

## How it decides

Every 30 minutes Nightwatch fetches forecasts for the active site: cloud, dew point, wind and visibility from Apple Weather (WeatherKit) when the build is signed for it, or from Open-Meteo otherwise, and 7Timer for seeing and transparency. On a signed build Open-Meteo's cloud is also fetched as a second opinion, shown as one agreement line and never used for the verdict. Apple Weather also supplies low, mid and high cloud layers directly; Open-Meteo estimates them. The popover footer names the source that drove tonight's verdict. It computes astronomical darkness, Moon phase and position, planet positions and target visibility locally with Astronomy Engine.

A night qualifies under the default go rule when there is a contiguous run of at least 3 hours inside astronomical darkness with total cloud at or under 25 percent. Both figures are adjustable, as is a minimum target altitude. Each night gets a score from cloud, Moon, seeing, transparency and wind, so the app ranks nights and sites, not only passes them.

On summer nights without proper darkness, an opt-in bright-night mode keeps the heads-up coming: a one-hour clear run in nautical darkness (Sun 12° down) with the Moon or a naked-eye planet at least 15° up. The Moon no longer counts against the score on a bright night, because it is the target.

Nothing leaves the Mac except the forecast requests, thumbnail fetches, the comet and ISS element downloads, and, when aurora alerts are on, AuroraWatch UK's status after dark.

## What it shows

**Menu-bar icon.** A star whose state says whether a window is coming, open, or unknown (stale forecast).

**Popover.** Liquid Glass on macOS 26 and later, a solid dark fill otherwise or with Reduce Transparency on. Top to bottom:
- **Header:** the site name, Bortle class and the equatorial set-up line (wedge tilt equals the site latitude, pointed at true north or south).
- **Score:** the sky score inside a 60-tick 12-hour clock bezel. Ticks glow red across the clear window, dim where it is dark but cloudy, and faint in daylight.
- **Verdict:** the clear window, or "Nothing to see here" with a plain reason, plus a "Held back by a 97% moon and high dew risk" line when something costs the score points, and, on a signed build, Open-Meteo's second opinion ("Open-Meteo agrees", or where it differs).
- **Clear-sky bars:** one per hour of darkness, with the window hours red.
- **Notice line:** at most one, for aurora (in AuroraWatch UK's own colours: yellow, amber or red) or a clearer dark site nearby.
- **Six tiles:** dark hours, the Moon with a real NASA phase image and its set or rise time, seeing, wind, dew or frost risk (amber with "Dew heater advised" when high), and transparency.
- **Best targets:** the best three, with thumbnails, catalogue ID, name and best time.
- **Footer:** a "Notify at HH:MM" switch, the Patrol button, and the update time with the cloud source (the Apple Weather mark and legal link, or Open-Meteo), plus an amber dot and "{n} h ago" when the forecast is over six hours old.

**Targets window.** Everything above the horizon during tonight's window, grouped into nebulae, galaxies, star clusters, planets and Moon, events, constellations, and dark sites.
- **Cards:** DSS2 sky-survey thumbnails for deep sky, real photographs for the planets and the Moon.
  - Every card's timeline spans the clear window, lit where the target is viewable, brighter where it is higher, with the best moment marked and "Viewable HH:MM–HH:MM · Best HH:MM · N°" beneath.
  - A neutral chip says how much of the field of view the target fills.
  - Amber chips flag targets that the Moon washes out or sits within 15° of.
  - Titles follow one pattern: catalogue ID, then name, then magnitude.
- **Header:** a slim clear-sky strip and a sort control (Best now, Altitude, Size, Brightness).
- **Sidebar:** glass, with the filters as switches under an amber Moon line.
- **Events:** meteor showers, eclipses, conjunctions, comets and ISS passes.

**Desktop widgets.** Small, medium and large widgets for the macOS desktop, built when Xcode and xcodegen are installed. The small one shows the sky-score bezel and a one-line verdict; the medium adds the window, the reason, Open-Meteo's line and the clear-sky bars; the large adds the hour labels, the best three targets and the notify time. They draw a snapshot the app writes after each patrol, so they always agree with the popover, and they fetch nothing themselves. A forecast more than six hours old shows an amber warning. Clicking a widget opens the Targets window; clicking a target on the large one opens its detail. The widget is the glance, the popover says why and whether to go out, and Targets is for planning.

**Dark sites.** Certified places (DarkSky International parks, reserves, sanctuaries and communities, plus 25 UK Dark Sky Discovery Sites near Sheffield) from a bundled list of 76, and up to five computed dark spots from a bundled light-pollution grid, all within a user-set radius (5 to 300 km or miles, default 50). Each card shows distance, bearing, darkness band or Bortle class, tonight's clear window and score. Forecasts are fetched for the nearest eight. "Use as beat" makes a site the active site for the whole app. Each card compares tonight's score and sky with home, and the popover's "Clearer sky" line opens that site's card.

**Settings.** Sites (automatic via Location Services or manual, with Bortle class), telescope preset or field of view in degrees, go rule, alert options and quiet hours, dark-site radius and unit, bright nights, aurora alerts and threshold, wording, launch at login.

## Alerts

All alerts are macOS notifications and all are derived from local sunset at the active site, so they are correct in either hemisphere and any time zone.

- Evening heads-up, one hour before sunset, when tonight qualifies. On a signed build it, and the nudge before the window, end with Open-Meteo's second opinion, and the opt-in "Alert only when Open-Meteo agrees" holds it back when Open-Meteo is not clear enough inside the window.
- Tomorrow preview.
- A nudge 30 minutes before the window opens.
- Stand-down if the forecast turns and the night no longer qualifies.
- Aurora alert (opt-in): AuroraWatch UK at or above the chosen level after dark, with this hour clear.
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

Keyless in the plain build; Apple Weather needs a signed build. Full attributions in `NOTICE`.

| Purpose | Source | Licence |
| --- | --- | --- |
| Cloud, dew point, wind, visibility (primary, signed builds) | Apple Weather via WeatherKit | Apple WeatherKit terms, attribution shown in the popover |
| Cloud, dew point, wind, visibility (fallback, all builds); cloud as the second opinion on signed builds | Open-Meteo | CC BY 4.0 |
| Seeing, transparency | 7Timer (Shanghai Astronomical Observatory) | Non-commercial use |
| Aurora status (opt-in) | AuroraWatch UK, Lancaster University | Free, non-commercial use, attribution |
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
- Builds and installs with `scripts/build-app.sh`, which signs ad hoc, or with the WeatherKit entitlement and an embedded provisioning profile when an Apple Development certificate and a profile for the bundle identifier are on the Mac. Tests run with `scripts/test.sh` (202 Swift Testing tests at 0.6.0).
- Caches under `~/Library/Caches/Nightwatch`. Settings in `~/Library/Application Support/Nightwatch/config.json`, a plain JSON file which can be symlinked into iCloud Drive to share across Macs.
- Data-building scripts in Python: `build-lp-grid.py` (VIIRS GeoTIFF to a 6.4 MB UK grid with sea masked and 7 x 7 smoothing) and `build-certified.py` (Wikidata plus a hand-verified curated list).

## Tone

The app carries a light Terry Pratchett City Watch flavour in its wording (Patrol, Beat, "All's well", "Nothing to see here. Move along."), with a plain-wording toggle in Settings for anyone who would rather not.

## What it is not

- It does not control a telescope. It tells you when and what; the DwarfLab or Seestar app does the rest.
- It is Mac-only. There is no iPhone app or iPhone widget yet.
- It is not a forecast provider. It reads Apple Weather or Open-Meteo plus 7Timer and applies a rule; it does not claim better accuracy than its sources.
- It is non-commercial: 7Timer's terms rule out a paid product without replacing that source.

## Releases

Tags follow the City Watch novels.

| Version | Name | Date | Contents |
| --- | --- | --- | --- |
| 0.1.0 | Guards! Guards! | 23 September 2026 | Forecasts, go rule, alerts, popover, target browser, presets, Discworld flavour |
| 0.2.0 | Men at Arms | 24 September 2026 | Dark-sky sites: certified list, light-pollution grid, per-site forecasts, use as beat |
| 0.2.1 | Men at Arms, patch 1 | 24 September 2026 | Equatorial tilt line in the popover header; Apple Weather via WeatherKit as the primary cloud source with Open-Meteo fallback; signed build path |
| 0.2.2 | Men at Arms, patch 2 | 24 September 2026 | Plain reason line under the no-window verdict; popover footer in two rows with the cloud source; strip caption names the real source |
| 0.3.0 | Feet of Clay | 24 September 2026 | Bright-night mode; aurora alerts from AuroraWatch UK; best-spot completion (Clearer sky line lands on the card, cards compare with home); site-cache pruning |
| 0.3.1 | Feet of Clay, patch 1 | 24 September 2026 | Fixes from the release review: stale aurora statuses never alert; the bright reason line matches the rule; toggling Bright nights mid-evening no longer sends a stand-down |
| 0.4.0 | Jingo | 24 September 2026 | Liquid Glass redesign: sky-score bezel, "Held back by" reason line, clear-sky bars, dew warning tile, notify switch; Targets viewability timeline, frame-fill chips, sort control, glass sidebar, Moon line |
| 0.4.1 | Jingo, patch 1 | 25 September 2026 | Tiles in each popover row share one height; tile contrast measured live and fixed (tiles are a fill on the glass panel) |
| 0.5.0 | The Fifth Elephant | 25 September 2026 | Open-Meteo as a second opinion beside Apple Weather: one agreement line in the popover and alerts; opt-in "Alert only when Open-Meteo agrees"; nothing logged |
| 0.5.1 | The Fifth Elephant, patch 1 | 25 September 2026 | App icon: a star over a red-lit horizon, as a Liquid Glass icon when built with Xcode and a classic icon otherwise |
| 0.5.2 | The Fifth Elephant, patch 2 | 25 September 2026 | App icon replaced with the owner's favourite: a porthole onto the night sky with a red-lit horizon, full-bleed for macOS 27 |
| 0.6.0 | Night Watch | 25 September 2026 | Desktop widgets (small, medium, large) drawn from the patrol snapshot; clicking opens Targets or a target's detail; Targets sidebar rebuilt on a native list; "All targets" is a button; windows open centred |

## Install

    xcode-select --install
    git clone https://github.com/rsutcliffe/nightwatch.git && cd nightwatch
    scripts/build-app.sh

Grant Location Services when asked, or add a site in Settings. Allow notifications in System Settings.
