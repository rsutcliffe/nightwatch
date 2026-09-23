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
    public var maxCloudPct: Int
    public init(darkHours: [HourlyConditions], windows: [ClearWindow], darkness: (Date, Date)?, moonIllumination: Double, moonAboveFraction: Double, maxCloudPct: Int = 25) {
        self.darkHours = darkHours; self.windows = windows; self.darkness = darkness
        self.moonIllumination = moonIllumination; self.moonAboveFraction = moonAboveFraction
        self.maxCloudPct = maxCloudPct
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
        let clearHours = Double(s.darkHours.filter { $0.cloudTotal <= s.maxCloudPct }.count)
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

public struct FieldOfView: Codable, Equatable, Sendable {
    public var widthDeg: Double
    public var heightDeg: Double
    public init(widthDeg: Double, heightDeg: Double) { self.widthDeg = widthDeg; self.heightDeg = heightDeg }
}

public enum FrameFit: String, Codable, Sendable { case fits, small, mosaic }

public struct RankedTarget: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let group: TargetGroup
    public let raHours: Double
    public let decDeg: Double
    public let sizeArcmin: Double?
    public let magnitude: Double?
    public let fit: FrameFit
    public let peakAltDeg: Double
    public let peakTime: Date
    public let moonSepDeg: Double
    public let moonWashed: Bool
    public let visibleFraction: Double
}

public struct NightPlan: Codable, Equatable, Sendable {
    public let night: Night
    public let windows: [ClearWindow]
    public let primary: ClearWindow?
    public let score: Int
    public let qualifies: Bool
    public let moonIllumination: Double
    public let moonRise: Date?
    public let moonSet: Date?
    public let darkHours: [HourlyConditions]
    public let targets: [RankedTarget]
    public let best: [RankedTarget]
    public let seeingAvailable: Bool
}

extension Planner {
    public static func frameFit(sizeArcmin: Double?, fov: FieldOfView) -> FrameFit {
        guard let s = sizeArcmin, s >= 5 else { return .small }
        let deg = s / 60
        if deg <= max(fov.widthDeg, fov.heightDeg) { return .fits }
        return .mosaic
    }

    /// Sample a window every 30 minutes; returns fraction of samples at or above `minAlt`, the peak altitude and its time.
    static func track(raHours: Double, decDeg: Double, window: ClearWindow, site: Site, minAlt: Double) -> (fraction: Double, peakAlt: Double, peakTime: Date) {
        var t = window.start
        var above = 0, n = 0
        var peak = -90.0, peakTime = window.start
        while t <= window.end {
            let alt = Ephemeris.altAz(raHours: raHours, decDeg: decDeg, at: t, site: site).alt
            n += 1
            if alt >= minAlt { above += 1 }
            if alt > peak { peak = alt; peakTime = t }
            t = t.addingTimeInterval(1800)
        }
        return (n == 0 ? 0 : Double(above) / Double(n), peak, peakTime)
    }

    public static func rank(catalog: Catalog, constellations: [Constellation], window: ClearWindow, site: Site, fov: FieldOfView, rule: GoRule) -> [RankedTarget] {
        let moon = Ephemeris.moon(at: window.midpoint, site: site)
        let moonUp = moon.position.altDeg > 0 && moon.illumination > 0.1
        var out: [RankedTarget] = []

        for o in catalog.objects {
            guard let mag = o.magnitude, mag <= 12 else { continue }
            let tr = track(raHours: o.raHours, decDeg: o.decDeg, window: window, site: site, minAlt: rule.minAltitudeDeg)
            guard tr.fraction >= 0.5 else { continue }
            let sep = Ephemeris.separationDeg(ra1Hours: o.raHours, dec1Deg: o.decDeg, ra2Hours: moon.position.raHours, dec2Deg: moon.position.decDeg)
            out.append(RankedTarget(id: o.id, name: o.displayName, subtitle: "\(o.typeCode) in \(o.constellation)", group: o.group,
                                    raHours: o.raHours, decDeg: o.decDeg, sizeArcmin: o.majAxisArcmin, magnitude: mag,
                                    fit: frameFit(sizeArcmin: o.majAxisArcmin, fov: fov), peakAltDeg: tr.peakAlt, peakTime: tr.peakTime,
                                    moonSepDeg: sep, moonWashed: moonUp && sep < 30, visibleFraction: tr.fraction))
        }

        for p in Planet.allCases {
            let pos = Ephemeris.planet(p, at: window.midpoint, site: site)
            let tr = track(raHours: pos.raHours, decDeg: pos.decDeg, window: window, site: site, minAlt: rule.minAltitudeDeg)
            guard tr.fraction >= 0.5 else { continue }
            let sep = Ephemeris.separationDeg(ra1Hours: pos.raHours, dec1Deg: pos.decDeg, ra2Hours: moon.position.raHours, dec2Deg: moon.position.decDeg)
            out.append(RankedTarget(id: "planet-\(p.rawValue)", name: p.displayName, subtitle: "Planet", group: .planets,
                                    raHours: pos.raHours, decDeg: pos.decDeg, sizeArcmin: nil, magnitude: pos.magnitude, fit: .small,
                                    peakAltDeg: tr.peakAlt, peakTime: tr.peakTime, moonSepDeg: sep, moonWashed: false, visibleFraction: tr.fraction))
        }
        if moon.illumination > 0.05 {
            let tr = track(raHours: moon.position.raHours, decDeg: moon.position.decDeg, window: window, site: site, minAlt: 10)
            if tr.fraction > 0 {
                out.append(RankedTarget(id: "moon", name: "Moon", subtitle: "\(Int((moon.illumination * 100).rounded()))% illuminated", group: .planets,
                                        raHours: moon.position.raHours, decDeg: moon.position.decDeg, sizeArcmin: 31, magnitude: nil,
                                        fit: frameFit(sizeArcmin: 31, fov: fov), peakAltDeg: tr.peakAlt, peakTime: tr.peakTime,
                                        moonSepDeg: 0, moonWashed: false, visibleFraction: tr.fraction))
            }
        }

        for c in constellations {
            let tr = track(raHours: c.raHours, decDeg: c.decDeg, window: window, site: site, minAlt: 20)
            guard tr.fraction >= 0.5 else { continue }
            out.append(RankedTarget(id: c.id, name: c.name, subtitle: "Constellation", group: .constellations,
                                    raHours: c.raHours, decDeg: c.decDeg, sizeArcmin: nil, magnitude: nil, fit: .mosaic,
                                    peakAltDeg: tr.peakAlt, peakTime: tr.peakTime, moonSepDeg: 0, moonWashed: false, visibleFraction: tr.fraction))
        }

        let fitOrder: [FrameFit: Int] = [.fits: 0, .small: 1, .mosaic: 2]
        return out.sorted {
            if $0.group != $1.group { return TargetGroup.allCases.firstIndex(of: $0.group)! < TargetGroup.allCases.firstIndex(of: $1.group)! }
            if $0.moonWashed != $1.moonWashed { return !$0.moonWashed }
            if fitOrder[$0.fit]! != fitOrder[$1.fit]! { return fitOrder[$0.fit]! < fitOrder[$1.fit]! }
            if $0.peakAltDeg != $1.peakAltDeg { return $0.peakAltDeg > $1.peakAltDeg }
            return ($0.magnitude ?? 99) < ($1.magnitude ?? 99)
        }
    }

    /// Top three across groups, at most one per group, deep sky first.
    static func best(from ranked: [RankedTarget]) -> [RankedTarget] {
        var picked: [RankedTarget] = []
        for g in [TargetGroup.nebulae, .galaxies, .clusters, .planets] {
            if let t = ranked.first(where: { $0.group == g && !$0.moonWashed }) { picked.append(t) }
            if picked.count == 3 { break }
        }
        return picked
    }

    public static func plan(night: Night, forecast: Forecast, catalog: Catalog, constellations: [Constellation], site: Site, fov: FieldOfView, rule: GoRule) -> NightPlan {
        let dark = darkHours(forecast.hours, night: night)
        var windows: [ClearWindow] = []
        if let ds = night.darkStart, let de = night.darkEnd {
            windows = Planner.windows(hours: forecast.hours, darkStart: ds, darkEnd: de, rule: rule)
        }
        let primary = windows.max { $0.hours < $1.hours }
        let moonMid = Ephemeris.moon(at: primary?.midpoint ?? night.darkStart ?? night.sunset, site: site)
        var aboveFraction = 0.0
        if let ds = night.darkStart, let de = night.darkEnd {
            var t = ds, n = 0, up = 0
            while t <= de { n += 1; if Ephemeris.moon(at: t, site: site).position.altDeg > 0 { up += 1 }; t = t.addingTimeInterval(3600) }
            aboveFraction = n == 0 ? 0 : Double(up) / Double(n)
        }
        let darkness: (Date, Date)? = (night.darkStart != nil && night.darkEnd != nil) ? (night.darkStart!, night.darkEnd!) : nil
        let score = Planner.score(ScoreInputs(darkHours: dark, windows: windows, darkness: darkness,
                                              moonIllumination: moonMid.illumination, moonAboveFraction: aboveFraction, maxCloudPct: rule.maxCloudPct))
        let targets = primary.map { rank(catalog: catalog, constellations: constellations, window: $0, site: site, fov: fov, rule: rule) } ?? []
        return NightPlan(night: night, windows: windows, primary: primary, score: score, qualifies: primary != nil,
                         moonIllumination: moonMid.illumination, moonRise: moonMid.rise, moonSet: moonMid.set,
                         darkHours: dark, targets: targets, best: best(from: targets), seeingAvailable: dark.contains { $0.seeing != nil })
    }
}
