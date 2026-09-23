import SwiftUI
import SkyCore

@main
struct NightwatchApp: App {
    var body: some Scene {
        MenuBarExtra("Nightwatch", systemImage: "star") {
            Text("Nightwatch").padding()
        }
        .menuBarExtraStyle(.window)
    }
}
