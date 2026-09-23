import Foundation

/// NASA Scientific Visualization Studio "Dial-a-Moon": a rendered image of the Moon as seen from Earth
/// for any UTC hour of the current year. Public domain. https://svs.gsfc.nasa.gov/5587
public enum MoonImage {
    /// The API URL for the hour containing `date` (UTC, minutes zeroed so one image is cached per hour).
    public static func apiURL(for date: Date) -> URL {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd'T'HH:00"
        return URL(string: "https://svs.gsfc.nasa.gov/api/dialamoon/\(f.string(from: date))")!
    }

    /// Cache key for the same hour: yyyyMMddHH in UTC.
    public static func hourKey(for date: Date) -> String {
        let f = DateFormatter()
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMddHH"
        return f.string(from: date)
    }

    public struct Info: Equatable, Sendable {
        public let imageURL: URL          // 730 × 730 JPEG
        public let phasePercent: Double   // illuminated fraction, 0–100
        public let ageDays: Double
    }

    private struct Payload: Decodable {
        struct Image: Decodable { let url: String }
        let image: Image
        let phase: Double
        let age: Double
    }

    public static func parse(_ data: Data) throws -> Info {
        let p = try JSONDecoder().decode(Payload.self, from: data)
        guard let url = URL(string: p.image.url) else { throw ForecastError.malformed("moon image url") }
        return Info(imageURL: url, phasePercent: p.phase, ageDays: p.age)
    }
}
