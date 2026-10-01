import Foundation

public struct CodeRoot: Sendable, Identifiable, Hashable {
    public let path: String
    public let repos: Int
    public var id: String { path }
}

public struct Detector: Sendable {
    static let skippedFolders: Set<String> = ["Library", "Applications", "Movies", "Music", "Pictures", "Public"]

    public let paths: Paths

    public init(paths: Paths) {
        self.paths = paths
    }

    public func codeRoots(minimumRepos: Int = 3) -> [CodeRoot] {
        let fileManager = FileManager.default
        let folders = (try? fileManager.contentsOfDirectory(
            at: paths.home, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles
        )) ?? []
        return folders
            .filter { !Self.skippedFolders.contains($0.lastPathComponent) && Self.isDirectory($0) }
            .map { CodeRoot(path: paths.abbreviate($0), repos: Self.repoCount(in: $0)) }
            .filter { $0.repos >= minimumRepos }
            .sorted { $0.repos > $1.repos }
    }

    static func repoCount(in folder: URL) -> Int {
        let fileManager = FileManager.default
        let children = (try? fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
        return children.filter(isDirectory).reduce(0) { count, child in
            if fileManager.fileExists(atPath: child.appending(path: ".git").path) { return count + 1 }
            let nested = (try? fileManager.contentsOfDirectory(at: child, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)) ?? []
            return count + nested.filter { fileManager.fileExists(atPath: $0.appending(path: ".git").path) }.count
        }
    }

    private static func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
