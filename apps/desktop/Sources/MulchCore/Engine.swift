import Foundation

/// Everything the app needs from the core, wired with one set of dependencies.
public struct Engine: Sendable {
    public let paths: Paths
    public let scanner: Scanner
    public let cleaner: Cleaner
    public let detector: Detector
    public let rules: [Rule]

    public init(probe: any SystemProbe, paths: Paths = Paths(), rules: [Rule] = BuiltInRules.all) {
        let runner = CommandRunner(home: paths.home)
        self.paths = paths
        self.rules = rules
        scanner = Scanner(paths: paths, probe: probe, runner: runner)
        cleaner = Cleaner(paths: paths, probe: probe, runner: runner)
        detector = Detector(paths: paths)
    }

    public func scan(config: Config, progress: (@Sendable (RuleReport) async -> Void)? = nil) async -> ScanReport {
        await scanner.scan(config.effective(rules), config: config, progress: progress)
    }

    /// Cleans everything eligible under Auto rules. Ask items stay in the report for the inbox.
    public func sweep(_ report: ScanReport, config: Config) async -> Outcome {
        await cleaner.clean(report.autoFindings, from: report, config: config)
    }
}
