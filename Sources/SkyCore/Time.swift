import CAstronomyEngine
import Foundation

/// Unix seconds at the J2000 epoch, 2000-01-01T12:00:00Z.
let j2000Unix: TimeInterval = 946_728_000

extension astro_time_t {
    init(_ date: Date) {
        self = Astronomy_TimeFromDays((date.timeIntervalSince1970 - j2000Unix) / 86_400)
    }
    var date: Date { Date(timeIntervalSince1970: ut * 86_400 + j2000Unix) }
}
