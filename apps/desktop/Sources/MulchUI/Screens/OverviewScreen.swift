import SwiftUI

/// Every rule in one table: size, mode and why it is or is not cleanable.
public struct OverviewScreen: View {
    let rows: [LedgerRow]
    let reclaimable: Int64
    let isScanning: Bool
    let isCleaning: Bool
    let onClean: () -> Void
    let onRescan: () -> Void

    public init(
        rows: [LedgerRow], reclaimable: Int64, isScanning: Bool, isCleaning: Bool,
        onClean: @escaping () -> Void, onRescan: @escaping () -> Void
    ) {
        self.rows = rows
        self.reclaimable = reclaimable
        self.isScanning = isScanning
        self.isCleaning = isCleaning
        self.onClean = onClean
        self.onRescan = onRescan
    }

    public var body: some View {
        PageScaffold {
            Button(isScanning ? "Scanning…" : "Rescan", action: onRescan).disabled(isScanning)
            Button(isCleaning ? "Cleaning…" : "Clean \(Theme.bytes(reclaimable))", action: onClean)
                .buttonStyle(.glassProminent)
                .disabled(reclaimable == 0 || isCleaning || isScanning)
        } content: {
            BigNumber(bytes: reclaimable, caption: "Reclaimable by Auto rules")
            let maxBytes = rows.map(\.bytes).max() ?? 0
            Table(rows) {
                TableColumn("Rule") { row in Text(row.title) }
                    .width(min: 160, ideal: 220)
                TableColumn("Group") { row in Text(row.group).foregroundStyle(.secondary) }
                    .width(min: 80, ideal: 110)
                TableColumn("Size") { row in
                    HStack(spacing: 8) {
                        Text(Theme.bytes(row.bytes)).monospacedDigit().frame(width: 70, alignment: .trailing)
                        SizeBar(fraction: maxBytes > 0 ? Double(row.bytes) / Double(maxBytes) : 0, tint: Theme.tint(row.mode))
                    }
                }
                .width(min: 150, ideal: 200)
                TableColumn("Mode") { row in ModeBadge(row.mode) }
                    .width(70)
                TableColumn("Status") { row in Text(row.status).foregroundStyle(.secondary) }
            }
            .scrollContentBackground(.hidden)
        }
    }
}
