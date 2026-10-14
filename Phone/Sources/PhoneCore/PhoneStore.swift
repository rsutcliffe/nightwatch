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

    private let catalog: Catalog
    private let constellations: [Constellation]
    private let stars: [BrightStar]

    public init(directory: URL, provider: @escaping ForecastProvider, scheduler: NotificationScheduling,
                clock: @escaping @Sendable () -> Date = { Date() },
                fetchData: @escaping @Sendable (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 },
                terrain: @escaping TerrainFetcher = { try await Terrain.fetch(site: $0, fetcher: URLSessionFetcher()) },
                terrainPause: Duration = .seconds(10)) {
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
        if s.name != site?.name { phase = .loading; tonight = nil }
        config.activeSiteName = s.name
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
        await recompute(now: clock())
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
        phase = .ready

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
