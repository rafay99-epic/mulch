import Foundation

public enum Mode: String, Codable, Sendable, CaseIterable {
    case auto
    case ask
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

public enum Blocker: Sendable, Hashable {
    case app(String, name: String)
    case appPrefix(String, name: String)
    case process(String, name: String)
    case itemBundleID
}

public enum Newest: Sendable, Hashable {
    case modified
    case version
    case versionPerProduct
}

public enum CommandMeasure: Sendable, Hashable {
    case paths([String])
    case output([String])
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

public enum Target: Sendable, Hashable {
    case paths([String])
    case projectArtifacts([String: [String]])
    case keepNewest(String, Newest)
    case command(CommandSpec)
}

public struct Rule: Sendable, Identifiable, Hashable {
    public let id: String
    public let title: String
    public let group: RuleGroup
    public let target: Target
    public let minAgeDays: Int?
    public let defaultMode: Mode
    public let blockers: [Blocker]
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

public struct EffectiveRule: Sendable, Identifiable, Hashable {
    public let rule: Rule
    public let mode: Mode
    public let minAgeDays: Int?

    public var id: String { rule.id }
}
