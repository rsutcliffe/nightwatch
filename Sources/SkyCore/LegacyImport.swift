import Foundation

/// 0.6.x kept its settings in ~/Library/Application Support/Nightwatch (and, before 0.6.9, its alert records in
/// ~/Library/Caches/Nightwatch). The sandboxed app (0.7.0) keeps them in its own container, so on first launch it copies
/// them in. macOS's own container migration was tried first and does nothing on a Mac with iCloud Desktop & Documents
/// switched on (Apple DTS, forums thread 767586; seen on the owner's Mac). The Developer ID build reads the old folders
/// through read-only sandbox exceptions for those two folders; the App Store build has no exceptions and nothing to import.
public enum LegacyImport {
    public enum Outcome: Equatable, Sendable {
        case imported
        case nothing
        /// The old settings file is a link (0.6.x settings sync) to a place the sandbox cannot read: ask the person to
        /// choose it, which the sandbox allows.
        case linked(URL)
        case failed(String)
    }

    /// Copies, never moves or overwrites: each alert record only when the container lacks it, and the settings only when
    /// the container has none. A cached forecast with no settings file means someone set up on 0.6.6 or earlier who never
    /// changed a setting: they get a settings file marked as welcomed, so the welcome never returns.
    public static func run(from legacy: URL, legacyCaches: URL, to dir: URL) -> Outcome {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        // An alert record that fails to copy costs at most one repeated alert, so it never fails the import.
        for n in StateFiles.names where !fm.fileExists(atPath: dir.appendingPathComponent(n).path) {
            guard let source = [legacy, legacyCaches].map({ $0.appendingPathComponent(n) }).first(where: { fm.fileExists(atPath: $0.path) }) else { continue }
            _ = copy(source, to: dir.appendingPathComponent(n))
        }
        let target = dir.appendingPathComponent("config.json"), old = legacy.appendingPathComponent("config.json")
        if fm.fileExists(atPath: target.path) { return .nothing }
        if (try? fm.attributesOfItem(atPath: old.path)) != nil {           // present, even as a dangling link
            if copy(old, to: target) { return .imported }
            if let link = try? fm.destinationOfSymbolicLink(atPath: old.path) {
                return .linked(URL(fileURLWithPath: link, relativeTo: legacy).standardizedFileURL)
            }
            return .failed(old.path)
        }
        if fm.fileExists(atPath: legacyCaches.appendingPathComponent("forecast.json").path) {
            return (try? Data(#"{"welcomed":true}"#.utf8).write(to: target, options: .atomic)) != nil ? .imported : .failed(target.path)
        }
        return .nothing
    }

    /// Contents, not links: a symlinked file arrives as a plain file.
    private static func copy(_ source: URL, to target: URL) -> Bool {
        guard let data = try? Data(contentsOf: source) else { return false }
        return (try? data.write(to: target, options: .atomic)) != nil
    }

    /// The real home folder's copies: inside the sandbox, NSHomeDirectory() is the container.
    public static var realHome: URL {
        URL(fileURLWithPath: getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory())
    }
    public static var legacyDirectory: URL { realHome.appendingPathComponent("Library/Application Support/Nightwatch", isDirectory: true) }
    public static var legacyCaches: URL { realHome.appendingPathComponent("Library/Caches/Nightwatch", isDirectory: true) }
}
