# Releasing Nightwatch on the Mac App Store

The App Store version, **"Nightwatch: Clear Sky Alerts"**, is built from the same code as the download. The only
difference is that it has no update check, because the App Store updates it (rule 2.4.5(vii)). That switch is the one
`#if APPSTORE` in `Sources/Nightwatch/Distribution.swift`, and a test keeps it the only one. CI builds both on every pull
request.

The store build also carries no temporary sandbox exceptions: those exist in the download only to copy settings from
0.6, which a new App Store user never had.

## Before you start

`scripts/appstore.sh` builds the widget through the everyday build, so it needs what `scripts/build-app.sh` needs for a
signed build with the widget: Xcode, `xcodegen` (`brew install xcodegen`), and the Apple Development certificate and
development profile already on this Mac.

## One-off setup

Everything below is at [developer.apple.com](https://developer.apple.com/account) or
[App Store Connect](https://appstoreconnect.apple.com), signed in as the team R Sutcliffe (8B44CZ9923).

1. **Two certificates.** Certificates, Identifiers & Profiles › Certificates › **+**:
   - **Apple Distribution**, which signs the app;
   - **Mac Installer Distribution**, which signs the package.

   For each, make a certificate request in Keychain Access (Certificate Assistant › Request a Certificate From a
   Certificate Authority › Saved to disk), upload it, download the certificate and double-click it.

2. **The widget's identifier.** Identifiers › **+** › App IDs › App, platform macOS, bundle ID
   `io.github.rsutcliffe.nightwatch.widget`. The app's own identifier, `io.github.rsutcliffe.nightwatch`, already exists,
   with WeatherKit. The App Group the app and widget share, `8B44CZ9923.io.github.rsutcliffe.nightwatch`, begins with the
   team ID, so on macOS it needs no registration in the portal.

3. **Two provisioning profiles.** Profiles › **+** › Distribution › **Mac App Store Connect**, once for each identifier.
   Download both and copy each into `~/Library/Developer/Xcode/UserData/Provisioning Profiles/`, named by its UUID, as
   for the Developer ID profile in `releasing.md` (double-clicking installs them where the script can't read them).

4. **The app record.** App Store Connect › Apps › **+** › New App:
   - Platform: macOS
   - Name: **Nightwatch: Clear Sky Alerts**
   - Primary language: English (UK)
   - Bundle ID: `io.github.rsutcliffe.nightwatch`
   - SKU: `nightwatch`

5. **Transporter.** Install Apple's free [Transporter](https://apps.apple.com/app/transporter/id1450874784) app and sign
   in with your Apple Account.

## Each release

1. Release the download as usual (`releasing.md`). Every release raises the build number, which the App Store requires.
2. From the same tagged commit, run `scripts/appstore.sh`. It stops with a pointer to this page if anything from the setup
   is missing, and refuses to package a build that still has the update check or a sandbox exception.
3. `open -a Transporter build/appstore/Nightwatch-<version>.pkg`, then **Deliver**.
4. In App Store Connect, add the build to the version, then **Submit for Review**. Review usually takes a day or two.

## Listing text

Nothing here names Terry Pratchett, Discworld or the City Watch (rule 5.2.1). Telescope makers are described, not named,
in the name, subtitle and keywords.

- **Subtitle** (30 characters at most): Know when the sky is clear
- **Category:** Weather (secondary: Utilities)
- **Price:** Free
- **Age rating:** answer "None" throughout (4+)
- **Privacy policy URL:** https://github.com/rsutcliffe/nightwatch/blob/main/PRIVACY.md
- **Support URL:** https://github.com/rsutcliffe/nightwatch/discussions
- **Marketing URL:** https://delphi-dolphin.com/nightwatch
- **Keywords** (100 characters at most):
  `astronomy,astrophotography,telescope,stars,forecast,seeing,dark sky,aurora,moon,nebula,menu bar`

**Promotional text:**

> A quiet menu-bar app that tells you when tonight will be clear enough for a long imaging session, and what to point at.

**Description:**

> Nightwatch sits in your menu bar and watches the weather for you. When tonight looks clear for long enough, it sends a
> heads-up before sunset, then a nudge just before the clear spell begins. If the forecast turns, it tells you.
>
> Open it to see a sky score, the clear window, cloud by hour, darkness, the Moon, seeing, wind, dew risk and
> transparency, and the best targets for your telescope's field of view tonight.
>
> • Two forecasts compared: Apple Weather, with Open-Meteo as a second opinion, and 7Timer for seeing
> • Targets chosen for your field of view, with presets for popular smart telescopes and cameras
> • "How to shoot this" on every target: filter, exposure and frames for your telescope
> • Darker skies nearby, scored for tonight against home
> • Aurora alerts from AuroraWatch UK
> • Small, medium and large desktop widgets
>
> Free, with no accounts, no advertising and no tracking. Nightwatch is open source:
> github.com/rsutcliffe/nightwatch

## App privacy answers

Apple counts data as collected when it leaves the Mac and is kept longer than it takes to answer the request.
Nightwatch itself keeps nothing, but the forecast services receive coordinates, so declare them:

- **Data types:** Location › **Precise Location**. Open-Meteo receives the site to four decimal places, so it is precise
  by Apple's definition (three or more).
- **Purpose:** App Functionality only.
- **Linked to the user:** No.
- **Used for tracking:** No.

Nothing else is collected.

## Notes for App Review

> Nightwatch needs a place to forecast for. On first launch, choose "Use this Mac's location" (and Allow) or "Add a
> site…". The popover then shows tonight's forecast. Alerts only fire on nights that meet the go rule, so the fastest
> check is the popover and Settings; notifications can be seen by lowering Settings › Go rule › Clear for at least to
> 1 h on a partly clear night. The app uses no login.

## Screenshots

Mac screenshots are 16:10: 1280 × 800, 1440 × 900, 2560 × 1600 or 2880 × 1800 pixels, one to ten of them, PNG or JPEG
with no transparency. Use 2880 × 1800, and take them at Northumberland Dark Sky Park as for the README, never at home.
