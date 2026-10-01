import AppKit
import MulchCore
import Observation

@Observable
final class AppStore {
    private(set) var config: Config
    private(set) var report: ScanReport?
    private(set) var history: [Run]
    private(set) var isScanning = false
    private(set) var isCleaning = false
    private(set) var message: String?
    private(set) var needsFullDiskAccess = false
    private(set) var diskFree: Int64?
    private(set) var launchAtLogin = LoginItem.isEnabled
    private(set) var skipped: Set<String> = []

    let engine: Engine
    @ObservationIgnored private let configFile = JSONFile.config(folder: Channel.current.slug)
    @ObservationIgnored private let historyFile = JSONFile.history(folder: Channel.current.displayName)
    @ObservationIgnored private var scanTask: Task<ScanReport, Never>?
    @ObservationIgnored private var pendingRescan: Task<Void, Never>?
    @ObservationIgnored private var scheduler: SweepScheduler?

    static let staleAfter: TimeInterval = 60 * 60

    init(engine: Engine = Engine(probe: WorkspaceProbe())) {
        self.engine = engine
        config = configFile.load { error, aside in
            Log.error("config: unreadable, moved to \(aside.path), using defaults: \(error)")
        }
        history = historyFile.load { error, aside in
            Log.error("history: unreadable, moved to \(aside.path): \(error)")
        }
        Log.info("config: loaded \(configFile.url.path), onboarded \(config.onboarded), every \(config.intervalDays) days, roots \(config.codeRoots), never \(config.never)")
        Log.info("history: loaded \(history.count) runs from \(historyFile.url.path)")
        Log.info("engine: \(engine.rules.count) rules, \(config.effective(engine.rules).filter { $0.mode != .off }.count) active")
        scheduler = SweepScheduler { [weak self] in await self?.runScheduledIfDue() }
        if !config.onboarded {
            Log.info("onboarding: first run, detecting code folders")
            Task {
                await detectRoots()
                await scan(reason: "first run")
            }
        }
    }

    var inbox: [Finding] {
        report?.askFindings.filter { !skipped.contains($0.id) } ?? []
    }

    var nextSweep: Date? {
        config.onboarded ? SweepSchedule.nextDate(history: history, intervalDays: config.intervalDays, now: .now) : nil
    }

    func refreshIfStale() {
        reloadConfig()
        guard !isScanning else { return }
        guard let report else {
            Task { await scan(reason: "no results yet") }
            return
        }
        let age = Date.now.timeIntervalSince(report.date)
        guard age >= Self.staleAfter else { return }
        Task { await scan(reason: "results are \(Int(age / 60)) min old") }
    }

    func rescan() async {
        Log.info("action: rescan, \(skipped.count) skipped items return")
        skipped = []
        message = nil
        await scan(reason: "Rescan")
    }

    @discardableResult
    func scan(reason: String, fresh: Bool = false) async -> ScanReport {
        if fresh, let scanTask {
            scanTask.cancel()
            self.scanTask = nil
            Log.info("scan: cancelled the running scan, it started before the disk changed")
        }
        if scanTask != nil { Log.info("scan: joining the running scan (\(reason))") }
        let task = scanTask ?? startScan(reason: reason)
        let result = await task.value
        if task.isCancelled {
            if scanTask != nil { return await scan(reason: reason) }
            return report ?? result
        }
        if scanTask == task { apply(result) }
        return result
    }

    private func startScan(reason: String) -> Task<ScanReport, Never> {
        isScanning = true
        Log.info("scan: started (\(reason)), roots \(config.codeRoots)")
        let engine = engine
        let config = config
        let showPartial = report == nil
        let task = Task.detached(priority: .background) {
            await engine.scan(config: config) { partial in
                guard showPartial, !Task.isCancelled else { return }
                await self.receive(partial)
            }
        }
        scanTask = task
        return task
    }

    private func apply(_ result: ScanReport) {
        scanTask = nil
        report = result
        skipped.formIntersection(result.rules.flatMap(\.findings).map(\.id))
        isScanning = false
        diskFree = DiskSpace.available()
        for rule in result.rules where !rule.findings.isEmpty || rule.note != nil {
            let note = rule.note.map { ", \($0)" } ?? ""
            Log.info("scan: \(rule.id) [\(rule.rule.mode.rawValue)] \(rule.findings.count) items, \(bytes(rule.totalBytes)), \(bytes(rule.eligibleBytes)) ready\(note)")
        }
        let seconds = Date.now.timeIntervalSince(result.date).formatted(.number.precision(.fractionLength(1)))
        let findings = result.rules.reduce(0) { $0 + $1.findings.count }
        Log.info("scan: finished in \(seconds)s, \(result.rules.count) rules, \(findings) items, \(bytes(result.autoBytes)) ready, \(result.askFindings.count) asking, disk free \(diskFree.map(bytes) ?? "unknown")")
    }

    private func receive(_ partial: RuleReport) {
        report = ScanReport(date: report?.date ?? .now, rules: (report?.rules ?? []) + [partial])
    }

    private func scheduleRescan() {
        pendingRescan?.cancel()
        pendingRescan = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if let scanTask { _ = await scanTask.value }
            await scan(reason: "settings changed")
        }
    }

    func cleanAuto() async {
        Log.info("action: clean all ready items")
        let report = await currentReport()
        await clean(report.autoFindings, from: report, trigger: .manual)
    }

    func cleanRule(_ ruleID: String) async {
        Log.info("action: clean rule \(ruleID)")
        guard let report, let rule = report.report(for: ruleID) else { return }
        await clean(rule.eligible, from: report, trigger: .manual)
    }

    func clean(itemIDs: Set<String>) async {
        Log.info("action: clean \(itemIDs.sorted())")
        guard let report else { return }
        let findings = report.rules.flatMap(\.findings).filter { itemIDs.contains($0.id) }
        await clean(findings, from: report, trigger: .manual)
    }

    func skip(_ id: String) {
        Log.info("action: skip \(id)")
        skipped.insert(id)
    }

    func finding(_ id: String) -> Finding? {
        report?.rules.lazy.flatMap(\.findings).first { $0.id == id }
    }

    func reveal(_ id: String) {
        guard let url = finding(id)?.url else { return }
        Log.info("action: reveal \(url.path)")
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func clean(_ findings: [Finding], from report: ScanReport, trigger: Run.Trigger) async {
        guard !isCleaning else {
            Log.info("clean: ignored, a clean is already running")
            return
        }
        guard !findings.isEmpty else {
            Log.info("clean: nothing ready to clean")
            return
        }
        isCleaning = true
        message = nil
        let total = findings.reduce(0) { $0 + $1.bytes }
        Log.info("clean (\(trigger.rawValue)): started, \(findings.count) items, \(bytes(total))")
        let outcome = await Task.detached(priority: .utility) { [engine, config] in
            await engine.cleaner.clean(findings, from: report, config: config)
        }.value
        isCleaning = false
        finish(outcome, trigger: trigger)
        await scan(reason: "after clean", fresh: true)
    }

    private func finish(_ outcome: Outcome, trigger: Run.Trigger) {
        record(Run(date: .now, trigger: trigger, outcome: outcome))
        for title in outcome.removed { Log.info("clean: removed \(title)") }
        for skip in outcome.skipped { Log.info("clean: skipped \(skip.title): \(skip.reason)") }
        for failure in outcome.failures { Log.error("clean: failed \(failure.title): \(failure.reason)") }
        if outcome.needsFullDiskAccess { Log.error("clean: macOS refused a delete, Full Disk Access is needed") }
        report = report?.removing(outcome.gone)
        diskFree = DiskSpace.available()
        needsFullDiskAccess = outcome.needsFullDiskAccess
        Log.info("clean (\(trigger.rawValue)): finished, freed \(bytes(outcome.freedBytes)), removed \(outcome.removed.count), \(outcome.gone.count - outcome.removed.count) already gone, \(outcome.skipped.count) skipped, \(outcome.failures.count) failed, disk free \(diskFree.map(bytes) ?? "unknown")")
        message = if outcome.freedBytes > 0 {
            "Freed \(bytes(outcome.freedBytes))"
        } else if let failure = outcome.failures.first {
            "Could not clean: \(failure.reason)"
        } else if let skip = outcome.skipped.first {
            "Skipped: \(skip.reason)"
        } else if !outcome.gone.isEmpty {
            "Already cleaned"
        } else {
            "Nothing to free"
        }
    }

    private func currentReport() async -> ScanReport {
        if let report, Date.now.timeIntervalSince(report.date) < Self.staleAfter { return report }
        return await scan(reason: "results too old to clean from")
    }

    func runScheduledIfDue() async {
        let next = SweepSchedule.nextDate(history: history, intervalDays: config.intervalDays, now: .now)
        guard config.onboarded, !isCleaning, next <= .now else {
            Log.info("sweep: woke, not due (onboarded \(config.onboarded), cleaning \(isCleaning), next \(next.ISO8601Format()))")
            return
        }
        Log.info("sweep: due, scanning first")
        let report = await scan(reason: "weekly sweep")
        guard !isCleaning else {
            Log.info("sweep: postponed, a manual clean started")
            return
        }
        isCleaning = true
        Log.info("clean (scheduled): started, \(report.autoFindings.count) items, \(bytes(report.autoBytes))")
        let outcome = await Task.detached(priority: .background) { [engine, config] in
            await engine.sweep(report, config: config)
        }.value
        isCleaning = false
        finish(outcome, trigger: .scheduled)
        let updated = await scan(reason: "after weekly sweep", fresh: true)

        let waiting = updated.askFindings.count
        guard outcome.freedBytes > 0 || waiting > 0 else { return }
        var lines: [String] = []
        if outcome.freedBytes > 0 { lines.append("Freed \(bytes(outcome.freedBytes)).") }
        if waiting > 0 { lines.append("\(waiting) item\(waiting == 1 ? "" : "s") need you.") }
        await Notifier.post("Mulch swept your Mac", body: lines.joined(separator: " "))
    }

    func setMode(_ mode: Mode, ruleID: String) {
        guard let rule = rule(ruleID) else { return }
        Log.info("settings: \(ruleID) mode \(mode.rawValue)")
        update { $0.setMode(mode, for: rule) }
    }

    func setMinAge(_ days: Int?, ruleID: String) {
        guard let rule = rule(ruleID) else { return }
        Log.info("settings: \(ruleID) idle days \(days.map(String.init) ?? "default")")
        update { $0.setMinAge(days, for: rule) }
    }

    func setGroup(_ group: RuleGroup, enabled: Bool) {
        Log.info("settings: group \(group.rawValue) \(enabled ? "on" : "off")")
        update { config in
            for rule in engine.rules where rule.group == group {
                config.setMode(enabled ? rule.defaultMode : .off, for: rule)
            }
        }
    }

    func addRoot(_ url: URL) {
        let path = engine.paths.abbreviate(url)
        Log.info("settings: add code folder \(path)")
        update { if !$0.codeRoots.contains(path) { $0.codeRoots.append(path) } }
    }

    func setRoot(_ path: String, enabled: Bool) {
        Log.info("settings: code folder \(path) \(enabled ? "on" : "removed")")
        update { config in
            config.codeRoots.removeAll { $0 == path }
            if enabled { config.codeRoots.append(path) }
        }
    }

    func addNever(_ url: URL) {
        let path = engine.paths.abbreviate(url)
        Log.info("settings: never touch \(path)")
        update { if !$0.never.contains(path) { $0.never.append(path) } }
    }

    func removeNever(_ path: String) {
        Log.info("settings: allow \(path) again")
        update { $0.never.removeAll { $0 == path } }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LoginItem.set(enabled)
        launchAtLogin = LoginItem.isEnabled
    }

    func openConfigFile() {
        if !FileManager.default.fileExists(atPath: configFile.url.path) { save() }
        Log.info("action: open \(configFile.url.path)")
        NSWorkspace.shared.open(configFile.url)
    }

    private func detectRoots() async {
        let detector = engine.detector
        let roots = await Task.detached(priority: .utility) { detector.codeRoots() }.value
        Log.info("onboarding: found code folders \(roots.map(\.path))")
        guard !roots.isEmpty else { return }
        update(rescan: false) { $0.codeRoots = roots.map(\.path) }
    }

    func finishOnboarding() async {
        Log.info("onboarding: finished")
        update { $0.onboarded = true }
        setLaunchAtLogin(true)
        await Notifier.requestPermission()
    }

    private func update(rescan: Bool = true, _ change: (inout Config) -> Void) {
        var next = config
        change(&next)
        guard next != config else { return }
        config = next
        save()
        if rescan { scheduleRescan() }
    }

    private func reloadConfig() {
        let onDisk = configFile.load { error, aside in
            Log.error("config: unreadable after a hand edit, moved to \(aside.path): \(error)")
        }
        if onDisk != config, FileManager.default.fileExists(atPath: configFile.url.path) {
            Log.info("config: reloaded hand edits from \(configFile.url.path)")
            config = onDisk
            report = nil
        }
    }

    private func save() {
        do {
            try configFile.save(config)
            Log.info("config: saved \(configFile.url.path)")
        } catch {
            Log.error("config: could not save \(configFile.url.path): \(error.localizedDescription)")
            message = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func record(_ run: Run) {
        history = Array((history + [run]).suffix(JSONFile<[Run]>.historyLimit))
        do {
            try historyFile.save(history)
        } catch {
            Log.error("history: could not save \(historyFile.url.path): \(error.localizedDescription)")
        }
    }

    private func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file))
    }

    private func rule(_ id: String) -> Rule? {
        engine.rules.first { $0.id == id }
    }
}
