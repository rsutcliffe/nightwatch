import Testing
import Foundation
import CAstronomyEngine
@testable import SkyCore

@Test func j2000RoundTrip() {
    let d = Date(timeIntervalSince1970: 946_728_000)
    let t = astro_time_t(d)
    #expect(abs(t.ut) < 1e-9)
    #expect(abs(t.date.timeIntervalSince(d)) < 0.001)
}

@Test func arbitraryDateRoundTrip() {
    let d = Date(timeIntervalSince1970: 1_790_000_000)
    #expect(abs(astro_time_t(d).date.timeIntervalSince(d)) < 0.001)
}
