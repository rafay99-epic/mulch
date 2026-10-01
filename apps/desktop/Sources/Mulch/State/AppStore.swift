import AppKit
import MulchCore
import Observation

/// The app's single source of truth. Owns config, the latest scan and history, and
/// runs engine work off the main actor. Views read it through `Presenter`.
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
    /// Inbox items dismissed until the user rescans. Automatic scans keep them.
    private(set) var skipped: Set<String> = []

    let engine: Engine
    @ObservationIgnored private let configFile = JSONFile.config(folder: Channel.current.configFolder)
    @ObservationIgnored private let historyFile = JSONFile.history(folder: Channel.current.displayName)
    @ObservationIgnored private var scanTask: Task<ScanReport, Never>?
    @ObservationIgnored private var pendingRescan: Task<Void, Never>?
    @ObservationIgnored private var scheduler: SweepScheduler?

    /// Cached scan results are reused for this long before the popover rescans.
    static let staleAfter: TimeInterval = 60 * 60

    init(engine: Engine = Engine(probe: WorkspaceProbe())) {
        self.engine = engine
        config = configFile.load()
        history = historyFile.load()
        scheduler = SweepScheduler { [weak self] in await self?.runScheduledIfDue() }
        if !config.onboarded {
            Task {
                await detectRoots()
                await scan()
            }
        }
    }

    var inbox: [Finding] {
        report?.askFindings.filter { !skipped.contains($0.id) } ?? []
    }

    var nextSweep: Date? {
        config.onboarded ? SweepSchedule.nextDate(history: history, intervalDays: config.intervalDays, now: .now) : nil
    }

    // MARK: Scanning

    /// Picks up edits made to the config file by hand, then rescans if the cache is old.
    func refreshIfStale() {
        reloadConfig()
        guard !isScanning else { return }
        if let report, Date.now.timeIntervalSince(report.date) < Self.staleAfter { return }
        Task { await scan() }
    }

    /// The Rescan button. Also brings back skipped items.
    func rescan() async {
        skipped = []
        message = nil
        await scan()
    }

    /// Scans at background priority. Concurrent callers share one scan, unless
    /// `fresh`: then a running scan is cancelled, since it started before the disk
    /// changed. With no previous report (first run) results appear rule by rule.
    @discardableResult
    func scan(fresh: Bool = false) async -> ScanReport {
        if fresh, let scanTask {
            scanTask.cancel()
            self.scanTask = nil
            Log.info("scan: restarting, the disk changed")
        }
        let task = scanTask ?? startScan()
        let result = await task.value
        if task.isCancelled {
            // Replaced by a fresh scan: wait for that one instead of returning stale results.
            if scanTask != nil { return await scan() }
            return report ?? result
        }
        if scanTask == task { apply(result) }
        return result
    }

    private func startScan() -> Task<ScanReport, Never> {
        isScanning = true
        Log.info("scan: started")
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
        let seconds = Date.now.timeIntervalSince(result.date).formatted(.number.precision(.fractionLength(1)))
        let findings = result.rules.reduce(0) { $0 + $1.findings.count }
        Log.info("scan: \(findings) items in \(seconds)s, \(bytes(result.autoBytes)) ready, \(result.askFindings.count) asking")
    }

    private func receive(_ partial: RuleReport) {
        report = ScanReport(date: report?.date ?? .now, rules: (report?.rules ?? []) + [partial])
    }

    /// Rescans shortly after the last settings change, so a burst of edits costs one scan.
    private func scheduleRescan() {
        pendingRescan?.cancel()
        pendingRescan = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            if let scanTask { _ = await scanTask.value }
            await scan()
        }
    }

    // MARK: Cleaning

    func cleanAuto() async {
        let report = await currentReport()
        await clean(report.autoFindings, from: report, trigger: .manual)
    }

    func cleanRule(_ ruleID: String) async {
        guard let report, let rule = report.report(for: ruleID) else { return }
        await clean(rule.eligible, from: report, trigger: .manual)
    }

    func clean(itemIDs: Set<String>) async {
        guard let report else { return }
        let findings = report.rules.flatMap(\.findings).filter { itemIDs.contains($0.id) }
        await clean(findings, from: report, trigger: .manual)
    }

    func skip(_ id: String) {
        skipped.insert(id)
    }

    func finding(_ id: String) -> Finding? {
        report?.rules.lazy.flatMap(\.findings).first { $0.id == id }
    }

    func reveal(_ id: String) {
        guard let url = finding(id)?.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    private func clean(_ findings: [Finding], from report: ScanReport, trigger: Run.Trigger) async {
        guard !isCleaning, !findings.isEmpty else { return }
        isCleaning = true
        message = nil
        let outcome = await Task.detached(priority: .utility) { [engine, config] in
            await engine.cleaner.clean(findings, from: report, config: config)
        }.value
        isCleaning = false
        finish(outcome, trigger: trigger)
        await scan(fresh: true)
    }

    /// Shows the result right away: what is gone leaves the report and free space is
    /// reread. The fresh scan that follows corrects everything else.
    private func finish(_ outcome: Outcome, trigger: Run.Trigger) {
        record(Run(date: .now, trigger: trigger, outcome: outcome))
        Log.info("clean (\(trigger.rawValue)): freed \(bytes(outcome.freedBytes)), removed \(outcome.removed.count), \(outcome.gone.count - outcome.removed.count) already gone")
        for skip in outcome.skipped { Log.info("clean: skipped \(skip.title): \(skip.reason)") }
        for failure in outcome.failures { Log.error("clean: \(failure.title): \(failure.reason)") }
        report = report?.removing(outcome.gone)
        diskFree = DiskSpace.available()
        needsFullDiskAccess = outcome.needsFullDiskAccess
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
        return await scan()
    }

    /// Called by the scheduler. Sweeps Auto rules when a week has passed, then
    /// notifies once if something was freed or is waiting for approval.
    func runScheduledIfDue() async {
        guard config.onboarded, !isCleaning,
              SweepSchedule.isDue(history: history, intervalDays: config.intervalDays, now: .now)
        else { return }

        let report = await scan()
        // A manual clean may have started while this scanned.
        guard !isCleaning else { return }
        Log.info("sweep: weekly sweep started")
        isCleaning = true
        let outcome = await Task.detached(priority: .background) { [engine, config] in
            await engine.sweep(report, config: config)
        }.value
        isCleaning = false
        finish(outcome, trigger: .scheduled)
        let updated = await scan(fresh: true)

        let waiting = updated.askFindings.count
        guard outcome.freedBytes > 0 || waiting > 0 else { return }
        var lines: [String] = []
        if outcome.freedBytes > 0 { lines.append("Freed \(bytes(outcome.freedBytes)).") }
        if waiting > 0 { lines.append("\(waiting) item\(waiting == 1 ? "" : "s") need you.") }
        await Notifier.post("Mulch swept your Mac", body: lines.joined(separator: " "))
    }

    // MARK: Settings

    func setMode(_ mode: Mode, ruleID: String) {
        guard let rule = rule(ruleID) else { return }
        update { $0.setMode(mode, for: rule) }
    }

    func setMinAge(_ days: Int?, ruleID: String) {
        guard let rule = rule(ruleID) else { return }
        update { $0.setMinAge(days, for: rule) }
    }

    /// Turns a whole group on (back to defaults) or off.
    func setGroup(_ group: RuleGroup, enabled: Bool) {
        update { config in
            for rule in engine.rules where rule.group == group {
                config.setMode(enabled ? rule.defaultMode : .off, for: rule)
            }
        }
    }

    func addRoot(_ url: URL) {
        let path = engine.paths.abbreviate(url)
        update { if !$0.codeRoots.contains(path) { $0.codeRoots.append(path) } }
    }

    func setRoot(_ path: String, enabled: Bool) {
        update { config in
            config.codeRoots.removeAll { $0 == path }
            if enabled { config.codeRoots.append(path) }
        }
    }

    func addNever(_ url: URL) {
        let path = engine.paths.abbreviate(url)
        update { if !$0.never.contains(path) { $0.never.append(path) } }
    }

    func removeNever(_ path: String) {
        update { $0.never.removeAll { $0 == path } }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        LoginItem.set(enabled)
        launchAtLogin = LoginItem.isEnabled
    }

    func openConfigFile() {
        if !FileManager.default.fileExists(atPath: configFile.url.path) { save() }
        NSWorkspace.shared.open(configFile.url)
    }

    // MARK: Onboarding

    /// Uses the home folders that hold git repos as code roots, if any are found.
    private func detectRoots() async {
        let detector = engine.detector
        let roots = await Task.detached(priority: .utility) { detector.codeRoots() }.value
        guard !roots.isEmpty else { return }
        update(rescan: false) { $0.codeRoots = roots.map(\.path) }
    }

    func finishOnboarding() async {
        update { $0.onboarded = true }
        setLaunchAtLogin(true)
        await Notifier.requestPermission()
    }

    // MARK: Persistence

    private func update(rescan: Bool = true, _ change: (inout Config) -> Void) {
        var next = config
        change(&next)
        guard next != config else { return }
        config = next
        save()
        if rescan { scheduleRescan() }
    }

    private func reloadConfig() {
        let onDisk = configFile.load()
        if onDisk != config, FileManager.default.fileExists(atPath: configFile.url.path) {
            Log.info("config: reloaded edits from \(configFile.url.path)")
            config = onDisk
            report = nil
        }
    }

    private func save() {
        do {
            try configFile.save(config)
        } catch {
            Log.error("config: could not save: \(error.localizedDescription)")
            message = "Could not save settings: \(error.localizedDescription)"
        }
    }

    private func record(_ run: Run) {
        history = Array((history + [run]).suffix(JSONFile<[Run]>.historyLimit))
        do { try historyFile.save(history) } catch { Log.error("history: could not save: \(error.localizedDescription)") }
    }

    private func bytes(_ value: Int64) -> String {
        value.formatted(.byteCount(style: .file))
    }

    private func rule(_ id: String) -> Rule? {
        engine.rules.first { $0.id == id }
    }
}
