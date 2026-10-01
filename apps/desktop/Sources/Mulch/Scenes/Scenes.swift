import AppKit
import MulchCore
import MulchUI
import SwiftUI

/// Connects the menu bar screen to the store.
struct PopoverScene: View {
    let store: AppStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PopoverScreen(
            model: Presenter.popover(store),
            actions: PopoverActions(
                clean: { Task { await store.cleanAuto() } },
                cleanItem: { id in Task { await store.clean(itemIDs: [id]) } },
                skipItem: { store.skip($0) },
                rescan: { Task { await store.scan() } },
                openApp: {
                    openWindow(id: MainScene.id)
                    NSApp.activate()
                },
                quit: { NSApp.terminate(nil) }
            )
        )
        .preferredColorScheme(.dark)
        .onAppear { store.refreshIfStale() }
    }
}

/// Connects the main window to the store. Shows onboarding until it is finished,
/// inside the same constant frame, and a Dock icon only while open.
struct MainScene: View {
    static let id = "main"

    let store: AppStore
    @State private var page: Page = .overview

    var body: some View {
        Group {
            if store.config.onboarded { shell } else { onboarding }
        }
        .frame(minWidth: 820, minHeight: 540)
        .preferredColorScheme(.dark)
        .onAppear {
            NSApp.setActivationPolicy(.regular)
            store.refreshIfStale()
        }
        .onDisappear { NSApp.setActivationPolicy(.accessory) }
    }

    private var shell: some View {
        MainShell(selection: $page, inboxCount: store.inbox.count) { page in
            switch page {
            case .overview:
                OverviewScreen(
                    rows: Presenter.ledger(store.report),
                    reclaimable: store.report?.autoBytes ?? 0,
                    isScanning: store.isScanning,
                    isCleaning: store.isCleaning,
                    onClean: { Task { await store.cleanAuto() } },
                    onRescan: { Task { await store.scan() } }
                )
            case .inbox:
                InboxScreen(
                    items: Presenter.inbox(store.inbox, report: store.report),
                    onClean: { id in Task { await store.clean(itemIDs: [id]) } },
                    onSkip: { store.skip($0) },
                    onCleanAll: { Task { await store.clean(itemIDs: Set(store.inbox.map(\.id))) } }
                )
            case .rules:
                RulesScreen(
                    sections: Presenter.ruleSections(store),
                    roots: store.config.codeRoots,
                    never: store.config.never,
                    launchAtLogin: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }),
                    actions: RulesActions(
                        setMode: { store.setMode(Presenter.mode($1), ruleID: $0) },
                        setMinAge: { store.setMinAge($1, ruleID: $0) },
                        addRoot: { store.addRoot($0) },
                        removeRoot: { store.setRoot($0, enabled: false) },
                        addNever: { store.addNever($0) },
                        removeNever: { store.removeNever($0) },
                        openConfig: { store.openConfigFile() }
                    )
                )
            case .history:
                HistoryScreen(points: Presenter.history(store.history))
            }
        }
    }

    private var onboarding: some View {
        OnboardingScreen(
            tools: Presenter.tools(store.tools),
            roots: Presenter.rootChoices(store),
            groups: Presenter.groupChoices(store),
            reclaimable: store.report?.autoBytes ?? 0,
            isScanning: store.isScanning,
            actions: OnboardingActions(
                toggleRoot: { store.setRoot($0, enabled: $1) },
                addRoot: { store.addRoot($0) },
                toggleGroup: { id, enabled in
                    if let group = RuleGroup(rawValue: id) { store.setGroup(group, enabled: enabled) }
                },
                review: { Task { await store.scan() } },
                finish: { Task { await store.finishOnboarding() } }
            )
        )
    }
}
