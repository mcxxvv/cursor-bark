import SwiftUI

struct MainDashboardView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(selection: $model.selectedTab) {
                Label("控制台", systemImage: "square.grid.2x2").tag(AppTab.dashboard)
                Label("会话监听", systemImage: "bubble.left.and.bubble.right").tag(AppTab.conversations)
                Label("桌面组件", systemImage: "rectangle.on.rectangle").tag(AppTab.widgets)
                Label("Bark 设置", systemImage: "bell.badge").tag(AppTab.settings)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 180)
        } detail: {
            Group {
                switch model.selectedTab {
                case .dashboard:
                    DashboardPanelView(model: model)
                case .conversations:
                    ConversationsPanelView(model: model)
                case .widgets:
                    WidgetsPanelView(model: model)
                case .settings:
                    SettingsView(model: model)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationSplitViewColumnWidth(min: 180, ideal: 200)
        .alert("Cursor Bark", isPresented: $model.showAlert) {
            Button("好", role: .cancel) {}
        } message: {
            Text(model.alertMessage ?? "")
        }
    }
}

enum AppTab: Hashable {
    case dashboard
    case conversations
    case widgets
    case settings
}
