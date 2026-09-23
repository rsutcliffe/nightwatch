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

    public init() {}
    public static let `default` = Config()

    /// Manual site wins when named; otherwise the automatic fix; otherwise the first saved site.
    public func activeSite(auto: Site?) -> Site? {
        if let n = activeSiteName, let s = sites.first(where: { $0.name == n }) { return s }
        return auto ?? sites.first
    }
}

public enum ConfigStore {
    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Nightwatch", isDirectory: true).appendingPathComponent("config.json")
    }

    public static func load(from url: URL) throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else { return .default }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try d.decode(Config.self, from: Data(contentsOf: url))
    }

    public static func save(_ config: Config, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let e = JSONEncoder(); e.outputFormatting = [.prettyPrinted, .sortedKeys]; e.dateEncodingStrategy = .iso8601
        try e.encode(config).write(to: url, options: .atomic)
    }
}
