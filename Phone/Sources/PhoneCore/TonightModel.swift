import Foundation
import SkyCore

/// The six tiles under tonight's verdict, worked out the way the Mac's popover does it (same SkyCore helpers), as text
/// ready to draw. Nil: nothing to say (no seeing data, say), and the tile shows a dash.
public struct TonightTiles: Equatable, Sendable {
    public var dark: String
    public var moon: String
    public var moonLine: String?
    public var seeing: String?
    public var wind: String?
    /// "Frost likely" when the night drops to 0 °C, else "Dew risk".
    public var dewLabel: String
    public var dew: String?
    public var dewHint: String?
    public var transparency: String?

    public static func make(plan: NightPlan, site: Site) -> TonightTiles {
        let dark = plan.darkSpan.map { "\(Copy.hhmm($0.start, site: site))–\(Copy.hhmm($0.end, site: site))" } ?? "None"
        let moon = Planner.moonTonight(plan)
        let pct = "\(Int((plan.moonIllumination * 100).rounded()))%"
        let winds = plan.darkHours.compactMap(\.windKmh)
        let dew = Planner.dewRisk(plan.darkHours)
        let frost = plan.darkHours.compactMap(\.tempC).min().map { $0 <= 0 } ?? false
        return TonightTiles(
            dark: dark,
            moon: moon == .down ? "Down" : pct,
            moonLine: moon.flatMap { $0 == .down ? "tonight" : Copy.moonText($0, site: site) },
            seeing: Copy.seeingText(plan.darkHours),
            wind: winds.isEmpty ? nil : String(format: "%.0f km/h", winds.reduce(0, +) / Double(winds.count)),
            dewLabel: frost ? "Frost likely" : "Dew risk",
            dew: dew?.displayName,
            dewHint: dew == .high ? "Dew heater advised" : nil,
            transparency: Copy.transparencyText(plan.darkHours))
    }
}

/// How old a forecast is, in words: "just now", "12 min ago", "3 hours ago". The page shows it so a stale answer is never
/// mistaken for a fresh one (offline in a dead zone, or a refresh that failed).
public struct ForecastAge: Equatable, Sendable {
    public let seconds: TimeInterval

    public init(fetchedAt: Date, now: Date) { seconds = max(0, now.timeIntervalSince(fetchedAt)) }

    public var text: String {
        let m = Int(seconds / 60)
        if m < 2 { return "just now" }
        if m < 60 { return "\(m) min ago" }
        let h = m / 60
        if h < 48 { return h == 1 ? "1 hour ago" : "\(h) hours ago" }
        let d = h / 24
        return "\(d) days ago"
    }

    public func isOlder(than interval: TimeInterval) -> Bool { seconds > interval }
}

/// Everything the Tonight page draws, built once per refresh from the plan SkyCore works out. The verdict, bezel, bars,
/// best three and the source line are SkyCore's own `WidgetSnapshot` (the Mac's widget draws from the same type), so the
/// wording is the Mac's wording.
public struct TonightModel: Equatable, Sendable {
    public var snapshot: WidgetSnapshot
    public var tiles: TonightTiles
    /// "Apple Weather" or "Open-Meteo": which service drove the verdict.
    public var source: String
    /// Apple's mark and legal page, supplied only when Apple Weather answered: the footer shows the mark, and the mark is the link.
    public var markURL: String?
    public var legalURL: String?
    public var fetchedAt: Date

    public var siteName: String { snapshot.siteName }

    public static func make(plan: NightPlan, tomorrow: NightPlan?, forecast: Forecast, site: Site, config: Config,
                            copy: Copy = Copy()) -> TonightModel {
        let source = forecast.cloudSource ?? "Open-Meteo"
        var snap = WidgetSnapshot.make(plan: plan, tomorrow: tomorrow, fetchedAt: forecast.fetchedAt, site: site, rule: config.goRule,
                                       bright: config.brightNights, alerts: config.alerts, copy: copy, source: source)
        snap.weatherLegalURL = forecast.attributionLegalURL
        return TonightModel(snapshot: snap, tiles: TonightTiles.make(plan: plan, site: site), source: source,
                            markURL: forecast.attributionMarkURL, legalURL: forecast.attributionLegalURL, fetchedAt: forecast.fetchedAt)
    }
}
