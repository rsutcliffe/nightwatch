import Testing
import Foundation
@testable import SkyCore

private struct Dirs { let legacy: URL, caches: URL, container: URL }
private func dirs(_ body: (Dirs) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let d = Dirs(legacy: root.appendingPathComponent("home/Library/Application Support/Nightwatch"),
                 caches: root.appendingPathComponent("home/Library/Caches/Nightwatch"),
                 container: root.appendingPathComponent("container/Library/Application Support/Nightwatch"))
    for u in [d.legacy, d.caches] { try FileManager.default.createDirectory(at: u, withIntermediateDirectories: true) }
    try body(d)
}
private func put(_ s: String, _ u: URL) throws { try Data(s.utf8).write(to: u) }
private func get(_ u: URL) -> String? { (try? Data(contentsOf: u)).map { String(decoding: $0, as: UTF8.self) } }
private func run(_ d: Dirs) -> LegacyImport.Outcome { LegacyImport.run(from: d.legacy, legacyCaches: d.caches, to: d.container) }

@Test func settingsAndAlertRecordsAreCopiedIntoTheSandbox() throws {
    try dirs { d in
        try put("settings", d.legacy.appendingPathComponent("config.json"))
        try put("alerts", d.legacy.appendingPathComponent(StateFiles.alerts))
        try put("aurora", d.legacy.appendingPathComponent(StateFiles.aurora))
        #expect(run(d) == .imported)   // creates the container folder
        #expect(get(d.container.appendingPathComponent("config.json")) == "settings")
        #expect(get(d.container.appendingPathComponent(StateFiles.alerts)) == "alerts")
        #expect(get(d.container.appendingPathComponent(StateFiles.aurora)) == "aurora")
        #expect(get(d.legacy.appendingPathComponent("config.json")) == "settings")   // copied, never moved
        #expect(run(d) == .nothing)    // a second launch changes nothing
    }
}

@Test func settingsAlreadyInTheSandboxAreNeverOverwrittenButMissingRecordsStillArrive() throws {
    try dirs { d in
        try put("old", d.legacy.appendingPathComponent("config.json"))
        try put("alerts", d.legacy.appendingPathComponent(StateFiles.alerts))
        try FileManager.default.createDirectory(at: d.container, withIntermediateDirectories: true)
        try put("current", d.container.appendingPathComponent("config.json"))
        #expect(run(d) == .nothing)
        #expect(get(d.container.appendingPathComponent("config.json")) == "current")
        #expect(get(d.container.appendingPathComponent(StateFiles.alerts)) == "alerts")
    }
}

@Test func alertRecordsFromBefore069AreFoundInTheOldCaches() throws {
    try dirs { d in
        try put("settings", d.legacy.appendingPathComponent("config.json"))
        try put("cached alerts", d.caches.appendingPathComponent(StateFiles.alerts))
        #expect(run(d) == .imported)
        #expect(get(d.container.appendingPathComponent(StateFiles.alerts)) == "cached alerts")
    }
}

@Test func aCachedForecastWithNoSettingsCountsAsAlreadySetUp() throws {   // 0.6.6 or earlier, no setting ever changed
    try dirs { d in
        try put("{}", d.caches.appendingPathComponent("forecast.json"))
        #expect(run(d) == .imported)
        let c = try JSONDecoder().decode(Config.self, from: Data(contentsOf: d.container.appendingPathComponent("config.json")))
        #expect(c.welcomed)
    }
}

@Test func nothingToImportLeavesTheSandboxEmpty() throws {
    try dirs { d in
        #expect(run(d) == .nothing)
        #expect(!FileManager.default.fileExists(atPath: d.container.appendingPathComponent("config.json").path))
    }
}

@Test func aReadableSymlinkedSettingsFileIsCopiedAsItsContents() throws {
    try dirs { d in
        let real = d.legacy.deletingLastPathComponent().appendingPathComponent("synced-config.json")
        try put("synced settings", real)
        try FileManager.default.createSymbolicLink(at: d.legacy.appendingPathComponent("config.json"), withDestinationURL: real)
        #expect(run(d) == .imported)
        let copied = d.container.appendingPathComponent("config.json")
        #expect(get(copied) == "synced settings")
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copied.path)) == nil)   // a plain file now
    }
}

@Test func anUnreadableSymlinkedSettingsFileIsReportedForThePersonToChoose() throws {
    // Inside the sandbox a link into iCloud Drive cannot be followed; a dangling link fails the same way here.
    try dirs { d in
        let target = URL(fileURLWithPath: "/nonexistent/iCloud/Nightwatch/config.json")
        try FileManager.default.createSymbolicLink(at: d.legacy.appendingPathComponent("config.json"), withDestinationURL: target)
        #expect(run(d) == .linked(target))
        #expect(!FileManager.default.fileExists(atPath: d.container.appendingPathComponent("config.json").path))
    }
}

@Test func theLegacyFoldersAreInTheRealHomeNotTheContainer() {
    #expect(LegacyImport.legacyDirectory.path.hasSuffix("/Library/Application Support/Nightwatch"))
    #expect(LegacyImport.legacyCaches.path.hasSuffix("/Library/Caches/Nightwatch"))
    #expect(!LegacyImport.realHome.path.contains("/Library/Containers/"))
}
