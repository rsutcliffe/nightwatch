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
        let demo = CommandLine.arguments.contains("-demo")
        let s = PhoneStore(directory: demo ? FileManager.default.temporaryDirectory.appendingPathComponent("nightwatch-demo") : dir, provider: { site, now, ask in
            if demo { return DemoData.forecast(fetchedAt: now, from: Calendar.current.startOfDay(for: now), site: site) }
            return try await ForecastService.fetch(site: site, fetcher: URLSessionFetcher(), now: now,
                                                   primary: ask ? WeatherKitSource.provider : nil)
        }, scheduler: UserNotificationScheduler())
        if demo { s.addSite(DemoData.site) }
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
