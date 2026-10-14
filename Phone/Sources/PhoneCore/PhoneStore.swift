import Foundation
import SkyCore

/// The plans the Plan, Targets, Favourites and Week screens draw.
public struct Planning: Equatable, Sendable {
    public var tonight: NightPlan
    public var tomorrow: NightPlan
    public var week: [WeekNight]
}

/// The phone's notification centre, behind a protocol so the core can be tested without one. The real implementation
/// (UNUserNotificationCenter) comes with the alerts milestone.
public protocol NotificationScheduling: Sendable {
    func isAuthorised() async -> Bool
    /// Post at once.
    func post(_ notification: AlertNotification) async
    /// Drop every alert queued earlier and queue these.
    func replaceScheduled(_ alerts: [ScheduledAlert]) async
}

/// Fetches a forecast for a site. `askPrimary` is false while Apple Weather is being left alone after a refusal.
/// Looks up the hills around a site: the eight heights, N to NW, in degrees.
public typealias TerrainFetcher = @Sendable (Site) async throws -> [Double]

public typealias ForecastProvider = @Sendable (_ site: Site, _ now: Date, _ askPrimary: Bool) async throws -> Forecast

/// The phone app's one source of truth: the settings, the saved forecast, tonight's plan as the page draws it, and the
/// alert queue. It owns no screen. A lean replacement for the Mac's `Store`, which is tied to AppKit and WidgetKit.
@MainActor
public final class PhoneStore: ObservableObject {
    public enum Phase: Equatable, Sendable {
        /// No site yet: the first-run screen asks where you observe from.
        case needsSite
        case loading
        case ready
        case failed(String)
    }

    /// What the app is doing while the page is loading, so the wait can say so. Only ever a step actually being taken.
    public enum LoadStage: Equatable, Sendable { case reading, planning }
    @Published public private(set) var stage: LoadStage?
    @Published public private(set) var phase: Phase = .loading
    @Published public private(set) var tonight: TonightModel?
    @Published public private(set) var forecast: Forecast?
    /// The last refresh found no connection: the page says how old the forecast it shows is.
    @Published public private(set) var offline = false
    @Published public private(set) var refreshing = false
    /// Apple's mark as kept on disk, exactly as supplied, for the footer; nil until Apple Weather has answered once.
    @Published public private(set) var appleMarkData: Data?
    @Published public var config: Config = .default
    /// Tonight's and tomorrow's full plans and the ten-night week, for the Plan, Targets, Favourites and Week screens.
    @Published public private(set) var planning: Planning?
    /// Sites whose hills are being looked up now, and sites whose lookup failed this launch (Retry clears one).
    @Published public private(set) var terrainChecking: Set<String> = []
    @Published public private(set) var terrainFailed: Set<String> = []

    private let directory: URL
    private let provider: ForecastProvider
    private let scheduler: NotificationScheduling
    private let clock: @Sendable () -> Date
    private let fetchData: @Sendable (URL) async throws -> Data
    private let markStore: AppleMarkStore
    private let forecastStore: ForecastStore
    private var pause = PrimaryPause()
    private let terrainFetcher: TerrainFetcher
    private let terrainPause: Duration
    private var terrainTask: Task<Void, Never>?
    private var ledger = AlertLedger()

    /// Tonight's events (showers, eclipses, conjunctions, bright comets, space station passes, the Moon covering a star), with
    /// the Moon-covers-a-star ones for the year ahead kept apart for "Coming up".
    @Published public private(set) var events: [SkyEvent] = []
    @Published public private(set) var occultationsAhead: [SkyEvent] = []
    private var comets: [CometElements] = []
    private var tle: TLE?
    private var feedAttempts: [String: Date] = [:]
    private var occultationsKey: String?
    private let showers: [MeteorShower]

    /// Dark sites near the observing site, tonight's plan at each (the nearest eight), and a clearer site worth the drive.
    @Published public private(set) var darkSites: [DarkSite] = []
    @Published public private(set) var sitePlans: [SitePlan] = []
    @Published public private(set) var bestAway: SitePlan?
    /// Tonight's plan at home, for the dark-site cards to compare with: the plan in view when home is where you are, else home's own
    /// (its forecast is fetched and kept 30 minutes, as a dark site's is).
    @Published public private(set) var homePlan: NightPlan?
    /// True while the list is being worked out (car parks, town names and forecasts are looked up one at a time).
    @Published public private(set) var darkSitesWorking = false
    /// The last run left out the forecasts and lookups because the connection is costly or constrained.
    @Published public private(set) var darkSitesSkipped = false
    private let darkLookups: DarkLookups?
    /// Told after each plan is built, with what the home-screen widget should draw (the app writes it to the shared App Group).
    private let widgetSink: (@Sendable (WidgetSnapshot) -> Void)?
    private let certified: [CertifiedSite]
    private var grids: [LPGrid] { Self.lightPollution }
    /// Britain's grid from SkyCore, and the world's from the app's own resources, as the Mac does: SkyCore carries only Britain's.
    private static let lightPollution: [LPGrid] = {
        let world = Bundle.main.url(forResource: "world", withExtension: "lpgrid", subdirectory: "LightPollution").flatMap(LPGrids.load)
        return LPGrids.finestFirst(LPGrids.bundled() + (world.map { [$0] } ?? []))
    }()
    private var spotPlaces: [String: String] = [:]               // town name by computed spot id; "" where Apple Maps has none
    private var spotPublic: [String: PublicPlace?] = [:]          // car park by computed spot id; nil inside: none within reach
    private var darkFailedAt: Date?
    private var darkGeneration = 0
    private var darkTask: Task<Void, Never>?
    private let feeds: @Sendable (URL) async throws -> Data
    private let findOccultations: Bool

    private let catalog: Catalog
    private let constellations: [Constellation]
    private let stars: [BrightStar]

    public init(directory: URL, provider: @escaping ForecastProvider, scheduler: NotificationScheduling,
                clock: @escaping @Sendable () -> Date = { Date() },
                fetchData: @escaping @Sendable (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 },
                terrain: @escaping TerrainFetcher = { try await Terrain.fetch(site: $0, fetcher: URLSessionFetcher()) },
                terrainPause: Duration = .seconds(10),
                feeds: @escaping @Sendable (URL) async throws -> Data = { try await URLSessionFetcher().get($0) },
                occultations: Bool = true,
                darkLookups: DarkLookups? = .live,
                widgetSink: (@Sendable (WidgetSnapshot) -> Void)? = nil) {
        self.widgetSink = widgetSink
        self.darkLookups = darkLookups
        certified = (try? DarkSites.bundledCertified()) ?? []
        self.feeds = feeds
        self.findOccultations = occultations
        showers = (try? MeteorShowers.bundled()) ?? []
        self.terrainFetcher = terrain
        self.terrainPause = terrainPause
        self.directory = directory
        self.provider = provider
        self.scheduler = scheduler
        self.clock = clock
        self.fetchData = fetchData
        markStore = AppleMarkStore(directory: directory)
        forecastStore = ForecastStore(url: directory.appendingPathComponent("forecast.json"))
        catalog = (try? Catalog.bundled()) ?? Catalog(objects: [])
        constellations = (try? Constellations.bundled()) ?? []
        stars = (try? BrightStars.bundled()) ?? []
        config = loadConfig() ?? .default
        ledger = Self.read(AlertLedger.self, from: directory.appendingPathComponent("alerts.json")) ?? AlertLedger()
        forecast = forecastStore.load()
        appleMarkData = forecast?.attributionMarkURL.flatMap { markStore.data(for: $0) }
        comets = Self.read([CometElements].self, from: directory.appendingPathComponent("comets.json")) ?? []
        tle = Self.read(TLE.self, from: directory.appendingPathComponent("iss-tle.json"))
        feedAttempts = Self.read([String: Date].self, from: directory.appendingPathComponent("feed-attempts.json")) ?? [:]
        spotPlaces = Self.read([String: String].self, from: directory.appendingPathComponent("spot-places-v2.json")) ?? [:]
        spotPublic = Self.read([String: PublicPlace?].self, from: directory.appendingPathComponent("spot-public.json")) ?? [:]
    }

    // MARK: Settings

    /// The app's clock (a fixed offset in demos), for screens that say how old something is.
    public var now: Date { clock() }

    public var site: Site? { config.activeSite(auto: nil) }

    /// Save the settings, and tell the other devices unless this save came from them.
    public func saveConfig(send: Bool = true) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        Self.write(config, to: configURL)
        if send { sync?.send() }
    }

    private var configURL: URL { directory.appendingPathComponent("config.json") }
    private var sync: SettingsSyncCoordinator?

    /// Start sharing the settings with the user's other devices through `store` (iCloud key-value storage in the app).
    public func attachSync(store: KeyValueStoring, defaults: UserDefaults = .standard) {
        let coordinator = SettingsSyncCoordinator(store: store, defaults: defaults,
                                                  readConfig: { [unowned self] in self.config },
                                                  writeConfig: { [unowned self] c in self.config = c; self.saveConfig(send: false); self.replan() })
        sync = coordinator
        let modified = (try? FileManager.default.attributesOfItem(atPath: configURL.path))?[.modificationDate] as? Date
        coordinator.start(localModified: modified)
    }

    private func loadConfig() -> Config? { Self.read(Config.self, from: configURL) }

    // MARK: Plan and favourites

    /// Rebuild the plans after the settings changed (a heart, a plan choice, or settings arriving from another device).
    public func replan() { Task { await recompute(now: clock()) } }

    /// Tonight's plan (or tomorrow night's) as the user has arranged it, from the favourites and that night's choices.
    public func session(tomorrow: Bool = false) -> SessionPlan? {
        guard let site, let p = planning else { return nil }
        let night = tomorrow ? p.tomorrow : p.tonight
        return SessionPlanner.make(plan: night, favourites: config.favourites, choices: config.planChoices[night.night.key] ?? PlanChoices(),
                                   stopBy: config.stopBy, site: site)
    }

    public func isFavourite(_ id: String) -> Bool { config.favourites.contains(id) }

    /// Is `id` in the plan for the night: a favourite not taken off, or a target added for it.
    public func isInPlan(_ id: String, tomorrow: Bool = false) -> Bool { session(tomorrow: tomorrow)?.items.contains { $0.id == id } ?? false }

    public func toggleFavourite(_ id: String) {
        config.toggleFavourite(id)
        saveConfig()
        replan()
    }

    /// Put a target in the night's plan, or take it off. A favourite is taken off or put back; any other target is added for the night.
    public func setInPlan(_ id: String, on: Bool, tomorrow: Bool = false) {
        guard let p = planning else { return }
        let key = (tomorrow ? p.tomorrow : p.tonight).night.key
        let choices = SessionPlanner.choose(id, on: on, isFavourite: isFavourite(id), in: config.planChoices[key] ?? PlanChoices())
        config.planChoices[key] = choices
        // Earlier nights have no further use; keeping only tonight and later keeps the synced settings small.
        config.planChoices = SessionPlanner.pruned(config.planChoices, from: p.tonight.night.key)
        saveConfig()
        replan()
    }

    // MARK: Horizons

    /// The height the horizon must clear to matter: the go rule's "Targets must reach". Heights at or below it change nothing.
    public var openDeg: Double { config.goRule.minAltitudeDeg }

    /// Save the eight horizon heights for a site (nil, open sky, when every one is at the open height, as the Mac does), then plan again.
    public func setHorizon(siteNamed name: String, heights: [Double]) {
        guard let i = config.sites.firstIndex(where: { $0.name == name }), heights.count == 8 else { return }
        config.sites[i].horizon = heights.allSatisfy({ $0 <= openDeg }) ? nil : heights
        saveConfig()
        replan()
    }

    /// Move a saved site to where a photo was taken (the Mac's "Move here"): its hills are looked up again, and if it is the one in view the
    /// forecast is read again for the new place.
    public func moveSite(named name: String, to c: Coordinate) {
        guard let i = config.sites.firstIndex(where: { $0.name == name }) else { return }
        config.sites[i].latitude = c.latitude
        config.sites[i].longitude = c.longitude
        config.sites[i].terrain = nil
        saveConfig()
        checkTerrain()
        if site?.name == name { Task { await refresh(force: true) } } else { replan() }
    }

    /// Look up the hills for every saved site that has none yet, one site at a time with a pause between, as the Mac does (the
    /// elevation service answers 429 to quick runs). A failure is remembered for the launch; `retryTerrain` clears it.
    public func checkTerrain() {
        guard terrainTask == nil else { return }
        terrainTask = Task { [weak self] in
            guard let self else { return }
            var first = true
            while let site = self.config.sites.first(where: { $0.terrain == nil && !self.terrainFailed.contains($0.name) }) {
                if !first { try? await Task.sleep(for: self.terrainPause) }
                first = false
                self.terrainChecking.insert(site.name)
                do {
                    let heights = try await self.terrainFetcher(site)
                    if let i = self.config.sites.firstIndex(where: { $0.name == site.name }), self.config.sites[i].latitude == site.latitude,
                       self.config.sites[i].longitude == site.longitude {
                        self.config.sites[i].terrain = heights
                        self.saveConfig()
                    }
                } catch { self.terrainFailed.insert(site.name) }
                self.terrainChecking.remove(site.name)
            }
            self.terrainTask = nil
        }
    }

    public func retryTerrain(siteNamed name: String) {
        terrainFailed.remove(name)
        checkTerrain()
    }

    /// Raise the horizon to clear the hills where they stand above it (the Mac's "Raise" button).
    public func raiseToTerrain(siteNamed name: String) {
        guard let site = config.sites.first(where: { $0.name == name }), let t = site.terrain else { return }
        var h = site.horizon ?? Array(repeating: openDeg, count: 8)
        for (i, v) in Terrain.raises(terrain: t, site: site, openDeg: openDeg) { h[i] = v }
        setHorizon(siteNamed: name, heights: h)
    }

    // MARK: Sites

    /// Add a site (or replace one of the same name), make it the active one, save, and read its forecast.
    public func addSite(_ s: Site) {
        config.sites.removeAll { $0.name == s.name }
        guard config.sites.count < Config.maxSites else { return }
        config.sites.append(s)
        selectSite(s)
        checkTerrain()
    }

    public func selectSite(_ s: Site) {
        // The page must not go on showing the last site's night under the new site's name.
        if s.name != site?.name { phase = .loading; tonight = nil; events = []; occultationsAhead = []; occultationsKey = nil; darkSites = []; sitePlans = []; bestAway = nil }
        config.choose(savedName: s.name)
        saveConfig()
        Task { await refresh(force: true) }
    }

    public func removeSites(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) { config.sites.remove(at: i) }
        if site == nil { config.activeSiteName = config.sites.first?.name }
        saveConfig()
        Task { await refresh() }
    }

    // MARK: Refresh

    /// Draw from what is saved, fetch if the policy says to, and rebuild tonight's page and the alert queue.
    public func refresh(force: Bool = false, connectivity: Connectivity = Connectivity()) async {
        guard let site else { phase = .needsSite; tonight = nil; return }
        defer { stage = nil }
        let now = clock()
        if forecast.map({ !ForecastStore.matches($0, site: site) }) ?? false { forecast = forecastStore.load().flatMap { ForecastStore.matches($0, site: site) ? $0 : nil } }
        switch RefreshPolicy.decision(now: now, forecast: forecast, site: site, pause: pause, force: force, connectivity: connectivity) {
        case .useSaved:
            offline = false
        case .offline:
            offline = true
            if forecast == nil { phase = .failed("No connection, and no forecast saved for \(site.name) yet."); return }
        case .fetch:
            refreshing = true; stage = .reading
            defer { refreshing = false }
            let ask = !pause.paused(now: now)
            do {
                let fc = try await provider(site, now, ask)
                if ask { pause.record(answered: fc.cloudSource == "Apple Weather", now: now) }
                forecast = fc
                try? forecastStore.save(fc)
                offline = false
                await keepAppleMark(for: fc)
            } catch {
                if forecast == nil { phase = .failed("Couldn't read the forecast for \(site.name). Try again."); return }
                offline = true   // keep drawing from the saved forecast, and say how old it is
            }
        }
        stage = .planning
        if connectivity.allowsOptionalDownloads { await refreshFeeds(now: clock()) }
        await recompute(now: clock())
        if darkLookups != nil {
            darkTask?.cancel()
            darkTask = Task { [weak self] in await self?.refreshDarkSites(connectivity: connectivity) }
        }
    }

    // MARK: Dark sites

    /// Observe from a dark site without saving it, as the Mac's "Observe from here".
    public func visit(_ s: DarkSite) {
        config.visit(DarkSites.toSite(s, timeZoneID: site?.timeZoneID ?? TimeZone.current.identifier))
        saveConfig()
        phase = .loading; tonight = nil; events = []; occultationsAhead = []; occultationsKey = nil
        Task { await refresh(force: true) }
    }

    /// Save the site being visited.
    public func keepVisiting() { config.keepVisiting(); saveConfig() }

    public func goHome() {
        config.goHome(); saveConfig()
        phase = .loading; tonight = nil; events = []; occultationsAhead = []; occultationsKey = nil
        Task { await refresh(force: true) }
    }

    public var isAway: Bool { config.isAway(auto: nil) }
    public var homeSite: Site? { config.homeSite(auto: nil) }
    public var homeLabel: String { config.homeSite(auto: nil)?.name ?? "home" }
    public var visitingSite: Site? { config.visiting }
    public var distanceUnit: DistanceUnit { config.darkSites.unit }

    /// While away, tonight's plan at home: its forecast kept in home-forecast.json (30 minutes fresh, gone after 24 hours) and fetched only on a
    /// cheap connection, never asking for Apple Weather. At home it is simply the plan in view.
    private func updateHomePlan(now: Date, cheap: Bool) async {
        guard isAway, let home = homeSite else { homePlan = planning?.tonight; return }
        let cache = ForecastStore(url: directory.appendingPathComponent("home-forecast.json"))
        var fc = cache.load().flatMap { ForecastStore.matches($0, site: home) ? $0 : nil }
        let stale = fc.map { now.timeIntervalSince($0.fetchedAt) > 30 * 60 } ?? true
        if stale, cheap, let fresh = try? await provider(home, now, false) { fc = fresh; try? cache.save(fresh) }
        guard let f = fc, now.timeIntervalSince(f.fetchedAt) <= 24 * 3600, let night = try? Ephemeris.currentNight(now: now, site: home) else { homePlan = nil; return }
        homePlan = Planner.plan(night: night, forecast: f, catalog: Catalog(objects: []), constellations: [], site: home,
                                fov: config.fov, rule: config.goRule, bright: config.brightNights)
    }

    /// Waits for the dark-sites run a refresh started (tests, and anything that needs the finished list).
    public func darkSitesFinished() async { await darkTask?.value }

    /// Settings changed (on, radius, unit): work the list out again.
    public func setDarkSites(_ change: (inout DarkSiteSettings) -> Void) {
        change(&config.darkSites)
        saveConfig()
        darkTask?.cancel()
        darkTask = Task { [weak self] in await self?.refreshDarkSites() }
    }

    /// Dark sites within the radius, and a forecast for the nearest eight (30-minute cache under sites/<id>.json) planned with the same
    /// go rule. Each run takes a generation number and checks it after every await, so a run superseded by a settings change stops
    /// and never publishes over the newer one. Looking up car parks, town names and forecasts waits for a cheap connection.
    public func refreshDarkSites(connectivity: Connectivity = Connectivity()) async {
        guard let lookups = darkLookups, let site, config.darkSites.enabled else { darkSites = []; sitePlans = []; bestAway = nil; return }
        darkGeneration += 1
        let gen = darkGeneration
        let now = clock()
        guard let night = try? Ephemeris.currentNight(now: now, site: site) else { return }
        darkSitesWorking = true
        defer { if gen == darkGeneration { darkSitesWorking = false } }
        let home = Coordinate(latitude: site.latitude, longitude: site.longitude)
        let radiusKm = config.darkSites.radiusKm, certified = certified, grids = grids
        let found = await Task.detached { DarkSites.sites(near: home, radiusKm: radiusKm, certified: certified, grids: grids, maxSpots: 5) }.value
        guard gen == darkGeneration else { return }
        NSLog("Nightwatch dark sites: run \(gen) found \(found.count) (\(found.filter { $0.isComputed }.count) computed) within \(Int(radiusKm)) km of \(site.name)")
        let cheap = connectivity.allowsOptionalDownloads
        darkSitesSkipped = !cheap
        let retry = now.timeIntervalSince(darkFailedAt ?? .distantPast) >= 3600
        await updateHomePlan(now: now, cheap: cheap)
        guard gen == darkGeneration else { return }

        // A computed spot is moved to the nearest dark car park, and is left out until one is known (and when there is none).
        var sites: [DarkSite] = [], seen = Set<String>()
        for s in found {
            guard s.isComputed else { sites.append(s); continue }
            if spotPublic[s.id] == nil, cheap, retry {
                do {
                    spotPublic[s.id] = .some(try await lookups.publicPlace(s.coordinate, s.band, grids))
                    Self.write(spotPublic, to: directory.appendingPathComponent("spot-public.json"))
                } catch { darkFailedAt = now; NSLog("Nightwatch dark sites: car park lookup failed: \(error)") }
                guard gen == darkGeneration else { return }
            }
            guard let entry = spotPublic[s.id], let p = entry else { continue }
            let c = Coordinate(latitude: p.latitude, longitude: p.longitude)
            let id = String(format: "place-%.3f-%.3f", c.latitude, c.longitude)
            guard seen.insert(id).inserted else { continue }   // two spots can share a car park
            sites.append(DarkSite(id: id, name: p.name, kind: "spot", coordinate: c, distanceKm: Geo.distanceKm(home, c),
                                  bearingDeg: Geo.bearingDeg(from: home, to: c),
                                  band: LPGrids.radiance(at: c, in: grids).map(DarknessBand.from) ?? s.band, bortle: nil, source: nil, isComputed: true))
        }
        sites = DarkSites.withoutDuplicates(sites).sorted { $0.distanceKm < $1.distanceKm }
        NSLog("Nightwatch dark sites: run \(gen) kept \(sites.count) after car parks (retry allowed: \(retry), cheap: \(cheap), known entries: \(spotPublic.count))")

        // Every car park carries its town, so two "Car park"s can be told apart: "Car park near Kettlewell".
        for s in sites where s.isComputed && spotPlaces[s.id] == nil && cheap && retry {
            do {
                spotPlaces[s.id] = try await lookups.placeName(s.coordinate) ?? ""
                Self.write(spotPlaces, to: directory.appendingPathComponent("spot-places-v2.json"))
            } catch { darkFailedAt = now }
            guard gen == darkGeneration else { return }
        }
        func named(_ s: DarkSite) -> DarkSite {
            guard s.isComputed else { return s }
            return spotPlaces[s.id].flatMap { DarkSites.spotName(place: $0, lead: s.name) }.map(s.named) ?? s
        }
        sites = sites.map(named)

        let cacheDir = directory.appendingPathComponent("sites", isDirectory: true)
        var plans: [SitePlan] = []
        for s in sites.prefix(8) {
            let asSite = DarkSites.toSite(s, timeZoneID: site.timeZoneID)
            let cache = ForecastStore(url: cacheDir.appendingPathComponent("\(s.id).json"))
            var fc = cache.load()
            if fc.map({ now.timeIntervalSince($0.fetchedAt) > 30 * 60 }) ?? true, cheap {
                if let fresh = try? await provider(asSite, now, false) { fc = fresh; try? cache.save(fresh) }
                guard gen == darkGeneration else { return }
            }
            // A cache over 24 hours old that could not be refreshed no longer describes tonight: no forecast, not a plan.
            if let f = fc, now.timeIntervalSince(f.fetchedAt) > 24 * 3600 { fc = nil }
            guard let fc else { plans.append(SitePlan.missing(s)); continue }
            let p = Planner.plan(night: night, forecast: fc, catalog: Catalog(objects: []), constellations: [], site: asSite,
                                 fov: config.fov, rule: config.goRule, bright: config.brightNights)
            plans.append(SitePlan(id: s.id, site: s, score: p.score, primary: p.primary, qualifies: p.qualifies, forecastMissing: false))
        }
        guard gen == darkGeneration else { return }
        darkSites = sites   // set with the plans so a page never sees a new list beside old plans
        sitePlans = SiteComparison.sorted(plans)
        bestAway = homePlan.flatMap { SiteComparison.bestAway(home: $0, sites: plans) }   // against home, as the cards are
        CachePruning.prune(directory: cacheDir, keepIDs: Set(sites.map(\.id)), now: now)
    }

    /// Comet elements daily and the space station's elements every 2 hours (CelesTrak asks for no more), as the Mac does. Gated on the
    /// last attempt, not the last success, so a failing server is not hammered. They are small, but skipped on a costly connection.
    func refreshFeeds(now: Date) async {
        if feedDue("comets", every: 86_400, now: now), let data = try? await feeds(Comets.url) {
            let unzipped = await Task.detached { Gzip.decompress(data) ?? data }.value
            if let c = try? Comets.decode(unzipped) { comets = c; Self.write(c, to: directory.appendingPathComponent("comets.json")) }
        }
        if feedDue("iss", every: 2 * 3600, now: now), let data = try? await feeds(Satellites.issURL),
           let t = try? Satellites.parseTLE(String(decoding: data, as: UTF8.self)) {
            tle = t; Self.write(t, to: directory.appendingPathComponent("iss-tle.json"))
        }
    }

    private func feedDue(_ key: String, every interval: TimeInterval, now: Date) -> Bool {
        guard now.timeIntervalSince(feedAttempts[key] ?? .distantPast) >= interval else { return false }
        feedAttempts[key] = now
        Self.write(feedAttempts, to: directory.appendingPathComponent("feed-attempts.json"))
        return true
    }

    private func buildEvents(night: Night, site: Site, now: Date) -> [SkyEvent] {
        var ev = Events.showers(night: night, site: site, showers: showers)
        ev += Events.eclipses(after: now, site: site, withinDays: 60)
        let mid = night.darkStart.map { $0.addingTimeInterval((night.darkEnd ?? $0).timeIntervalSince($0) / 2) } ?? night.sunset
        ev += Events.conjunctions(at: mid, site: site, maxSeparationDeg: 3, night: night, fov: config.fov)
        for (c, pos) in Comets.bright(comets, at: mid, limit: 12) {
            let later = Comets.position(c, at: mid.addingTimeInterval(7 * 86_400))
            if let e = Events.comet(designation: c.designation, pos: pos, later: later, night: night, site: site) { ev.append(e) }
        }
        if let tle, let passes = try? Satellites.visiblePasses(tle: tle, site: site, from: night.sunset, to: night.sunrise, minPeakElevation: 30) {
            ev += passes.map { Events.issPass($0, site: site) }
        }
        updateOccultations(site: site, now: now)
        ev += occultationsAhead.filter { $0.time >= night.sunset && $0.time < night.sunrise }
        return ev.sorted { $0.when < $1.when }
    }

    /// The Moon covering a planet or bright star over the coming year, worked out once a day per site off the main thread (about a
    /// second), after which the plan is rebuilt so tonight's join the events.
    private func updateOccultations(site: Site, now: Date) {
        guard findOccultations else { return }
        let day = site.calendar.startOfDay(for: now)
        let key = "\(site.latitude),\(site.longitude),\(site.horizon ?? []),\(day.timeIntervalSince1970)"
        guard key != occultationsKey else { return }
        occultationsKey = key
        let stars = self.stars
        Task.detached(priority: .utility) { [weak self] in
            let found = Occultations.find(from: day, days: 365, site: site, stars: stars).map { Events.occultation($0, site: site) }
            await MainActor.run {
                guard let self, self.occultationsKey == key else { return }
                self.occultationsAhead = found
                Task { await self.recompute(now: self.clock()) }
            }
        }
    }

    /// Keep Apple's mark on disk the first time it is supplied (a failed download is tried again at the next forecast).
    private func keepAppleMark(for fc: Forecast) async {
        guard let address = fc.attributionMarkURL, let url = URL(string: address) else { return }
        if let kept = markStore.data(for: address) { appleMarkData = kept; return }
        guard let data = try? await fetchData(url), !data.isEmpty else { return }
        try? markStore.save(data, for: address)
        appleMarkData = data
    }

    /// Tonight's and tomorrow's plans from the saved forecast, the page model, and the alerts queue.
    func recompute(now: Date) async {
        guard let site, let fc = forecast, ForecastStore.matches(fc, site: site) else { return }
        let cal = site.calendar
        guard let night = try? Ephemeris.currentNight(now: now, site: site),
              let tomorrowDate = cal.date(byAdding: .day, value: 1, to: night.localDate),
              let next = try? Ephemeris.night(localDate: tomorrowDate, site: site) else {
            phase = .failed("Couldn't work out tonight for \(site.name).")
            return
        }
        let plan = Planner.plan(night: night, forecast: fc, catalog: catalog, constellations: constellations, stars: stars, site: site,
                                fov: config.fov, rule: config.goRule, bright: config.brightNights, favourites: config.favourites)
        let tomorrow = Planner.plan(night: next, forecast: fc, catalog: catalog, constellations: constellations, stars: stars, site: site,
                                    fov: config.fov, rule: config.goRule, bright: config.brightNights, favourites: config.favourites)
        tonight = TonightModel.make(plan: plan, tomorrow: tomorrow, forecast: fc, site: site, config: config)
        planning = Planning(tonight: plan, tomorrow: tomorrow,
                            week: Planner.week(tonight: plan, tomorrow: tomorrow, forecast: fc, site: site, fov: config.fov,
                                               rule: config.goRule, bright: config.brightNights))
        events = Events.markClear(buildEvents(night: night, site: site, now: now), hours: fc.hours, maxCloudPct: config.goRule.maxCloudPct)
        phase = .ready
        if let snap = tonight?.snapshot { widgetSink?(snap) }

        guard config.notifyEnabled, await scheduler.isAuthorised() else { return }
        let r = AlertPlanner.plan(now: now, ledger: ledger, tonight: plan, tomorrow: tomorrow, settings: config.alerts,
                                  forecastFetchedAt: fc.fetchedAt, site: site)
        ledger = r.ledger
        Self.write(ledger, to: directory.appendingPathComponent("alerts.json"))
        if let n = r.immediate { await scheduler.post(n) }
        await scheduler.replaceScheduled(r.ledger.scheduled)
    }

    // MARK: Files

    private static func write<T: Encodable>(_ value: T, to url: URL) {
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        if let data = try? enc.encode(value) { try? data.write(to: url, options: .atomic) }
    }

    private static func read<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
