import CoreLocation
import SkyCore

final class LocationProvider: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<Site?, Never>?

    /// One fix, or nil when denied, restricted or timed out. Never prompts more than macOS itself does.
    func requestOnce() async -> Site? {
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        guard manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorized || manager.authorizationStatus == .notDetermined else { return nil }
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

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let l = locations.last else { return finish(nil) }
        finish(Site(name: "Current location", latitude: l.coordinate.latitude, longitude: l.coordinate.longitude,
                    elevationM: max(0, l.altitude), timeZoneID: TimeZone.current.identifier, bortle: 5))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) { finish(nil) }
}
