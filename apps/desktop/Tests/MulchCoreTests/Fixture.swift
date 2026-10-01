import Foundation
@testable import MulchCore

/// A throwaway home folder for one test.
struct Fixture {
    let home: URL
    var paths: Paths { Paths(home: home, darwinX: home.appending(path: "X")) }

    init() throws {
        home = FileManager.default.temporaryDirectory
            .appending(path: "mulch-tests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    }

    /// Writes a file (and its folders) at a home-relative path.
    @discardableResult
    func file(_ path: String, bytes: Int = 4096) throws -> URL {
        let url = home.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(repeating: 1, count: bytes).write(to: url)
        return url
    }

    func url(_ path: String) -> URL { home.appending(path: path) }

    func exists(_ path: String) -> Bool { FileManager.default.fileExists(atPath: url(path).path) }

    /// Backdates an item and everything inside it.
    func age(_ path: String, days: Double) throws {
        let date = Date(timeIntervalSinceNow: -days * 86_400)
        let root = url(path)
        let inside = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil)?.allObjects as? [URL] ?? []
        for item in inside.reversed() + [root] {
            try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: item.path)
        }
    }

    func engine(rules: [Rule], running: Set<String> = []) -> Engine {
        Engine(probe: FixedProbe(running: running), paths: paths, rules: rules)
    }

    func cleanup() { try? FileManager.default.removeItem(at: home) }
}

struct FixedProbe: SystemProbe {
    var running: Set<String> = []
    var installed: Set<String> = []
    func runningBundleIDs() async -> Set<String> { running }
    func installedBundleIDs(among candidates: [String]) async -> Set<String> { installed.intersection(candidates) }
}

extension Config {
    static func test(roots: [String] = ["~/Code"], never: [String] = Config.defaultNever) -> Config {
        Config(codeRoots: roots, never: never)
    }
}
