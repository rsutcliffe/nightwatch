import SwiftUI
import SkyCore

/// Two sizes of home-screen widget, drawn from a snapshot. Static: no animation, nothing fetched.
public struct NightwatchWidgetView: View {
    public enum Size { case small, medium }
    let snapshot: WidgetSnapshot?
    let size: Size
    let red: Bool
    let now: Date

    public init(snapshot: WidgetSnapshot?, size: Size, red: Bool, now: Date = .now) {
        self.snapshot = snapshot; self.size = size; self.red = red; self.now = now
    }

    private var text: Color { red ? Color(red: 1, green: 0.16, blue: 0.1) : .white }
    private var dim: Color { red ? Color(red: 0.7, green: 0.1, blue: 0.06) : Color(white: 0.62) }
    private var accent: Color { red ? Color(red: 1, green: 0.16, blue: 0.1) : Color(red: 0.04, green: 0.52, blue: 1) }
    public static func background(red: Bool) -> Color { red ? .black : Color(red: 0.078, green: 0.09, blue: 0.114) }

    /// Plain hyphens only, never an en or em dash, whatever wording SkyCore supplies.
    private func plain(_ t: String) -> String { t.replacingOccurrences(of: "\u{2013}", with: "-").replacingOccurrences(of: "\u{2014}", with: "-") }

    public var body: some View {
        if let s = snapshot {
            switch size {
            case .small: small(s)
            case .medium: medium(s)
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
    private func bezel(_ s: WidgetSnapshot, _ d: CGFloat) -> some View {
        ZStack {
            Canvas { ctx, size in
                let c = CGPoint(x: size.width / 2, y: size.height / 2), r = min(size.width, size.height) / 2
                for i in 0..<min(60, s.slots.count) {
                    let hour = i % 5 == 0, len: CGFloat = hour ? r * 0.17 : r * 0.1
                    let a = Double(i) * .pi / 30 - .pi / 2
                    var p = Path()
                    p.move(to: CGPoint(x: c.x + (r - len) * cos(a), y: c.y + (r - len) * sin(a)))
                    p.addLine(to: CGPoint(x: c.x + r * cos(a), y: c.y + r * sin(a)))
                    ctx.stroke(p, with: .color(tickColour(s.slots[i])), style: StrokeStyle(lineWidth: hour ? 2 : 1.3, lineCap: .round))
                }
            }
            Text("\(s.score)").font(.system(size: d * 0.3, weight: .light)).monospacedDigit().foregroundStyle(text)
        }
        .frame(width: d, height: d)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(s.bezelLabel)
    }

    private func stale(_ s: WidgetSnapshot) -> String? { s.staleText(now: now) }

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
            Text(plain(s.headline)).font(.footnote.weight(.semibold)).foregroundStyle(text).lineLimit(2).minimumScaleFactor(0.8)
            if let w = s.windowShort ?? s.window { Text(plain(w)).font(.caption.weight(.medium)).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.7) }
            if s.auroraLine(now: now) != nil { auroraLine(s) }
            else { Text(plain(stale(s) ?? s.notifyShort ?? s.siteName)).font(.caption2).foregroundStyle(dim).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func medium(_ s: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                bezel(s, 82)
                Text(plain(s.siteName)).font(.caption2).foregroundStyle(dim).lineLimit(1)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(plain(s.headline)).font(.subheadline.weight(.semibold)).foregroundStyle(text).lineLimit(2).minimumScaleFactor(0.8)
                if let w = s.window { Text(plain(w)).font(.footnote.weight(.medium)).monospacedDigit().foregroundStyle(accent).lineLimit(1).minimumScaleFactor(0.6) }
                if !s.bars.isEmpty { bars(s.bars).padding(.vertical, 2) }
                auroraLine(s)
                if !s.targets.isEmpty {
                    Text(plain(s.targets.prefix(2).map { "\($0.catalogueID) \($0.best)" }.joined(separator: " · "))).font(.caption).foregroundStyle(text).lineLimit(1).minimumScaleFactor(0.7)
                }
                Text(plain(stale(s) ?? s.updated ?? "")).font(.caption2).foregroundStyle(dim).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func bars(_ bars: [ClearSkyBar]) -> some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(Array(bars.enumerated()), id: \.offset) { _, b in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 1.5).fill(dim.opacity(0.25))
                    RoundedRectangle(cornerRadius: 1.5).fill(b.lit ? accent : dim).frame(height: max(2, 28 * CGFloat(b.clearPct) / 100))
                }
                .frame(height: 28)
            }
        }
        .accessibilityHidden(true)
    }
}

private extension Color {
    init(hex: UInt32) { self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255) }
}
