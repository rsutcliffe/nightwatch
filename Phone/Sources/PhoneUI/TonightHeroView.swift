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
    @ScaledMetric(relativeTo: .largeTitle) private var large: CGFloat = 120
    @ScaledMetric(relativeTo: .largeTitle) private var medium: CGFloat = 104
    @ScaledMetric(relativeTo: .largeTitle) private var compact: CGFloat = 80
    @State private var arrived = false

    private var numeralSize: CGFloat { scale == .large ? large : scale == .medium ? medium : compact }
    private var timesSize: CGFloat { scale == .large ? 38 : scale == .medium ? 34 : 28 }

    private var numeral: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(arrived ? snap.score : 0)").font(.system(size: numeralSize, weight: .light)).monospacedDigit()
                .contentTransition(.numericText(value: Double(arrived ? snap.score : 0)))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.9), value: arrived)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text("SKY SCORE").font(.caption.weight(.medium)).tracking(3).secondary()
                .dynamicTypeSize(...DynamicTypeSize.accessibility1).padding(.leading, 4)
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
                Text(line).font(.callout.weight(.medium)).foregroundStyle(theme.gold).fixedSize(horizontal: false, vertical: true)
            }
            if let r = snap.reason { Text(r).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
            if let a = snap.agreement {
                Text((snap.agreementWarns ? "! " : "✓ ") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                    .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// "9.4 hours · medium dew risk", whichever of the two there is.
    private var goldLine: String? {
        let parts = [hero.hours, hero.dewLine].compactMap { $0 }
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

/// One thin line for the night's hours: lit where the sky is clear (brighter the clearer it is), a hairline where it is not, with
/// the first hour, the Moon note and the last hour beneath. It replaces the ten bars on Tonight; the Week page keeps its bars.
struct ClearHoursLine: View {
    let bars: [ClearSkyBar]
    let caption: String
    let end: String?
    let moonNote: String
    @Environment(\.phoneTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var arrived = false

    var body: some View {
        if bars.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 8) {
                ZStack {
                    Rectangle().fill(theme.textPrimary.opacity(0.35)).frame(height: 1)
                    HStack(spacing: 1) {
                        ForEach(Array(bars.enumerated()), id: \.offset) { _, b in
                            Rectangle().fill(b.lit ? theme.textPrimary.opacity(0.55 + 0.35 * Double(b.clearPct) / 100)
                                                   : theme.textPrimary.opacity(b.clearPct > 0 ? 0.22 : 0))
                        }
                    }
                    .frame(height: 6).clipShape(Capsule())
                }
                .scaleEffect(x: arrived || reduceMotion ? 1 : 0.02, anchor: .leading)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.8), value: arrived)
                HStack {
                    Text((bars.first?.hour ?? "") + ":00")
                    Spacer(minLength: 8)
                    Text(moonNote).multilineTextAlignment(.center)
                    Spacer(minLength: 8)
                    Text(end ?? "")
                }
                .font(.caption).monospacedDigit().secondary().dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            }
            .onAppear { arrived = true }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(ClearSkyBarsView.speech(caption: caption, bars: bars) + ". " + moonNote)
        }
    }
}
