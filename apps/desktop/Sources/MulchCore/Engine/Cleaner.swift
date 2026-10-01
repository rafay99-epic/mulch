import Foundation

/// Deletes findings from a scan. Every item is checked again right before it goes:
/// it must still exist, stay inside its folder, avoid every never path, have its
/// blocking apps closed, and be unchanged since the scan. Deletes are permanent.
public struct Cleaner: Sendable {
    public enum Verdict: Equatable, Sendable {
        case delete(URL)
        /// Deleted by something else since the scan.
        case gone
        case refuse(String)
    }

    public let paths: Paths
    public let probe: any SystemProbe
    public let runner: CommandRunner

    public init(paths: Paths, probe: any SystemProbe, runner: CommandRunner) {
        self.paths = paths
        self.probe = probe
        self.runner = runner
    }

    public func clean(_ findings: [Finding], from report: ScanReport, config: Config) async -> Outcome {
        let protection = Protection(config.never, paths: paths)
        var blockers = BlockerCheck(running: await probe.runningBundleIDs(), runner: runner)
        var outcome = Outcome()

        for finding in findings {
            if Task.isCancelled { break }
            guard let rule = report.report(for: finding.ruleID)?.rule, rule.mode != .off else {
                outcome.skipped.append((finding.title, "rule is off"))
                continue
            }
            if case let .command(spec) = rule.rule.target {
                await runCommand(spec, finding: finding, blockers: &blockers, rule: rule, into: &outcome)
                continue
            }
            switch await verdict(for: finding, rule: rule, protection: protection, blockers: &blockers) {
            case .gone:
                outcome.gone.insert(finding.id)
            case let .refuse(reason):
                outcome.skipped.append((finding.title, reason))
            case let .delete(url):
                do {
                    try FileManager.default.removeItem(at: url)
                    outcome.freedBytes += finding.bytes
                    outcome.removed.append(finding.title)
                    outcome.gone.insert(finding.id)
                } catch {
                    if Self.isPermissionError(error) { outcome.needsFullDiskAccess = true }
                    outcome.failures.append((finding.title, error.localizedDescription))
                }
            }
        }
        return outcome
    }

    func verdict(
        for finding: Finding, rule: EffectiveRule, protection: Protection, blockers: inout BlockerCheck
    ) async -> Verdict {
        guard let url = finding.url, let root = finding.root else { return .refuse("nothing to delete") }
        guard FileManager.default.fileExists(atPath: url.path) else { return .gone }
        guard !protection.forbidsDeleting(url) else { return .refuse("protected path") }
        guard Paths.isContained(url, in: root) else { return .refuse("outside its folder") }
        if let reason = await blockers.reason(for: rule.rule.blockers) ?? blockers.itemReason(url, blockers: rule.rule.blockers) {
            return .refuse(reason)
        }
        if let newest = finding.newest, let modified = Measure.modificationDate(of: url),
           modified > newest.addingTimeInterval(1) {
            return .refuse("changed since the scan")
        }
        return .delete(url)
    }

    private func runCommand(
        _ spec: CommandSpec, finding: Finding, blockers: inout BlockerCheck, rule: EffectiveRule, into outcome: inout Outcome
    ) async {
        if let reason = await blockers.reason(for: rule.rule.blockers) {
            outcome.skipped.append((finding.title, reason))
            return
        }
        do {
            let result = try await runner.run(spec.tool, spec.clean, timeout: .seconds(900))
            guard result.succeeded else {
                let last = result.output.split(separator: "\n").last.map(String.init) ?? "exit \(result.status)"
                outcome.failures.append((finding.title, last))
                return
            }
            if case let .paths(patterns) = spec.measure {
                let after = patterns.flatMap(paths.resolve).reduce(0) { $0 + Measure.of($1.url).bytes }
                outcome.freedBytes += max(finding.bytes - after, 0)
            } else {
                outcome.freedBytes += finding.bytes
            }
            outcome.removed.append(finding.title)
            outcome.gone.insert(finding.id)
        } catch {
            outcome.failures.append((finding.title, error.localizedDescription))
        }
    }

    static func isPermissionError(_ error: any Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileWriteNoPermissionError { return true }
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        return underlying?.domain == NSPOSIXErrorDomain && [EPERM, EACCES].contains(Int32(underlying?.code ?? 0))
    }
}
