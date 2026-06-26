import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        Form {
            Section("Bark 推送") {
                SecureField("Device Key", text: $model.config.bark.deviceKey)
                TextField("服务器地址", text: $model.config.bark.serverURL)
                TextField("通知分组", text: $model.config.bark.group)
                Picker("通知级别", selection: $model.config.bark.level) {
                    Text("时效性").tag("timeSensitive")
                    Text("默认").tag("active")
                    Text("静默").tag("passive")
                    Text("重要").tag("critical")
                }
                TextField("铃声（可选）", text: $model.config.bark.sound)
                TextField("图标 URL（可选）", text: $model.config.bark.icon)
            }

            Section("Cursor 插件桥接") {
                Toggle("启用通知", isOn: $model.config.enabled)
                Toggle("任务开始时本地提醒", isOn: $model.config.monitor.notifyOnTaskStart)
                TextField("插件地址", text: $model.config.monitor.extensionHost)
                Stepper(
                    "插件端口: \(model.config.monitor.extensionPort)",
                    value: $model.config.monitor.extensionPort,
                    in: 1024 ... 65535
                )
                LabeledContent("插件连接", value: model.bridgeConnected ? "已连接" : "未连接")
                Text("请先将 dist/cursor-bark-bridge-0.1.0.vsix 拖入 Cursor 扩展面板安装，默认端口 8766。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("子 Agent 完成时通知", isOn: $model.config.monitor.notifySubagents)
                Toggle("失败/取消时通知", isOn: $model.config.monitor.notifyOnError)
                Toggle("推送包含任务摘要", isOn: $model.config.monitor.includeSummary)
                Stepper(
                    "摘要长度: \(model.config.monitor.summaryMaxChars)",
                    value: $model.config.monitor.summaryMaxChars,
                    in: 60 ... 500,
                    step: 20
                )
            }

            Section("状态") {
                LabeledContent("当前状态", value: model.statusText)
                if !model.lastMessage.isEmpty {
                    LabeledContent("最近通知", value: model.lastMessage)
                }
                Toggle("登录时自动启动", isOn: Binding(
                    get: { model.launchAtLogin },
                    set: { model.setLaunchAtLogin($0) }
                ))
                LabeledContent("配置文件", value: AppConfig.configURL.path)
            }

            HStack {
                Button("保存并应用") {
                    model.saveConfig()
                }
                .keyboardShortcut(.defaultAction)

                Button("发送测试推送") {
                    Task { await model.sendTestNotification() }
                }

                Button("打开 VSIX 安装包") {
                    model.openExtensionPackage()
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 520, minHeight: 560)
        .padding()
        .navigationTitle("Cursor Bark 设置")
    }
}
