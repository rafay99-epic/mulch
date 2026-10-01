import SwiftUI

public struct OnboardingActions {
    public var toggleRoot: (String, Bool) -> Void
    public var addRoot: (URL) -> Void
    public var toggleGroup: (String, Bool) -> Void
    public var review: () -> Void
    public var finish: () -> Void

    public init(
        toggleRoot: @escaping (String, Bool) -> Void,
        addRoot: @escaping (URL) -> Void,
        toggleGroup: @escaping (String, Bool) -> Void,
        review: @escaping () -> Void,
        finish: @escaping () -> Void
    ) {
        self.toggleRoot = toggleRoot
        self.addRoot = addRoot
        self.toggleGroup = toggleGroup
        self.review = review
        self.finish = finish
    }
}

/// First run in three steps: tools found, code folders, review what gets cleaned.
public struct OnboardingScreen: View {
    let tools: [ToolStatus]
    let roots: [Choice]
    let groups: [Choice]
    let reclaimable: Int64
    let isScanning: Bool
    let actions: OnboardingActions

    @State private var step = 0
    @State private var addingRoot = false

    private static let steps = ["Tools", "Code folders", "Review"]

    public init(
        tools: [ToolStatus], roots: [Choice], groups: [Choice], reclaimable: Int64,
        isScanning: Bool, actions: OnboardingActions
    ) {
        self.tools = tools
        self.roots = roots
        self.groups = groups
        self.reclaimable = reclaimable
        self.isScanning = isScanning
        self.actions = actions
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 16) {
                ForEach(Self.steps.indices, id: \.self) { index in
                    Text("\(index + 1) \(Self.steps[index])")
                        .font(.callout.monospaced())
                        .foregroundStyle(index == step ? .primary : .secondary)
                }
            }

            Group {
                switch step {
                case 0: toolsStep
                case 1: rootsStep
                default: reviewStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            HStack {
                if step > 0 { Button("Back") { step -= 1 } }
                Spacer()
                if step < 2 {
                    Button("Continue") {
                        step += 1
                        if step == 2 { actions.review() }
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button("Start weekly sweep", action: actions.finish)
                        .buttonStyle(.glassProminent)
                        .disabled(isScanning)
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .fileImporter(isPresented: $addingRoot, allowedContentTypes: [.folder]) { result in
            if case let .success(url) = result { actions.addRoot(url) }
        }
    }

    private var toolsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Found on this Mac").font(.title2.weight(.semibold))
            ForEach(tools) { ToolStatusRow($0) }
        }
    }

    private var rootsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Where your code lives").font(.title2.weight(.semibold))
            Text("Build output in these folders is cleaned once a project has been idle for 14 days.")
                .foregroundStyle(.secondary)
            ForEach(roots) { root in
                ChoiceRow(root) { actions.toggleRoot(root.id, $0) }
            }
            Button("Add folder…") { addingRoot = true }.buttonStyle(.borderless)
        }
    }

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            BigNumber(bytes: reclaimable, caption: isScanning ? "Scanning…" : "Cleaned on the first sweep")
            ForEach(groups) { group in
                ChoiceRow(group) { actions.toggleGroup(group.id, $0) }
            }
            Text("T3 worktrees, emulators and simulators are never touched.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }
}
