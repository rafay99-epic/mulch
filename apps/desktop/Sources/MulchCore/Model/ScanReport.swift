import Foundation

public struct Finding: Sendable, Identifiable, Hashable {
    public enum Status: Sendable, Hashable {
        case eligible
        case tooRecent(days: Int)
        case blocked(String)
    }

    public let ruleID: String
    public let url: URL?
    public let root: URL?
    public let title: String
    public let bytes: Int64
    public let newest: Date?
    public let status: Status

    public var id: String { "\(ruleID)|\(url?.path ?? title)" }
    public var isEligible: Bool { status == .eligible }

    public init(ruleID: String, url: URL?, root: URL?, title: String, bytes: Int64, newest: Date?, status: Status) {
        self.ruleID = ruleID
        self.url = url
        self.root = root
        self.title = title
        self.bytes = bytes
        self.newest = newest
        self.status = status
    }
}

public struct RuleReport: Sendable, Identifiable {
    public let rule: EffectiveRule
    public let findings: [Finding]
    public let note: String?

    public var id: String { rule.id }
    public var eligible: [Finding] { findings.filter(\.isEligible) }
    public var eligibleBytes: Int64 { eligible.reduce(0) { $0 + $1.bytes } }
    public var totalBytes: Int64 { findings.reduce(0) { $0 + $1.bytes } }

    public init(rule: EffectiveRule, findings: [Finding], note: String? = nil) {
        self.rule = rule
        self.findings = findings
        self.note = note
    }
}

public struct ScanReport: Sendable {
    public let date: Date
    public let rules: [RuleReport]

    public init(date: Date, rules: [RuleReport]) {
        self.date = date
        self.rules = rules
    }

    public func rules(in mode: Mode) -> [RuleReport] {
        rules.filter { $0.rule.mode == mode }
    }

    public var autoFindings: [Finding] { rules(in: .auto).flatMap(\.eligible) }
    public var autoBytes: Int64 { autoFindings.reduce(0) { $0 + $1.bytes } }

    public var askFindings: [Finding] { rules(in: .ask).flatMap(\.eligible) }

    public func report(for ruleID: String) -> RuleReport? {
        rules.first { $0.id == ruleID }
    }

    public func removing(_ ids: Set<String>) -> ScanReport {
        guard !ids.isEmpty else { return self }
        return ScanReport(date: date, rules: rules.map { rule in
            RuleReport(rule: rule.rule, findings: rule.findings.filter { !ids.contains($0.id) }, note: rule.note)
        })
    }
}

public struct Outcome: Sendable {
    public var freedBytes: Int64 = 0
    public var removed: [String] = []
    public var gone: Set<String> = []
    public var skipped: [(title: String, reason: String)] = []
    public var failures: [(title: String, reason: String)] = []
    public var needsFullDiskAccess = false

    public init() {}
}
