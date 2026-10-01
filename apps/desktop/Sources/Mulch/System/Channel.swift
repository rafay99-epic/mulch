import Foundation

/// Which build this is, read from Info.plist (`build.sh` stamps it). Stable ships
/// from `main` and updates itself; Dev is a local build for testing. Each has its own
/// bundle ID, config, history and log, so both can run side by side.
nonisolated enum Channel: String, Sendable {
    case stable, dev

    static let current = Channel(rawValue: info("MulchChannel") ?? "") ?? .stable
    /// Release number: the commit count on `main`.
    static let version = info("CFBundleShortVersionString") ?? "0"
    /// `branch@sha` the build came from, if stamped.
    static let commit = info("MulchCommit")

    var displayName: String { self == .stable ? "Mulch" : "Mulch \(rawValue.capitalized)" }

    /// Folder under `~/.config` that holds config.json.
    var configFolder: String { self == .stable ? "mulch" : "mulch-\(rawValue)" }

    /// Only Stable updates itself; Dev is whatever you built.
    var updates: Bool { self == .stable }

    var menuSymbol: String { self == .stable ? "leaf" : "hammer" }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
