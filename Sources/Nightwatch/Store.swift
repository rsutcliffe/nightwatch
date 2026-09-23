import Foundation
import SkyCore
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published var config: Config = .default
    @Published var plan: NightPlan?
    @Published var tomorrow: NightPlan?
    @Published var events: [SkyEvent] = []
    @Published var forecast: Forecast?
    @Published var alertState: AlertState?
    @Published var autoSite: Site?
    @Published var lastError: String?
    @Published var refreshing = false
    /// config.json exists but would not decode: saves are refused so the user's file is never overwritten.
    @Published var configLoadFailed = false
    var booting = false                // set synchronously by boot() so a second label .task cannot boot twice
    var scheduler: Scheduler?          // not @Published: doesn't drive UI, just needs stable storage across boot()

    static let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Nightwatch", isDirectory: true)
    private let fetcher: Fetcher = URLSessionFetcher()
    private let catalog: Catalog
    private let constellations: [Constellation]
    private let showers: [MeteorShower]
    private var comets: [CometElements] = []
    private var tle: TLE?
    private var configModDate: Date?
    private var auxAttempts: [String: Date] = [:]   // last download ATTEMPT per aux feed, keyed "comets"/"iss"

    init() {
        catalog = (try? Catalog.bundled()) ?? Catalog(objects: [])
        constellations = (try? Constellations.bundled()) ?? []
        showers = (try? MeteorShowers.bundled()) ?? []
        try? FileManager.default.createDirectory(at: Store.cacheDir, withIntermediateDirectories: true)
        forecast = Store.read("forecast.json")
        plan = Store.read("plan.json")             // content in the popover before the first fetch
        alertState = Store.read("alerts-state.json")
        comets = Store.read("comets.json") ?? []
        tle = Store.read("iss-tle.json")
        auxAttempts = Store.read("aux-attempts.json") ?? [:]
        if catalog.objects.isEmpty { lastError = "Catalogue missing: run scripts/fetch-data.sh and rebuild." }
        loadConfig()
    }

    /// Loads config.json. A file that exists but will not decode (or a dangling symlink) is never overwritten:
    /// it is copied to config.json.bad beside it and saves are refused until Reset config in Settings.
    /// On failure the in-memory config is kept (the default at launch, the last good one on a reload).
    private func loadConfig() {
        let url = ConfigStore.defaultURL
        configModDate = Store.configModDate()
        do {
            config = try ConfigStore.load(from: url)
            configLoadFailed = false
        } catch {
            configLoadFailed = true
            if let d = try? Data(contentsOf: url) { try? d.write(to: url.appendingPathExtension("bad"), options: .atomic) }
            lastError = "Could not read \(url.path): \(error.localizedDescription) A copy is at config.json.bad. Settings will not be saved until you fix the file or use Reset config in Settings."
        }
    }

    /// Modification time of the file the config path resolves to (through a synced-folder symlink).
    private static func configModDate() -> Date? {
        try? FileManager.default.attributesOfItem(atPath: ConfigStore.defaultURL.resolvingSymlinksInPath().path)[.modificationDate] as? Date
    }

    /// Clears `configLoadFailed` by writing defaults. (A later load that decodes, e.g. after the user fixes the file
    /// by hand, also clears it: memory then matches the file, so saving can no longer lose anything.)
    func resetConfig() {
        configLoadFailed = false
        config = .default
        saveConfig()
    }

    private func forecastMatches(_ s: Site) -> Bool {
        forecast.map { abs($0.latitude - s.latitude) <= 0.01 && abs($0.longitude - s.longitude) <= 0.01 } ?? false
    }

    func constellation(_ id: String) -> Constellation? { constellations.first { $0.id == id } }

    var copy: Copy { Copy(flavour: config.flavour) }
    var site: Site? { config.activeSite(auto: autoSite) }
    var isStale: Bool { (forecast?.fetchedAt).map { Date().timeIntervalSince($0) > 6 * 3600 } ?? true }
    var iconName: String { Theme.icon(for: plan, stale: isStale, now: Date()) }

    func saveConfig() {
        if configLoadFailed {
            lastError = "Not saved: \(ConfigStore.defaultURL.lastPathComponent) could not be read. Fix it, or use Reset config in Settings."
        } else {
            try? ConfigStore.save(config, to: ConfigStore.defaultURL)
            configModDate = Store.configModDate()
        }
        let siteChanged = site.map { !forecastMatches($0) } ?? false
        Task { if siteChanged { await refresh(force: true) } else { await recompute(now: Date()) } }
    }

    /// Fetch when the cache is older than 30 minutes (or forced), then recompute everything.
    /// Also reloads config.json first when it changed on disk (another Mac editing it through a synced symlink),
    /// and treats a forecast for other coordinates as stale.
    func refresh(force: Bool) async {
        if let m = Store.configModDate(), m > (configModDate ?? .distantPast) { loadConfig() }
        guard !refreshing else { return }
        guard let site else {
            if !configLoadFailed { lastError = "No site. Add one in Settings or allow location access." }
            return
        }
        refreshing = true
        let now = Date()
        if force || !forecastMatches(site) || (forecast?.fetchedAt).map({ now.timeIntervalSince($0) > 30 * 60 }) ?? true {
            do {
                forecast = try await ForecastService.fetch(site: site, fetcher: fetcher, now: now)
                Store.write(forecast, "forecast.json")
                lastError = nil
            } catch {
                lastError = "Forecast fetch failed: \(error.localizedDescription)"
            }
        }
        await refreshAuxiliary(now: now)
        await recompute(now: now)
        refreshing = false
        // The site changed while this ran (location fix, Settings, config reload) and its own refresh hit the guard above.
        if self.site != site { await refresh(force: false) }
    }

    /// Comet elements daily, ISS elements every 2 hours (CelesTrak asks for no more). The MPC file is gzip, so it goes through gunzip.
    /// Gated on the last attempt, not the last success, so a failing server is not hammered every tick.
    private func refreshAuxiliary(now: Date) async {
        if attemptDue("comets", every: 86_400, now: now), let data = try? await fetcher.get(Comets.url) {
            let unzipped = await Task.detached { Store.gunzip(data) }.value
            if let c = try? Comets.decode(unzipped) { comets = c; Store.write(c, "comets.json") }
        }
        if attemptDue("iss", every: 2 * 3600, now: now), let data = try? await fetcher.get(Satellites.issURL),
           let t = try? Satellites.parseTLE(String(decoding: data, as: UTF8.self)) {
            tle = t; Store.write(t, "iss-tle.json")
        }
    }

    /// True (and the attempt recorded) when `interval` has passed since the last attempt for `key`.
    private func attemptDue(_ key: String, every interval: TimeInterval, now: Date) -> Bool {
        guard now.timeIntervalSince(auxAttempts[key] ?? .distantPast) >= interval else { return false }
        auxAttempts[key] = now
        Store.write(auxAttempts, "aux-attempts.json")
        return true
    }

    /// The night whose sunset is coming up, or the one in progress: local date of (now − 9 h). ponytail: a fixed 9 h
    /// offset means the previous night stays "tonight" until 09:00 local; sunrise-based switching if anyone minds.
    func recompute(now: Date) async {
        guard let site, let fc = forecast else { return }
        guard forecastMatches(site) else {
            plan = nil; tomorrow = nil; events = []
            lastError = "Forecast is for a different site; refreshing"
            return
        }
        let cal = site.calendar
        guard let night = try? Ephemeris.night(localDate: now.addingTimeInterval(-9 * 3600), site: site),
              let next = try? Ephemeris.night(localDate: cal.date(byAdding: .day, value: 1, to: night.localDate)!, site: site) else { return }
        let fov = config.fov, rule = config.goRule
        let p = Planner.plan(night: night, forecast: fc, catalog: catalog, constellations: constellations, site: site, fov: fov, rule: rule)
        let t = Planner.plan(night: next, forecast: fc, catalog: catalog, constellations: constellations, site: site, fov: fov, rule: rule)
        plan = p; tomorrow = t
        events = buildEvents(night: night, site: site, now: now)
        Store.write(p, "plan.json")
        if config.notifyEnabled {
            let r = AlertEngine.step(now: now, tonight: p, tomorrow: t, state: alertState, settings: config.alerts,
                                     forecastFetchedAt: fc.fetchedAt, site: site, copy: copy)
            alertState = r.state
            Store.write(r.state, "alerts-state.json")
            if let n = r.notification { Notifier.post(n) }
        }
    }

    private func buildEvents(night: Night, site: Site, now: Date) -> [SkyEvent] {
        var ev = Events.showers(night: night, site: site, showers: showers)
        ev += Events.eclipses(after: now, site: site, withinDays: 60)
        let mid = night.darkStart.map { $0.addingTimeInterval((night.darkEnd ?? $0).timeIntervalSince($0) / 2) } ?? night.sunset
        ev += Events.conjunctions(at: mid, site: site, maxSeparationDeg: 3)
        for (c, pos) in Comets.bright(comets, at: mid, limit: 12) {
            let alt = Ephemeris.altAz(raHours: pos.raHours, decDeg: pos.decDeg, at: mid, site: site).alt
            guard alt > 20 else { continue }
            ev.append(SkyEvent(id: "comet-\(c.designation)", kind: .comet, title: c.designation,
                               detail: String(format: "mag %.1f · alt %.0f°", pos.magnitude, alt), time: mid, endTime: nil, raHours: pos.raHours, decDeg: pos.decDeg))
        }
        if let tle, let passes = try? Satellites.visiblePasses(tle: tle, site: site, from: night.sunset, to: night.sunrise, minPeakElevation: 30) {
            for p in passes {
                ev.append(SkyEvent(id: "iss-\(Int(p.rise.timeIntervalSince1970))", kind: .issPass, title: "ISS pass",
                                   detail: String(format: "max %.0f° at %@", p.maxElevationDeg, Copy.hhmm(p.peak, site: site)),
                                   time: p.rise, endTime: p.set, raHours: nil, decDeg: nil))
            }
        }
        return ev.sorted { $0.time < $1.time }
    }

    // MARK: cache helpers
    static func url(_ name: String) -> URL { cacheDir.appendingPathComponent(name) }
    static func read<T: Decodable>(_ name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(T.self, from: data)
    }
    static func write<T: Encodable>(_ value: T?, _ name: String) {
        guard let value else { return }
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        try? e.encode(value).write(to: url(name), options: .atomic)
    }
    /// gzip via Foundation is unavailable; shell out to the system gunzip for the MPC file.
    /// `nonisolated` so this can run off the main actor (see `refreshAuxiliary`): the blocking
    /// `readDataToEndOfFile`/`waitUntilExit` pair would otherwise freeze the UI on `Store`.
    nonisolated static func gunzip(_ data: Data) -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cometels.json.gz")
        try? data.write(to: tmp)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip"); p.arguments = ["-c", tmp.path]
        let pipe = Pipe(); p.standardOutput = pipe
        do { try p.run() } catch { return Data() }
        let out = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        guard p.terminationStatus == 0 else { return Data() }
        return out
    }
}
