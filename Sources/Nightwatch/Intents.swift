import AppIntents
import SkyCore

// Siri, Spotlight and Shortcuts (#53). Every answer comes from the forecast already cached: nothing is fetched at ask time,
// except by Refresh. Phrases carry no parameters: a September 2026 trial whose phrases did made the Shortcuts app crash.

/// The running app's store, set at launch, so the actions read the same plan the popover shows.
@MainActor enum IntentHost { static weak var store: Store? }

struct TonightIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Tonight Clear"
    static let description = IntentDescription("Tonight's sky score and clear window at your site, and tomorrow's outlook.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(Copy.siriTonight(IntentHost.store?.snapshot()))")
    }
}

struct BestTargetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Best Targets Tonight"
    static let description = IntentDescription("Tonight's plan, or the best targets for your telescope tonight.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = IntentHost.store
        return .result(dialog: "\(Copy.siriBest(store?.snapshot(), session: store?.session(for: store?.plan), site: store?.site))")
    }
}

struct TargetEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Target"
    static let defaultQuery = TargetQuery()
    let id: String
    let name: String
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct TargetQuery: EntityStringQuery {
    @MainActor private func targets() -> [RankedTarget] {
        guard let p = IntentHost.store?.plan else { return [] }
        var seen = Set<String>()
        return (p.targets + p.brightTargets + p.favourites.map(\.target)).filter { seen.insert($0.id).inserted }
    }
    @MainActor func entities(for identifiers: [String]) async throws -> [TargetEntity] {
        targets().filter { identifiers.contains($0.id) }.map { TargetEntity(id: $0.id, name: $0.name) }
    }
    @MainActor func entities(matching string: String) async throws -> [TargetEntity] {
        targets().filter { $0.matches(string) }.map { TargetEntity(id: $0.id, name: $0.name) }
    }
    @MainActor func suggestedEntities() async throws -> [TargetEntity] {
        Array(targets().prefix(20)).map { TargetEntity(id: $0.id, name: $0.name) }
    }
}

struct ShowTargetIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Target"
    static let description = IntentDescription("Opens a target's page in the Targets window.")
    static let openAppWhenRun = true
    @Parameter(title: "Target") var target: TargetEntity
    @MainActor func perform() async throws -> some IntentResult {
        AppDelegate.onURL?(WidgetLink.target(target.id).url)
        return .result()
    }
}

struct EventsTonightIntent: AppIntent {
    static let title: LocalizedStringResource = "Events Tonight"
    static let description = IntentDescription("Meteor showers, space station passes, eclipses and other events tonight.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: "\(Copy.siriEvents(IntentHost.store?.events ?? []))")
    }
}

struct RefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Forecast"
    static let description = IntentDescription("Fetches the forecast now and works out tonight again.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let store = IntentHost.store else { return .result(dialog: "Nightwatch isn't running.") }
        await store.refresh(force: true)
        return .result(dialog: "\("Refreshed. " + Copy.siriTonight(store.snapshot()))")
    }
}

struct NotificationsOnIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn On Clear-Sky Notifications"
    static let description = IntentDescription("Turns Nightwatch's clear-sky notifications on.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentHost.store?.setNotifications(true)
        return .result(dialog: "Clear-sky notifications are on.")
    }
}

struct NotificationsOffIntent: AppIntent {
    static let title: LocalizedStringResource = "Turn Off Clear-Sky Notifications"
    static let description = IntentDescription("Turns Nightwatch's clear-sky notifications off.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog {
        IntentHost.store?.setNotifications(false)
        return .result(dialog: "Clear-sky notifications are off.")
    }
}

struct NightwatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: TonightIntent(), phrases: ["Is tonight clear in \(.applicationName)", "Check the sky in \(.applicationName)"],
                    shortTitle: "Is Tonight Clear", systemImageName: "moon.stars")
        AppShortcut(intent: BestTargetsIntent(), phrases: ["What should I image tonight in \(.applicationName)", "Best targets in \(.applicationName)"],
                    shortTitle: "Best Targets", systemImageName: "scope")
        AppShortcut(intent: ShowTargetIntent(), phrases: ["Show a target in \(.applicationName)"],
                    shortTitle: "Show Target", systemImageName: "sparkles")
        AppShortcut(intent: EventsTonightIntent(), phrases: ["Any events tonight in \(.applicationName)", "\(.applicationName) events tonight"],
                    shortTitle: "Events Tonight", systemImageName: "calendar")
        AppShortcut(intent: RefreshIntent(), phrases: ["Refresh \(.applicationName)", "Refresh the forecast in \(.applicationName)"],
                    shortTitle: "Refresh", systemImageName: "arrow.clockwise")
        AppShortcut(intent: NotificationsOnIntent(), phrases: ["Turn on \(.applicationName) notifications"],
                    shortTitle: "Notifications On", systemImageName: "bell")
        AppShortcut(intent: NotificationsOffIntent(), phrases: ["Turn off \(.applicationName) notifications"],
                    shortTitle: "Notifications Off", systemImageName: "bell.slash")
    }
}
