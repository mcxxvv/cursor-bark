import SwiftUI

struct DashboardPanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                statusCards
                if model.isAnyTaskRunning {
                    runningBanner
                }
                recentConversations
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Cursor Bark")
                    .font(.largeTitle.bold())
                Text(model.statusText)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isAnyTaskRunning {
                ProgressView()
                    .controlSize(.regular)
                Text("任务进行中")
                    .font(.headline)
                    .foregroundStyle(.orange)
            }
            Button("刷新") { model.refreshConversations() }
        }
    }

    private var statusCards: some View {
        HStack(spacing: 12) {
            statCard(title: "已打开", value: "\(model.openConversationCount)", icon: "bubble.left.and.bubble.right")
            statCard(title: "监听中", value: "\(model.monitoredConversationCount)", icon: "checkmark.circle")
            statCard(title: "进行中", value: "\(model.runningConversationCount)", icon: "arrow.trianglehead.2.clockwise")
            statCard(title: "Bark", value: model.config.isReady ? "已配置" : "未配置", icon: "bell.badge")
        }
    }

    private var runningBanner: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 4) {
                Text("有 \(model.runningConversationCount) 个任务正在处理")
                    .font(.headline)
                Text(model.runningTitles.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(14)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var recentConversations: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近会话")
                .font(.title3.bold())
            if model.conversations.isEmpty {
                ContentUnavailableView("暂无会话", systemImage: "bubble.left", description: Text("打开 Cursor 并创建对话后会显示在这里"))
            } else {
                ForEach(model.conversations.prefix(8)) { item in
                    ConversationRowView(item: item) {
                        model.toggleConversationMonitoring(item.id)
                    }
                }
            }
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
}
