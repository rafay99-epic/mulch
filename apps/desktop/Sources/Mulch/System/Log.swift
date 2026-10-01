import AppKit
import Foundation
import os

nonisolated enum Log {
    static let folder = URL.homeDirectory.appending(path: ".mulch/logs")
    static let url = folder.appending(path: "\(Channel.current.slug).log")
    static let crashes = folder.appending(path: "crashes")

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.rafay99.mulch", category: "app")
    private static let queue = DispatchQueue(label: "mulch.log", qos: .utility)
    private static let maxBytes: Int64 = 5 * 1024 * 1024
    private static let sessionKey = "logSessionOpen"
    private static let launchKey = "logLastLaunch"

    static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        queue.async { append("INFO", message) }
    }

    static func error(_ message: String) {
        logger.error("\(message, privacy: .public)")
        queue.async { append("ERROR", message) }
    }

    static func launched() {
        let defaults = UserDefaults.standard
        let previousLaunch = defaults.object(forKey: launchKey) as? Date
        let endedCleanly = !defaults.bool(forKey: sessionKey)
        defaults.set(Date.now, forKey: launchKey)
        defaults.set(true, forKey: sessionKey)

        let commit = Channel.commit.map { " (\($0))" } ?? ""
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        info("app: \(Channel.current.displayName) \(Channel.version)\(commit) launched on macOS \(os), pid \(ProcessInfo.processInfo.processIdentifier)")
        info("app: logging to \(url.path)")

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification, object: nil, queue: nil
        ) { _ in
            UserDefaults.standard.set(false, forKey: sessionKey)
            logger.info("app: quit")
            queue.sync { append("INFO", "app: quit") }
        }

        queue.async {
            let reports = collectCrashReports(since: previousLaunch)
            if !endedCleanly, reports == 0, previousLaunch != nil {
                append("CRASH", "app: previous run ended without quitting (force quit, killed, or the Mac lost power)")
            }
        }
    }

    private static func append(_ level: String, _ message: String) {
        rotateIfNeeded()
        let data = Data("\(Date.now.ISO8601Format())  \(level)  \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try? data.write(to: url)
        }
    }

    private static func rotateIfNeeded() {
        guard let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64, size > maxBytes
        else { return }
        let previous = folder.appending(path: "\(Channel.current.slug).1.log")
        try? FileManager.default.removeItem(at: previous)
        try? FileManager.default.moveItem(at: url, to: previous)
    }

    private static func collectCrashReports(since: Date?) -> Int {
        guard let since else { return 0 }
        let source = URL.libraryDirectory.appending(path: "Logs/DiagnosticReports")
        let files = (try? FileManager.default.contentsOfDirectory(
            at: source, includingPropertiesForKeys: [.contentModificationDateKey]
        )) ?? []
        var count = 0
        for file in files where file.lastPathComponent.hasPrefix("\(Channel.current.displayName)-") {
            guard let date = try? file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate,
                  date > since else { continue }
            try? FileManager.default.createDirectory(at: crashes, withIntermediateDirectories: true)
            let copy = crashes.appending(path: file.lastPathComponent)
            try? FileManager.default.removeItem(at: copy)
            let copied = (try? FileManager.default.copyItem(at: file, to: copy)) != nil
            append("CRASH", "app: previous run crashed at \(date.ISO8601Format()). Report: \((copied ? copy : file).path)")
            count += 1
        }
        return count
    }
}
