# Nightwatch: product overview

*As of 25 September 2026, version 0.6.6 "Night Watch", the first public download. Free and open source, MIT licence. https://github.com/rsutcliffe/nightwatch*

## What it is

Nightwatch is a silent macOS menu-bar app for amateur astronomers and astrophotographers. It answers two questions without being opened: will tonight be clear enough for a long imaging session, and what is worth pointing at. It runs on any Mac on macOS 14 or later, needs no account and no API key, and keeps every calculation on the machine. The download from the GitHub releases page is signed with a Developer ID and notarised by Apple, and reads Apple Weather. Built from source it needs only the Command Line Tools and reads Open-Meteo, unless it is signed with the builder's own Apple Developer certificate.

It was built for a DwarfLab DWARF Mini owner in the UK, but it is telescope-agnostic: any instrument is described by its field of view.

## Who it is for

- An imager with a smart telescope or a camera and lens, who wants to be told when a night is worth the effort rather than reading forecast charts every evening.
- A UK observer, where clear nights are scarce and a missed one costs more than a false alarm.
- Anyone who wants a quiet, keyless, offline-capable tool rather than a subscription app.

## How it decides

Every 30 minutes Nightwatch fetches forecasts for the active site: cloud, dew point, wind and visibility from Apple Weather (WeatherKit) when the build is signed for it, or from Open-Meteo otherwise, and 7Timer for seeing and transparency. On a signed build Open-Meteo's cloud is also fetched as a second opinion, shown as one agreement line and never used for the verdict. Apple Weather also supplies low, mid and high cloud layers directly; Open-Meteo estimates them. The popover footer names the source that drove tonight's verdict. It computes astronomical darkness, Moon phase and position, planet positions and target visibility locally with Astronomy Engine.

A night qualifies under the default go rule when there is a contiguous run of at least 3 hours inside astronomical darkness with total cloud at or under 25 percent. Both figures are adjustable, as is a minimum target altitude. Each night gets a score from cloud, Moon, seeing, transparency and wind, so the app ranks nights and sites, not only passes them.

On summer nights without proper darkness, an opt-in bright-night mode keeps the heads-up coming: a one-hour clear run in nautical darkness (Sun 12° down) with the Moon or a naked-eye planet at least 15° up. The Moon no longer counts against the score on a bright night, because it is the target.

Nothing leaves the Mac except the forecast requests (for the active site, home while observing elsewhere, and the nearest dark sites), sky-survey image fetches, the comet and ISS element downloads, and, when aurora alerts are on, AuroraWatch UK's status after dark. Every request names the app and its version.

## What it shows

**Menu-bar icon.** A star whose state says whether a window is coming, open, or unknown (stale forecast).

**Popover.** Liquid Glass on macOS 26 and later, a solid dark fill otherwise or with Reduce Transparency on. Top to bottom:
- **Header:** the site name, Bortle class and the equatorial set-up line (wedge tilt equals the site latitude, pointed at true north or south).
- **Away bar:** when observing somewhere other than home, "Observing away from home · Back to <home>", which returns everything to home in one click.
- **Score:** the sky score inside a 60-tick 12-hour clock bezel. Ticks glow red across the clear window, dim where it is dark but cloudy, and faint in daylight.
- **Verdict:** the clear window, or "Nothing to see here" with a plain reason, plus a "Held back by a 97% moon and high dew risk" line when something costs the score points, and, on a signed build, Open-Meteo's second opinion ("Open-Meteo agrees", or where it differs).
- **Clear-sky bars:** one per hour of darkness, with the window hours red.
- **Notice line:** at most one: aurora, in AuroraWatch UK's own colours (yellow, amber or red) and linking to their site, or a clearer dark site nearby.
- **Six tiles:** dark hours, the Moon with a real NASA phase image and its set or rise time, seeing, wind, dew or frost risk (amber with "Dew heater advised" when high), and transparency.
- **Best targets:** the best three, with thumbnails, catalogue ID, name and best time.
- **Footer:** a "Notify at HH:MM" switch, the Patrol button, and the update time with the cloud source (the Apple Weather mark and legal link, or Open-Meteo), plus an amber dot and "{n} h ago" when the forecast is over six hours old.

**Targets window.** Everything above the horizon during tonight's window, grouped into nebulae, galaxies, star clusters, planets and Moon, events, constellations, and dark sites.
- **Cards:** Digitized Sky Survey images for deep sky, real photographs for the planets and the Moon, and artwork made for Nightwatch for all 88 constellations (the figure with its star points on top).
  - Every card's timeline spans the clear window, lit where the target is viewable, brighter where it is higher, with the best moment marked and "Viewable HH:MM–HH:MM · Best HH:MM · N°" beneath.
  - A neutral chip says how much of the field of view the target fills.
  - Amber chips flag targets that the Moon washes out or sits within 15° of.
  - Titles follow one pattern: catalogue ID, then name, then magnitude.
- **Header:** a slim clear-sky strip and a sort control (Best now, Altitude, Size, Brightness).
- **Sidebar:** glass, with the filters as switches under an amber Moon line.
- **Events:** meteor showers, eclipses, conjunctions, comets and ISS passes.
- **Detail page:** the image fills the window and the text sits on it in black caption boxes.
  - Deep-sky survey photos fill the page, fetched sharp at 1600 px. A pill says "Shown at your field of view", or, for an object bigger than the field, a dashed box marks what you would capture, with extra sky around it.
  - The Moon, planet photographs and constellation artwork are fitted above the caption.
  - The caption holds the name, type and coordinates, and the survey image's credit where one is shown. On a night with a clear window it adds best time, time above the minimum altitude, Moon separation, a suggested stack, and an altitude chart from sunset to sunrise. The chart shows the window shaded and the minimum altitude dashed, and the curve is red only where the target is up inside the window.

**Desktop widgets.** Small, medium and large widgets for the macOS desktop, included in the download (building them from source needs Xcode and xcodegen). The small one shows the sky-score bezel and a one-line verdict; the medium adds the window, the reason, Open-Meteo's line and the clear-sky bars; the large adds the hour labels, the best three targets and the notify time. They draw a snapshot the app writes after each patrol, so they always agree with the popover, and they fetch nothing themselves. A forecast more than six hours old shows an amber warning. With aurora alerts on, "● Aurora amber" in AuroraWatch UK's colour shows while the status is at or above the chosen level and less than an hour old: on the small widget's second line, and at the end of the header line on the medium and large ones. Clicking a widget opens the Targets window; clicking a target on the large one opens its detail. The widget is the glance, the popover says why and whether to go out, and Targets is for planning.

**Dark sites.** Certified places (DarkSky International parks, reserves, sanctuaries and communities, plus 25 UK Dark Sky Discovery Sites near Sheffield) from a bundled list of 76, and up to five computed dark spots from a bundled light-pollution grid, all within a user-set radius (5 to 300 km or miles, default 50). Each card shows distance, bearing, darkness band or Bortle class, tonight's clear window and score. Forecasts are fetched for the nearest eight. "Observe from here" makes a site the active site for the whole app without saving it; the popover and the Dark sites page then offer "Back to" home in one click. Each card compares tonight's score and sky with home ("vs 20 at <home> (home)" while away), as does the popover's "Clearer sky" line, which opens that site's card.

**Settings.** Where you observe: one list of saved sites and this Mac's location, a click to observe from any of them, a star for home (a saved site or this Mac's location), a visited dark site kept apart until you choose Keep, and "Add a site…" with labelled fields and the sky's darkness chosen by name (Bortle 1 Pristine to 9 Inner city). Then telescope preset or field of view in degrees, go rule, alert options and quiet hours, dark-site radius and unit, bright nights, aurora alerts and threshold, wording, launch at login. Every numeric setting is a menu that shows its value.

## Alerts

All alerts are macOS notifications and all are derived from local sunset at the active site, so they are correct in either hemisphere and any time zone.

- Evening heads-up, one hour before sunset, when tonight qualifies. On a signed build it, and the nudge before the window, end with Open-Meteo's second opinion, and the opt-in "Alert only when Open-Meteo agrees" holds it back when Open-Meteo is not clear enough inside the window.
- Tomorrow preview.
- A nudge 30 minutes before the window opens.
- After a heads-up or nudge, if the forecast turns:
  - **Stand-down** ("Stand down. Clouds moving in") when Apple Weather and Open-Meteo both lose the window, or when there is no second opinion.
  - **Less certain** ("Hold fire. Forecasts disagree") when they split, saying what each sees. For example, "Apple Weather still sees clear from 21:00. Open-Meteo sees no clear window." Where only Open-Meteo doubts, it is sent only with the opt-in "Alert only when Open-Meteo agrees" on. It is sent at most once a night. If both clear again before the nudge, the nudge still fires; if the nudge has already gone, nothing more is sent. Nothing is sent after the window has closed.
- Aurora alert (opt-in): AuroraWatch UK at or above the chosen level after dark, with this hour clear. It plays the alert sound, because an aurora does not wait.
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

Keyless; Apple Weather needs a signed build, which the download is. Full attributions in `NOTICE`. Open-Meteo, 7Timer, AuroraWatch UK and the Digitized Sky Survey are all used under non-commercial terms, which is why Nightwatch is free with no ads, subscriptions or in-app purchases. 7Timer's author has been told the app uses the data, as its terms ask.

| Purpose | Source | Licence |
| --- | --- | --- |
| Cloud, dew point, wind, visibility (primary, signed builds) | Apple Weather via WeatherKit | Apple WeatherKit terms, attribution shown in the popover |
| Cloud, dew point, wind, visibility (fallback, all builds); cloud as the second opinion on signed builds | Open-Meteo | CC BY 4.0 |
| Seeing, transparency | 7Timer (Shanghai Astronomical Observatory) | Non-commercial use |
| Aurora status (opt-in) | AuroraWatch UK, Lancaster University | Free, non-commercial use, attribution |
| Ephemeris | Astronomy Engine (vendored C) | MIT |
| Deep-sky catalogue | OpenNGC | CC BY-SA 4.0 |
| Constellation artwork | Made for Nightwatch; star lines from d3-celestial | MIT (artwork), BSD-3 (star lines) |
| Sky-survey images | Digitized Sky Survey (STScI/NASA), coloured by CDS, via hips2fits | ODbL 1.0 (CDS); STScI permits non-profit use with acknowledgement; plates copyright AAO, SERC, Caltech, AURA |
| Comets | IAU Minor Planet Center | Public |
| ISS passes | CelesTrak elements, SatelliteKit SGP4 | MIT |
| Meteor showers | International Meteor Organization calendar | Compiled |
| Moon image | NASA SVS Dial-a-Moon | Public domain |
| Planet photographs | NASA missions via Wikimedia Commons | Public domain |
| Certified dark-sky places | DarkSky International, UK Dark Sky Discovery Sites, coordinates from Wikidata | CC0 coordinates |
| Light-pollution grid | NOAA/NASA EOG VIIRS annual composite, Natural Earth land mask | CC BY 4.0, public domain |

## Architecture

- A Swift package with four targets: `CAstronomyEngine` (vendored C), `SkyCore` (all logic and bundled data, fully tested), `NightwatchUI` (the views the app and the widget share) and `Nightwatch` (the SwiftUI menu-bar app). The widget extension is the one Xcode project, generated from `Widget/project.yml` with xcodegen; it reads a snapshot the app writes to a shared App Group after each patrol.
- `scripts/build-app.sh` builds and installs: ad hoc without a certificate, or with the WeatherKit entitlement and the widget when an Apple Development certificate and profile are on the Mac. `scripts/release.sh` builds the public download: a Developer ID signed, notarised and stapled DMG, attached to the GitHub release (`docs/releasing.md`). Tests run with `scripts/test.sh` (229 Swift Testing tests at 0.6.6).
- Caches under `~/Library/Caches/Nightwatch`. Settings in `~/Library/Application Support/Nightwatch/config.json`, a plain JSON file which can be symlinked into iCloud Drive to share across Macs.
- Data-building scripts in Python: `build-lp-grid.py` (VIIRS GeoTIFF to a 6.4 MB UK grid with sea masked and 7 x 7 smoothing) and `build-certified.py` (Wikidata plus a hand-verified curated list).

## Tone

The app carries a light Terry Pratchett City Watch flavour in its wording (Patrol, "All's well", "Hold fire", "Nothing to see here. Move along."), with a plain-wording toggle in Settings for anyone who would rather not. The flavour stays in light touches: anything a newcomer must understand to act, such as "Observe from here" or "Where you observe", is plain in both modes.

## What it is not

- It does not control a telescope. It tells you when and what; the DwarfLab or Seestar app does the rest.
- It is Mac-only. There is no iPhone app or iPhone widget yet.
- It is not a forecast provider. It reads Apple Weather or Open-Meteo plus 7Timer and applies a rule; it does not claim better accuracy than its sources.
- It is not commercial: its data sources' terms rule out a paid or ad-supported product without replacing them.
- It is not on the Mac App Store: the app is not sandboxed, which the store requires. It is a signed, notarised download instead.

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
| 0.6.1 | Night Watch, patch 1 | 25 September 2026 | The popover's aurora line in AuroraWatch UK's own colours (yellow, amber, red), the owner's choice over the night palette |
| 0.6.2 | Night Watch, patch 2 | 25 September 2026 | Constellation artwork for all 88 constellations, a figure with its star plot on top, in place of the stick figures |
| 0.6.3 | Night Watch, patch 3 | 25 September 2026 | After a heads-up, a stand-down only when both forecasts lose the window; when they split, "Hold fire. Forecasts disagree", saying what each sees |
| 0.6.4 | Night Watch, patch 4 | 25 September 2026 | Full-window target detail pages with caption boxes and a labelled altitude chart; sharper survey photos; the dashed field-of-view box kept clear of the caption; dark-site cards say "Observe from here" instead of "Use as beat" |
| 0.6.5 | Night Watch, patch 5 | 25 September 2026 | Where you observe: home, one-click "Back to" home from the popover and Dark sites, dark sites visited without being saved, honest comparison with home, an "Add a site" sheet with named sky darkness, and menus in place of up/down arrows throughout Settings |
| 0.6.6 | Night Watch, patch 6 | 25 September 2026 | The first public download: a signed, notarised DMG on the GitHub release. Aurora on the desktop widgets; aurora alerts play a sound; the large widget no longer overflows on a clear night (measured at the real 344 × 344 size); AuroraWatch UK linked and the sky survey credited as their terms ask; `scripts/release.sh` builds a Developer ID signed, notarised download |

## Install

Download `Nightwatch-<version>.dmg` from https://github.com/rsutcliffe/nightwatch/releases/latest, open it and drag Nightwatch to Applications. It is signed and notarised, so it opens without a warning. To add the widget, right-click the desktop › Edit Widgets… › Nightwatch.

Or build from source:

    xcode-select --install
    git clone https://github.com/rsutcliffe/nightwatch.git && cd nightwatch
    scripts/build-app.sh

Grant Location Services when asked, or add a site in Settings › Where you observe. Allow notifications in System Settings.
