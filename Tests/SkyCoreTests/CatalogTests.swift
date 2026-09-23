import Testing
import Foundation
@testable import SkyCore

@Test func parsesSampleRows() throws {
    let csv = String(decoding: try fixture("ngc-sample.csv"), as: UTF8.self)
    let objs = try Catalog.parse(csv: csv)
    let m31 = try #require(objs.first { $0.id == "NGC0224" })
    #expect(m31.messier == 31)
    #expect(m31.group == .galaxies)
    #expect(abs(m31.raHours - 0.712) < 0.01)
    #expect(abs(m31.decDeg - 41.27) < 0.05)
    #expect((m31.majAxisArcmin ?? 0) > 100)
    #expect(m31.displayName.hasPrefix("M31"))
    let nan = try #require(objs.first { $0.id == "NGC7000" })
    #expect(nan.group == .nebulae)
    #expect(nan.commonName?.contains("North America") == true)
    let ring = try #require(objs.first { $0.id == "NGC6720" })
    #expect(ring.group == .nebulae && ring.messier == 57)
    let dbl = try #require(objs.first { $0.id == "NGC0869" })
    #expect(dbl.group == .clusters)
    #expect(objs.first { $0.id == "IC0001" } == nil)   // double star, no group
    let pleiades = try #require(objs.first { $0.id == "Mel022" })
    #expect(pleiades.messier == 45 && pleiades.group == .clusters)
}

@Test func bundledCatalogLoads() throws {
    let cat = try Catalog.bundled()
    #expect(cat.objects.count > 5000)
    #expect(cat.objects.filter { $0.messier != nil }.count >= 100)
}

@Test func bundledConstellationsLoad() throws {
    let cs = try Constellations.bundled()
    #expect(cs.count == 88)
    #expect(Set(cs.map(\.id)).count == cs.count)
    let ori = try #require(cs.first { $0.id == "Ori" })
    #expect(ori.name == "Orion")
    #expect(!ori.lines.isEmpty)
    #expect(ori.raHours >= 0 && ori.raHours < 24)
    let ser = try #require(cs.first { $0.id == "Ser" })
    #expect(ser.name == "Serpens")
    #expect(ser.lines.count >= 2)
}

@Test func figureCrossingZeroHoursIsUnwrapped() throws {
    let and = try #require(try Constellations.bundled().first { $0.id == "And" })
    let raw = and.lines.flatMap { $0.map { $0[0] } }
    #expect(raw.max()! - raw.min()! > 12)            // straddles 0 h in the stored 0..24 form
    let ras = and.unwrappedLines.flatMap { $0.map { $0[0] } }
    #expect(ras.max()! - ras.min()! < 6)
    let cyg = try #require(try Constellations.bundled().first { $0.id == "Cyg" })
    #expect(cyg.unwrappedLines == cyg.lines)          // nowhere near 0 h: untouched
}
