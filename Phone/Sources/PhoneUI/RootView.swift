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

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: SidebarItem? = .tonight
    /// The sidebar starts closed in portrait, so the page has the full width; landscape has room for both.
    @State private var columns: NavigationSplitViewVisibility = .automatic
    enum SidebarItem: Hashable { case tonight, settings }

    @ViewBuilder private var phaseContent: some View {
        phaseSwitch.animation(reduceMotion ? nil : .easeOut(duration: 0.4), value: store.phase)
    }

    @ViewBuilder private var phaseSwitch: some View {
        switch store.phase {
        case .needsSite: FirstRunScreen(store: store)
        case .loading: LoadingScreen(siteName: store.site?.name ?? "your site", stage: store.stage).transition(.opacity)
        case .failed(let why):
            EmptyState(title: "No forecast yet", message: why, action: ("Try again", { refresh(force: true) }))
        case .ready:
            if let m = store.tonight {
                TonightScreen(model: m, markData: store.appleMarkData, offline: store.offline, refreshing: store.refreshing,
                              onRefresh: { refresh(force: true) },
                              alertsPrompt: AlertsPrompt(permission: permission, onGranted: { refresh(force: true) }), now: store.now)
                    .transition(.opacity)
            }
        }
    }

    private var nightModeButton: some View {
        Button { red.toggle() } label: { Image(systemName: red ? "moon.fill" : "moon") }
            .accessibilityLabel("Red night mode")
            .sensoryFeedback(.selection, trigger: red)
    }

    /// iPhone and Slide Over: one stack, with sites and settings as sheets.
    private func stack(_ theme: PhoneTheme) -> some View {
        NavigationStack {
            phaseContent
                .navigationBarTitleDisplayModeInline()
                .toolbar {
                    // A drawn title, not .navigationTitle: the system title ignores the red palette.
                    ToolbarItem(placement: .principal) {
                        Text(store.site?.name ?? "Nightwatch").font(.headline).foregroundStyle(theme.textPrimary)
                    }
                    ToolbarItemGroup(placement: .primaryAction) {
                        nightModeButton
                        if store.phase != .needsSite {
                            Button { showSites = true } label: { Image(systemName: "mappin.and.ellipse") }.accessibilityLabel("Sites")
                        }
                        Button { showSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                    }
                    .plainBackground()
                }
                .clearNavigationBar()
        }
    }

    /// iPad: a sidebar with Tonight, the sites and Settings, and the page beside it.
    private func split(_ theme: PhoneTheme) -> some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                Section {
                    Label("Tonight", systemImage: "moon.stars").tag(SidebarItem.tonight)
                    Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
                }
                Section {
                    Toggle(isOn: $red) { Label("Red night mode", systemImage: "moon.fill") }
                        .toggleStyle(PhoneToggleStyle())
                } footer: { Text("Keeps your eyes dark-adapted at the telescope.") }
                Section("Your sites") {
                    ForEach(store.config.sites, id: \.name) { s in
                        Button { store.selectSite(s); selection = .tonight } label: {
                            HStack { Text(s.name); Spacer(); if s.name == store.site?.name { Image(systemName: "checkmark").foregroundStyle(theme.accent) } }
                        }
                    }
                    Button { showSites = true } label: { Label("Add or remove sites", systemImage: "plus") }
                }
            }
            .scrollContentBackground(.hidden).background(theme.background)
            .navigationTitle("Nightwatch")
        } detail: {
            NavigationStack {
                Group {
                    if selection == .settings { SettingsScreen(store: store, red: $red, permission: permission, embedded: true) } else { phaseContent }
                }
                .navigationBarTitleDisplayModeInline()
                .clearNavigationBar()
            }
        }
    }

    public var body: some View {
        let theme = PhoneTheme.named(red: red)
        Group {
            if sizeClass == .regular && store.phase != .needsSite {
                GeometryReader { geo in
                    split(theme).onAppear { columns = geo.size.width < 1000 ? .detailOnly : .all }
                }
            } else { stack(theme) }
        }
        .sheet(isPresented: $showSites) { SitesSheet(store: store).phoneTheme(theme) }
        .sheet(isPresented: $showSettings) { SettingsScreen(store: store, red: $red, permission: permission).phoneTheme(theme) }
        .phoneTheme(theme)
        .environment(\.allowsOptionalDownloads, connectivity.current.allowsOptionalDownloads)
        .task { refresh() }
        .onChange(of: scenePhase) { _, p in if p == .active { refresh(); Task { await permission.refresh() } } }
        .onChange(of: connectivity.current.isOnline) { _, on in if on { refresh() } }
    }
}

extension ToolbarContent {
    /// The toolbar's buttons without iOS 26's glass capsule behind them.
    func plainBackground() -> some ToolbarContent {
        #if os(iOS)
        if #available(iOS 26.0, *) { return AnyToolbarContent(self.sharedBackgroundVisibility(.hidden)) }
        #endif
        return AnyToolbarContent(self)
    }
}

/// Type erasure for the two branches above.
struct AnyToolbarContent<Content: ToolbarContent>: ToolbarContent {
    let content: Content
    init(_ content: Content) { self.content = content }
    var body: some ToolbarContent { content }
}

extension View {
    /// No translucent bar behind the title and buttons: the sky shows through to the top.
    func clearNavigationBar() -> some View {
        #if os(iOS)
        toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

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
    @Environment(\.phoneTheme) private var theme
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
                }.listRowBackground(theme.card)
                Section("Add a site") {
                    TextField("A place name", text: $name).submitLabel(.search).onSubmit {
                        Task { if let s = await PlaceSearch.find(name) { store.addSite(s); name = "" } else { message = "Could not find that place." } }
                    }
                    if let message { Text(message).font(.footnote) }
                }.listRowBackground(theme.card)
            }
            .scrollContentBackground(.hidden).background(theme.background)
            .navigationBarTitleDisplayModeInline()
            .toolbar {
                ToolbarItem(placement: .principal) { Text("Sites").font(.headline).foregroundStyle(theme.textPrimary) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct SettingsScreen: View {
    @ObservedObject var store: PhoneStore
    @Environment(\.phoneTheme) private var theme
    @Binding var red: Bool
    @ObservedObject var permission: NotificationPermission
    var embedded = false
    @Environment(\.dismiss) private var dismiss

    private func binding<T>(_ kp: WritableKeyPath<AlertSettings, T>) -> Binding<T> {
        Binding(get: { store.config.alerts[keyPath: kp] }, set: { store.config.alerts[keyPath: kp] = $0; store.saveConfig() })
    }

    private var form: some View {
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
            }.listRowBackground(theme.card)
            Section {
                Toggle("Red night mode", isOn: $red)
            } header: { Text("Display") } footer: {
                Text("Keeps your eyes dark-adapted. iOS cannot recolour the status bar, keyboard or permission alerts, and screen brightness is yours to lower. For a fully red screen, use iOS Settings, Accessibility, Display, Colour Filters, Colour Tint.")
            }.listRowBackground(theme.card)
        }
        .scrollContentBackground(.hidden).background(theme.background)
        .toggleStyle(PhoneToggleStyle())
        .navigationBarTitleDisplayModeInline()
    }

    var body: some View {
        if embedded {
            form.toolbar { ToolbarItem(placement: .principal) { Text("Settings").font(.headline).foregroundStyle(theme.textPrimary) } }
        } else {
            NavigationStack {
                form.toolbar {
                    ToolbarItem(placement: .principal) { Text("Settings").font(.headline).foregroundStyle(theme.textPrimary) }
                    ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
                }
            }
        }
    }
}
