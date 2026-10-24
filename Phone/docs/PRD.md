# Nightwatch for iPhone and iPad: product requirements

Working name. The store name must differ from the Mac app's and is decided later.

## One line

A free iPhone and iPad companion to the Nightwatch Mac app: it tells you, in five seconds, whether tonight is worth setting
up the telescope, and speaks up on your phone when it is.

## Why

The go or no-go decision is acted on outdoors, with a phone, but Nightwatch speaks only on the Mac, and Mac notifications
do not reach an iPhone (issue #58 in the Mac repository).

## Who

Owners of smart telescopes and cameras who observe from a garden, a balcony or a dark site. In the field they usually have
a cellular iPad, or an iPhone with data tethered to it, so a connection is likely but not guaranteed.

## Product principles

- **A five-second answer.** The verdict first, the reasons under it, specialist terms kept and explained.
- **Honest.** "No clear window tonight" is a good answer. A forecast that is old says how old.
- **The Mac's words and design.** Same verdict wording, sky-score bezel, clear-sky bars, dark palette. One source of truth for
  the sky maths: SkyCore, from the Mac repository.
- **Connected first, offline as the fallback.** Refresh when opened if the forecast is over 30 minutes old. Frugal with data:
  optional downloads wait for a cheap connection (not cellular, not Personal Hotspot, not Low Data Mode).
- **No glare.** A red night mode that keeps dark adaptation. The Apple Weather mark is never recoloured.
- **Free, no account, no paywall, no tracking.** The data terms require it to stay non-commercial.

## Version 1: the smallest closed loop

Open the app, see tonight's answer for your saved site, optionally change site, and be alerted by notification. Nothing a
person can get lost in.

1. First run, at most three screens: what it does; where you observe from (sites arrive from the Mac through iCloud, else
   "Use this iPhone's location" or add a site by name); notifications, asked for after the verdict is shown.
2. Tonight: score bezel, headline, clear window, clear-sky bars, six tiles (Dark, Moon, Seeing, Wind, Dew risk or Frost
   likely, Transparency), the best three targets, the source footer with Apple Weather's mark and legal link.
3. Sites and a small Settings: alerts on or off, quiet hours, red night mode, the go rule read-only from the Mac.
4. Alerts: heads-up an hour before sunset, nudge before the window, cancel notice. Local notifications queued from the
   latest forecast by SkyCore's alert engine, rebuilt at every refresh. Background refresh is best-effort; nothing is queued
   from a forecast more than six hours old at the moment it would fire.

## Not in version 1, on purpose

Targets list and detail, Tonight's plan, the week ahead, favourites, dark sites, events, horizon editing, Siri and Shortcuts,
widgets (likeliest v1.1), Apple Watch (decided: no). Order after v1: week ahead, then favourites and Tonight's plan once the
Mac's 1.7.0 ships, then dark sites and events.

## Decisions made

Own repository and App Store record; SkyCore pinned by revision; iOS 17 and later; build now, submit only after Apple
approves the Mac app; no change to the Mac repository except the two-line change that lets SkyCore build for iOS.

## Open, to settle before release

The store name; the iCloud key-value sharing with the Mac app, to be proved on real devices; Apple's attribution wording for
the mark in red mode; the background-refresh cadence in practice; privacy text, drafted in this repository and not in the
Mac repository's PRIVACY.md until the Mac app is approved.
