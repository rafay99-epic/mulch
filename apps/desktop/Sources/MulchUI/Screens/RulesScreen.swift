import SwiftUI
import UniformTypeIdentifiers

public struct RulesActions {
    public var setMode: (String, CleanMode) -> Void
    public var setMinAge: (String, Int?) -> Void
    public var addRoot: (URL) -> Void
    public var removeRoot: (String) -> Void
    public var addNever: (URL) -> Void
    public var removeNever: (String) -> Void
    public var openConfig: () -> Void

    public init(
        setMode: @escaping (String, CleanMode) -> Void,
        setMinAge: @escaping (String, Int?) -> Void,
        addRoot: @escaping (URL) -> Void,
        removeRoot: @escaping (String) -> Void,
        addNever: @escaping (URL) -> Void,
        removeNever: @escaping (String) -> Void,
        openConfig: @escaping () -> Void
    ) {
        self.setMode = setMode
        self.setMinAge = setMinAge
        self.addRoot = addRoot
        self.removeRoot = removeRoot
        self.addNever = addNever
        self.removeNever = removeNever
        self.openConfig = openConfig
    }
}

/// Rules grouped by tool, the folders Mulch scans, and the folders it never touches.
public struct RulesScreen: View {
    let sections: [RuleSection]
    let roots: [String]
    let never: [String]
    @Binding var launchAtLogin: Bool
    let actions: RulesActions

    @State private var picking: PickTarget?

    private enum PickTarget: Identifiable {
        case root, never
        var id: Self { self }
    }

    public init(sections: [RuleSection], roots: [String], never: [String], launchAtLogin: Binding<Bool>, actions: RulesActions) {
        self.sections = sections
        self.roots = roots
        self.never = never
        _launchAtLogin = launchAtLogin
        self.actions = actions
    }

    public var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                LabeledContent("Config file") {
                    Button("Open", action: actions.openConfig)
                }
            }

            ForEach(sections) { section in
                Section(section.id) {
                    ForEach(section.rows) { row in
                        RuleLine(row: row, actions: actions)
                    }
                }
            }

            pathSection("Code folders", paths: roots, add: .root, remove: actions.removeRoot)
            pathSection("Never touch", paths: never, add: .never, remove: actions.removeNever)
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: [.folder]
        ) { result in
            guard case let .success(url) = result else { return }
            picking == .root ? actions.addRoot(url) : actions.addNever(url)
        }
    }

    private func pathSection(_ title: String, paths: [String], add: PickTarget, remove: @escaping (String) -> Void) -> some View {
        Section(title) {
            ForEach(paths, id: \.self) { path in
                HStack {
                    Text(path).font(.system(.body, design: .monospaced))
                    Spacer()
                    Button("Remove", systemImage: "minus.circle") { remove(path) }
                        .labelStyle(.iconOnly)
                        .buttonStyle(.borderless)
                }
            }
            Button("Add folder…") { picking = add }
        }
    }
}

private struct RuleLine: View {
    let row: RuleRow
    let actions: RulesActions

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.title)
                if let bytes = row.bytes, bytes > 0 {
                    Text(Theme.bytes(bytes)).font(.caption).monospacedDigit().foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let days = row.minAgeDays {
                Stepper(
                    "Idle \(days)d",
                    value: Binding(get: { days }, set: { actions.setMinAge(row.id, $0) }),
                    in: 0...365
                )
                .font(.callout.monospacedDigit())
                .fixedSize()
            }
            ModePicker(selection: Binding(get: { row.mode }, set: { actions.setMode(row.id, $0) }))
        }
    }
}
