import Testing
import Foundation
@testable import SkyCore

private let testSite = Site(name: "Test site", latitude: 54.0, longitude: -1.5, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
private let sydneyBezel = Site(name: "Sydney", latitude: -33.87, longitude: 151.21, elevationM: 50, timeZoneID: "Australia/Sydney", bortle: 7)

/// Hourly samples from `from` for `n` hours, cloud chosen per sample time.
private func hours(from: Date, _ n: Int, cloud: (Date) -> Int) -> [HourlyConditions] {
    (0..<n).map { i in
        let t = from.addingTimeInterval(Double(i) * 3600)
        return HourlyConditions(time: t, cloudTotal: cloud(t), cloudLow: nil, cloudMid: nil, cloudHigh: nil, tempC: nil, dewPointC: nil,
                                humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)
    }
}

@Test func bezelWindowCrossingMidnight() {
    // November, GMT, so UTC is local. Darkness 20:00–05:00 fits the face, so the face is centred on darkness (18:30–06:30).
    let dark = ClearWindow(start: utc(2026, 11, 20, 20, 0), end: utc(2026, 11, 21, 5, 0))
    let window = ClearWindow(start: utc(2026, 11, 20, 23, 0), end: utc(2026, 11, 21, 2, 0))
    let h = hours(from: utc(2026, 11, 20, 18, 0), 14) { $0 < window.start ? 30 : ($0 < window.end ? 10 : 80) }
    let s = Bezel.slots(darkness: dark, windows: [window], primary: window, hours: h, site: testSite)
    #expect(s.count == 60)
    #expect(s[0] == .clear)        // 00:00
    #expect(s[55] == .clear)       // 23:00
    #expect(s[10] == .cloudy)      // 02:00, cloud 80
    #expect(s[50] == .partCloud)   // 22:00, cloud 30
    #expect(s[30] == .daylight)    // 06:00
    #expect(s[35] == .daylight)    // 19:00
}

@Test func bezelDarknessOverTwelveHoursCentresOnTheWindow() {
    // Darkness 17:45–06:15 (12.5 h) is longer than the face, so the face is the 12 h round the window's middle, 20:30–08:30.
    let dark = ClearWindow(start: utc(2026, 11, 20, 17, 45), end: utc(2026, 11, 21, 6, 15))
    let window = ClearWindow(start: utc(2026, 11, 21, 1, 0), end: utc(2026, 11, 21, 4, 0))
    let h = hours(from: utc(2026, 11, 20, 17, 0), 15) { $0 >= window.start && $0 < window.end ? 5 : 30 }
    let s = Bezel.slots(darkness: dark, windows: [window], primary: window, hours: h, site: testSite)
    #expect(s[10] == .clear)       // 02:00
    #expect(s[30] == .partCloud)   // 06:00 is still dark
    #expect(s[31] == .daylight)    // 06:12, middle 06:18, after darkness
    #expect(s[38] == .daylight)    // 07:36 in the morning, not 19:36
    #expect(s[43] == .partCloud)   // 08:36 on the face reads as 20:36, which is dark
}

@Test func bezelUsesTheSiteClock() {
    // Sydney in June is UTC+10. Darkness 18:30–05:30 local, window 22:00–01:00 local.
    let dark = ClearWindow(start: utc(2026, 6, 21, 8, 30), end: utc(2026, 6, 21, 19, 30))
    let window = ClearWindow(start: utc(2026, 6, 21, 12, 0), end: utc(2026, 6, 21, 15, 0))
    let h = hours(from: utc(2026, 6, 21, 8, 0), 12) { $0 >= window.start && $0 < window.end ? 5 : 90 }
    let s = Bezel.slots(darkness: dark, windows: [window], primary: window, hours: h, site: sydneyBezel)
    #expect(s[0] == .clear)        // local midnight
    #expect(s[10] == .cloudy)      // 02:00 local
    #expect(s[30] == .daylight)    // 18:00 local on this face, before darkness (a UTC clock would put it at 18:00Z, in darkness)
}

@Test func bezelWithoutDarknessIsAllDaylight() {
    #expect(Bezel.slots(darkness: nil, windows: [], primary: nil, hours: [], site: testSite) == Array(repeating: .daylight, count: 60))
}

@Test func bezelDarknessUnderTwelveHoursCentresOnDarknessNotTheWindow() {
    // Darkness 18:00–05:30 (11.5 h) fits the face, so the face is 17:45–05:45 whatever the window. Centred on the early
    // window (18:30–21:30) instead, the face would be 14:00–02:00 and 04:00 would read as 16:00, daylight.
    let dark = ClearWindow(start: utc(2026, 11, 20, 18, 0), end: utc(2026, 11, 21, 5, 30))
    let window = ClearWindow(start: utc(2026, 11, 20, 18, 30), end: utc(2026, 11, 20, 21, 30))
    let h = hours(from: utc(2026, 11, 20, 17, 0), 14) { $0 >= window.start && $0 < window.end ? 5 : 30 }
    let s = Bezel.slots(darkness: dark, windows: [window], primary: window, hours: h, site: testSite)
    #expect(s[20] == .partCloud)   // 04:00, still dark
    #expect(s[35] == .clear)       // 19:00, in the window
}
