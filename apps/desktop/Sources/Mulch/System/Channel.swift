import Foundation

nonisolated enum Channel: String, Sendable {
    case stable, dev

    static let current = Channel(rawValue: info("MulchChannel") ?? "") ?? .stable
    static let version = info("CFBundleShortVersionString") ?? "0"
    static let commit = info("MulchCommit")

    var displayName: String { self == .stable ? "Mulch" : "Mulch \(rawValue.capitalized)" }

    var slug: String { self == .stable ? "mulch" : "mulch-\(rawValue)" }

    var updates: Bool { self == .stable }

    var menuSymbol: String { self == .stable ? "leaf" : "hammer" }

    private static func info(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }
}
