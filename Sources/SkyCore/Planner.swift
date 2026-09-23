import Foundation

public struct GoRule: Codable, Equatable, Sendable {
    public var minHours: Double
    public var maxCloudPct: Int
    public var minAltitudeDeg: Double
    public init(minHours: Double = 3, maxCloudPct: Int = 25, minAltitudeDeg: Double = 30) {
        self.minHours = minHours; self.maxCloudPct = maxCloudPct; self.minAltitudeDeg = minAltitudeDeg
    }
}

public struct ClearWindow: Codable, Equatable, Sendable {
    public var start: Date
    public var end: Date
    public init(start: Date, end: Date) { self.start = start; self.end = end }
    public var hours: Double { end.timeIntervalSince(start) / 3600 }
    public var midpoint: Date { start.addingTimeInterval(end.timeIntervalSince(start) / 2) }
}

public struct ScoreInputs {
    public var darkHours: [HourlyConditions]
    public var windows: [ClearWindow]
    public var darkness: (Date, Date)?
    public var moonIllumination: Double
    public var moonAboveFraction: Double
    public init(darkHours: [HourlyConditions], windows: [ClearWindow], darkness: (Date, Date)?, moonIllumination: Double, moonAboveFraction: Double) {
        self.darkHours = darkHours; self.windows = windows; self.darkness = darkness
        self.moonIllumination = moonIllumination; self.moonAboveFraction = moonAboveFraction
    }
}

public enum Planner {
    /// Hourly samples that overlap the night's darkness. A sample at time t covers [t, t + 1 h).
    public static func darkHours(_ hours: [HourlyConditions], night: Night) -> [HourlyConditions] {
        guard let ds = night.darkStart, let de = night.darkEnd else { return [] }
        return hours.filter { $0.time.addingTimeInterval(3600) > ds && $0.time < de }.sorted { $0.time < $1.time }
    }

    /// Maximal runs of consecutive hourly samples inside darkness with cloud at or under the rule, at least `minHours` long.
    public static func windows(hours: [HourlyConditions], darkStart: Date, darkEnd: Date, rule: GoRule) -> [ClearWindow] {
        let dark = hours.filter { $0.time.addingTimeInterval(3600) > darkStart && $0.time < darkEnd }.sorted { $0.time < $1.time }
        var out: [ClearWindow] = []
        var run: [HourlyConditions] = []
        func flush() {
            guard let f = run.first, let l = run.last else { return }
            let w = ClearWindow(start: max(f.time, darkStart), end: min(l.time.addingTimeInterval(3600), darkEnd))
            if w.hours >= rule.minHours { out.append(w) }
            run = []
        }
        for h in dark {
            let clear = h.cloudTotal <= rule.maxCloudPct
            let contiguous = run.last.map { h.time.timeIntervalSince($0.time) == 3600 } ?? true
            if clear && contiguous { run.append(h) } else { flush(); if clear { run = [h] } }
        }
        flush()
        return out
    }

    /// 0–100. Cloud 60 (75 without seeing data), Moon 15, seeing + transparency 15, wind and dew 10.
    public static func score(_ s: ScoreInputs) -> Int {
        guard let (ds, de) = s.darkness, de > ds, !s.darkHours.isEmpty else { return 0 }
        let clearHours = Double(s.darkHours.filter { $0.cloudTotal <= 25 }.count)
        let totalHours = Double(s.darkHours.count)
        let clearFraction = min(1, clearHours / totalHours)
        let primaryHours = s.windows.map(\.hours).max() ?? 0
        let contiguity = clearHours > 0 ? min(1, primaryHours / clearHours) : 0
        let seeingSamples = s.darkHours.compactMap(\.seeing)
        let transSamples = s.darkHours.compactMap(\.transparency)
        let hasSeeing = !seeingSamples.isEmpty && !transSamples.isEmpty
        let cloudWeight = hasSeeing ? 60.0 : 75.0
        let cloudScore = cloudWeight * clearFraction * (0.5 + 0.5 * contiguity)
        let moonScore = 15 * (1 - s.moonIllumination * s.moonAboveFraction)
        var seeingScore = 0.0
        if hasSeeing {
            let avgS = Double(seeingSamples.reduce(0, +)) / Double(seeingSamples.count)
            let avgT = Double(transSamples.reduce(0, +)) / Double(transSamples.count)
            seeingScore = 7.5 * (1 - (avgS - 1) / 7) + 7.5 * (1 - (avgT - 1) / 7)
        }
        let winds = s.darkHours.compactMap(\.windKmh)
        let avgWind = winds.isEmpty ? 0 : winds.reduce(0, +) / Double(winds.count)
        let windPenalty = min(1, max(0, (avgWind - 10) / 30)) * 5      // no penalty under 10 km/h, full at 40
        let spreads = s.darkHours.compactMap { h -> Double? in
            guard let t = h.tempC, let d = h.dewPointC else { return nil }
            return t - d
        }
        let minSpread = spreads.min() ?? 10
        let dewPenalty: Double = minSpread < 2 ? 5 : (minSpread < 4 ? 2.5 : 0)
        let total = cloudScore + moonScore + seeingScore + (10 - windPenalty - dewPenalty)
        return max(0, min(100, Int(total.rounded())))
    }
}
