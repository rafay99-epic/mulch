import Darwin
import Foundation

/// Expands rule patterns into real paths.
///
/// `~` is the home folder and `$X` is the per-user Darwin cache folder
/// (`/var/folders/../X`) where browsers leave `code_sign_clone` copies.
/// `*` and `?` glob a single path component.
public struct Paths: Sendable {
    public let home: URL
    public let darwinX: URL

    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser, darwinX: URL = Paths.defaultDarwinX) {
        self.home = home
        self.darwinX = darwinX
    }

    /// `NSTemporaryDirectory()` is `/var/folders/<a>/<b>/T/`; its sibling `X` holds the clones.
    public static var defaultDarwinX: URL {
        URL(filePath: NSTemporaryDirectory()).deletingLastPathComponent().appending(path: "X")
    }

    public func expand(_ pattern: String) -> String {
        if pattern == "~" { return home.path }
        if pattern.hasPrefix("~/") { return home.path + pattern.dropFirst() }
        if pattern.hasPrefix("$X") { return darwinX.path + pattern.dropFirst(2) }
        return pattern
    }

    /// Existing items matching `pattern`, each paired with the folder it must stay inside:
    /// the part of the pattern before the first glob, or the item's parent when there is no glob.
    public func resolve(_ pattern: String) -> [(url: URL, root: URL)] {
        let parts = expand(pattern).split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard let firstGlob = parts.firstIndex(where: Self.isGlob) else {
            let url = URL(filePath: "/" + parts.joined(separator: "/"))
            return FileManager.default.fileExists(atPath: url.path) ? [(url, url.deletingLastPathComponent())] : []
        }
        let root = URL(filePath: "/" + parts[..<firstGlob].joined(separator: "/"), directoryHint: .isDirectory)
        var current = [root]
        for part in parts[firstGlob...] {
            current = current.flatMap { dir -> [URL] in
                guard Self.isGlob(part) else {
                    let next = dir.appending(path: part)
                    return FileManager.default.fileExists(atPath: next.path) ? [next] : []
                }
                let names = (try? FileManager.default.contentsOfDirectory(atPath: dir.path)) ?? []
                return names.filter { fnmatch(part, $0, FNM_PERIOD) == 0 }.map { dir.appending(path: $0) }
            }
        }
        return current.map { ($0, root) }
    }

    /// `/Users/me/Code/app` becomes `~/Code/app`, also when home sits behind a symlink.
    public func abbreviate(_ url: URL) -> String {
        let path = url.path
        for base in [home.path, Self.canonical(home.path)].compactMap({ $0 }) where path.hasPrefix(base + "/") {
            return "~" + path.dropFirst(base.count)
        }
        return path
    }

    /// The real path with symlinks resolved, or `nil` if it does not exist.
    public static func canonical(_ path: String) -> String? {
        guard let resolved = realpath(path, nil) else { return nil }
        defer { free(resolved) }
        return String(cString: resolved)
    }

    /// True when `url`, after resolving symlinks, is strictly inside `root`.
    public static func isContained(_ url: URL, in root: URL) -> Bool {
        guard let item = canonical(url.path), let base = canonical(root.path) else { return false }
        return item.hasPrefix(base + "/")
    }

    private static func isGlob(_ part: String) -> Bool {
        part.contains("*") || part.contains("?")
    }
}

/// Paths Mulch must never delete: the user's never list plus a floor that protects
/// the home folder and everything above it.
public struct Protection: Sendable {
    private let never: [String]
    private let home: String

    public init(_ patterns: [String], paths: Paths) {
        never = patterns.flatMap { pattern -> [String] in
            let expanded = (paths.expand(pattern) as NSString).standardizingPath
            return [expanded, Paths.canonical(expanded)].compactMap { $0 }
        }
        home = Paths.canonical(paths.home.path) ?? paths.home.path
    }

    /// Cheap string check used while walking: is `path` inside a never path?
    public func isInsideNever(_ path: String) -> Bool {
        never.contains { path == $0 || path.hasPrefix($0 + "/") }
    }

    /// Full check before deleting: refuses never paths, anything containing one,
    /// and the home folder or its ancestors.
    public func forbidsDeleting(_ url: URL) -> Bool {
        let raw = (url.path as NSString).standardizingPath
        let real = Paths.canonical(raw) ?? raw
        if real == home || home.hasPrefix(real + "/") || real == "/" { return true }
        return [raw, real].contains { path in
            never.contains { path == $0 || path.hasPrefix($0 + "/") || $0.hasPrefix(path + "/") }
        }
    }
}
