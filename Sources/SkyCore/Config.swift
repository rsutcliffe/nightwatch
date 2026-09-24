import Foundation

public struct TelescopePreset: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let widthDeg: Double
    public let heightDeg: Double
    public let source: String
    public var fov: FieldOfView { FieldOfView(widthDeg: widthDeg, heightDeg: heightDeg) }
}

public enum TelescopePresets {
    public static func bundled() throws -> [TelescopePreset] {
        guard let url = Bundle.module.url(forResource: "telescopes", withExtension: "json", subdirectory: "Resources/presets") else {
            throw CatalogError.missingResource("telescopes")
        }
        return try JSONDecoder().decode([TelescopePreset].self, from: Data(contentsOf: url))
    }
}

public struct Config: Codable, Equatable, Sendable {
    public var sites: [Site] = []
    public var activeSiteName: String? = nil          // nil = automatic location when available
    public var fov = FieldOfView(widthDeg: 2.1, heightDeg: 1.2)
    public var fovPresetID: String? = "dwarf-mini"
    public var goRule = GoRule()
    public var alerts = AlertSettings()
    public var flavour: Flavour = .watch
    public var loginItem = false
    public var notifyEnabled = true
    public var darkSites = DarkSiteSettings()
    public var brightNights = BrightSettings()

    public init() {}
    public static let `default` = Config()

    /// Manual site wins when named; otherwise the automatic fix; otherwise the first saved site.
    public func activeSite(auto: Site?) -> Site? {
        if let n = activeSiteName, let s = sites.first(where: { $0.name == n }) { return s }
        return auto ?? sites.first
    }

    enum CodingKeys: String, CodingKey {
        case sites, activeSiteName, fov, fovPresetID, goRule, alerts, flavour, loginItem, notifyEnabled, darkSites, brightNights
    }

    /// Missing keys fall back to the same defaults as `init()`, so a config file written by an
    /// older version (fewer fields) still decodes instead of throwing.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        sites = try c.decodeIfPresent([Site].self, forKey: .sites) ?? []
        activeSiteName = try c.decodeIfPresent(String.self, forKey: .activeSiteName)
        fov = try c.decodeIfPresent(FieldOfView.self, forKey: .fov) ?? FieldOfView(widthDeg: 2.1, heightDeg: 1.2)
        fovPresetID = try c.decodeIfPresent(String.self, forKey: .fovPresetID) ?? "dwarf-mini"
        goRule = try c.decodeIfPresent(GoRule.self, forKey: .goRule) ?? GoRule()
        alerts = try c.decodeIfPresent(AlertSettings.self, forKey: .alerts) ?? AlertSettings()
        flavour = try c.decodeIfPresent(Flavour.self, forKey: .flavour) ?? .watch
        loginItem = try c.decodeIfPresent(Bool.self, forKey: .loginItem) ?? false
        notifyEnabled = try c.decodeIfPresent(Bool.self, forKey: .notifyEnabled) ?? true
        darkSites = try c.decodeIfPresent(DarkSiteSettings.self, forKey: .darkSites) ?? DarkSiteSettings()
        brightNights = try c.decodeIfPresent(BrightSettings.self, forKey: .brightNights) ?? BrightSettings()
    }
}

/// Bright-night mode (v0.3): Moon and planets on nights when the dark rule cannot be met.
/// Windows are bounded by nautical twilight; 1 h minimum by owner ruling (Home gets 1.56 h at the solstice).
public struct BrightSettings: Codable, Equatable, Sendable {
    public var enabled = false
    public var minHours: Double = 1
    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        minHours = min(6, max(1, try c.decodeIfPresent(Double.self, forKey: .minHours) ?? 1))
    }
    enum CodingKeys: String, CodingKey { case enabled, minHours }
}

public struct DarkSiteSettings: Codable, Equatable, Sendable {
    public var enabled = true
    public var radiusKm: Double = 50
    public var unit: DistanceUnit = .km
    public init() {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        radiusKm = min(max(try c.decodeIfPresent(Double.self, forKey: .radiusKm) ?? 50, 5), 300)
        // An unknown unit (hand edit, newer version) reads as km rather than failing the whole config.
        unit = (try c.decodeIfPresent(String.self, forKey: .unit)).flatMap(DistanceUnit.init(rawValue:)) ?? .km
    }
    enum CodingKeys: String, CodingKey { case enabled, radiusKm, unit }
}

public enum ConfigStore {
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nightwatch", isDirectory: true).appendingPathComponent("config.json")
    }

    /// Missing path: defaults. Anything at the path (attributesOfItem does not follow the final symlink, so a
    /// dangling symlink counts) must decode or this throws, so the caller never mistakes it for "no config yet".
    public static func load(from url: URL) throws -> Config {
        guard (try? FileManager.default.attributesOfItem(atPath: url.path)) != nil else { return .default }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try d.decode(Config.self, from: Data(contentsOf: url))
    }

    /// Resolves `url` to its real path first so an atomic write to a synced-settings symlink
    /// replaces the symlink's target, not the symlink itself.
    public static func save(_ config: Config, to url: URL) throws {
        let target = url.resolvingSymlinksInPath()
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
        try e.encode(config).write(to: target, options: .atomic)
    }
}
