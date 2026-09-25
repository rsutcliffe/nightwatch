import SwiftUI
import ServiceManagement
import SkyCore

final class SettingsViewState: ObservableObject {
    @Published var presets: [TelescopePreset] = (try? TelescopePresets.bundled()) ?? []
    @Published var newSite = Site(name: "", latitude: 0, longitude: 0, elevationM: 0, timeZoneID: TimeZone.current.identifier, bortle: 5)
    @Published var loginStatus = ""
    @Published var confirmReset = false
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var ui = SettingsViewState()

    var body: some View {
        Form {
            Section(store.copy.siteNoun + "s") {
                Picker("Observe from", selection: Binding(get: { store.config.activeSiteName ?? "" }, set: { store.config.activeSiteName = $0.isEmpty ? nil : $0; store.saveConfig() })) {
                    Text("Automatic (this Mac's location)").tag("")
                    ForEach(store.config.sites, id: \.name) { Text($0.name).tag($0.name) }
                }
                Text(automaticStatus).font(.caption).foregroundStyle(Theme.dim)
                ForEach(store.config.sites, id: \.name) { s in
                    HStack {
                        Text(s.name); Spacer()
                        Text(String(format: "%.3f, %.3f · Bortle %d", s.latitude, s.longitude, s.bortle)).foregroundStyle(Theme.dim).font(.caption)
                        Button(role: .destructive) {
                            store.config.sites.removeAll { $0.name == s.name }
                            if store.config.activeSiteName == s.name { store.config.activeSiteName = nil }
                            store.saveConfig()
                        } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain).foregroundStyle(Theme.dim).help("Remove \(s.name)")
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Add a place to observe from. Latitude and longitude in decimal degrees, north and east positive; Sheffield is 53.381, −1.470. Then choose it under Observe from.")
                        .font(.caption).foregroundStyle(Theme.dim)
                    HStack {
                        TextField("Name (e.g. Back garden)", text: $ui.newSite.name)
                        TextField("Latitude", value: $ui.newSite.latitude, format: .number.precision(.fractionLength(0...4))).frame(width: 90)
                        TextField("Longitude", value: $ui.newSite.longitude, format: .number.precision(.fractionLength(0...4))).frame(width: 90)
                        Button("Use this Mac's location") {
                            if let a = store.autoSite { ui.newSite.latitude = a.latitude; ui.newSite.longitude = a.longitude; ui.newSite.elevationM = a.elevationM }
                        }.disabled(store.autoSite == nil).help(store.autoSite == nil ? "Location Services has not given Nightwatch a fix yet" : "Copy the current coordinates into the fields")
                    }
                    HStack {
                        Text("Sky darkness (Bortle class)")
                        Spacer()
                        Stepper("\(ui.newSite.bortle)", value: $ui.newSite.bortle, in: 1...9).frame(width: 64)
                        Button("Add") {
                            ui.newSite.name = ui.newSite.name.trimmingCharacters(in: .whitespaces)
                            store.config.sites.append(ui.newSite); store.saveConfig(); ui.newSite.name = ""
                        }.disabled(ui.newSite.name.trimmingCharacters(in: .whitespaces).isEmpty || nameTaken)
                    }
                    Text("Bortle class grades light pollution from 1 (pristine dark sky) through 4 (rural or suburban) to 9 (inner city). It is shown in the popover header; it does not change the forecast.")
                        .font(.caption).foregroundStyle(Theme.dim)
                }
            }
            Section("Field of view") {
                Picker("Preset", selection: Binding(get: { store.config.fovPresetID ?? "custom" }, set: { id in
                    store.config.fovPresetID = id == "custom" ? nil : id
                    if let p = ui.presets.first(where: { $0.id == id }) { store.config.fov = p.fov }
                    store.saveConfig()
                })) {
                    ForEach(ui.presets) { Text($0.name).tag($0.id) }
                    Text("Custom").tag("custom")
                }
                HStack {
                    TextField("Width °", value: Binding(get: { store.config.fov.widthDeg }, set: { store.config.fov.widthDeg = max(0.05, $0); store.config.fovPresetID = nil; store.saveConfig() }), format: .number)
                    TextField("Height °", value: Binding(get: { store.config.fov.heightDeg }, set: { store.config.fov.heightDeg = max(0.05, $0); store.config.fovPresetID = nil; store.saveConfig() }), format: .number)
                }
            }
            Section("Go rule") {
                Text("A night qualifies when there is one unbroken run of clear hours inside astronomical darkness that meets all three.")
                    .font(.caption).foregroundStyle(Theme.dim)
                stepperRow("Clear for at least", value: String(format: "%.0f h", store.config.goRule.minHours),
                           binding: Binding(get: { store.config.goRule.minHours }, set: { store.config.goRule.minHours = $0; store.saveConfig() }), range: 1...8, step: 1)
                stepperRow("Cloud cover at most", value: "\(store.config.goRule.maxCloudPct) %",
                           binding: Binding(get: { store.config.goRule.maxCloudPct }, set: { store.config.goRule.maxCloudPct = $0; store.saveConfig() }), range: 5...60, step: 5)
                stepperRow("Targets must reach", value: "\(Int(store.config.goRule.minAltitudeDeg))° altitude",
                           binding: Binding(get: { store.config.goRule.minAltitudeDeg }, set: { store.config.goRule.minAltitudeDeg = $0; store.saveConfig() }), range: 10...60, step: 5)
            }
            Section("Alerts") {
                Toggle("Evening heads-up (one hour before sunset)", isOn: bind(\.alerts.headsUp))
                Toggle("Tomorrow preview when tonight is out", isOn: bind(\.alerts.tomorrowPreview))
                stepperRow("Nudge before the window opens", value: "\(store.config.alerts.preWindowMinutes) min",
                           binding: bind(\.alerts.preWindowMinutes), range: 0...120, step: 15)
                Toggle("Cancel notice if the forecast turns", isOn: bind(\.alerts.cancelOnDowngrade))
                // Keyed on the build's source, not on one fetch: a single failed Open-Meteo call must not grey it out, and a
                // switch that is on can always be turned off.
                let signed = store.forecast?.cloudSource == "Apple Weather"
                Toggle("Alert only when Open-Meteo agrees", isOn: bind(\.alerts.requireAgreement))
                    .disabled(!signed && !store.config.alerts.requireAgreement)
                if !signed {
                    Text("Needs Apple Weather (signed build)").font(.caption).foregroundStyle(Theme.dim)
                }
                stepperRow("Quiet hours start", value: String(format: "%02d:00", store.config.alerts.quietStartHour),
                           binding: bind(\.alerts.quietStartHour), range: 0...23, step: 1)
                stepperRow("Quiet hours end", value: String(format: "%02d:00", store.config.alerts.quietEndHour),
                           binding: bind(\.alerts.quietEndHour), range: 0...23, step: 1)
                Text("No banners between those hours; the popover still shows what was missed.").font(.caption).foregroundStyle(Theme.dim)
            }
            Section("Dark sites") {
                Toggle("Look for darker skies nearby", isOn: bind(\.darkSites.enabled))
                Picker("Distance unit", selection: bind(\.darkSites.unit)) { Text("Kilometres").tag(DistanceUnit.km); Text("Miles").tag(DistanceUnit.mi) }
                stepperRow("Search radius", value: Geo.format(km: store.config.darkSites.radiusKm, unit: store.config.darkSites.unit),
                           binding: bind(\.darkSites.radiusKm), range: 5...300, step: 5)
                Text("Certified places plus the darkest spots on the bundled light-pollution grid. Tonight's forecast is fetched for the nearest eight.").font(.caption).foregroundStyle(Theme.dim)
            }
            Section("Bright nights") {
                Toggle("Moon and planets when there is no proper darkness", isOn: bind(\.brightNights.enabled))
                stepperRow("Minimum clear run", value: String(format: "%.1f h", store.config.brightNights.minHours),
                           binding: bind(\.brightNights.minHours), range: 1...6, step: 0.5)
                Text("Applies only on nights when the dark rule above cannot be met, from about early May to early August at British latitudes. The Moon or a planet must stand 15° up in a clear stretch of nautical darkness. Deep-sky targets are never suggested on a bright night.").font(.caption).foregroundStyle(Theme.dim)
            }
            Section("Aurora") {
                Toggle("Alert me to aurora when the sky is clear", isOn: bind(\.aurora.enabled))
                Picker("Alert from", selection: bind(\.aurora.threshold)) {
                    ForEach([AuroraLevel.yellow, .amber, .red], id: \.self) { Text($0.displayName).tag($0) }
                }
                Text("Status from AuroraWatch UK (Lancaster University), checked every 5 minutes after dark. An alert needs the Sun 12° down and this hour's forecast cloud under your limit. Quiet hours apply.").font(.caption).foregroundStyle(Theme.dim)
            }
            Section("App") {
                Picker("Wording", selection: bind(\.flavour)) { Text("Nightwatch").tag(Flavour.watch); Text("Plain").tag(Flavour.plain) }
                // Reads the live login-item status (the user can remove it in System Settings); config.loginItem only records the choice.
                Toggle("Start at login", isOn: Binding(get: { SMAppService.mainApp.status == .enabled }, set: { on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; store.config.loginItem = on; store.saveConfig() }
                    catch { ui.loginStatus = error.localizedDescription }
                    if SMAppService.mainApp.status == .requiresApproval { ui.loginStatus = "Approve Nightwatch under System Settings › General › Login Items." }
                }))
                if !ui.loginStatus.isEmpty { Text(ui.loginStatus).font(.caption).foregroundStyle(Theme.warn) }
                LabeledContent("Config file") { Text(ConfigStore.defaultURL.path).font(.caption).textSelection(.enabled) }
                Text("Symlink that file into iCloud Drive or any synced folder to share settings across Macs.").font(.caption).foregroundStyle(Theme.dim)
                if store.configLoadFailed {
                    Text("The config file could not be read, so changes are not being saved. A copy is at config.json.bad. Fix the file, or reset to defaults.").font(.caption).foregroundStyle(Theme.warn)
                }
                Button("Reset config", role: .destructive) { ui.confirmReset = true }
                    .confirmationDialog("Replace the config file with defaults? Sites and settings will be lost.", isPresented: $ui.confirmReset) {
                        Button("Reset config", role: .destructive) { store.resetConfig() }
                    }
            }
        }
        .formStyle(.grouped)
        .preferredColorScheme(.dark)
        .tint(Tokens.controlOn)
    }

    /// Label on the left, the current value right beside the up/down buttons so it is obvious what they change.
    private func stepperRow<V: Strideable>(_ label: String, value: String, binding: Binding<V>, range: ClosedRange<V>, step: V.Stride) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: binding, in: range, step: step) { Text(value).font(.body.weight(.semibold)).monospacedDigit() }
        }
    }

    private var automaticStatus: String {
        if let a = store.autoSite {
            return String(format: "Automatic is using this Mac's location: %.3f, %.3f.", a.latitude, a.longitude)
        }
        return "Automatic needs Location Services permission for Nightwatch (System Settings › Privacy & Security › Location Services). Until then, add a place below and choose it."
    }

    private var nameTaken: Bool {
        let trimmed = ui.newSite.name.trimmingCharacters(in: .whitespaces)
        return store.config.sites.contains { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    private func bind<T>(_ path: WritableKeyPath<Config, T>) -> Binding<T> {
        Binding(get: { store.config[keyPath: path] }, set: { store.config[keyPath: path] = $0; store.saveConfig() })
    }
}
