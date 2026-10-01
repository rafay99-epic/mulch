import Foundation

// Plain values the screens render. MulchUI does not import MulchCore; the app
// target maps engine results into these, so views stay dumb and previewable.

public enum CleanMode: String, CaseIterable, Identifiable, Sendable {
    case auto, ask, off

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
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
    /// A newer build ready to install, e.g. "42".
    public var update: String?

    public init() {}
}

/// Version and update state for Settings.
public struct AboutModel: Sendable {
    /// e.g. "Mulch 42".
    public var version: String
    /// `nil` when this build does not update itself (Dev).
    public var updateStatus: String?
    public var canInstall: Bool
    public var isBusy: Bool

    public init(version: String, updateStatus: String?, canInstall: Bool, isBusy: Bool) {
        self.version = version
        self.updateStatus = updateStatus
        self.canInstall = canInstall
        self.isBusy = isBusy
    }
}
