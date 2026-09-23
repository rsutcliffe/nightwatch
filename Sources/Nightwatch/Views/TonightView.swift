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
                cloudStrip(plan)
                tiles(plan, site)
                best(plan)
            } else {
                Text(store.lastError ?? "Waiting for the first forecast…").font(.callout).foregroundStyle(Theme.dim).padding(.vertical, 20)
            }
            footer
        }
        .padding(16)
        .background(Theme.bg)
        .foregroundStyle(Theme.text)
        .preferredColorScheme(.dark)
        .onAppear { Task { await store.refresh(force: false) } }   // cheap: the 30-minute cache gate decides whether to fetch
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TONIGHT · \(store.site?.name.uppercased() ?? "NO SITE")").font(.caption).foregroundStyle(Theme.dim)
                if let s = store.site, let p = store.plan {
                    Text("\(p.night.key) · Bortle \(s.bortle)").font(.caption).foregroundStyle(Theme.dim)
                }
            }
            Spacer()
            Button { openWindow(id: "settings") } label: { Image(systemName: "gearshape") }.buttonStyle(.plain).foregroundStyle(Theme.dim)
        }
    }

    private func verdict(_ plan: NightPlan, _ site: Site) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Theme.line, lineWidth: 7)
                Circle().trim(from: 0, to: Double(plan.score) / 100).stroke(Theme.accent, style: StrokeStyle(lineWidth: 7, lineCap: .round)).rotationEffect(.degrees(-90))
                Text("\(plan.score)").font(.system(size: 24, weight: .semibold))
            }.frame(width: 84, height: 84)
            VStack(alignment: .leading, spacing: 4) {
                if let w = plan.primary {
                    Text("Clear window tonight").font(.title3.weight(.semibold))
                    Text("\(Copy.hhmm(w.start, site: site)) → \(Copy.hhmm(w.end, site: site)) · \(String(format: "%.1f h", w.hours))").foregroundStyle(Theme.text)
                    Text("Notify at \(Copy.hhmm(w.start.addingTimeInterval(-Double(store.config.alerts.preWindowMinutes) * 60), site: site))").font(.caption).foregroundStyle(Theme.dim)
                } else if !plan.night.hasDarkness {
                    Text("No astronomical darkness").font(.title3.weight(.semibold))
                    Text("Too far north or south for this date.").font(.caption).foregroundStyle(Theme.dim)
                } else {
                    Text(store.copy.noWindow).font(.title3.weight(.semibold))
                    if let t = store.tomorrow, let w = t.primary {
                        Text("Tomorrow: \(Copy.hhmm(w.start, site: site)) → \(Copy.hhmm(w.end, site: site))").font(.caption).foregroundStyle(Theme.dim)
                    }
                }
            }
        }
    }

    private func cloudStrip(_ plan: NightPlan) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(plan.darkHours, id: \.time) { h in
                    let clear = h.cloudTotal <= store.config.goRule.maxCloudPct
                    RoundedRectangle(cornerRadius: 2)
                        .fill(clear ? Theme.accent : Theme.line)
                        .frame(height: max(3, CGFloat(h.cloudTotal) * 0.4))
                        .frame(maxWidth: .infinity)
                }
            }.frame(height: 44, alignment: .bottom)
            HStack {
                if let f = plan.darkHours.first, let l = plan.darkHours.last, let s = store.site {
                    Text(Copy.hhmm(f.time, site: s)); Spacer(); Text(Copy.hhmm(l.time, site: s))
                }
            }.font(.caption2).foregroundStyle(Theme.dim)
            Text("Cloud cover during darkness · bar height = % cloud · Open-Meteo").font(.caption2).foregroundStyle(Theme.dim)
        }
    }

    private func tile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption2).foregroundStyle(Theme.dim)
            Text(value).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
        }.padding(10).frame(maxWidth: .infinity, alignment: .leading).background(Theme.card).clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func tiles(_ plan: NightPlan, _ site: Site) -> some View {
        let dark: String = {
            if let ds = plan.night.darkStart, let de = plan.night.darkEnd {
                return "\(Copy.hhmm(ds, site: site))–\(Copy.hhmm(de, site: site))"
            }
            return "none"
        }()
        let moon = "\(Int((plan.moonIllumination * 100).rounded()))%" + (plan.moonSet.map { " · sets \(Copy.hhmm($0, site: site))" } ?? "")
        let seeing = plan.darkHours.compactMap(\.seeing)
        let seeingText = seeing.isEmpty ? "n/a" : ["", "<0.5″", "0.5–0.75″", "0.75–1″", "1–1.25″", "1.25–1.5″", "1.5–2″", "2–2.5″", ">2.5″"][min(8, seeing.reduce(0, +) / seeing.count)]
        let wind = plan.darkHours.compactMap(\.windKmh)
        let windText = wind.isEmpty ? "n/a" : String(format: "%.0f km/h", wind.reduce(0, +) / Double(wind.count))
        let spread = plan.darkHours.compactMap { h -> Double? in guard let t = h.tempC, let d = h.dewPointC else { return nil }; return t - d }.min()
        let dewText = spread.map { $0 < 2 ? "High" : ($0 < 4 ? "Medium" : "Low") } ?? "n/a"
        let frost = plan.darkHours.compactMap(\.tempC).min().map { $0 <= 0 } ?? false
        let transp = plan.darkHours.compactMap(\.transparency)
        let transpText = transp.isEmpty ? "n/a" : (transp.reduce(0, +) / transp.count <= 3 ? "Good" : "Average")
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
            tile("Dark", dark); tile("Moon", moon); tile("Seeing", seeingText)
            tile("Wind", windText); tile(frost ? "Frost likely" : "Dew risk", dewText); tile("Transparency", transpText)
        }
    }

    private func best(_ plan: NightPlan) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("BEST TONIGHT").font(.caption).foregroundStyle(Theme.dim)
                Spacer()
                Button("All targets →") { openWindow(id: "targets") }.buttonStyle(.plain).font(.caption).foregroundStyle(Theme.accent)
            }
            HStack(spacing: 8) {
                ForEach(plan.best) { t in
                    VStack(alignment: .leading, spacing: 6) {
                        ThumbnailView(target: t).frame(height: 64)
                        Text(t.name).font(.caption.weight(.semibold)).lineLimit(1)
                        Text(t.group.displayName).font(.caption2).foregroundStyle(Theme.dim)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Toggle(isOn: Binding(get: { store.config.notifyEnabled }, set: { store.config.notifyEnabled = $0; store.saveConfig() })) {
                Text("Notify when clear").font(.callout)
            }.toggleStyle(.checkbox)
            Spacer()
            if store.refreshing { ProgressView().controlSize(.small) }
            else if let f = store.forecast, let s = store.site {
                Text(store.isStale ? store.copy.offlineSince(Copy.hhmm(f.fetchedAt, site: s)) : "Updated \(Copy.hhmm(f.fetchedAt, site: s))")
                    .font(.caption).foregroundStyle(store.isStale ? Theme.warn : Theme.dim)
            }
            Button(store.copy.refresh) { Task { await store.refresh(force: true) } }.font(.caption)
        }.padding(.top, 4)
    }
}
