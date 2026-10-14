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

/// One candidate for "add a site": the site plus where it is, so two places with one name can be told apart.
public struct PlaceMatch: Identifiable {
    public let site: Site
    public let detail: String
    public var id: String { "\(site.name)|\(site.latitude)|\(site.longitude)" }
}

/// Finds places by name for "add a site". The user picks one; the site can be renamed afterwards.
public enum PlaceSearch {
    /// For a search-as-you-type field: waits for a pause in typing (a newer keystroke cancels this one), ignores short text.
    public static func matches(typed text: String) async -> [PlaceMatch] {
        let t = text.trimmingCharacters(in: .whitespaces)
        guard t.count >= 3 else { return [] }
        try? await Task.sleep(for: .milliseconds(400))
        return Task.isCancelled ? [] : await matches(t)
    }

    public static func matches(_ text: String) async -> [PlaceMatch] {
        let req = MKLocalSearch.Request()
        req.naturalLanguageQuery = text
        guard let items = try? await MKLocalSearch(request: req).start().mapItems else { return [] }
        return items.prefix(6).map { item in
            let pm = item.placemark
            let loc = pm.location ?? CLLocation(latitude: pm.coordinate.latitude, longitude: pm.coordinate.longitude)
            let where_ = [pm.locality, pm.administrativeArea, pm.country].compactMap { $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }
            return PlaceMatch(site: Site(name: item.name ?? text, latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude,
                                         elevationM: max(0, loc.altitude), timeZoneID: pm.timeZone?.identifier ?? TimeZone.current.identifier, bortle: 5),
                              detail: where_.joined(separator: ", "))
        }
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
