import Foundation

/// Names of cached survey images. Card images keep the name they have always had (`<id>-<w>x<h>.jpg`), so the existing
/// cache stays valid; the detail page's larger images add their width, and their extra sky (v0.6.4).
public enum ThumbnailFiles {
    public static let cardWidth = 480

    public static func name(id: String, fovWidthDeg: Double, fovHeightDeg: Double, width: Int = cardWidth, context: Double = 1) -> String {
        let size = width == cardWidth ? "" : "-w\(width)", wider = context == 1 ? "" : String(format: "-c%.1f", context)
        return "\(id)-\(String(format: "%.2fx%.2f", fovWidthDeg, fovHeightDeg))\(size)\(wider).jpg"
    }

    /// Detail images older than `maxAge` (30 days): each is 0.2–0.3 MB and only fetched when a page is opened. Card images
    /// are kept forever, as before; a file whose date is unknown is kept.
    public static func staleDetailImages(names: [String], modified: [String: Date], now: Date, maxAge: TimeInterval = 30 * 86_400) -> [String] {
        names.filter { n in
            guard n.range(of: #"-w\d+(-c[\d.]+)?\.jpg$"#, options: .regularExpression) != nil, let m = modified[n] else { return false }
            return now.timeIntervalSince(m) > maxAge
        }
    }
}
