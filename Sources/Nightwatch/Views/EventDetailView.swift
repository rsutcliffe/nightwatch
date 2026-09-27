import SwiftUI
import NightwatchUI
import SkyCore

/// An event's page (v1.0.1), laid out as a target's page is: the picture fills the space above a black caption box with the
/// title, the facts and "How to shoot this". The picture is the event's artwork, the radiant's constellation for a meteor
/// shower, and a drawing of the pass across the sky for the ISS (owner's choices, 27 September 2026).
struct EventDetailView: View {
    @EnvironmentObject var store: Store
    let event: SkyEvent
    let onBack: () -> Void
    @StateObject private var tipsUI = TipsState()
    private static let presets = (try? TelescopePresets.bundled()) ?? []

    var body: some View {
        ZStack {
            Theme.card
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button(action: onBack) { Label("Events", systemImage: "chevron.left").captionPill() }.buttonStyle(.plain)
                    Spacer()
                }
                .zIndex(1)
                hero.frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(alignment: .bottomTrailing) { tips }
                caption.zIndex(1)
            }
            .padding(16)
        }
        .foregroundStyle(Theme.text)
    }

    @ViewBuilder private var hero: some View {
        if event.kind == .issPass, !event.path.isEmpty, let s = store.site {
            SkyPathView(path: event.path, site: s).frame(maxWidth: 420, maxHeight: 420)
        } else if event.kind == .meteorShower, let id = event.radiantConstellation, let art = ConstellationArt(id: id) {
            art
        } else {
            EventArt(kind: event.kind).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder private var tips: some View {
        if tipsUI.shown, let s = store.site {
            let preset = Self.presets.first { $0.id == store.config.fovPresetID }
            ShootingTipCard(tip: ShootingTips.tip(for: event, fov: store.config.fov, presetName: preset?.name, site: s)).zIndex(2)
        }
    }

    private var caption: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 18) { titleBlock.frame(maxWidth: 360, alignment: .leading); Spacer(minLength: 12); facts.frame(maxWidth: 470) }
            VStack(alignment: .leading, spacing: 12) { titleBlock; facts }
        }
        .padding(14)
        .captionBacking(cornerRadius: 10)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title).font(.system(size: 24, weight: .semibold)).lineLimit(2)
            Text(event.detail).font(.system(size: 13)).foregroundStyle(Theme.text.opacity(0.85)).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                if event.atPeak { Chip(text: "At peak", icon: "sparkle") }
                if let f = event.fits { Chip(text: f ? "Fits frame" : "Too wide", icon: "viewfinder") }
                if let c = event.clear { Chip(text: c ? "Clear then" : "Cloudy then", icon: c ? "checkmark" : "cloud.fill", warning: !c) }
            }
            .padding(.top, 2)
            if store.site != nil { HowToShootButton(shown: $tipsUI.shown).help("How to photograph this event") }
        }
    }

    private var facts: some View {
        Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 6) {
            ForEach(event.facts, id: \.label) { f in
                GridRow {
                    Text(f.label).font(.system(size: 11)).foregroundStyle(Theme.dim)
                    Text(f.value).font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
