import Foundation

// Plain values the screens render. MulchUI does not import MulchCore; the app
// target maps engine results into these, so views stay dumb and previewable.

public enum CleanMode: String, CaseIterable, Identifiable, Sendable {
    case auto, ask, off

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum Page: String, CaseIterable, Identifiable, Sendable {
    case overview, inbox, rules, history

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
    public var symbol: String {
        switch self {
        case .overview: "chart.bar.xaxis"
        case .inbox: "tray"
        case .rules: "slider.horizontal.3"
        case .history: "clock.arrow.circlepath"
        }
    }
}

/// One rule as a proportional bar.
public struct BarItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let bytes: Int64
    public let mode: CleanMode

    public init(id: String, title: String, bytes: Int64, mode: CleanMode) {
        self.id = id
        self.title = title
        self.bytes = bytes
        self.mode = mode
    }
}

/// Something waiting for approval.
public struct InboxItem: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let bytes: Int64

    public init(id: String, title: String, detail: String, bytes: Int64) {
        self.id = id
        self.title = title
        self.detail = detail
        self.bytes = bytes
    }
}

/// One row of the overview table.
public struct LedgerRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let group: String
    public let bytes: Int64
    public let mode: CleanMode
    public let status: String

    public init(id: String, title: String, group: String, bytes: Int64, mode: CleanMode, status: String) {
        self.id = id
        self.title = title
        self.group = group
        self.bytes = bytes
        self.mode = mode
        self.status = status
    }
}

public struct RuleRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let mode: CleanMode
    public let minAgeDays: Int?
    /// Current size, if scanned.
    public let bytes: Int64?

    public init(id: String, title: String, mode: CleanMode, minAgeDays: Int?, bytes: Int64?) {
        self.id = id
        self.title = title
        self.mode = mode
        self.minAgeDays = minAgeDays
        self.bytes = bytes
    }
}

public struct RuleSection: Identifiable, Hashable, Sendable {
    public let id: String
    public let rows: [RuleRow]

    public init(title: String, rows: [RuleRow]) {
        id = title
        self.rows = rows
    }
}

public struct HistoryPoint: Identifiable, Hashable, Sendable {
    public let date: Date
    public let bytes: Int64
    public let scheduled: Bool
    public var id: Date { date }

    public init(date: Date, bytes: Int64, scheduled: Bool) {
        self.date = date
        self.bytes = bytes
        self.scheduled = scheduled
    }
}

/// A detection line in onboarding.
public struct ToolStatus: Identifiable, Hashable, Sendable {
    public enum State: Sendable { case found, missing }
    public let name: String
    public let state: State
    public var id: String { name }

    public init(name: String, state: State) {
        self.name = name
        self.state = state
    }
}

/// A selectable entry in onboarding: a code folder or a rule group.
public struct Choice: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let detail: String
    public let enabled: Bool

    public init(id: String, title: String, detail: String, enabled: Bool) {
        self.id = id
        self.title = title
        self.detail = detail
        self.enabled = enabled
    }
}

public struct PopoverModel: Sendable {
    public var reclaimable: Int64 = 0
    public var bars: [BarItem] = []
    public var inbox: [InboxItem] = []
    public var nextSweep: Date?
    public var freedThisMonth: Int64 = 0
    public var diskFree: Int64?
    public var isScanning = false
    public var isCleaning = false
    /// Result of the last action, e.g. "Freed 12.3 GB".
    public var message: String?
    public var needsFullDiskAccess = false

    public init() {}
}
