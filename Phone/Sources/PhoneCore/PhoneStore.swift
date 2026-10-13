import Foundation
import SkyCore

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

    @Published public private(set) var phase: Phase = .loading
    @Published public private(set) var tonight: TonightModel?
    @Published public private(set) var forecast: Forecast?
    /// The last refresh found no connection: the page says how old the forecast it shows is.
    @Published public private(set) var offline = false
    @Published public private(set) var refreshing = false
    /// Apple's mark as kept on disk, exactly as supplied, for the footer; nil until Apple Weather has answered once.
    @Published public private(set) var appleMarkData: Data?
    @Published public var config: Config = .default

    private let directory: URL
    private let provider: ForecastProvider
    private let scheduler: NotificationScheduling
    private let clock: @Sendable () -> Date
    private let fetchData: @Sendable (URL) async throws -> Data
    private let markStore: AppleMarkStore
    private let forecastStore: ForecastStore
    private var pause = PrimaryPause()
    private var ledger = AlertLedger()

    private let catalog: Catalog
    private let constellations: [Constellation]
    private let stars: [BrightStar]

    public init(directory: URL, provider: @escaping ForecastProvider, scheduler: NotificationScheduling,
                clock: @escaping @Sendable () -> Date = { Date() },
                fetchData: @escaping @Sendable (URL) async throws -> Data = { try await URLSession.shared.data(from: $0).0 }) {
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
                                                  writeConfig: { [unowned self] c in self.config = c; self.saveConfig(send: false) })
        sync = coordinator
        let modified = (try? FileManager.default.attributesOfItem(atPath: configURL.path))?[.modificationDate] as? Date
        coordinator.start(localModified: modified)
    }

    private func loadConfig() -> Config? { Self.read(Config.self, from: configURL) }

    // MARK: Sites

    /// Add a site (or replace one of the same name), make it the active one, save, and read its forecast.
    public func addSite(_ s: Site) {
        config.sites.removeAll { $0.name == s.name }
        guard config.sites.count < Config.maxSites else { return }
        config.sites.append(s)
        selectSite(s)
    }

    public func selectSite(_ s: Site) {
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
        let now = clock()
        if forecast.map({ !ForecastStore.matches($0, site: site) }) ?? false { forecast = forecastStore.load().flatMap { ForecastStore.matches($0, site: site) ? $0 : nil } }
        switch RefreshPolicy.decision(now: now, forecast: forecast, site: site, pause: pause, force: force, connectivity: connectivity) {
        case .useSaved:
            offline = false
        case .offline:
            offline = true
            if forecast == nil { phase = .failed("No connection, and no forecast saved for \(site.name) yet."); return }
        case .fetch:
            refreshing = true
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
