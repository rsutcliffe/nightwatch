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
    @Environment(\.phoneTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(model: TonightModel, markData: Data?, offline: Bool, refreshing: Bool, onRefresh: @escaping () -> Void,
                alertsPrompt: AlertsPrompt? = nil, now: Date = .now) {
        self.alertsPrompt = alertsPrompt; self.now = now
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
            Text(model.overline).font(.caption.weight(.medium)).tracking(0.8).secondary()
            Text(model.dateLine).font(.caption).secondary()
        }
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
            ScoreBezelView(score: snap.score, slots: snap.slots, label: snap.bezelLabel, size: bezel)
            VStack(alignment: .leading, spacing: 5) {
                Text(snap.headline).font(scale == .large ? .title.weight(.medium) : .title2.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                if let w = snap.window { Text(w).font(.callout.weight(.medium)).monospacedDigit().foregroundStyle(theme.accent) }
                if let r = snap.reason { Text(r).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
                if let a = snap.agreement {
                    Text((snap.agreementWarns ? "! " : "✓ ") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                        .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary)
                }
            }
        }
        .heroSurface(clear: clearNight, padding: scale == .compact ? 16 : 20, figure: clearNight ? nil : figureArt)
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
            verdict(.compact)
            bars(height: 37)
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
            HStack(alignment: .top, spacing: 20) {
                verdict(.medium).frame(maxWidth: .infinity)
                bars(height: 70).frame(maxWidth: .infinity)
            }
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
                VStack(alignment: .leading, spacing: 20) { header; verdict(.large); bars(height: 90); tomorrowCard }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) { TilesView(tiles: model.tiles, columns: 2); targets(height: 190) }.frame(maxWidth: .infinity)
            }
            footer
        }
    }
}
