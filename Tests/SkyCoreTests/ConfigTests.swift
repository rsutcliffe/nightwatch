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

@Test func saveThroughSymlinkKeepsTheLink() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let realURL = dir.appendingPathComponent("real").appendingPathComponent("config.json")
    try ConfigStore.save(Config.default, to: realURL)

    let linkURL = dir.appendingPathComponent("link.json")
    try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: realURL)

    var modified = Config.default
    modified.flavour = .plain
    try ConfigStore.save(modified, to: linkURL)

    #expect(try FileManager.default.attributesOfItem(atPath: linkURL.path)[.type] as? FileAttributeType == .typeSymbolicLink)
    #expect(try ConfigStore.load(from: realURL).flavour == .plain)
}

@Test func decodesPartialFileWithDefaults() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("config.json")
    let json = #"{"flavour":"plain","goRule":{"minHours":2,"maxCloudPct":40,"minAltitudeDeg":30}}"#
    try json.write(to: url, atomically: true, encoding: .utf8)

    let c = try ConfigStore.load(from: url)
    #expect(c.flavour == .plain)
    #expect(c.goRule.minHours == 2)
    var expected = Config.default
    expected.flavour = .plain
    expected.goRule = GoRule(minHours: 2, maxCloudPct: 40, minAltitudeDeg: 30)
    #expect(c == expected)
}

@Test func malformedFileThrows() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let url = dir.appendingPathComponent("config.json")
    try "{not json".write(to: url, atomically: true, encoding: .utf8)
    #expect(throws: (any Error).self) { try ConfigStore.load(from: url) }
}

@Test func danglingSymlinkThrows() throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    let link = dir.appendingPathComponent("config.json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: dir.appendingPathComponent("gone/config.json"))
    #expect(throws: (any Error).self) { try ConfigStore.load(from: link) }
}
