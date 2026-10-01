import Foundation
import os

/// The activity log: `~/Library/Logs/<channel name>/activity.log`, one line per event
/// as `<ISO date>  <LEVEL>  <message>`, where LEVEL is INFO, ERROR or CRASH. Lines also
/// go to the unified log, so `log stream --predicate 'subsystem BEGINSWITH "com.rafay99.mulch"'`
/// follows a running app. Rotates to `activity.1.log` past 2 MB.
nonisolated enum Log {
    static let url = URL.libraryDirectory.appending(path: "Logs/\(Channel.current.displayName)/activity.log")

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.rafay99.mulch", category: "app")
    private static let queue = DispatchQueue(label: "mulch.log", qos: .utility)
    private static let maxBytes: Int64 = 2 * 1024 * 1024

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        queue.async { append("INFO", message) }
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        queue.async { append("ERROR", message) }
    }

    /// Called once at launch: records the build, then points at any crash report
    /// macOS wrote since the previous launch. Those reports hold the full stack trace
    /// and exception reason, so the log links to them rather than copying them.
    static func launched() {
        let commit = Channel.commit.map { " (\($0))" } ?? ""
        info("\(Channel.current.displayName) \(Channel.version)\(commit) launched on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        queue.async { noteCrashReports() }
    }

    private static func append(_ level: String, _ message: String) {
        rotateIfNeeded()
        let data = Data("\(Date.now.ISO8601Format())  \(level)  \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private static func rotateIfNeeded() {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64, size > maxBytes
        else { return }
        let previous = url.deletingPathExtension().appendingPathExtension("1.log")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: url, to: previous)
    }

    /// macOS names reports `<executable>-<date>.ips` in DiagnosticReports.
    private static func noteCrashReports() {
        let key = "lastLaunch"
        let since = UserDefaults.standard.object(forKey: key) as? Date ?? .now
        UserDefaults.standard.set(Date.now, forKey: key)
        let folder = URL.libraryDirectory.appending(path: "Logs/DiagnosticReports")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        for file in files where file.lastPathComponent.hasPrefix("\(Channel.current.displayName)-") {
            guard let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  date > since else { continue }
            append("CRASH", "previous run crashed at \(date.ISO8601Format()). Report: \(file.path)")
        }
    }
}
