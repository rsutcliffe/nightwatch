import SwiftUI
import NightwatchUI
import SkyCore

enum Theme {
    static let bg = Tokens.targetsBackground
    static let card = Tokens.targetsCard
    static let line = Tokens.targetsTrack
    static let text = Tokens.textPrimary
    static let dim = Tokens.textSecondary
    // Red accent by owner decision: preserves dark adaptation at the telescope. Never green.
    static let accent = Tokens.accentClear
    static let warn = Tokens.statusWarning

    static func icon(for plan: NightPlan?, stale: Bool, now: Date) -> String {
        if stale { return "star.slash" }
        guard let p = plan, let w = p.primary else { return "star" }
        return now >= w.start.addingTimeInterval(-1800) && now < w.end ? "star.fill" : "star.circle"
    }

    static func glyph(for group: TargetGroup) -> String { group.symbolName }
}
