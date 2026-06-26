import SwiftUI

struct MenuBarStatusView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        HStack(spacing: 8) {
            if model.isAnyTaskRunning {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: model.menuBarSymbol)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(model.isAnyTaskRunning ? "任务进行中" : "Cursor Bark")
                    .font(.headline)
                Text(model.statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
    }
}

struct MenuBarControlsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MenuBarStatusView(model: model)

            if model.isAnyTaskRunning {
                Text(model.runningTitles.joined(separator: "\n"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                Divider()
            }

            Button("显示主面板") {
                model.showMainWindow()
            }
            Button(model.config.enabled ? "暂停通知" : "启用通知") {
                model.toggleEnabled()
            }
            Button("刷新会话") {
                model.refreshConversations()
            }
            Button("发送测试推送") {
                Task { await model.sendTestNotification() }
            }
            Divider()
            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}

import AppKit
