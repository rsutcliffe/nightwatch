import Testing
import Foundation
@testable import SkyCore

private let sheffieldSite = Site(name: "Sheffield", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
private let dwarfMini = FieldOfView(widthDeg: 2.1, heightDeg: 1.2)

@Test func frameFitThresholds() {
    #expect(Planner.frameFit(sizeArcmin: 3, fov: dwarfMini) == .small)
    #expect(Planner.frameFit(sizeArcmin: 60, fov: dwarfMini) == .fits)
    #expect(Planner.frameFit(sizeArcmin: 178, fov: dwarfMini) == .mosaic)   // M31 at 2.97 degrees
    #expect(Planner.frameFit(sizeArcmin: 500, fov: dwarfMini) == .mosaic)
    #expect(Planner.frameFit(sizeArcmin: nil, fov: dwarfMini) == .small)
}

@Test func ranksNorthAmericaNebulaOnASeptemberNight() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: sheffieldSite)
    let window = ClearWindow(start: night.darkStart!, end: night.darkStart!.addingTimeInterval(4 * 3600))
    let cat = try Catalog.bundled()
    let cons = try Constellations.bundled()
    let ranked = Planner.rank(catalog: cat, constellations: cons, window: window, site: sheffieldSite, fov: dwarfMini, rule: GoRule())
    let nan = try #require(ranked.first { $0.id == "NGC7000" })
    #expect(nan.group == .nebulae)
    #expect(nan.peakAltDeg > 60)
    #expect(nan.fit == .fits)
    #expect(ranked.contains { $0.group == .planets })
    #expect(ranked.contains { $0.group == .constellations && $0.id == "Cyg" })
    #expect(!ranked.contains { $0.id == "NGC1976" })   // Orion is below 30 degrees in that window
    let nebulae = ranked.filter { $0.group == .nebulae }
    #expect(nebulae.count > 3)
    #expect(nebulae.allSatisfy { $0.visibleFraction >= 0.5 })
    // No magnitude in OpenNGC, still ranked. IC1396 is typed Cl+N, which the catalogue groups as a cluster.
    #expect(ranked.contains { $0.id == "IC1396" && $0.group == .clusters && $0.magnitude == nil && $0.peakAltDeg > 30 })
    #expect(nebulae.contains { $0.id == "NGC0281" && $0.magnitude == nil && $0.peakAltDeg > 30 })   // Pacman Nebula
    #expect(!ranked.contains { $0.group == .galaxies && $0.magnitude == nil })
}

@Test func planQualifiesWhenForecastIsClear() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: sheffieldSite)
    let start = night.sunset.addingTimeInterval(-3600)
    let hours = (0..<14).map { i in
        HourlyConditions(time: start.addingTimeInterval(Double(i) * 3600), cloudTotal: 5, cloudLow: 0, cloudMid: 0, cloudHigh: 5,
                         tempC: 10, dewPointC: 3, humidityPct: 60, windKmh: 8, gustKmh: 15, visibilityM: 20000, seeing: 3, transparency: 3)
    }
    let fc = Forecast(fetchedAt: start, latitude: 53.38, longitude: -1.47, hours: hours, seeingSource: "7Timer")
    let plan = Planner.plan(night: night, forecast: fc, catalog: try Catalog.bundled(), constellations: try Constellations.bundled(),
                            site: sheffieldSite, fov: dwarfMini, rule: GoRule())
    #expect(plan.qualifies)
    #expect(plan.primary != nil)
    #expect(plan.score >= 70)
    #expect(plan.best.count == 3)
    #expect(Set(plan.best.map(\.group)).count == 3)
    #expect(plan.seeingAvailable)
}

@Test func planDoesNotQualifyWhenOvercast() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: sheffieldSite)
    let start = night.sunset.addingTimeInterval(-3600)
    let hours = (0..<14).map { i in
        HourlyConditions(time: start.addingTimeInterval(Double(i) * 3600), cloudTotal: 90, cloudLow: 90, cloudMid: nil, cloudHigh: nil,
                         tempC: nil, dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)
    }
    let fc = Forecast(fetchedAt: start, latitude: 53.38, longitude: -1.47, hours: hours, seeingSource: nil)
    let plan = Planner.plan(night: night, forecast: fc, catalog: Catalog(objects: []), constellations: [], site: sheffieldSite, fov: dwarfMini, rule: GoRule())
    #expect(!plan.qualifies)
    #expect(plan.primary == nil)
    // No clear window: nothing is "best", but the browser still ranks what is up during darkness
    // (the catalogue is empty here, so only the Moon and planets can appear; the 91 % Moon is up that evening).
    #expect(plan.best.isEmpty)
    #expect(plan.targets.contains { $0.id == "moon" })
    #expect(plan.score < 30)
}

@Test func viewabilityIsClippedToTheWindowAndSampled() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: sheffieldSite)
    let window = ClearWindow(start: night.darkStart!, end: night.darkStart!.addingTimeInterval(4 * 3600))
    let ranked = Planner.rank(catalog: try Catalog.bundled(), constellations: try Constellations.bundled(), window: window, site: sheffieldSite, fov: dwarfMini, rule: GoRule())
    for t in ranked {
        let v = try #require(t.viewable)
        #expect(v.start >= window.start && v.end <= window.end && v.start <= v.end)
        #expect(t.altitudeSamples.count == 9)
        #expect(!t.catalogueID.isEmpty && !t.typeName.isEmpty)
    }
    let nan = try #require(ranked.first { $0.id == "NGC7000" })
    #expect(abs((nan.altitudeSamples.max() ?? 0) - nan.peakAltDeg) < 1)
    #expect(nan.catalogueID == "NGC 7000" && nan.commonName == "North America Nebula" && nan.typeName == "Emission nebula")
    #expect(ranked.contains { $0.viewable!.end < window.end })   // something sets during the window
}

@Test func frameFillAgainstTheLongerSide() {
    #expect(abs(Planner.frameFill(sizeArcmin: 60, fov: dwarfMini)! - 60.0 / 60 / 2.1) < 1e-9)
    #expect(Planner.frameFill(sizeArcmin: 500, fov: dwarfMini) == 1)
    #expect(Planner.frameFill(sizeArcmin: nil, fov: dwarfMini) == nil)
}

@Test func brightMoonCarriesItsFrameFill() throws {
    // The first hour of July 2026 with the Moon over half lit and 15° up at Home stands in for a bright window.
    let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let t = try #require((0..<(31 * 24)).lazy.map { utc(2026, 7, 1, 0, 0).addingTimeInterval(Double($0) * 3600) }.first {
        let m = Ephemeris.moon(at: $0, site: testSite); return m.illumination > 0.5 && m.position.altDeg > 20
    })
    let moon = try #require(Planner.brightTargets(during: ClearWindow(start: t, end: t.addingTimeInterval(3600)), site: testSite, fov: dwarfMini).first { $0.id == "moon" })
    #expect(moon.frameFill == Planner.frameFill(sizeArcmin: 31, fov: dwarfMini))
}
