import SwiftUI
import SkyCore
import PhoneCore

/// The sky score inside a 60-tick, 12-hour bezel: the Mac app's dial, redrawn. Outer radius 45.5, hour ticks 8 by 1.7, minute
/// ticks 4.5 by 1.1; ticks inside a clear window are lit with one glow.
struct ScoreBezelView: View {
    let score: Int
    let slots: [BezelSlot]
    let label: String
    var size: CGFloat = 104
    @Environment(\.phoneTheme) private var theme

    private func colour(_ s: BezelSlot) -> Color {
        switch s { case .clear: theme.accent; case .partCloud: theme.tickPartCloud; case .cloudy: theme.tickCloudy; case .daylight: theme.tickDaylight }
    }

    private func ticks(_ include: @escaping (BezelSlot) -> Bool) -> some View {
        ZStack {
            ForEach(0..<60, id: \.self) { i in
                if i < slots.count, include(slots[i]) {
                    let hour = i % 5 == 0
                    Capsule().fill(colour(slots[i]))
                        .frame(width: hour ? 1.7 : 1.1, height: hour ? 8 : 4.5)
                        .offset(y: -45.5 + (hour ? 4 : 2.25))
                        .frame(width: 91, height: 91)
                        .rotationEffect(.degrees(Double(i) * 6))
                }
            }
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(theme.ring, lineWidth: 0.75).frame(width: 66, height: 66)
            ticks { $0 != .clear }
            ticks { $0 == .clear }.compositingGroup().shadow(color: theme.accent.opacity(0.7), radius: 3)
            Text("\(score)").font(.system(size: 27, weight: .light)).foregroundStyle(theme.textPrimary)
                .overlay(alignment: .top) {
                    Text("SKY SCORE").font(.system(size: 9, weight: .medium)).secondary().fixedSize().offset(y: 28)
                }
        }
        .frame(width: 91, height: 91)
        .scaleEffect(size / 91).frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

/// One column per hour of darkness, filled to the clear-sky share; hours inside a clear window are lit with a glow.
struct ClearSkyBarsView: View {
    let bars: [ClearSkyBar]
    let caption: String
    var trackHeight: CGFloat = 44
    @Environment(\.phoneTheme) private var theme

    var body: some View {
        if bars.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .bottom, spacing: 4) {
                    ForEach(Array(bars.enumerated()), id: \.offset) { _, b in
                        VStack(spacing: 3) {
                            ZStack(alignment: .bottom) {
                                RoundedRectangle(cornerRadius: 3).fill(theme.barTrack)
                                RoundedRectangle(cornerRadius: 3).fill(b.lit ? theme.accent : theme.barCloudy)
                                    .frame(height: max(2, trackHeight * CGFloat(b.clearPct) / 100))
                                    .shadow(color: b.lit ? theme.accent.opacity(0.7) : .clear, radius: 3)
                            }
                            .frame(height: trackHeight)
                            Text(b.hour).font(.system(size: 10)).secondary().fixedSize()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                Text(caption).font(.caption).secondary()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(caption + " " + bars.map { "\($0.hour) hundred hours \($0.clearPct) percent clear" }.joined(separator: ", "))
        }
    }
}

struct TileView: View {
    let label: String
    let value: String?
    var hint: String? = nil
    /// A warning is drawn in the warning colour, and with a dashed outline and a "!" so it never relies on colour alone.
    var warns = false
    @Environment(\.phoneTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).secondary()
            Text((warns ? "! " : "") + (value ?? "–")).font(.callout.weight(warns ? .semibold : .medium))
                .foregroundStyle(warns ? theme.warning : theme.textPrimary).lineLimit(1).minimumScaleFactor(0.8)
            if let hint { Text(hint).font(.caption2).secondary().lineLimit(2) }
        }
        .padding(.horizontal, 10).padding(.vertical, 9)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .topLeading)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(warns ? theme.warning : theme.hairline, style: StrokeStyle(lineWidth: 1, dash: warns ? [4, 3] : [])))
        .accessibilityElement(children: .combine)
    }
}

struct TilesView: View {
    let tiles: TonightTiles
    var body: some View {
        let cols = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
        LazyVGrid(columns: cols, spacing: 8) {
            TileView(label: "Dark", value: tiles.dark)
            TileView(label: "Moon", value: tiles.moon, hint: tiles.moonLine)
            TileView(label: "Seeing", value: tiles.seeing)
            TileView(label: "Wind", value: tiles.wind)
            TileView(label: tiles.dewLabel, value: tiles.dew, hint: tiles.dewHint, warns: tiles.dew == "High" || tiles.dewLabel == "Frost likely")
            TileView(label: "Transparency", value: tiles.transparency)
        }
    }
}

/// The source line at the foot: Apple's mark (the link to its legal page) when Apple Weather supplied the forecast, otherwise
/// the service's name; when it was updated; and Refresh. Apple's mark is drawn exactly as supplied, in either palette.
struct SourceFooter: View {
    let model: TonightModel
    let markData: Data?
    let refreshing: Bool
    let onRefresh: () -> Void
    @Environment(\.phoneTheme) private var theme
    @State private var refreshes = 0

    var body: some View {
        HStack(spacing: 12) {
            attribution
            Spacer(minLength: 8)
            Text(model.snapshot.updated ?? "").font(.caption).secondary()
            Button { refreshes += 1; onRefresh() } label: {
                Text(refreshing ? "Refreshing" : "Refresh").font(.callout.weight(.medium)).foregroundStyle(theme.accent)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(PressStyle())
            .sensoryFeedback(.impact(weight: .light), trigger: refreshes)
            .accessibilityLabel("Refresh the forecast")
        }
    }

    @ViewBuilder private var attribution: some View {
        let label = Group {
            if model.markURL != nil, let data = markData, let image = Image(platformData: data) {
                image.resizable().scaledToFit().frame(height: 14)   // exactly as supplied: never tinted
            } else {
                Text(model.source).font(.caption).secondary()
            }
        }
        if let legal = model.legalURL.flatMap(URL.init(string:)) {
            Link(destination: legal) { label.frame(minHeight: 44) }
                .accessibilityLabel("Apple Weather, legal attribution and data sources")
        } else {
            label
        }
    }
}
