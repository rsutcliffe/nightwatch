import SwiftUI

extension Color {
    public init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255, opacity: opacity)
    }
}

/// Design tokens, v0.4 spec §4. The spec's dotted names are in the comments.
public enum Tokens {
    public static let textPrimary = Color(hex: 0xE8EAEF)                 // text.primary
    public static let textSecondary = Color(hex: 0xA8AEBE)               // text.secondary
    public static let accentClear = Color(hex: 0xFF453A)                 // accent.clear: the app red, chosen to keep night vision (owner ruling)
    public static let accentClearLow = Color(hex: 0x7A231E)              // accent.clear.low
    public static let statusWarning = Color(hex: 0xF5B041)               // status.warning
    public static let controlOn = Color(hex: 0x0A84FF)                   // control.on: system blue, never green
    public static let glassTint = Color(hex: 0x0C0E16, opacity: 0.62)    // glass.tint
    public static let glassHairline = Color.white.opacity(0.12)          // glass.hairline
    public static let surfaceTile = Color.white.opacity(0.06)            // surface.tile
    public static let surfaceTrack = Color.white.opacity(0.07)           // surface.track
    public static let surfaceButton = Color.white.opacity(0.23)          // surface.button
    public static let tickCloudy = Color.white.opacity(0.31)             // tick.cloudy
    public static let tickPartCloud = Color.white.opacity(0.47)          // tick.partcloud
    public static let tickDaylight = Color.white.opacity(0.12)           // tick.daylight
    public static let barCloudy = Color.white.opacity(0.35)              // bar.cloudy
    public static let targetsBackground = Color(hex: 0x14171D)           // targets.background
    public static let targetsCard = Color(hex: 0x1C1F27)                 // targets.card
    public static let targetsTrack = Color(hex: 0x272A34)                // targets.track
    public static let bestLine = Color(hex: 0xCDD2DC)                    // handover type table: the target "Best" line

    /// accent.clear.low blended towards accent.clear by u (0…1). Done by hand: Color.mix is macOS 15.
    public static func clearBlend(_ u: Double) -> Color {
        let u = min(1, max(0, u))
        func lerp(_ a: Double, _ b: Double) -> Double { (a + (b - a) * u) / 255 }
        return Color(.sRGB, red: lerp(0x7A, 0xFF), green: lerp(0x23, 0x45), blue: lerp(0x1E, 0x3A), opacity: 1)
    }
}
