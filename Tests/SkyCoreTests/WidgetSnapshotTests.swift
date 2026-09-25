import Testing
import Foundation
@testable import SkyCore

private let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
private let copy = Copy(flavour: .watch)

private func hours(from t0: Date, _ cloud: [Int]) -> [HourlyConditions] {
    cloud.enumerated().map { i, c in
        HourlyConditions(time: t0.addingTimeInterval(Double(i) * 3600), cloudTotal: c, cloudLow: nil, cloudMid: nil, cloudHigh: nil,
                         tempC: nil, dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)
    }
}
/// Plans for an Home night from `day` (12:00 UTC), hourly cloud from 17:00 UTC that day.
private func plans(_ day: Date, _ cloud: [Int], bright: Bool = false) throws -> (NightPlan, NightPlan) {
    let night = try Ephemeris.night(localDate: day, site: testSite)
    let next = try Ephemeris.night(localDate: day.addingTimeInterval(86_400), site: testSite)
    let fc = Forecast(fetchedAt: day, latitude: testSite.latitude, longitude: testSite.longitude,
                      hours: hours(from: day.addingTimeInterval(5 * 3600), cloud + cloud), seeingSource: nil)
    var b = BrightSettings(); b.enabled = bright
    func p(_ n: Night) -> NightPlan {
        Planner.plan(night: n, forecast: fc, catalog: Catalog(objects: []), constellations: [], site: testSite,
                     fov: FieldOfView(widthDeg: 2.1, heightDeg: 1.2), rule: GoRule(), bright: b)
    }
    return (p(night), p(next))
}
private func snap(_ p: NightPlan, _ t: NightPlan?, fetchedAt: Date = Date()) -> WidgetSnapshot {
    WidgetSnapshot.make(plan: p, tomorrow: t, fetchedAt: fetchedAt, site: testSite, rule: GoRule(), bright: BrightSettings(), alerts: AlertSettings(), copy: copy)
}
private let november = utc(2026, 11, 20, 12, 0)
private let clearMiddle = [90, 90, 90, 10, 10, 10, 10, 10, 10, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90, 90]

@Test func snapshotForAClearNight() throws {
    let (p, t) = try plans(november, clearMiddle)
    let s = snap(p, t)
    #expect(s.headline == "Clear window tonight")
    #expect(s.window == "20:00 → 02:00 · 6.0 h" && s.windowShort == "Clear 20:00–02:00")
    #expect(s.slots.count == 60 && !s.bars.isEmpty && s.notify == "Notify at 19:30")
    #expect(s.targets.count <= 3 && s.siteName == "Test site" && s.tomorrow == nil)
}

@Test func snapshotForNoWindow() throws {
    let cloudy = Array(repeating: 90, count: 24)
    let (p, t) = try plans(november, cloudy)
    #expect(p.primary == nil)
    let s = snap(p, t)
    #expect(s.headline == copy.noWindow && s.window == nil && s.reasonWarns == false)
    #expect(s.reason == Planner.noWindowReasonText(plan: p, rule: GoRule(), bright: BrightSettings(), site: testSite))
    #expect(s.tomorrow == nil)                                                    // tomorrow is cloudy too
    let (clearTomorrow, _) = try plans(november.addingTimeInterval(86_400), clearMiddle)
    #expect(snap(p, clearTomorrow).tomorrow == "Tomorrow 20:00–02:00")
}

@Test func snapshotWithNoDarkness() throws {
    let (p, t) = try plans(utc(2026, 6, 21, 12, 0), Array(repeating: 5, count: 24))
    #expect(!p.night.hasDarkness)
    let s = snap(p, t)
    #expect(s.headline == "No astronomical darkness")
    #expect(s.window == nil && s.bars.isEmpty && s.slots.allSatisfy { $0 == .daylight })
    // The popover never shows a Tomorrow line under "No astronomical darkness", even when tomorrow has a window.
    let (clearTomorrow, _) = try plans(november.addingTimeInterval(86_400), clearMiddle)
    #expect(snap(p, clearTomorrow).tomorrow == nil)
}

@Test func snapshotForABrightNight() throws {
    let (p, t) = try plans(utc(2026, 7, 30, 12, 0), Array(repeating: 5, count: 24), bright: true)
    #expect(p.mode == .bright && p.primary != nil)
    let s = snap(p, t)
    #expect(s.headline == "Bright night: Moon and planets")
    #expect(s.windowShort?.hasPrefix("Bright ") == true)
    #expect(s.targets.map(\.id) == Array(p.brightTargets.prefix(3)).map(\.id))
}

@Test func snapshotCarriesAgreement() throws {
    var (p, t) = try plans(november, clearMiddle)
    p.agreement = .cloudFrom(utc(2026, 11, 21, 0, 0))
    let s = snap(p, t)
    #expect(s.agreement == "Open-Meteo sees cloud from 00:00" && s.agreementWarns)
}

@Test func snapshotStaleText() throws {
    let (p, t) = try plans(november, clearMiddle)
    let s = snap(p, t, fetchedAt: november)
    #expect(s.staleText(now: november.addingTimeInterval(5 * 3600)) == nil)
    #expect(s.staleText(now: november.addingTimeInterval(7 * 3600 + 1200)) == "Forecast 7 h old")
}

@Test func snapshotRoundTrips() throws {
    let (p, t) = try plans(november, clearMiddle)
    let s = snap(p, t, fetchedAt: november)
    let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
    let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
    #expect(try d.decode(WidgetSnapshot.self, from: e.encode(s)) == s)
}
