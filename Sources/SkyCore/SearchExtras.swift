import Foundation

/// What a Targets search finds in the catalogue that the night's list leaves out (#250): a card for each, so it can be opened and given a
/// heart. One that is up for half the window (only the list's magnitude cut left it out) is an ordinary card; the rest are greyed with the
/// first night they are well placed. The views ask on every clock tick, so the last answer is kept.
public final class SearchExtras {
    /// A broad word ("galaxy") matches thousands: the brightest few are enough to find one by.
    public static let limit = 12
    private var key = ""
    private var kept: [FavouriteTarget] = []
    private var listKey = ""
    private var list: [DeepSkyObject] = []
    /// The nights ahead, kept from one keystroke to the next: working a night out costs far more than tracking a target across it.
    private var nightsKey = ""
    private var nights: [Int: Night?] = [:]
    public init() {}

    /// Every catalogue match that is not in the night's list, whatever its group: the search hint counts them.
    public func notListed(query: String, ranked: [RankedTarget], catalog: Catalog, nightKey: String) -> [DeepSkyObject] {
        guard !query.allSatisfy(\.isWhitespace) else { return [] }
        let k = "\(query)|\(nightKey)|\(ranked.count)"
        if k != listKey {
            let listed = Set(ranked.map(\.id))
            list = catalog.objects(matching: query).filter { !listed.contains($0.id) }
            listKey = k
        }
        return list
    }

    public func cards(query: String, group: TargetGroup, ranked: [RankedTarget], catalog: Catalog, plan: NightPlan, site: Site,
                      fov: FieldOfView, rule: GoRule) -> [FavouriteTarget] {
        guard !query.allSatisfy(\.isWhitespace) else { return [] }
        let k = "\(query)|\(group)|\(plan.night.key)|\(plan.mode)|\(String(describing: plan.primary))|\(site)|\(fov)|\(rule)|\(ranked.count)"
        if k != key {
            let found = notListed(query: query, ranked: ranked, catalog: catalog, nightKey: plan.night.key).filter { $0.group == group }
            let nk = "\(plan.night.key)|\(site.latitude),\(site.longitude),\(site.timeZoneID)"
            if nk != nightsKey { nights = [:]; nightsKey = nk }
            kept = Planner.searchExtras(found, plan: plan, site: site, fov: fov, rule: rule) { i in
                if let n = self.nights[i] { return n }
                let n = try? Ephemeris.night(localDate: site.calendar.date(byAdding: .day, value: i, to: plan.night.localDate)!, site: site)
                self.nights[i] = n
                return n
            }
            key = k
        }
        return kept
    }
}

extension Planner {
    /// `found`: one group's catalogue matches that the night's list leaves out.
    /// `night(i)`: the night i days after the plan's.
    static func searchExtras(_ found: [DeepSkyObject], plan: NightPlan, site: Site, fov: FieldOfView, rule: GoRule,
                             limit: Int = SearchExtras.limit, night: (Int) -> Night?) -> [FavouriteTarget] {
        let matches = found.sorted { ($0.magnitude ?? 99) < ($1.magnitude ?? 99) }.prefix(limit)
        guard !matches.isEmpty else { return [] }
        let window = plan.primary ?? plan.darkSpan
        let span = window ?? ClearWindow(start: plan.night.sunset, end: plan.night.sunrise)
        let moon = Ephemeris.moon(at: span.midpoint, site: site)
        let moonUp = moon.position.altDeg > 0 && moon.illumination > 0.1
        return matches.compactMap { o in
            guard let b = build(.object(o), window: span, site: site, fov: fov, rule: rule, moon: moon, moonUp: moonUp) else { return nil }
            if window != nil, b.fraction >= 0.5 { return FavouriteTarget(target: b.target, notTonight: nil) }
            let next = nextWellPlaced(raHours: o.raHours, decDeg: o.decDeg, site: site, minAlt: rule.minAltitudeDeg, night: night)
            return FavouriteTarget(target: b.target, notTonight: Copy.nextWellPlaced(next, decDeg: o.decDeg, site: site, minAlt: rule.minAltitudeDeg))
        }
    }

    /// The first night after tonight, within a year, on which a place in the sky is above the floor for half of the darkness: the test the
    /// night's list sets. `night(i)` is the night i days on. Looked for a week at a time, then to the day in the week before the first hit.
    static func nextWellPlaced(raHours: Double, decDeg: Double, site: Site, minAlt: Double, night: (Int) -> Night?) -> Night? {
        func placed(_ i: Int) -> Night? {
            guard let n = night(i), let s = n.darkStart, let e = n.darkEnd else { return nil }
            return track(raHours: raHours, decDeg: decDeg, window: ClearWindow(start: s, end: e), site: site, minAlt: minAlt).fraction >= 0.5 ? n : nil
        }
        for week in stride(from: 7, through: 364, by: 7) where placed(week) != nil {
            for day in (week - 6)..<week { if let n = placed(day) { return n } }
            return placed(week)
        }
        return nil
    }

    public static func nextWellPlaced(raHours: Double, decDeg: Double, after tonight: Night, site: Site, minAlt: Double) -> Night? {
        nextWellPlaced(raHours: raHours, decDeg: decDeg, site: site, minAlt: minAlt) {
            try? Ephemeris.night(localDate: site.calendar.date(byAdding: .day, value: $0, to: tonight.localDate)!, site: site)
        }
    }
}

extension Copy {
    /// A searched-for target's greyed card (#250): when to come back for it, or that this site never gets it.
    static func nextWellPlaced(_ night: Night?, decDeg: Double, site: Site, minAlt: Double) -> String {
        if let night {
            let f = DateFormatter(); f.timeZone = site.timeZone; f.dateFormat = "d MMM"; f.locale = Locale(identifier: "en_GB")
            return "Next well placed from \(f.string(from: night.localDate))"
        }
        // Its highest point anywhere in the year is when it crosses the meridian.
        return 90 - abs(site.latitude - decDeg) < minAlt ? "Never clears \(Int(minAlt.rounded()))° from here" : "Not well placed from here in the coming year"
    }
}
