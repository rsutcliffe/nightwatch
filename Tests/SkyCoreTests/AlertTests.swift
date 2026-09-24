import Testing
import Foundation
@testable import SkyCore

private let site = Site(name: "Sheffield", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
private let copy = Copy(flavour: .watch)
private let settings = AlertSettings()

/// Build a plan by hand with a given window and qualifying flag.
private func plan(night: Night, window: ClearWindow?) -> NightPlan {
    NightPlan(night: night, windows: window.map { [$0] } ?? [], primary: window, score: window == nil ? 10 : 80, qualifies: window != nil,
              moonIllumination: 0.3, moonRise: nil, moonSet: nil, darkHours: [], targets: [], best: [], seeingAvailable: false)
}

private func fixtures() throws -> (Night, NightPlan, NightPlan, NightPlan) {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: site)
    let window = ClearWindow(start: night.darkStart!.addingTimeInterval(3600), end: night.darkStart!.addingTimeInterval(5 * 3600))
    let good = plan(night: night, window: window)
    let bad = plan(night: night, window: nil)
    let tomorrowNight = try Ephemeris.night(localDate: utc(2026, 9, 24, 12, 0), site: site)
    let tomorrowGood = plan(night: tomorrowNight, window: ClearWindow(start: tomorrowNight.darkStart!, end: tomorrowNight.darkStart!.addingTimeInterval(4 * 3600)))
    return (night, good, bad, tomorrowGood)
}

@Test func headsUpFiresOneHourBeforeSunsetOnly() throws {
    let (night, good, _, _) = try fixtures()
    let early = night.sunset.addingTimeInterval(-2 * 3600)
    let r0 = AlertEngine.step(now: early, tonight: good, tomorrow: nil, state: nil, settings: settings, forecastFetchedAt: early, site: site, copy: copy)
    #expect(r0.notification == nil && r0.state.stage == .idle)
    let due = night.sunset.addingTimeInterval(-3600 + 60)
    let r1 = AlertEngine.step(now: due, tonight: good, tomorrow: nil, state: r0.state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r1.notification?.kind == .headsUp)
    #expect(r1.state.stage == .headsUpSent)
    let r2 = AlertEngine.step(now: due.addingTimeInterval(600), tonight: good, tomorrow: nil, state: r1.state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r2.notification == nil)   // idempotent
}

@Test func goFiresThirtyMinutesBeforeWindow() throws {
    let (_, good, _, _) = try fixtures()
    let state = AlertState(nightKey: good.night.key, stage: .headsUpSent)
    let tooEarly = good.primary!.start.addingTimeInterval(-45 * 60)
    #expect(AlertEngine.step(now: tooEarly, tonight: good, tomorrow: nil, state: state, settings: settings, forecastFetchedAt: tooEarly, site: site, copy: copy).notification == nil)
    let due = good.primary!.start.addingTimeInterval(-29 * 60)
    let r = AlertEngine.step(now: due, tonight: good, tomorrow: nil, state: state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r.notification?.kind == .go)
    #expect(r.state.stage == .goSent)
    #expect(r.notification!.title.hasPrefix("All's well"))
}

@Test func cancelAfterHeadsUpWhenForecastDrops() throws {
    let (_, _, bad, _) = try fixtures()
    let state = AlertState(nightKey: bad.night.key, stage: .headsUpSent)
    let now = bad.night.sunset
    let r = AlertEngine.step(now: now, tonight: bad, tomorrow: nil, state: state, settings: settings, forecastFetchedAt: now, site: site, copy: copy)
    #expect(r.notification?.kind == .cancel)
    #expect(r.state.stage == .cancelled)
    #expect(r.notification!.title.hasPrefix("Stand down"))
}

@Test func tomorrowPreviewWhenTonightFails() throws {
    let (night, _, bad, tomorrowGood) = try fixtures()
    let due = night.sunset.addingTimeInterval(-3000)
    let r = AlertEngine.step(now: due, tonight: bad, tomorrow: tomorrowGood, state: nil, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r.notification?.kind == .tomorrowPreview)
    #expect(r.state.stage == .previewSent)
    let again = AlertEngine.step(now: due.addingTimeInterval(600), tonight: bad, tomorrow: tomorrowGood, state: r.state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(again.notification == nil && again.state.stage == .previewSent)   // never resent
}

@Test func quietHoursDropButAdvance() throws {
    let (_, good, _, _) = try fixtures()
    // 02:00 local on the 24th is inside 00:00–07:00
    let cal = site.calendar
    let two = cal.date(bySettingHour: 2, minute: 0, second: 0, of: cal.date(byAdding: .day, value: 1, to: good.night.localDate)!)!
    let late = plan(night: good.night, window: ClearWindow(start: two.addingTimeInterval(1200), end: two.addingTimeInterval(4 * 3600)))
    let state = AlertState(nightKey: late.night.key, stage: .headsUpSent)
    let r = AlertEngine.step(now: two, tonight: late, tomorrow: nil, state: state, settings: settings, forecastFetchedAt: two, site: site, copy: copy)
    #expect(r.notification == nil)
    #expect(r.state.stage == .goSent)
    #expect(AlertEngine.inQuietHours(two, site: site, settings: settings))
}

@Test func staleForecastSendsNothing() throws {
    let (night, good, _, _) = try fixtures()
    let due = night.sunset.addingTimeInterval(-3000)
    let r = AlertEngine.step(now: due, tonight: good, tomorrow: nil, state: nil, settings: settings, forecastFetchedAt: due.addingTimeInterval(-7 * 3600), site: site, copy: copy)
    #expect(r.notification == nil && r.state.stage == .idle)
}

@Test func newNightResetsState() throws {
    let (night, good, _, _) = try fixtures()
    let stale = AlertState(nightKey: "2026-09-22", stage: .done)
    let due = night.sunset.addingTimeInterval(-3000)
    let r = AlertEngine.step(now: due, tonight: good, tomorrow: nil, state: stale, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r.state.nightKey == "2026-09-23")
    #expect(r.notification?.kind == .headsUp)
}

@Test func plainFlavourHasNoWatchPhrases() {
    let c = Copy(flavour: .plain)
    #expect(c.refresh == "Refresh")
    #expect(c.noWindow == "No clear window tonight.")
    #expect(!c.cancelTitle.contains("Stand down"))
}

@Test func cancelledRecoversToGoWhenForecastClears() throws {
    let (_, good, _, _) = try fixtures()
    let state = AlertState(nightKey: good.night.key, stage: .cancelled)
    let due = good.primary!.start.addingTimeInterval(-20 * 60)
    let r = AlertEngine.step(now: due, tonight: good, tomorrow: nil, state: state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r.notification?.kind == .go)
    #expect(r.state.stage == .goSent)
}

@Test func goSentFinishesAtSunriseWhenDowngradedWithoutCancel() throws {
    let (night, _, bad, _) = try fixtures()
    var noCancel = settings
    noCancel.cancelOnDowngrade = false
    let state = AlertState(nightKey: bad.night.key, stage: .goSent)

    let afterSunrise = night.sunrise.addingTimeInterval(60)
    let r1 = AlertEngine.step(now: afterSunrise, tonight: bad, tomorrow: nil, state: state, settings: noCancel, forecastFetchedAt: afterSunrise, site: site, copy: copy)
    #expect(r1.notification == nil)
    #expect(r1.state.stage == .done)

    let stillInWindow = night.sunset.addingTimeInterval(2 * 3600)
    let r2 = AlertEngine.step(now: stillInWindow, tonight: bad, tomorrow: nil, state: state, settings: noCancel, forecastFetchedAt: stillInWindow, site: site, copy: copy)
    #expect(r2.state.stage == .goSent)
}

@Test func lateClearanceAfterSunsetFiresGo() throws {
    let (night, _, bad, _) = try fixtures()
    let r0 = AlertEngine.step(now: night.sunset, tonight: bad, tomorrow: nil, state: nil, settings: settings, forecastFetchedAt: night.sunset, site: site, copy: copy)
    #expect(r0.notification == nil)
    #expect(r0.state.stage == .idle)

    let now = night.sunset.addingTimeInterval(3600)
    let late = plan(night: night, window: ClearWindow(start: now.addingTimeInterval(20 * 60), end: now.addingTimeInterval(5 * 3600)))
    let r1 = AlertEngine.step(now: now, tonight: late, tomorrow: nil, state: r0.state, settings: settings, forecastFetchedAt: now, site: site, copy: copy)
    #expect(r1.notification?.kind == .go)
    #expect(r1.state.stage == .goSent)
}

@Test func lateClearanceAfterPreviewFiresGo() throws {
    let (_, good, _, tomorrowGood) = try fixtures()
    let state = AlertState(nightKey: good.night.key, stage: .previewSent)
    let due = good.primary!.start.addingTimeInterval(-20 * 60)
    let r1 = AlertEngine.step(now: due, tonight: good, tomorrow: tomorrowGood, state: state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r1.notification?.kind == .go)
    #expect(r1.state.stage == .goSent)
    let r2 = AlertEngine.step(now: due, tonight: good, tomorrow: tomorrowGood, state: r1.state, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(r2.notification == nil)
}

// MARK: - v0.3 bright nights

private func brightTarget(_ id: String, _ name: String, _ subtitle: String, alt: Double) -> RankedTarget {
    RankedTarget(id: id, name: name, subtitle: subtitle, group: .planets, raHours: 0, decDeg: 0, sizeArcmin: nil, magnitude: nil,
                 fit: .small, peakAltDeg: alt, peakTime: Date(timeIntervalSince1970: 0), moonSepDeg: 0, moonWashed: false, visibleFraction: 1)
}
private func bright(_ p: NightPlan) -> NightPlan {
    var b = p
    b.mode = .bright
    b.brightTargets = [brightTarget("moon", "Moon", "62% illuminated", alt: 22), brightTarget("planet-saturn", "Saturn", "Planet", alt: 18)]
    return b
}

@Test func brightListNamesTheMoonWithItsPhase() {
    #expect(Copy.brightList(bright(NightPlan(night: Night(key: "k", localDate: Date(), sunset: Date(), sunrise: Date(), darkStart: nil, darkEnd: nil),
                                             windows: [], primary: nil, score: 0, qualifies: false, moonIllumination: 0, moonRise: nil, moonSet: nil,
                                             darkHours: [], targets: [], best: [], seeingAvailable: false)).brightTargets) == "Moon 62%, Saturn")
}

@Test func brightHeadsUpGoAndPreviewUseBrightWording() throws {
    let (night, good, bad, tomorrowGood) = try fixtures()
    let tonight = bright(good)
    let due = night.sunset.addingTimeInterval(-3600 + 60)
    let heads = AlertEngine.step(now: due, tonight: tonight, tomorrow: nil, state: nil, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    let h = try #require(heads.notification)
    #expect(h.kind == .headsUp)
    #expect(h.title == "Bright night tonight from \(Copy.hhmm(tonight.primary!.start, site: site)) · Moon 62%, Saturn")
    #expect(h.body == "Moon 62%, Saturn well placed.")

    let goAt = tonight.primary!.start.addingTimeInterval(-Double(settings.preWindowMinutes) * 60 + 60)
    let go = AlertEngine.step(now: goAt, tonight: tonight, tomorrow: nil, state: heads.state, settings: settings, forecastFetchedAt: goAt, site: site, copy: copy)
    #expect(go.notification?.title == "Bright night. Clear from \(Copy.hhmm(tonight.primary!.start, site: site))")

    let preview = AlertEngine.step(now: due, tonight: bad, tomorrow: bright(tomorrowGood), state: nil, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(preview.notification?.title == String(format: "Tomorrow looks bright and clear · %.1f h", tomorrowGood.primary!.hours))
    // Same words in plain mode: no new Discworld copy for bright nights.
    #expect(Copy(flavour: .plain).brightGoTitle(windowStart: "22:30") == copy.brightGoTitle(windowStart: "22:30"))
}

@Test func switchingBrightModeMidEveningDoesNotStandDown() throws {
    let (night, good, _, _) = try fixtures()
    let due = night.sunset.addingTimeInterval(-3600 + 60)
    let dark = AlertEngine.step(now: due, tonight: good, tomorrow: nil, state: nil, settings: settings, forecastFetchedAt: due, site: site, copy: copy)
    #expect(dark.state.stage == .headsUpSent && dark.state.mode == .dark)
    // The same night now planned in bright mode (the owner toggled Bright nights): no "Stand down", a fresh bright heads-up instead.
    let later = due.addingTimeInterval(600)
    let r = AlertEngine.step(now: later, tonight: bright(good), tomorrow: nil, state: dark.state, settings: settings, forecastFetchedAt: later, site: site, copy: copy)
    #expect(r.notification?.kind != .cancel)
    #expect(r.notification?.title.hasPrefix("Bright night tonight") == true)
}

@Test func aBrightPlanFromThePlannerDrivesTheHeadsUp() throws {
    // The seam: Planner.plan(bright:) straight into AlertEngine.step, no hand-built plan.
    let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let night = try Ephemeris.night(localDate: utc(2026, 7, 30, 12, 0), site: testSite)
    let t0 = utc(2026, 7, 30, 18, 0)
    let hours = (0..<14).map { HourlyConditions(time: t0.addingTimeInterval(Double($0) * 3600), cloudTotal: 5, cloudLow: nil, cloudMid: nil, cloudHigh: nil,
                                                 tempC: nil, dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil) }
    var b = BrightSettings(); b.enabled = true
    let plan = Planner.plan(night: night, forecast: Forecast(fetchedAt: t0, latitude: testSite.latitude, longitude: testSite.longitude, hours: hours, seeingSource: nil),
                            catalog: Catalog(objects: []), constellations: [], site: testSite, fov: FieldOfView(widthDeg: 2.1, heightDeg: 1.2), rule: GoRule(), bright: b)
    let due = night.sunset.addingTimeInterval(-3600 + 60)
    let r = AlertEngine.step(now: due, tonight: plan, tomorrow: nil, state: nil, settings: settings, forecastFetchedAt: due, site: testSite, copy: copy)
    #expect(plan.mode == .bright)
    #expect(r.notification?.title.hasPrefix("Bright night tonight from") == true)
    #expect(r.notification?.body.contains("Moon") == true)
}
