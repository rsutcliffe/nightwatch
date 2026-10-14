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
    @State private var showHorizon: HorizonTarget?

    public init(store: PhoneStore, connectivity: ConnectivityMonitor) {
        self.store = store; self.connectivity = connectivity
        // `-demoTab plan` (or targets, week) opens that section first, for screenshots in the Simulator.
        let first = UserDefaults.standard.string(forKey: "demoTab").flatMap { ["tonight": SidebarItem.tonight, "plan": .plan, "targets": .targets, "week": .week][$0] } ?? .tonight
        _tab = State(initialValue: first); _selection = State(initialValue: first)
    }

    private func refresh(force: Bool = false) { Task { await store.refresh(force: force, connectivity: connectivity.current) } }

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var selection: SidebarItem?
    /// The sidebar starts closed in portrait, so the page has the full width; landscape has room for both.
    @State private var columns: NavigationSplitViewVisibility = .automatic
    enum SidebarItem: Hashable { case tonight, plan, targets, week, settings }
    @State private var tab: SidebarItem
    @State private var planTomorrow = false

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

    /// The page for a section. Until the forecast is ready every section shows the same waiting, failed or first-run page.
    @ViewBuilder private func page(_ item: SidebarItem) -> some View {
        if store.phase != .ready || store.planning == nil || item == .tonight {
            phaseContent
        } else {
            switch item {
            case .plan: PlanScreen(store: store, onBrowse: { tab = .targets; selection = .targets })
            case .targets: TargetsScreen(store: store)
            case .week: WeekScreen(store: store, onOpenPlan: { _ in tab = .plan; selection = .plan })
            default: phaseContent
            }
        }
    }

    private func title(_ item: SidebarItem) -> String {
        switch item {
        case .tonight: store.site?.name ?? "Nightwatch"
        case .plan: "Plan"
        case .targets: "Targets"
        case .week: "The week ahead"
        case .settings: "Settings"
        }
    }

    private var nightModeButton: some View {
        Button { red.toggle() } label: { Image(systemName: red ? "moon.fill" : "moon") }
            .accessibilityLabel("Red night mode")
            .sensoryFeedback(.selection, trigger: red)
    }

    /// iPhone and Slide Over: four tabs, each in its own stack, with sites and settings as sheets.
    private func stack(_ theme: PhoneTheme) -> some View {
        TabView(selection: $tab) {
            ForEach([SidebarItem.tonight, .plan, .targets, .week], id: \.self) { item in
                NavigationStack {
                    page(item)
                        .navigationBarTitleDisplayModeInline()
                        .toolbar {
                            // A drawn title, not .navigationTitle: the system title ignores the red palette.
                            if store.phase != .ready || item != .tonight {
                                ToolbarItem(placement: .principal) { Text(title(item)).font(.headline).foregroundStyle(theme.textPrimary) }
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
                .tabItem { Label(tabName(item), systemImage: tabSymbol(item)) }
                .tag(item)
            }
        }
    }

    private func tabName(_ i: SidebarItem) -> String { i == .tonight ? "Tonight" : i == .plan ? "Plan" : i == .targets ? "Targets" : "Week" }
    private func tabSymbol(_ i: SidebarItem) -> String { i == .tonight ? "moon.stars" : i == .plan ? "list.bullet.rectangle" : i == .targets ? "sparkles" : "calendar" }

    /// iPad: a sidebar with Tonight, the sites and Settings, and the page beside it.
    private func split(_ theme: PhoneTheme) -> some View {
        NavigationSplitView(columnVisibility: $columns) {
            List(selection: $selection) {
                Section {
                    Label("Tonight", systemImage: "moon.stars").tag(SidebarItem.tonight)
                    Label("Plan", systemImage: "list.bullet.rectangle").tag(SidebarItem.plan)
                    Label("Targets", systemImage: "sparkles").tag(SidebarItem.targets)
                    Label("The week ahead", systemImage: "calendar").tag(SidebarItem.week)
                    Label("Settings", systemImage: "gearshape").tag(SidebarItem.settings)
                }
                Section {
                    Button { showSites = true } label: {
                        HStack {
                            Label("Sites", systemImage: "mappin.and.ellipse")
                            Spacer()
                            Text(store.site?.name ?? "").font(.callout).secondary().lineLimit(1)
                        }
                    }
                    Toggle(isOn: $red) { Label("Red night mode", systemImage: "moon.fill") }
                        .toggleStyle(PhoneToggleStyle())
                }
            }
            .scrollContentBackground(.hidden).background(theme.background)
            .navigationTitle("Nightwatch")
        } detail: {
            NavigationStack {
                Group {
                    if selection == .settings { SettingsScreen(store: store, red: $red, permission: permission, embedded: true) } else { page(selection ?? .tonight) }
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
        .sheet(item: $showHorizon) { HorizonSheet(store: store, siteName: $0.name).phoneTheme(theme) }
        .sheet(isPresented: $showSettings) { SettingsScreen(store: store, red: $red, permission: permission).phoneTheme(theme) }
        .phoneTheme(theme)
        .environment(\.allowsOptionalDownloads, connectivity.current.allowsOptionalDownloads)
        .task {
            refresh()
            // `-demoOpen horizon` opens the active site's horizon sheet at launch, for screenshots in the Simulator.
            if UserDefaults.standard.string(forKey: "demoOpen") == "horizon", let n = store.site?.name { try? await Task.sleep(for: .seconds(2)); showHorizon = HorizonTarget(name: n) }
        }
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
    @State private var choices: [PlaceMatch] = []
    @Environment(\.phoneTheme) private var theme

    var body: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Is tonight a night to observe?").font(.title2.weight(.medium)).multilineTextAlignment(.center)
            Text("Nightwatch reads the sky forecast and tells you, then alerts you. Where do you observe from?")
                .font(.callout).secondary().multilineTextAlignment(.center)
            TextField("A place name", text: $name).textFieldStyle(.roundedBorder).submitLabel(.search).onSubmit(add)
                .task(id: name) { choices = await PlaceSearch.matches(typed: name) }
            if let message { Text(message).font(.footnote).foregroundStyle(theme.warning) }
            PlaceChoices(matches: choices) { store.addSite($0.site); choices = [] }
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
            choices = await PlaceSearch.matches(name)
            if choices.isEmpty { message = "Could not find that place." }
            busy = false
        }
    }

    private func useLocation() {
        Task {
            do { store.addSite(try await location.currentSite()) } catch { message = "Location is not available. Type a place name instead." }
        }
    }
}

/// A site named for the horizon sheet to open.
struct HorizonTarget: Identifiable { let name: String; var id: String { name } }

struct SitesSheet: View {
    @ObservedObject var store: PhoneStore
    @Environment(\.phoneTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var message: String?
    @State private var horizonSite: HorizonTarget?
    @State private var choices: [PlaceMatch] = []

    var body: some View {
        NavigationStack {
            List {
                Section("Your sites") {
                    ForEach(store.config.sites, id: \.name) { s in
                        HStack {
                            Button { store.selectSite(s); dismiss() } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(s.name)
                                        Text(Copy.horizonSummary(s, openDeg: store.openDeg).plainDashes).font(.caption).secondary().lineLimit(1)
                                    }
                                    Spacer(); if s.name == store.site?.name { Image(systemName: "checkmark") }
                                }
                            }
                            .buttonStyle(.borderless)
                            Button { horizonSite = HorizonTarget(name: s.name) } label: {
                                Image(systemName: "mountain.2").frame(width: 44, height: 44).contentShape(Rectangle())
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Horizon for \(s.name)")
                        }
                    }
                    .onDelete { store.removeSites(at: $0) }
                }.listRowBackground(theme.card)
                Section("Add a site") {
                    TextField("A place name", text: $name).submitLabel(.search)
                        .task(id: name) { choices = await PlaceSearch.matches(typed: name) }
                    if let message { Text(message).font(.footnote) }
                    PlaceChoices(matches: choices) { store.addSite($0.site); name = ""; choices = [] }
                }.listRowBackground(theme.card)
            }
            .sheet(item: $horizonSite) { HorizonSheet(store: store, siteName: $0.name).phoneTheme(theme) }
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

    private func step(_ delta: Int) {
        store.config.stopBy.minutes = ((store.config.stopBy.minutes + delta) % 1440 + 1440) % 1440
        store.saveConfig(); store.replan()
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
                Toggle("Finish by", isOn: Binding(get: { store.config.stopBy.enabled }, set: { store.config.stopBy.enabled = $0; store.saveConfig(); store.replan() }))
                if store.config.stopBy.enabled {
                    Stepper(String(format: "Stop at %02d:%02d", store.config.stopBy.minutes / 60, store.config.stopBy.minutes % 60),
                            onIncrement: { step(30) }, onDecrement: { step(-30) })
                }
            } header: { Text("Plan") } footer: {
                Text("A finish time (for sleep, or work the next day) shortens the clear window the plan uses, and keeps targets that are best after it out.")
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

/// The places a search found, each with where it is; tapping one adds it.
struct PlaceChoices: View {
    let matches: [PlaceMatch]
    let pick: (PlaceMatch) -> Void
    var body: some View {
        ForEach(matches) { m in
            Button { pick(m) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(m.site.name)
                    if !m.detail.isEmpty { Text(m.detail).font(.caption).secondary() }
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.borderless)
        }
    }
}
