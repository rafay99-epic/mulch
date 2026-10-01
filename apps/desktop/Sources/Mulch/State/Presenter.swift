import Foundation
import MulchCore
import MulchUI

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

    static func popover(_ store: AppStore, updater: Updater) -> PopoverModel {
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
        model.update = updater.available.map { String($0.version) }
        return model
    }

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

    static func freedThisMonth(_ runs: [Run], now: Date = .now) -> Int64 {
        runs.filter { Calendar.current.isDate($0.date, equalTo: now, toGranularity: .month) }
            .reduce(0) { $0 + $1.freedBytes }
    }

    static func ruleList(_ report: ScanReport?) -> [RuleListSection] {
        let visible = (report?.rules ?? []).filter { !$0.findings.isEmpty }.sorted { $0.totalBytes > $1.totalBytes }
        return [("Weekly", Mode.auto), ("Asks first", Mode.ask)].compactMap { title, mode in
            let items = visible.filter { $0.rule.mode == mode }.map {
                RuleListItem(id: $0.id, title: $0.rule.rule.title, bytes: $0.totalBytes, mode: self.mode(mode))
            }
            return items.isEmpty ? nil : RuleListSection(title: title, items: items)
        }
    }

    static func summary(_ rule: RuleReport) -> RuleSummary {
        RuleSummary(
            id: rule.id, title: rule.rule.rule.title, mode: mode(rule.rule.mode),
            readyBytes: rule.eligibleBytes, readyCount: rule.eligible.count, why: why(rule.rule)
        )
    }

    static func items(_ rule: RuleReport, skipped: Set<String>) -> [ItemRow] {
        rule.findings.map { finding in
            let isSkipped = skipped.contains(finding.id)
            return ItemRow(
                id: finding.id, title: relativeTitle(finding), bytes: finding.bytes,
                status: isSkipped ? "skipped" : status(finding.status),
                ready: finding.isEligible && !isSkipped
            )
        }
    }

    static func detail(_ finding: Finding, rule: RuleReport, paths: Paths, skipped: Set<String>) -> ItemDetail {
        let isSkipped = skipped.contains(finding.id)
        return ItemDetail(
            id: finding.id,
            name: finding.url?.lastPathComponent ?? finding.title,
            path: finding.title,
            folder: finding.url.map { paths.abbreviate($0.deletingLastPathComponent()) },
            bytes: finding.bytes,
            lastUsed: finding.newest,
            rule: rule.rule.rule.title,
            why: why(rule.rule),
            status: isSkipped ? "skipped until you rescan" : status(finding.status),
            ready: finding.isEligible && !isSkipped,
            mode: mode(rule.rule.mode),
            canReveal: finding.url != nil
        )
    }

    static func why(_ rule: EffectiveRule) -> String {
        var parts: [String] = []
        switch rule.rule.target {
        case .projectArtifacts: parts.append("Project output, rebuilt by your tools")
        case .keepNewest: parts.append("Older version, the newest is kept")
        case let .command(spec): parts.append("Runs \(([spec.tool] + spec.clean).joined(separator: " "))")
        case .paths: parts.append("Cache, rebuilt when needed")
        }
        if let days = rule.minAgeDays, days > 0 { parts.append("unused for \(days)+ days") }
        let apps = rule.rule.blockers.compactMap { blocker -> String? in
            switch blocker {
            case let .app(_, name), let .appPrefix(_, name), let .process(_, name): name
            case .itemBundleID: "its app"
            }
        }
        if !apps.isEmpty { parts.append("only while \(apps.joined(separator: " and ")) is closed") }
        return parts.joined(separator: ", ")
    }

    static func status(_ status: Finding.Status) -> String {
        switch status {
        case .eligible: "ready"
        case let .tooRecent(days): days == 0 ? "used today" : "used \(days)d ago"
        case let .blocked(reason): reason
        }
    }

    static func relativeTitle(_ finding: Finding) -> String {
        guard let path = finding.url?.path, let root = finding.root?.path else { return finding.title }
        let base = root.hasSuffix("/") ? root : root + "/"
        return path.hasPrefix(base) ? String(path.dropFirst(base.count)) : finding.title
    }

    static func firstRunRows(_ store: AppStore) -> [FirstRunRow] {
        let effective = store.config.effective(store.engine.rules)
        return RuleGroup.allCases.compactMap { group in
            let rules = effective.filter { $0.rule.group == group }
            guard !rules.isEmpty else { return nil }
            let active = rules.filter { $0.mode != .off }
            let reports = active.compactMap { store.report?.report(for: $0.id) }
            let title = group == .code
                ? "Code, \(store.config.codeRoots.joined(separator: ", "))"
                : group.title
            let bytes = reports.reduce(0) { $0 + $1.eligibleBytes }
            let note = reports.compactMap(\.note).first
            let blocked = reports.flatMap(\.findings).lazy.compactMap { finding -> String? in
                if case let .blocked(reason) = finding.status { return reason }
                return nil
            }.first
            let asks = !active.isEmpty && active.allSatisfy { $0.mode == .ask }
            return FirstRunRow(
                id: group.rawValue,
                title: title,
                tag: note ?? (bytes == 0 ? blocked : nil) ?? (asks ? "asks first" : nil),
                bytes: bytes,
                done: store.report != nil && reports.count == active.count,
                enabled: !active.isEmpty
            )
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

    static func about(_ updater: Updater, isCleaning: Bool) -> AboutModel {
        AboutModel(
            version: "\(Channel.current.displayName) \(Channel.version)",
            updateStatus: Updater.isEnabled ? updater.statusText : nil,
            canInstall: updater.available != nil,
            isBusy: isCleaning || [.checking, .installing].contains(updater.status)
        )
    }

    static func history(_ runs: [Run]) -> [HistoryPoint] {
        runs.map { HistoryPoint(date: $0.date, bytes: $0.freedBytes, scheduled: $0.trigger == .scheduled) }
    }
}
