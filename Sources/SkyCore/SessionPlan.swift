import Foundation

/// When the night's session must end (#57): sleep, or work the next day. Off by default; `minutes` after local midnight.
public struct StopBy: Codable, Equatable, Sendable {
    public var enabled = false
    public var minutes = 30   // 00:30
    public init(enabled: Bool = false, minutes: Int = 30) { self.enabled = enabled; self.minutes = minutes }

    /// The first time at this clock time, in the site's time zone, after `after`.
    public func date(after: Date, site: Site) -> Date {
        let cal = site.calendar
        let midnight = cal.startOfDay(for: after)
        let today = midnight.addingTimeInterval(Double(minutes) * 60)
        return today > after ? today : cal.date(byAdding: .day, value: 1, to: today)!
    }
}

/// One target's turn in Tonight's plan.
public struct PlanSlot: Equatable, Sendable, Identifiable {
    public let target: RankedTarget
    public let start: Date
    public let end: Date
    public var id: String { target.id }
}

/// Tonight's plan (#57, owner-approved mock-up, 29 September 2026): the clear window as a running order, each deep-sky
/// target at its best time, each slot long enough for its stack, ending with the window or the Stop by time.
public struct SessionPlan: Equatable, Sendable {
    public let slots: [PlanSlot]
    /// The window's end, or Stop by when that comes first.
    public let end: Date
    /// Time left after the last slot; nil when under 15 minutes.
    public let leftover: ClearWindow?
    /// The stack each slot holds, in minutes; nil without a maker's frame count (a slot is then the time a target is up).
    public let stackMinutes: Double?
    /// The leftover is shorter than a stack, rather than empty for want of anything else to shoot.
    public var leftoverTooShort: Bool { leftover.map { l in stackMinutes.map { l.hours * 60 < $0 } ?? true } ?? false }
    /// The maker's battery life when the plan runs longer than it (a power bank or spare battery may be needed); else nil.
    public let outlastsBatteryHours: Double?
    public var hours: Double { slots.last.map { $0.end.timeIntervalSince(slots[0].start) / 3600 } ?? 0 }
}

public enum SessionPlanner {
    static let deepSky: Set<TargetGroup> = [.nebulae, .galaxies, .clusters]

    /// The plan for `plan`'s clear window, or nil on a night with no window, a bright night, or nothing to shoot.
    /// `added` (from a target's page) and then `favourites` take their turn first when they are up; `removed` never do.
    /// Everyone else is chosen by altitude at the middle of the slot, so each target comes when it is best placed and one
    /// that sets early is not left until it has gone.
    public static func make(plan: NightPlan, presetID: String?, batteryHours: Double?, stopBy: StopBy, favourites: [String],
                            added: [String] = [], removed: Set<String> = [], site: Site) -> SessionPlan? {
        guard plan.mode == .dark, let w = plan.primary else { return nil }
        let end = stopBy.enabled ? min(w.end, stopBy.date(after: w.start, site: site)) : w.end
        guard end > w.start else { return nil }

        var pool: [String: RankedTarget] = [:]
        for t in plan.targets + plan.favourites.filter({ $0.notTonight == nil }).map(\.target) where pool[t.id] == nil { pool[t.id] = t }
        let chosen = Set(added)
        let candidates = pool.values.filter { t in
            guard !removed.contains(t.id), t.viewable != nil else { return false }
            return chosen.contains(t.id) || (deepSky.contains(t.group) && !t.moonWashed && t.fit == .fits)
        }
        let priority = added + favourites.filter { !chosen.contains($0) }
        let stack = ShootingTips.stackMinutes(presetID: presetID).map { $0 * 60 }

        var slots: [PlanSlot] = []
        var t = w.start
        while true {
            let used = Set(slots.map(\.id))
            // The slot each candidate would take from `t`: the stack, or without a published figure the time it stays up.
            func slot(_ c: RankedTarget) -> TimeInterval? {
                guard let v = c.viewable, v.start <= t else { return nil }
                let upTo = min(v.end, end)
                if let s = stack { return upTo.timeIntervalSince(t) >= s ? s : nil }
                return upTo.timeIntervalSince(t) >= 3600 ? upTo.timeIntervalSince(t) : nil
            }
            let open = candidates.filter { !used.contains($0.id) && slot($0) != nil }
            func altitude(_ c: RankedTarget) -> Double {
                Ephemeris.altAz(raHours: c.raHours, decDeg: c.decDeg, at: t.addingTimeInterval(slot(c)! / 2), site: site).alt
            }
            let first = priority.lazy.compactMap { id in open.first { $0.id == id } }.first
            guard let pick = first ?? open.max(by: { (altitude($0), -($0.magnitude ?? 99)) < (altitude($1), -($1.magnitude ?? 99)) }) else { break }
            let len = slot(pick)!
            slots.append(PlanSlot(target: pick, start: t, end: t.addingTimeInterval(len)))
            t = t.addingTimeInterval(len)
        }
        guard !slots.isEmpty else { return nil }
        let left = end.timeIntervalSince(t) >= 15 * 60 ? ClearWindow(start: t, end: end) : nil
        let hours = t.timeIntervalSince(slots[0].start) / 3600
        return SessionPlan(slots: slots, end: end, leftover: left, stackMinutes: stack.map { $0 / 60 },
                           outlastsBatteryHours: batteryHours.flatMap { hours > $0 ? $0 : nil })
    }
}
