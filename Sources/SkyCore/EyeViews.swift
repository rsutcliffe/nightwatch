import Foundation

/// The Eyes and binoculars group (#63, owner-approved mock-up, 29 September 2026): what can be seen tonight without a
/// telescope, for someone with a camera and lens, binoculars or a first telescope.
public enum EyeView: String, Sendable { case nakedEye = "Naked eye", binoculars = "Binoculars" }

public enum EyeViews {
    /// The faintest star the eye sees at each Bortle class (the scale's own naked-eye limiting magnitudes).
    static let nakedEyeLimit: [Int: Double] = [1: 7.6, 2: 7.1, 3: 6.6, 4: 6.1, 5: 5.6, 6: 5.1, 7: 4.6, 8: 4.1, 9: 4.0]
    /// Binoculars reach about magnitude 8, and an object under 5′ is a point rather than something to see.
    static let binocularLimit = 8.0, binocularMinArcmin = 5.0

    /// How `t` can be seen from a sky of `bortle`, or nil when it needs a telescope. The Moon always; planets by brightness;
    /// deep sky by brightness and, for binoculars, size. A deep-sky target the Moon washes out tonight is left out. Stars and
    /// constellations are left out too: every one of them is a naked-eye sight, so listing them would bury the rest.
    public static func view(_ t: RankedTarget, bortle: Int) -> EyeView? {
        let limit = nakedEyeLimit[min(9, max(1, bortle))]!
        if t.id == "moon" { return .nakedEye }
        guard let m = t.magnitude else { return nil }
        switch t.group {
        case .planets:
            return m <= limit ? .nakedEye : (m <= binocularLimit ? .binoculars : nil)
        case .nebulae, .galaxies, .clusters:
            guard !t.moonWashed else { return nil }
            if m <= limit { return .nakedEye }
            return m <= binocularLimit && (t.sizeArcmin ?? 0) >= binocularMinArcmin ? .binoculars : nil
        default:
            return nil
        }
    }

    /// Events anyone can watch without a telescope: meteors, the space station, conjunctions, a lunar eclipse. Comets are
    /// left out (their brightness is not known here) and a solar eclipse is never suggested for the eye.
    public static func includes(_ e: SkyEvent) -> Bool {
        [.meteorShower, .issPass, .conjunction, .lunarEclipse].contains(e.kind)
    }
}

extension Copy {
    /// What it looks like, not how to photograph it: "A faint smudge to the eye", "A fuzzy ball in binoculars".
    public static func eyeLook(_ t: RankedTarget, _ v: EyeView) -> String {
        let eye = v == .nakedEye
        if t.id == "moon" { return "Craters along the shadow line in binoculars" }
        switch t.group {
        case .planets: return eye ? "A bright star that does not twinkle" : "A small steady point in binoculars"
        case .galaxies: return eye ? "A faint smudge to the eye" : "A small oval glow in binoculars"
        case .clusters where t.typeName == "Globular cluster": return eye ? "A fuzzy star to the eye" : "A fuzzy ball in binoculars"
        case .clusters: return eye ? "A misty patch to the eye" : "A spray of stars in binoculars"
        default: return eye ? "A misty glow to the eye" : "A small grey patch in binoculars"
        }
    }
}
