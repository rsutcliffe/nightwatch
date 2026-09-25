import Testing
import Foundation
@testable import SkyCore

private func tempDir() throws -> URL {
    let d = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
    return d
}

@Test func stateFilesMoveOutOfCachesOnce() throws {
    let caches = try tempDir(), support = try tempDir().appendingPathComponent("Nightwatch")
    try Data("old-alerts".utf8).write(to: caches.appendingPathComponent("alerts-state.json"))
    try Data("old-aurora".utf8).write(to: caches.appendingPathComponent("aurora-state.json"))
    try Data("{}".utf8).write(to: caches.appendingPathComponent("forecast.json"))   // a real cache file stays put
    StateFiles.migrate(from: caches, to: support)
    #expect(try String(contentsOf: support.appendingPathComponent("alerts-state.json"), encoding: .utf8) == "old-alerts")
    #expect(try String(contentsOf: support.appendingPathComponent("aurora-state.json"), encoding: .utf8) == "old-aurora")
    #expect(try FileManager.default.contentsOfDirectory(atPath: caches.path) == ["forecast.json"])
}

@Test func stateAlreadyInSupportWinsOverALeftoverCopy() throws {
    let caches = try tempDir(), support = try tempDir()
    try Data("current".utf8).write(to: support.appendingPathComponent("alerts-state.json"))
    try Data("stale".utf8).write(to: caches.appendingPathComponent("alerts-state.json"))
    StateFiles.migrate(from: caches, to: support)
    #expect(try String(contentsOf: support.appendingPathComponent("alerts-state.json"), encoding: .utf8) == "current")
    #expect(!FileManager.default.fileExists(atPath: caches.appendingPathComponent("alerts-state.json").path))
    StateFiles.migrate(from: caches.appendingPathComponent("missing"), to: support)   // nothing to move: no throw, no change
    #expect(try String(contentsOf: support.appendingPathComponent("alerts-state.json"), encoding: .utf8) == "current")
}

@Test func stateLivesBesideTheSettingsNotInCaches() {
    #expect(StateFiles.directory == ConfigStore.defaultURL.deletingLastPathComponent())
    #expect(!StateFiles.directory.path.contains("/Caches/"))
}
