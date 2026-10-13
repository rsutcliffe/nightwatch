import SwiftUI
import UserNotifications
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

/// Provisional: reports no permission, so nothing is posted or queued. Replaced by the real scheduler in M3.
struct NoAlerts: NotificationScheduling {
    func isAuthorised() async -> Bool { false }
    func post(_ notification: AlertNotification) async {}
    func replaceScheduled(_ alerts: [ScheduledAlert]) async {}
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
        }, scheduler: NoAlerts())
        if demo { s.addSite(DemoData.site) }
        s.attachSync(store: CloudStore())
        _store = StateObject(wrappedValue: s)
    }

    var body: some Scene {
        WindowGroup { RootView(store: store, connectivity: connectivity) }
    }
}
