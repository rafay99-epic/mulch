import SwiftUI

public struct InspectorActions {
    public var cleanAll: () -> Void
    public var cleanRule: (String) -> Void
    public var cleanItem: (String) -> Void
    public var skipItem: (String) -> Void
    public var reveal: (String) -> Void
    public var rescan: () -> Void

    public init(
        cleanAll: @escaping () -> Void,
        cleanRule: @escaping (String) -> Void,
        cleanItem: @escaping (String) -> Void,
        skipItem: @escaping (String) -> Void,
        reveal: @escaping (String) -> Void,
        rescan: @escaping () -> Void
    ) {
        self.cleanAll = cleanAll
        self.cleanRule = cleanRule
        self.cleanItem = cleanItem
        self.skipItem = skipItem
        self.reveal = reveal
        self.rescan = rescan
    }
}

public struct InspectorScreen: View {
    let sections: [RuleListSection]
    @Binding var selectedRule: String?
    let summary: RuleSummary?
    let items: [ItemRow]
    @Binding var selectedItem: String?
    let detail: ItemDetail?
    let reclaimable: Int64
    let isScanning: Bool
    let isCleaning: Bool
    let actions: InspectorActions

    public init(
        sections: [RuleListSection], selectedRule: Binding<String?>, summary: RuleSummary?,
        items: [ItemRow], selectedItem: Binding<String?>, detail: ItemDetail?,
        reclaimable: Int64, isScanning: Bool, isCleaning: Bool, actions: InspectorActions
    ) {
        self.sections = sections
        _selectedRule = selectedRule
        self.summary = summary
        self.items = items
        _selectedItem = selectedItem
        self.detail = detail
        self.reclaimable = reclaimable
        self.isScanning = isScanning
        self.isCleaning = isCleaning
        self.actions = actions
    }

    public var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 300)
        } content: {
            itemsPane
                .navigationSplitViewColumnWidth(min: 260, ideal: 320, max: 480)
        } detail: {
            inspector
        }
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Text("\(Theme.bytes(reclaimable)) reclaimable")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Button("Rescan", systemImage: "arrow.clockwise", action: actions.rescan)
                    .disabled(isScanning)
                    .help("Scan again")
                Button(isCleaning ? "Cleaning…" : "Clean", action: actions.cleanAll)
                    .buttonStyle(.glassProminent)
                    .disabled(reclaimable == 0 || isCleaning || isScanning)
                    .help("Clean everything ready under weekly rules")
                SettingsLink { Label("Settings", systemImage: "gearshape") }
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selectedRule) {
            ForEach(sections) { section in
                Section(section.id) {
                    ForEach(section.items) { item in
                        HStack {
                            Text(item.title)
                                .foregroundStyle(item.mode == .ask ? Theme.ask : .primary)
                                .lineLimit(1)
                            Spacer()
                            Text(item.bytes > 0 ? Theme.bytes(item.bytes) : "")
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .tag(item.id)
                    }
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView(isScanning ? "Scanning" : "Nothing to clean", systemImage: isScanning ? "magnifyingglass" : "leaf")
            }
        }
    }

    @ViewBuilder
    private var itemsPane: some View {
        if let summary {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(summary.title).font(.headline)
                        Text("\(summary.readyCount) ready, \(Theme.bytes(summary.readyBytes))")
                            .font(.callout).monospacedDigit().foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Clean \(summary.readyCount)") { actions.cleanRule(summary.id) }
                        .disabled(summary.readyCount == 0 || isCleaning || isScanning)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                Divider()
                List(items, selection: $selectedItem) { item in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(.system(.callout, design: .monospaced))
                                .lineLimit(1)
                                .truncationMode(.middle)
                            if !item.ready {
                                Text(item.status).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 6)
                        Text(Theme.bytes(item.bytes))
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(item.ready ? .primary : .secondary)
                    }
                    .tag(item.id)
                }
                .scrollContentBackground(.hidden)
            }
            .background(Theme.background)
        } else {
            ContentUnavailableView("Select a rule", systemImage: "sidebar.left")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        }
    }

    @ViewBuilder
    private var inspector: some View {
        Group {
            if let detail {
                ItemInspector(detail: detail, isBusy: isCleaning || isScanning, actions: actions)
            } else if let summary {
                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.title).font(.title3.weight(.semibold))
                    ModeBadge(summary.mode)
                    Text(summary.why).foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear
            }
        }
        .background(Theme.background)
    }
}

private struct ItemInspector: View {
    let detail: ItemDetail
    let isBusy: Bool
    let actions: InspectorActions

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(detail.name).font(.title3.weight(.semibold)).lineLimit(2)
                Text(detail.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(3)
            }

            Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 12, verticalSpacing: 6) {
                field("Size", Theme.bytes(detail.bytes))
                if let folder = detail.folder { field("In", folder) }
                if let lastUsed = detail.lastUsed {
                    field("Last used", lastUsed.formatted(.relative(presentation: .named)))
                }
                field("Rule", detail.rule)
                field("Why", detail.why)
                GridRow {
                    Text("Status").foregroundStyle(.secondary)
                    Text(detail.status).foregroundStyle(detail.ready ? Theme.auto : Theme.ask)
                }
            }
            .font(.callout)

            HStack(spacing: 8) {
                Button("Clean") { actions.cleanItem(detail.id) }
                    .buttonStyle(.glassProminent)
                    .disabled(!detail.ready || isBusy)
                if detail.mode == .ask {
                    Button("Skip") { actions.skipItem(detail.id) }
                }
                if detail.canReveal {
                    Button("Reveal in Finder") { actions.reveal(detail.id) }
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func field(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value).monospacedDigit()
        }
    }
}
