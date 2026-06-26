import SwiftUI

struct WidgetsPanelView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("桌面浮动组件") {
                Toggle("启用桌面组件", isOn: $model.config.monitor.showDesktopWidgets)
                Toggle("状态概览", isOn: $model.config.monitor.showCompactWidget)
                Toggle("会话列表", isOn: $model.config.monitor.showListWidget)
                Toggle("进行中面板", isOn: $model.config.monitor.showRunningWidget)
                Text("这些组件是浮动窗口，可拖到桌面任意位置，始终置顶显示实时进度。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("预览") {
                CompactWidgetView(model: model)
                ListWidgetView(model: model)
                RunningWidgetView(model: model)
            }

            Button("保存并应用") {
                model.saveConfig()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct WidgetCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.15))
        )
    }
}

struct CompactWidgetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        WidgetCard(title: "状态概览") {
            HStack {
                if model.isAnyTaskRunning {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "bell.badge")
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.isAnyTaskRunning ? "任务进行中" : "等待任务")
                        .font(.headline)
                    Text("监听 \(model.monitoredConversationCount) · 进行中 \(model.runningConversationCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }
}

struct ListWidgetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        WidgetCard(title: "会话列表") {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(model.monitoredConversations.prefix(5)) { item in
                    HStack {
                        Circle()
                            .fill(item.status == .running ? .orange : .green)
                            .frame(width: 8, height: 8)
                        Text(item.title)
                            .lineLimit(1)
                            .font(.caption)
                        Spacer()
                        Text(item.status == .running ? "进行中" : "空闲")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                if model.monitoredConversations.isEmpty {
                    Text("暂无监听会话")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct RunningWidgetView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        WidgetCard(title: "进行中") {
            if model.runningConversations.isEmpty {
                Text("当前没有进行中的任务")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(model.runningConversations) { item in
                        HStack(alignment: .top, spacing: 8) {
                            ProgressView().controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.caption.bold())
                                Text(item.subtitle.isEmpty ? item.displayProject : item.subtitle)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
    }
}
