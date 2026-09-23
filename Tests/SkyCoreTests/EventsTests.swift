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
}
