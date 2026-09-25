import CAstronomyEngine
import Foundation

public struct Site: Codable, Equatable, Sendable {
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var elevationM: Double
    public var timeZoneID: String
    public var bortle: Int

    public init(name: String, latitude: Double, longitude: Double, elevationM: Double, timeZoneID: String, bortle: Int) {
        self.name = name; self.latitude = latitude; self.longitude = longitude
        self.elevationM = elevationM; self.timeZoneID = timeZoneID; self.bortle = bortle
    }

    public var timeZone: TimeZone { TimeZone(identifier: timeZoneID) ?? .current }

    public var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = timeZone
        return c
    }

    var observer: astro_observer_t { Astronomy_MakeObserver(latitude, longitude, elevationM) }
}

/// Plain names for the Bortle scale (v0.6.5), so a sky's darkness is chosen by what it looks like, not a bare number.
public enum Bortle {
    public static func name(_ level: Int) -> String {
        switch level {
        case ...1: "Pristine"
        case 2: "Truly dark"
        case 3: "Rural"
        case 4: "Rural and suburban edge"
        case 5: "Suburban"
        case 6: "Bright suburban"
        case 7: "Suburban and urban edge"
        case 8: "City"
        default: "Inner city"
        }
    }
}
