import Foundation

public struct SitePlan: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let site: DarkSite
    public let score: Int
    public let primary: ClearWindow?
    public let qualifies: Bool
    public let forecastMissing: Bool
    public init(id: String, site: DarkSite, score: Int, primary: ClearWindow?, qualifies: Bool, forecastMissing: Bool) {
        self.id = id; self.site = site; self.score = score; self.primary = primary; self.qualifies = qualifies; self.forecastMissing = forecastMissing
    }
    /// A site with no forecast: sorts last, never qualifies, never recommended.
    public static func missing(_ site: DarkSite) -> SitePlan {
        SitePlan(id: site.id, site: site, score: 0, primary: nil, qualifies: false, forecastMissing: true)
    }
}

public enum SiteComparison {
    public static func sorted(_ plans: [SitePlan]) -> [SitePlan] {
        plans.sorted {
            if $0.forecastMissing != $1.forecastMissing { return !$0.forecastMissing }
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.site.distanceKm < $1.site.distanceKm
        }
    }

    /// The best qualifying site whose score beats home by at least `margin`; nil when none.
    public static func bestAway(home: NightPlan, sites: [SitePlan], margin: Int = 20) -> SitePlan? {
        sorted(sites).first { !$0.forecastMissing && $0.qualifies && $0.score >= home.score + margin }
    }
}
