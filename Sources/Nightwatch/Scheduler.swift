import AppKit
import Foundation

/// Fires `onFire` every `interval` seconds while the app runs, plus once on wake from sleep.
final class Scheduler {
    private let activity = NSBackgroundActivityScheduler(identifier: "io.github.rsutcliffe.nightwatch.patrol")
    private let onFire: () -> Void

    init(interval: TimeInterval = 30 * 60, onFire: @escaping () -> Void) {
        self.onFire = onFire
        activity.repeats = true
        activity.interval = interval
        activity.tolerance = interval / 3
        activity.qualityOfService = .utility
    }

    func start() {
        activity.schedule { [onFire] completion in
            DispatchQueue.main.async { onFire() }
            completion(.finished)
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [onFire] _ in
            onFire()
        }
    }
}
