import Foundation
import UserNotifications

enum LocalNotifier {
    private static var canUseUserNotifications: Bool {
        Bundle.main.bundlePath.hasSuffix(".app")
            && Bundle.main.bundleIdentifier != nil
    }

    static func setup() {
        guard canUseUserNotifications else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func show(title: String, subtitle: String, body: String) {
        if canUseUserNotifications {
            showWithUserNotifications(title: title, subtitle: subtitle, body: body)
        } else {
            showWithAppleScript(title: title, subtitle: subtitle, body: body)
        }
    }

    private static func showWithUserNotifications(title: String, subtitle: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.subtitle = subtitle
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private static func showWithAppleScript(title: String, subtitle: String, body: String) {
        let script = """
        display notification "\(escapeAppleScript(body))" with title "\(escapeAppleScript(title))" subtitle "\(escapeAppleScript(subtitle))"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        try? process.run()
    }

    private static func escapeAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
