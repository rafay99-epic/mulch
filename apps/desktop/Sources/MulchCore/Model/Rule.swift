import Foundation

/// How a rule behaves during a sweep.
public enum Mode: String, Codable, Sendable, CaseIterable {
    /// Cleaned silently by the weekly sweep and by "Clean".
    case auto
    /// Found and sized, then held in the inbox until approved.
    case ask
    /// Not scanned at all.
    case off
}

public enum RuleGroup: String, Codable, Sendable, CaseIterable {
    case code, browsers, xcode, android, editors, packages, docker, system

    public var title: String {
        switch self {
        case .code: "Code"
        case .browsers: "Browsers"
        case .xcode: "Xcode"
        case .android: "Android"
        case .editors: "Editors"
        case .packages: "Package managers"
        case .docker: "Docker"
        case .system: "System"
        }
    }
}

/// Something that must not be running while a rule cleans.
public enum Blocker: Sendable, Hashable {
    /// An app by bundle id.
    case app(String, name: String)
    /// Any app whose bundle id starts with the prefix.
    case appPrefix(String, name: String)
    /// A process whose command line matches (`pgrep -f`).
    case process(String, name: String)
    /// The found item's own folder name is a bundle id, e.g. `~/Library/Caches/com.spotify.client`.
    case itemBundleID
}

/// How a "keep newest" target groups siblings before keeping the newest of each group.
public enum Grouping: Sendable, Hashable {
    /// All children form one group.
    case single
    /// Children grouped by name with trailing version characters removed,
    /// so `chromium-1208` and `chromium-1234` share the stem `chromium`.
    case versionedStem
}

/// How a command rule reports the space it can free.
public enum CommandMeasure: Sendable, Hashable {
    /// Sum the sizes of these paths.
    case paths([String])
    /// Run the tool with these arguments and sum the human sizes that start each output line.
    case output([String])
    /// Size is unknown.
    case none
}

public struct CommandSpec: Sendable, Hashable {
    public let tool: String
    public let clean: [String]
    public let measure: CommandMeasure

    public init(tool: String, clean: [String], measure: CommandMeasure) {
        self.tool = tool
        self.clean = clean
        self.measure = measure
    }
}

/// What a rule points at. Paths use `~` for home and `$X` for the per-user
/// Darwin cache folder that holds browser update leftovers; `*` globs one component.
public enum Target: Sendable, Hashable {
    /// Each matching path is one item.
    case paths([String])
    /// Folders found under the code roots, keyed by name. A name only counts when its
    /// parent holds one of the listed manifests; an empty list means always.
    case projectArtifacts([String: [String]])
    /// Children of each matching folder, minus the newest per group.
    case keepNewest(String, Grouping)
    /// A tool that cleans up after itself.
    case command(CommandSpec)
}

/// A cleanup rule. Rules are plain data; the catalog lives in `BuiltInRules`.
public struct Rule: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let group: RuleGroup
    public let target: Target
    /// Items modified more recently than this are left alone. `nil` skips the check.
    public let minAgeDays: Int?
    public let defaultMode: Mode
    public let blockers: [Blocker]
    /// Item names to skip, matched with `fnmatch`.
    public let excluding: [String]

    public init(
        id: String,
        title: String,
        group: RuleGroup,
        target: Target,
        minAgeDays: Int? = nil,
        defaultMode: Mode = .auto,
        blockers: [Blocker] = [],
        excluding: [String] = []
    ) {
        self.id = id
        self.title = title
        self.group = group
        self.target = target
        self.minAgeDays = minAgeDays
        self.defaultMode = defaultMode
        self.blockers = blockers
        self.excluding = excluding
    }
}

/// A rule with the user's overrides applied.
public struct EffectiveRule: Sendable, Identifiable, Hashable {
    public let rule: Rule
    public let mode: Mode
    public let minAgeDays: Int?

    public var id: String { rule.id }
}
