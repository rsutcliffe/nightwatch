import Foundation

/// Files that remember what Nightwatch has already done tonight: which alerts went out. They live beside the settings in
/// Application Support, not in Caches, because cleaners and macOS itself may empty Caches at any time, and losing them
/// sends the same notification again (v0.6.9; a cleaner repeated tomorrow's preview on 25 September 2026).
public enum StateFiles {
    public static let names = ["alerts-state.json", "aurora-state.json"]
    public static var directory: URL { ConfigStore.defaultURL.deletingLastPathComponent() }

    /// Moves the files 0.6.8 and earlier kept in Caches into `dir`, once. A file already in `dir` is newer, so it wins
    /// and the leftover copy is removed.
    public static func migrate(from legacy: URL, to dir: URL = directory) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        for n in names {
            let old = legacy.appendingPathComponent(n), new = dir.appendingPathComponent(n)
            guard fm.fileExists(atPath: old.path) else { continue }
            if fm.fileExists(atPath: new.path) { try? fm.removeItem(at: old) } else { try? fm.moveItem(at: old, to: new) }
        }
    }
}
