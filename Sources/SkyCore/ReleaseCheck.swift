import Foundation

/// The once-a-day "is there a newer Nightwatch?" check (v0.6.7). Downloads do not update themselves, so the app asks
/// GitHub for the latest release and says so in the popover when it is newer than the running version.
public enum ReleaseCheck {
    public static let latestURL = URL(string: "https://api.github.com/repos/rsutcliffe/nightwatch/releases/latest")!
    public static let interval: TimeInterval = 24 * 3600

    public struct Latest: Codable, Equatable, Sendable {
        public let version: String
        public let url: URL
    }

    /// The release's version (without the leading "v") and page, from GitHub's latest-release JSON.
    public static func parse(_ data: Data) -> Latest? {
        guard let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = o["tag_name"] as? String, let page = o["html_url"] as? String, let url = URL(string: page) else { return nil }
        if (o["draft"] as? Bool) == true || (o["prerelease"] as? Bool) == true { return nil }
        return Latest(version: tag.hasPrefix("v") ? String(tag.dropFirst()) : tag, url: url)
    }

    /// The last successful check, kept on disk so the "available" line survives a relaunch. A failed request is not
    /// recorded, so it is retried at the next patrol rather than a day later.
    public struct Record: Codable, Equatable, Sendable {
        public var checkedAt: Date
        public var latest: Latest?
        public init(checkedAt: Date, latest: Latest?) { self.checkedAt = checkedAt; self.latest = latest }
    }
    public static func due(_ last: Record?, now: Date) -> Bool { last.map { now.timeIntervalSince($0.checkedAt) >= interval } ?? true }

    /// Numeric comparison part by part, so 0.10.0 is newer than 0.9.1; a missing part counts as 0.
    public static func isNewer(_ latest: String, than current: String) -> Bool {
        let a = latest.split(separator: ".").map { Int($0) ?? 0 }, b = current.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0, y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
