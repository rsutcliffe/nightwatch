import Foundation
import SkyCore

/// The service answered, and said no. SkyCore's own fetcher turns every non-2xx into one anonymous `badServerResponse`, which made a daily
/// request limit look like a missing connection; this keeps the status, and the service's own reason when it gives one.
public struct HTTPFailure: Error, Equatable, Sendable {
    public let status: Int
    public let reason: String?
    public init(status: Int, reason: String?) { self.status = status; self.reason = reason }
    /// Too many requests from this address (Open-Meteo says "Daily API request limit exceeded" with a 429).
    public var isRateLimit: Bool { status == 429 }
}

/// The same request SkyCore's `URLSessionFetcher` makes (named agent, 20 second timeout), but a refusal keeps its status and reason.
public struct PhoneFetcher: Fetcher {
    public var timeout: TimeInterval
    public init(timeout: TimeInterval = 20) { self.timeout = timeout }
    public func get(_ url: URL) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: timeout)
        req.setValue(URLSessionFetcher.userAgent, forHTTPHeaderField: "User-Agent")
        RequestTally.record(url)
        let (data, response) = try await URLSession.shared.data(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            let reason = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["reason"] as? String
            throw HTTPFailure(status: http.statusCode, reason: reason)
        }
        return data
    }
}
