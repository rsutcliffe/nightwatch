import Testing
import Foundation
@testable import SkyCore

func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func openMeteoParsesSeventyTwoHoursInUTC() throws {
    let data = try fixture("openmeteo.json")
    let hours = try OpenMeteo.parse(data)
    #expect(hours.count == 72)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let offset = json["utc_offset_seconds"] as! Double
    let firstLocal = (json["hourly"] as! [String: Any])["time"] as! [String]
    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.timeZone = TimeZone(identifier: "UTC")
    let expected = f.date(from: firstLocal[0])!.addingTimeInterval(-offset)
    #expect(hours[0].time == expected)
    #expect(hours[1].time.timeIntervalSince(hours[0].time) == 3600)
    #expect(hours[0].cloudTotal >= 0 && hours[0].cloudTotal <= 100)
    #expect(hours[0].visibilityM != nil)
    #expect(hours[0].seeing == nil)
}

@Test func openMeteoUrlHasRequiredVariables() {
    let u = OpenMeteo.url(latitude: 53.38, longitude: -1.47, days: 3).absoluteString
    #expect(u.hasPrefix("https://api.open-meteo.com/v1/forecast?"))
    for v in ["cloud_cover", "cloud_cover_low", "cloud_cover_mid", "cloud_cover_high", "dew_point_2m", "temperature_2m", "relative_humidity_2m", "wind_speed_10m", "wind_gusts_10m", "visibility"] {
        #expect(u.contains(v))
    }
    #expect(u.contains("timezone=auto"))
    #expect(u.contains("forecast_days=3"))
}

@Test func sevenTimerParsesInitAndTimepoints() throws {
    let data = try fixture("seventimer.json")
    let samples = try SevenTimer.parse(data)
    #expect(samples.count == 24)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let initString = json["init"] as! String
    let f = DateFormatter(); f.dateFormat = "yyyyMMddHH"; f.timeZone = TimeZone(identifier: "UTC")
    let initDate = f.date(from: initString)!
    let firstTimepoint = ((json["dataseries"] as! [[String: Any]])[0]["timepoint"] as! Double)
    #expect(samples[0].time == initDate.addingTimeInterval(firstTimepoint * 3600))
    #expect((1...8).contains(samples[0].seeing))
    #expect((1...8).contains(samples[0].transparency))
}

@Test func mergeHoldsSeeingForThreeHoursOnly() {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)
    let hours = (0..<6).map { i in
        HourlyConditions(time: t0.addingTimeInterval(Double(i) * 3600), cloudTotal: 10, cloudLow: nil, cloudMid: nil, cloudHigh: nil,
                         tempC: nil, dewPointC: nil, humidityPct: nil, windKmh: nil, gustKmh: nil, visibilityM: nil, seeing: nil, transparency: nil)
    }
    let seeing = [SeeingSample(time: t0, seeing: 3, transparency: 2)]
    let merged = ForecastService.merge(hours: hours, seeing: seeing)
    #expect(merged[0].seeing == 3)
    #expect(merged[2].seeing == 3)
    #expect(merged[3].seeing == nil)
    #expect(merged[2].transparency == 2)
}

struct StubFetcher: Fetcher {
    let byHost: [String: Data]
    func get(_ url: URL) async throws -> Data {
        guard let d = byHost[url.host ?? ""] else { throw URLError(.badURL) }
        return d
    }
}

@Test func fetchSurvivesSevenTimerFailure() async throws {
    let om = try fixture("openmeteo.json")
    let f = StubFetcher(byHost: ["api.open-meteo.com": om])
    let site = Site(name: "S", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let fc = try await ForecastService.fetch(site: site, fetcher: f, now: Date())
    #expect(fc.hours.count == 72)
    #expect(fc.seeingSource == nil)
}

@Test func fetchMergesSevenTimerWhenPresent() async throws {
    let f = StubFetcher(byHost: ["api.open-meteo.com": try fixture("openmeteo.json"), "www.7timer.info": try fixture("seventimer.json")])
    let site = Site(name: "S", latitude: 53.38, longitude: -1.47, elevationM: 100, timeZoneID: "Europe/London", bortle: 5)
    let fc = try await ForecastService.fetch(site: site, fetcher: f, now: Date())
    #expect(fc.seeingSource == "7Timer")
    #expect(fc.hours.contains { $0.seeing != nil })
}
