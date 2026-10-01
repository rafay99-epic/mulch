import SwiftUI

public enum Theme {
    public static let background = Color.black
    public static let auto = Color.green
    public static let ask = Color.orange
    public static let off = Color.gray
    public static let track = Color.white.opacity(0.08)

    public static func tint(_ mode: CleanMode) -> Color {
        switch mode {
        case .auto: auto
        case .ask: ask
        case .off: off
        }
    }

    public static func bytes(_ value: Int64) -> String {
        value == 0 ? "0 KB" : value.formatted(.byteCount(style: .file))
    }
}

public struct SizeBar: View {
    let fraction: Double
    let tint: Color

    public init(fraction: Double, tint: Color = .white) {
        self.fraction = fraction
        self.tint = tint
    }

    public var body: some View {
        Capsule()
            .fill(Theme.track)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(tint)
                    .scaleEffect(x: min(max(fraction, 0), 1), anchor: .leading)
            }
            .frame(height: 5)
            .accessibilityHidden(true)
    }
}

public struct ModeBadge: View {
    let mode: CleanMode

    public init(_ mode: CleanMode) { self.mode = mode }

    public var body: some View {
        Label(mode.title, systemImage: symbol)
            .labelStyle(.titleAndIcon)
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(Theme.tint(mode))
            .imageScale(.small)
    }

    private var symbol: String {
        switch mode {
        case .auto: "circle.fill"
        case .ask: "triangle.fill"
        case .off: "circle"
        }
    }
}

public struct ModePicker: View {
    @Binding var selection: CleanMode

    public init(selection: Binding<CleanMode>) { _selection = selection }

    public var body: some View {
        Picker("Mode", selection: $selection) {
            ForEach(CleanMode.allCases) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }
}

public struct BigNumber: View {
    let bytes: Int64
    let caption: String

    public init(bytes: Int64, caption: String) {
        self.bytes = bytes
        self.caption = caption
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(Theme.bytes(bytes))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(caption).font(.callout).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

public struct StatRow: View {
    let label: String
    let value: String
    let tint: Color

    public init(_ label: String, value: String, tint: Color = .primary) {
        self.label = label
        self.value = value
        self.tint = tint
    }

    public var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).monospacedDigit().foregroundStyle(tint)
        }
        .font(.callout)
    }
}

public struct BarRow: View {
    let item: BarItem
    let maxBytes: Int64

    public init(_ item: BarItem, maxBytes: Int64) {
        self.item = item
        self.maxBytes = maxBytes
    }

    public var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(item.title).lineLimit(1)
                if item.mode != .auto { ModeBadge(item.mode) }
                Spacer()
                Text(Theme.bytes(item.bytes)).monospacedDigit()
            }
            .font(.callout)
            SizeBar(
                fraction: maxBytes > 0 ? Double(item.bytes) / Double(maxBytes) : 0,
                tint: item.mode == .auto ? .white : Theme.tint(item.mode)
            )
        }
        .accessibilityElement(children: .combine)
    }
}

public struct InboxRow: View {
    let item: InboxItem
    let onClean: () -> Void
    let onSkip: () -> Void

    public init(_ item: InboxItem, onClean: @escaping () -> Void, onSkip: @escaping () -> Void) {
        self.item = item
        self.onClean = onClean
        self.onSkip = onSkip
    }

    public var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title).lineLimit(1)
                Text(item.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Text(Theme.bytes(item.bytes)).monospacedDigit().font(.callout)
            Button("Clean", action: onClean).buttonStyle(.glassProminent).controlSize(.small)
            Button("Skip", action: onSkip).buttonStyle(.borderless).controlSize(.small)
        }
    }
}
