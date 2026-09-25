import Testing
import Foundation
@testable import SkyCore

private let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)

/// An Home November night (GMT, so UTC is local) with the given hourly cloud from 17:00.
private func plan(_ cloud: [Int]) throws -> NightPlan {
    let night = try Ephemeris.night(localDate: utc(2026, 11, 20, 12, 0), site: testSite)
    let t0 = utc(2026, 11, 20, 17, 0)
    let hours = cloud.enumerated().map { i, c in
        HourlyConditions(time: t0.addingTimeInterval(Double(i) * 3600), cloudTotal: c, cloudLow: nil, cloudMid: nil, cloudHigh: nil,
                         tempC: nil, dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)
    }
    return Planner.plan(night: night, forecast: Forecast(fetchedAt: t0, latitude: testSite.latitude, longitude: testSite.longitude, hours: hours, seeingSource: nil),
                        catalog: Catalog(objects: []), constellations: [], site: testSite, fov: FieldOfView(widthDeg: 2.1, heightDeg: 1.2), rule: GoRule())
}
private let clearMiddle = [90, 90, 90, 10, 10, 10, 10, 10, 10, 90, 90, 90, 90, 90, 90]   // clear 20:00–02:00

@Test func clearSkyBarsMatchTheOldRule() throws {
    let p = try plan(clearMiddle)
    let bars = Planner.clearSkyBars(plan: p, site: testSite)
    #expect(bars.count == p.darkHours.count)
    for (b, h) in zip(bars, p.darkHours) {
        #expect(b.lit == p.windows.contains { $0.overlapsHour(startingAt: h.time) })
        #expect(b.clearPct == max(0, min(100, 100 - h.cloudTotal)))
        #expect(b.hour == String(Copy.hhmm(h.time, site: testSite).prefix(2)))
    }
    #expect(bars.filter(\.peak).count == 1)
    #expect(bars.first(where: \.peak)?.hour == "20")   // the first of the clearest hours, as before
    #expect(Planner.clearSkyBars(plan: try plan(Array(repeating: 100, count: 15)), site: testSite).allSatisfy { !$0.peak })   // 0 % clear: no peak label
}

@Test func barsLabelSentence() throws {
    #expect(Copy.barsLabel(plan: try plan(clearMiddle), site: testSite) == "Clear sky by hour. Clearest 20:00 at 90% clear. Clear window 20:00 to 02:00.")
}

@Test func noWindowReasonMatchesThePopover() throws {
    let p = try plan([90, 90, 90, 10, 10, 90, 10, 10, 90, 90, 90, 90, 90, 90, 90])   // two 2 h runs: no window
    #expect(p.primary == nil)
    let expected = Planner.noWindowReason(darkHours: p.darkHours, darkStart: p.night.darkStart!, darkEnd: p.night.darkEnd!, rule: GoRule(), site: testSite)
    #expect(Planner.noWindowReasonText(plan: p, rule: GoRule(), bright: BrightSettings(), site: testSite) == expected)
    #expect(expected != nil)
}
