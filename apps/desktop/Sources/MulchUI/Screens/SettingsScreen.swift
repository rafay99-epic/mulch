import SwiftUI
import UniformTypeIdentifiers

public struct SettingsActions {
    public var setMode: (String, CleanMode) -> Void
    public var setMinAge: (String, Int?) -> Void
    public var addRoot: (URL) -> Void
    public var removeRoot: (String) -> Void
    public var addNever: (URL) -> Void
    public var removeNever: (String) -> Void
    public var openConfig: () -> Void
    public var checkForUpdates: () -> Void
    public var installUpdate: () -> Void
    public var openLog: () -> Void

    public init(
        setMode: @escaping (String, CleanMode) -> Void,
        setMinAge: @escaping (String, Int?) -> Void,
        addRoot: @escaping (URL) -> Void,
        removeRoot: @escaping (String) -> Void,
        addNever: @escaping (URL) -> Void,
        removeNever: @escaping (String) -> Void,
        openConfig: @escaping () -> Void,
        checkForUpdates: @escaping () -> Void,
        installUpdate: @escaping () -> Void,
        openLog: @escaping () -> Void
    ) {
        self.setMode = setMode
        self.setMinAge = setMinAge
        self.addRoot = addRoot
        self.removeRoot = removeRoot
        self.addNever = addNever
        self.removeNever = removeNever
        self.openConfig = openConfig
        self.checkForUpdates = checkForUpdates
        self.installUpdate = installUpdate
        self.openLog = openLog
    }
}

public struct SettingsScreen: View {
    let sections: [RuleSection]
    let roots: [String]
    let never: [String]
    let history: [HistoryPoint]
    let nextSweep: Date?
    let about: AboutModel
    @Binding var launchAtLogin: Bool
    let actions: SettingsActions

    public init(
        sections: [RuleSection], roots: [String], never: [String], history: [HistoryPoint],
        nextSweep: Date?, about: AboutModel, launchAtLogin: Binding<Bool>, actions: SettingsActions
    ) {
        self.sections = sections
        self.roots = roots
        self.never = never
        self.history = history
        self.nextSweep = nextSweep
        self.about = about
        _launchAtLogin = launchAtLogin
        self.actions = actions
    }

    public var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { general }
            Tab("Rules", systemImage: "slider.horizontal.3") { rules }
            Tab("Folders", systemImage: "folder") { FoldersPane(roots: roots, never: never, actions: actions) }
            Tab("History", systemImage: "clock") { HistoryPane(points: history) }
        }
        .frame(width: 640, height: 520)
    }

    private var general: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
            LabeledContent("Next sweep") {
                Text(nextSweep.map { $0 <= .now ? "When idle" : $0.formatted(date: .abbreviated, time: .shortened) } ?? "Not scheduled")
            }
            LabeledContent("Config file") {
                Button("Open", action: actions.openConfig)
            }
            LabeledContent("Activity log") {
                Button("Open", action: actions.openLog)
            }
            LabeledContent(about.version) {
                if let status = about.updateStatus {
                    HStack(spacing: 10) {
                        Text(status).foregroundStyle(.secondary)
                        if about.canInstall {
                            Button("Install", action: actions.installUpdate).disabled(about.isBusy)
                        } else {
                            Button("Check for updates", action: actions.checkForUpdates).disabled(about.isBusy)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private var rules: some View {
        Form {
            ForEach(sections) { section in
                Section(section.id) {
                    ForEach(section.rows) { RuleLine(row: $0, actions: actions) }
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct RuleLine: View {
    let row: RuleRow
    let actions: SettingsActions

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

private struct FoldersPane: View {
    let roots: [String]
    let never: [String]
    let actions: SettingsActions

    @State private var picking: Target?

    private enum Target { case root, never }

    var body: some View {
        Form {
            list("Code folders", paths: roots, add: .root, remove: actions.removeRoot)
            list("Never touch", paths: never, add: .never, remove: actions.removeNever)
        }
        .formStyle(.grouped)
        .fileImporter(
            isPresented: Binding(get: { picking != nil }, set: { if !$0 { picking = nil } }),
            allowedContentTypes: [.folder]
        ) { result in
            guard case let .success(url) = result else { return }
            picking == .root ? actions.addRoot(url) : actions.addNever(url)
        }
    }

    private func list(_ title: String, paths: [String], add: Target, remove: @escaping (String) -> Void) -> some View {
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

private struct HistoryPane: View {
    let points: [HistoryPoint]

    var body: some View {
        if points.isEmpty {
            ContentUnavailableView("No sweeps yet", systemImage: "clock")
        } else {
            VStack(alignment: .leading, spacing: 14) {
                BigNumber(bytes: points.reduce(0) { $0 + $1.bytes }, caption: "Freed in total")
                HistoryChart(points).frame(height: 150)
                List(points.reversed()) { point in
                    HStack {
                        Text(point.date.formatted(date: .abbreviated, time: .shortened))
                        Text(point.scheduled ? "weekly" : "manual").foregroundStyle(.secondary)
                        Spacer()
                        Text(Theme.bytes(point.bytes)).monospacedDigit()
                    }
                }
            }
            .padding(20)
        }
    }
}
