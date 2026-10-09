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

/// One row of the plan page: a target in the plan, one suggested for a long gap, or one taken off for the night.
public enum PlanRow: Equatable, Sendable, Identifiable {
    case item(PlanItem), suggestion(RankedTarget), takenOff(RankedTarget)
    public var target: RankedTarget {
        switch self { case .item(let i): i.target; case .suggestion(let t), .takenOff(let t): t }
    }
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
    /// Targets suggested for the long gaps between the night's favourites and at either end, by best time, less any now
    /// in the plan or taken off. The set is the same whatever has been added or taken off.
    public var suggestions: [RankedTarget] = []

    /// Every row of the page in best-time order: a target keeps its place whether it is in the plan, suggested or taken
    /// off (owner, 9 October 2026, on a recording of rows appearing and leaving as he pressed).
    public var rows: [PlanRow] {
        (items.map(PlanRow.item) + suggestions.map(PlanRow.suggestion) + takenOff.map(PlanRow.takenOff))
            .sorted { ($0.target.peakTime, $0.id) < ($1.target.peakTime, $1.id) }
    }
}

public enum SessionPlanner {
    /// Best times this close together count as the same time.
    public static let clashMinutes: Double = 30
    /// Best times this far apart leave room for another target between them (owner, 9 October 2026: "3 hours is the right size").
    public static let gapHours: Double = 3
    /// A suggestion's best time keeps this clear of the plan items either side, so it is a target of its own and not a clash.
    public static let gapMarginHours: Double = 1

    /// The most suggestions one gap between plan rows is given, however long it is.
    /// ponytail: a fixed cap so a long empty night is not filled with a dozen dashed rows; raise it if three is too few.
    public static let gapSuggestionLimit = 3

    /// One set of suggestions for the night, for each gap of `gapHours` or more between the best times of neighbouring
    /// favourites, before the first (from the window opening) and after the last (to the end of the plan). `anchors` are
    /// the favourites that can be in the plan that night, by best time, whether or not they have been taken off, so the
    /// set does not change as the user adds and takes off rows. With no favourites the whole window is one gap, so a
    /// clear night still has something to review.
    ///
    /// (Three earlier versions measured the gaps between the rows then in the plan. Every press redrew the gaps, so
    /// suggestions the user had not touched left and others arrived, a suggestion taken off brought up a replacement
    /// without end, and a plan with no rows was offered nothing. Owner, 9 October 2026: "one set of recommendations
    /// built from what would be most visible in the gaps".)
    ///
    /// The first for a gap is the highest target that night whose best time falls inside it, `gapMarginHours` clear of
    /// the favourites beside it, a Messier or Caldwell object when there is one. It then counts as a row itself, and
    /// what is left of the gap either side is filled the same way while it is still `gapHours` long, up to
    /// `gapSuggestionLimit` for the gap. In the order chosen, which `make` sorts by best time.
    ///
    /// Objects only (nebulae, galaxies, star clusters, planets and the Moon), as the popover's best three are; never a
    /// favourite, one washed out by the Moon, or one too big or too small for the frame. In haze the brightest wins,
    /// not the highest (`Planner.hazeBrightness`).
    static func suggestions(anchors: [RankedTarget], plan: NightPlan, excluding: Set<String>, window: ClearWindow) -> [RankedTarget] {
        let margin = gapMarginHours * 3600
        var used = excluding, out: [RankedTarget] = []
        func best(from: Date, to: Date) -> RankedTarget? {
            let candidates = plan.targets.filter { t in
                [TargetGroup.nebulae, .galaxies, .clusters, .planets].contains(t.group) && !used.contains(t.id) && !t.moonWashed
                    && (t.group == .planets || t.fit == .fits) && t.viewable != nil
                    && t.peakTime >= from && t.peakTime <= min(to, window.end)   // never a target best after the finish time
            }
            // A Messier or Caldwell object when one is best in the stretch, else anything (owner, 9 October 2026).
            let pool = candidates.contains(where: \.isShowpiece) ? candidates.filter(\.isShowpiece) : candidates
            return plan.hazy ? pool.min { Planner.hazeBrightness($0) < Planner.hazeBrightness($1) }
                             : pool.max { ($0.peakAltDeg, -($0.magnitude ?? 99)) < ($1.peakAltDeg, -($1.magnitude ?? 99)) }
        }
        /// `lo` and `hi` bound the stretch being filled; a bound that is a row (a favourite or a suggestion) is kept clear
        /// of by the margin, and a bound that is the window's edge is not.
        func fill(lo: Date, loIsRow: Bool, hi: Date, hiIsRow: Bool, left: inout Int) {
            guard left > 0, hi.timeIntervalSince(lo) >= gapHours * 3600,
                  let t = best(from: loIsRow ? lo.addingTimeInterval(margin) : lo, to: hiIsRow ? hi.addingTimeInterval(-margin) : hi) else { return }
            used.insert(t.id); left -= 1
            out.append(t)
            fill(lo: lo, loIsRow: loIsRow, hi: t.peakTime, hiIsRow: true, left: &left)
            fill(lo: t.peakTime, loIsRow: true, hi: hi, hiIsRow: hiIsRow, left: &left)
        }
        let edges = [(window.start, false)] + anchors.map { ($0.peakTime, true) } + [(window.end, false)]
        for (a, b) in zip(edges, edges.dropFirst()) {
            var left = gapSuggestionLimit
            fill(lo: a.0, loIsRow: a.1, hi: b.0, hiIsRow: b.1, left: &left)
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
        var anchors: [RankedTarget] = []   // the favourites that can be in the plan this night, taken off or not
        for id in favourites + choices.added where seen.insert(id).inserted {
            guard let t = byID[id] else { continue }
            if let reason = reasons[id] ?? nil { omitted.append(PlanOmission(target: t, reason: reason)); continue }
            if t.moonWashed { omitted.append(PlanOmission(target: t, reason: "Washed out by the Moon")); continue }
            guard let v = t.viewable else { omitted.append(PlanOmission(target: t, reason: site.horizon == nil ? "Not up in the clear window" : "Behind your horizon in the clear window")); continue }
            guard v.start < end else {
                omitted.append(PlanOmission(target: t, reason: "Up only after your finish time, \(Copy.hhmm(end, site: site))")); continue
            }
            if favourites.contains(id) { anchors.append(t) }
            if choices.removed.contains(id) { takenOff.append(t); continue }
            items.append(PlanItem(target: t, added: !favourites.contains(id)))
        }
        // A target added for the night and then taken off is a taken-off row too, with Put back, as a favourite is.
        for id in choices.removed where seen.insert(id).inserted {
            if let t = byID[id], let v = t.viewable, v.start < end { takenOff.append(t) }
        }
        items.sort { ($0.target.peakTime, $0.id) < ($1.target.peakTime, $1.id) }
        for i in items.indices {
            items[i].clashes = items.filter { o in
                o.id != items[i].id && abs(o.target.peakTime.timeIntervalSince(items[i].target.peakTime)) <= clashMinutes * 60
            }.map(\.target)
        }
        // The suggestions are the same set whatever the night's choices. One the user added is a plan row, and one added
        // and then taken off is a taken-off row with Put back: each stays where it stood, and none is offered twice.
        let window = ClearWindow(start: w.start, end: end)
        let suggested = Self.suggestions(anchors: anchors.sorted { $0.peakTime < $1.peakTime }, plan: plan, excluding: Set(favourites), window: window)
        let spoken = Set(items.map(\.id) + takenOff.map(\.id))
        return SessionPlan(items: items, takenOff: takenOff.sorted { $0.peakTime < $1.peakTime }, omitted: omitted, window: window,
                           suggestions: suggested.filter { !spoken.contains($0.id) }.sorted { ($0.peakTime, $0.id) < ($1.peakTime, $1.id) })
    }

    /// The night's choices after a target is put in (`on`) or taken out. Put in: a favourite is simply back, any other
    /// target is added for the night. Taken out: it is remembered as taken off whichever it was, so its row stays in
    /// place with Put back, and a suggestion taken off is not replaced by another.
    public static func choose(_ id: String, on: Bool, isFavourite: Bool, in choices: PlanChoices) -> PlanChoices {
        var c = choices
        c.added.removeAll { $0 == id }
        c.removed.removeAll { $0 == id }
        if !on { c.removed.append(id) } else if !isFavourite { c.added.append(id) }
        return c
    }

    /// Choices for `from` (a night key, "2026-09-29") and later, without empty ones: earlier nights have no further use.
    public static func pruned(_ all: [String: PlanChoices], from: String) -> [String: PlanChoices] {
        all.filter { $0.key >= from && !$0.value.isEmpty }
    }
}
