import Testing
import Foundation

/// The download and the Mac App Store build come from one codebase. Their only difference is the update check, behind one
/// `#if APPSTORE` in Sources/Nightwatch/Distribution.swift. A second one anywhere means the builds are drifting apart:
/// decide it on purpose and update this test.
@Test func theAppStoreBuildDiffersInExactlyOnePlace() throws {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    let files = FileManager.default.enumerator(at: root.appendingPathComponent("Sources"), includingPropertiesForKeys: nil)!
        .compactMap { $0 as? URL }.filter { $0.pathExtension == "swift" }
    let hits = try files.flatMap { url in
        try String(contentsOf: url, encoding: .utf8).components(separatedBy: "\n")
            .filter { $0.contains("APPSTORE") && $0.trimmingCharacters(in: .whitespaces).hasPrefix("#if") }
            .map { _ in url.lastPathComponent }
    }
    #expect(hits == ["Distribution.swift"])
    let widget = try String(contentsOf: root.appendingPathComponent("Widget/Sources/NightwatchWidget.swift"), encoding: .utf8)
    #expect(!widget.contains("APPSTORE"))
}
