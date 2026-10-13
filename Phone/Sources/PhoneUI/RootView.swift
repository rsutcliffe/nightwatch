import SwiftUI
import SkyCore
import PhoneCore

/// The whole app: first run until a site exists, then Tonight with a sites sheet and settings. Red night mode is per device.
public struct RootView: View {
    @ObservedObject var store: PhoneStore
    @ObservedObject var connectivity: ConnectivityMonitor
    @StateObject private var permission = NotificationPermission()
    @AppStorage("redNightMode") private var red = false
    @Environment(\.scenePhase) private var scenePhase
    @State private var showSites = false
    @State private var showSettings = false

    public init(store: PhoneStore, connectivity: ConnectivityMonitor) { self.store = store; self.connectivity = connectivity }

    private func refresh(force: Bool = false) { Task { await store.refresh(force: force, connectivity: connectivity.current) } }

    public var body: some View {
        let theme = PhoneTheme.named(red: red)
        NavigationStack {
            Group {
                switch store.phase {
                case .needsSite: FirstRunScreen(store: store)
                case .loading: VStack { WaitingText(text: "Reading tonight's forecast") }.frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let why):
                    EmptyState(title: "No forecast yet", message: why, action: ("Try again", { refresh(force: true) }))
                case .ready:
                    if let m = store.tonight {
                        TonightScreen(model: m, markData: store.appleMarkData, offline: store.offline, refreshing: store.refreshing,
                                      onRefresh: { refresh(force: true) },
                                      alertsPrompt: AlertsPrompt(permission: permission, onGranted: { refresh(force: true) }))
                    }
                }
            }
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                // A drawn title, not .navigationTitle: the system title ignores the red palette.
                ToolbarItem(placement: .principal) {
                    Text(store.site?.name ?? "Nightwatch").font(.headline).foregroundStyle(theme.textPrimary)
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button { red.toggle() } label: { Image(systemName: red ? "moon.fill" : "moon") }
                        .accessibilityLabel("Red night mode")
                        .sensoryFeedback(.selection, trigger: red)
                    if store.phase != .needsSite {
                        Button { showSites = true } label: { Image(systemName: "mappin.and.ellipse") }.accessibilityLabel("Sites")
                    }
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showSites) { SitesSheet(store: store).phoneTheme(theme) }
        .sheet(isPresented: $showSettings) { SettingsScreen(store: store, red: $red, permission: permission).phoneTheme(theme) }
        .phoneTheme(theme)
        .task { refresh() }
        .onChange(of: scenePhase) { _, p in if p == .active { refresh(); Task { await permission.refresh() } } }
        .onChange(of: connectivity.current.isOnline) { _, on in if on { refresh() } }
    }
}

extension View {
    func navigationBarTitleDisplayModeInline() -> some View {
        #if os(iOS)
        navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

/// Where do you observe from? Shown until the first site exists (sites arriving from the Mac's iCloud settings skip it).
struct FirstRunScreen: View {
    @ObservedObject var store: PhoneStore
    @StateObject private var location = LocationProvider()
    @State private var name = ""
    @State private var message: String?
    @State private var busy = false
    @Environment(\.phoneTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Is tonight a night to observe?").font(.title2.weight(.medium)).multilineTextAlignment(.center)
            Text("Nightwatch reads the sky forecast and tells you, then alerts you. Where do you observe from?")
                .font(.callout).secondary().multilineTextAlignment(.center)
            TextField("A place name", text: $name).textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit(add)
            if let message { Text(message).font(.footnote).foregroundStyle(theme.warning) }
            Spacer()
            SecondaryButton(title: "Use this device's location", systemImage: "location") { useLocation() }
            PrimaryButton(title: busy ? "Searching" : "Add this place", action: add)
        }
        .padding(20).frame(maxWidth: 520)
    }

    private func add() {
        guard !name.isEmpty, !busy else { return }
        busy = true; message = nil
        Task {
            if let s = await PlaceSearch.find(name) { store.addSite(s) } else { message = "Could not find that place." }
            busy = false
        }
    }

    private func useLocation() {
        Task {
            do { store.addSite(try await location.currentSite()) } catch { message = "Location is not available. Type a place name instead." }
        }
    }
}

struct SitesSheet: View {
    @ObservedObject var store: PhoneStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Your sites") {
                    ForEach(store.config.sites, id: \.name) { s in
                        Button { store.selectSite(s); dismiss() } label: {
                            HStack { Text(s.name); Spacer(); if s.name == store.site?.name { Image(systemName: "checkmark") } }
                        }
                    }
                    .onDelete { store.removeSites(at: $0) }
                }
                Section("Add a site") {
                    TextField("A place name", text: $name).submitLabel(.search).onSubmit {
                        Task { if let s = await PlaceSearch.find(name) { store.addSite(s); name = "" } else { message = "Could not find that place." } }
                    }
                    if let message { Text(message).font(.footnote) }
                }
            }
            .navigationTitle("Sites")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct SettingsScreen: View {
    @ObservedObject var store: PhoneStore
    @Binding var red: Bool
    @ObservedObject var permission: NotificationPermission
    @Environment(\.dismiss) private var dismiss

    private func binding<T>(_ kp: WritableKeyPath<AlertSettings, T>) -> Binding<T> {
        Binding(get: { store.config.alerts[keyPath: kp] }, set: { store.config.alerts[keyPath: kp] = $0; store.saveConfig() })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if permission.status == .denied {
                        Text("Alerts are off for Nightwatch in iOS Settings, Notifications.").font(.footnote)
                    }
                    Toggle("Heads-up before sunset", isOn: binding(\.headsUp))
                    Toggle("Tomorrow preview", isOn: binding(\.tomorrowPreview))
                    Toggle("Cancel if the forecast worsens", isOn: binding(\.cancelOnDowngrade))
                    Stepper("Quiet from \(store.config.alerts.quietStartHour):00", value: binding(\.quietStartHour), in: 0...23)
                    Stepper("Quiet until \(store.config.alerts.quietEndHour):00", value: binding(\.quietEndHour), in: 0...23)
                } header: { Text("Alerts") } footer: {
                    Text("An alert is only sent from a forecast under six hours old. If you have not opened the app for a while, an alert may wait until the next refresh. iOS decides when the app may refresh in the background.")
                }
                Section {
                    Toggle("Red night mode", isOn: $red)
                } header: { Text("Display") } footer: {
                    Text("Keeps your eyes dark-adapted. iOS cannot recolour the status bar, keyboard or permission alerts, and screen brightness is yours to lower. For a fully red screen, use iOS Settings, Accessibility, Display, Colour Filters, Colour Tint.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
