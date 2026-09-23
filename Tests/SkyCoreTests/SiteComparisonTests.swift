import Testing
import Foundation
@testable import SkyCore

private func plan(score: Int, qualifies: Bool) -> NightPlan {
    let night = try! Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: Site(name: "S", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5))
    let w = qualifies ? ClearWindow(start: night.darkStart!, end: night.darkStart!.addingTimeInterval(4 * 3600)) : nil
    return NightPlan(night: night, windows: w.map { [$0] } ?? [], primary: w, score: score, qualifies: qualifies, moonIllumination: 0.3,
                     moonRise: nil, moonSet: nil, darkHours: [], targets: [], best: [], seeingAvailable: false)
}
private func site(_ id: String, km: Double) -> DarkSite {
    DarkSite(id: id, name: id, kind: "park", coordinate: Coordinate(latitude: 53, longitude: -2), distanceKm: km, bearingDeg: 0, band: .dark, bortle: nil, source: nil, isComputed: false)
}

@Test func bestAwayNeedsTwentyPointMargin() {
    let home = plan(score: 40, qualifies: false)
    let a = SitePlan(id: "a", site: site("a", km: 30), score: 59, primary: nil, qualifies: true, forecastMissing: false)
    let b = SitePlan(id: "b", site: site("b", km: 60), score: 60, primary: nil, qualifies: true, forecastMissing: false)
    #expect(SiteComparison.bestAway(home: home, sites: [a]) == nil)
    #expect(SiteComparison.bestAway(home: home, sites: [a, b])?.id == "b")
}

@Test func bestAwayIgnoresMissingForecastsAndNonQualifying() {
    let home = plan(score: 10, qualifies: false)
    let missing = SitePlan(id: "m", site: site("m", km: 10), score: 0, primary: nil, qualifies: false, forecastMissing: true)
    let noWindow = SitePlan(id: "n", site: site("n", km: 10), score: 70, primary: nil, qualifies: false, forecastMissing: false)
    #expect(SiteComparison.bestAway(home: home, sites: [missing, noWindow]) == nil)
}

@Test func sortedByScoreThenDistanceMissingLast() {
    let s = [SitePlan(id: "far", site: site("far", km: 90), score: 80, primary: nil, qualifies: true, forecastMissing: false),
             SitePlan(id: "near", site: site("near", km: 20), score: 80, primary: nil, qualifies: true, forecastMissing: false),
             SitePlan(id: "miss", site: site("miss", km: 5), score: 0, primary: nil, qualifies: false, forecastMissing: true),
             SitePlan(id: "low", site: site("low", km: 10), score: 30, primary: nil, qualifies: false, forecastMissing: false)]
    #expect(SiteComparison.sorted(s).map(\.id) == ["near", "far", "low", "miss"])
}
