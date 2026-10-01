import Foundation

public struct DetectedTool: Sendable, Identifiable, Hashable {
    public let name: String
    public let installed: Bool
    public var id: String { name }
}

public struct CodeRoot: Sendable, Identifiable, Hashable {
    /// Home-relative, e.g. `~/Code`.
    public let path: String
    public let repos: Int
    public var id: String { path }
}

/// First-run discovery: which dev tools are on this Mac and where the code lives.
public struct Detector: Sendable {
    struct Tool: Sendable {
        let name: String
        let bundleIDs: [String]
        let executable: String?
    }

    static let tools: [Tool] = [
        Tool(name: "Xcode", bundleIDs: ["com.apple.dt.Xcode"], executable: nil),
        Tool(name: "Android Studio", bundleIDs: ["com.google.android.studio"], executable: nil),
        Tool(name: "Flutter", bundleIDs: [], executable: "flutter"),
        Tool(name: "Cursor", bundleIDs: [Apps.cursor], executable: nil),
        Tool(name: "VS Code", bundleIDs: ["com.microsoft.VSCode"], executable: nil),
        Tool(name: "JetBrains", bundleIDs: Apps.jetbrains, executable: nil),
        Tool(name: "Chrome", bundleIDs: ["com.google.Chrome"], executable: nil),
        Tool(name: "Brave", bundleIDs: ["com.brave.Browser"], executable: nil),
        Tool(name: "Docker", bundleIDs: ["com.docker.docker"], executable: "docker"),
        Tool(name: "Homebrew", bundleIDs: [], executable: "brew"),
        Tool(name: "pnpm", bundleIDs: [], executable: "pnpm"),
        Tool(name: "Bun", bundleIDs: [], executable: "bun"),
    ]

    /// Home folders that are clearly not code roots.
    static let skippedFolders: Set<String> = ["Library", "Applications", "Movies", "Music", "Pictures", "Public"]

    public let paths: Paths
    public let probe: any SystemProbe
    public let runner: CommandRunner

    public init(paths: Paths, probe: any SystemProbe, runner: CommandRunner) {
        self.paths = paths
        self.probe = probe
        self.runner = runner
    }

    public func detectTools() async -> [DetectedTool] {
        let installed = await probe.installedBundleIDs(among: Self.tools.flatMap(\.bundleIDs))
        return Self.tools.map { tool in
            let hasApp = tool.bundleIDs.contains(where: installed.contains)
            let hasCLI = tool.executable.flatMap(runner.locate) != nil
            return DetectedTool(name: tool.name, installed: hasApp || hasCLI)
        }
    }

    /// Top-level home folders holding at least `minimumRepos` git repos, counting
    /// repos one or two levels down. Largest first.
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
