import Testing
import Foundation
@testable import SkyCore

private func dirs(_ body: (URL, URL) throws -> Void) throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let legacy = root.appendingPathComponent("home/Library/Application Support/Nightwatch")
    let container = root.appendingPathComponent("container/Library/Application Support/Nightwatch")
    try FileManager.default.createDirectory(at: legacy, withIntermediateDirectories: true)
    try body(legacy, container)
}
private func put(_ s: String, _ u: URL) throws { try Data(s.utf8).write(to: u) }
private func get(_ u: URL) -> String? { (try? Data(contentsOf: u)).map { String(decoding: $0, as: UTF8.self) } }

@Test func settingsAndAlertRecordsAreCopiedIntoTheSandboxOnce() throws {
    try dirs { legacy, container in
        try put("settings", legacy.appendingPathComponent("config.json"))
        try put("alerts", legacy.appendingPathComponent(StateFiles.alerts))
        try put("aurora", legacy.appendingPathComponent(StateFiles.aurora))
        #expect(LegacyImport.run(from: legacy, to: container))   // creates the container folder
        #expect(get(container.appendingPathComponent("config.json")) == "settings")
        #expect(get(container.appendingPathComponent(StateFiles.alerts)) == "alerts")
        #expect(get(container.appendingPathComponent(StateFiles.aurora)) == "aurora")
        #expect(get(legacy.appendingPathComponent("config.json")) == "settings")   // copied, never moved
    }
}

@Test func settingsAlreadyInTheSandboxAreNeverOverwritten() throws {
    try dirs { legacy, container in
        try put("old", legacy.appendingPathComponent("config.json"))
        try FileManager.default.createDirectory(at: container, withIntermediateDirectories: true)
        try put("current", container.appendingPathComponent("config.json"))
        #expect(!LegacyImport.run(from: legacy, to: container))
        #expect(get(container.appendingPathComponent("config.json")) == "current")
    }
}

@Test func nothingToImportLeavesTheSandboxEmpty() throws {
    try dirs { legacy, container in
        #expect(!LegacyImport.run(from: legacy.appendingPathComponent("missing"), to: container))
        #expect(!FileManager.default.fileExists(atPath: container.appendingPathComponent("config.json").path))
    }
}

@Test func aSymlinkedSettingsFileIsCopiedAsItsContents() throws {   // settings synced by a symlink (README, 0.6.x)
    try dirs { legacy, container in
        let real = legacy.deletingLastPathComponent().appendingPathComponent("synced-config.json")
        try put("synced settings", real)
        try FileManager.default.createSymbolicLink(at: legacy.appendingPathComponent("config.json"), withDestinationURL: real)
        #expect(LegacyImport.run(from: legacy, to: container))
        let copied = container.appendingPathComponent("config.json")
        #expect(get(copied) == "synced settings")
        #expect((try? FileManager.default.destinationOfSymbolicLink(atPath: copied.path)) == nil)   // a plain file now
    }
}

@Test func theLegacyFolderIsTheRealHomeNotTheContainer() {
    #expect(LegacyImport.legacyDirectory.path.hasSuffix("/Library/Application Support/Nightwatch"))
    #expect(!LegacyImport.legacyDirectory.path.contains("/Library/Containers/"))
}
