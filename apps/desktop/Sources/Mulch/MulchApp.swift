import MulchUI
import SwiftUI

/// Menu bar first. The main window opens on first launch for setup and afterwards
/// only on request. Settings is the standard Cmd+comma window.
@main
struct MulchApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        MenuBarExtra("Mulch", systemImage: "leaf") {
            PopoverScene(store: store)
        }
        .menuBarExtraStyle(.window)

        Window("Mulch", id: MainScene.id) {
            MainScene(store: store)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 560)
        .defaultLaunchBehavior(store.config.onboarded ? .suppressed : .presented)

        Settings {
            SettingsScene(store: store)
        }
    }
}
