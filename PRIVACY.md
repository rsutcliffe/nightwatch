# Nightwatch privacy policy

*Last updated 26 September 2026. Applies to Nightwatch 0.7.0 and later, from GitHub, delphi-dolphin.com or the Mac App Store.*

Nightwatch is a free, open-source Mac app by Richard Sutcliffe. It has no accounts, no analytics, no advertising and no
tracking. The developer collects no data about you: nothing is sent to the developer, and there is no Nightwatch server.

## What stays on your Mac

- **Your settings:** your saved sites, telescope, alert choices and so on.
- **Your location**, if you let Nightwatch use it. It is used to work out sunset, darkness and what is visible from where
  you are.
- **Caches:** forecasts, tonight's plan and sky-survey images, plus a record of which alerts tonight has already sent, so
  none is sent twice.

All of it is kept in Nightwatch's own folder on your Mac,
`~/Library/Containers/io.github.rsutcliffe.nightwatch`. Delete the app and that folder, and it is gone.

## What is sent over the internet, and to whom

To fetch forecasts, Nightwatch sends **the coordinates of the place being forecast** (your location or a saved site, and
nearby dark-sky sites if that feature is on). No name, account, identifier or device information goes with them. They
go to:

- **Apple Weather (WeatherKit)**, on builds signed for it. See [Apple's privacy policy](https://www.apple.com/legal/privacy/).
- **[Open-Meteo](https://open-meteo.com/en/terms)**, for cloud cover and a second opinion.
- **[7Timer!](https://www.7timer.info)**, for seeing and transparency.

Other requests carry nothing about you or your location:

- **[AuroraWatch UK](https://aurorawatch.lancs.ac.uk)**, for the aurora status, if aurora alerts are on.
- **The Minor Planet Center and CelesTrak**, for comet and ISS data.
- **CDS (Strasbourg)**, for sky-survey images. It receives the sky position of the target being shown, not yours.
- **GitHub**, once a day, to check for a newer version (download from GitHub or delphi-dolphin.com only; Settings ›
  Updates turns it off). The App Store version does not check; the App Store updates it.

Each request identifies itself as Nightwatch and its version, as the services ask. These services receive your IP
address as part of any internet request, and their own privacy policies apply. Nightwatch shares nothing else with them
or with anyone.

## Permissions

- **Location** is asked for only when you choose "Use this Mac's location". You can refuse it and add a site by hand,
  or turn it off later in System Settings › Privacy & Security › Location Services.
- **Notifications** are used only for Nightwatch's own alerts.

## Children

Nightwatch collects no personal data from anyone, including children.

## Changes and contact

Changes to this policy are published here, in the app's public repository, with the date above. Questions:
[GitHub Discussions](https://github.com/rsutcliffe/nightwatch/discussions), or
[open an issue](https://github.com/rsutcliffe/nightwatch/issues).
