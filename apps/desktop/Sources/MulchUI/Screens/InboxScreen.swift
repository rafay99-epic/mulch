import SwiftUI

/// Items from Ask rules, waiting for a decision.
public struct InboxScreen: View {
    let items: [InboxItem]
    let onClean: (String) -> Void
    let onSkip: (String) -> Void
    let onCleanAll: () -> Void

    public init(
        items: [InboxItem], onClean: @escaping (String) -> Void,
        onSkip: @escaping (String) -> Void, onCleanAll: @escaping () -> Void
    ) {
        self.items = items
        self.onClean = onClean
        self.onSkip = onSkip
        self.onCleanAll = onCleanAll
    }

    public var body: some View {
        PageScaffold {
            Button("Clean all \(Theme.bytes(items.reduce(0) { $0 + $1.bytes }))", action: onCleanAll)
                .buttonStyle(.glassProminent)
                .disabled(items.isEmpty)
        } content: {
            if items.isEmpty {
                ContentUnavailableView("Nothing needs you", systemImage: "checkmark.circle")
            } else {
                List(items) { item in
                    InboxRow(item, onClean: { onClean(item.id) }, onSkip: { onSkip(item.id) })
                        .padding(.vertical, 2)
                }
                .scrollContentBackground(.hidden)
            }
        }
    }
}
