import Testing
import Foundation
@testable import SkyCore

private let sheffieldPt = Coordinate(latitude: 53.381, longitude: -1.470)
private let edinburghPt = Coordinate(latitude: 55.953, longitude: -3.189)
private let londonPt = Coordinate(latitude: 51.507, longitude: -0.128)

// Reference values computed independently with the spherical formulas (R = 6371.0088 km) on 2026-09-23.
@Test func distanceSheffieldEdinburgh() { #expect(abs(Geo.distanceKm(sheffieldPt, edinburghPt) - 306.59) < 0.5) }
@Test func distanceSheffieldLondon() { #expect(abs(Geo.distanceKm(sheffieldPt, londonPt) - 227.36) < 0.5) }
@Test func distanceIsSymmetricAndZeroAtSelf() {
    #expect(abs(Geo.distanceKm(sheffieldPt, edinburghPt) - Geo.distanceKm(edinburghPt, sheffieldPt)) < 1e-9)
    #expect(Geo.distanceKm(sheffieldPt, sheffieldPt) == 0)
}
@Test func bearings() {
    #expect(abs(Geo.bearingDeg(from: sheffieldPt, to: edinburghPt) - 339.6) < 0.5)
    #expect(abs(Geo.bearingDeg(from: sheffieldPt, to: londonPt) - 155.9) < 0.5)
}
@Test func compassPoints() {
    #expect(Geo.compass(0) == "N"); #expect(Geo.compass(339.6) == "NNW"); #expect(Geo.compass(155.9) == "SSE")
    #expect(Geo.compass(359.9) == "N"); #expect(Geo.compass(45) == "NE")
}
@Test func destinationRoundTrip() {
    let d = Geo.destination(from: sheffieldPt, bearingDeg: 90, distanceKm: 50)
    #expect(abs(Geo.distanceKm(sheffieldPt, d) - 50) < 0.05)
    #expect(abs(Geo.bearingDeg(from: sheffieldPt, to: d) - 90) < 0.5)
}
@Test func unitFormatting() {
    #expect(Geo.format(km: 32.4, unit: .km) == "32 km")
    #expect(Geo.format(km: 32.4, unit: .mi) == "20 mi")
    #expect(Geo.format(km: 0.8, unit: .km) == "0.8 km")
}
