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
    public let detail: String
    public let time: Date
    public let endTime: Date?
    public let raHours: Double?
    public let decDeg: Double?
    public init(id: String, kind: SkyEventKind, title: String, detail: String, time: Date, endTime: Date?, raHours: Double?, decDeg: Double?) {
        self.id = id; self.kind = kind; self.title = title; self.detail = detail; self.time = time; self.endTime = endTime
        self.raHours = raHours; self.decDeg = decDeg
    }
}

public enum Events {
    public static func showers(night: Night, site: Site, showers: [MeteorShower]) -> [SkyEvent] {
        let cal = site.calendar
        return MeteorShowers.active(on: night.localDate, calendar: cal, showers: showers).map { s in
            let peakTonight = MeteorShowers.isPeak(s, on: night.localDate, calendar: cal)
                || MeteorShowers.isPeak(s, on: cal.date(byAdding: .day, value: 1, to: night.localDate)!, calendar: cal)
            let detail = peakTonight ? "At peak tonight, ZHR \(s.zhr)" : "Active, peak \(s.peakDay)/\(s.peakMonth), ZHR \(s.zhr)"
            return SkyEvent(id: "shower-\(s.id)", kind: .meteorShower, title: s.name, detail: detail,
                            time: night.darkStart ?? night.sunset, endTime: night.darkEnd, raHours: s.raHours, decDeg: s.decDeg)
        }
    }

    public static func eclipses(after date: Date, site: Site, withinDays: Int) -> [SkyEvent] {
        let limit = date.addingTimeInterval(Double(withinDays) * 86_400)
        var out: [SkyEvent] = []
        if let l = Ephemeris.nextLunarEclipse(after: date), l.peak <= limit {
            out.append(SkyEvent(id: "lunar-\(Int(l.peak.timeIntervalSince1970))", kind: .lunarEclipse,
                                title: "\(l.kind.rawValue.capitalized) lunar eclipse", detail: "Peak obscuration \(Int((l.obscuration * 100).rounded()))%",
                                time: l.peak, endTime: nil, raHours: nil, decDeg: nil))
        }
        if let s = Ephemeris.nextLocalSolarEclipse(after: date, site: site), s.peak <= limit {
            out.append(SkyEvent(id: "solar-\(Int(s.peak.timeIntervalSince1970))", kind: .solarEclipse,
                                title: "\(s.kind.rawValue.capitalized) solar eclipse from \(site.name)", detail: "Peak obscuration \(Int((s.obscuration * 100).rounded()))%",
                                time: s.peak, endTime: s.partialEnd, raHours: nil, decDeg: nil))
        }
        return out
    }

    /// Pairs among the Moon and the seven planets closer than `maxSeparationDeg` at `date`.
    public static func conjunctions(at date: Date, site: Site, maxSeparationDeg: Double) -> [SkyEvent] {
        var bodies: [(String, BodyPosition)] = Planet.allCases.map { ($0.displayName, Ephemeris.planet($0, at: date, site: site)) }
        bodies.append(("Moon", Ephemeris.moon(at: date, site: site).position))
        var out: [SkyEvent] = []
        for i in 0..<bodies.count {
            for j in (i + 1)..<bodies.count {
                let (a, pa) = bodies[i], (b, pb) = bodies[j]
                let sep = Ephemeris.separationDeg(ra1Hours: pa.raHours, dec1Deg: pa.decDeg, ra2Hours: pb.raHours, dec2Deg: pb.decDeg)
                guard sep <= maxSeparationDeg else { continue }
                out.append(SkyEvent(id: "conj-\(a)-\(b)", kind: .conjunction, title: "\(a) near \(b)",
                                    detail: String(format: "%.1f° apart", sep), time: date, endTime: nil,
                                    raHours: pa.raHours, decDeg: pa.decDeg))
            }
        }
        return out.sorted { $0.detail < $1.detail }
    }
}
