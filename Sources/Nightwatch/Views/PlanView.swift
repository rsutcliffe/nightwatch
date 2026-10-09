import SwiftUI
import NightwatchUI
import SkyCore

/// Tonight's plan as a page of its own in the Targets window (#57, redesigned from the owner's UAT and approved mock-up,
/// 29 September 2026): the user's favourites that are up in the clear window, plus anything added for the night, in order
/// of their best time. "Not tonight" takes one off for that night; the choice is saved with the settings, so it syncs and
/// is still there when the night planned as tomorrow becomes tonight.
struct PlanView: View {
    @EnvironmentObject var store: Store
    /// The night shown: tonight, or tomorrow night while it is chosen.
    let plan: NightPlan?
    let canPlanTomorrow: Bool
    @Binding var tomorrow: Bool
    /// The suggested targets are on show: only once asked for, or when there are no favourites to make a plan from.
    @Binding var showSuggestions: Bool
    let onSelect: (RankedTarget) -> Void

    private var isTomorrow: Bool { plan != nil && plan?.night.key != store.plan?.night.key }
    private var session: SessionPlan? { store.session(for: plan) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(isTomorrow ? "Tomorrow night's plan" : "Tonight's plan").font(Font.scaled(.title2).weight(.semibold))
                HStack(spacing: 12) {
                    if canPlanTomorrow {
                        SegmentedChoice(title: "Night", showsTitle: false, selection: $tomorrow, options: [(false, "Tonight"), (true, "Tomorrow night")])
                            .fixedSize()
                    }
                    // Only on a night with a plan and something to suggest. With no favourites they are shown anyway.
                    if let session, !session.suggestions.isEmpty, !store.config.favourites.isEmpty {
                        Button(showSuggestions ? "Hide suggestions" : "Show suggestions") { showSuggestions.toggle() }
                            .buttonStyle(SecondaryButtonStyle())
                    }
                }
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    @ViewBuilder private var content: some View {
        if let p = plan, let s = store.site {
            if let session {
                Text(Copy.planSummary(session, plan: p, site: s)).font(Font.scaled(.callout)).foregroundStyle(Tokens.textSecondary)
                let suggesting = showSuggestions || store.config.favourites.isEmpty
                let rows = session.rows.filter { if case .suggestion = $0 { suggesting } else { true } }
                let words = isTomorrow ? "tomorrow night" : "tonight"
                if rows.isEmpty && session.omitted.isEmpty {
                    empty
                } else {
                    // With no favourites a clear night still has suggestions to review (owner, 9 October 2026).
                    Text(store.config.favourites.isEmpty && !session.suggestions.isEmpty
                         ? "You have no favourites yet, so these are suggested for \(words): well-placed targets spread across the clear window. Add the ones you want. Heart a target to keep it in every plan."
                         : "Your favourites that are up in the clear window, in order of their best time. Take off any you'll skip \(words): your choices are kept for this night, even if you make them the day before.")
                        .font(Font.scaled(.callout)).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                    // Each target keeps its line style from night to night (owner, 1 October 2026).
                    let styles = ChartLayout.styles(for: session.items.map(\.target.id), count: PlanLineStyle.all.count)
                    if !rows.isEmpty {
                        // Drawn with no lines too, so the rows do not jump up when the last one is taken off.
                        PlanChart(items: session.items, night: p.night, window: p.primary ?? session.window, minAltitude: store.config.goRule.minAltitudeDeg,
                                  site: s, nightWords: words, styles: styles)
                    }
                    // One list by best time: a row changes how it looks where it stands, and nothing else moves.
                    VStack(spacing: 8) {
                        ForEach(rows) { r in
                            switch r {
                            case .item(let item): row(item, index: styles[item.target.id] ?? 0, night: p.night.key, site: s)
                            case .suggestion(let t):
                                offRow(r, symbol: "plus", button: "Add to plan", label: "Add \(t.name) to the plan", night: p.night.key, site: s)
                            case .takenOff(let t):
                                offRow(r, symbol: "minus", button: "Put back", label: "Put \(t.name) back in the plan", night: p.night.key, site: s)
                            }
                        }
                    }
                    if rows.isEmpty {
                        Text("Nothing for the plan this night.").font(Font.scaled(.callout)).foregroundStyle(Tokens.textSecondary)
                    }
                    if !session.omitted.isEmpty {
                        group("FAVOURITES NOT IN THE PLAN") {
                            ForEach(session.omitted) { o in
                                Text("\(o.target.name) · \(o.reason.prefix(1).lowercased() + o.reason.dropFirst())")
                                    .font(.system(size: TextScale.pt(13))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    Text("Heart a target to keep it in every plan, or use Add to plan on its page for one night only.")
                        .font(Font.scaled(.caption)).foregroundStyle(Tokens.textSecondary)
                }
            } else if p.mode == .bright {
                note("A bright night: the plan is for dark, clear nights. The Moon and planets are in Targets.")
            } else if p.primary == nil, canPlanTomorrow, let w = store.tomorrow?.primary {
                note("\(store.copy.noWindow) Tomorrow night looks clear \(Copy.span(w.start, w.end, site: s)): choose Tomorrow night above to plan it.")
            } else if p.primary == nil {
                note(isTomorrow ? "No clear window forecast for tomorrow night." : store.copy.noWindow)
            } else {
                note("Your finish time comes before \(isTomorrow ? "tomorrow night's" : "tonight's") clear window opens.")
            }
        } else {
            note(store.lastError ?? "Waiting for the first forecast…")
        }
    }

    private func note(_ text: String) -> some View {
        Text(text).font(Font.scaled(.callout)).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
    }

    /// No favourites and nothing added: what the plan is made from.
    private var empty: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart").font(.system(size: TextScale.pt(34))).foregroundStyle(Tokens.textSecondary).accessibilityHidden(true)
            Text("Your plan is made from your favourites").font(Font.scaled(.headline))
            Text("Heart the targets you want to image. Each night, the ones up in the clear window appear here in order of their best time, and you choose which to keep.")
                .font(Font.scaled(.callout)).foregroundStyle(Tokens.textSecondary).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            Button("Browse tonight's targets") { store.targetsRequest = TargetsRequest(section: .group(.nebulae), siteID: nil) }
                .buttonStyle(ScaledButtonStyle(prominent: true))
        }
        .frame(maxWidth: 460).frame(maxWidth: .infinity).padding(.top, 40)
    }

    private func row(_ item: PlanItem, index: Int, night: String, site: Site) -> some View {
        let t = item.target
        return HStack(spacing: 16) {
            HStack(spacing: 16) {
                PlanLineKey(index: index)
                Text(Copy.hhmm(t.peakTime, site: site)).font(.system(size: TextScale.pt(18), weight: .semibold)).monospacedDigit().frame(width: 58, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(t.catalogueID.isEmpty ? t.name : t.catalogueID).font(.system(size: TextScale.pt(14), weight: .semibold))
                        if !t.catalogueID.isEmpty, t.cardName != t.catalogueID { Text(t.cardName).font(.system(size: TextScale.pt(14))).foregroundStyle(Tokens.textSecondary) }
                    }
                    Text(Copy.planDetail(item, presetID: store.config.fovPresetID, site: site))
                        .font(.system(size: TextScale.pt(12))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                    if let clash = Copy.planClash(item) {
                        HStack(spacing: 6) {
                            Circle().fill(Tokens.statusWarning).frame(width: 6, height: 6).accessibilityHidden(true)
                            Text(clash).font(.system(size: TextScale.pt(12))).foregroundStyle(Tokens.statusWarning)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opens { onSelect(t) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect(t) }
            Button("Not \(isTomorrow ? "tomorrow" : "tonight")") { store.setInPlan(t.id, false, night: night) }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel("Take \(t.name) off the plan")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .background(Tokens.targetsCard, in: RoundedRectangle(cornerRadius: 11))
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Tokens.cardOutline, lineWidth: 1))
    }

    /// A target that is not in the plan and keeps its place in the list: one suggested for a long gap, or one taken off
    /// for the night (owner, 9 October 2026: the separate "Taken off" box "looks clunky next to the rest of the UI").
    /// Laid out as a plan row is, but outlined with dashes and without a fill or a chart line, with one button to put it in.
    private func offRow(_ r: PlanRow, symbol: String, button: String, label: String, night: String, site: Site) -> some View {
        let t = r.target
        return HStack(spacing: 16) {
            HStack(spacing: 16) {
                Image(systemName: symbol).font(.system(size: TextScale.pt(13), weight: .medium)).foregroundStyle(Tokens.textSecondary)
                    .frame(width: 26, height: 10).accessibilityHidden(true)
                Text(Copy.hhmm(t.peakTime, site: site)).font(.system(size: TextScale.pt(18), weight: .semibold)).monospacedDigit()
                    .foregroundStyle(Tokens.textSecondary).frame(width: 58, alignment: .leading)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(t.catalogueID.isEmpty ? t.name : t.catalogueID).font(.system(size: TextScale.pt(14), weight: .semibold))
                        if !t.catalogueID.isEmpty, t.cardName != t.catalogueID { Text(t.cardName).font(.system(size: TextScale.pt(14))).foregroundStyle(Tokens.textSecondary) }
                    }
                    Text(Copy.planOffDetail(r, nightWords: isTomorrow ? "tomorrow night" : "tonight", presetID: store.config.fovPresetID, site: site) ?? "")
                        .font(.system(size: TextScale.pt(12))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .opens { onSelect(t) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onSelect(t) }
            Button(button) { store.setInPlan(t.id, true, night: night) }
                .buttonStyle(SecondaryButtonStyle())
                .accessibilityLabel(label)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .overlay(RoundedRectangle(cornerRadius: 11).stroke(Tokens.cardOutline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
    }

    private func group<C: View>(_ title: String, @ViewBuilder _ rows: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: TextScale.pt(11), weight: .semibold)).tracking(0.6).foregroundStyle(Tokens.textSecondary)
            VStack(alignment: .leading, spacing: 6) { rows() }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Tokens.targetsCard, in: RoundedRectangle(cornerRadius: 11))
                .overlay(RoundedRectangle(cornerRadius: 11).stroke(Tokens.cardOutline, lineWidth: 1))
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
