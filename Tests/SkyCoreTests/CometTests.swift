import Testing
import Foundation
@testable import SkyCore

@Test func decodesMpcRecords() throws {
    let comets = try Comets.decode(try fixture("comets.json"))
    #expect(comets.count == 3)
    let encke = try #require(comets.first { $0.designation == "2P/Encke" })
    #expect(encke.orbitType == "P" && abs(encke.q - 0.338612) < 1e-9 && encke.perihelionDay == 10.2278)
}

// Oracle: JPL Horizons, 2P/Encke, geocentric, 2026-09-23 00:00 UT: RA 16.36366°, Dec 20.44533°, delta 1.28624917 AU, APmag 17.815.
@Test func enckeMatchesHorizonsAtEpoch() throws {
    let encke = try #require(try Comets.decode(try fixture("comets.json")).first { $0.designation == "2P/Encke" })
    let p = try #require(Comets.position(encke, at: utc(2026, 9, 23, 0, 0)))
    #expect(abs(p.raHours * 15 - 16.36366) < 0.5)
    #expect(abs(p.decDeg - 20.44533) < 0.5)
    #expect(abs(p.deltaAU - 1.28625) < 0.02)
    #expect(abs(p.magnitude - 17.8) < 1.5)
}

@Test func hyperbolicOrbitPropagates() throws {
    let borisov = try #require(try Comets.decode(try fixture("comets.json")).first { $0.designation == "2I/Borisov" })
    let p = try #require(Comets.position(borisov, at: utc(2026, 9, 23, 0, 0)))
    #expect(p.rAU > 10)          // long gone
    #expect(p.magnitude > 20)
}

@Test func nearParabolicDoesNotCrash() throws {
    var c = try #require(try Comets.decode(try fixture("comets.json")).first { $0.designation.hasPrefix("C/1942") })
    c.e = 1.0
    #expect(Comets.position(c, at: utc(2026, 9, 23, 0, 0)) != nil)
}
