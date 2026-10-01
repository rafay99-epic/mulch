import Foundation

// View models for the main window, settings and first run.

/// A rule in the sidebar.
public struct RuleListItem: Identifiable, Hashable, Sendable {
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

public struct RuleListSection: Identifiable, Hashable, Sendable {
    public let id: String
    public let items: [RuleListItem]

    public init(title: String, items: [RuleListItem]) {
        id = title
        self.items = items
    }
}

/// The selected rule, shown above its items.
public struct RuleSummary: Hashable, Sendable {
    public let id: String
    public let title: String
    public let mode: CleanMode
    public let readyBytes: Int64
    public let readyCount: Int
    /// Why this rule's items are safe to remove.
    public let why: String

    public init(id: String, title: String, mode: CleanMode, readyBytes: Int64, readyCount: Int, why: String) {
        self.id = id
        self.title = title
        self.mode = mode
        self.readyBytes = readyBytes
        self.readyCount = readyCount
        self.why = why
    }
}

/// One item of the selected rule.
public struct ItemRow: Identifiable, Hashable, Sendable {
    public let id: String
    /// Path relative to the rule's folder.
    public let title: String
    public let bytes: Int64
    public let status: String
    public let ready: Bool

    public init(id: String, title: String, bytes: Int64, status: String, ready: Bool) {
        self.id = id
        self.title = title
        self.bytes = bytes
        self.status = status
        self.ready = ready
    }
}

/// Everything known about the selected item.
public struct ItemDetail: Hashable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public let folder: String?
    public let bytes: Int64
    public let lastUsed: Date?
    public let rule: String
    public let why: String
    public let status: String
    public let ready: Bool
    public let mode: CleanMode
    public let canReveal: Bool

    public init(
        id: String, name: String, path: String, folder: String?, bytes: Int64, lastUsed: Date?,
        rule: String, why: String, status: String, ready: Bool, mode: CleanMode, canReveal: Bool
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.folder = folder
        self.bytes = bytes
        self.lastUsed = lastUsed
        self.rule = rule
        self.why = why
        self.status = status
        self.ready = ready
        self.mode = mode
        self.canReveal = canReveal
    }
}

/// A rule group on the first-run screen.
public struct FirstRunRow: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Short note in orange, e.g. "asks first" or "not running".
    public let tag: String?
    public let bytes: Int64
    /// The scan has finished this group.
    public let done: Bool
    public let enabled: Bool

    public init(id: String, title: String, tag: String?, bytes: Int64, done: Bool, enabled: Bool) {
        self.id = id
        self.title = title
        self.tag = tag
        self.bytes = bytes
        self.done = done
        self.enabled = enabled
    }
}
