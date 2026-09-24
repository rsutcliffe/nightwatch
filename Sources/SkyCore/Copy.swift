import Foundation

public enum Flavour: String, Codable, Sendable { case watch, plain }

/// Every flavoured string reads as ordinary English. Spec §6 is the only place new ones may be added.
public struct Copy: Sendable {
    public let flavour: Flavour
    public init(flavour: Flavour) { self.flavour = flavour }
    private var watch: Bool { flavour == .watch }

    public var refresh: String { watch ? "Patrol" : "Refresh" }
    public var siteNoun: String { watch ? "Beat" : "Site" }
    public var noWindow: String { watch ? "Nothing to see here. Move along." : "No clear window tonight." }
    public var cancelTitle: String { watch ? "Stand down. Clouds moving in" : "Cancelled. Clouds moving in" }
    public func offlineSince(_ time: String) -> String { watch ? "Off the beat since \(time)" : "Offline since \(time)" }
    public func goTitle(windowStart: String) -> String { watch ? "All's well. Clear from \(windowStart)" : "Clear from \(windowStart)" }
    public func headsUpTitle(windowStart: String, hours: Double) -> String {
        String(format: "Clear skies tonight from %@ · %.1f h", windowStart, hours)
    }
    public func tomorrowTitle(hours: Double) -> String { String(format: "Tomorrow night looks clear · %.1f h", hours) }

    // Bright nights (v0.3): the same words in both wording modes, no Discworld lines (owner ruling).
    public func brightHeadsUpTitle(windowStart: String, targets: [RankedTarget]) -> String {
        "Bright night tonight from \(windowStart) · \(Copy.brightList(targets))"
    }
    public func brightGoTitle(windowStart: String) -> String { "Bright night. Clear from \(windowStart)" }
    public func brightTomorrowTitle(hours: Double) -> String { String(format: "Tomorrow looks bright and clear · %.1f h", hours) }
    /// "Moon 62%, Saturn": the Moon with its illumination, planets by name, in the plan's order.
    public static func brightList(_ targets: [RankedTarget]) -> String {
        targets.map { $0.id == "moon" ? "Moon \($0.subtitle.prefix { $0 != " " })" : $0.name }.joined(separator: ", ")
    }

    public func notificationBody(plan: NightPlan, site: Site) -> String {
        if plan.mode == .bright { return Copy.brightList(plan.brightTargets) + " well placed." }
        var parts: [String] = []
        if let set = plan.moonSet { parts.append("Moon sets \(Copy.hhmm(set, site: site))") }
        else if plan.moonIllumination < 0.1 { parts.append("No Moon") }
        else { parts.append("Moon \(Int((plan.moonIllumination * 100).rounded()))%") }
        if !plan.best.isEmpty { parts.append(plan.best.map(\.name).joined(separator: ", ") + " well placed") }
        return parts.joined(separator: ". ") + "."
    }

    /// "Held back by a 97% moon and high dew risk": the two biggest losses, or nil when nothing limits the score.
    public static func heldBack(_ factors: [LimitingFactor]) -> String? {
        factors.isEmpty ? nil : "Held back by " + factors.prefix(2).map(\.text).joined(separator: " and ")
    }

    /// The bezel's screen-reader sentence (spec §7).
    public static func bezelLabel(_ plan: NightPlan, site: Site) -> String {
        guard let w = plan.primary else { return "Sky score \(plan.score) of 100. No clear window." }
        var s = "Sky score \(plan.score) of 100. Clear from \(hhmm(w.start, site: site)) to \(hhmm(w.end, site: site))"
        if let h = plan.darkHours.min(by: { $0.cloudTotal < $1.cloudTotal }) { s += ", clearest hour \(hhmm(h.time, site: site)) at \(max(0, 100 - h.cloudTotal))% clear" }
        return s + "."
    }

    public static func hhmm(_ date: Date, site: Site) -> String {
        let f = DateFormatter(); f.timeZone = site.timeZone; f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_GB")
        return f.string(from: date)
    }

    public func scoreBand(_ score: Int) -> String {
        switch score { case 80...: "Excellent"; case 50..<80: "Fair"; case 20..<50: "Poor"; default: "Overcast" }
    }
}
