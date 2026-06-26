import Foundation
import ServiceManagement

enum LaunchAtLogin {
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return FileManager.default.fileExists(atPath: legacyPlistPath)
    }

    private static var legacyPlistPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.cursorbark.app.plist")
            .path
    }

    static func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return
        }

        if enabled {
            try installLegacyAgent()
        } else {
            try removeLegacyAgent()
        }
    }

    private static func installLegacyAgent() throws {
        let executable = Bundle.main.executableURL ?? URL(fileURLWithPath: CommandLine.arguments[0])
        let plist: [String: Any] = [
            "Label": "com.cursorbark.app",
            "ProgramArguments": [executable.path],
            "RunAtLoad": true,
            "KeepAlive": true,
        ]
        let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let url = URL(fileURLWithPath: legacyPlistPath)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    private static func removeLegacyAgent() throws {
        let path = legacyPlistPath
        if FileManager.default.fileExists(atPath: path) {
            try FileManager.default.removeItem(atPath: path)
        }
    }
}
