import Foundation

/// 0.6.x kept its settings in ~/Library/Application Support/Nightwatch. The sandboxed app (0.7.0) keeps them in its own
/// container, so on first launch it copies them in. macOS's own container migration was tried first and does nothing on a
/// Mac with iCloud Desktop & Documents switched on (Apple DTS, forums thread 767586; seen on the owner's Mac). The
/// Developer ID build reads the old folder through a read-only sandbox exception for that one folder; the App Store build
/// has no exception and nothing to import.
public enum LegacyImport {
    public static let names = ["config.json"] + StateFiles.names

    /// Copies the files, never moving or overwriting: only when the container has no settings yet. A symlinked settings
    /// file (0.6.x settings sync) is copied as its contents. True when settings were imported.
    @discardableResult
    public static func run(from legacy: URL, to dir: URL) -> Bool {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: dir.appendingPathComponent("config.json").path),
              let settings = try? Data(contentsOf: legacy.appendingPathComponent("config.json")) else { return false }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for n in names.dropFirst() {
            if let d = try? Data(contentsOf: legacy.appendingPathComponent(n)) { try? d.write(to: dir.appendingPathComponent(n), options: .atomic) }
        }
        // Settings last: their presence is what marks the import as done.
        return (try? settings.write(to: dir.appendingPathComponent("config.json"), options: .atomic)) != nil
    }

    /// The real home folder's copy: inside the sandbox, NSHomeDirectory() is the container.
    public static var legacyDirectory: URL {
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/Nightwatch", isDirectory: true)
    }
}
