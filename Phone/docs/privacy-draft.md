# Nightwatch for iPhone and iPad: privacy policy (draft)

*Draft, not published. It goes live only with the app's App Store submission, on its own page (not the Mac policy's).*

Nightwatch is a free, open-source app by Richard Sutcliffe. It has no accounts, no analytics, no advertising and no
tracking. The developer collects no data about you: nothing is sent to the developer, and there is no Nightwatch server.

## What stays on your device

- **Your settings:** your saved sites, alert choices and quiet hours. If you are signed in to iCloud they are also kept in
  your iCloud account, so your Mac, iPhone and iPad share them (Apple's iCloud key-value storage, under
  [Apple's privacy policy](https://www.apple.com/legal/privacy/)); the developer cannot see them. Red night mode is kept
  on each device only.
- **Your location**, if you let Nightwatch use it. It is asked for only when you press "Use this device's location". It is
  used once, to make a saved site for where you are. Only the coordinates go to the forecast services below.
- **The last forecast, tonight's plan and a record of which alerts have been sent**, so the app works without a
  connection and sends no alert twice.

## What is sent over the internet, and to whom

To read the forecast, Nightwatch sends **the coordinates of a saved site**:

- **Apple Weather (WeatherKit).** iOS makes these requests on Nightwatch's behalf and identifies the app to Apple, as it
  does for every app using Apple Weather. See [Apple's privacy policy](https://www.apple.com/legal/privacy/).
- **[Open-Meteo](https://open-meteo.com/en/terms)**, for cloud cover and a second opinion.
- **[7Timer!](https://www.7timer.info)**, for seeing and transparency.
- **Apple Maps**, when you type a place name in "Add a site": the text is sent to Apple Maps to find the place (with the
  area around your current site, so nearer places rank first). Your own location is not sent. Dark sites also asks Apple Maps
  for the nearest car park and town to each dark spot found near your site, and draws a small map of each.
- **Open-Meteo (elevation)**, once per saved site, with its coordinates, to find the hills around it (Horizon).
- **Sky pictures** (CDS Strasbourg) and **the Moon's picture** (NASA): the position of a target or the time, never you.
- **AuroraWatch UK** (Lancaster University) or **NOAA's Space Weather Prediction Center**, only if you turn aurora alerts on: the app downloads the
  current aurora status. Nothing about you is sent; NOAA's file is a worldwide grid, and the app reads your site's cell from it on the device.
- **CelesTrak** and the **Minor Planet Center**: nothing about you is sent; the app downloads the space station's and
  comets' orbit data, no more than every two hours and daily.

None of these receives your name, an account or any identifier from Nightwatch. They receive your IP address as part of
any internet request, and their own privacy policies apply.

## Photos

"Measure from a photo" reads one photo you choose, on the device, for the direction, lens and tilt it recorded. The photo
is not kept or sent anywhere; only the height you set is saved. Nightwatch does not ask for access to your photo library:
you pick the photo with the system's own picker.

## The home-screen widget

The widget shows the same answer as the app. The app hands it tonight's answer through an App Group shared only with the
widget on the same device. The widget fetches nothing.

## Permissions

- **Location** is asked for only when you press the button for it. You can refuse and type a place name instead.
- **Notifications** are asked for after the app has shown tonight's answer and said what the alerts are for. They are
  used only for Nightwatch's own alerts, and never during your quiet hours.

## Keeping, deleting and changing your mind

- The developer holds no data about you, so there is nothing for the developer to keep, hand over or delete.
- Delete the app to remove what it keeps on the device. Your settings stay in your iCloud account for your other devices;
  remove them with Reset in the Mac app, or in iPhone Settings › [your name] › iCloud › Manage Account Storage.
- To stop Nightwatch using your location or sending alerts, change it in iOS Settings › Nightwatch.

## Children

Nightwatch collects no personal data from anyone, including children.

## Changes and contact

Changes are published with the date above. Questions: GitHub Discussions or an issue on the app's public repository.
