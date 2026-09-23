import SwiftUI
import ServiceManagement
import SkyCore

final class SettingsViewState: ObservableObject {
    @Published var presets: [TelescopePreset] = (try? TelescopePresets.bundled()) ?? []
    @Published var newSite = Site(name: "", latitude: 0, longitude: 0, elevationM: 0, timeZoneID: TimeZone.current.identifier, bortle: 5)
    @Published var loginStatus = ""
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @StateObject private var ui = SettingsViewState()

    var body: some View {
        Form {
            Section(store.copy.siteNoun + "s") {
                Picker("Active", selection: Binding(get: { store.config.activeSiteName ?? "" }, set: { store.config.activeSiteName = $0.isEmpty ? nil : $0; store.saveConfig() })) {
                    Text("Automatic (location)").tag("")
                    ForEach(store.config.sites, id: \.name) { Text($0.name).tag($0.name) }
                }
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
                HStack {
                    TextField("Name", text: $ui.newSite.name)
                    TextField("Lat", value: $ui.newSite.latitude, format: .number).frame(width: 70)
                    TextField("Lon", value: $ui.newSite.longitude, format: .number).frame(width: 70)
                    Stepper("Bortle \(ui.newSite.bortle)", value: $ui.newSite.bortle, in: 1...9).frame(width: 110)
                    Button("Add") {
                        ui.newSite.name = ui.newSite.name.trimmingCharacters(in: .whitespaces)
                        store.config.sites.append(ui.newSite); store.saveConfig(); ui.newSite.name = ""
                    }.disabled(ui.newSite.name.trimmingCharacters(in: .whitespaces).isEmpty || nameTaken)
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
                    TextField("Width °", value: Binding(get: { store.config.fov.widthDeg }, set: { store.config.fov.widthDeg = $0; store.config.fovPresetID = nil; store.saveConfig() }), format: .number)
                    TextField("Height °", value: Binding(get: { store.config.fov.heightDeg }, set: { store.config.fov.heightDeg = $0; store.config.fovPresetID = nil; store.saveConfig() }), format: .number)
                }
            }
            Section("Go rule") {
                Stepper("At least \(String(format: "%.0f", store.config.goRule.minHours)) h clear", value: Binding(get: { store.config.goRule.minHours }, set: { store.config.goRule.minHours = $0; store.saveConfig() }), in: 1...8)
                Stepper("Cloud at most \(store.config.goRule.maxCloudPct)%", value: Binding(get: { store.config.goRule.maxCloudPct }, set: { store.config.goRule.maxCloudPct = $0; store.saveConfig() }), in: 5...60, step: 5)
                Stepper("Targets above \(Int(store.config.goRule.minAltitudeDeg))°", value: Binding(get: { store.config.goRule.minAltitudeDeg }, set: { store.config.goRule.minAltitudeDeg = $0; store.saveConfig() }), in: 10...60, step: 5)
            }
            Section("Alerts") {
                Toggle("Evening heads-up (one hour before sunset)", isOn: bind(\.alerts.headsUp))
                Toggle("Tomorrow preview when tonight is out", isOn: bind(\.alerts.tomorrowPreview))
                Stepper("Nudge \(store.config.alerts.preWindowMinutes) min before the window", value: bind(\.alerts.preWindowMinutes), in: 0...120, step: 15)
                Toggle("Cancel notice if the forecast turns", isOn: bind(\.alerts.cancelOnDowngrade))
                HStack {
                    Stepper("Quiet from \(store.config.alerts.quietStartHour):00", value: bind(\.alerts.quietStartHour), in: 0...23)
                    Stepper("to \(store.config.alerts.quietEndHour):00", value: bind(\.alerts.quietEndHour), in: 0...23)
                }
            }
            Section("App") {
                Picker("Wording", selection: bind(\.flavour)) { Text("Nightwatch").tag(Flavour.watch); Text("Plain").tag(Flavour.plain) }
                Toggle("Start at login", isOn: Binding(get: { store.config.loginItem }, set: { on in
                    do { if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }; store.config.loginItem = on; store.saveConfig() }
                    catch { ui.loginStatus = error.localizedDescription }
                    if SMAppService.mainApp.status == .requiresApproval { ui.loginStatus = "Approve Nightwatch under System Settings › General › Login Items." }
                }))
                if !ui.loginStatus.isEmpty { Text(ui.loginStatus).font(.caption).foregroundStyle(Theme.warn) }
                LabeledContent("Config file") { Text(ConfigStore.defaultURL.path).font(.caption).textSelection(.enabled) }
                Text("Symlink that file into iCloud Drive or any synced folder to share settings across Macs.").font(.caption).foregroundStyle(Theme.dim)
            }
        }
        .formStyle(.grouped)
        .preferredColorScheme(.dark)
    }

    private var nameTaken: Bool {
        store.config.sites.contains { $0.name.caseInsensitiveCompare(ui.newSite.name) == .orderedSame }
    }

    private func bind<T>(_ path: WritableKeyPath<Config, T>) -> Binding<T> {
        Binding(get: { store.config[keyPath: path] }, set: { store.config[keyPath: path] = $0; store.saveConfig() })
    }
}
