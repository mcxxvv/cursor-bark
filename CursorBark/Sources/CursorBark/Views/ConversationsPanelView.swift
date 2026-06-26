import SwiftUI

struct ConversationsPanelView: View {
    @ObservedObject var model: AppModel

    private var openConversations: [ConversationItem] {
        model.conversations.filter(\.isOpen)
    }

    private var otherConversations: [ConversationItem] {
        model.conversations.filter { !$0.isOpen }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .windowBackgroundColor))
        .onChange(of: model.config.monitor.monitorMode) { _, _ in
            model.saveConfig()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("会话监听")
                    .font(.title.bold())
                Text("勾选需要接收完成通知的对话。状态由 Cursor Bark Bridge 插件实时提供。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                Picker("模式", selection: $model.config.monitor.monitorMode) {
                    Text("仅勾选").tag("selected")
                    Text("全部打开").tag("all")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 240)

                Spacer()

                Button("全选已打开") { model.selectAllOpenConversations() }
                Button("清空") { model.clearMonitoredConversations() }
                Button("刷新") { model.refreshConversations(force: true) }
            }

            HStack(spacing: 16) {
                statLabel("全部", value: model.conversations.count)
                statLabel("已打开", value: openConversations.count)
                statLabel("监听中", value: model.monitoredConversationCount)
                statLabel("进行中", value: model.runningConversationCount, highlight: model.runningConversationCount > 0)
                Spacer()
                if model.bridgeConnected {
                    Label("插件已连接", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                } else {
                    Label("插件未连接", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if model.conversations.isEmpty {
            ContentUnavailableView {
                Label("暂无会话", systemImage: "bubble.left.and.exclamationmark")
            } description: {
                Text(model.bridgeConnected
                    ? "插件已连接，但还没有同步到对话。请在 Cursor 里打开 Agent 对话，或点击刷新。"
                    : "请先在 Cursor 安装 Cursor Bark Bridge 插件，并确认端口为 \(model.config.monitor.extensionPort)。")
            } actions: {
                Button("刷新") { model.refreshConversations(force: true) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            List {
                if !openConversations.isEmpty {
                    Section {
                        ForEach(openConversations) { item in
                            ConversationRowView(item: binding(for: item)) {
                                model.toggleConversationMonitoring(item.id)
                            }
                        }
                    } header: {
                        Text("已打开 (\(openConversations.count))")
                    }
                }

                if !otherConversations.isEmpty {
                    Section {
                        ForEach(otherConversations) { item in
                            ConversationRowView(item: binding(for: item)) {
                                model.toggleConversationMonitoring(item.id)
                            }
                        }
                    } header: {
                        Text("其他会话 (\(otherConversations.count))")
                    }
                }
            }
            .listStyle(.inset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func statLabel(_ title: String, value: Int, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(highlight ? .orange : .primary)
        }
    }

    private func binding(for item: ConversationItem) -> ConversationItem {
        model.conversations.first(where: { $0.id == item.id }) ?? item
    }
}

struct ConversationRowView: View {
    let item: ConversationItem
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onToggle) {
                Image(systemName: item.isMonitored ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isMonitored ? .blue : .secondary)
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .help(item.isMonitored ? "取消监听" : "开始监听")

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.headline)
                        .lineLimit(1)
                    if item.isOpen {
                        Text("已打开")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.blue.opacity(0.15), in: Capsule())
                    }
                    statusBadge
                    Spacer(minLength: 0)
                }

                Text(item.displayProject)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text("ID: \(item.shortID)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch item.status {
        case .running:
            Label("进行中", systemImage: "arrow.trianglehead.2.clockwise")
                .font(.caption2)
                .foregroundStyle(.orange)
        case .completed:
            Label("已完成", systemImage: "checkmark")
                .font(.caption2)
                .foregroundStyle(.green)
        case .idle:
            Label("空闲", systemImage: "moon")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
