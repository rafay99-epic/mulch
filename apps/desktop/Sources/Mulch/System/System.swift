import AppKit
import MulchCore
import ServiceManagement
import UserNotifications

nonisolated struct WorkspaceProbe: SystemProbe {
    func runningBundleIDs() async -> Set<String> {
        await MainActor.run { Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier)) }
    }
}

enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            Log.info("login item: \(enabled ? "enabled" : "disabled")")
        } catch {
            Log.error("login item: could not \(enabled ? "enable" : "disable"): \(error.localizedDescription)")
        }
    }
}

enum Notifier {
    private static var available: Bool { Bundle.main.bundleIdentifier != nil }

    static func requestPermission() async {
        guard available else { return }
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert])
            Log.info("notifications: \(granted ? "allowed" : "denied")")
        } catch {
            Log.error("notifications: permission request failed: \(error.localizedDescription)")
        }
    }

    static func post(_ title: String, body: String) async {
        guard available else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        do {
            try await UNUserNotificationCenter.current().add(request)
            Log.info("notifications: posted \"\(title)\" \(body)")
        } catch {
            Log.error("notifications: could not post: \(error.localizedDescription)")
        }
    }
}

final class SweepScheduler {
    private let activity = NSBackgroundActivityScheduler(identifier: "\(Bundle.main.bundleIdentifier ?? "com.rafay99.mulch").sweep")

    init(check: @escaping @Sendable @MainActor () async -> Void) {
        activity.repeats = true
        activity.interval = 6 * 60 * 60
        activity.tolerance = 60 * 60
        activity.qualityOfService = .background
        activity.schedule { completion in
            Task { @MainActor in
                Log.info("scheduler: background wake")
                await check()
                completion(.finished)
            }
        }
    }
}
