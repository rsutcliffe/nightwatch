import SwiftUI
import UserNotifications
import BackgroundTasks
import SkyCore
import PhoneCore
import PhoneUI

/// The real iCloud key-value store, behind PhoneCore's protocol.
final class CloudStore: KeyValueStoring {
    private let kv = NSUbiquitousKeyValueStore.default
    func data(forKey key: String) -> Data? { kv.data(forKey: key) }
    func set(_ data: Data?, forKey key: String) { if let data { kv.set(data, forKey: key) } else { kv.removeObject(forKey: key) } }
    func synchronize() { kv.synchronize() }
    func observeExternalChanges(_ handler: @escaping @Sendable () -> Void) -> AnyObject {
        NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: kv, queue: .main) { _ in handler() }
    }
}

/// iOS decides when this runs (rarely more than a few times a day, and not at all in Low Power Mode), so alerts also rely on
/// the app being opened. It refreshes the forecast and requeues the alerts.
/// Shows an alert as a banner even while the app is open: without this iOS keeps it quiet in the foreground.
final class AlertPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = AlertPresenter()
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent n: UNNotification) async -> UNNotificationPresentationOptions {
        NSLog("Nightwatch delivered %@", n.request.identifier)
        return [.banner, .list, .sound]
    }
}

let refreshTaskID = "io.github.rsutcliffe.nightwatch.phone.refresh"

func scheduleBackgroundRefresh() {
    let r = BGAppRefreshTaskRequest(identifier: refreshTaskID)
    r.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)
    try? BGTaskScheduler.shared.submit(r)
}

@main
struct NightwatchPhoneApp: App {
    @StateObject private var store: PhoneStore
    @StateObject private var connectivity = ConnectivityMonitor()

    init() {
        let dir = URL.applicationSupportDirectory.appendingPathComponent("Nightwatch", isDirectory: true)
        // `-demo` shows made-up conditions for a public site, for screenshots and layout checks. Never used in a release.
        //   -demoNow 17:05   the app's clock starts at that time today, then runs
        //   -demoCloud 90    cloud cover for every hour (default 5)
        UNUserNotificationCenter.current().delegate = AlertPresenter.shared
        if CommandLine.arguments.contains("-probeWeatherKit") {   // says why Apple Weather fell back, in the console
            Task {
                NSLog("WeatherKit probe started")
                let started = Date()
                let work = Task { try await WeatherKitSource.hours(site: DemoData.site, now: .now) }
                let watchdog = Task { try await Task.sleep(for: .seconds(40)); NSLog("WeatherKit probe: no answer after 40 s"); work.cancel() }
                do { let r = try await work.value; NSLog("WeatherKit OK: \(r.hours.count) hours in \(Date().timeIntervalSince(started)) s, mark \(r.markURL ?? "none")") }
                catch { NSLog("WeatherKit failed after \(Date().timeIntervalSince(started)) s: \(String(reflecting: error))") }
                watchdog.cancel()
            }
        }
        let args = CommandLine.arguments
        func value(_ flag: String) -> String? { args.firstIndex(of: flag).flatMap { args.indices.contains($0 + 1) ? args[$0 + 1] : nil } }
        let demo = args.contains("-demo")
        var shift: TimeInterval = 0
        if demo, let t = value("-demoNow")?.split(separator: ":").compactMap({ Int($0) }), t.count == 2,
           let target = Calendar.current.date(bySettingHour: t[0], minute: t[1], second: 0, of: Date()) { shift = target.timeIntervalSinceNow }
        let clock: @Sendable () -> Date = { Date(timeIntervalSinceNow: shift) }
        if demo { try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appendingPathComponent("nightwatch-demo")) }   // every demo launch starts clean
        let cloud = value("-demoCloud").flatMap(Int.init) ?? 5
        let demoDir = FileManager.default.temporaryDirectory.appendingPathComponent("nightwatch-demo")
        if args.contains("-demoOffline") {   // a forecast from two hours ago, and no way to fetch another
            try? FileManager.default.createDirectory(at: demoDir, withIntermediateDirectories: true)
            try? ForecastStore(url: demoDir.appendingPathComponent("forecast.json")).save(
                DemoData.forecast(fetchedAt: clock().addingTimeInterval(-7200), from: Calendar.current.startOfDay(for: clock())))
        }
        let s = PhoneStore(directory: demo ? FileManager.default.temporaryDirectory.appendingPathComponent("nightwatch-demo") : dir, provider: { site, now, ask in
            if demo, let wait = value("-demoSlow").flatMap(Double.init) { try await Task.sleep(for: .seconds(wait)) }   // hold the loading screen
            if args.contains("-demoOffline") { throw URLError(.notConnectedToInternet) }
            if demo { return DemoData.forecast(fetchedAt: now, from: Calendar.current.startOfDay(for: now), cloud: cloud, site: site) }
            return try await ForecastService.fetch(site: site, fetcher: URLSessionFetcher(), now: now,
                                                   primary: ask ? WeatherKitSource.provider : nil)
        }, scheduler: UserNotificationScheduler(now: clock), clock: clock)
        if demo, !args.contains("-demoEmpty") { s.addSite(DemoData.site) }   // -demoEmpty shows the first-run screen
        s.attachSync(store: CloudStore())
        BGTaskScheduler.shared.register(forTaskWithIdentifier: refreshTaskID, using: nil) { task in
            scheduleBackgroundRefresh()
            let work = Task { @MainActor in
                await s.refresh()
                task.setTaskCompleted(success: true)
            }
            task.expirationHandler = { work.cancel() }
        }
        _store = StateObject(wrappedValue: s)
    }

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup { RootView(store: store, connectivity: connectivity) }
            .onChange(of: scenePhase) { _, p in if p == .background { scheduleBackgroundRefresh() } }
    }
}
