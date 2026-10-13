import SwiftUI
import SkyCore
import PhoneCore

/// Tonight's answer for the active site. Width decides the layout: one column on an iPhone, two on an iPad.
public struct TonightScreen: View {
    let model: TonightModel
    let markData: Data?
    let offline: Bool
    let refreshing: Bool
    let onRefresh: () -> Void
    var alertsPrompt: AlertsPrompt? = nil
    var now: Date = .now
    @Environment(\.phoneTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(model: TonightModel, markData: Data?, offline: Bool, refreshing: Bool, onRefresh: @escaping () -> Void, alertsPrompt: AlertsPrompt? = nil, now: Date = .now) {
        self.alertsPrompt = alertsPrompt; self.now = now
        self.model = model; self.markData = markData; self.offline = offline; self.refreshing = refreshing; self.onRefresh = onRefresh
    }

    private var snap: WidgetSnapshot { model.snapshot }

    private var regular: Bool { sizeClass == .regular }

    private var verdict: some View {
        HStack(alignment: .center, spacing: 20) {
            ScoreBezelView(score: snap.score, slots: snap.slots, label: snap.bezelLabel, size: regular ? 170 : 104)
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.headline).font(regular ? .title.weight(.medium) : .title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
                if let w = snap.window { Text(w).font(.callout).foregroundStyle(theme.accent) }
                if let r = snap.reason { Text(r).font(.footnote).secondary().fixedSize(horizontal: false, vertical: true) }
                if let a = snap.agreement {
                    Text((snap.agreementWarns ? "! " : "") + a).font(.footnote.weight(snap.agreementWarns ? .semibold : .regular))
                        .foregroundStyle(snap.agreementWarns ? theme.warning : theme.textSecondary)
                }
            }
        }
    }

    private var targets: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Best targets tonight").font(.caption).secondary()
                if snap.targets.isEmpty {
                    Text("None above the horizon in the window.").font(.callout).secondary()
                }
                ForEach(Array(snap.targets.prefix(3).enumerated()), id: \.offset) { _, t in
                    HStack { Text(t.name); Spacer(); Text(t.best).secondary() }.font(.callout)
                }
            }
        }
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if offline {
                    Card { Text("No connection. Showing the forecast from \(ForecastAge(fetchedAt: model.fetchedAt, now: now).text).").font(.callout) }
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.warning, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                if regular {
                    HStack(alignment: .top, spacing: 20) {
                        VStack(alignment: .leading, spacing: 20) {
                            Card(padding: 20) { verdict }
                            Card(padding: 20) { ClearSkyBarsView(bars: snap.bars, caption: snap.barsLabel, trackHeight: 170) }
                        }
                        VStack(alignment: .leading, spacing: 20) {
                            TilesView(tiles: model.tiles)
                            targets
                        }
                    }
                } else {
                    Card { verdict }
                    Card { ClearSkyBarsView(bars: snap.bars, caption: snap.barsLabel) }
                    TilesView(tiles: model.tiles)
                    targets
                }
                if let t = snap.tomorrow { Text(t).font(.footnote).secondary() }
                if let alertsPrompt { alertsPrompt }
                SourceFooter(model: model, markData: markData, refreshing: refreshing, onRefresh: onRefresh)
            }
            .padding(regular ? 28 : 16)
            .frame(maxWidth: 1100)
            .frame(maxWidth: .infinity)
        }
        .refreshable { onRefresh() }
    }
}
