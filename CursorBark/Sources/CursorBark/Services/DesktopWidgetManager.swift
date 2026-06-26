import AppKit
import SwiftUI

@MainActor
final class DesktopWidgetManager {
    private var controllers: [WidgetKind: WidgetPanelController] = [:]
    private var lastSyncSignature: String = ""

    func sync(model: AppModel) {
        let signature = [
            model.config.monitor.showDesktopWidgets.description,
            model.config.monitor.showCompactWidget.description,
            model.config.monitor.showListWidget.description,
            model.config.monitor.showRunningWidget.description,
            model.isAnyTaskRunning.description,
        ].joined(separator: "|")

        let widgetsEnabled = model.config.monitor.showDesktopWidgets
        if !widgetsEnabled {
            hideAll()
            lastSyncSignature = signature
            return
        }

        if model.config.monitor.showCompactWidget {
            show(kind: .compact, model: model, size: NSSize(width: 260, height: 120))
        } else {
            hide(kind: .compact)
        }

        if model.config.monitor.showListWidget {
            show(kind: .list, model: model, size: NSSize(width: 320, height: 360))
        } else {
            hide(kind: .list)
        }

        if model.config.monitor.showRunningWidget, model.isAnyTaskRunning {
            show(kind: .running, model: model, size: NSSize(width: 300, height: 180))
        } else {
            hide(kind: .running)
        }

        if signature != lastSyncSignature {
            lastSyncSignature = signature
            controllers.values.forEach { $0.panel.orderFrontRegardless() }
        }
    }

    func hideAll() {
        controllers.values.forEach { $0.panel.orderOut(nil) }
    }

    private func show(kind: WidgetKind, model: AppModel, size: NSSize) {
        if let controller = controllers[kind] {
            controller.bind(model: model)
            controller.panel.setContentSize(size)
            controller.panel.orderFrontRegardless()
            return
        }

        let controller = WidgetPanelController(kind: kind, model: model, origin: defaultOrigin(for: kind), size: size)
        controllers[kind] = controller
        controller.panel.orderFrontRegardless()
    }

    private func hide(kind: WidgetKind) {
        controllers[kind]?.panel.orderOut(nil)
    }

    private func defaultOrigin(for kind: WidgetKind) -> NSPoint {
        guard let screen = NSScreen.main else { return .zero }
        let visible = screen.visibleFrame
        switch kind {
        case .compact:
            return NSPoint(x: visible.maxX - 280, y: visible.maxY - 150)
        case .list:
            return NSPoint(x: visible.maxX - 340, y: visible.midY - 180)
        case .running:
            return NSPoint(x: visible.minX + 24, y: visible.maxY - 220)
        }
    }
}

@MainActor
private final class WidgetPanelController {
    let panel: NSPanel
    private let hostingView: NSHostingView<AnyView>
    private weak var model: AppModel?
    private let kind: WidgetKind

    init(kind: WidgetKind, model: AppModel, origin: NSPoint, size: NSSize) {
        self.kind = kind
        self.model = model
        let root = WidgetPanelController.makeView(kind: kind, model: model)
        self.hostingView = NSHostingView(rootView: AnyView(root))

        panel = NSPanel(
            contentRect: NSRect(origin: origin, size: size),
            styleMask: [.nonactivatingPanel, .hudWindow, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.contentView = hostingView
    }

    func bind(model: AppModel) {
        self.model = model
    }

    @ViewBuilder
    private static func makeView(kind: WidgetKind, model: AppModel) -> some View {
        switch kind {
        case .compact:
            CompactWidgetView(model: model)
        case .list:
            ListWidgetView(model: model)
        case .running:
            RunningWidgetView(model: model)
        }
    }
}

private enum WidgetKind: CaseIterable {
    case compact
    case list
    case running
}
