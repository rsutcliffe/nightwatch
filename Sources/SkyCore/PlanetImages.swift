import Foundation

/// Bundled public-domain planet photographs (NASA missions via Wikimedia Commons; see NOTICE).
public enum PlanetImages {
    /// File URL for a planet's image, or nil when none is bundled.
    public static func url(for planet: Planet) -> URL? {
        Bundle.module.url(forResource: planet.rawValue, withExtension: "jpg", subdirectory: "Resources/planets")
    }

    /// The planet behind a ranked-target id of the form "planet-<name>".
    public static func planet(forTargetID id: String) -> Planet? {
        guard id.hasPrefix("planet-") else { return nil }
        return Planet(rawValue: String(id.dropFirst("planet-".count)))
    }
}
