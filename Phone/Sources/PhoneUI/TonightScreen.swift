import SwiftUI
import SkyCore
import PhoneCore

/// Tonight's answer for the active site. Three layouts from one set of sections: one column (iPhone, Slide Over), a wide
/// portrait page (iPad upright) and three columns (iPad landscape).
public struct TonightScreen: View {
    let model: TonightModel
    let markData: Data?
    let offline: Bool
    let refreshing: Bool
    let onRefresh: () -> Void
    var alertsPrompt: AlertsPrompt? = nil
    var now: Date = .now
    var visit: AnyView? = nil
    @Environment(\.phoneTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: TonightModel, markData: Data?, offline: Bool, refreshing: Bool, onRefresh: @escaping () -> Void,
                alertsPrompt: AlertsPrompt? = nil, now: Date = .now, visit: AnyView? = nil) {
        self.alertsPrompt = alertsPrompt; self.now = now; self.visit = visit
        self.model = model; self.markData = markData; self.offline = offline; self.refreshing = refreshing; self.onRefresh = onRefresh
    }

    private var snap: WidgetSnapshot { model.snapshot }
    private var clearNight: Bool { snap.window != nil }
    private var figureArt: (Data, Data)? {
        guard let id = model.figureID, let f = bundledArt("\(id)-figure", folder: "Constellations"), let p = bundledArt("\(id)-plot", folder: "Constellations") else { return nil }
        return (f, p)
    }

    // MARK: Sections

    /// "TONIGHT · MALHAM TARN" over the date and Bortle class, as the Mac's popover has it.
    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(model.overline).font(.caption.weight(.medium)).tracking(0.8).secondary().lineLimit(2)
            Text(model.dateLine).font(.caption).secondary()
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)   // a caption never needs to be as big as the verdict
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private enum Scale { case compact, medium, large }

    private func verdict(_ scale: Scale) -> some View {
        let bezel: CGFloat = scale == .compact ? 104 : scale == .medium ? 124 : 144
        let spacing: CGFloat = scale == .compact ? 18 : 22
        // At the accessibility text sizes the words need the full width, so the bezel sits above them.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: spacing))
        return layout {
            ScoreBezelView(score: snap.score, slots: snap.slots, label: snap.bezelLabel, size: typeSize.isAccessibilitySize ? 96 : bezel)
            VStack(alignment: .leading, spacing: 5) {
                Text(snap.headline).font(scale == .large ? .title.weight(.medium) : .title2.weight(.medium)).dynamicTypeSize(...DynamicTypeSize.accessibility2).fixedSize(horizontal: false, vertical: true)
                if let w = snap.window { Text(w).font(.callout.weight(.medium)).monospacedDigit().foregroundStyle(theme.accent).lineLimit(1).minimumScaleFactor(0.5) }
                if let r = snap.reason { Text(r).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
                if let a = snap.agreement {
                    Text((snap.agreementWarns ? "! " : "✓ ") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                        .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary)
                }
            }
        }
        .heroSurface(clear: clearNight, padding: scale == .compact ? 16 : 20, figure: clearNight ? nil : figureArt)
    }

    /// Aurora, when alerts are on and it is at or above your level and under an hour old, naming its source and linking to it (AuroraWatch UK's
    /// terms ask for that). The level keeps the source's own colour, except in red mode, which has one hue.
    @ViewBuilder private var auroraRow: some View {
        if let line = snap.auroraLine(now: now), let a = snap.aurora {
            Link(destination: a.source.link) {
                HStack(spacing: 8) {
                    Circle().fill(theme.isRed ? theme.accent : Color(hex: line.hex)).frame(width: 10, height: 10).accessibilityHidden(true)
                    Text("\(line.text) · \(a.source.name)").font(.callout.weight(.medium)).foregroundStyle(theme.textPrimary)
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right").font(.footnote).secondary()
                }
                .padding(.horizontal, 12).frame(minHeight: 44)
                .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.hairline, lineWidth: 1))
            }
            .buttonStyle(PressStyle())
            .accessibilityLabel("\(line.text), from \(a.source.name). Opens their page.")
        }
    }

    private func bars(height: CGFloat) -> some View {
        Card { ClearSkyBarsView(bars: snap.bars, caption: snap.barsLabel, trackHeight: height) }
    }

    private func targets(height: CGFloat = 78) -> some View { PicksSection(model: model, pictureHeight: height) }

    private var offlineNote: some View {
        Card { Text("No connection. Showing the forecast from \(ForecastAge(fetchedAt: model.fetchedAt, now: now).text).").font(.callout) }
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.warning, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    @ViewBuilder private var tomorrowCard: some View {
        if let t = snap.tomorrow {
            Card {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TOMORROW NIGHT").font(.caption.weight(.medium)).tracking(0.8).secondary()
                    Text(t.hasPrefix("Tomorrow ") ? String(t.dropFirst(9)) : t).font(.callout).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let alertsPrompt { alertsPrompt }
            SourceFooter(model: model, markData: markData, refreshing: refreshing, onRefresh: onRefresh)
        }
    }

    // MARK: Layouts

    public var body: some View {
        GeometryReader { geo in
            ScrollView {
                Group {
                    if geo.size.width >= 1100 { landscape } else if geo.size.width >= 640 { wide(width: geo.size.width) } else { compact }
                }
                .padding(geo.size.width >= 640 ? 28 : 16)
                .frame(maxWidth: 1400)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .background { StarField(seed: model.overline + model.dateLine).ignoresSafeArea() }
        .refreshable { onRefresh() }
    }

    private var compact: some View {
        VStack(alignment: .leading, spacing: 14) {
            if offline { offlineNote }
            header
            visit
            verdict(.compact)
            bars(height: 37)
            auroraRow
            TilesView(tiles: model.tiles)
            targets()
            tomorrowCard
            footer
        }
    }

    /// An iPad page: the verdict and the hours side by side, the six tiles in one row, big pictures for the targets.
    private func wide(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if offline { offlineNote }
            header
            visit
            HStack(alignment: .top, spacing: 20) {
                verdict(.medium).frame(maxWidth: .infinity)
                bars(height: 70).frame(maxWidth: .infinity)
            }
            auroraRow
            TilesView(tiles: model.tiles, columns: width >= 760 ? 6 : 3)
            targets(height: width >= 760 ? 230 : 170)
            tomorrowCard
            footer
        }
    }

    private var landscape: some View {
        VStack(alignment: .leading, spacing: 20) {
            if offline { offlineNote }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) { header; visit; verdict(.large); bars(height: 90); auroraRow; tomorrowCard }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) { TilesView(tiles: model.tiles, columns: 2); targets(height: 190) }.frame(maxWidth: .infinity)
            }
            footer
        }
    }
}
