import Foundation

public struct AlertSettings: Codable, Equatable, Sendable {
    public var headsUp = true
    public var tomorrowPreview = true
    public var preWindowMinutes = 30
    public var cancelOnDowngrade = true
    public var quietStartHour = 0
    public var quietEndHour = 7
    public init() {}
}

public struct AlertState: Codable, Equatable, Sendable {
    public enum Stage: String, Codable, Sendable { case idle, previewSent, headsUpSent, goSent, cancelled, done }
    public var nightKey: String
    public var stage: Stage
    /// The plan mode the current stage was reached under; nil in files from 0.3.0 and earlier.
    public var mode: PlanMode?
    public init(nightKey: String, stage: Stage, mode: PlanMode? = nil) { self.nightKey = nightKey; self.stage = stage; self.mode = mode }
}

public struct AlertNotification: Equatable, Sendable {
    public enum Kind: Sendable { case headsUp, tomorrowPreview, go, cancel, aurora }
    public let kind: Kind
    public let title: String
    public let body: String
}

public enum AlertEngine {
    static let staleAfter: TimeInterval = 6 * 3600

    public static func inQuietHours(_ date: Date, site: Site, settings: AlertSettings) -> Bool {
        let h = site.calendar.component(.hour, from: date)
        let a = settings.quietStartHour, b = settings.quietEndHour
        if a == b { return false }
        return a < b ? (h >= a && h < b) : (h >= a || h < b)
    }

    public static func step(now: Date, tonight: NightPlan, tomorrow: NightPlan?, state: AlertState?, settings: AlertSettings,
                            forecastFetchedAt: Date, site: Site, copy: Copy) -> (notification: AlertNotification?, state: AlertState) {
        var s = (state?.nightKey == tonight.night.key) ? state! : AlertState(nightKey: tonight.night.key, stage: .idle)
        // Switching bright nights on or off mid-evening changes the plan, not the sky: start the night's alerts afresh
        // in the new mode rather than sending "Stand down. Clouds moving in".
        if let m = s.mode, m != tonight.mode { s = AlertState(nightKey: tonight.night.key, stage: .idle) }
        guard now.timeIntervalSince(forecastFetchedAt) <= staleAfter else { return (nil, s) }

        let headsUpAt = tonight.night.sunset.addingTimeInterval(-3600)
        let goAt = tonight.primary?.start.addingTimeInterval(-Double(settings.preWindowMinutes) * 60)
        var note: AlertNotification? = nil

        func window(_ p: NightPlan) -> (String, Double) {
            (Copy.hhmm(p.primary!.start, site: site), p.primary!.hours)
        }
        /// Fires go when tonight qualifies and the nudge time has passed; true when it fired.
        func goIfDue() -> Bool {
            guard let g = goAt, tonight.qualifies, now >= g else { return false }
            note = AlertNotification(kind: .go, title: tonight.mode == .bright ? copy.brightGoTitle(windowStart: window(tonight).0) : copy.goTitle(windowStart: window(tonight).0), body: copy.notificationBody(plan: tonight, site: site))
            s.stage = .goSent
            return true
        }

        switch s.stage {
        case .idle:
            // If the first tick already lands at or after goAt, go fires straight from idle and heads-up
            // is skipped: the go notification carries the same window and targets, so a heads-up a minute
            // earlier would just be a second banner for no new information.
            if !goIfDue(), now >= headsUpAt {
                if tonight.qualifies, settings.headsUp {
                    let (start, hours) = window(tonight)
                    note = AlertNotification(kind: .headsUp, title: tonight.mode == .bright ? copy.brightHeadsUpTitle(windowStart: start, targets: tonight.brightTargets) : copy.headsUpTitle(windowStart: start, hours: hours), body: copy.notificationBody(plan: tonight, site: site))
                    s.stage = .headsUpSent
                } else if !tonight.qualifies, let t = tomorrow, t.qualifies, settings.tomorrowPreview {
                    note = AlertNotification(kind: .tomorrowPreview, title: t.mode == .bright ? copy.brightTomorrowTitle(hours: t.primary!.hours) : copy.tomorrowTitle(hours: t.primary!.hours), body: copy.notificationBody(plan: t, site: site, agreement: false))
                    s.stage = .previewSent
                }
                // A night that fails at sunset stays idle: the forecast can still clear later and fire go.
            }
        case .previewSent:
            // Preview already sent for tomorrow; tonight can still clear late. Go only, never a second preview or heads-up.
            _ = goIfDue()
        case .headsUpSent, .cancelled:
            // cancelled recovers straight to go when the forecast clears again; no second heads-up
            if !tonight.qualifies, s.stage == .headsUpSent, settings.cancelOnDowngrade {
                note = AlertNotification(kind: .cancel, title: copy.cancelTitle, body: copy.noWindow)
                s.stage = .cancelled
            } else {
                _ = goIfDue()
            }
        case .goSent:
            if !tonight.qualifies, settings.cancelOnDowngrade {
                note = AlertNotification(kind: .cancel, title: copy.cancelTitle, body: copy.noWindow)
                s.stage = .cancelled
            } else if now >= (tonight.primary?.end ?? tonight.night.sunrise) {
                s.stage = .done
            }
        case .done:
            break
        }

        if note != nil, inQuietHours(now, site: site, settings: settings) { note = nil }   // dropped, not deferred
        if s.stage != .idle, s.stage != .previewSent { s.mode = tonight.mode }
        return (note, s)
    }
}
