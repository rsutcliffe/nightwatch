import SwiftUI
import SkyCore

@main
struct NightwatchApp: App {
    @StateObject private var store = Store()
    private let location = LocationProvider()

    var body: some Scene {
        MenuBarExtra {
            TonightView()
                .environmentObject(store)
                .frame(width: 360)
        } label: {
            // The label is the status-bar icon and is always rendered at launch; the popover
            // content above is lazy and only builds once opened, so boot() must start here.
            Image(systemName: store.iconName)
                .task { await boot() }
        }
        .menuBarExtraStyle(.window)

        Window("Targets", id: "targets") { TargetsView().environmentObject(store) }
            .defaultSize(width: 980, height: 640)
        Window("Settings", id: "settings") { SettingsView().environmentObject(store) }
            .defaultSize(width: 520, height: 560)
        Window("About Nightwatch", id: "about") { AboutView() }
            .defaultSize(width: 420, height: 420)
    }

    @MainActor
    private func boot() async {
        guard store.scheduler == nil, !store.booting else { return }
        store.booting = true
        location.onSite = { [store] site in Task { @MainActor in store.autoSite = site; await store.refresh(force: false) } }
        await Notifier.requestAuthorisation()
        if store.config.activeSiteName == nil { store.autoSite = await location.requestOnce() }
        await store.refresh(force: false)
        let s = Scheduler { [location] in
            Task { @MainActor in
                if store.site == nil, let fix = await location.requestOnce() { store.autoSite = fix }   // retry location until we have a site
                await store.refresh(force: false)
            }
        }
        s.start()
        store.scheduler = s
    }
}
