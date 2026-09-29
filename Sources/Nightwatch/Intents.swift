import AppIntents
import SwiftUI
import NightwatchUI
import SkyCore

// Siri, Spotlight and Shortcuts (#53). Every answer comes from the forecast already cached: nothing is fetched at ask time,
// except by Refresh. Phrases carry no parameters: a September 2026 trial whose phrases did made the Shortcuts app crash.
// Each answer is a card as well as a sentence: Spotlight runs an action without showing its sentence (owner's test,
// 29 September 2026), and a card carries the forecast's source, Apple Weather's mark where it supplied the forecast.
// Phrases name Nightwatch first: "Is tonight clear in …" went to Apple Weather, and "Best targets in …" to a web answer.

/// The running app's store, set at launch, so the actions read the same plan the popover shows.
@MainActor enum IntentHost { static weak var store: Store? }

struct TonightIntent: AppIntent {
    static let title: LocalizedStringResource = "Is Tonight Clear"
    static let description = IntentDescription("Tonight's sky score and clear window at your site, and tomorrow's outlook.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let snap = IntentHost.store?.snapshot()
        return .result(dialog: "\(Copy.siriTonight(snap))", view: TonightCard(snapshot: snap, mark: IntentHost.store?.weatherMark))
    }
}

struct BestTargetsIntent: AppIntent {
    static let title: LocalizedStringResource = "Best Targets Tonight"
    static let description = IntentDescription("Tonight's plan, or the best targets for your telescope tonight.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = IntentHost.store, snap = store?.snapshot()
        let text = Copy.siriBest(snap, session: store?.session(for: store?.plan), site: store?.site)
        return .result(dialog: "\(text)", view: AnswerCard(text: text, snapshot: snap, mark: store?.weatherMark))
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
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let text = Copy.siriEvents(IntentHost.store?.events ?? [])
        return .result(dialog: "\(text)", view: AnswerCard(text: text, snapshot: IntentHost.store?.snapshot(), mark: IntentHost.store?.weatherMark))
    }
}

struct RefreshIntent: AppIntent {
    static let title: LocalizedStringResource = "Refresh Forecast"
    static let description = IntentDescription("Fetches the forecast now and works out tonight again.")
    @MainActor func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let store = IntentHost.store
        await store?.refresh(force: true)
        let snap = store?.snapshot()
        return .result(dialog: "\("Refreshed. " + Copy.siriTonight(snap))", view: TonightCard(snapshot: snap, mark: store?.weatherMark))
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
        AppShortcut(intent: TonightIntent(), phrases: ["\(.applicationName) sky score", "What's the sky score in \(.applicationName)"],
                    shortTitle: "Sky Score", systemImageName: "moon.stars")
        AppShortcut(intent: BestTargetsIntent(), phrases: ["\(.applicationName) tonight's plan", "\(.applicationName) best targets"],
                    shortTitle: "Tonight's Plan", systemImageName: "scope")
        AppShortcut(intent: ShowTargetIntent(), phrases: ["Show a target in \(.applicationName)"],
                    shortTitle: "Show Target", systemImageName: "sparkles")
        AppShortcut(intent: EventsTonightIntent(), phrases: ["\(.applicationName) events tonight", "\(.applicationName) sky events"],
                    shortTitle: "Events Tonight", systemImageName: "calendar")
        AppShortcut(intent: RefreshIntent(), phrases: ["Refresh \(.applicationName)", "Refresh the \(.applicationName) forecast"],
                    shortTitle: "Refresh", systemImageName: "arrow.clockwise")
        AppShortcut(intent: NotificationsOnIntent(), phrases: ["Turn on \(.applicationName) notifications"],
                    shortTitle: "Notifications On", systemImageName: "bell")
        AppShortcut(intent: NotificationsOffIntent(), phrases: ["Turn off \(.applicationName) notifications"],
                    shortTitle: "Notifications Off", systemImageName: "bell.slash")
    }
}

/// The forecast's source at a card's foot: Apple Weather's mark when it supplied the forecast (Apple requires it wherever
/// WeatherKit data is shown), else the source's name.
struct SourceLine: View {
    let snapshot: WidgetSnapshot?
    let mark: NSImage?
    var body: some View {
        if let mark, snapshot?.source == "Apple Weather" {
            Image(nsImage: mark).resizable().scaledToFit().frame(height: 11).accessibilityLabel("Apple Weather")
        } else if let src = snapshot?.source {
            Text(src).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// "Is Tonight Clear" and "Refresh" as a card: the bezel, the verdict and the window, as the small widget draws them.
struct TonightCard: View {
    let snapshot: WidgetSnapshot?
    let mark: NSImage?
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if let s = snapshot {
                ScoreBezel(score: s.score, slots: s.slots, label: s.bezelLabel).frame(width: 92, height: 92)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tonight · \(s.siteName)").font(.caption).foregroundStyle(.secondary)
                    Text(s.headline).font(.headline)
                    ForEach([s.window, s.reason, s.tomorrow.map { "Tomorrow: \($0)" }].compactMap { $0 }, id: \.self) {
                        Text($0).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    }
                    SourceLine(snapshot: s, mark: mark).padding(.top, 2)
                }
            } else {
                Text(Copy.siriTonight(nil)).font(.callout)
            }
        }
        .padding()
    }
}

/// Tonight's plan, the best targets or the events, as a card with the forecast's source.
struct AnswerCard: View {
    let text: String
    let snapshot: WidgetSnapshot?
    let mark: NSImage?
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let s = snapshot { Text("Tonight · \(s.siteName)").font(.caption).foregroundStyle(.secondary) }
            Text(text).font(.callout).fixedSize(horizontal: false, vertical: true)
            SourceLine(snapshot: snapshot, mark: mark)
        }
        .padding()
    }
}
