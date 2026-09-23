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

    public func notificationBody(plan: NightPlan, site: Site) -> String {
        var parts: [String] = []
        if let set = plan.moonSet { parts.append("Moon sets \(Copy.hhmm(set, site: site))") }
        else if plan.moonIllumination < 0.1 { parts.append("No Moon") }
        else { parts.append("Moon \(Int((plan.moonIllumination * 100).rounded()))%") }
        if !plan.best.isEmpty { parts.append(plan.best.map(\.name).joined(separator: ", ") + " well placed") }
        return parts.joined(separator: ". ") + "."
    }

    public static func hhmm(_ date: Date, site: Site) -> String {
        let f = DateFormatter(); f.timeZone = site.timeZone; f.dateFormat = "HH:mm"; f.locale = Locale(identifier: "en_GB")
        return f.string(from: date)
    }

    public func scoreBand(_ score: Int) -> String {
        switch score { case 80...: "Excellent"; case 50..<80: "Fair"; case 20..<50: "Poor"; default: "Overcast" }
    }
}
