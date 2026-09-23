import SwiftUI
import SkyCore

enum BrowserSection: Hashable { case group(TargetGroup), darkSites }

final class TargetsViewState: ObservableObject {
    @Published var section: BrowserSection = .group(.nebulae)
    @Published var fitsOnly = false
    @Published var includeMoonWashed = false
    @Published var search = ""
    @Published var selected: RankedTarget? = nil
}

struct TargetsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var ui = TargetsViewState()

    private var targets: [RankedTarget] { store.plan?.targets ?? [] }

    private func count(_ g: TargetGroup) -> Int {
        g == .events ? store.events.count : targets.filter { $0.group == g }.count
    }

    private var selectedGroup: TargetGroup {
        if case .group(let g) = ui.section { return g }
        return .nebulae
    }

    private var visible: [RankedTarget] {
        guard case .group(let g) = ui.section else { return [] }
        return targets.filter { $0.group == g }
            .filter { !ui.fitsOnly || $0.fit == .fits }
            .filter { ui.includeMoonWashed || !$0.moonWashed }
            .filter { ui.search.isEmpty || $0.name.localizedCaseInsensitiveContains(ui.search) || $0.subtitle.localizedCaseInsensitiveContains(ui.search) }
    }

    var body: some View {
        NavigationSplitView {
            List(TargetGroup.allCases.map { BrowserSection.group($0) } + [.darkSites], id: \.self, selection: $ui.section) { section in
                switch section {
                case .group(let g):
                    Label { HStack { Text(g.displayName); Spacer(); Text("\(count(g))").foregroundStyle(Theme.dim) } } icon: { Image(systemName: Theme.glyph(for: g)) }
                case .darkSites:
                    Label { HStack { Text("Dark sites"); Spacer(); Text("\(store.darkSites.count)").foregroundStyle(Theme.dim) } } icon: { Image(systemName: "moon.stars") }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("Fits my field of view", isOn: $ui.fitsOnly)
                    Toggle("Include Moon-washed", isOn: $ui.includeMoonWashed)
                }.font(.caption).padding(10)
            }
            .navigationSplitViewColumnWidth(232)
        } detail: {
            if let selected = ui.selected {
                DetailView(target: selected) { ui.selected = nil }
            } else {
                switch ui.section {
                case .group(.events): eventsList
                case .darkSites: darkSitesList
                case .group: grid
                }
            }
        }
        .searchable(text: $ui.search, prompt: "M42, Orion, comet…")
        .preferredColorScheme(.dark)
        .background(Theme.bg)
    }

    private var darkSitesList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text("Dark sites").font(.title2.weight(.semibold))
                Text("Within \(Geo.format(km: store.config.darkSites.radiusKm, unit: store.distanceUnit)) of \(store.site?.name ?? "home") · sorted by tonight's score").font(.caption).foregroundStyle(Theme.dim)
            }.frame(maxWidth: .infinity, alignment: .leading).padding([.horizontal, .top], 20)
            if store.darkSites.isEmpty {
                Text("No dark sites within \(Geo.format(km: store.config.darkSites.radiusKm, unit: store.distanceUnit)). Widen the radius in Settings.")
                    .foregroundStyle(Theme.dim).padding(20)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(store.sitePlans) { DarkSiteCard(plan: $0) }
                ForEach(store.darkSites.dropFirst(8)) { DarkSiteCard(plan: SitePlan.missing($0)) }
            }.padding(20)
        }
    }

    private var grid: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedGroup.displayName).font(.title2.weight(.semibold))
                if let w = store.plan?.primary, let s = store.site {
                    Text("Sorted by fit and altitude during tonight's clear window · \(Copy.hhmm(w.start, site: s))–\(Copy.hhmm(w.end, site: s))").font(.caption).foregroundStyle(Theme.dim)
                } else if let n = store.plan?.night, let ds = n.darkStart, let de = n.darkEnd, let s = store.site {
                    Text("\(store.copy.noWindow) Showing what is up during darkness · \(Copy.hhmm(ds, site: s))–\(Copy.hhmm(de, site: s))").font(.caption).foregroundStyle(Theme.dim)
                } else {
                    Text(store.copy.noWindow).font(.caption).foregroundStyle(Theme.dim)
                }
            }.frame(maxWidth: .infinity, alignment: .leading).padding([.horizontal, .top], 20)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                ForEach(visible) { t in
                    Button { ui.selected = t } label: { card(t) }.buttonStyle(.plain)
                }
            }.padding(20)
        }
    }

    private func badge(_ t: RankedTarget) -> some View {
        let (text, colour): (String, Color) = t.moonWashed ? ("Moon-washed", Theme.bad) : (t.fit == .fits ? ("Fits frame", Theme.accent) : (t.fit == .small ? ("Small", Theme.warn) : ("Mosaic", Theme.warn)))
        return Text(text).font(.caption2).padding(.horizontal, 7).padding(.vertical, 3).background(colour.opacity(0.15)).foregroundStyle(colour).clipShape(Capsule())
    }

    private func card(_ t: RankedTarget) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ThumbnailView(target: t).frame(height: 110).overlay(alignment: .topTrailing) { badge(t).padding(8) }
            HStack(alignment: .firstTextBaseline) {
                Text(t.name).font(.callout.weight(.semibold)).lineLimit(1)
                Spacer()
                if let m = t.magnitude { Text(String(format: "mag %.1f", m)).font(.caption2).foregroundStyle(Theme.dim) }
            }
            HStack(spacing: 8) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.line).frame(height: 4)
                        Capsule().fill(t.moonWashed ? Theme.dim : Theme.accent).frame(width: g.size.width * t.visibleFraction, height: 4)
                    }
                }.frame(height: 4)
                if let s = store.site { Text("best \(Copy.hhmm(t.peakTime, site: s)) · \(Int(t.peakAltDeg))°").font(.caption2).foregroundStyle(Theme.text) }
            }
        }
        .padding(10).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }

    private var eventsList: some View {
        List(store.events) { e in
            HStack {
                Image(systemName: e.kind == .issPass ? "airplane" : (e.kind == .meteorShower ? "sparkle" : (e.kind == .comet ? "comet" : "moon.stars"))).foregroundStyle(Theme.accent)
                VStack(alignment: .leading) {
                    Text(e.title).font(.callout.weight(.semibold))
                    Text(e.detail).font(.caption).foregroundStyle(Theme.dim)
                }
                Spacer()
                if let s = store.site { Text(e.kind == .lunarEclipse || e.kind == .solarEclipse ? e.time.formatted(date: .abbreviated, time: .shortened) : Copy.hhmm(e.time, site: s)).font(.caption).foregroundStyle(Theme.dim) }
            }.padding(.vertical, 4)
        }
        .overlay { if store.events.isEmpty { Text("No events tonight").foregroundStyle(Theme.dim) } }
    }
}

struct DarkSiteCard: View {
    @EnvironmentObject var store: Store
    let plan: SitePlan
    var body: some View {
        let s = plan.site
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(s.name).font(.callout.weight(.semibold)).lineLimit(2)
                Spacer()
                if !plan.forecastMissing { Text("\(plan.score)").font(.title3.weight(.semibold)).foregroundStyle(plan.qualifies ? Theme.accent : Theme.dim) }
            }
            Text("\(Geo.format(km: s.distanceKm, unit: store.distanceUnit)) \(s.compass) · \(s.kind.capitalized)" + (s.bortle.map { " · Bortle \($0)" } ?? s.band.map { " · \($0.displayName)" } ?? ""))
                .font(.caption).foregroundStyle(Theme.dim)
            if let w = plan.primary, let home = store.site {
                Text("Clear \(Copy.hhmm(w.start, site: home))–\(Copy.hhmm(w.end, site: home)) · \(String(format: "%.1f h", w.hours))").font(.caption)
            } else if plan.forecastMissing {
                Text("No forecast fetched (beyond the nearest eight, or offline)").font(.caption).foregroundStyle(Theme.dim)
            } else {
                Text(store.copy.noWindow).font(.caption).foregroundStyle(Theme.dim)
            }
            HStack {
                if let src = s.source, let url = URL(string: src) { Link("Source", destination: url).font(.caption) }
                Spacer()
                Button("Use as beat") { store.adoptAsBeat(s) }.font(.caption)
            }
        }
        .padding(12).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line))
    }
}
