import Foundation

public struct HourlyConditions: Codable, Equatable, Sendable {
    public var time: Date
    public var cloudTotal: Int
    public var cloudLow: Int?
    public var cloudMid: Int?
    public var cloudHigh: Int?
    public var tempC: Double?
    public var dewPointC: Double?
    public var humidityPct: Int?
    public var windKmh: Double?
    public var gustKmh: Double?
    public var visibilityM: Double?
    public var seeing: Int?
    public var transparency: Int?

    public init(time: Date, cloudTotal: Int, cloudLow: Int?, cloudMid: Int?, cloudHigh: Int?, tempC: Double?, dewPointC: Double?,
                humidityPct: Int?, windKmh: Double?, gustKmh: Double?, visibilityM: Double?, seeing: Int?, transparency: Int?) {
        self.time = time; self.cloudTotal = cloudTotal; self.cloudLow = cloudLow; self.cloudMid = cloudMid; self.cloudHigh = cloudHigh
        self.tempC = tempC; self.dewPointC = dewPointC; self.humidityPct = humidityPct; self.windKmh = windKmh; self.gustKmh = gustKmh
        self.visibilityM = visibilityM; self.seeing = seeing; self.transparency = transparency
    }
}

public struct Forecast: Codable, Equatable, Sendable {
    public var fetchedAt: Date
    public var latitude: Double
    public var longitude: Double
    public var hours: [HourlyConditions]
    public var seeingSource: String?
    public init(fetchedAt: Date, latitude: Double, longitude: Double, hours: [HourlyConditions], seeingSource: String?) {
        self.fetchedAt = fetchedAt; self.latitude = latitude; self.longitude = longitude; self.hours = hours; self.seeingSource = seeingSource
    }
}

public protocol Fetcher: Sendable {
    func get(_ url: URL) async throws -> Data
}

public struct URLSessionFetcher: Fetcher {
    public init() {}
    public func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 20)
        req.setValue("Nightwatch/0.1 (https://github.com/rsutcliffe/nightwatch)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }
}

public enum ForecastError: Error { case malformed(String) }

public enum OpenMeteo {
    static let variables = ["cloud_cover", "cloud_cover_low", "cloud_cover_mid", "cloud_cover_high", "dew_point_2m", "temperature_2m",
                            "relative_humidity_2m", "wind_speed_10m", "wind_gusts_10m", "visibility"]

    public static func url(latitude: Double, longitude: Double, days: Int) -> URL {
        var c = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        c.queryItems = [
            .init(name: "latitude", value: String(format: "%.4f", latitude)),
            .init(name: "longitude", value: String(format: "%.4f", longitude)),
            .init(name: "hourly", value: variables.joined(separator: ",")),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: String(days))
        ]
        return c.url!
    }

    private struct Payload: Decodable {
        let utc_offset_seconds: Double
        let hourly: Hourly
        struct Hourly: Decodable {
            let time: [String]
            let cloud_cover: [Int?]
            let cloud_cover_low: [Int?]?
            let cloud_cover_mid: [Int?]?
            let cloud_cover_high: [Int?]?
            let dew_point_2m: [Double?]?
            let temperature_2m: [Double?]?
            let relative_humidity_2m: [Int?]?
            let wind_speed_10m: [Double?]?
            let wind_gusts_10m: [Double?]?
            let visibility: [Double?]?
        }
    }

    public static func parse(_ data: Data) throws -> [HourlyConditions] {
        let p = try JSONDecoder().decode(Payload.self, from: data)
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        var out: [HourlyConditions] = []
        for (i, ts) in p.hourly.time.enumerated() {
            guard let local = f.date(from: ts) else { throw ForecastError.malformed("time \(ts)") }
            func at<T>(_ a: [T?]?) -> T? { guard let a, i < a.count else { return nil }; return a[i] }
            out.append(HourlyConditions(
                time: local.addingTimeInterval(-p.utc_offset_seconds),
                cloudTotal: at(p.hourly.cloud_cover) ?? 100,
                cloudLow: at(p.hourly.cloud_cover_low), cloudMid: at(p.hourly.cloud_cover_mid), cloudHigh: at(p.hourly.cloud_cover_high),
                tempC: at(p.hourly.temperature_2m), dewPointC: at(p.hourly.dew_point_2m), humidityPct: at(p.hourly.relative_humidity_2m),
                windKmh: at(p.hourly.wind_speed_10m), gustKmh: at(p.hourly.wind_gusts_10m), visibilityM: at(p.hourly.visibility),
                seeing: nil, transparency: nil))
        }
        return out
    }
}

public struct SeeingSample: Equatable, Sendable {
    public let time: Date
    public let seeing: Int
    public let transparency: Int
    public init(time: Date, seeing: Int, transparency: Int) { self.time = time; self.seeing = seeing; self.transparency = transparency }
}

public enum SevenTimer {
    public static func url(latitude: Double, longitude: Double) -> URL {
        var c = URLComponents(string: "http://www.7timer.info/bin/api.pl")!
        c.queryItems = [
            .init(name: "lon", value: String(format: "%.2f", longitude)),
            .init(name: "lat", value: String(format: "%.2f", latitude)),
            .init(name: "product", value: "astro"),
            .init(name: "output", value: "json")
        ]
        return c.url!
    }

    private struct Payload: Decodable {
        let `init`: String
        let dataseries: [Entry]
        struct Entry: Decodable { let timepoint: Double; let seeing: Int; let transparency: Int }
    }

    /// `init` is the model run in UTC as YYYYMMDDHH; `timepoint` is hours after that run (observed from live data, 2026-09-23).
    public static func parse(_ data: Data) throws -> [SeeingSample] {
        let p = try JSONDecoder().decode(Payload.self, from: data)
        let f = DateFormatter()
        f.dateFormat = "yyyyMMddHH"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let start = f.date(from: p.`init`) else { throw ForecastError.malformed("init \(p.`init`)") }
        return p.dataseries.map { SeeingSample(time: start.addingTimeInterval($0.timepoint * 3600), seeing: $0.seeing, transparency: $0.transparency) }
    }
}

public enum ForecastService {
    /// Attach the most recent 7Timer sample at or before each hour, held for at most 3 hours.
    public static func merge(hours: [HourlyConditions], seeing: [SeeingSample]) -> [HourlyConditions] {
        let sorted = seeing.sorted { $0.time < $1.time }
        return hours.map { h in
            var h = h
            if let s = sorted.last(where: { $0.time <= h.time }), h.time.timeIntervalSince(s.time) < 3 * 3600 {
                h.seeing = s.seeing
                h.transparency = s.transparency
            }
            return h
        }
    }

    public static func fetch(site: Site, fetcher: Fetcher, now: Date) async throws -> Forecast {
        let hours = try OpenMeteo.parse(try await fetcher.get(OpenMeteo.url(latitude: site.latitude, longitude: site.longitude, days: 3)))
        var seeingSource: String? = nil
        var merged = hours
        if let data = try? await fetcher.get(SevenTimer.url(latitude: site.latitude, longitude: site.longitude)),
           let samples = try? SevenTimer.parse(data), !samples.isEmpty {
            merged = merge(hours: hours, seeing: samples)
            seeingSource = "7Timer"
        }
        return Forecast(fetchedAt: now, latitude: site.latitude, longitude: site.longitude, hours: merged, seeingSource: seeingSource)
    }
}
