import Foundation
import SkyCore
import SwiftUI

@MainActor
final class Store: ObservableObject {
    @Published var config: Config
    @Published var plan: NightPlan?
    @Published var tomorrow: NightPlan?
    @Published var events: [SkyEvent] = []
    @Published var forecast: Forecast?
    @Published var alertState: AlertState?
    @Published var autoSite: Site?
    @Published var lastError: String?
    @Published var refreshing = false
    var scheduler: Scheduler?          // not @Published: doesn't drive UI, just needs stable storage across boot()

    static let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("Nightwatch", isDirectory: true)
    private let fetcher: Fetcher = URLSessionFetcher()
    private let catalog: Catalog
    private let constellations: [Constellation]
    private let showers: [MeteorShower]
    private var comets: [CometElements] = []
    private var tle: TLE?

    init() {
        config = (try? ConfigStore.load(from: ConfigStore.defaultURL)) ?? .default
        catalog = (try? Catalog.bundled()) ?? Catalog(objects: [])
        constellations = (try? Constellations.bundled()) ?? []
        showers = (try? MeteorShowers.bundled()) ?? []
        try? FileManager.default.createDirectory(at: Store.cacheDir, withIntermediateDirectories: true)
        forecast = Store.read("forecast.json")
        alertState = Store.read("alerts-state.json")
        comets = Store.read("comets.json") ?? []
        tle = Store.read("iss-tle.json")
        if catalog.objects.isEmpty { lastError = "Catalogue missing: run scripts/fetch-data.sh and rebuild." }
    }

    var copy: Copy { Copy(flavour: config.flavour) }
    var site: Site? { config.activeSite(auto: autoSite) }
    var isStale: Bool { (forecast?.fetchedAt).map { Date().timeIntervalSince($0) > 6 * 3600 } ?? true }
    var iconName: String { Theme.icon(for: plan, stale: isStale, now: Date()) }

    func saveConfig() {
        try? ConfigStore.save(config, to: ConfigStore.defaultURL)
        Task { await recompute(now: Date()) }
    }

    /// Fetch when the cache is older than 30 minutes (or forced), then recompute everything.
    func refresh(force: Bool) async {
        guard let site else { lastError = "No site. Add one in Settings or allow location access."; return }
        refreshing = true
        defer { refreshing = false }
        let now = Date()
        if force || (forecast?.fetchedAt).map({ now.timeIntervalSince($0) > 30 * 60 }) ?? true {
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
    }

    /// Comet elements daily, ISS elements every 2 hours (CelesTrak asks for no more). The MPC file is gzip, so it goes through gunzip.
    private func refreshAuxiliary(now: Date) async {
        if Store.age("comets.json") > 86_400, let data = try? await fetcher.get(Comets.url), let c = try? Comets.decode(Store.gunzip(data)) {
            comets = c; Store.write(c, "comets.json")
        }
        if Store.age("iss-tle.json") > 2 * 3600, let data = try? await fetcher.get(Satellites.issURL),
           let t = try? Satellites.parseTLE(String(decoding: data, as: UTF8.self)) {
            tle = t; Store.write(t, "iss-tle.json")
        }
    }

    /// The night whose sunset is coming up, or the one in progress: local date of (now − 9 h). ponytail: a fixed 9 h
    /// offset means the previous night stays "tonight" until 09:00 local; sunrise-based switching if anyone minds.
    func recompute(now: Date) async {
        guard let site, let fc = forecast else { return }
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
    static func age(_ name: String) -> TimeInterval {
        guard let d = try? FileManager.default.attributesOfItem(atPath: url(name).path)[.modificationDate] as? Date else { return .infinity }
        return Date().timeIntervalSince(d)
    }
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
    static func gunzip(_ data: Data) -> Data {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent("cometels.json.gz")
        try? data.write(to: tmp)
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip"); p.arguments = ["-c", tmp.path]
        let pipe = Pipe(); p.standardOutput = pipe
        try? p.run(); let out = pipe.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return out
    }
}
