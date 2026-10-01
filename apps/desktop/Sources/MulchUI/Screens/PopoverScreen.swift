import SwiftUI

public struct PopoverActions {
    public var clean: () -> Void
    public var cleanItem: (String) -> Void
    public var skipItem: (String) -> Void
    public var rescan: () -> Void
    public var openApp: () -> Void
    public var quit: () -> Void

    public init(
        clean: @escaping () -> Void,
        cleanItem: @escaping (String) -> Void,
        skipItem: @escaping (String) -> Void,
        rescan: @escaping () -> Void,
        openApp: @escaping () -> Void,
        quit: @escaping () -> Void
    ) {
        self.clean = clean
        self.cleanItem = cleanItem
        self.skipItem = skipItem
        self.rescan = rescan
        self.openApp = openApp
        self.quit = quit
    }
}

/// The menu bar window: one number, the biggest rules, the inbox, and the schedule.
/// Fixed width and no animated height changes.
public struct PopoverScreen: View {
    let model: PopoverModel
    let actions: PopoverActions

    public init(model: PopoverModel, actions: PopoverActions) {
        self.model = model
        self.actions = actions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            BigNumber(bytes: model.reclaimable, caption: model.isScanning ? "Scanning…" : "Reclaimable now")

            if !model.bars.isEmpty {
                let maxBytes = model.bars.map(\.bytes).max() ?? 0
                VStack(spacing: 10) {
                    ForEach(model.bars) { BarRow($0, maxBytes: maxBytes) }
                }
            }

            Button(action: actions.clean) {
                Text(model.isCleaning ? "Cleaning…" : "Clean \(Theme.bytes(model.reclaimable))")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(model.reclaimable == 0 || model.isCleaning || model.isScanning)

            if let message = model.message {
                Text(message).font(.callout).foregroundStyle(Theme.auto)
            }
            if model.needsFullDiskAccess {
                Text("Some items need Full Disk Access in System Settings, Privacy & Security.")
                    .font(.caption).foregroundStyle(Theme.ask)
            }

            if !model.inbox.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Needs you  \(model.inbox.count)").font(.headline)
                    ForEach(model.inbox.prefix(4)) { item in
                        InboxRow(item, onClean: { actions.cleanItem(item.id) }, onSkip: { actions.skipItem(item.id) })
                    }
                }
            }

            Divider()
            VStack(spacing: 4) {
                StatRow("Next sweep", value: model.nextSweep.map(Self.nextSweepText) ?? "Not scheduled")
                StatRow("Freed this month", value: Theme.bytes(model.freedThisMonth), tint: Theme.auto)
                if let free = model.diskFree { StatRow("Disk free", value: Theme.bytes(free)) }
            }

            HStack {
                Button("Open Mulch", action: actions.openApp)
                Button("Rescan", action: actions.rescan).disabled(model.isScanning)
                Spacer()
                Button("Quit", action: actions.quit)
            }
            .buttonStyle(.borderless)
            .font(.callout)
        }
        .padding(16)
        .frame(width: 340)
        .background(Theme.background)
    }

    static func nextSweepText(_ date: Date) -> String {
        date <= .now ? "When idle" : date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
    }
}
