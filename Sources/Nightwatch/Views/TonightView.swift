import SwiftUI
import SkyCore

struct TonightView: View {
    @EnvironmentObject var store: Store
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if let plan = store.plan, let site = store.site {
                verdict(plan, site)
                ClearSkyBars(plan: plan, site: site, source: store.forecast?.cloudSource ?? "Open-Meteo")
                notice(site)
                tiles(plan, site)
                best(plan)
            } else {
                Text(store.lastError ?? "Waiting for the first forecast…").font(.callout).foregroundStyle(Theme.dim).padding(.vertical, 20)
            }
            footer
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 22, trailing: 16))   // extra at the foot: the window otherwise sits tight on the footer row
        .overlay(RoundedRectangle(cornerRadius: 13).stroke(Tokens.glassHairline, lineWidth: 1))
        .nightwatchGlass(in: RoundedRectangle(cornerRadius: 13))
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onAppear { Task { await store.refresh(force: false) } }   // cheap: the 30-minute cache gate decides whether to fetch
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TONIGHT · \(store.site?.name.uppercased() ?? "NO SITE")").font(.system(size: 11)).foregroundStyle(Tokens.textSecondary)
                if let s = store.site, let p = store.plan {
                    Text("\(p.night.key) · Bortle \(s.bortle) · EQ tilt \(String(format: "%.1f", abs(s.latitude)))° \(s.latitude >= 0 ? "true north" : "true south")" + (p.mode == .bright ? " · bright night" : ""))
                        .font(.system(size: 11)).foregroundStyle(Tokens.textSecondary)   // wedge angle = site latitude; the vendor app does the alignment
                }
            }
            Spacer()
            Button { open("settings") } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).foregroundStyle(Theme.dim)
        }
    }

    /// A menu-bar agent app is never the active app, so a window opened from the popover would land behind
    /// whatever the user is working in. Activate first so the window comes to the front.
    private func open(_ id: String) {
        openWindow(id: id)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// The plain reason under the no-window verdict: astronomical darkness and the go rule on a dark night,
    /// nautical darkness and the bright rule on a bright one.
    private func noWindowReason(_ plan: NightPlan, _ site: Site) -> String? {
        if plan.mode == .bright {
            guard let ns = plan.night.nauticalStart, let ne = plan.night.nauticalEnd else { return nil }
            let r = store.config.goRule
            return Planner.noWindowReason(darkHours: plan.darkHours, darkStart: ns, darkEnd: ne,
                                          rule: GoRule(minHours: store.config.brightNights.minHours, maxCloudPct: r.maxCloudPct, minAltitudeDeg: r.minAltitudeDeg),
                                          site: site, mode: .bright, brightTargetsUp: Planner.anyBrightTargetUp(from: ns, to: ne, site: site))
        }
        guard let ds = plan.night.darkStart, let de = plan.night.darkEnd else { return nil }
        return Planner.noWindowReason(darkHours: plan.darkHours, darkStart: ds, darkEnd: de, rule: store.config.goRule, site: site)
    }

    private func verdict(_ plan: NightPlan, _ site: Site) -> some View {
        HStack(alignment: .top, spacing: 14) {
            ScoreBezel(score: plan.score,
                       slots: Bezel.slots(darkness: plan.darkSpan, windows: plan.windows, primary: plan.primary, hours: plan.darkHours, site: site),
                       label: Copy.bezelLabel(plan, site: site))
            VStack(alignment: .leading, spacing: 4) {
                if let w = plan.primary {
                    Text(plan.mode == .bright ? "Bright night: Moon and planets" : "Clear window tonight").font(.system(size: 15, weight: .medium))
                    Text("\(Copy.hhmm(w.start, site: site)) → \(Copy.hhmm(w.end, site: site)) · \(String(format: "%.1f h", w.hours))").font(.system(size: 13))
                    if plan.mode == .bright {
                        Text(Copy.brightList(plan.brightTargets)).font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
                    }
                    if let why = Copy.heldBack(plan.limiting) {
                        HStack(spacing: 5) { WarningDot(size: 4.5); Text(why) }
                            .font(.system(size: 10)).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    Text("Notify at \(Copy.hhmm(w.start.addingTimeInterval(-Double(store.config.alerts.preWindowMinutes) * 60), site: site))")
                        .font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)   // moves into the footer toggle in Task 5
                } else if !plan.night.hasDarkness && (plan.mode == .dark || !plan.night.hasNauticalDarkness) {
                    Text("No astronomical darkness").font(.system(size: 15, weight: .medium))
                    Text("Too far north or south for this date.").font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
                } else {
                    Text(store.copy.noWindow).font(.system(size: 15, weight: .medium)).fixedSize(horizontal: false, vertical: true)
                    if let why = noWindowReason(plan, site) {
                        Text(why).font(.system(size: 10)).foregroundStyle(Tokens.textSecondary).fixedSize(horizontal: false, vertical: true)
                    }
                    if let t = store.tomorrow, let w = t.primary {
                        Text("Tomorrow: \(Copy.hhmm(w.start, site: site)) → \(Copy.hhmm(w.end, site: site))").font(.system(size: 10)).foregroundStyle(Tokens.textSecondary)
                    }
                }
            }
        }
    }

    /// Severity in the app's night-safe palette (never green): green dim, yellow warn, amber and red accent.
    private func auroraColour(_ l: AuroraLevel) -> Color {
        switch l { case .green: Theme.dim; case .yellow: Theme.warn; case .amber, .red: Theme.accent }
    }

    /// At most one line under the bars: aurora first, then the Clearer sky line (spec §5.1).
    /// The aurora line needs AuroraWatch UK to have published within the hour: its `updated` time moves on every
    /// publication (live: 20:33:32Z then 20:39:31Z, both green), so an older status is stale.
    @ViewBuilder private func notice(_ site: Site) -> some View {
        if store.config.aurora.enabled, let a = store.aurora, a.level >= store.config.aurora.threshold, Date().timeIntervalSince(a.updated) < 3600 {
            Text("Aurora: \(a.level.rawValue) (AuroraWatch UK)").font(.system(size: 10)).foregroundStyle(auroraColour(a.level))
        } else if let a = store.bestAway, let w = a.primary {
            Button {
                store.targetsRequest = TargetsRequest(section: .darkSites, siteID: a.site.id)
                open("targets")
            } label: {
                Text("Clearer sky \(Geo.format(km: a.site.distanceKm, unit: store.distanceUnit)) \(a.site.compass): \(a.site.name)\(a.site.band.map { " (\($0.displayName))" } ?? ""), clear \(Copy.hhmm(w.start, site: site))–\(Copy.hhmm(w.end, site: site)) →")
                    .font(.system(size: 10)).foregroundStyle(Tokens.textPrimary).multilineTextAlignment(.leading)
            }.buttonStyle(.plain)   // a link, so text.primary: red means clear sky only
        }
    }

    private func tiles(_ plan: NightPlan, _ site: Site) -> some View {
        let dark = plan.darkSpan.map { "\(Copy.hhmm($0.start, site: site))–\(Copy.hhmm($0.end, site: site))" } ?? "None"
        let moon = Planner.moonTonight(plan)
        let pct = "\(Int((plan.moonIllumination * 100).rounded()))%"
        let seeing = plan.darkHours.compactMap(\.seeing)
        let seeingText = seeing.isEmpty ? nil : ["", "<0.5″", "0.5–0.75″", "0.75–1″", "1–1.25″", "1.25–1.5″", "1.5–2″", "2–2.5″", ">2.5″"][min(8, seeing.reduce(0, +) / seeing.count)]
        let wind = plan.darkHours.compactMap(\.windKmh)
        let windText = wind.isEmpty ? nil : String(format: "%.0f km/h", wind.reduce(0, +) / Double(wind.count))
        let dew = Planner.dewRisk(plan.darkHours)
        let frost = plan.darkHours.compactMap(\.tempC).min().map { $0 <= 0 } ?? false
        let transp = plan.darkHours.compactMap(\.transparency)
        let transpText = transp.isEmpty ? nil : (transp.reduce(0, +) / transp.count <= 3 ? "Good" : "Average")
        let moonAt = plan.primary?.midpoint ?? plan.night.darkStart ?? plan.night.sunset
        return GlassGroup(spacing: 8.5) {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8.5), count: 3), spacing: 8.5) {
                StatTile(label: "Dark", value: dark)
                MoonTile(value: moon == .down ? "Down tonight" : pct, line: moon.flatMap { $0 == .down ? nil : Copy.moonText($0, site: site) }, at: moonAt)
                StatTile(label: "Seeing", value: seeingText)
                StatTile(label: "Wind", value: windText)
                StatTile(label: frost ? "Frost likely" : "Dew risk", value: dew?.displayName,
                         hint: dew == .high ? "Dew heater advised" : nil, warning: dew == .high)
                StatTile(label: "Transparency", value: transpText)
            }
        }
    }

    /// Deep-sky picks on a dark night; the Moon and planets on a bright one.
    private func picks(_ plan: NightPlan) -> [RankedTarget] { plan.mode == .bright ? plan.brightTargets : plan.best }

    private func best(_ plan: NightPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(picks(plan).isEmpty ? "UP TONIGHT" : "BEST TONIGHT").font(.caption).foregroundStyle(Theme.dim)
                Spacer()
                Button("All targets →") { open("targets") }.buttonStyle(.plain).font(.caption).foregroundStyle(Theme.accent)
            }
            if plan.mode == .bright, plan.brightTargets.isEmpty {
                Text("No Moon or planet in a clear window tonight.").font(.caption).foregroundStyle(Theme.dim)
            } else if plan.mode == .dark, plan.best.isEmpty {
                Text("\(plan.targets.count) objects above the horizon during darkness. No clear window, so nothing is recommended.")
                    .font(.caption).foregroundStyle(Theme.dim)
            }
            HStack(spacing: 8) {
                ForEach(picks(plan)) { t in
                    VStack(alignment: .leading, spacing: 6) {
                        ThumbnailView(target: t).frame(height: 64)
                        Text(t.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(t.group.displayName).font(.caption2).foregroundStyle(Theme.dim)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    /// Which service supplied the cloud hours. Apple requires its mark and legal link wherever WeatherKit data is shown.
    private func sourceBadge(_ f: Forecast) -> some View {
        HStack(spacing: 4) {
            if let m = f.attributionMarkURL, let url = URL(string: m) {
                AsyncImage(url: url) { $0.resizable().scaledToFit() } placeholder: { EmptyView() }.frame(height: 10)
            }
            if let l = f.attributionLegalURL, let url = URL(string: l) {
                Link("Apple Weather", destination: url).font(.caption2).foregroundStyle(Theme.dim)
            } else {
                Text(f.cloudSource ?? "Open-Meteo").font(.caption2).foregroundStyle(Theme.dim)
            }
        }
    }

    /// Two rows so the checkbox label never truncates: controls on the first, provenance on the second.
    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Toggle(isOn: Binding(get: { store.config.notifyEnabled }, set: { store.config.notifyEnabled = $0; store.saveConfig() })) {
                    Text("Notify when clear").font(.callout)
                }.toggleStyle(.checkbox).fixedSize()
                Spacer()
                if store.refreshing { ProgressView().controlSize(.small) }
                Button(store.copy.refresh) { Task { await store.refresh(force: true) } }.font(.caption)
            }
            if let f = store.forecast, let s = store.site {
                HStack(spacing: 6) {
                    Text(store.isStale ? store.copy.offlineSince(Copy.hhmm(f.fetchedAt, site: s)) : "Updated \(Copy.hhmm(f.fetchedAt, site: s))")
                        .font(.caption).foregroundStyle(store.isStale ? Theme.warn : Theme.dim)
                    Text("·").font(.caption).foregroundStyle(Theme.dim)
                    sourceBadge(f)
                }
            }
        }.padding(.top, 4)
    }
}
