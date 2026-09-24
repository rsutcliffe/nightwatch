import Testing
import Foundation
@testable import SkyCore

private func hour(_ t0: Date, _ i: Int, cloud: Int, wind: Double? = nil, temp: Double? = nil, dew: Double? = nil, seeing: Int? = nil, transp: Int? = nil) -> HourlyConditions {
    HourlyConditions(time: t0.addingTimeInterval(Double(i) * 3600), cloudTotal: cloud, cloudLow: nil, cloudMid: nil, cloudHigh: nil,
                     tempC: temp, dewPointC: dew, humidityPct: nil, windKmh: wind, gustKmh: nil, visibilityM: nil, seeing: seeing, transparency: transp)
}

private let t0 = Date(timeIntervalSince1970: 1_790_000_000)   // any fixed instant
private let rule = GoRule()

@Test func oneClearWindowClippedToDarkness() {
    // darkness 20:30 -> 04:30 relative to t0 = 20:00
    let dark = (t0.addingTimeInterval(1800), t0.addingTimeInterval(8.5 * 3600))
    let hours = (0..<12).map { hour(t0, $0, cloud: $0 < 2 ? 80 : ($0 < 8 ? 10 : 90)) }   // clear 22:00–04:00
    let w = Planner.windows(hours: hours, darkStart: dark.0, darkEnd: dark.1, rule: rule)
    #expect(w.count == 1)
    #expect(w[0].start == t0.addingTimeInterval(2 * 3600))
    #expect(w[0].end == t0.addingTimeInterval(8 * 3600))
    #expect(w[0].hours == 6)
}

@Test func windowShorterThanRuleIsDropped() {
    let dark = (t0, t0.addingTimeInterval(10 * 3600))
    let hours = (0..<10).map { hour(t0, $0, cloud: (3...4).contains($0) ? 0 : 90) }   // 2 h clear
    #expect(Planner.windows(hours: hours, darkStart: dark.0, darkEnd: dark.1, rule: rule).isEmpty)
}

@Test func twoWindowsSortedLongestFirstByCaller() {
    let dark = (t0, t0.addingTimeInterval(12 * 3600))
    let hours = (0..<12).map { hour(t0, $0, cloud: ((0...2).contains($0) || (5...9).contains($0)) ? 5 : 95) }
    let w = Planner.windows(hours: hours, darkStart: dark.0, darkEnd: dark.1, rule: rule)
    #expect(w.count == 2)
    #expect(w.map(\.hours) == [3, 5])
}

@Test func windowCrossingMidnightIsContiguous() {
    // t0 = 22:00, darkness 22:00 -> 05:00; clear 23:00 -> 03:00 spans midnight
    let dark = (t0, t0.addingTimeInterval(7 * 3600))
    let hours = (0..<7).map { hour(t0, $0, cloud: (1...4).contains($0) ? 0 : 100) }
    let w = Planner.windows(hours: hours, darkStart: dark.0, darkEnd: dark.1, rule: rule)
    #expect(w.count == 1 && w[0].hours == 4)
}

@Test func cloudAtThresholdCounts() {
    let dark = (t0, t0.addingTimeInterval(4 * 3600))
    let hours = (0..<4).map { hour(t0, $0, cloud: 25) }
    #expect(Planner.windows(hours: hours, darkStart: dark.0, darkEnd: dark.1, rule: rule).count == 1)
}

@Test func scoreExtremes() {
    let dark = (t0, t0.addingTimeInterval(8 * 3600))
    let clear = (0..<8).map { hour(t0, $0, cloud: 0, wind: 5, temp: 10, dew: 2, seeing: 1, transp: 1) }
    let overcast = (0..<8).map { hour(t0, $0, cloud: 100, wind: 50, temp: 10, dew: 9.5) }
    let full = ScoreInputs(darkHours: clear, windows: [ClearWindow(start: dark.0, end: dark.1)], darkness: dark, moonIllumination: 0, moonAboveFraction: 0)
    let none = ScoreInputs(darkHours: overcast, windows: [], darkness: dark, moonIllumination: 1, moonAboveFraction: 1)
    #expect(Planner.score(full) == 100)
    #expect(Planner.score(none) == 0)
}

@Test func scoreWithoutSeeingRedistributesWeight() {
    let dark = (t0, t0.addingTimeInterval(8 * 3600))
    let clear = (0..<8).map { hour(t0, $0, cloud: 0, wind: 5, temp: 10, dew: 2) }
    let s = Planner.score(ScoreInputs(darkHours: clear, windows: [ClearWindow(start: dark.0, end: dark.1)], darkness: dark, moonIllumination: 0, moonAboveFraction: 0))
    #expect(s == 100)
}

@Test func fullMoonAllNightCostsFifteen() {
    let dark = (t0, t0.addingTimeInterval(8 * 3600))
    let clear = (0..<8).map { hour(t0, $0, cloud: 0, wind: 5, temp: 10, dew: 2, seeing: 1, transp: 1) }
    let s = Planner.score(ScoreInputs(darkHours: clear, windows: [ClearWindow(start: dark.0, end: dark.1)], darkness: dark, moonIllumination: 1, moonAboveFraction: 1))
    #expect(s == 85)
}

@Test func noDarknessScoresZero() {
    #expect(Planner.score(ScoreInputs(darkHours: [], windows: [], darkness: nil, moonIllumination: 0, moonAboveFraction: 0)) == 0)
}

@Test func maxCloudPctOverrideAffectsScore() {
    let dark = (t0, t0.addingTimeInterval(8 * 3600))
    let hazy = (0..<8).map { hour(t0, $0, cloud: 35) }
    let strictWindows = Planner.windows(hours: hazy, darkStart: dark.0, darkEnd: dark.1, rule: GoRule(maxCloudPct: 25))
    let looseWindows = Planner.windows(hours: hazy, darkStart: dark.0, darkEnd: dark.1, rule: GoRule(maxCloudPct: 40))
    #expect(strictWindows.isEmpty)   // 35% cloud fails the default 25% rule -> no window
    let strict = Planner.score(ScoreInputs(darkHours: hazy, windows: strictWindows, darkness: dark, moonIllumination: 0, moonAboveFraction: 0, maxCloudPct: 25))
    let loose = Planner.score(ScoreInputs(darkHours: hazy, windows: looseWindows, darkness: dark, moonIllumination: 0, moonAboveFraction: 0, maxCloudPct: 40))
    #expect(strict == 25)   // 0 clear hours -> cloud component 0; moon(15) + baseline(10) still apply
    #expect(loose == 100)   // all 8 hours clear and contiguous under the 40% rule
    #expect(loose - strict >= 75)
}

private func reasonHours(_ clouds: [Int], from t0: Date) -> [HourlyConditions] {
    clouds.enumerated().map { i, c in HourlyConditions(time: t0.addingTimeInterval(Double(i) * 3600), cloudTotal: c, cloudLow: nil, cloudMid: nil, cloudHigh: nil,
                                                       tempC: nil, dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil) }
}

@Test func noWindowReasonExplainsShortDarkness() {
    let site = Site(name: "S", latitude: 53.9, longitude: -1.7, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let t0 = utc(2026, 6, 20, 23, 0)
    let r = Planner.noWindowReason(darkHours: reasonHours([0, 0], from: t0), darkStart: t0, darkEnd: t0.addingTimeInterval(2 * 3600), rule: GoRule(), site: site)
    #expect(r == "Only 2.0 h of darkness; the rule needs 3 h.")
}

@Test func noWindowReasonExplainsCloudNeverBelowLimit() {
    let site = Site(name: "S", latitude: 53.9, longitude: -1.7, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let t0 = utc(2026, 9, 24, 21, 0)
    let r = Planner.noWindowReason(darkHours: reasonHours([90, 60, 75, 100, 80, 95, 70, 88], from: t0), darkStart: t0, darkEnd: t0.addingTimeInterval(8 * 3600), rule: GoRule(), site: site)
    #expect(r == "Cloud never below 60% during darkness; the rule allows 25%.")
}

@Test func noWindowReasonExplainsShortClearRun() {
    let site = Site(name: "S", latitude: 53.9, longitude: -1.7, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let t0 = utc(2026, 9, 24, 21, 0)   // 22:00 BST
    // clear at 23:00 and 00:00 UTC only: a 2-hour run starting 00:00 BST
    let r = Planner.noWindowReason(darkHours: reasonHours([90, 10, 20, 80, 10, 95, 70, 88], from: t0), darkStart: t0, darkEnd: t0.addingTimeInterval(8 * 3600), rule: GoRule(), site: site)
    #expect(r == "Longest clear run is 2 h from 23:00; the rule needs 3 h.")
}
