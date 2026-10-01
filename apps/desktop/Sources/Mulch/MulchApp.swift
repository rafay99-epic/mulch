import MulchUI
import SwiftUI

@main
struct MulchApp: App {
    @State private var store: AppStore
    @State private var updater: Updater

    init() {
        Log.launched()
        let store = AppStore()
        _store = State(initialValue: store)
        _updater = State(initialValue: Updater { !store.isCleaning })
    }

    var body: some Scene {
        MenuBarExtra(Channel.current.displayName, systemImage: Channel.current.menuSymbol) {
            PopoverScene(store: store, updater: updater)
        }
        .menuBarExtraStyle(.window)

        Window(Channel.current.displayName, id: MainScene.id) {
            MainScene(store: store)
        }
        .windowResizability(.contentMinSize)
        .defaultSize(width: 860, height: 560)
        .defaultLaunchBehavior(store.config.onboarded ? .suppressed : .presented)

        Settings {
            SettingsScene(store: store, updater: updater)
        }
    }
}
