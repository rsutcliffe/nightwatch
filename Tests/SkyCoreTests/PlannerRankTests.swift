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
    // The first hour of July 2026 with the Moon over half lit and 15° up at the test site stands in for a bright window.
    let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let t = try #require((0..<(31 * 24)).lazy.map { utc(2026, 7, 1, 0, 0).addingTimeInterval(Double($0) * 3600) }.first {
        let m = Ephemeris.moon(at: $0, site: testSite); return m.illumination > 0.5 && m.position.altDeg > 20
    })
    let moon = try #require(Planner.brightTargets(during: ClearWindow(start: t, end: t.addingTimeInterval(3600)), site: testSite, fov: dwarfMini).first { $0.id == "moon" })
    #expect(moon.frameFill == Planner.frameFill(sizeArcmin: 31, fov: dwarfMini))
}

@Test func timelineStopsFollowAltitude() {
    #expect(Planner.timelineStops([30, 50, 70]) == [0, 0.5, 1])
    #expect(Planner.timelineStops([]) == [])
}

@Test func timelineStopsWithALowPeak() {
    // The Moon's 10° floor and bright targets at 15°: the floor drops to 10° below the peak, never dividing by zero.
    let u = Planner.timelineStops([5, 12])
    #expect(abs(u[0] - 0.3) < 1e-9 && u[1] == 1)
    #expect(Planner.timelineStops([20, 20]) == [1, 1])
}

@Test func frameChipWording() {
    func t(_ fit: FrameFit, _ fill: Double?) -> RankedTarget {
        var r = RankedTarget(id: "x", name: "x", subtitle: "", group: .nebulae, raHours: 0, decDeg: 0, sizeArcmin: nil, magnitude: nil, fit: fit,
                             peakAltDeg: 50, peakTime: Date(), moonSepDeg: 90, moonWashed: false, visibleFraction: 1)
        r.frameFill = fill
        return r
    }
    #expect(Copy.frameChip(t(.fits, 0.476)) == "Fills 48% of frame")
    #expect(Copy.frameChip(t(.fits, 0.001)) == "Fills 1% of frame")
    #expect(Copy.frameChip(t(.small, 0.02)) == "Small in frame")
    #expect(Copy.frameChip(t(.mosaic, 1)) == "Mosaic")
    #expect(Copy.frameChip(t(.fits, nil)) == "Fits frame")   // no size to measure: never invent a percentage
}

@Test func sortOrders() throws {
    func t(_ id: String, alt: Double, size: Double?, mag: Double?) -> RankedTarget {
        RankedTarget(id: id, name: id, subtitle: "", group: .nebulae, raHours: 0, decDeg: 0, sizeArcmin: size, magnitude: mag, fit: .fits,
                     peakAltDeg: alt, peakTime: Date(), moonSepDeg: 90, moonWashed: false, visibleFraction: 1)
    }
    let ts = [t("a", alt: 40, size: nil, mag: 9), t("b", alt: 70, size: 30, mag: nil), t("c", alt: 55, size: 90, mag: 5)]
    let day = Date(timeIntervalSince1970: 1_790_000_000)
    #expect(Planner.sorted(ts, by: .altitude, now: day, span: nil, site: sheffieldSite).map(\.id) == ["b", "c", "a"])
    #expect(Planner.sorted(ts, by: .size, now: day, span: nil, site: sheffieldSite).map(\.id) == ["c", "b", "a"])
    #expect(Planner.sorted(ts, by: .brightness, now: day, span: nil, site: sheffieldSite).map(\.id) == ["c", "a", "b"])
    #expect(Planner.sorted(ts, by: .bestNow, now: day, span: nil, site: sheffieldSite).map(\.id) == ["a", "b", "c"])   // outside the span: ranked order
}

@Test func bestNowUsesCurrentAltitudeInsideTheSpan() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: sheffieldSite)
    let span = ClearWindow(start: night.darkStart!, end: night.darkEnd!)
    let ranked = Planner.rank(catalog: try Catalog.bundled(), constellations: [], window: span, site: sheffieldSite, fov: dwarfMini, rule: GoRule())
    let now = span.midpoint
    let alts = Planner.sorted(ranked, by: .bestNow, now: now, span: span, site: sheffieldSite)
        .map { Ephemeris.altAz(raHours: $0.raHours, decDeg: $0.decDeg, at: now, site: sheffieldSite).alt }
    #expect(alts == alts.sorted(by: >))
}

@Test func nearMoonRule() {
    func t(_ id: String, _ group: TargetGroup, sep: Double) -> RankedTarget {
        RankedTarget(id: id, name: id, subtitle: "", group: group, raHours: 0, decDeg: 0, sizeArcmin: nil, magnitude: nil, fit: .fits,
                     peakAltDeg: 50, peakTime: Date(), moonSepDeg: sep, moonWashed: false, visibleFraction: 1)
    }
    #expect(t("NGC7000", .nebulae, sep: 10).isNearMoon(moonIllumination: 0.8, moonUpTonight: true))
    #expect(!t("NGC7000", .nebulae, sep: 10).isNearMoon(moonIllumination: 0.4, moonUpTonight: true))
    #expect(!t("NGC7000", .nebulae, sep: 20).isNearMoon(moonIllumination: 0.8, moonUpTonight: true))
    #expect(!t("moon", .planets, sep: 0).isNearMoon(moonIllumination: 0.9, moonUpTonight: true))
    #expect(!t("Cyg", .constellations, sep: 0).isNearMoon(moonIllumination: 0.9, moonUpTonight: true))
    #expect(!t("NGC7000", .nebulae, sep: 10).isNearMoon(moonIllumination: 0.8, moonUpTonight: false))   // a Moon below the horizon all night washes nothing out
}

@Test func brightPlanetsCarryARealMoonSeparation() throws {
    // 0 used to stand in for "not measured" on bright targets, which would mark every planet Near Moon.
    let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    var checked = 0
    for h in 0..<8 {   // 21:00Z to 04:00Z, so at least one planet is up
        let t = utc(2026, 7, 30, 21, 0).addingTimeInterval(Double(h) * 3600)
        let moon = Ephemeris.moon(at: t, site: testSite).position
        for p in Planner.brightTargets(at: t, site: testSite) where p.id != "moon" {
            let expected = Ephemeris.separationDeg(ra1Hours: p.raHours, dec1Deg: p.decDeg, ra2Hours: moon.raHours, dec2Deg: moon.decDeg)
            #expect(abs(p.moonSepDeg - expected) < 1e-6)
            #expect(p.moonSepDeg > 0)
            checked += 1
        }
    }
    #expect(checked > 0)
}

@Test func cardLabelCarriesChipsAndMagnitude() {
    func target(washed: Bool) -> RankedTarget {
        var r = RankedTarget(id: "NGC7000", name: "NGC 7000", subtitle: "", group: .nebulae, raHours: 0, decDeg: 0, sizeArcmin: 120, magnitude: 4, fit: .fits,
                             peakAltDeg: 64, peakTime: utc(2026, 9, 23, 22, 20), moonSepDeg: 20, moonWashed: washed, visibleFraction: 1)
        r.catalogueID = "NGC 7000"; r.commonName = "North America Nebula"; r.frameFill = 0.95
        r.viewable = ClearWindow(start: utc(2026, 9, 23, 20, 10), end: utc(2026, 9, 24, 0, 40))
        return r
    }
    let s = Copy.cardLabel(target(washed: true), lit: true, nearMoon: false, site: sheffieldSite)
    #expect(s.contains("magnitude 4.0"))
    #expect(s.contains("Moon-washed"))
    #expect(s.contains("Fills 95% of frame"))
    #expect(Copy.cardLabel(target(washed: false), lit: true, nearMoon: true, site: sheffieldSite).contains("Near Moon"))
}

@Test func notifyLabelFallsBackWhenTheNudgeIsInQuietHours() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 11, 20, 12, 0), site: sheffieldSite)
    func plan(_ start: Date) -> NightPlan {
        let w = ClearWindow(start: start, end: start.addingTimeInterval(3 * 3600))
        return NightPlan(night: night, windows: [w], primary: w, score: 80, qualifies: true, moonIllumination: 0, moonRise: nil, moonSet: nil,
                         darkHours: [], targets: [], best: [], seeingAvailable: false)
    }
    let settings = AlertSettings()   // quiet 00:00–07:00, nudge 30 min before
    #expect(Copy.notifyLabel(plan(utc(2026, 11, 20, 21, 0)), site: sheffieldSite, settings: settings) == "Notify at 20:30")
    #expect(Copy.notifyLabel(plan(utc(2026, 11, 21, 1, 0)), site: sheffieldSite, settings: settings) == "Notify when clear")
    #expect(Copy.notifyLabel(nil, site: sheffieldSite, settings: settings) == "Notify when clear")
}
