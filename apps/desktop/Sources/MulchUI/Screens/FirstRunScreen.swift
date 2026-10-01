import SwiftUI

public struct FirstRunScreen: View {
    let rows: [FirstRunRow]
    let reclaimable: Int64
    let isScanning: Bool
    let onToggle: (String, Bool) -> Void
    let onFinish: () -> Void

    public init(
        rows: [FirstRunRow], reclaimable: Int64, isScanning: Bool,
        onToggle: @escaping (String, Bool) -> Void, onFinish: @escaping () -> Void
    ) {
        self.rows = rows
        self.reclaimable = reclaimable
        self.isScanning = isScanning
        self.onToggle = onToggle
        self.onFinish = onFinish
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            BigNumber(bytes: reclaimable, caption: isScanning ? "Scanning your Mac" : "Cleaned on the first sweep")

            VStack(spacing: 0) {
                ForEach(rows) { row in
                    HStack(spacing: 10) {
                        Image(systemName: row.done ? "checkmark" : "circle.dotted")
                            .foregroundStyle(row.done ? Theme.auto : .secondary)
                            .frame(width: 16)
                        Text(row.title)
                        if let tag = row.tag {
                            Text(tag).foregroundStyle(Theme.ask)
                        }
                        Spacer()
                        Text(row.done ? (row.bytes > 0 ? Theme.bytes(row.bytes) : "nothing to clean") : "")
                            .monospacedDigit()
                            .foregroundStyle(row.enabled && row.bytes > 0 ? .primary : .secondary)
                        Toggle(row.title, isOn: Binding(get: { row.enabled }, set: { onToggle(row.id, $0) }))
                            .labelsHidden()
                            .toggleStyle(.switch)
                            .controlSize(.small)
                    }
                    .padding(.vertical, 7)
                    Divider()
                }
            }

            HStack {
                Text("Worktrees, emulators and simulators are never touched.")
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
                Button("Start weekly sweep", action: onFinish)
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(isScanning)
            }
        }
        .frame(maxWidth: 540)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
