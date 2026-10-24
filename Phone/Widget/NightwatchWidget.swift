import WidgetKit
import SwiftUI
import SkyCore
import PhoneWidgetUI

// Nightwatch's home-screen widget. It never fetches: it draws the snapshot the app wrote after its last refresh, so it can never
// disagree with the app. Small and medium.

struct NightEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
    let red: Bool
}

struct NightProvider: TimelineProvider {
    func placeholder(in context: Context) -> NightEntry { NightEntry(date: .now, snapshot: .sample, red: false) }
    func getSnapshot(in context: Context, completion: @escaping (NightEntry) -> Void) {
        completion(NightEntry(date: .now, snapshot: context.isPreview ? .sample : WidgetShare.load(), red: WidgetShare.red))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<NightEntry>) -> Void) {
        let now = Date()
        // The app reloads the timeline whenever it has a new forecast; this is only the backstop, so a stale line appears on time.
        completion(Timeline(entries: [NightEntry(date: now, snapshot: WidgetShare.load(), red: WidgetShare.red)], policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct NightwatchWidgetEntryView: View {
    let entry: NightEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        NightwatchWidgetView(snapshot: entry.snapshot, size: family == .systemLarge ? .large : family == .systemMedium ? .medium : .small,
                             red: entry.red, now: entry.date)
            .widgetURL(family == .systemMedium ? WidgetLink.plan.url : nil)   // small opens the app on Tonight, medium on Plan; large's rows are their own links
            .containerBackground(for: .widget) { NightwatchWidgetView.background(red: entry.red) }   // a plain card, as on the Mac: no picture, so it looks the same on every device
    }
}

struct NightwatchWidget: Widget {
    var body: some WidgetConfiguration {
        // Renamed (18 Oct 2026): iOS had kept re-showing a cached drawing of the old "NightwatchWidget" on the iPad.
        StaticConfiguration(kind: "NightwatchTonight", provider: NightProvider()) { NightwatchWidgetEntryView(entry: $0) }
            .configurationDisplayName("Tonight")
            .description("Whether tonight is worth setting up for, and when the sky is clear.")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])   // the iPad's extra-large stayed a grey placeholder at every layout tried, so it is not offered
    }
}

@main
struct NightwatchWidgetBundle: WidgetBundle {
    var body: some Widget { NightwatchWidget() }
}
