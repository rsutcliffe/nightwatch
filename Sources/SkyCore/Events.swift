import Foundation

public struct MeteorShower: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let startMonth: Int, startDay: Int, endMonth: Int, endDay: Int, peakMonth: Int, peakDay: Int
    public let zhr: Int
    public let raHours: Double
    public let decDeg: Double
    public let parent: String
    public let velocityKms: Int
}

public enum MeteorShowers {
    public static func bundled() throws -> [MeteorShower] {
        guard let url = Bundle.module.url(forResource: "meteor-showers", withExtension: "json", subdirectory: "Resources/events") else {
            throw CatalogError.missingResource("meteor-showers")
        }
        return try JSONDecoder().decode([MeteorShower].self, from: Data(contentsOf: url))
    }

    /// Day-of-year comparison that wraps across the new year.
    static func inRange(month: Int, day: Int, shower s: MeteorShower) -> Bool {
        let d = month * 100 + day, a = s.startMonth * 100 + s.startDay, b = s.endMonth * 100 + s.endDay
        return a <= b ? (d >= a && d <= b) : (d >= a || d <= b)
    }

    public static func active(on date: Date, calendar: Calendar, showers: [MeteorShower]) -> [MeteorShower] {
        let c = calendar.dateComponents([.month, .day], from: date)
        return showers.filter { inRange(month: c.month!, day: c.day!, shower: $0) }
    }

    public static func isPeak(_ s: MeteorShower, on date: Date, calendar: Calendar) -> Bool {
        let c = calendar.dateComponents([.month, .day], from: date)
        return c.month == s.peakMonth && c.day == s.peakDay
    }
}

public enum SkyEventKind: String, Codable, Sendable { case meteorShower, lunarEclipse, solarEclipse, conjunction, comet, issPass }

public struct SkyEvent: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let kind: SkyEventKind
    public let title: String
    public var detail: String
    public let time: Date
    public let endTime: Date?
    public let raHours: Double?
    public let decDeg: Double?
    public init(id: String, kind: SkyEventKind, title: String, detail: String, time: Date, endTime: Date?, raHours: Double?, decDeg: Double?) {
        self.id = id; self.kind = kind; self.title = title; self.detail = detail; self.time = time; self.endTime = endTime
        self.raHours = raHours; self.decDeg = decDeg
    }
    /// When to look (v1.0.1): a shower's best hour, the ISS's peak, a comet's or a pair's highest point. Nil: `time`.
    public var best: Date? = nil
    /// The event page's rows, e.g. ("Radiant", "Taurus, highest at 02:10, 52° up").
    public var facts: [EventFact] = []
    /// True when `best` (or `time`) is in a clear hour of tonight's forecast, false in a cloudy one, nil outside it.
    public var clear: Bool? = nil
    /// A conjunction's separation, for "does it fit my field of view".
    public var separationDeg: Double? = nil
    /// The time to show: `best`, else `time`.
    public var when: Date { best ?? time }
}

public struct EventFact: Codable, Equatable, Sendable {
    public let label: String
    public let value: String
    public init(_ label: String, _ value: String) { self.label = label; self.value = value }
}

public enum Events {
    /// Tonight's darkness, or sunset to sunrise when there is none.
    static func darkness(_ night: Night) -> (start: Date, end: Date) {
        (night.darkStart ?? night.sunset, night.darkEnd ?? night.sunrise)
    }

    /// The highest point of a fixed sky position between `from` and `to`, sampled every 15 minutes.
    static func highest(raHours: Double, decDeg: Double, from: Date, to: Date, site: Site) -> (time: Date, alt: Double) {
        var best = (time: from, alt: -90.0)
        var t = from
        while t <= to {
            let alt = Ephemeris.altAz(raHours: raHours, decDeg: decDeg, at: t, site: site).alt
            if alt > best.alt { best = (t, alt) }
            t = t.addingTimeInterval(900)
        }
        return best
    }

    /// "5 November"
    static func day(_ d: Date, site: Site) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB"); f.timeZone = site.timeZone; f.dateFormat = "d MMMM"
        return f.string(from: d)
    }

    /// What the Moon does to faint things at `date`.
    static func moonNote(at date: Date, site: Site, hides: String) -> String {
        let m = Ephemeris.moon(at: date, site: site)
        let lit = Int((m.illumination * 100).rounded())
        if m.position.altDeg <= 0 { return "Below the horizon at \(Copy.hhmm(date, site: site)) (\(lit)% lit)" }
        let up = "\(lit)% lit and \(Int(m.position.altDeg.rounded()))° up at \(Copy.hhmm(date, site: site))"
        return m.illumination > 0.5 ? "\(up): it will \(hides)" : up
    }

    /// The date of a shower's peak nearest `date`, and the whole days from `date` to it (negative when past).
    static func peak(_ s: MeteorShower, near date: Date, calendar cal: Calendar) -> (date: Date, days: Int) {
        let start = cal.startOfDay(for: date)
        let y = cal.component(.year, from: date)
        let candidates = [y - 1, y, y + 1].compactMap { cal.date(from: DateComponents(year: $0, month: s.peakMonth, day: s.peakDay)) }
        let p = candidates.min { abs($0.timeIntervalSince(start)) < abs($1.timeIntervalSince(start)) }!
        return (p, cal.dateComponents([.day], from: start, to: p).day!)
    }

    public static func showers(night: Night, site: Site, showers: [MeteorShower]) -> [SkyEvent] {
        let cal = site.calendar
        let dark = darkness(night)
        return MeteorShowers.active(on: night.localDate, calendar: cal, showers: showers).map { s in
            // Tonight's night runs into tomorrow's date, so a peak on either counts as tonight.
            let (peakDate, days) = peak(s, near: night.localDate, calendar: cal)
            let peakText: String
            switch days {
            case 0, 1: peakText = "At peak tonight"
            case 2...: peakText = "Peak \(day(peakDate, site: site)), in \(days) days"
            default: peakText = "Past its peak (\(day(peakDate, site: site)))"
            }
            let top = highest(raHours: s.raHours, decDeg: s.decDeg, from: dark.start, to: dark.end, site: site)
            let where_ = Ephemeris.constellation(raHours: s.raHours, decDeg: s.decDeg).name
            let up = top.alt > 0
            var e = SkyEvent(id: "shower-\(s.id)", kind: .meteorShower, title: s.name,
                             detail: up ? "\(peakText) · radiant in \(where_), best \(Copy.hhmm(top.time, site: site))"
                                        : "\(peakText) · radiant in \(where_), below the horizon tonight",
                             time: dark.start, endTime: dark.end, raHours: s.raHours, decDeg: s.decDeg)
            e.best = up ? top.time : nil
            let speed = s.velocityKms >= 55 ? "fast" : s.velocityKms <= 30 ? "slow" : "medium"
            e.facts = [
                EventFact("Peak", days >= 0 && days <= 1 ? "Tonight, ZHR \(s.zhr)" : "\(day(peakDate, site: site)), ZHR \(s.zhr)"),
                EventFact("Radiant", up ? "\(where_), highest at \(Copy.hhmm(top.time, site: site)), \(Int(top.alt.rounded()))° up"
                                        : "\(where_), below the horizon all night"),
            ]
            // The ZHR assumes the radiant overhead and a perfectly dark sky; the rate falls with the radiant's height.
            if up {
                let rate = max(1, Int((Double(s.zhr) * sin(top.alt * .pi / 180)).rounded()))
                e.facts.append(EventFact("At peak, from here", "Up to about \(rate) an hour, under a dark, moonless sky"))
                e.facts.append(EventFact("Moon", moonNote(at: top.time, site: site, hides: "hide all but the brightest meteors")))
            }
            e.facts += [EventFact("Speed", "\(s.velocityKms) km/s (\(speed))"), EventFact("Parent", s.parent)]
            return e
        }
    }

    public static func eclipses(after date: Date, site: Site, withinDays: Int) -> [SkyEvent] {
        let limit = date.addingTimeInterval(Double(withinDays) * 86_400)
        var out: [SkyEvent] = []
        func times(_ begin: Date?, _ peak: Date, _ end: Date?) -> [EventFact] {
            [begin.map { EventFact("Begins", "\(day($0, site: site)) \(Copy.hhmm($0, site: site))") },
             EventFact("Peak", "\(day(peak, site: site)) \(Copy.hhmm(peak, site: site))"),
             end.map { EventFact("Ends", "\(day($0, site: site)) \(Copy.hhmm($0, site: site))") }].compactMap { $0 }
        }
        if let l = Ephemeris.nextLunarEclipse(after: date), l.peak <= limit {
            var e = SkyEvent(id: "lunar-\(Int(l.peak.timeIntervalSince1970))", kind: .lunarEclipse,
                             title: "\(l.kind.rawValue.capitalized) lunar eclipse", detail: "Peak obscuration \(Int((l.obscuration * 100).rounded()))%",
                             time: l.peak, endTime: l.end, raHours: nil, decDeg: nil)
            let alt = Ephemeris.moon(at: l.peak, site: site).position.altDeg
            e.facts = times(l.begin, l.peak, l.end) + [EventFact("Moon at peak", alt > 0 ? "\(Int(alt.rounded()))° up"
                                                                                       : "Below the horizon: not visible from \(site.name)")]
            if alt <= 0 { e.detail += " · Moon below the horizon here" }
            out.append(e)
        }
        if let s = Ephemeris.nextLocalSolarEclipse(after: date, site: site), s.peak <= limit {
            var e = SkyEvent(id: "solar-\(Int(s.peak.timeIntervalSince1970))", kind: .solarEclipse,
                             title: "\(s.kind.rawValue.capitalized) solar eclipse from \(site.name)", detail: "Peak obscuration \(Int((s.obscuration * 100).rounded()))%",
                             time: s.peak, endTime: s.partialEnd, raHours: nil, decDeg: nil)
            let alt = Ephemeris.sunAltitude(at: s.peak, site: site)
            e.facts = times(s.partialBegin, s.peak, s.partialEnd) + [EventFact("Sun at peak", "\(Int(alt.rounded()))° up"),
                      EventFact("Safety", "Never look at the Sun, or point a telescope or camera at it, without a certified solar filter.")]
            out.append(e)
        }
        return out
    }

    /// Pairs among the Moon and the seven planets closer than `maxSeparationDeg` at `date`. With `night`, each gets the
    /// pair's highest point in darkness; with `fov`, whether both fit in the frame.
    public static func conjunctions(at date: Date, site: Site, maxSeparationDeg: Double, night: Night? = nil, fov: FieldOfView? = nil) -> [SkyEvent] {
        var bodies: [(String, BodyPosition)] = Planet.allCases.map { ($0.displayName, Ephemeris.planet($0, at: date, site: site)) }
        bodies.append(("Moon", Ephemeris.moon(at: date, site: site).position))
        var out: [(sep: Double, event: SkyEvent)] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let (a, pa) = bodies[i], (b, pb) = bodies[j]
                let sep = Ephemeris.separationDeg(ra1Hours: pa.raHours, dec1Deg: pa.decDeg, ra2Hours: pb.raHours, dec2Deg: pb.decDeg)
                guard sep <= maxSeparationDeg else { continue }
                var detail = String(format: "%.1f° apart", sep)
                var e = SkyEvent(id: "conj-\(a)-\(b)", kind: .conjunction, title: "\(a) near \(b)", detail: detail, time: date, endTime: nil,
                                 raHours: pa.raHours, decDeg: pa.decDeg)
                e.separationDeg = sep
                e.facts = [EventFact("Separation", String(format: "%.1f°", sep))]
                if let f = fov {
                    // Both in one frame with a little margin: the longer side, less a tenth.
                    let fits = sep <= max(f.widthDeg, f.heightDeg) * 0.9
                    detail += fits ? " · fits your field of view" : " · wider than your field of view"
                    e.facts.append(EventFact("Your field of view", String(format: "%g × %g°: ", f.widthDeg, f.heightDeg)
                                             + (fits ? "both fit in one frame" : "too narrow for both at once")))
                }
                if let n = night {
                    let d = darkness(n)
                    let top = highest(raHours: pa.raHours, decDeg: pa.decDeg, from: d.start, to: d.end, site: site)
                    if top.alt > 0 {
                        e.best = top.time
                        detail += " · best \(Copy.hhmm(top.time, site: site))"
                        e.facts.append(EventFact("Best", "\(Copy.hhmm(top.time, site: site)), \(Int(top.alt.rounded()))° up"))
                    } else {
                        e.facts.append(EventFact("Best", "Below the horizon in darkness tonight"))
                    }
                }
                e.detail = detail
                out.append((sep, e))
            }
        }
        return out.sorted { $0.sep < $1.sep }.map(\.event)
    }

    /// A comet tonight, from its position now (`pos`) and a week later (`later`, for the trend). Nil when it never gets
    /// above `minAlt` in darkness.
    public static func comet(designation: String, pos: CometPosition, later: CometPosition?, night: Night, site: Site, minAlt: Double = 20) -> SkyEvent? {
        let d = darkness(night)
        let top = highest(raHours: pos.raHours, decDeg: pos.decDeg, from: d.start, to: d.end, site: site)
        guard top.alt > minAlt else { return nil }
        let where_ = Ephemeris.constellation(raHours: pos.raHours, decDeg: pos.decDeg).name
        var e = SkyEvent(id: "comet-\(designation)", kind: .comet, title: designation,
                         detail: String(format: "mag %.1f · in %@ · best %@, %.0f° up", pos.magnitude, where_, Copy.hhmm(top.time, site: site), top.alt),
                         time: d.start, endTime: d.end, raHours: pos.raHours, decDeg: pos.decDeg)
        e.best = top.time
        var mag = String(format: "%.1f", pos.magnitude)
        if let l = later {
            let change = l.magnitude - pos.magnitude   // smaller magnitude is brighter
            mag += abs(change) < 0.1 ? ", steady" : String(format: ", %@ (%.1f in a week)", change < 0 ? "brightening" : "fading", l.magnitude)
        }
        e.facts = [EventFact("Magnitude", mag), EventFact("Where", where_),
                   EventFact("Best", "\(Copy.hhmm(top.time, site: site)), \(Int(top.alt.rounded()))° up"),
                   EventFact("Distance", String(format: "%.2f AU from Earth, %.2f AU from the Sun", pos.deltaAU, pos.rAU)),
                   EventFact("Moon", moonNote(at: top.time, site: site, hides: "wash out its faint tail"))]
        return e
    }

    /// An ISS pass: where it rises, peaks and sets.
    public static func issPass(_ p: SatellitePass, site: Site) -> SkyEvent {
        func dir(_ az: Double?) -> String { az.map { " \(Geo.compass($0))" } ?? "" }
        let highest = "\(Int(p.maxElevationDeg.rounded()))° up in the\(dir(p.peakAzimuthDeg))"
        var e = SkyEvent(id: "iss-\(Int(p.rise.timeIntervalSince1970))", kind: .issPass, title: "ISS pass",
                         detail: "Rises\(dir(p.riseAzimuthDeg)) \(Copy.hhmm(p.rise, site: site)) · \(highest) \(Copy.hhmm(p.peak, site: site)) · sets\(dir(p.setAzimuthDeg)) \(Copy.hhmm(p.set, site: site))",
                         time: p.rise, endTime: p.set, raHours: nil, decDeg: nil)
        e.best = p.peak
        let minutes = max(1, Int((p.set.timeIntervalSince(p.rise) / 60).rounded()))
        e.facts = [EventFact("Rises", "\(Copy.hhmm(p.rise, site: site))\(dir(p.riseAzimuthDeg))"),
                   EventFact("Highest", "\(Copy.hhmm(p.peak, site: site)), \(highest)"),
                   EventFact("Sets", "\(Copy.hhmm(p.set, site: site))\(dir(p.setAzimuthDeg))"),
                   EventFact("Visible for", "About \(minutes) minute\(minutes == 1 ? "" : "s")")]
        return e
    }

    /// Marks each event clear or cloudy from the forecast hour containing its `when`; nil when no hour covers it.
    public static func markClear(_ events: [SkyEvent], hours: [HourlyConditions], maxCloudPct: Int) -> [SkyEvent] {
        events.map { e in
            var e = e
            e.clear = hours.first { $0.time <= e.when && e.when < $0.time.addingTimeInterval(3600) }.map { $0.cloudTotal <= maxCloudPct }
            return e
        }
    }
}
