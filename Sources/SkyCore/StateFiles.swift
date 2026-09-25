import Foundation

/// Files that remember what Nightwatch has already done tonight: which alerts went out. They live beside the settings in
/// Application Support, not in Caches, because cleaners and macOS itself may empty Caches at any time, and losing them
/// sends the same notification again (v0.6.9; a cleaner repeated tomorrow's preview on 25 September 2026).
public enum StateFiles {
    public static let alerts = "alerts-state.json", aurora = "aurora-state.json"
    public static let names = [alerts, aurora]
    public static var directory: URL { ConfigStore.defaultURL.deletingLastPathComponent() }
    public static func url(_ name: String) -> URL { directory.appendingPathComponent(name) }

    /// Moves the files 0.6.8 and earlier kept in Caches into `dir`. When both copies exist (someone went back to 0.6.8
    /// and upgraded again), the one written last is kept, so an alert already sent is never forgotten.
    public static func migrate(from legacy: URL, to dir: URL = directory) {
        let fm = FileManager.default
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        func modified(_ u: URL) -> Date { ((try? fm.attributesOfItem(atPath: u.path))?[.modificationDate] as? Date) ?? .distantPast }
        for n in names {
            let old = legacy.appendingPathComponent(n), new = dir.appendingPathComponent(n)
            guard fm.fileExists(atPath: old.path) else { continue }
            if fm.fileExists(atPath: new.path), modified(new) >= modified(old) { try? fm.removeItem(at: old); continue }
            try? fm.removeItem(at: new)
            try? fm.moveItem(at: old, to: new)
        }
    }
}
