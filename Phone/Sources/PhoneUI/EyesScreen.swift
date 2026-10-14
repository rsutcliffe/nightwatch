import SwiftUI
import SkyCore
import PhoneCore

/// Eyes and binoculars: what can be seen tonight without a telescope from this site's sky, and the events that need none.
struct EyesScreen: View {
    @ObservedObject var store: PhoneStore
    @State private var query = ""

    var body: some View {
        let targets = store.eyeTargets.filter { $0.matches(query) }
        let events = store.eyeEvents.filter { e in
            let q = query.trimmingCharacters(in: .whitespaces)
            return q.isEmpty || [e.title, e.detail, e.kind.phoneName].contains { $0.localizedCaseInsensitiveContains(q) }
        }
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                Text(store.eyeTargets.isEmpty && store.eyeEvents.isEmpty ? "Nothing bright enough to see without a telescope tonight."
                                                                         : "No telescope needed. Look first with your eyes; binoculars show the rest.")
                    .font(.callout).secondary()
                ForEach(Array(targets.enumerated()), id: \.element.id) { i, t in
                    if let eye = store.eyeView(t) {
                        NavigationLink { TargetDetailScreen(store: store, target: t, eye: eye) } label: { TargetCardView(store: store, target: t, eye: eye) }
                            .buttonStyle(.plain).risesIn(i)
                    }
                }
                if let site = store.site, !events.isEmpty {
                    Text("EVENTS").font(.caption.weight(.medium)).tracking(0.8).secondary().padding(.top, 10)
                    ForEach(events) { e in
                        NavigationLink { EventDetailScreen(store: store, event: e) } label: { EventCard(event: e, site: site) }.buttonStyle(.plain)
                    }
                }
            }
            .padding(16).frame(maxWidth: 700).frame(maxWidth: .infinity)
        }
        .background { StarField(seed: "eyes").ignoresSafeArea() }
        .searchable(text: $query, prompt: "Orion, Pleiades, Moon")
        .navigationTitle("Eyes and binoculars")
        .navigationBarTitleDisplayModeInline()
    }
}
