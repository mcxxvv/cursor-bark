import Foundation
import AppKit

@MainActor
final class AppModel: ObservableObject {
    @Published var config: AppConfig
    @Published var statusText: String = "启动中"
    @Published var lastMessage: String = ""
    @Published var alertMessage: String?
    @Published var showAlert = false
    @Published var launchAtLogin = LaunchAtLogin.isEnabled
    @Published var conversations: [ConversationItem] = []
    @Published var selectedTab: AppTab = .dashboard
    @Published var bridgeConnected = false

    private var recentKeys: [String: Date] = [:]
    private var processedBridgeEventIDs: Set<String> = []
    private var runningNotifiedIDs: Set<String> = []
    private let desktopWidgets = DesktopWidgetManager()
    private var refreshTimer: Timer?
    private var refreshTask: Task<Void, Never>?
    private var lastRefreshAt: Date = .distantPast
    private var lastRunningState = false
    private var lastWidgetSignature = ""

    init() {
        config = AppConfig.load()
        LocalNotifier.setup()
        restartServices()
        refreshConversations(force: true)
        startRefreshTimer()
        desktopWidgets.sync(model: self)
    }

    var menuBarSymbol: String {
        if !config.enabled { return "bell.slash" }
        if !bridgeConnected { return "exclamationmark.triangle" }
        if isAnyTaskRunning { return "arrow.trianglehead.2.clockwise" }
        if config.isReady { return "bell.badge" }
        return "bell"
    }

    var isAnyTaskRunning: Bool {
        conversations.contains { $0.status == .running && ($0.isMonitored || $0.isOpen) }
    }

    var runningConversations: [ConversationItem] {
        conversations.filter { $0.status == .running && ($0.isMonitored || $0.isOpen) }
    }

    var monitoredConversations: [ConversationItem] {
        conversations.filter(\.isMonitored)
    }

    var openConversationCount: Int {
        conversations.filter(\.isOpen).count
    }

    var monitoredConversationCount: Int {
        conversations.filter(\.isMonitored).count
    }

    var runningConversationCount: Int {
        runningConversations.count
    }

    var runningTitles: [String] {
        runningConversations.map(\.title)
    }

    func showMainWindow() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        for window in NSApp.windows where window.canBecomeMain {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func refreshConversations(force: Bool = false) {
        let now = Date()
        if !force, now.timeIntervalSince(lastRefreshAt) < 1.0 {
            return
        }
        lastRefreshAt = now

        refreshTask?.cancel()
        let monitored = Set(config.monitor.monitoredConversationIDs)
        let usesSelected = config.monitor.usesSelectedConversations
        let host = config.monitor.extensionHost
        let port = config.monitor.extensionPort

        refreshTask = Task.detached(priority: .utility) {
            async let health = ExtensionBridgeClient.fetchHealth(host: host, port: port)
            async let snapshot = ExtensionBridgeClient.fetchSnapshot(host: host, port: port)
            let connected = await health
            guard let snapshot = await snapshot else {
                await MainActor.run {
                    self.bridgeConnected = connected
                    self.statusText = connected ? "插件已连接，等待状态..." : "未连接 Cursor Bark Bridge 插件"
                }
                return
            }
            guard !Task.isCancelled else { return }

            let mapped = ExtensionBridgeClient.mapConversations(
                snapshot,
                monitored: monitored,
                usesSelected: usesSelected
            )
            await MainActor.run {
                self.bridgeConnected = true
                self.statusText = "已连接插件 · :\(port) · \(mapped.count) 个会话"
                self.applyBridgeSnapshot(mapped, events: snapshot.events)
            }
        }
    }

    private func applyBridgeSnapshot(_ mapped: [ConversationItem], events: [BridgeEvent]) {
        let running = mapped.contains { $0.isMonitored && $0.status == .running }
        let widgetSignature = widgetConfigSignature(running: running)

        for event in events where !processedBridgeEventIDs.contains(event.id) {
            processedBridgeEventIDs.insert(event.id)
            handle(event: ExtensionBridgeClient.mapEvent(event))
        }
        if processedBridgeEventIDs.count > 500 {
            processedBridgeEventIDs = Set(processedBridgeEventIDs.suffix(200))
        }

        guard mapped != conversations else {
            if running != lastRunningState || widgetSignature != lastWidgetSignature {
                syncDesktopWidgets(running: running, signature: widgetSignature)
            }
            return
        }

        conversations = mapped
        handleRunningTransitions()
        publishSnapshot()

        if running != lastRunningState || widgetSignature != lastWidgetSignature {
            syncDesktopWidgets(running: running, signature: widgetSignature)
        }

        if running != lastRunningState {
            lastRunningState = running
            rescheduleRefreshTimer()
        }
    }

    func toggleConversationMonitoring(_ id: String) {
        var ids = Set(config.monitor.monitoredConversationIDs)
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
        config.monitor.monitoredConversationIDs = Array(ids).sorted()
        config.monitor.monitorMode = "selected"
        saveConfig()
        refreshConversations(force: true)
    }

    func selectAllOpenConversations() {
        let ids = conversations.filter(\.isOpen).map(\.id)
        config.monitor.monitoredConversationIDs = ids
        config.monitor.monitorMode = "selected"
        saveConfig()
        refreshConversations(force: true)
    }

    func clearMonitoredConversations() {
        config.monitor.monitoredConversationIDs = []
        config.monitor.monitorMode = "selected"
        saveConfig()
        refreshConversations(force: true)
    }

    func shouldMonitor(conversationID: String?) -> Bool {
        guard config.enabled else { return false }
        guard let conversationID else { return !config.monitor.usesSelectedConversations }
        if config.monitor.usesSelectedConversations {
            return config.monitor.monitoredConversationIDs.contains(conversationID)
        }
        return conversations.first(where: { $0.id == conversationID })?.isOpen ?? true
    }

    func restartServices() {
        guard config.enabled else {
            statusText = "已暂停"
            bridgeConnected = false
            syncDesktopWidgets(running: false, signature: widgetConfigSignature(running: false))
            return
        }
        refreshConversations(force: true)
    }

    func saveConfig() {
        config.save()
        restartServices()
        refreshConversations(force: true)
        syncDesktopWidgets(running: isAnyTaskRunning, signature: widgetConfigSignature(running: isAnyTaskRunning))
    }

    func toggleEnabled() {
        config.enabled.toggle()
        saveConfig()
    }

    func sendTestNotification() async {
        let result = await BarkClient.send(
            config: config,
            title: "Cursor Bark 测试",
            body: "如果你看到这条推送，说明 Bark 已连接成功。",
            subtitle: "配置正常"
        )
        if result.ok {
            lastMessage = "测试推送已发送"
            LocalNotifier.show(title: "Cursor Bark", subtitle: "测试成功", body: "Bark 推送已发送")
        } else {
            presentAlert("测试失败: \(result.message)")
        }
    }

    func openExtensionPackage() {
        let candidates = [
            URL(fileURLWithPath: "/Users/flower./Desktop/cursor/cursor-bark/dist"),
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Desktop/cursor/cursor-bark/dist"),
        ]
        for dir in candidates where FileManager.default.fileExists(atPath: dir.path) {
            if let vsix = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "vsix" }) {
                NSWorkspace.shared.activateFileViewerSelecting([vsix])
                return
            }
            NSWorkspace.shared.open(dir)
            return
        }
        presentAlert("未找到 VSIX 安装包。请先运行 scripts/package-extension.sh 生成。")
    }

    func openLog() {
        if !FileManager.default.fileExists(atPath: AppConfig.logURL.path) {
            FileManager.default.createFile(atPath: AppConfig.logURL.path, contents: Data())
        }
        NSWorkspace.shared.open(AppConfig.logURL)
    }

    func openConfigDirectory() {
        NSWorkspace.shared.open(AppConfig.appSupportDirectory)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try LaunchAtLogin.setEnabled(enabled)
            launchAtLogin = LaunchAtLogin.isEnabled
            lastMessage = enabled ? "已开启登录自启" : "已关闭登录自启"
        } catch {
            presentAlert("登录自启设置失败: \(error.localizedDescription)")
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private func startRefreshTimer() {
        rescheduleRefreshTimer()
    }

    private func rescheduleRefreshTimer() {
        refreshTimer?.invalidate()
        let interval = isAnyTaskRunning ? 1.5 : (bridgeConnected ? 3.0 : 5.0)
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refreshConversations()
                self?.rescheduleRefreshTimer()
            }
        }
    }

    private func widgetConfigSignature(running: Bool) -> String {
        [
            config.monitor.showDesktopWidgets.description,
            config.monitor.showCompactWidget.description,
            config.monitor.showListWidget.description,
            config.monitor.showRunningWidget.description,
            running.description,
        ].joined(separator: "|")
    }

    private func syncDesktopWidgets(running: Bool, signature: String) {
        lastWidgetSignature = signature
        lastRunningState = running
        desktopWidgets.sync(model: self)
    }

    private func handleRunningTransitions() {
        let running = Set(runningConversations.map(\.id))
        let newlyRunning = running.subtracting(runningNotifiedIDs)
        if config.monitor.notifyOnTaskStart {
            for id in newlyRunning {
                guard let item = conversations.first(where: { $0.id == id }) else { continue }
                LocalNotifier.show(
                    title: "Cursor 任务进行中",
                    subtitle: item.displayProject,
                    body: item.title
                )
            }
        }
        runningNotifiedIDs = running
    }

    private func publishSnapshot() {
        let snapshot = SharedProgressSnapshot(
            updatedAt: Date(),
            isAnyRunning: isAnyTaskRunning,
            runningCount: runningConversationCount,
            monitoredCount: monitoredConversationCount,
            conversations: conversations.map {
                ConversationSnapshot(
                    id: $0.id,
                    title: $0.title,
                    projectLabel: $0.displayProject,
                    status: $0.status,
                    subtitle: $0.subtitle,
                    isMonitored: $0.isMonitored
                )
            }
        )
        SharedProgressStore.save(snapshot)
    }

    private func handle(event: AgentEvent) {
        config = AppConfig.load()
        guard config.isReady else { return }
        guard shouldMonitor(conversationID: event.conversationID) else { return }
        if event.isSubagent && !config.monitor.notifySubagents { return }

        let lowered = event.status.lowercased()
        if ["failed", "error", "cancelled"].contains(lowered) && !config.monitor.notifyOnError {
            return
        }

        let dedupeKey = [
            event.source,
            event.eventType,
            event.projectPath ?? "",
            event.conversationID ?? "",
            String(event.summary.prefix(80)),
        ].joined(separator: "|")

        if let last = recentKeys[dedupeKey], Date().timeIntervalSince(last) < 8 {
            return
        }
        recentKeys[dedupeKey] = Date()

        let notification = buildNotification(config: config, event: event)
        let url = event.projectPath.map { "cursor://file/\($0)" } ?? ""

        Task {
            let result = await BarkClient.send(
                config: config,
                title: notification.title,
                body: notification.body,
                subtitle: notification.subtitle,
                url: url
            )
            appendLog(event: event, result: result)
            if result.ok {
                lastMessage = notification.title
                LocalNotifier.show(
                    title: notification.title,
                    subtitle: notification.subtitle,
                    body: notification.body
                )
            }
        }
    }

    private func appendLog(event: AgentEvent, result: BarkResult) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let line = "[\(timestamp)] \(event.eventType) \(projectLabel(for: event.projectPath)) ok=\(result.ok) \(result.message.prefix(120))\n"
        if let data = line.data(using: .utf8) {
            if FileManager.default.fileExists(atPath: AppConfig.logURL.path) {
                if let handle = try? FileHandle(forWritingTo: AppConfig.logURL) {
                    _ = try? handle.seekToEnd()
                    try? handle.write(contentsOf: data)
                    try? handle.close()
                }
            } else {
                try? data.write(to: AppConfig.logURL)
            }
        }
    }

    private func presentAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}

