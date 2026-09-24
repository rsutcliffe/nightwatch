import Foundation

/// Keeps the per-site forecast cache to the sites currently listed and the last 24 hours.
public enum CachePruning {
    /// Names to delete: anything that is not `<id>.json` for a current id, and anything older than `maxAge`.
    /// A file whose date is unknown is kept.
    public static func filesToDelete(names: [String], modified: [String: Date], keepIDs: Set<String>, now: Date, maxAge: TimeInterval = 86_400) -> [String] {
        names.filter { name in
            guard name.hasSuffix(".json"), keepIDs.contains(String(name.dropLast(5))) else { return true }
            guard let m = modified[name] else { return false }
            return now.timeIntervalSince(m) > maxAge
        }
    }

    /// Deletes what `filesToDelete` selects in `directory`. The cache is disposable, so every error is ignored.
    public static func prune(directory: URL, keepIDs: Set<String>, now: Date) {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        var modified: [String: Date] = [:]
        for n in names { modified[n] = (try? fm.attributesOfItem(atPath: directory.appendingPathComponent(n).path))?[.modificationDate] as? Date }
        for n in filesToDelete(names: names, modified: modified, keepIDs: keepIDs, now: now) {
            try? fm.removeItem(at: directory.appendingPathComponent(n))
        }
    }
}
