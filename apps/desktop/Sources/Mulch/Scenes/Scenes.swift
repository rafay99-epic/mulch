import AppKit
import MulchCore
import MulchUI
import SwiftUI

struct PopoverScene: View {
    let store: AppStore
    let updater: Updater
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        PopoverScreen(
            model: Presenter.popover(store, updater: updater),
            actions: PopoverActions(
                clean: { Task { await store.cleanAuto() } },
                cleanItem: { id in Task { await store.clean(itemIDs: [id]) } },
                skipItem: { store.skip($0) },
                rescan: { Task { await store.rescan() } },
                update: { updater.install() },
                openApp: {
                    Log.info("action: open main window")
                    openWindow(id: MainScene.id)
                    NSApp.activate()
                },
                quit: {
                    Log.info("action: quit")
                    NSApp.terminate(nil)
                }
            )
        )
        .preferredColorScheme(.dark)
        .onAppear {
            Log.info("ui: menu bar window opened")
            store.refreshIfStale()
        }
        .onDisappear { Log.info("ui: menu bar window closed") }
    }
}

struct MainScene: View {
    static let id = "main"

    let store: AppStore
    @State private var selectedRule: String?
    @State private var selectedItem: String?

    var body: some View {
        Group {
            if store.config.onboarded { inspector } else { firstRun }
        }
        .frame(minWidth: 760, minHeight: 480)
        .preferredColorScheme(.dark)
        .tint(Theme.auto)
        .onAppear {
            Log.info("ui: main window opened (\(store.config.onboarded ? "inspector" : "first run"))")
            NSApp.setActivationPolicy(.regular)
            store.refreshIfStale()
        }
        .onDisappear {
            Log.info("ui: main window closed")
            NSApp.setActivationPolicy(.accessory)
        }
    }

    private var sections: [RuleListSection] { Presenter.ruleList(store.report) }
    private var rule: RuleReport? { selectedRule.flatMap { store.report?.report(for: $0) } }

    private var detail: ItemDetail? {
        guard let rule, let finding = selectedItem.flatMap(store.finding) else { return nil }
        return Presenter.detail(finding, rule: rule, paths: store.engine.paths, skipped: store.skipped)
    }

    private var inspector: some View {
        InspectorScreen(
            sections: sections,
            selectedRule: $selectedRule,
            summary: rule.map(Presenter.summary),
            items: rule.map { Presenter.items($0, skipped: store.skipped) } ?? [],
            selectedItem: $selectedItem,
            detail: detail,
            reclaimable: store.report?.autoBytes ?? 0,
            isScanning: store.isScanning,
            isCleaning: store.isCleaning,
            actions: InspectorActions(
                cleanAll: { Task { await store.cleanAuto() } },
                cleanRule: { id in Task { await store.cleanRule(id) } },
                cleanItem: { id in Task { await store.clean(itemIDs: [id]) } },
                skipItem: { store.skip($0) },
                reveal: { store.reveal($0) },
                rescan: { Task { await store.rescan() } }
            )
        )
        .onChange(of: sections, initial: true) { keepSelectionValid() }
        .onChange(of: selectedRule) {
            selectedItem = rule?.findings.first?.id
        }
    }

    private func keepSelectionValid() {
        let ids = sections.flatMap(\.items).map(\.id)
        if selectedRule.map(ids.contains) != true { selectedRule = ids.first }
        if let selectedItem, store.finding(selectedItem) == nil { self.selectedItem = rule?.findings.first?.id }
    }

    private var firstRun: some View {
        FirstRunScreen(
            rows: Presenter.firstRunRows(store),
            reclaimable: store.report?.autoBytes ?? 0,
            isScanning: store.isScanning,
            onToggle: { id, enabled in
                if let group = RuleGroup(rawValue: id) { store.setGroup(group, enabled: enabled) }
            },
            onFinish: { Task { await store.finishOnboarding() } }
        )
    }
}

struct SettingsScene: View {
    let store: AppStore
    let updater: Updater

    var body: some View {
        SettingsScreen(
            sections: Presenter.ruleSections(store),
            roots: store.config.codeRoots,
            never: store.config.never,
            history: Presenter.history(store.history),
            nextSweep: store.nextSweep,
            about: Presenter.about(updater, isCleaning: store.isCleaning),
            launchAtLogin: Binding(get: { store.launchAtLogin }, set: { store.setLaunchAtLogin($0) }),
            actions: SettingsActions(
                setMode: { store.setMode(Presenter.mode($1), ruleID: $0) },
                setMinAge: { store.setMinAge($1, ruleID: $0) },
                addRoot: { store.addRoot($0) },
                removeRoot: { store.setRoot($0, enabled: false) },
                addNever: { store.addNever($0) },
                removeNever: { store.removeNever($0) },
                openConfig: { store.openConfigFile() },
                checkForUpdates: { Task { await updater.check() } },
                installUpdate: { updater.install() },
                openLog: { NSWorkspace.shared.activateFileViewerSelecting([Log.url]) }
            )
        )
        .preferredColorScheme(.dark)
        .tint(Theme.auto)
        .onAppear { Log.info("ui: settings opened") }
        .onDisappear { Log.info("ui: settings closed") }
    }
}
