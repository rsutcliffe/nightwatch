import WidgetKit
import SwiftUI
import SkyCore
import NightwatchUI

// Nightwatch's desktop widget (v0.6). It never fetches: it draws the snapshot the app writes after each patrol, so it can
// never disagree with the popover. Layouts follow the owner-approved canvas (small, medium, large).

struct NightEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

enum SnapshotFile {
    static func load() -> WidgetSnapshot? {
        guard let group = Bundle.main.object(forInfoDictionaryKey: "NightwatchAppGroup") as? String,
              let dir = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group),
              let data = try? Data(contentsOf: dir.appendingPathComponent("widget.json")) else { return nil }
        let d = JSONDecoder(); d.dateDecodingStrategy = .iso8601
        return try? d.decode(WidgetSnapshot.self, from: data)
    }
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> NightEntry { NightEntry(date: .now, snapshot: .sample) }
    /// The gallery shows the sample until the app has written a snapshot.
    func getSnapshot(in context: Context, completion: @escaping (NightEntry) -> Void) {
        completion(NightEntry(date: .now, snapshot: SnapshotFile.load() ?? (context.isPreview ? .sample : nil)))
    }
    /// The app reloads the widget after every patrol; the 30-minute refresh is only a fallback. A second entry just past the
    /// six-hour mark shows "Forecast N h old" on time rather than at the next refresh.
    func getTimeline(in context: Context, completion: @escaping (Timeline<NightEntry>) -> Void) {
        let s = SnapshotFile.load()
        var entries = [NightEntry(date: .now, snapshot: s)]
        if let s, case let staleAt = s.fetchedAt.addingTimeInterval(6 * 3600 + 60), staleAt > .now {
            entries.append(NightEntry(date: staleAt, snapshot: s))
        }
        completion(Timeline(entries: entries, policy: .after(.now.addingTimeInterval(1800))))
    }
}

/// A grey line with a tick, or an amber one with a dot: the reason and agreement lines, as in the popover.
struct NoteLine: View {
    let text: String
    let warns: Bool
    var tick = false
    var lines = 2
    var body: some View {
        HStack(spacing: 5) {
            if warns { WarningDot(size: 4.5) }
            else if tick { Image(systemName: "checkmark").font(.system(size: 7, weight: .bold)).accessibilityHidden(true) }
            Text(text).lineLimit(lines)
        }
        .font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
    }
}

/// `compact` (the medium size): the headline on one line, shrinking to fit, and no Tomorrow line when a reason is shown,
/// so the reason and the Open-Meteo line are never cut off (owner's desktop, 25 September 2026). With a window line as
/// well, each note keeps to one line. `showStale` false: the large widget shows staleness in its footer instead.
struct Headline: View {
    let s: WidgetSnapshot
    let now: Date
    var compact = false
    var showStale = true
    private var noteLines: Int { compact && s.window != nil ? 1 : 2 }
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("TONIGHT · \(s.siteName.uppercased())").font(.system(size: 10)).foregroundStyle(Tokens.textSecondary).lineLimit(1)
            Text(s.headline).font(.system(size: 15, weight: .medium)).foregroundStyle(Tokens.textPrimary)
                .lineLimit(compact ? 1 : 2).minimumScaleFactor(compact ? 0.7 : 0.8)
            if let w = s.window { Text(w).font(.system(size: 13)).foregroundStyle(Tokens.textPrimary) }
            if let r = s.reason { NoteLine(text: r, warns: s.reasonWarns, lines: noteLines).fixedSize(horizontal: false, vertical: true) }
            if let a = s.agreement { NoteLine(text: a, warns: s.agreementWarns, tick: true, lines: noteLines).fixedSize(horizontal: false, vertical: true) }
            if let t = s.tomorrow, !(compact && s.reason != nil) { NoteLine(text: t, warns: false) }
            if showStale, let stale = s.staleText(now: now) { NoteLine(text: stale, warns: true) }
        }
    }
}

struct SmallView: View {
    let s: WidgetSnapshot
    let now: Date
    var body: some View {
        VStack(spacing: 6) {
            ScoreBezel(score: s.score, slots: s.slots, label: s.bezelLabel)
            // The small size has room for one short line: the first sentence of the headline ("Nothing to see here").
            Text(s.windowShort ?? (s.headline.components(separatedBy: ". ").first ?? s.headline).trimmingCharacters(in: CharacterSet(charactersIn: ".")))
                .font(.system(size: 12.5, weight: .medium)).foregroundStyle(Tokens.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.7).multilineTextAlignment(.center)
            if let stale = s.staleText(now: now) {
                NoteLine(text: stale, warns: true)
            } else {
                Text(s.windowShort == nil ? (s.tomorrow ?? s.siteName)
                     : s.brightList ?? [s.siteName, s.notifyShort].compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 10)).foregroundStyle(Tokens.textSecondary).lineLimit(1)
            }
        }
    }
}

struct MediumView: View {
    let s: WidgetSnapshot
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 14) {
                ScoreBezel(score: s.score, slots: s.slots, label: s.bezelLabel)
                Headline(s: s, now: now, compact: true)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            ClearSkyBars(bars: s.bars, label: s.barsLabel, trackHeight: 16, labels: false)
        }
    }
}

struct LargeView: View {
    let s: WidgetSnapshot
    let now: Date
    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .top, spacing: 14) {
                ScoreBezel(score: s.score, slots: s.slots, label: s.bezelLabel)
                Headline(s: s, now: now, showStale: false)
                Spacer(minLength: 0)
            }
            ClearSkyBars(bars: s.bars, label: s.barsLabel, trackHeight: 28, labels: true, caption: false)
            Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
            Text(s.targets.isEmpty ? "UP TONIGHT" : "BEST TONIGHT").font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
            if s.targets.isEmpty {
                Text(s.windowShort == nil ? "No clear window, so nothing is recommended."
                     : s.mode == .bright ? "No Moon or planet well placed in the window." : "Nothing well placed in the window.")
                    .font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
            }
            VStack(alignment: .leading, spacing: 7) { ForEach(s.targets, id: \.id) { t in
                Link(destination: URL(string: "nightwatch://target/\(t.id.addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? t.id)")!) {
                    HStack(spacing: 10) {
                        Image(systemName: t.group.symbolName).font(.system(size: 14)).foregroundStyle(Tokens.textSecondary)
                            .frame(width: 34, height: 34).background(Color(hex: 0x0E1018), in: RoundedRectangle(cornerRadius: 7))
                        VStack(alignment: .leading, spacing: 1) {
                            (Text(t.catalogueID).fontWeight(.bold) + Text("  " + t.name).foregroundColor(Tokens.textSecondary))
                                .font(.system(size: 11)).foregroundStyle(Tokens.textPrimary).lineLimit(1)
                            Text(t.best).font(.system(size: 9.5, weight: .medium)).foregroundStyle(Tokens.bestLine)
                        }
                    }
                }
            } }
            Spacer(minLength: 0)
            HStack {
                Text(s.notify ?? "").font(.system(size: 9.5)).foregroundStyle(Tokens.textSecondary)
                Spacer()
                if let stale = s.staleText(now: now) { NoteLine(text: stale, warns: true, lines: 1) } else {
                Text((["Updated \(s.fetchedAt.formatted(date: .omitted, time: .shortened))", s.source].compactMap { $0 }).joined(separator: " · "))
                    .font(.system(size: 9.5)).foregroundStyle(Tokens.textSecondary)
                }
            }
        }
    }
}

struct NightwatchWidgetView: View {
    let entry: NightEntry
    @Environment(\.widgetFamily) private var family
    var body: some View {
        Group {
            if let s = entry.snapshot {
                switch family {
                case .systemSmall: SmallView(s: s, now: entry.date)
                case .systemLarge: LargeView(s: s, now: entry.date)
                default: MediumView(s: s, now: entry.date)
                }
            } else {
                VStack(spacing: 6) {
                    Image(systemName: "star").font(.title2).foregroundStyle(Tokens.textSecondary)
                    Text("Open Nightwatch to load tonight's sky").font(.system(size: 11)).foregroundStyle(Tokens.textSecondary)
                        .multilineTextAlignment(.center)
                }
            }
        }
        // The small widget and the empty state are centred, as on the canvas; medium and large read from the top left.
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: entry.snapshot == nil || family == .systemSmall ? .center : .topLeading)
        .containerBackground(for: .widget) { Tokens.targetsCard }
        .widgetURL(URL(string: "nightwatch://targets"))
    }
}

@main
struct NightwatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "Nightwatch", provider: Provider()) { NightwatchWidgetView(entry: $0) }
            .configurationDisplayName("Nightwatch")
            .description("Tonight's sky at a glance")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
