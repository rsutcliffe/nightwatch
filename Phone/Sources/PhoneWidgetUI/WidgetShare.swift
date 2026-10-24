import Foundation
import SkyCore

/// How the app hands the widget what to draw: the same snapshot the Tonight page was built from, kept in the shared App Group's
/// defaults, so the widget can never disagree with the app. The widget never fetches anything.
public enum WidgetShare {
    public static let group = "group.io.github.rsutcliffe.nightwatch.phone"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: group) }

    public static func save(_ snapshot: WidgetSnapshot) {
        let e = JSONEncoder(); e.dateEncodingStrategy = .iso8601
        if let data = try? e.encode(snapshot) { defaults?.set(data, forKey: "snapshot") }
    }

    public static func load() -> WidgetSnapshot? {
        guard let data = defaults?.data(forKey: "snapshot") else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(WidgetSnapshot.self, from: data)
    }

    /// Red night mode, per device, mirrored here so the widget follows it.
    public static var red: Bool {
        get { defaults?.bool(forKey: "red") ?? false }
        set { defaults?.set(newValue, forKey: "red") }
    }
}
