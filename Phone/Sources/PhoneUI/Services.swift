import Foundation
import CoreLocation
import MapKit
import Network
import SkyCore
import PhoneCore

/// One-shot "where am I": asked only when the user presses the button. Builds a site named "Current location".
@MainActor
public final class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?

    public override init() { super.init(); manager.delegate = self }

    public func currentSite() async throws -> Site {
        if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() }
        let fix: CLLocation = try await withCheckedThrowingContinuation { c in
            continuation = c
            manager.requestLocation()
        }
        return Site(name: "Current location", latitude: fix.coordinate.latitude, longitude: fix.coordinate.longitude,
                    elevationM: max(0, fix.altitude), timeZoneID: TimeZone.current.identifier, bortle: 5)
    }

    public nonisolated func locationManager(_ m: CLLocationManager, didUpdateLocations l: [CLLocation]) {
        Task { @MainActor in if let f = l.last { continuation?.resume(returning: f); continuation = nil } }
    }
    public nonisolated func locationManager(_ m: CLLocationManager, didFailWithError e: Error) {
        Task { @MainActor in continuation?.resume(throwing: e); continuation = nil }
    }
}

/// Finds a place by name for "add a site". The result is a plain site; the user can rename it.
public enum PlaceSearch {
    public static func find(_ text: String) async -> Site? {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = text
        guard let item = try? await MKLocalSearch(request: req).start().mapItems.first else { return nil }
        let loc = item.placemark.location ?? CLLocation(latitude: item.placemark.coordinate.latitude, longitude: item.placemark.coordinate.longitude)
        return Site(name: item.name ?? text, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                    elevationM: max(0, loc.altitude), timeZoneID: item.placemark.timeZone?.identifier ?? TimeZone.current.identifier, bortle: 5)
    }
}

/// Watches the network path and reports it as PhoneCore's `Connectivity`.
@MainActor
public final class ConnectivityMonitor: ObservableObject {
    @Published public private(set) var current = Connectivity()
    private let monitor = NWPathMonitor()

    public init() {
        monitor.pathUpdateHandler = { [weak self] p in
            let c = Connectivity(isOnline: p.status == .satisfied, isExpensive: p.isExpensive, isConstrained: p.isConstrained)
            Task { @MainActor in self?.current = c }
        }
        monitor.start(queue: .global(qos: .utility))
    }
    deinit { monitor.cancel() }
}
