import Foundation

/// When the night's session must end (#57): sleep, or work the next day. Off by default; `minutes` after local midnight.
public struct StopBy: Codable, Equatable, Sendable {
    public var enabled = false
    public var minutes = 30   // 00:30
    public init(enabled: Bool = false, minutes: Int = 30) { self.enabled = enabled; self.minutes = minutes }

    /// This clock time on `night`: the first one after that day's noon, so 23:00 is the same evening and 00:30 the next
    /// morning, whenever the window opens. Set by clock hour and minute, so the night the clocks change keeps it right.
    public func date(night: Night, site: Site) -> Date {
        let cal = site.calendar
        let noon = cal.date(bySettingHour: 12, minute: 0, second: 0, of: night.localDate)!
        let h = minutes / 60 % 24, m = minutes % 60
        let same = cal.date(bySettingHour: h, minute: m, second: 0, of: noon)!
        return same > noon ? same : cal.date(bySettingHour: h, minute: m, second: 0, of: cal.date(byAdding: .day, value: 1, to: noon)!)!
    }
}

/// One night's choices for Tonight's plan: favourites taken off for that night, and targets added for that night only.
/// Kept per night in settings, so they sync to the user's other Macs and are still there when the night planned as
/// "tomorrow night" becomes tonight (owner's UAT, 29 September 2026).
public struct PlanChoices: Codable, Equatable, Sendable {
    public var added: [String] = []
    public var removed: [String] = []
    public init(added: [String] = [], removed: [String] = []) { self.added = added; self.removed = removed }
    public var isEmpty: Bool { added.isEmpty && removed.isEmpty }
}

/// A target in the plan. `clashes`: the others whose best time is within `SessionPlanner.clashMinutes` of this one's.
public struct PlanItem: Equatable, Sendable, Identifiable {
    public let target: RankedTarget
    /// Added for this night only, rather than a favourite.
    public let added: Bool
    public var clashes: [RankedTarget] = []
    public var id: String { target.id }
}

/// A favourite, or an added target, left out of the night's plan, and why: "Below 30° in tonight's window".
public struct PlanOmission: Equatable, Sendable, Identifiable {
    public let target: RankedTarget
    public let reason: String
    public var id: String { target.id }
}

/// A target offered for a long gap in the plan (owner, 9 October 2026, approved mock-up): neither a favourite nor added,
/// shown between the two plan items it would sit between until the user adds it for the night or leaves it.
public struct PlanSuggestion: Equatable, Sendable, Identifiable {
    public let target: RankedTarget
    /// The plan item it follows; nil for the gap before the first item.
    public let afterID: String?
    /// The length of the gap: between the best times of the items either side, or from the window opening to the first
    /// item's best time, or from the last item's to the end of the plan.
    public let free: TimeInterval
    public var id: String { target.id }
}

/// Tonight's plan, as redesigned at the owner's UAT (29 September 2026, approved mock-up): the user's favourites that are
/// up in the clear window, plus any target added for the night, in order of their best time. The user takes off the ones
/// they will skip; nothing is scheduled into slots, so two favourites best at the same time are flagged for the user to
/// choose between.
public struct SessionPlan: Equatable, Sendable {
    /// In the plan, by best time.
    public let items: [PlanItem]
    /// Taken off for this night, by best time.
    public let takenOff: [RankedTarget]
    /// Favourites (and added targets) that cannot be in it tonight.
    public let omitted: [PlanOmission]
    /// The clear window, ended by Stop by when that comes first.
    public let window: ClearWindow
    /// One target for each long gap between neighbouring items; empty when the plan has none.
    public var suggestions: [PlanSuggestion] = []
}

public enum SessionPlanner {
    /// Best times this close together count as the same time.
    public static let clashMinutes: Double = 30
    /// Best times this far apart leave room for another target between them (owner, 9 October 2026: "3 hours is the right size").
    public static let gapHours: Double = 3
    /// A suggestion's best time keeps this clear of the plan items either side, so it is a target of its own and not a clash.
    public static let gapMarginHours: Double = 1

    /// One target for each gap of `gapHours` or more: between the best times of neighbouring plan items, before the first
    /// item (from the window opening) and after the last (to the end of the plan; owner, 9 October 2026: "cover the gaps
    /// before the first row and after the last too"). It is the highest one that night whose best time falls inside the
    /// gap, `gapMarginHours` clear of the plan items beside it. An empty plan gets none: its page says what a plan is
    /// made from. Objects only (nebulae, galaxies, star clusters, planets and the Moon), as the popover's best three are;
    /// never one already in the plan, taken off or left out of it, washed out by the Moon, or too big or too small for
    /// the frame. In haze the brightest wins, not the highest (`Planner.hazeBrightness`). A gap beside a target added
    /// for the night gets no suggestion: the first version offered another at once in the gap that remained, in the
    /// very place the row just added had been, so pressing Add to plan looked as if it had done nothing (owner,
    /// 9 October 2026). Add one and its dashed row goes; take it off again and the suggestion returns.
    static func suggestions(items: [PlanItem], plan: NightPlan, excluding: Set<String>, window: ClearWindow) -> [PlanSuggestion] {
        guard let first = items.first, let last = items.last else { return [] }
        let margin = gapMarginHours * 3600
        // Each gap: the item it follows, the span a suggestion's best time may fall in, and how long the gap is.
        var gaps: [(after: String?, from: Date, to: Date, free: TimeInterval)] = []
        if !first.added {
            gaps.append((nil, window.start, first.target.peakTime.addingTimeInterval(-margin), first.target.peakTime.timeIntervalSince(window.start)))
        }
        for (a, b) in zip(items, items.dropFirst()) where !a.added && !b.added {
            gaps.append((a.id, a.target.peakTime.addingTimeInterval(margin), b.target.peakTime.addingTimeInterval(-margin),
                         b.target.peakTime.timeIntervalSince(a.target.peakTime)))
        }
        if !last.added {
            gaps.append((last.id, last.target.peakTime.addingTimeInterval(margin), window.end, window.end.timeIntervalSince(last.target.peakTime)))
        }
        var used = excluding, out: [PlanSuggestion] = []
        for gap in gaps where gap.free >= gapHours * 3600 {
            let to = min(gap.to, window.end)   // never a target best after the finish time
            let candidates = plan.targets.filter { t in
                [TargetGroup.nebulae, .galaxies, .clusters, .planets].contains(t.group) && !used.contains(t.id) && !t.moonWashed
                    && (t.group == .planets || t.fit == .fits) && t.viewable != nil && t.peakTime >= gap.from && t.peakTime <= to
            }
            let pick = plan.hazy ? candidates.min { Planner.hazeBrightness($0) < Planner.hazeBrightness($1) }
                                 : candidates.max { ($0.peakAltDeg, -($0.magnitude ?? 99)) < ($1.peakAltDeg, -($1.magnitude ?? 99)) }
            if let t = pick { out.append(PlanSuggestion(target: t, afterID: gap.after, free: gap.free)); used.insert(t.id) }
        }
        return out
    }

    /// The plan for `plan`'s clear window, or nil on a night with no window, a bright night, or a Stop by before the
    /// window opens. Favourites come first in `favourites` order for the omissions; the plan itself is by best time.
    public static func make(plan: NightPlan, favourites: [String], choices: PlanChoices, stopBy: StopBy, site: Site) -> SessionPlan? {
        guard plan.mode == .dark, let w = plan.primary else { return nil }
        let end = stopBy.enabled ? min(w.end, stopBy.date(night: plan.night, site: site)) : w.end
        guard end > w.start else { return nil }
        var byID: [String: RankedTarget] = [:]
        for t in plan.targets + plan.favourites.map(\.target) where byID[t.id] == nil { byID[t.id] = t }
        let reasons = Dictionary(plan.favourites.map { ($0.target.id, $0.notTonight) }, uniquingKeysWith: { a, _ in a })
        var items: [PlanItem] = [], takenOff: [RankedTarget] = [], omitted: [PlanOmission] = [], seen = Set<String>()
        for id in favourites + choices.added where seen.insert(id).inserted {
            guard let t = byID[id] else { continue }
            if let reason = reasons[id] ?? nil { omitted.append(PlanOmission(target: t, reason: reason)); continue }
            if t.moonWashed { omitted.append(PlanOmission(target: t, reason: "Washed out by the Moon")); continue }
            guard let v = t.viewable else { omitted.append(PlanOmission(target: t, reason: site.horizon == nil ? "Not up in the clear window" : "Behind your horizon in the clear window")); continue }
            guard v.start < end else {
                omitted.append(PlanOmission(target: t, reason: "Up only after your finish time, \(Copy.hhmm(end, site: site))")); continue
            }
            if choices.removed.contains(id) { takenOff.append(t); continue }
            items.append(PlanItem(target: t, added: !favourites.contains(id)))
        }
        items.sort { ($0.target.peakTime, $0.id) < ($1.target.peakTime, $1.id) }
        for i in items.indices {
            items[i].clashes = items.filter { o in
                o.id != items[i].id && abs(o.target.peakTime.timeIntervalSince(items[i].target.peakTime)) <= clashMinutes * 60
            }.map(\.target)
        }
        // Favourites and added targets are spoken for whatever became of them: in the plan, taken off, or left out.
        let suggestions = Self.suggestions(items: items, plan: plan, excluding: Set(favourites + choices.added), window: ClearWindow(start: w.start, end: end))
        return SessionPlan(items: items, takenOff: takenOff.sorted { $0.peakTime < $1.peakTime }, omitted: omitted,
                           window: ClearWindow(start: w.start, end: end), suggestions: suggestions)
    }

    /// The night's choices after a target is put in (`on`) or taken out. A favourite is taken off or put back; any other
    /// target is added for the night or dropped.
    public static func choose(_ id: String, on: Bool, isFavourite: Bool, in choices: PlanChoices) -> PlanChoices {
        var c = choices
        c.added.removeAll { $0 == id }
        c.removed.removeAll { $0 == id }
        if isFavourite { if !on { c.removed.append(id) } } else if on { c.added.append(id) }
        return c
    }

    /// Choices for `from` (a night key, "2026-09-29") and later, without empty ones: earlier nights have no further use.
    public static func pruned(_ all: [String: PlanChoices], from: String) -> [String: PlanChoices] {
        all.filter { $0.key >= from && !$0.value.isEmpty }
    }
}
