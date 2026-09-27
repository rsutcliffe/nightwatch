import Testing
import Foundation
@testable import SkyCore

private let site = Site(name: "Sheffield", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)

@Test func bundledShowersLoad() throws {
    let s = try MeteorShowers.bundled()
    #expect(s.count == 12)
    #expect(s.contains { $0.id == "gem" && $0.zhr == 150 })
}

@Test func activeShowersOnSeptember23IncludeSouthernTaurids() throws {
    let s = try MeteorShowers.bundled()
    let active = MeteorShowers.active(on: utc(2026, 9, 23, 12, 0), calendar: site.calendar, showers: s)
    #expect(active.map(\.id) == ["sta"])
}

@Test func quadrantidsSpanTheNewYear() throws {
    let s = try MeteorShowers.bundled()
    #expect(MeteorShowers.active(on: utc(2026, 12, 30, 12, 0), calendar: site.calendar, showers: s).contains { $0.id == "qua" })
    #expect(MeteorShowers.active(on: utc(2027, 1, 2, 12, 0), calendar: site.calendar, showers: s).contains { $0.id == "qua" })
    #expect(!MeteorShowers.active(on: utc(2027, 1, 20, 12, 0), calendar: site.calendar, showers: s).contains { $0.id == "qua" })
}

@Test func peakDetection() throws {
    let gem = try #require(try MeteorShowers.bundled().first { $0.id == "gem" })
    #expect(MeteorShowers.isPeak(gem, on: utc(2026, 12, 14, 12, 0), calendar: site.calendar))
    #expect(!MeteorShowers.isPeak(gem, on: utc(2026, 12, 10, 12, 0), calendar: site.calendar))
}

@Test func showerEventsCarryRadiantAndTitle() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 12, 14, 12, 0), site: site)
    let ev = Events.showers(night: night, site: site, showers: try MeteorShowers.bundled())
    let gem = try #require(ev.first { $0.id == "shower-gem" })
    #expect(gem.kind == .meteorShower)
    #expect(gem.title.contains("Geminids"))
    #expect(gem.detail.contains("peak"))
    #expect(gem.raHours == 7.5)
}

@Test func eclipseEventsWithinAYearExist() {
    let ev = Events.eclipses(after: utc(2026, 9, 23, 0, 0), site: site, withinDays: 400)
    #expect(ev.contains { $0.kind == .lunarEclipse })
}

@Test func conjunctionsAreSymmetricAndBounded() {
    let ev = Events.conjunctions(at: utc(2026, 9, 23, 23, 0), site: site, maxSeparationDeg: 180)
    // 7 planets + Moon = 8 bodies -> 28 pairs
    #expect(ev.count == 28)
    let tight = Events.conjunctions(at: utc(2026, 9, 23, 23, 0), site: site, maxSeparationDeg: 3)
    #expect(tight.count <= 28)
    #expect(tight.allSatisfy { $0.kind == .conjunction })
    let seps = ev.map { Double($0.detail.split(separator: "°")[0])! }
    #expect(zip(seps, seps.dropFirst()).allSatisfy { $0 <= $1 })
}

// MARK: richer events (v1.0.1)

private let dwarfMini = FieldOfView(widthDeg: 2.1, heightDeg: 1.2)

@Test func constellationsComeFromTheIAUBoundaries() {
    #expect(Ephemeris.constellation(raHours: 5.278, decDeg: 46.0).name == "Auriga")     // Capella
    #expect(Ephemeris.constellation(raHours: 18.616, decDeg: 38.78).name == "Lyra")     // Vega
    #expect(Ephemeris.constellation(raHours: 5.919, decDeg: 7.41).name == "Orion")      // Betelgeuse
}

@Test func aShowerSaysWhenItPeaksWhereToLookAndWhatTheMoonDoes() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 27, 12, 0), site: site)   // full Moon
    let sta = try #require(Events.showers(night: night, site: site, showers: try MeteorShowers.bundled()).first { $0.id == "shower-sta" })
    let radiant = Ephemeris.constellation(raHours: 3.5, decDeg: 15).name
    #expect(sta.detail.hasPrefix("Peak 5 November, in 39 days · radiant in \(radiant), best "))
    #expect(sta.facts.map(\.label) == ["Peak", "Radiant", "At peak, from here", "Moon", "Speed", "Parent"])
    #expect(sta.facts[0].value == "5 November, ZHR 7")
    #expect(sta.facts[3].value.contains("hide all but the brightest meteors"))
    let best = try #require(sta.best)
    #expect(best >= night.darkStart! && best <= night.darkEnd!)
    #expect(sta.when == best)
}

@Test func showerPeakWordingTonightAndAfter() throws {
    let showers = try MeteorShowers.bundled()
    let gemNight = try Ephemeris.night(localDate: utc(2026, 12, 14, 12, 0), site: site)
    let gem = try #require(Events.showers(night: gemNight, site: site, showers: showers).first { $0.id == "shower-gem" })
    #expect(gem.detail.hasPrefix("At peak tonight · radiant in Gemini"))
    let rate = try #require(gem.facts.first { $0.label == "At peak, from here" }?.value)
    let n = try #require(Int(rate.split(separator: " ")[3]))                          // "Up to about N an hour…"
    #expect(n > 0 && n <= 150)
    let quaNight = try Ephemeris.night(localDate: utc(2027, 1, 8, 12, 0), site: site)
    let qua = try #require(Events.showers(night: quaNight, site: site, showers: showers).first { $0.id == "shower-qua" })
    #expect(qua.detail.hasPrefix("Past its peak (3 January)"))
}

@Test func eclipsesGiveLocalTimesAndHeight() throws {
    let lunar = try #require(Events.eclipses(after: utc(2026, 9, 23, 0, 0), site: site, withinDays: 400).first { $0.kind == .lunarEclipse })
    #expect(lunar.facts.map(\.label).prefix(3) == ["Begins", "Peak", "Ends"])
    #expect(lunar.facts.last?.label == "Moon at peak")
    let l = try #require(Ephemeris.nextLunarEclipse(after: utc(2026, 9, 23, 0, 0)))
    #expect(try #require(l.begin) < l.peak && l.peak < (try #require(l.end)))
}

@Test func conjunctionsSayWhetherTheyFitTheFrame() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: site)
    let ev = Events.conjunctions(at: utc(2026, 9, 23, 23, 0), site: site, maxSeparationDeg: 180, night: night, fov: dwarfMini)
    #expect(ev.count == 28)
    for e in ev {
        let sep = try #require(e.separationDeg)
        #expect(e.detail.contains(sep <= 2.1 * 0.9 ? "fits your field of view" : "wider than your field of view"))
        #expect(e.facts.map(\.label).starts(with: ["Separation", "Your field of view", "Best"]))
    }
}

@Test func anISSPassSaysWhereToLook() {
    let p = SatellitePass(rise: utc(2026, 9, 27, 20, 10), peak: utc(2026, 9, 27, 20, 14), set: utc(2026, 9, 27, 20, 18),
                          maxElevationDeg: 62, peakAzimuthDeg: 180, riseAzimuthDeg: 270, setAzimuthDeg: 90)
    let e = Events.issPass(p, site: site)
    #expect(e.detail == "Rises W 21:10 · 62° up in the S 21:14 · sets E 21:18")
    #expect(e.best == p.peak)
    #expect(e.facts.last?.value == "About 8 minutes")
}

@Test func aCometSaysWhereItIsAndWhetherItIsBrightening() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 27, 12, 0), site: site)
    let here = CometPosition(raHours: 5.278, decDeg: 46.0, magnitude: 9.1, deltaAU: 1.2, rAU: 1.5)   // Capella's place: high before dawn
    let c = try #require(Events.comet(designation: "C/2026 X1", pos: here, later: CometPosition(raHours: 5.3, decDeg: 46, magnitude: 8.8, deltaAU: 1.1, rAU: 1.4),
                                      night: night, site: site))
    #expect(c.detail.hasPrefix("mag 9.1 · in Auriga · best "))
    #expect(c.facts.first?.value == "9.1, brightening (8.8 in a week)")
    let fading = Events.comet(designation: "x", pos: here, later: CometPosition(raHours: 5.3, decDeg: 46, magnitude: 9.6, deltaAU: 1.3, rAU: 1.6),
                              night: night, site: site)
    #expect(fading?.facts.first?.value == "9.1, fading (9.6 in a week)")
    let south = CometPosition(raHours: 5.0, decDeg: -60, magnitude: 7, deltaAU: 1, rAU: 1)   // never rises at 53° N
    #expect(Events.comet(designation: "y", pos: south, later: nil, night: night, site: site) == nil)
}

@Test func eventsAreMarkedClearOrCloudyFromTheForecastHour() {
    func hour(_ h: Int, _ cloud: Int) -> HourlyConditions {
        HourlyConditions(time: utc(2026, 9, 27, h, 0), cloudTotal: cloud, cloudLow: nil, cloudMid: nil, cloudHigh: nil, tempC: nil,
                         dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)
    }
    let hours = [hour(20, 10), hour(21, 80)]
    func ev(_ h: Int, _ m: Int) -> SkyEvent {
        SkyEvent(id: "\(h)\(m)", kind: .issPass, title: "", detail: "", time: utc(2026, 9, 27, h, m), endTime: nil, raHours: nil, decDeg: nil)
    }
    let marked = Events.markClear([ev(20, 30), ev(21, 5), ev(23, 0)], hours: hours, maxCloudPct: 25)
    #expect(marked.map(\.clear) == [true, false, nil])
}

@Test func eventTipsFitTheKindOfEvent() throws {
    func e(_ k: SkyEventKind, sep: Double? = nil) -> SkyEvent {
        var x = SkyEvent(id: "x", kind: k, title: "", detail: "", time: utc(2026, 9, 27, 20, 10), endTime: nil, raHours: nil, decDeg: nil)
        x.separationDeg = sep
        return x
    }
    func labels(_ x: SkyEvent) -> [String] { ShootingTips.tip(for: x, fov: dwarfMini, presetName: nil, site: site).rows.map(\.label) }
    #expect(labels(e(.meteorShower)) == ["Kit", "Aim", "Exposure"])
    #expect(labels(e(.issPass)) == ["Kit", "Timing"])
    #expect(labels(e(.solarEclipse)) == ["Safety"])
    let near = ShootingTips.tip(for: e(.conjunction, sep: 1.0), fov: dwarfMini, presetName: nil, site: site).rows[0].text
    let far = ShootingTips.tip(for: e(.conjunction, sep: 2.5), fov: dwarfMini, presetName: nil, site: site).rows[0].text
    #expect(near.hasPrefix("Both fit") && far.hasPrefix("Wider than"))
}
