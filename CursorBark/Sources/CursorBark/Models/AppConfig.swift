import Foundation

struct BarkSettings: Codable, Equatable {
    var deviceKey: String = ""
    var serverURL: String = "https://api.day.app"
    var group: String = "Cursor"
    var level: String = "timeSensitive"
    var sound: String = ""
    var icon: String = ""

    enum CodingKeys: String, CodingKey {
        case deviceKey = "device_key"
        case serverURL = "server_url"
        case group, level, sound, icon
    }
}

struct MonitorSettings: Codable, Equatable {
    var extensionHost: String = "127.0.0.1"
    var extensionPort: Int = 8766
    var notifySubagents: Bool = true
    var notifyOnError: Bool = false
    var includeSummary: Bool = true
    var summaryMaxChars: Int = 180
    var monitorMode: String = "selected"
    var monitoredConversationIDs: [String] = []
    var notifyOnTaskStart: Bool = true
    var showDesktopWidgets: Bool = true
    var showCompactWidget: Bool = true
    var showListWidget: Bool = true
    var showRunningWidget: Bool = true

    enum CodingKeys: String, CodingKey {
        case extensionHost = "extension_host"
        case extensionPort = "extension_port"
        case notifySubagents = "notify_subagents"
        case notifyOnError = "notify_on_error"
        case includeSummary = "include_summary"
        case summaryMaxChars = "summary_max_chars"
        case monitorMode = "monitor_mode"
        case monitoredConversationIDs = "monitored_conversation_ids"
        case notifyOnTaskStart = "notify_on_task_start"
        case showDesktopWidgets = "show_desktop_widgets"
        case showCompactWidget = "show_compact_widget"
        case showListWidget = "show_list_widget"
        case showRunningWidget = "show_running_widget"
        // Legacy keys for migration
        case listenHost = "listen_host"
        case listenPort = "listen_port"
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        extensionHost = try container.decodeIfPresent(String.self, forKey: .extensionHost)
            ?? container.decodeIfPresent(String.self, forKey: .listenHost)
            ?? "127.0.0.1"
        extensionPort = try container.decodeIfPresent(Int.self, forKey: .extensionPort)
            ?? container.decodeIfPresent(Int.self, forKey: .listenPort)
            ?? 8766
        notifySubagents = try container.decodeIfPresent(Bool.self, forKey: .notifySubagents) ?? true
        notifyOnError = try container.decodeIfPresent(Bool.self, forKey: .notifyOnError) ?? false
        includeSummary = try container.decodeIfPresent(Bool.self, forKey: .includeSummary) ?? true
        summaryMaxChars = try container.decodeIfPresent(Int.self, forKey: .summaryMaxChars) ?? 180
        monitorMode = try container.decodeIfPresent(String.self, forKey: .monitorMode) ?? "selected"
        monitoredConversationIDs = try container.decodeIfPresent([String].self, forKey: .monitoredConversationIDs) ?? []
        notifyOnTaskStart = try container.decodeIfPresent(Bool.self, forKey: .notifyOnTaskStart) ?? true
        showDesktopWidgets = try container.decodeIfPresent(Bool.self, forKey: .showDesktopWidgets) ?? true
        showCompactWidget = try container.decodeIfPresent(Bool.self, forKey: .showCompactWidget) ?? true
        showListWidget = try container.decodeIfPresent(Bool.self, forKey: .showListWidget) ?? true
        showRunningWidget = try container.decodeIfPresent(Bool.self, forKey: .showRunningWidget) ?? true
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(extensionHost, forKey: .extensionHost)
        try container.encode(extensionPort, forKey: .extensionPort)
        try container.encode(notifySubagents, forKey: .notifySubagents)
        try container.encode(notifyOnError, forKey: .notifyOnError)
        try container.encode(includeSummary, forKey: .includeSummary)
        try container.encode(summaryMaxChars, forKey: .summaryMaxChars)
        try container.encode(monitorMode, forKey: .monitorMode)
        try container.encode(monitoredConversationIDs, forKey: .monitoredConversationIDs)
        try container.encode(notifyOnTaskStart, forKey: .notifyOnTaskStart)
        try container.encode(showDesktopWidgets, forKey: .showDesktopWidgets)
        try container.encode(showCompactWidget, forKey: .showCompactWidget)
        try container.encode(showListWidget, forKey: .showListWidget)
        try container.encode(showRunningWidget, forKey: .showRunningWidget)
    }

    var usesSelectedConversations: Bool {
        monitorMode == "selected"
    }
}

struct AppConfig: Codable, Equatable {
    var enabled: Bool = true
    var bark: BarkSettings = .init()
    var monitor: MonitorSettings = .init()

    var isReady: Bool {
        enabled && !bark.deviceKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static let appSupportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("CursorBark", isDirectory: true)
    }()

    static let configURL: URL = appSupportDirectory.appendingPathComponent("config.json")
    static let stateURL: URL = appSupportDirectory.appendingPathComponent("state.json")
    static let logURL: URL = appSupportDirectory.appendingPathComponent("hook.log")

    static func load() -> AppConfig {
        try? FileManager.default.createDirectory(at: appSupportDirectory, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: configURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            let config = AppConfig()
            config.save()
            return config
        }
        return config
    }

    func save() {
        try? FileManager.default.createDirectory(at: Self.appSupportDirectory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(self) else { return }
        try? data.write(to: Self.configURL, options: .atomic)
    }
}

func projectLabel(for path: String?) -> String {
    guard let path, !path.isEmpty else { return "Cursor" }
    let name = URL(fileURLWithPath: path).lastPathComponent
    return name.isEmpty ? path : name
}
