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

    private func verdict(big: Bool) -> some View {
        // At the accessibility text sizes the words need the full width, so the bezel sits above them.
        let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .center, spacing: big ? 28 : 18))
        return layout {
            ScoreBezelView(score: snap.score, slots: snap.slots, label: snap.bezelLabel, size: big ? 190 : 104)
            VStack(alignment: .leading, spacing: 5) {
                Text(snap.headline).font(.system(big ? .largeTitle : .title2, design: .serif, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                if let w = snap.window { Text(w).font(big ? .title3.weight(.medium) : .callout.weight(.medium)).monospacedDigit().foregroundStyle(theme.accent) }
                if let r = snap.reason { Text(r).font(big ? .callout : .footnote).secondary().fixedSize(horizontal: false, vertical: true) }
                if let a = snap.agreement {
                    Text((snap.agreementWarns ? "! " : "✓ ") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                        .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary)
                }
            }
        }
        .heroSurface(clear: clearNight, padding: big ? 24 : 16)
    }

    private func bars(height: CGFloat) -> some View {
        Card { ClearSkyBarsView(bars: snap.bars, caption: snap.barsLabel, trackHeight: height) }
    }

    private var targets: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("BEST TONIGHT").font(.caption.weight(.medium)).tracking(0.8).secondary()
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    if snap.targets.isEmpty {
                        Text("None above the horizon in the window.").font(.callout).secondary()
                    }
                    ForEach(Array(snap.targets.prefix(3).enumerated()), id: \.offset) { _, t in
                        HStack { Text(t.name); Spacer(); Text(t.best).monospacedDigit().secondary() }.font(.callout)
                    }
                }
            }
        }
    }

    private var offlineNote: some View {
        Card { Text("No connection. Showing the forecast from \(ForecastAge(fetchedAt: model.fetchedAt, now: now).text).").font(.callout) }
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.warning, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let t = snap.tomorrow { Text(t).font(.footnote).secondary() }
            if let alertsPrompt { alertsPrompt }
            SourceFooter(model: model, markData: markData, refreshing: refreshing, onRefresh: onRefresh)
        }
    }

    // MARK: Layouts

    public var body: some View {
        GeometryReader { geo in
            ScrollView {
                Group {
                    if geo.size.width >= 1000 { landscape } else if geo.size.width >= 600 { portrait(width: geo.size.width) } else { compact }
                }
                .padding(geo.size.width >= 600 ? 28 : 16)
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
            verdict(big: false)
            bars(height: 37)
            TilesView(tiles: model.tiles)
            targets
            footer
        }
    }

    private func portrait(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if offline { offlineNote }
            header
            verdict(big: true)
            bars(height: 90)
            TilesView(tiles: model.tiles, columns: width >= 900 ? 6 : 3)
            targets
            footer
        }
    }

    private var landscape: some View {
        VStack(alignment: .leading, spacing: 20) {
            if offline { offlineNote }
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 20) { header; verdict(big: true) }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) { bars(height: 110); TilesView(tiles: model.tiles, columns: 2) }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) { targets }.frame(maxWidth: .infinity)
            }
            footer
        }
    }
}
