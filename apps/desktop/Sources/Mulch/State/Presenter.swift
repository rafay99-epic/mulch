import Foundation
import MulchCore
import MulchUI

/// Maps engine values to the plain view models MulchUI renders. Pure functions,
/// the only place that knows both sides.
enum Presenter {
    static func mode(_ mode: Mode) -> CleanMode {
        switch mode {
        case .auto: .auto
        case .ask: .ask
        case .off: .off
        }
    }

    static func mode(_ mode: CleanMode) -> Mode {
        switch mode {
        case .auto: .auto
        case .ask: .ask
        case .off: .off
        }
    }

    static func popover(_ store: AppStore) -> PopoverModel {
        var model = PopoverModel()
        model.reclaimable = store.report?.autoBytes ?? 0
        model.bars = bars(store.report)
        model.inbox = inbox(store.inbox, report: store.report)
        model.nextSweep = store.nextSweep
        model.freedThisMonth = freedThisMonth(store.history)
        model.diskFree = store.diskFree
        model.isScanning = store.isScanning
        model.isCleaning = store.isCleaning
        model.message = store.message
        model.needsFullDiskAccess = store.needsFullDiskAccess
        return model
    }

    /// The five rules with the most to clean now.
    static func bars(_ report: ScanReport?) -> [BarItem] {
        (report?.rules ?? [])
            .filter { $0.rule.mode != .off && $0.eligibleBytes > 0 }
            .sorted { $0.eligibleBytes > $1.eligibleBytes }
            .prefix(5)
            .map { BarItem(id: $0.id, title: $0.rule.rule.title, bytes: $0.eligibleBytes, mode: mode($0.rule.mode)) }
    }

    static func inbox(_ findings: [Finding], report: ScanReport?) -> [InboxItem] {
        findings.map { finding in
            InboxItem(
                id: finding.id,
                title: report?.report(for: finding.ruleID)?.rule.rule.title ?? finding.ruleID,
                detail: finding.title,
                bytes: finding.bytes
            )
        }
    }

    static func ledger(_ report: ScanReport?) -> [LedgerRow] {
        (report?.rules ?? [])
            .filter { !$0.findings.isEmpty || $0.note != nil }
            .sorted { $0.totalBytes > $1.totalBytes }
            .map { rule in
                LedgerRow(
                    id: rule.id, title: rule.rule.rule.title, group: rule.rule.rule.group.title,
                    bytes: rule.totalBytes, mode: mode(rule.rule.mode), status: status(rule)
                )
            }
    }

    static func status(_ report: RuleReport) -> String {
        let ready = report.eligible.count
        if ready > 0 {
            let noun = ready == 1 ? "item" : "items"
            return report.rule.mode == .ask ? "\(ready) \(noun) waiting" : "\(ready) \(noun) ready"
        }
        if let note = report.note { return note }
        switch report.findings.first?.status {
        case let .blocked(reason): return reason
        case let .tooRecent(days): return "used \(days)d ago"
        default: return "nothing to clean"
        }
    }

    static func ruleSections(_ store: AppStore) -> [RuleSection] {
        let effective = store.config.effective(store.engine.rules)
        return RuleGroup.allCases.compactMap { group in
            let rows = effective.filter { $0.rule.group == group }.map { rule in
                RuleRow(
                    id: rule.id, title: rule.rule.title, mode: mode(rule.mode),
                    minAgeDays: rule.minAgeDays, bytes: store.report?.report(for: rule.id)?.totalBytes
                )
            }
            return rows.isEmpty ? nil : RuleSection(title: group.title, rows: rows)
        }
    }

    static func history(_ runs: [Run]) -> [HistoryPoint] {
        runs.map { HistoryPoint(date: $0.date, bytes: $0.freedBytes, scheduled: $0.trigger == .scheduled) }
    }

    static func freedThisMonth(_ runs: [Run], now: Date = .now) -> Int64 {
        runs.filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.freedBytes }
    }

    static func tools(_ tools: [DetectedTool]) -> [ToolStatus] {
        tools.map { ToolStatus(name: $0.name, state: $0.installed ? .found : .missing) }
    }

    static func rootChoices(_ store: AppStore) -> [Choice] {
        let repos = Dictionary(store.suggestedRoots.map { ($0.path, $0.repos) }, uniquingKeysWith: { first, _ in first })
        let paths = store.suggestedRoots.map(\.path) + store.config.codeRoots.filter { repos[$0] == nil }
        return paths.map { path in
            Choice(
                id: path, title: path,
                detail: repos[path].map { "\($0) repos" } ?? "",
                enabled: store.config.codeRoots.contains(path)
            )
        }
    }

    static func groupChoices(_ store: AppStore) -> [Choice] {
        let effective = store.config.effective(store.engine.rules)
        return RuleGroup.allCases.compactMap { group in
            let rules = effective.filter { $0.rule.group == group }
            guard !rules.isEmpty else { return nil }
            let bytes = rules.compactMap { store.report?.report(for: $0.id)?.eligibleBytes }.reduce(0, +)
            return Choice(
                id: group.rawValue, title: group.title,
                detail: store.report == nil ? "" : bytes.formatted(.byteCount(style: .file)),
                enabled: rules.contains { $0.mode != .off }
            )
        }
    }
}
