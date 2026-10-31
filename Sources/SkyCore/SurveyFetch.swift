import Foundation

/// NASA SkyView's cutout of the same Digitized Sky Survey plates, for when CDS's hips2fits cannot be reached (it was down for days from
/// 26 October 2026, and every target photo fell back to its icon). Greyscale, where CDS's is colour.
public enum SkyViewCutout {
    /// SkyView gave a 1200 px wide image and refused or overloaded at larger sizes in testing (30 October 2026).
    static let maxWidth = 1200

    /// The SkyView request that covers what a hips2fits request covers; nil for any other URL.
    public static func fallback(for cds: URL) -> URL? {
        guard cds.host == "alasky.cds.unistra.fr",
              let q = URLComponents(url: cds, resolvingAgainstBaseURL: false)?.queryItems,
              let ra = value("ra", q), let dec = value("dec", q), let fov = value("fov", q),
              let w = value("width", q), let h = value("height", q), w > 0, h > 0 else { return nil }
        let width = min(Int(w), maxWidth), height = max(1, Int((Double(width) * h / w).rounded()))
        var c = URLComponents(string: "https://skyview.gsfc.nasa.gov/current/cgi/runquery.pl")!
        c.queryItems = [
            .init(name: "Position", value: String(format: "%.5f,%.5f", ra, dec)),
            .init(name: "Survey", value: "DSS2 Red"),
            .init(name: "Pixels", value: "\(width),\(height)"),
            .init(name: "Size", value: String(format: "%.4f,%.4f", fov, fov * h / w)),
            .init(name: "Projection", value: "Tan"),
            .init(name: "Return", value: "JPEG")
        ]
        return c.url
    }

    private static func value(_ name: String, _ q: [URLQueryItem]) -> Double? { q.first { $0.name == name }?.value.flatMap(Double.init) }
}

/// Survey photos: CDS first, SkyView when CDS cannot be reached. Once CDS has failed it is not tried again for ten minutes, so a screen of
/// cards does not each wait out a timeout. SkyView is a shared NASA service that answers "Too Many Processes" (with a 200 and a web page) when
/// busy (about half of the requests in testing on 30 October 2026), so it is asked for two images at a time, a busy page is tried again after
/// a pause, and anything that is not a JPEG is a failure.
public actor SurveyFetch {
    public static let shared = SurveyFetch()
    public typealias Get = @Sendable (URL, TimeInterval) async throws -> Data

    static let retryAfter: TimeInterval = 600
    private let slots = 2
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var cdsDownUntil = Date.distantPast

    public init() {}

    public func image(_ url: URL, timeout: TimeInterval, now: Date = Date(), retryDelay: Duration = .seconds(2),
                      get: Get = { try await URLSessionFetcher(timeout: $1).get($0) }) async -> Data? {
        guard let fallback = SkyViewCutout.fallback(for: url) else { return try? await get(url, timeout) }
        if now >= cdsDownUntil {
            if let data = try? await get(url, timeout), !data.isEmpty { return data }
            cdsDownUntil = now.addingTimeInterval(Self.retryAfter)
        }
        await acquire()
        defer { release() }
        for attempt in 0..<4 {
            if attempt > 0 { try? await Task.sleep(for: retryDelay * attempt) }
            if let data = try? await get(fallback, timeout), Self.isJPEG(data) { return data }
        }
        return nil
    }

    static func isJPEG(_ d: Data) -> Bool { d.starts(with: [0xFF, 0xD8]) }

    private func acquire() async {
        if running < slots { running += 1; return }
        await withCheckedContinuation { waiting.append($0) }
    }

    private func release() {
        if waiting.isEmpty { running -= 1 } else { waiting.removeFirst().resume() }
    }
}
