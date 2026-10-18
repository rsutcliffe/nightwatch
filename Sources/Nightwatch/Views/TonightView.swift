import SwiftUI
import NightwatchUI
import SkyCore

struct TonightView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    /// The popover's height as laid out, to know when it is taller than the screen (#60).
    @State private var contentHeight: CGFloat = 0
    /// The usable height of the screen the popover is on, not the one with focus (a menu-bar app often has no key window).
    @State private var screenHeight: CGFloat = .greatestFiniteMagnitude

    /// Taller than the screen (a small display, or the Larger Text resolutions): it scrolls rather than losing its footer.
    /// Otherwise exactly as before, with no scroll view at all.
    var body: some View {
        Group {
            if contentHeight > screenHeight {
                ScrollView { content }.frame(height: screenHeight)
            } else {
                content
            }
        }
        .background { NightBackdrop() }
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Tokens.glassEdge, lineWidth: 1))
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onAppear { Task { await store.refresh(force: false) } }   // cheap: the 30-minute cache gate decides whether to fetch
        .background(WindowScreenReader { screenHeight = $0 - 24 })
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if store.isAway { awayBar }
            if let plan = store.plan, let site = store.site {
                verdict(plan, site)
                NightArcCanvas(bars: Planner.clearSkyBars(plan: plan, site: site), label: Copy.barsLabel(plan: plan, site: site),
                               ember: Tokens.ember, nowFraction: nowFraction(plan), height: 96)
                notice(site)
                tiles(plan, site)
                best(plan, site)
            } else {
                Text(store.lastError ?? "Waiting for the first forecast…").font(Font.scaled(.callout)).foregroundStyle(Theme.dim).padding(.vertical, 20)
            }
            footer
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 22, trailing: 16))   // extra at the foot: the window otherwise sits tight on the footer row
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
    }

    /// One click back to home after "Observe from here" or choosing another site (v0.6.5).
    private var awayBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "location.fill").font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.statusWarning).accessibilityHidden(true)
            Text("Observing away from home").font(.system(size: TextScale.pt(11)))
            Spacer()
            Button("Back to \(store.homeLabel)") { store.goHome() }.buttonStyle(SecondaryButtonStyle())
        }
        .padding(8)
        .cardSurface(radius: 10)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TONIGHT · \(store.site?.name.uppercased() ?? "NO SITE")").capsLabel()
                if let s = store.site, let p = store.plan {
                    Text("\(Copy.dayMonth(p.night.localDate, site: s)) · Bortle \(s.bortle) · EQ tilt \(String(format: "%.1f", abs(s.latitude)))° \(s.latitude >= 0 ? "true north" : "true south")" + (p.mode == .bright ? " · bright night" : ""))
                        .font(.system(size: TextScale.pt(11))).foregroundStyle(Tokens.textSecondary)   // wedge angle = site latitude; the vendor app does the alignment
                }
            }
            Spacer()
            Button { open("settings") } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).foregroundStyle(Theme.dim)
                .help("Settings").accessibilityLabel("Settings")
            // A menu-bar app has no menu bar of its own, so Quit lives here (owner, 27 September 2026); ⌘Q works while open.
            Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }.buttonStyle(.plain).foregroundStyle(Theme.dim)
                .keyboardShortcut("q").help("Quit Nightwatch").accessibilityLabel("Quit Nightwatch")
        }
    }

    /// A menu-bar agent app is never the active app, so a window opened from the popover would land behind
    /// whatever the user is working in. Activate first so the window comes to the front.
    private func open(_ id: String) {
        openWindow(id: id)
        NSApp.activate()
    }

    private func noWindowReason(_ plan: NightPlan, _ site: Site) -> String? {
        Planner.noWindowReasonText(plan: plan, rule: store.config.goRule, bright: store.config.brightNights, site: site)
    }

    private func verdict(_ plan: NightPlan, _ site: Site) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ScoreBezel(score: plan.score,
                       slots: Bezel.slots(darkness: plan.darkSpan, windows: plan.windows, primary: plan.primary, hours: plan.darkHours, site: site),
                       label: Copy.bezelLabel(plan, site: site))
            VStack(alignment: .leading, spacing: 4) {
                if let w = plan.primary {
                    TwoWeight.headline(plan.mode == .bright ? "Bright night: Moon and planets" : "Clear window tonight", size: TextScale.pt(16))
                    (Text("\(Copy.hhmm(w.start, site: site))–\(Copy.hhmm(w.end, site: site))".plainDashes).font(.system(size: TextScale.pt(24), weight: .thin))
                        + Text(" · \(String(format: "%.1f h", w.hours))").font(.system(size: TextScale.pt(13))))
                        .foregroundStyle(Tokens.lit).fixedSize(horizontal: false, vertical: true)
                    if let warning = dewWarning(plan) { WarningChip(warning) }
                    if plan.mode == .bright {
                        Text(Copy.brightList(plan.brightTargets)).font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary)
                    }
                    if let why = Copy.heldBack(plan.limiting) {
                        // No dot: every line under the verdict reads the same way (owner, 28 September 2026).
                        Text(why)
                            .font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    agreementLine(plan, site)
                } else if !plan.night.hasDarkness && (plan.mode == .dark || !plan.night.hasNauticalDarkness) {
                    TwoWeight.headline("No astronomical darkness", size: TextScale.pt(16))
                    Text("Too far north or south for this date.").font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary)
                } else {
                    TwoWeight.headline(store.copy.noWindow, size: TextScale.pt(16)).fixedSize(horizontal: false, vertical: true)
                    if let why = noWindowReason(plan, site) {
                        Text(why).font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    // No "Tomorrow" line: after sunrise the popover shows tomorrow night itself (owner, 28 September 2026).
                    agreementLine(plan, site)
                }
            }
        }
    }

    /// Open-Meteo's second opinion (v0.5). When it agrees, a small line with a tick. When it disagrees, one plain grey line
    /// that says what it means ("Less certain: a second forecast sees cloud from 00:00."): no box, no dot, no coloured text
    /// (owner, 28 September 2026).
    @ViewBuilder private func agreementLine(_ plan: NightPlan, _ site: Site) -> some View {
        if let advice = Copy.advice(plan, site: site, alerts: store.config.alerts) {
            let lead = "Less certain: "
            if advice.line.hasPrefix(lead) {
                VStack(alignment: .leading, spacing: 3) {
                    WarningChip("Less certain")
                    Text(String(advice.line.dropFirst(lead.count))).font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(advice.line).font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
        } else if let a = plan.agreement {
            HStack(spacing: 5) {
                Image(systemName: "checkmark").font(.system(size: TextScale.pt(7), weight: .bold)).accessibilityHidden(true)
                Text(Copy.agreementText(a, site: site))
            }
            .font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// At most one line under the bars: aurora first, then the Clearer sky line (spec §5.1).
    /// The aurora line needs its source to have published within the hour: AuroraWatch UK's `updated` time moves on
    /// every publication (live: 20:33:32Z then 20:39:31Z, both green), so an older status is stale. It is the status for
    /// this site: AuroraWatch UK's in the UK and Ireland, NOAA's figure for the site elsewhere.
    @ViewBuilder private func notice(_ site: Site) -> some View {
        if let a = store.auroraHere, store.config.aurora.shows(a), AuroraSettings.isFresh(a, now: Date()) {
            // AuroraWatch UK's terms ask for the source to be named, "ideally with a link or button" to their site.
            Link(destination: a.source.link) {
                Text(a.line).font(.system(size: TextScale.pt(10))).foregroundStyle(Color(hex: a.level.hex))
            }
            .buttonStyle(.plain).linkCursor().help(a.source == .noaa ? "Open NOAA's aurora forecast" : "Open AuroraWatch UK")
        } else if let a = store.bestAway, let w = a.primary {
            Button {
                // The menu-bar label also opens the window on any request; opening a single Window twice is harmless.
                store.targetsRequest = TargetsRequest(section: .darkSites, siteID: a.site.id)
                open("targets")
            } label: {
                Text("Clearer sky \(Geo.format(km: a.site.distanceKm, unit: store.distanceUnit)) \(a.site.compass): \(a.site.name)\(a.site.band.map { " (\($0.displayName))" } ?? ""), clear \(Copy.hhmm(w.start, site: site))–\(Copy.hhmm(w.end, site: site)) →")
                    .font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textPrimary).multilineTextAlignment(.leading)
            }.buttonStyle(.plain)   // a link, so text.primary: red means clear sky only
        }
    }

    /// One fact on the picture: a small capital label over a heavy value, and an optional hint.
    private struct Fact: Identifiable {
        let label: String
        let value: String?
        var hint: String? = nil
        var id: String { label }
    }

    private func tiles(_ plan: NightPlan, _ site: Site) -> some View {
        let dark = plan.darkSpan.map { "\(Copy.hhmm($0.start, site: site))–\(Copy.hhmm($0.end, site: site))" } ?? "None"
        let window = plan.primary.map { "\(Copy.hhmm($0.start, site: site))–\(Copy.hhmm($0.end, site: site))" }
        let moon = Planner.moonTonight(plan)
        let pct = "\(Int((plan.moonIllumination * 100).rounded()))%"
        let wind = plan.darkHours.compactMap(\.windKmh)
        let windText = wind.isEmpty ? nil : String(format: "%.0f km/h", wind.reduce(0, +) / Double(wind.count))
        let dew = Planner.dewRisk(plan.darkHours)
        let frost = plan.darkHours.compactMap(\.tempC).min().map { $0 <= 0 } ?? false
        let moonAt = plan.primary?.midpoint ?? plan.night.darkStart ?? plan.night.sunset
        // "Dark" is left out when it is the same span as the clear window shown above it; everything else the tiles said stays.
        let facts = [dark == window ? nil : Fact(label: "Dark", value: dark),
                     Fact(label: "Seeing", value: Copy.seeingText(plan.darkHours)),
                     Fact(label: "Wind", value: windText),
                     Fact(label: "Transparency", value: Copy.transparencyText(plan.darkHours)),
                     Fact(label: frost ? "Frost likely" : "Dew risk", value: dew?.displayName, hint: dew == .high ? "Dew heater advised" : nil)].compactMap { $0 }
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10, alignment: .topLeading), count: 3), alignment: .leading, spacing: 10) {
                ForEach(facts) { f in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(f.label.uppercased()).capsLabel()
                        Text((f.value ?? "No data").plainDashes).font(.system(size: TextScale.pt(14), weight: .heavy))
                            .foregroundStyle(f.value == nil ? Tokens.textSecondary : Tokens.lit).fixedSize(horizontal: false, vertical: true)
                        if let hint = f.hint { Text(hint).font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.lit).fixedSize(horizontal: false, vertical: true) }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .accessibilityElement(children: .combine)
                }
            }
            // "Down" over "tonight", as "34%" sits over "Sets 06:10": on one line it broke the word, "Down tonig" / "ht" (1.6.4).
            MoonTile(value: moon == .down ? "Down" : pct, line: moon.flatMap { $0 == .down ? "tonight" : Copy.moonText($0, site: site) }, at: moonAt, plain: true)
        }
    }

    /// How far through the night's hours the current time is, for the arc's "now" dot; nil outside them.
    private func nowFraction(_ plan: NightPlan) -> Double? {
        guard let first = plan.darkHours.first?.time else { return nil }
        let span = Double(plan.darkHours.count) * 3600, t = Date().timeIntervalSince(first)
        return t >= 0 && t <= span ? t / span : nil
    }

    /// A chip under the times when dew is likely to be a problem or the night drops to freezing; the Dew risk fact keeps the full words.
    private func dewWarning(_ plan: NightPlan) -> String? {
        if (plan.darkHours.compactMap(\.tempC).min().map { $0 <= 0 } ?? false) { return "Frost likely" }
        return Planner.dewRisk(plan.darkHours) == .high ? "High dew risk" : nil
    }

    /// Deep-sky picks on a dark night; the Moon and planets on a bright one.
    private func picks(_ plan: NightPlan) -> [RankedTarget] { plan.mode == .bright ? plan.brightTargets : plan.best }

    private func best(_ plan: NightPlan, _ site: Site) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(picks(plan).isEmpty ? "UP TONIGHT" : "BEST TONIGHT").capsLabel()
                Spacer()
                Button("All targets →") { open("targets") }
                    .buttonStyle(SecondaryButtonStyle())
                    .help("Open the Targets window: everything up tonight, with timelines, sorting and dark sites")
            }
            if plan.mode == .bright, plan.brightTargets.isEmpty {
                Text("No Moon or planet in a clear window tonight.").font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary)
            } else if plan.mode == .dark, plan.best.isEmpty {
                Text("\(plan.targets.count) objects above the horizon during darkness. No clear window, so nothing is recommended.")
                    .font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
            }
            HStack(alignment: .top, spacing: 8) {
                ForEach(picks(plan)) { t in
                    VStack(spacing: 0) {
                        ThumbnailView(target: t).frame(height: 70).clipped()
                        VStack(alignment: .leading, spacing: 2) {
                            Text(t.catalogueID).font(.system(size: TextScale.pt(12), weight: .heavy)).lineLimit(1).fixedSize(horizontal: false, vertical: true)
                            Text((t.commonName ?? t.typeName).uppercased()).font(.system(size: TextScale.pt(9), weight: .semibold)).tracking(1).foregroundStyle(Tokens.textSecondary).lineLimit(1)
                            Text("Best \(Copy.hhmm(t.peakTime, site: site)) · \(Int(t.peakAltDeg.rounded()))° up").font(.system(size: TextScale.pt(9.5), weight: .medium)).foregroundStyle(Tokens.lit)
                        }
                        .padding(8).frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.black.opacity(0.55))
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Tokens.glassEdge, lineWidth: 1))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// One centre line, evenly spread as on the large widget: the cloud source, the update time, "Refresh". The notify switch
    /// lives in Settings › Alerts (owner, 27 September 2026).
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let u = store.availableUpdate {
                HStack(spacing: 5) {
                    Circle().fill(Tokens.controlOn).frame(width: 6, height: 6).accessibilityHidden(true)
                    Text("Nightwatch \(u.version) is available").foregroundStyle(Tokens.textPrimary)
                    Link("Download ↗", destination: ReleaseCheck.latestPage).linkCursor()
                }
                .font(.system(size: TextScale.pt(10.5)))
            }
            HStack(alignment: .center, spacing: 0) {
                if let f = store.forecast, let s = store.site {
                    // The mark on the left: its weight looked odd in the middle (owner, 27 September 2026).
                    SourceBadge(forecast: f)
                    Spacer(minLength: 8)
                    HStack(spacing: 6) {
                        if store.isStale { StaleBadge(fetchedAt: f.fetchedAt) }
                        Text(store.isStale ? store.copy.offlineSince(Copy.clockTime(f.fetchedAt)) : "Updated \(Copy.clockTime(f.fetchedAt))")   // this Mac's clock
                            .font(.system(size: TextScale.pt(10))).foregroundStyle(Tokens.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                HStack(spacing: 6) {
                    if store.refreshing { ProgressView().controlSize(.small) }
                    Button(store.copy.refresh) { Task { await store.refresh(force: true) } }
                    .buttonStyle(SecondaryButtonStyle())
                    .help("Fetch the forecast now and recompute tonight")
                }
            }
        }.padding(.top, 4)
    }
}
