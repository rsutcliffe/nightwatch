import SwiftUI
import SkyCore

/// Two sizes of home-screen widget, drawn from a snapshot. Static: no animation, nothing fetched.
public struct NightwatchWidgetView: View {
    public enum Size { case small, medium, large }
    let snapshot: WidgetSnapshot?
    let size: Size
    let red: Bool
    let now: Date

    public init(snapshot: WidgetSnapshot?, size: Size, red: Bool, now: Date = .now) {
        self.snapshot = snapshot; self.size = size; self.red = red; self.now = now
    }

    private var text: Color { red ? Color(red: 1, green: 0.16, blue: 0.1) : .white }
    private var dim: Color { red ? Color(red: 0.7, green: 0.1, blue: 0.06) : Color(white: 0.62) }
    /// What is lit: warm white, as in the app (red in red mode).
    private var accent: Color { red ? Color(red: 1, green: 0.16, blue: 0.1) : Color(red: 0.957, green: 0.945, blue: 0.918) }
    /// The widget's plain card: the Mac widget's colour (0x1C1F27), so a widget looks the same on every device. Black in red mode.
    public static func background(red: Bool) -> Color { red ? .black : Color(red: 28 / 255, green: 31 / 255, blue: 39 / 255) }

    /// Plain hyphens only, never an en or em dash, whatever wording SkyCore supplies.
    private func plain(_ t: String) -> String { t.replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: "-") }

    public var body: some View {
        if let s = snapshot {
            switch size {
            case .small: small(s)
            case .medium: medium(s)
            case .large: large(s)
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "moon.stars").font(.title2).foregroundStyle(accent)
                Text("Open Nightwatch to read tonight's forecast").font(.caption).multilineTextAlignment(.center).foregroundStyle(dim)
            }
        }
    }

    private func tickColour(_ slot: BezelSlot) -> Color {
        switch slot {
        case .clear: accent
        case .partCloud: red ? Color(red: 0.55, green: 0.08, blue: 0.05) : Color(red: 0.55, green: 0.6, blue: 0.7)
        case .cloudy: red ? Color(red: 0.3, green: 0.04, blue: 0.03) : Color(white: 0.3)
        case .daylight: red ? Color(red: 0.16, green: 0.02, blue: 0.02) : Color(white: 0.17)
        }
    }

    /// The 12-hour bezel the app and the Mac draw: 60 ticks, hours longer, the clear ones lit.
    private func bezel(_ s: WidgetSnapshot, _ d: CGFloat, glow: Bool = true) -> some View {
        ZStack {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) / 2
                for i in 0..<min(60, s.slots.count) {
                    let hour = i % 5 == 0, len: CGFloat = hour ? r * 0.17 : r * 0.1
                    let a = Double(i) * .pi / 30 - .pi / 2
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + (r - len) * cos(a), y: c.y + (r - len) * sin(a)))
                    p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
                    if glow, s.slots[i] == .clear {
                        ctx.drawLayer { layer in layer.addFilter(.blur(radius: 2.5)); layer.stroke(p, with: .color(accent.opacity(0.7)), style: StrokeStyle(lineWidth: hour ? 3.2 : 2.4, lineCap: .round)) }
                    }
                    ctx.stroke(p, with: .color(tickColour(s.slots[i])), style: StrokeStyle(lineWidth: hour ? 2 : 1.3, lineCap: .round))
                }
            }
            Text("\(s.score)").font(.system(size: d * 0.3, weight: .bold)).monospacedDigit().foregroundStyle(text)
        }
        .frame(width: d, height: d)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(s.bezelLabel)
    }

    private func stale(_ s: WidgetSnapshot) -> String? { s.staleText(now: now) }

    /// Where the forecast came from, as on the Mac's widget: Apple's mark (the link to its legal page, except on the small widget, which is one
    /// tap target), drawn as supplied in either palette; the service's name when Apple Weather did not supply the forecast.
    private func attribution(_ s: WidgetSnapshot, link: Bool) -> some View {
        WeatherMarkView(snapshot: s, link: link).font(.caption2).foregroundStyle(dim).lineLimit(1)
    }

    /// "Aurora amber" in the level's own colour (one hue in red mode), while the status is under an hour old.
    @ViewBuilder private func auroraLine(_ s: WidgetSnapshot) -> some View {
        if let l = s.auroraLine(now: now) {
            HStack(spacing: 5) {
                Circle().fill(red ? accent : Color(hex: l.hex)).frame(width: 7, height: 7)
                Text(l.text).font(.caption.weight(.medium)).foregroundStyle(text).lineLimit(1)
            }
        }
    }

    private func small(_ s: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                bezel(s, 62)
                Spacer(minLength: 0)
            }
            TwoWeight.headline(plain(s.headline), size: 15).foregroundStyle(text).lineLimit(2).minimumScaleFactor(0.7)
            if let w = s.windowShort ?? s.window { Text(plain(w)).font(.caption.weight(.light)).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7) }
            if s.auroraLine(now: now) != nil { auroraLine(s) }
            else { Text(plain(stale(s) ?? s.notifyShort ?? s.siteName)).font(.caption2).foregroundStyle(dim).lineLimit(1) }
            attribution(s, link: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                bezel(s, 82)
                Text(plain(s.siteName)).font(.caption2).foregroundStyle(dim).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                TwoWeight.headline(plain(s.headline), size: 17).foregroundStyle(text).lineLimit(2).minimumScaleFactor(0.7)
                if let w = s.window { Text(plain(w)).font(.system(size: 15, weight: .thin)).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6) }
                if !s.bars.isEmpty { NightArcCanvas(bars: s.bars, lit: accent, faint: text, labels: false, height: 34, lineWidth: 3) }
                auroraLine(s)
                if !s.targets.isEmpty {
                    Text(plain(s.targets.prefix(2).map { "\($0.catalogueID) \($0.best)" }.joined(separator: " · "))).font(.caption).foregroundStyle(text).lineLimit(1).minimumScaleFactor(0.7)
                }
                HStack(spacing: 0) {
                    Text(plain(stale(s) ?? s.updated ?? "")).font(.caption2).foregroundStyle(dim).lineLimit(1)
                    Spacer(minLength: 8)
                    attribution(s, link: true)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    /// The large widget. The full layout when the widget is tall enough (an iPhone's); otherwise a shorter one, so nothing is ever clipped: an
    /// iPad's large widget is much shorter. The shorter layout drops the reason, the aurora line and tomorrow, and shrinks the dial and arc.
    private func large(_ s: WidgetSnapshot) -> some View {
        ViewThatFits(in: .vertical) {
            largeLayout(s, full: true)
            largeLayout(s, full: false)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func largeLayout(_ s: WidgetSnapshot, full: Bool) -> some View {
        VStack(alignment: .leading, spacing: full ? 12 : 6) {
            HStack(alignment: .top, spacing: 14) {
                bezel(s, full ? 82 : 60)
                VStack(alignment: .leading, spacing: full ? 4 : 2) {
                    Text(s.siteName.uppercased()).font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(dim).lineLimit(1)
                    TwoWeight.headline(plain(s.headline), size: full ? 20 : 17).foregroundStyle(text).lineLimit(1).minimumScaleFactor(0.7)
                    if let w = s.window { Text(plain(w)).font(.system(size: full ? 17 : 15, weight: .thin)).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6) }
                    if full, let r = s.reason { Text(plain(r)).font(.caption).foregroundStyle(dim).lineLimit(2) }
                }
            }
            if !s.bars.isEmpty { NightArcCanvas(bars: s.bars, lit: accent, faint: text, height: full ? 78 : 56, lineWidth: 3.5) }
            if !s.targets.isEmpty {
                VStack(alignment: .leading, spacing: full ? 4 : 2) {
                    Text(s.mode == .bright ? "MOON AND PLANETS" : "BEST TONIGHT").font(.caption2.weight(.semibold)).tracking(1.4).foregroundStyle(dim)
                    ForEach(s.targets, id: \.id) { t in
                        Link(destination: WidgetLink.target(t.id).url) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(plain(t.catalogueID)).font(.callout.weight(.heavy)).foregroundStyle(text).lineLimit(1).fixedSize().layoutPriority(2)
                                Text(plain(t.name).uppercased()).font(.caption2).tracking(1.0).foregroundStyle(dim).lineLimit(1)
                                Spacer(minLength: 4)
                                Text(plain(t.best)).font(.caption).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7).layoutPriority(1)
                            }
                            .frame(minHeight: full ? 28 : 22)
                        }
                    }
                }
            }
            if full {
                Spacer(minLength: 0)
                auroraLine(s)
                if let t = s.tomorrow { Text(plain(t)).font(.caption).foregroundStyle(dim).lineLimit(1) }
            }
            // Updated on the left, Apple's mark on the right, on one centre line, as the Mac's large widget has it.
            HStack(alignment: .center, spacing: 0) {
                Text(plain(stale(s) ?? s.updated ?? "")).font(.caption2).foregroundStyle(dim).lineLimit(1)
                Spacer(minLength: 8)
                attribution(s, link: true)
            }
        }
    }
}

/// Apple's Weather mark where Apple Weather supplied the forecast, else the source's name. The image is the file the app kept in the
/// App Group (a widget cannot fetch it). Never tinted: the mark is drawn as Apple supplies it, in red night mode too.
public struct WeatherMarkView: View {
    let snapshot: WidgetSnapshot
    let link: Bool
    let height: CGFloat

    public init(snapshot: WidgetSnapshot, link: Bool = true, height: CGFloat = 9) {
        self.snapshot = snapshot; self.link = link; self.height = height
    }

    private static func image(_ data: Data) -> Image? {
        #if canImport(UIKit)
        UIImage(data: data).map(Image.init(uiImage:))
        #else
        NSImage(data: data).map(Image.init(nsImage:))
        #endif
    }

    public var body: some View {
        if snapshot.weatherMarkFile != nil, let data = WidgetShare.loadMark(), let image = Self.image(data) {
            let mark = image.resizable().scaledToFit().frame(height: height)
            if link, let legal = snapshot.weatherLegalURL.flatMap(URL.init(string:)) {
                Link(destination: legal) { mark }.accessibilityLabel("Apple Weather, legal attribution and data sources")
            } else {
                mark.accessibilityLabel("Apple Weather")
            }
        } else if let source = snapshot.source {
            Text(source)
        }
    }
}

private extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }
}
