import SwiftUI
import SkyCore
import PhoneCore

/// A constellation's figure and star plot (the owner's art), drawn faint behind the hero on a night with no clear window.
struct FigureArt: View {
    let figure: (Data, Data)
    @Environment(\.phoneTheme) private var theme
    var body: some View {
        if let f = Image(platformData: figure.0), let p = Image(platformData: figure.1) {
            ZStack { f.resizable().scaledToFit(); p.resizable().scaledToFit() }
                .saturation(theme.isRed ? 0 : 1).colorMultiply(theme.isRed ? Color(hex: 0xC0180E) : .white)
                .opacity(0.13).padding(10).accessibilityHidden(true)
        }
    }
}

/// The Tonight verdict on the photograph, with no card: the Mac's dial with the score inside, and beside it
/// the headline, the clear window in large light type, then hours clear and the dew line in warm white.
struct TonightHeroView: View {
    enum Scale { case compact, medium, large }
    let snap: WidgetSnapshot
    let hero: TonightHero
    let scale: Scale
    var figure: (Data, Data)? = nil
    @Environment(\.phoneTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    private var dialSize: CGFloat { typeSize.isAccessibilitySize ? 140 : scale == .large ? 200 : scale == .medium ? 170 : 120 }
    private var timesSize: CGFloat { scale == .large ? 38 : scale == .medium ? 34 : 28 }

    /// The Mac's 60-tick, 12-hour dial with the score inside: ticks inside a clear window are lit.
    private var dial: some View {
        ScoreBezelView(score: snap.score, slots: snap.slots, label: snap.bezelLabel, size: dialSize, lit: theme.lit, numeralWeight: .bold)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snap.headline).font(.title2.weight(.bold)).dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .fixedSize(horizontal: false, vertical: true)
            if let t = hero.times {
                Text(t).font(.system(size: timesSize, weight: .semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }
            if let line = hoursLine {
                Text(line).font(.callout.weight(hero.dewWarns ? .semibold : .regular)).foregroundStyle(hero.dewWarns ? theme.warning : theme.lit).fixedSize(horizontal: false, vertical: true)
            }
            if let r = hero.reason { Text(r).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
            if let a = snap.agreement {
                Text((snap.agreementWarns ? "! " : "✓ ") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                    .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "9.4 hours · medium dew risk", whichever of the two there is.
    private var hoursLine: String? {
        let parts = [hero.hours, hero.dewLine.map { (hero.dewWarns ? "! " : "") + $0 }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        // At the accessibility text sizes the numeral sits above the words so neither is squeezed.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: scale == .compact ? 22 : 36))
        layout {
            dial
            words.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) { if let figure { FigureArt(figure: figure).frame(maxHeight: 220) } }
    }
}

/// The night as a low arc over the horizon: each hour a stretch of the curve, lit white where the sky is clear (brighter the
/// clearer it is), a faint line where it is not, and the Moon note beneath. It replaces the ten bars on Tonight; the Week page keeps its bars.
struct ClearHoursLine: View {
    let bars: [ClearSkyBar]
    let caption: String
    let moonNote: String
    /// How far through the night it is now (0 to 1), or nil when it is outside the night: the ember dot sits there.
    var nowFraction: Double? = nil
    @Environment(\.phoneTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    private func arc(_ size: CGSize) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 3, y: size.height - 16))
        p.addQuadCurve(to: CGPoint(x: size.width - 3, y: size.height - 16), control: CGPoint(x: size.width / 2, y: -size.height * 0.5))
        return p
    }

    var body: some View {
        if bars.isEmpty { EmptyView() } else {
            VStack(spacing: 6) {
                Canvas { ctx, size in
                    let path = arc(size), n = Double(bars.count), gap = 0.004
                    ctx.stroke(path, with: .color(theme.textPrimary.opacity(0.18)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                    func seg(_ i: Int) -> Path { path.trimmedPath(from: Double(i) / n + gap, to: Double(i + 1) / n - gap) }
                    for (i, b) in bars.enumerated() {
                        if b.lit { ctx.stroke(seg(i), with: .color(theme.lit.opacity(0.55 + 0.45 * Double(b.clearPct) / 100)), style: StrokeStyle(lineWidth: 4, lineCap: .butt)) }
                        else if b.clearPct > 0 { ctx.stroke(seg(i), with: .color(theme.textPrimary.opacity(0.28)), style: StrokeStyle(lineWidth: 3, lineCap: .butt)) }
                    }
                    if let f = nowFraction, let pt = path.trimmedPath(from: 0, to: min(max(f, 0.001), 1)).currentPoint {
                        let dot = CGRect(x: pt.x - 6, y: pt.y - 6, width: 12, height: 12)
                        ctx.fill(Path(ellipseIn: dot), with: .color(theme.ember))
                        ctx.stroke(Path(ellipseIn: dot), with: .color(theme.textPrimary), lineWidth: 1.5)
                    }
                }
                // Room above and below the curve, so the glow is never cut off at the edge of the drawing.
                .frame(height: 74)
                .mask { GeometryReader { g in Rectangle().frame(width: arrived || reduceMotion ? g.size.width : 0)
                    .animation(reduceMotion ? nil : .easeOut(duration: 1.1), value: arrived) } }
                Text(moonNote).font(.caption).monospacedDigit().secondary().dynamicTypeSize(...DynamicTypeSize.xxxLarge).multilineTextAlignment(.center)
            }
            .onAppear { arrived = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ClearSkyBarsView.speech(caption: caption, bars: bars) + ". " + moonNote)
        }
    }
}

/// Seeing, wind, transparency (and the dark hours when they differ from the window): a small capital label over a bold value, left-aligned
/// with room between, where the grey footer line was.
struct FactsRow: View {
    let facts: [TonightHero.Fact]
    var body: some View {
        if facts.isEmpty { EmptyView() } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 12, alignment: .leading)], alignment: .leading, spacing: 14) {
                ForEach(facts, id: \.label) { f in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(f.label.uppercased()).font(.caption2.weight(.semibold)).tracking(0.8).secondary().lineLimit(1).minimumScaleFactor(0.8)
                        Text(f.value).font(.headline.weight(.bold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(facts.map { "\($0.label) \($0.value)" }.joined(separator: ", "))
        }
    }
}
