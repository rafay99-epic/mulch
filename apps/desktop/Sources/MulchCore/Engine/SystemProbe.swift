import Foundation

/// What the engine needs to know about installed and running apps. The app target
/// implements it with `NSWorkspace`; tests use fixed sets.
public protocol SystemProbe: Sendable {
    func runningBundleIDs() async -> Set<String>
    func installedBundleIDs(among candidates: [String]) async -> Set<String>
}

/// Answers "why can't this rule run right now?" for a scan or clean.
/// Process lookups are cached for the lifetime of one check.
struct BlockerCheck {
    let running: Set<String>
    let runner: CommandRunner
    private var processes: [String: Bool] = [:]

    init(running: Set<String>, runner: CommandRunner) {
        self.running = running
        self.runner = runner
    }

    /// The first blocker that applies to the whole rule.
    mutating func reason(for blockers: [Blocker]) async -> String? {
        for blocker in blockers {
            switch blocker {
            case let .app(id, name) where running.contains(id):
                return "\(name) is open"
            case let .appPrefix(prefix, name) where running.contains(where: { $0.hasPrefix(prefix) }):
                return "\(name) is open"
            case let .process(pattern, name):
                if processes[pattern] == nil { processes[pattern] = await runner.isProcessRunning(pattern) }
                if processes[pattern] == true { return "\(name) is running" }
            default:
                continue
            }
        }
        return nil
    }

    /// A blocker that depends on the item itself, e.g. the app owning a cache folder.
    func itemReason(_ url: URL, blockers: [Blocker]) -> String? {
        guard blockers.contains(.itemBundleID), running.contains(url.lastPathComponent) else { return nil }
        return "app is open"
    }
}
