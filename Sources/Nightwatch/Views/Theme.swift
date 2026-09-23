import SwiftUI
import SkyCore

enum Theme {
    static let bg = Color(red: 0.078, green: 0.090, blue: 0.118)          // #14171e
    static let card = Color(red: 0.106, green: 0.122, blue: 0.157)        // #1b1f28
    static let line = Color(red: 0.149, green: 0.165, blue: 0.208)        // #262a35
    static let text = Color(red: 0.910, green: 0.918, blue: 0.941)        // #e8eaf0
    static let dim = Color(red: 0.545, green: 0.576, blue: 0.655)         // #8b93a7
    static let accent = Color(red: 0.431, green: 0.906, blue: 0.718)      // #6ee7b7
    static let warn = Color(red: 0.957, green: 0.722, blue: 0.376)        // #f4b860
    static let bad = Color(red: 0.941, green: 0.549, blue: 0.549)         // #f08c8c

    static func icon(for plan: NightPlan?, stale: Bool, now: Date) -> String {
        if stale { return "star.slash" }
        guard let p = plan, let w = p.primary else { return "star" }
        return now >= w.start.addingTimeInterval(-1800) && now < w.end ? "star.fill" : "star.circle"
    }

    static func glyph(for group: TargetGroup) -> String {
        switch group {
        case .nebulae: "cloud.fill"
        case .galaxies: "hurricane"
        case .clusters: "sparkles"
        case .planets: "circle.circle"
        case .events: "calendar"
        case .constellations: "point.3.connected.trianglepath.dotted"
        }
    }
}
