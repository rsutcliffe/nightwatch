import Testing
import Foundation
@testable import SkyCore

@Test func presetsLoad() throws {
    let p = try TelescopePresets.bundled()
    #expect(p.count == 4)
    #expect(p.first { $0.id == "dwarf-mini" }?.widthDeg == 2.1)
}

@Test func defaultConfigIsSane() {
    let c = Config.default
    #expect(c.sites.isEmpty && c.activeSiteName == nil)
    #expect(c.fov == FieldOfView(widthDeg: 2.1, heightDeg: 1.2))
    #expect(c.goRule == GoRule())
    #expect(c.flavour == .watch && c.notifyEnabled && !c.loginItem)
}

@Test func roundTripsThroughDisk() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    let url = dir.appendingPathComponent("config.json")
    var c = Config.default
    c.sites = [Site(name: "Home", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)]
    c.activeSiteName = "Home"
    try ConfigStore.save(c, to: url)
    #expect(try ConfigStore.load(from: url) == c)
    #expect(try ConfigStore.load(from: dir.appendingPathComponent("missing.json")) == Config.default)
}

@Test func activeSiteResolution() {
    var c = Config.default
    let home = Site(name: "Home", latitude: 1, longitude: 2, elevationM: 0, timeZoneID: "UTC", bortle: 4)
    let auto = Site(name: "Current location", latitude: 9, longitude: 9, elevationM: 0, timeZoneID: "UTC", bortle: 5)
    c.sites = [home]
    #expect(c.activeSite(auto: auto) == auto)
    #expect(c.activeSite(auto: nil) == home)
    c.activeSiteName = "Home"
    #expect(c.activeSite(auto: auto) == home)
    c.sites = []; c.activeSiteName = nil
    #expect(c.activeSite(auto: nil) == nil)
}
