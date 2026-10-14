# App Store submission notes (draft)

Submission waits for Apple's approval of the Mac app. Nothing here is entered anywhere yet.

## App Review notes (write these first, not after a rejection)

Nightwatch tells you whether tonight is worth observing the night sky, and alerts you. No account or sign-in is needed.

- **Apple Weather attribution.** Apple Weather's mark and its legal-attribution link are shown in the footer of the Tonight
  screen whenever Apple Weather supplied the forecast, and are kept on the device so they show without a connection. When
  Apple Weather is not the source, its mark is not shown and the footer names the service that is (Open-Meteo).
- **Location** is requested only when "Use this device's location" is pressed on the welcome screen. A place name can be
  typed instead.
- **Notifications** are requested after Tonight's answer has been shown and a card has explained the alerts; the system
  prompt appears only when "Turn on alerts" is pressed.
- **Background refresh** is used to read a fresh forecast and re-queue the alerts. iOS decides when it runs.
- **iCloud key-value storage** shares saved sites and alert settings with the developer's Mac app (the same identifier).
- **Red night mode** is a display palette for use at a telescope.
- **Maps and Apple Maps search** find a place when one is typed, suggest car parks and towns for the dark sites list, and draw a
  small map of each dark site.
- **Home-screen widget** (small and medium) shows tonight's answer. The app and the widget share it through an App Group
  (`group.io.github.rsutcliffe.nightwatch.phone`); the widget fetches nothing.
- **Photos:** "Measure from a photo" (in a site's Horizon) uses the system photo picker, so no photo-library permission is
  requested. The chosen photo is read on the device and not kept.
- **To see the app working:** open it, choose any place on the welcome screen, and Tonight's answer appears.

## Guideline pre-flight

Re-run the Mac app's table in `docs/app-store.md` of the Mac repository before submitting; it records each guideline
the Mac app was rejected on (including 5.2.5, the Apple Weather attribution).

## Still to decide or provide

- Store name (must differ from the Mac app's).
- App icon: the Mac app's Icon Composer file, copied to `App/Nightwatch.icon` and set to "shared" so iOS uses it (decided 13 Oct 2026). Check how it looks on the iPad home screen and in the store's 1024 size.
- Screenshots: iPhone 6.9-inch and iPad 13-inch sets, without the home location.
- App Store Connect record, App ID with WeatherKit and iCloud (created at first signed build).
