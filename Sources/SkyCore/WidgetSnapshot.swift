import Foundation

/// One of the widget's best-tonight rows.
public struct WidgetTarget: Codable, Equatable, Sendable {
    public var id: String
    public var catalogueID: String
    public var name: String
    public var best: String
    public var group: TargetGroup
    public init(id: String, catalogueID: String, name: String, best: String, group: TargetGroup) {
        self.id = id; self.catalogueID = catalogueID; self.name = name; self.best = best; self.group = group
    }
}

/// Everything the desktop widget draws, as plain values (v0.6). The app writes it after each patrol; the widget only reads
/// it, so the widget can never disagree with the popover. Nothing here is new wording except `staleText`.
public struct WidgetSnapshot: Codable, Equatable, Sendable {
    public var siteName: String
    public var fetchedAt: Date
    public var score: Int
    public var mode: PlanMode
    public var headline: String
    public var window: String?
    public var windowShort: String?
    public var reason: String?
    public var reasonWarns: Bool
    public var agreement: String?
    public var agreementWarns: Bool
    public var slots: [BezelSlot]
    public var bezelLabel: String
    public var bars: [ClearSkyBar]
    public var barsLabel: String
    public var targets: [WidgetTarget]
    public var tomorrow: String?
    public var notify: String?

    public static func make(plan: NightPlan, tomorrow: NightPlan?, fetchedAt: Date, site: Site, rule: GoRule,
                            bright: BrightSettings, alerts: AlertSettings, copy: Copy) -> WidgetSnapshot {
        func hm(_ d: Date) -> String { Copy.hhmm(d, site: site) }
        let w = plan.primary
        let noDarkness = w == nil && !plan.night.hasDarkness && (plan.mode == .dark || !plan.night.hasNauticalDarkness)
        let headline = w != nil ? (plan.mode == .bright ? "Bright night: Moon and planets" : "Clear window tonight")
                                : (noDarkness ? "No astronomical darkness" : copy.noWindow)
        let reason: String? = w != nil ? Copy.heldBack(plan.limiting)
            : (noDarkness ? "Too far north or south for this date." : Planner.noWindowReasonText(plan: plan, rule: rule, bright: bright, site: site))
        let picks = plan.mode == .bright ? plan.brightTargets : plan.best
        return WidgetSnapshot(
            siteName: site.name, fetchedAt: fetchedAt, score: plan.score, mode: plan.mode, headline: headline,
            window: w.map { "\(hm($0.start)) → \(hm($0.end)) · \(String(format: "%.1f h", $0.hours))" },
            windowShort: w.map { (plan.mode == .bright ? "Bright " : "Clear ") + "\(hm($0.start))–\(hm($0.end))" },
            reason: reason, reasonWarns: w != nil && reason != nil,
            agreement: plan.agreement.map { Copy.agreementText($0, site: site) },
            agreementWarns: plan.agreement.map(Copy.agreementWarns) ?? false,
            slots: Bezel.slots(darkness: plan.darkSpan, windows: plan.windows, primary: plan.primary, hours: plan.darkHours, site: site),
            bezelLabel: Copy.bezelLabel(plan, site: site),
            bars: Planner.clearSkyBars(plan: plan, site: site), barsLabel: Copy.barsLabel(plan: plan, site: site),
            targets: picks.prefix(3).map { t in
                WidgetTarget(id: t.id, catalogueID: t.catalogueID, name: t.commonName ?? t.typeName,
                             best: "Best \(hm(t.peakTime)) · \(Int(t.peakAltDeg.rounded()))° up", group: t.group)
            },
            tomorrow: w == nil && !noDarkness ? tomorrow?.primary.map { "Tomorrow \(hm($0.start))–\(hm($0.end))" } : nil,
            notify: Copy.notifyLabel(plan, site: site, settings: alerts))
    }

    /// "Forecast 7 h old" once the snapshot's forecast is more than six hours old at `now` (the alerts' stale rule); else nil.
    public func staleText(now: Date) -> String? {
        let age = now.timeIntervalSince(fetchedAt)
        return age > 6 * 3600 ? "Forecast \(Int(age / 3600)) h old" : nil
    }
}
