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
    #expect(r.state.stage == .done)
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
