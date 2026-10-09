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
    /// A suggestion's best time is at least this far from the best time of every other row, favourite or suggestion, and
    /// a suggested deep-sky object is clear of the horizon for at least this long. Owner, 9 October 2026: "most deep space
    /// object need 3-4 hours of time to capture all the pictures required for image stacking, you're typically not
    /// tracking more than 3 or 4 objects in one night". At this spacing a nine-hour window holds four rows at most.
    public static let gapHours: Double = 3

    /// One set of suggestions for the night: targets for the stretches of `gapHours` or more with no favourite best in
    /// them, between neighbouring favourites, before the first (from the window opening) and after the last (to the end
    /// of the plan). `anchors` are the favourites that can be in the plan that night, by best time, whether or not they
    /// have been taken off, so the set does not change as the user adds and takes off rows. With no favourites the
    /// whole window is one stretch, so a clear night still has something to review.
    ///
    /// (Earlier versions measured between the rows then in the plan, so every press brought suggestions and took them
    /// away, and offered up to three a gap an hour apart, which the owner called "dumping a ton of options".)
    ///
    /// The first for a stretch is the highest target that night whose best time falls inside it, `gapHours` clear of
    /// the favourites beside it, a Messier or Caldwell object when there is one. It then counts as a row itself, and
    /// what is left either side is filled the same way. In the order chosen, which `make` sorts by best time.
    ///
    /// Objects only (nebulae, galaxies, star clusters, planets and the Moon), as the popover's best three are; never a
    /// favourite, one washed out by the Moon, one too big or too small for the frame, or a deep-sky object clear of the
    /// horizon for under `gapHours`. In haze the brightest wins, not the highest (`Planner.hazeBrightness`).
    static func suggestions(anchors: [RankedTarget], plan: NightPlan, excluding: Set<String>, window: ClearWindow) -> [RankedTarget] {
        let gap = gapHours * 3600
        var used = excluding, out: [RankedTarget] = []
        func best(from: Date, to: Date) -> RankedTarget? {
            let candidates = plan.targets.filter { t in
                guard [TargetGroup.nebulae, .galaxies, .clusters, .planets].contains(t.group), !used.contains(t.id), !t.moonWashed, let v = t.viewable else { return false }
                return (t.group == .planets || (t.fit == .fits && v.end.timeIntervalSince(v.start) >= gap))
                    && t.peakTime >= from && t.peakTime <= min(to, window.end)   // never a target best after the finish time
            }
            // A Messier or Caldwell object when one is best in the stretch, else anything (owner, 9 October 2026).
            let pool = candidates.contains(where: \.isShowpiece) ? candidates.filter(\.isShowpiece) : candidates
            return plan.hazy ? pool.min { Planner.hazeBrightness($0) < Planner.hazeBrightness($1) }
                             : pool.max { ($0.peakAltDeg, -($0.magnitude ?? 99)) < ($1.peakAltDeg, -($1.magnitude ?? 99)) }
        }
        /// `lo` and `hi` bound the stretch being filled; a bound that is a row (a favourite or a suggestion) is kept
        /// `gapHours` clear of, and a bound that is the window's edge is not.
        func fill(lo: Date, loIsRow: Bool, hi: Date, hiIsRow: Bool) {
            guard hi.timeIntervalSince(lo) >= gap,
                  let t = best(from: loIsRow ? lo.addingTimeInterval(gap) : lo, to: hiIsRow ? hi.addingTimeInterval(-gap) : hi) else { return }
            used.insert(t.id)
            out.append(t)
            fill(lo: lo, loIsRow: loIsRow, hi: t.peakTime, hiIsRow: true)
            fill(lo: t.peakTime, loIsRow: true, hi: hi, hiIsRow: hiIsRow)
        }
        let edges = [(window.start, false)] + anchors.map { ($0.peakTime, true) } + [(window.end, false)]
        for (a, b) in zip(edges, edges.dropFirst()) { fill(lo: a.0, loIsRow: a.1, hi: b.0, hiIsRow: b.1) }
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
        items.sort { ($0.target.peakTime, $0.id) < ($1.target.peakTime, $1.id) }
        for i in items.indices {
            items[i].clashes = items.filter { o in
                o.id != items[i].id && abs(o.target.peakTime.timeIntervalSince(items[i].target.peakTime)) <= clashMinutes * 60
            }.map(\.target)
        }
        // The suggestions are the same set whatever the night's choices; one the user added is a plan row instead.
        // Only favourites are ever taken-off rows, so the page holds a favourite's row, a suggestion, or a target the
        // user added, and nothing he has let go of.
        let window = ClearWindow(start: w.start, end: end)
        let suggested = Self.suggestions(anchors: anchors.sorted { $0.peakTime < $1.peakTime }, plan: plan, excluding: Set(favourites), window: window)
        let spoken = Set(items.map(\.id) + takenOff.map(\.id))
        return SessionPlan(items: items, takenOff: takenOff.sorted { $0.peakTime < $1.peakTime }, omitted: omitted, window: window,
                           suggestions: suggested.filter { !spoken.contains($0.id) }.sorted { ($0.peakTime, $0.id) < ($1.peakTime, $1.id) })
    }

    /// The night's choices after a target is put in (`on`) or taken out. Put in: a favourite is simply back, any other
    /// target is added for the night. Taken out: a favourite is remembered as taken off, so its row stays in place with
    /// Put back; any other target just leaves the plan (a suggestion goes back to being that suggestion). For a few
    /// hours on 9 October 2026 every target taken off was remembered and kept a row: after one session of trying things
    /// the owner's page held ten of them ("too many options on this page now").
    public static func choose(_ id: String, on: Bool, isFavourite: Bool, in choices: PlanChoices) -> PlanChoices {
        var c = choices
        c.added.removeAll { $0 == id }
        c.removed.removeAll { $0 == id }
        if on { if !isFavourite { c.added.append(id) } } else if isFavourite { c.removed.append(id) }
        return c
    }

    /// Choices for `from` (a night key, "2026-09-29") and later, without empty ones: earlier nights have no further use.
    public static func pruned(_ all: [String: PlanChoices], from: String) -> [String: PlanChoices] {
        all.filter { $0.key >= from && !$0.value.isEmpty }
    }
}
