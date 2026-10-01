import Darwin
import Foundation

/// Finds and sizes what each rule would clean. Read-only.
///
/// Run it from a `.background` priority task: Darwin then throttles its disk I/O
/// so a scan never competes with the user's work.
public struct Scanner: Sendable {
    public let paths: Paths
    public let probe: any SystemProbe
    public let runner: CommandRunner
    /// How deep to look for project artifacts under a code root.
    public var maxDepth = 8

    public init(paths: Paths, probe: any SystemProbe, runner: CommandRunner) {
        self.paths = paths
        self.probe = probe
        self.runner = runner
    }

    public func scan(_ rules: [EffectiveRule], config: Config, now: Date = .now) async -> ScanReport {
        let active = rules.filter { $0.mode != .off }
        let protection = Protection(config.never, paths: paths)
        var blockers = BlockerCheck(running: await probe.runningBundleIDs(), runner: runner)
        let artifacts = findArtifacts(for: active, roots: config.codeRoots, protection: protection)
        var claimed = Set<String>()
        var reports: [RuleReport] = []

        for rule in active {
            if Task.isCancelled { break }
            let ruleBlock = await blockers.reason(for: rule.rule.blockers)

            let candidates: [(url: URL, root: URL)]
            switch rule.rule.target {
            case let .command(spec):
                reports.append(await scanCommand(rule, spec, block: ruleBlock))
                continue
            case let .paths(patterns):
                candidates = patterns.flatMap(paths.resolve)
            case let .keepNewest(pattern, grouping):
                candidates = olderSiblings(pattern, grouping)
            case .projectArtifacts:
                candidates = artifacts[rule.id] ?? []
            }

            var findings: [Finding] = []
            for (url, root) in candidates {
                let key = url.standardizedFileURL.path
                guard !claimed.contains(key),
                      !rule.rule.excluding.contains(where: { fnmatch($0, url.lastPathComponent, 0) == 0 }),
                      !protection.forbidsDeleting(url)
                else { continue }
                claimed.insert(key)

                let size = Measure.of(url)
                guard size.bytes > 0 else { continue }
                let block = ruleBlock ?? blockers.itemReason(url, blockers: rule.rule.blockers)
                findings.append(Finding(
                    ruleID: rule.id, url: url, root: root, title: paths.abbreviate(url),
                    bytes: size.bytes, newest: size.newest,
                    status: Self.status(block: block, minAgeDays: rule.minAgeDays, newest: size.newest, now: now)
                ))
            }
            reports.append(RuleReport(rule: rule, findings: findings.sorted { $0.bytes > $1.bytes }))
        }
        return ScanReport(date: now, rules: reports)
    }

    static func status(block: String?, minAgeDays: Int?, newest: Date?, now: Date) -> Finding.Status {
        if let block { return .blocked(block) }
        if let minAgeDays, let newest {
            let days = Int(now.timeIntervalSince(newest) / 86_400)
            if days < minAgeDays { return .tooRecent(days: max(days, 0)) }
        }
        return .eligible
    }

    // MARK: Targets

    /// Children of each folder matching `pattern`, minus the newest of each group.
    func olderSiblings(_ pattern: String, _ grouping: Grouping) -> [(url: URL, root: URL)] {
        paths.resolve(pattern).flatMap { folder -> [(url: URL, root: URL)] in
            let children = (try? FileManager.default.contentsOfDirectory(
                at: folder.url, includingPropertiesForKeys: [.contentModificationDateKey], options: .skipsHiddenFiles
            )) ?? []
            let groups = Dictionary(grouping: children) { Self.groupKey($0.lastPathComponent, grouping) }
            return groups.values.flatMap { group in
                group
                    .sorted { (Measure.modificationDate(of: $0) ?? .distantPast) > (Measure.modificationDate(of: $1) ?? .distantPast) }
                    .dropFirst()
                    .map { (url: $0, root: folder.url) }
            }
        }
    }

    static func groupKey(_ name: String, _ grouping: Grouping) -> String {
        switch grouping {
        case .single: ""
        case .versionedStem: String(name.reversed().drop { "0123456789.-_ ".contains($0) }.reversed())
        }
    }

    /// One walk over every code root that serves all project-artifact rules. Matched
    /// folders, `.git`, `node_modules` and never paths are not walked into.
    func findArtifacts(
        for rules: [EffectiveRule], roots: [String], protection: Protection
    ) -> [String: [(url: URL, root: URL)]] {
        var owners: [String: [(ruleID: String, manifests: [String])]] = [:]
        for rule in rules {
            guard case let .projectArtifacts(names) = rule.rule.target else { continue }
            for (name, manifests) in names { owners[name, default: []].append((rule.id, manifests)) }
        }
        guard !owners.isEmpty else { return [:] }

        var found: [String: [(url: URL, root: URL)]] = [:]
        let fileManager = FileManager.default
        for pattern in roots {
            let root = URL(filePath: paths.expand(pattern), directoryHint: .isDirectory)
            guard let walker = fileManager.enumerator(
                at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: { _, _ in true }
            ) else { continue }

            while let url = walker.nextObject() as? URL {
                if Task.isCancelled { return found }
                guard (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let name = url.lastPathComponent
                if let candidates = owners[name] {
                    let parent = url.deletingLastPathComponent()
                    let owner = candidates.first { candidate in
                        candidate.manifests.isEmpty
                            || candidate.manifests.contains { fileManager.fileExists(atPath: parent.appending(path: $0).path) }
                    }
                    if let owner {
                        found[owner.ruleID, default: []].append((url, root))
                        walker.skipDescendants()
                        continue
                    }
                }
                if name == ".git" || name == "node_modules" || walker.level >= maxDepth
                    || protection.isInsideNever(url.path) {
                    walker.skipDescendants()
                }
            }
        }
        return found
    }

    func scanCommand(_ rule: EffectiveRule, _ spec: CommandSpec, block: String?) async -> RuleReport {
        guard runner.locate(spec.tool) != nil else {
            return RuleReport(rule: rule, findings: [], note: "\(spec.tool) not installed")
        }
        var bytes: Int64 = 0
        switch spec.measure {
        case let .paths(patterns):
            bytes = patterns.flatMap(paths.resolve).reduce(0) { $0 + Measure.of($1.url).bytes }
            if bytes == 0 { return RuleReport(rule: rule, findings: []) }
        case let .output(arguments):
            guard let result = try? await runner.run(spec.tool, arguments, timeout: .seconds(30)), result.succeeded else {
                return RuleReport(rule: rule, findings: [], note: "\(spec.tool) is not running")
            }
            bytes = result.output.split(separator: "\n").compactMap(HumanBytes.parse).reduce(0, +)
            if bytes == 0 { return RuleReport(rule: rule, findings: []) }
        case .none:
            break
        }
        let finding = Finding(
            ruleID: rule.id, url: nil, root: nil, title: ([spec.tool] + spec.clean).joined(separator: " "),
            bytes: bytes, newest: nil, status: block.map(Finding.Status.blocked) ?? .eligible
        )
        return RuleReport(rule: rule, findings: [finding])
    }
}
