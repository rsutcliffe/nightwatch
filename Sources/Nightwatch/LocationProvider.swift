import CoreLocation
import SkyCore

/// @unchecked: created on the main thread, and CoreLocation delivers delegate calls on that thread.
final class LocationProvider: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Site?, Never>?
    /// A fix that arrives with no `requestOnce` waiting: authorisation granted after the 15 s timeout.
    var onSite: ((Site) -> Void)?

    private var allowed: Bool { [.authorizedAlways, .authorized].contains(manager.authorizationStatus) }

    /// One fix, or nil when denied, restricted or timed out. Never prompts more than macOS itself does.
    func requestOnce() async -> Site? {
        guard continuation == nil else { return nil }   // one request in flight; a second would leak its continuation
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        guard allowed || manager.authorizationStatus == .notDetermined else { return nil }
        return await withCheckedContinuation { c in
            continuation = c
            manager.requestLocation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in self?.finish(nil) }
        }
    }

    private func finish(_ site: Site?) {
        continuation?.resume(returning: site)
        continuation = nil
    }

    /// The user answered the prompt (possibly long after `requestOnce` gave up): ask for a fix now.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if allowed { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return finish(nil) }
        let site = Site(name: "Current location", latitude: l.coordinate.latitude, longitude: l.coordinate.longitude,
                        elevationM: max(0, l.altitude), timeZoneID: TimeZone.current.identifier, bortle: 5)
        if continuation != nil { finish(site) } else { onSite?(site) }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }
}
