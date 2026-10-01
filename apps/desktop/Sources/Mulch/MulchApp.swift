import MulchUI
import SwiftUI

/// Menu bar first. The main window opens on first launch for onboarding and
/// afterwards only on request.
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
        .defaultSize(width: 980, height: 640)
        .defaultLaunchBehavior(store.config.onboarded ? .suppressed : .presented)
    }
}
