import SwiftUI
import SkyCore
import PhoneCore

/// The Targets browser: Favourites and the groups, each with how many are up tonight, as the Mac's sidebar lists them.
struct TargetsScreen: View {
    @ObservedObject var store: PhoneStore
    @Environment(\.phoneTheme) private var theme

    private var plan: NightPlan? { store.planning?.tonight }
    private func targets(in g: TargetGroup) -> [RankedTarget] { (plan?.mode == .bright ? plan?.brightTargets : plan?.targets)?.filter { $0.group == g } ?? [] }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                row(title: "Favourites", symbol: "heart.fill", count: store.config.favourites.count) { FavouritesScreen(store: store) }
                ForEach(TargetGroup.allCases.filter { $0 != .events }, id: \.self) { g in
                    row(title: g.displayName, symbol: g.phoneSymbol, count: targets(in: g).count) { TargetGroupScreen(store: store, group: g) }
                }
            }
            .padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background { StarField(seed: "targets").ignoresSafeArea() }
    }

    private func row<D: View>(title: String, symbol: String, count: Int, @ViewBuilder dest: @escaping () -> D) -> some View {
        NavigationLink(destination: dest) {
            HStack(spacing: 12) {
                Image(systemName: symbol).frame(width: 28).foregroundStyle(theme.accent)
                Text(title).font(.body.weight(.medium))
                Spacer()
                Text("\(count)").font(.callout).monospacedDigit().secondary()
                Image(systemName: "chevron.right").font(.footnote).secondary()
            }
            .padding(.horizontal, 14).frame(minHeight: 56)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressStyle())
    }
}

/// One group's targets for tonight: search, sort, and the two switches the Mac has (only those that fit the telescope, include those
/// washed out by the Moon). While searching, matches the switches would hide still show, last.
struct TargetGroupScreen: View {
    @ObservedObject var store: PhoneStore
    let group: TargetGroup
    @State private var query = ""
    @State private var sort = TargetSort.bestNow
    @AppStorage("fitsOnly") private var fitsOnly = false
    @AppStorage("includeMoonWashed") private var includeMoonWashed = false
    @Environment(\.phoneTheme) private var theme

    var body: some View {
        let plan = store.planning?.tonight
        let all = (plan?.mode == .bright ? plan?.brightTargets : plan?.targets) ?? []
        let shown = store.site.map { site in
            RankedTarget.cards(all, group: group, query: query, fitsOnly: fitsOnly, includeMoonWashed: includeMoonWashed, sort: sort,
                               now: store.now, span: plan?.primary, site: site)
        } ?? []
        ScrollView {
            LazyVStack(spacing: 10) {
                HStack {
                    Menu { Picker("Sort", selection: $sort) { ForEach(TargetSort.allCases, id: \.self) { Text($0.rawValue).tag($0) } } } label: {
                        Label("Sort: \(sort.rawValue)", systemImage: "arrow.up.arrow.down").font(.callout)
                    }
                    Spacer()
                }
                Toggle("Only those that fit my telescope", isOn: $fitsOnly).font(.callout)
                Toggle("Include those the Moon washes out", isOn: $includeMoonWashed).font(.callout)
                if shown.isEmpty {
                    Text(query.isEmpty ? "Nothing in this group is up tonight." : "No match.").font(.callout).secondary().padding(.top, 20)
                }
                ForEach(shown) { t in
                    NavigationLink { TargetDetailScreen(store: store, target: t) } label: {
                        TargetCardView(store: store, target: t, dimmed: t.hiddenByFit(fitsOnly: fitsOnly) || t.hiddenByMoon(includeMoonWashed: includeMoonWashed))
                    }.buttonStyle(.plain)
                }
            }
            .padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .toggleStyle(PhoneToggleStyle())
        .background { StarField(seed: group.rawValue).ignoresSafeArea() }
        .searchable(text: $query, prompt: "M42, Orion, comet")
        .navigationTitle(group.displayName)
        .navigationBarTitleDisplayModeInline()
    }
}

/// The user's favourites for tonight: those that are up first, then the rest greyed with the reason, as on the Mac.
struct FavouritesScreen: View {
    @ObservedObject var store: PhoneStore

    var body: some View {
        let favs = store.planning?.tonight.favourites ?? []
        let usable = favs.filter { $0.notTonight == nil }.sorted { $0.target.peakTime < $1.target.peakTime }
        let rest = favs.filter { $0.notTonight != nil }
        ScrollView {
            LazyVStack(spacing: 10) {
                if favs.isEmpty {
                    EmptyState(title: "No favourites yet", message: "Tap the heart on any target to keep it here, and in every night's plan when it is up.")
                }
                ForEach(usable) { f in
                    NavigationLink { TargetDetailScreen(store: store, target: f.target) } label: { TargetCardView(store: store, target: f.target) }.buttonStyle(.plain)
                }
                ForEach(rest) { f in
                    NavigationLink { TargetDetailScreen(store: store, target: f.target) } label: {
                        TargetCardView(store: store, target: f.target, dimmed: true, note: f.notTonight)
                    }.buttonStyle(.plain)
                }
            }
            .padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background { StarField(seed: "favourites").ignoresSafeArea() }
        .navigationTitle("Favourites")
        .navigationBarTitleDisplayModeInline()
    }
}
