import Testing
import Foundation
@testable import SkyCore

private let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)

private func plan(up: Double?, rise: Date? = nil, set: Date? = nil) throws -> NightPlan {
    let night = try Ephemeris.night(localDate: utc(2026, 11, 20, 12, 0), site: testSite)
    return NightPlan(night: night, windows: [], primary: nil, score: 0, qualifies: false, moonIllumination: 0.5, moonRise: rise, moonSet: set,
                     darkHours: [], targets: [], best: [], seeingAvailable: false, moonUpFraction: up)
}

@Test func moonTonightCases() throws {
    let n = try Ephemeris.night(localDate: utc(2026, 11, 20, 12, 0), site: testSite)
    let inside = n.darkStart!.addingTimeInterval(3600)
    #expect(Planner.moonTonight(try plan(up: 0)) == .down)
    #expect(Planner.moonTonight(try plan(up: 0.5, set: inside)) == .sets(inside))
    #expect(Planner.moonTonight(try plan(up: 0.5, rise: inside)) == .rises(inside))
    #expect(Planner.moonTonight(try plan(up: 1, rise: n.sunset.addingTimeInterval(-86_400), set: n.sunrise.addingTimeInterval(3600))) == .upAllNight)
    #expect(Planner.moonTonight(try plan(up: nil)) == nil)
    #expect(Copy.moonText(.sets(inside), site: testSite) == "Sets \(Copy.hhmm(inside, site: testSite))")
}

@Test func planRecordsTheMoonsShareOfDarkness() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 11, 20, 12, 0), site: testSite)
    let p = Planner.plan(night: night, forecast: Forecast(fetchedAt: night.sunset, latitude: testSite.latitude, longitude: testSite.longitude, hours: [], seeingSource: nil),
                         catalog: Catalog(objects: []), constellations: [], site: testSite, fov: FieldOfView(widthDeg: 2.1, heightDeg: 1.2), rule: GoRule())
    let f = try #require(p.moonUpFraction)
    #expect(f >= 0 && f <= 1)
}

@Test func anHourOverlappingAClippedWindowIsLit() {
    // Darkness from 18:37 clips the window to 18:37; the clear 18:00 hour's midpoint (18:30) is outside it, but the hour is clear.
    let w = ClearWindow(start: utc(2026, 11, 20, 18, 37), end: utc(2026, 11, 20, 22, 20))
    #expect(w.overlapsHour(startingAt: utc(2026, 11, 20, 18, 0)))
    #expect(w.overlapsHour(startingAt: utc(2026, 11, 20, 22, 0)))
    #expect(!w.overlapsHour(startingAt: utc(2026, 11, 20, 17, 0)))
    #expect(!w.overlapsHour(startingAt: utc(2026, 11, 20, 22, 20)))
}

@Test func aMoonriseAfterTheLastHourlySampleStillCounts() throws {
    // Sampled hourly, the Moon can read 0% up yet rise before darkness ends: the event wins over the sampled share.
    let n = try Ephemeris.night(localDate: utc(2026, 11, 20, 12, 0), site: testSite)
    let late = n.darkEnd!.addingTimeInterval(-600)
    #expect(Planner.moonTonight(try plan(up: 0, rise: late)) == .rises(late))
}
