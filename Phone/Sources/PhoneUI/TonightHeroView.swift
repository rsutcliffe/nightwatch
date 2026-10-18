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

/// The Tonight verdict on the photograph, with no card: a very large light numeral over a wide-tracked "SKY SCORE", and beside it
/// the headline, the clear window in large light type, then hours clear and the dew line in warm pale gold.
struct TonightHeroView: View {
    enum Scale { case compact, medium, large }
    let snap: WidgetSnapshot
    let hero: TonightHero
    let scale: Scale
    var figure: (Data, Data)? = nil
    @Environment(\.phoneTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ScaledMetric(relativeTo: .largeTitle) private var large: CGFloat = 120
    @ScaledMetric(relativeTo: .largeTitle) private var medium: CGFloat = 104
    @ScaledMetric(relativeTo: .largeTitle) private var compact: CGFloat = 80
    @State private var arrived = false

    private var numeralSize: CGFloat { scale == .large ? large : scale == .medium ? medium : compact }
    private var timesSize: CGFloat { scale == .large ? 38 : scale == .medium ? 34 : 28 }

    private var numeral: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(arrived ? snap.score : 0)").font(.system(size: numeralSize, weight: .light, design: .serif)).monospacedDigit()
                .foregroundStyle(LinearGradient(colors: [theme.textPrimary, theme.gold], startPoint: .top, endPoint: .bottom))
                .shadow(color: theme.gold.opacity(reduceTransparency ? 0 : 0.4), radius: 22)
                .contentTransition(.numericText(value: Double(arrived ? snap.score : 0)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.9), value: arrived)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("SKY SCORE").font(.caption.weight(.medium)).tracking(3).secondary()
                .dynamicTypeSize(...DynamicTypeSize.accessibility1).padding(.leading, 4)
        }
        .background(alignment: .leading) {
            // A soft lamp behind the numeral: the night's one warm light.
            if !reduceTransparency {
                RadialGradient(colors: [theme.gold.opacity(0.20), .clear], center: .center, startRadius: 0, endRadius: numeralSize * 1.1)
                    .frame(width: numeralSize * 2.4, height: numeralSize * 2.4).offset(x: -numeralSize * 0.15).allowsHitTesting(false)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snap.bezelLabel)
    }

    private var words: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(snap.headline).font(.title3.weight(.regular)).secondary().dynamicTypeSize(...DynamicTypeSize.accessibility2)
                .fixedSize(horizontal: false, vertical: true)
            if let t = hero.times {
                Text(t).font(.system(size: timesSize, weight: .light)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
            }
            if let line = goldLine {
                Text(line).font(.callout.weight(hero.dewWarns ? .semibold : .medium)).foregroundStyle(theme.gold).fixedSize(horizontal: false, vertical: true)
            }
            if let r = hero.reason { Text(r).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
            if let a = snap.agreement {
                Text((snap.agreementWarns ? "! " : "✓ ") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                    .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "9.4 hours · medium dew risk", whichever of the two there is.
    private var goldLine: String? {
        let parts = [hero.hours, hero.dewLine.map { (hero.dewWarns ? "! " : "") + $0 }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    var body: some View {
        // At the accessibility text sizes the numeral sits above the words so neither is squeezed.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: scale == .compact ? 22 : 36))
        layout {
            numeral
            words.frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) { if let figure { FigureArt(figure: figure).frame(maxHeight: 220) } }
        .onAppear { arrived = true }
    }
}

/// The night as a low arc over the horizon: each hour a stretch of the curve, lit gold with a glow where the sky is clear (brighter the
/// clearer it is), a faint line where it is not, and the Moon note beneath. It replaces the ten bars on Tonight; the Week page keeps its bars.
struct ClearHoursLine: View {
    let bars: [ClearSkyBar]
    let caption: String
    let moonNote: String
    @Environment(\.phoneTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
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
                    if !reduceTransparency {
                        ctx.drawLayer { layer in
                            layer.addFilter(.blur(radius: 6))
                            for (i, b) in bars.enumerated() where b.lit { layer.stroke(seg(i), with: .color(theme.gold.opacity(0.55 * Double(b.clearPct) / 100)), style: StrokeStyle(lineWidth: 8)) }
                        }
                    }
                    for (i, b) in bars.enumerated() {
                        if b.lit { ctx.stroke(seg(i), with: .color(theme.gold.opacity(0.6 + 0.4 * Double(b.clearPct) / 100)), style: StrokeStyle(lineWidth: 5, lineCap: .butt)) }
                        else if b.clearPct > 0 { ctx.stroke(seg(i), with: .color(theme.textPrimary.opacity(0.28)), style: StrokeStyle(lineWidth: 3, lineCap: .butt)) }
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
