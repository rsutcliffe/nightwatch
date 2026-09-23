import CAstronomyEngine
import Foundation

public struct CometElements: Codable, Equatable, Sendable {
    public var orbitType: String
    public var designation: String
    public var q: Double
    public var e: Double
    public var periDeg: Double
    public var nodeDeg: Double
    public var incDeg: Double
    public var perihelionYear: Int
    public var perihelionMonth: Int
    public var perihelionDay: Double
    public var epochYear: Int?
    public var epochMonth: Int?
    public var epochDay: Int?
    public var h: Double?
    public var g: Double?

    enum CodingKeys: String, CodingKey {
        case orbitType = "Orbit_type", designation = "Designation_and_name", q = "Perihelion_dist", e
        case periDeg = "Peri", nodeDeg = "Node", incDeg = "i"
        case perihelionYear = "Year_of_perihelion", perihelionMonth = "Month_of_perihelion", perihelionDay = "Day_of_perihelion"
        case epochYear = "Epoch_year", epochMonth = "Epoch_month", epochDay = "Epoch_day", h = "H", g = "G"
    }

    var perihelionDate: Date {
        var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "UTC")!
        let whole = Int(perihelionDay.rounded(.down))
        let d = cal.date(from: DateComponents(year: perihelionYear, month: perihelionMonth, day: whole))!
        return d.addingTimeInterval((perihelionDay - Double(whole)) * 86_400)
    }
}

public struct CometPosition: Equatable, Sendable {
    public let raHours: Double
    public let decDeg: Double
    public let magnitude: Double
    public let deltaAU: Double
    public let rAU: Double
}

public enum Comets {
    public static let url = URL(string: "https://www.minorplanetcenter.net/Extended_Files/cometels.json.gz")!

    public static func decode(_ data: Data) throws -> [CometElements] {
        try JSONDecoder().decode([CometElements].self, from: data)
    }

    private static let k = 0.017_202_098_95          // Gaussian gravitational constant, rad/day
    private static let obliquity = 23.439_291_1 * Double.pi / 180

    /// Heliocentric distance r and true anomaly ν at `dt` days from perihelion.
    static func anomaly(q: Double, e: Double, dt: Double) -> (r: Double, nu: Double) {
        if abs(e - 1) < 1e-6 {
            let w = 1.5 * k / sqrt(2 * q * q * q) * dt
            let y = cbrt(w + sqrt(w * w + 1))
            let s = y - 1 / y
            return (q * (1 + s * s), 2 * atan(s))
        }
        if e < 1 {
            let a = q / (1 - e)
            let m = k / pow(a, 1.5) * dt
            var ecc = m
            for _ in 0..<50 { ecc -= (ecc - e * sin(ecc) - m) / (1 - e * cos(ecc)) }
            let nu = 2 * atan2(sqrt(1 + e) * sin(ecc / 2), sqrt(1 - e) * cos(ecc / 2))
            return (a * (1 - e * cos(ecc)), nu)
        }
        let a = q / (e - 1)
        let m = k / pow(a, 1.5) * dt
        var hh = asinh(m / e)
        for _ in 0..<50 { hh -= (e * sinh(hh) - hh - m) / (e * cosh(hh) - 1) }
        let nu = 2 * atan2(sqrt(e + 1) * sinh(hh / 2), sqrt(e - 1) * cosh(hh / 2))
        return (a * (e * cosh(hh) - 1), nu)
    }

    public static func position(_ c: CometElements, at date: Date) -> CometPosition? {
        let dt = date.timeIntervalSince(c.perihelionDate) / 86_400
        let (r, nu) = anomaly(q: c.q, e: c.e, dt: dt)
        guard r.isFinite, nu.isFinite else { return nil }
        let d2r = Double.pi / 180
        let w = c.periDeg * d2r, om = c.nodeDeg * d2r, inc = c.incDeg * d2r
        let u = w + nu
        // heliocentric ecliptic J2000
        let x = r * (cos(om) * cos(u) - sin(om) * sin(u) * cos(inc))
        let y = r * (sin(om) * cos(u) + cos(om) * sin(u) * cos(inc))
        let z = r * (sin(u) * sin(inc))
        // ecliptic -> equatorial J2000
        let xe = x
        let ye = y * cos(obliquity) - z * sin(obliquity)
        let ze = y * sin(obliquity) + z * cos(obliquity)
        let earth = Astronomy_HelioVector(BODY_EARTH, astro_time_t(date))
        guard earth.status == ASTRO_SUCCESS else { return nil }
        let gx = xe - earth.x, gy = ye - earth.y, gz = ze - earth.z
        let delta = sqrt(gx * gx + gy * gy + gz * gz)
        var ra = atan2(gy, gx) / d2r / 15
        if ra < 0 { ra += 24 }
        let dec = asin(gz / delta) / d2r
        let mag = (c.h ?? 20) + 5 * log10(delta) + 2.5 * (c.g ?? 4) * log10(r)
        return CometPosition(raHours: ra, decDeg: dec, magnitude: mag, deltaAU: delta, rAU: r)
    }

    /// Comets brighter than `limit` at `date`, brightest first.
    public static func bright(_ comets: [CometElements], at date: Date, limit: Double = 12) -> [(CometElements, CometPosition)] {
        comets.compactMap { c in position(c, at: date).map { (c, $0) } }
            .filter { $0.1.magnitude <= limit }
            .sorted { $0.1.magnitude < $1.1.magnitude }
    }
}
