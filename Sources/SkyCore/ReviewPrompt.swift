import Foundation

/// When to ask for a rating. Only Apple's own system prompt is used, never custom wording and never an incentive (App Review Guidelines 5.6.1 and
/// 5.6.3), and Apple itself shows it at most three times in 365 days. The record had no ratings by 3 November 2026, so the ask comes after a success:
/// the app is opened while tonight's clear window is open, on the third different night. After it has been asked, not again for 120 days, and then
/// only after three more such nights.
public struct ReviewPrompt: Codable, Equatable, Sendable {
    public static let nightsNeeded = 3
    public static let minimumGap: TimeInterval = 120 * 86_400

    private(set) var nights: [String] = []
    private(set) var askedAt: Date?

    public init() {}

    /// A key for tonight's clear window when `now` is inside it and the plan qualifies; nil otherwise. The same window always gives the same key.
    public static func clearNight(mode: PlanMode, qualifies: Bool, primary: ClearWindow?, now: Date) -> String? {
        guard mode == .dark, qualifies, let w = primary, w.start <= now, now < w.end else { return nil }
        return String(Int(w.start.timeIntervalSince1970 / 86_400))
    }

    /// Records a night (once) and says whether to ask now.
    public mutating func opened(onNight night: String, now: Date) -> Bool {
        if let asked = askedAt, now.timeIntervalSince(asked) < Self.minimumGap { return false }
        if !nights.contains(night) { nights.append(night) }
        guard nights.count >= Self.nightsNeeded else { return false }
        nights = []
        askedAt = now
        return true
    }
}

public extension ReviewPrompt {
    private static let key = "reviewPrompt"

    /// Decides for the current plan, keeps the state in `defaults`, and returns true when the system prompt should be shown.
    static func due(for plan: NightPlan?, now: Date = Date(), defaults: UserDefaults = .standard) -> Bool {
        guard let plan, let night = clearNight(mode: plan.mode, qualifies: plan.qualifies, primary: plan.primary, now: now) else { return false }
        var state = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(ReviewPrompt.self, from: $0) } ?? ReviewPrompt()
        let ask = state.opened(onNight: night, now: now)
        defaults.set(try? JSONEncoder().encode(state), forKey: key)
        return ask
    }
}
