import Testing
import Foundation
@testable import SkyCore

let sheffield = Site(name: "Sheffield", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
let sydney = Site(name: "Sydney", latitude: -33.87, longitude: 151.21, elevationM: 20, timeZoneID: "Australia/Sydney", bortle: 7)

func utc(_ y: Int, _ mo: Int, _ d: Int, _ h: Int, _ mi: Int) -> Date {
    var c = DateComponents(); c.year = y; c.month = mo; c.day = d; c.hour = h; c.minute = mi
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
    return cal.date(from: c)!
}

func close(_ a: Date, _ b: Date, minutes: Double) -> Bool { abs(a.timeIntervalSince(b)) <= minutes * 60 }

// Oracles: USNO sunset 18:02 UTC (23rd); sunrise-sunset.org api.sunrise-sunset.org/json (date=2026-09-23)
// astronomical_twilight_end 20:01:49 (23rd evening); (date=2026-09-24) astronomical_twilight_begin 03:56:43,
// sunrise 05:53:39 (24th morning, verified live — the brief's original 03:54:39/05:51:54 were the
// date=2026-09-23 response's own morning fields, i.e. the 23rd's dawn, not the night-ending 24th morning).
@Test func sheffieldNightOracle() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 12, 0), site: sheffield)
    #expect(night.key == "2026-09-23")
    #expect(close(night.sunset, utc(2026, 9, 23, 18, 3), minutes: 3))
    #expect(close(try #require(night.darkStart), utc(2026, 9, 23, 20, 2), minutes: 3))
    #expect(close(try #require(night.darkEnd), utc(2026, 9, 24, 3, 57), minutes: 3))
    #expect(close(night.sunrise, utc(2026, 9, 24, 5, 54), minutes: 3))
}

// Oracle: sunrise-sunset.org Sydney 2026-09-23: sunset 07:53:02 UTC, astronomical twilight end 09:15:09 UTC.
@Test func sydneyNightOracleSouthernHemisphere() throws {
    let night = try Ephemeris.night(localDate: utc(2026, 9, 23, 2, 0), site: sydney)
    #expect(night.key == "2026-09-23")
    #expect(close(night.sunset, utc(2026, 9, 23, 7, 53), minutes: 3))
    #expect(close(try #require(night.darkStart), utc(2026, 9, 23, 9, 15), minutes: 3))
}

@Test func polarSummerHasNoAstronomicalDarkness() throws {
    let tromso = Site(name: "Tromsø", latitude: 69.65, longitude: 18.96, elevationM: 10, timeZoneID: "Europe/Oslo", bortle: 4)
    let night = try Ephemeris.night(localDate: utc(2026, 7, 20, 10, 0), site: tromso)
    #expect(night.darkStart == nil)
    #expect(night.darkEnd == nil)
    #expect(night.sunrise > night.sunset)
    #expect(!night.hasDarkness)
}

@Test func polarNightHasDarkness() throws {
    let tromso = Site(name: "Tromsø", latitude: 69.65, longitude: 18.96, elevationM: 10, timeZoneID: "Europe/Oslo", bortle: 4)
    let night = try Ephemeris.night(localDate: utc(2026, 12, 21, 10, 0), site: tromso)
    #expect(night.hasDarkness)
    let ds = try #require(night.darkStart), de = try #require(night.darkEnd)
    #expect(ds >= night.sunset && de <= night.sunrise && de > ds)
    #expect(Ephemeris.sunAltitude(at: ds.addingTimeInterval(3600), site: tromso) < -18)
    #expect(de.timeIntervalSince(ds) > 12 * 3600)   // most of the polar night is astronomically dark
}

@Test func polarisIsHighFromSheffield() {
    let p = Ephemeris.altAz(raHours: 2.53, decDeg: 89.26, at: utc(2026, 9, 23, 22, 0), site: sheffield)
    #expect(abs(p.alt - 53.4) < 1.5)
}

@Test func moonIlluminationInRange() {
    let m = Ephemeris.moon(at: utc(2026, 9, 23, 22, 0), site: sheffield)
    #expect(m.illumination >= 0 && m.illumination <= 1)
    #expect(m.position.altDeg > -90 && m.position.altDeg < 90)
}

@Test func separationOfIdenticalPointsIsZeroAndPolesIs180() {
    #expect(Ephemeris.separationDeg(ra1Hours: 1, dec1Deg: 10, ra2Hours: 1, dec2Deg: 10) < 1e-9)
    #expect(abs(Ephemeris.separationDeg(ra1Hours: 0, dec1Deg: 90, ra2Hours: 0, dec2Deg: -90) - 180) < 1e-9)
}

@Test func constellationLookup() {
    let c = Ephemeris.constellation(raHours: 5.6, decDeg: -5.4)   // M42
    #expect(c.symbol == "Ori")
}

@Test func nextLunarEclipseExists() {
    let e = Ephemeris.nextLunarEclipse(after: utc(2026, 9, 23, 0, 0))
    #expect(e != nil)
    #expect(e!.peak > utc(2026, 9, 23, 0, 0))
}
