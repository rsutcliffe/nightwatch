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
    @Environment(\.phoneTheme) private var theme
    @Environment(\.horizontalSizeClass) private var sizeClass

    public init(model: TonightModel, markData: Data?, offline: Bool, refreshing: Bool, onRefresh: @escaping () -> Void) {
        self.model = model; self.markData = markData; self.offline = offline; self.refreshing = refreshing; self.onRefresh = onRefresh
    }

    private var snap: WidgetSnapshot { model.snapshot }

    private var verdict: some View {
        HStack(alignment: .center, spacing: 16) {
            ScoreBezelView(score: snap.score, slots: snap.slots, label: snap.bezelLabel)
            VStack(alignment: .leading, spacing: 4) {
                Text(snap.headline).font(.title3.weight(.medium)).fixedSize(horizontal: false, vertical: true)
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
                    Card { Text("No connection. Showing the forecast from \(ForecastAge(fetchedAt: model.fetchedAt, now: .now).text).").font(.callout) }
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(theme.warning, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                }
                if sizeClass == .regular {
                    HStack(alignment: .top, spacing: 16) {
                        VStack(alignment: .leading, spacing: 14) {
                            Card { verdict }
                            Card { ClearSkyBarsView(bars: snap.bars, caption: snap.barsLabel, trackHeight: 70) }
                        }
                        VStack(alignment: .leading, spacing: 14) {
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
                SourceFooter(model: model, markData: markData, refreshing: refreshing, onRefresh: onRefresh)
            }
            .padding(16)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .refreshable { onRefresh() }
    }
}
