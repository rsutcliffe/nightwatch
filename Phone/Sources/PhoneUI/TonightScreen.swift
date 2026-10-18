import SwiftUI
import SkyCore
import PhoneCore

/// Tonight's answer for the active site. Three layouts from one set of sections: one column (iPhone, Slide Over), a wide
/// portrait page (iPad upright) and three columns (iPad landscape).
public struct TonightScreen: View {
    let model: TonightModel
    let markData: Data?
    let offline: Bool
    /// When iOS said there was a connection but the forecast services did not answer: the reason, so "No connection" is not claimed untruly.
    var failure: String? = nil
    let refreshing: Bool
    let onRefresh: () -> Void
    var alertsPrompt: AlertsPrompt? = nil
    var now: Date = .now
    var visit: AnyView? = nil
    @Environment(\.phoneTheme) private var theme

    public init(model: TonightModel, markData: Data?, offline: Bool, refreshing: Bool, onRefresh: @escaping () -> Void,
                alertsPrompt: AlertsPrompt? = nil, now: Date = .now, visit: AnyView? = nil, failure: String? = nil) {
        self.failure = failure
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

    private func verdict(_ scale: TonightHeroView.Scale) -> some View {
        TonightHeroView(snap: snap, hero: model.hero, scale: scale, figure: clearNight ? nil : figureArt)
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

    private var hours: some View {
        ClearHoursLine(bars: snap.bars, caption: snap.barsLabel, end: model.hero.times?.components(separatedBy: "-").last, moonNote: model.hero.moonNote)
    }

    private func targets(height: CGFloat = 78) -> some View { PicksSection(model: model, pictureHeight: height) }

    private var offlineNote: some View {
        Card {
            let age = ForecastAge(fetchedAt: model.fetchedAt, now: now).text
            Text(failure.map { "Couldn't read a new forecast: \($0). Showing the one from \(age). Trying again shortly." } ?? "No connection. Showing the forecast from \(age).")
                .font(.callout)
        }
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
            hours
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
            verdict(.medium)
            hours
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
                VStack(alignment: .leading, spacing: 20) { header; visit; verdict(.large); hours; auroraRow; tomorrowCard }.frame(maxWidth: .infinity)
                VStack(alignment: .leading, spacing: 20) { TilesView(tiles: model.tiles, columns: 2); targets(height: 190) }.frame(maxWidth: .infinity)
            }
            footer
        }
    }
}
