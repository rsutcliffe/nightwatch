import Foundation
import SkyCore

/// Where a `nightwatch://` link (from the widget, or a Shortcut) takes the app. SkyCore's `WidgetLink` reads the URL; this says which page.
public enum LinkRoute: Equatable, Sendable { case plan, targets }

public extension WidgetLink {
    /// Plan has its own page; everything else lands in Targets (a target opens its page there, a search opens the list).
    var phoneRoute: LinkRoute { if case .plan = self { return .plan }; return .targets }
}

public extension PhoneStore {
    /// A target by its id, from tonight's lists, the favourites and the Milky Way entries; nil when it is not one of tonight's.
    func target(withID id: String) -> RankedTarget? {
        guard let p = planning?.tonight else { return nil }
        let pool = p.targets + p.brightTargets + p.best + p.favourites.map(\.target) + milkyWayTonight
        return pool.first { $0.id == id }
    }
}
