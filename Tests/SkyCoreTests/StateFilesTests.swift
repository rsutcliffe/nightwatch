import Testing
import Foundation
@testable import SkyCore

private func withTempDirs(_ body: (URL, URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let caches = root.appendingPathComponent("Caches"), support = root.appendingPathComponent("Support/Nightwatch")
    try FileManager.default.createDirectory(at: caches, withIntermediateDirectories: true)
    try body(caches, support)
}

private func write(_ text: String, _ url: URL, modified: Date) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(text.utf8).write(to: url)
    try FileManager.default.setAttributes([.modificationDate: modified], ofItemAtPath: url.path)
}

private func read(_ url: URL) throws -> String { try String(contentsOf: url, encoding: .utf8) }

@Test func stateFilesMoveOutOfCaches() throws {
    try withTempDirs { caches, support in
        try write("old-alerts", caches.appendingPathComponent(StateFiles.alerts), modified: Date())
        try write("old-aurora", caches.appendingPathComponent(StateFiles.aurora), modified: Date())
        try write("{}", caches.appendingPathComponent("forecast.json"), modified: Date())   // a real cache file stays put
        StateFiles.migrate(from: caches, to: support)   // also creates the missing Application Support folder
        #expect(try read(support.appendingPathComponent(StateFiles.alerts)) == "old-alerts")
        #expect(try read(support.appendingPathComponent(StateFiles.aurora)) == "old-aurora")
        #expect(try FileManager.default.contentsOfDirectory(atPath: caches.path) == ["forecast.json"])
    }
}

@Test func theCopyWrittenLastWins() throws {
    let earlier = Date(timeIntervalSince1970: 1_790_000_000), later = earlier.addingTimeInterval(600)
    try withTempDirs { caches, support in
        // Normal case: the Application Support copy is current; a leftover in Caches is removed.
        try write("current", support.appendingPathComponent(StateFiles.alerts), modified: later)
        try write("stale", caches.appendingPathComponent(StateFiles.alerts), modified: earlier)
        StateFiles.migrate(from: caches, to: support)
        #expect(try read(support.appendingPathComponent(StateFiles.alerts)) == "current")
        #expect(!FileManager.default.fileExists(atPath: caches.appendingPathComponent(StateFiles.alerts).path))
        // Back to 0.6.8 and up again: 0.6.8 wrote a newer record in Caches, and that one is kept.
        try write("from-0.6.8", caches.appendingPathComponent(StateFiles.alerts), modified: later.addingTimeInterval(600))
        StateFiles.migrate(from: caches, to: support)
        #expect(try read(support.appendingPathComponent(StateFiles.alerts)) == "from-0.6.8")
        StateFiles.migrate(from: caches.appendingPathComponent("missing"), to: support)   // nothing to move: no change
        #expect(try read(support.appendingPathComponent(StateFiles.alerts)) == "from-0.6.8")
    }
}

@Test func stateLivesBesideTheSettingsNotInCaches() {
    #expect(StateFiles.directory == ConfigStore.defaultURL.deletingLastPathComponent())
    for n in StateFiles.names { #expect(!StateFiles.url(n).path.contains("/Caches/")) }
}
