import AppKit
import MulchCore
import ServiceManagement
import UserNotifications

/// `SystemProbe` backed by `NSWorkspace`. Reads happen on the main actor, where
/// `NSWorkspace` keeps its running-app list current.
nonisolated struct WorkspaceProbe: SystemProbe {
    func runningBundleIDs() async -> Set<String> {
        await MainActor.run { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }
    }
}

/// Launch at login through `SMAppService`. Only works from the installed .app bundle.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            Log.error("login item: could not \(enabled ? "enable" : "disable"): \(error.localizedDescription)")
        }
    }
}

/// Local notifications. A no-op outside an app bundle, e.g. under `swift run`.
enum Notifier {
    private static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestPermission() async {
        guard available else { return }
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
    }

    static func post(_ title: String, body: String) async {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}

/// Wakes the app every few hours at background priority, when macOS judges the Mac
/// idle enough. The handler decides whether a sweep is actually due, so the weekly
/// clock survives reboots and relaunches. Lives as long as the app.
final class SweepScheduler {
    private let activity = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier ?? "com.rafay99.mulch").sweep")

    init(check: @escaping @Sendable @MainActor () async -> Void) {
        activity.repeats = true
        activity.interval = 6 * 60 * 60
        activity.tolerance = 60 * 60
        activity.qualityOfService = .background
        activity.schedule { completion in
            Task { @MainActor in
                await check()
                completion(.finished)
            }
        }
    }
}
