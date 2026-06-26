"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const vscode = __importStar(require("vscode"));
const composerMeta_1 = require("./composerMeta");
const hookInstaller_1 = require("./hookInstaller");
const statusServer_1 = require("./statusServer");
const statusTracker_1 = require("./statusTracker");
let tracker;
let server;
let metaTimer;
let bridgeHost = "127.0.0.1";
let bridgePort = 8766;
let bridgeMode = "failed";
let bridgeError;
async function activate(context) {
    tracker = new statusTracker_1.StatusTracker();
    server = new statusServer_1.StatusServer(tracker);
    bridgeHost = vscode.workspace.getConfiguration("cursorBarkBridge").get("host", "127.0.0.1");
    bridgePort = vscode.workspace.getConfiguration("cursorBarkBridge").get("port", 8766);
    const statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
    statusItem.command = "cursorBarkBridge.showStatus";
    context.subscriptions.push(statusItem);
    context.subscriptions.push(vscode.commands.registerCommand("cursorBarkBridge.showStatus", async () => {
        const snapshot = await readSnapshot();
        const running = snapshot?.conversations.filter((item) => item.status === "running").length ?? 0;
        const total = snapshot?.conversations.length ?? 0;
        const modeLabel = bridgeMode === "attached" ? "（复用已有服务）" : bridgeMode === "started" ? "" : "（未启动）";
        const errorSuffix = bridgeError ? ` · 错误: ${bridgeError}` : "";
        vscode.window.showInformationMessage(`Cursor Bark Bridge · :${bridgePort}${modeLabel} · 对话 ${total} · 进行中 ${running}${errorSuffix}`);
    }), vscode.commands.registerCommand("cursorBarkBridge.installHooks", () => {
        const hooksFile = (0, hookInstaller_1.installBridgeHooks)(bridgePort);
        vscode.window.showInformationMessage(`Cursor Bark Hooks 已更新: ${hooksFile}`);
    }), vscode.commands.registerCommand("cursorBarkBridge.openHealth", async () => {
        const healthUrl = `http://${bridgeHost}:${bridgePort}/health`;
        try {
            const response = await fetch(healthUrl);
            const body = await response.text();
            vscode.window.showInformationMessage(`健康检查 ${healthUrl} → ${body}`);
        }
        catch (error) {
            const message = error instanceof Error ? error.message : String(error);
            vscode.window.showErrorMessage(`无法访问 ${healthUrl}: ${message}`);
        }
    }), vscode.workspace.onDidChangeConfiguration(async (event) => {
        if (!event.affectsConfiguration("cursorBarkBridge")) {
            return;
        }
        bridgeHost = vscode.workspace.getConfiguration("cursorBarkBridge").get("host", "127.0.0.1");
        bridgePort = vscode.workspace.getConfiguration("cursorBarkBridge").get("port", 8766);
        await startBridge(statusItem);
    }), {
        dispose: () => {
            void shutdownBridge();
        },
    });
    await startBridge(statusItem);
}
async function readSnapshot() {
    if (bridgeMode === "started") {
        return tracker?.peekSnapshot(bridgePort);
    }
    return (0, statusServer_1.fetchBridgeSnapshot)(bridgeHost, bridgePort);
}
async function startBridge(statusItem) {
    const autoInstallHooks = vscode.workspace
        .getConfiguration("cursorBarkBridge")
        .get("autoInstallHooks", true);
    try {
        const mode = await server.start(bridgeHost, bridgePort);
        bridgeMode = mode;
        bridgeError = undefined;
        if (mode === "started") {
            statusItem.text = `$(radio-tower) Bark :${bridgePort}`;
            statusItem.tooltip = `Cursor Bark Bridge 运行中 · ${bridgeHost}:${bridgePort}`;
            statusItem.backgroundColor = undefined;
            if (autoInstallHooks) {
                (0, hookInstaller_1.installBridgeHooks)(bridgePort);
            }
            startMetaPolling();
        }
        else {
            statusItem.text = `$(radio-tower) Bark :${bridgePort}`;
            statusItem.tooltip = `已连接到现有桥接服务 · ${bridgeHost}:${bridgePort}`;
            statusItem.backgroundColor = undefined;
            if (autoInstallHooks) {
                (0, hookInstaller_1.installBridgeHooks)(bridgePort);
            }
        }
        statusItem.show();
    }
    catch (error) {
        bridgeMode = "failed";
        bridgeError = error instanceof Error ? error.message : String(error);
        statusItem.text = `$(error) Bark :${bridgePort}`;
        statusItem.tooltip = `桥接启动失败: ${bridgeError}`;
        statusItem.backgroundColor = new vscode.ThemeColor("statusBarItem.errorBackground");
        statusItem.show();
        const occupied = bridgeError.includes("EADDRINUSE");
        const hint = occupied
            ? "端口已被占用。可重载 Cursor 窗口，或在设置中修改 cursorBarkBridge.port。"
            : bridgeError;
        vscode.window.showErrorMessage(`Cursor Bark Bridge 启动失败 (:${bridgePort}): ${hint}`);
    }
}
function startMetaPolling() {
    if (bridgeMode !== "started") {
        return;
    }
    if (metaTimer) {
        clearInterval(metaTimer);
    }
    const interval = vscode.workspace
        .getConfiguration("cursorBarkBridge")
        .get("pollComposerMetaMs", 5000);
    const tick = () => {
        if (!tracker) {
            return;
        }
        try {
            const result = (0, composerMeta_1.loadComposerSnapshot)();
            tracker.applyComposerMeta(result.entries, result.ok);
            if (!result.ok && result.error) {
                console.warn("[cursor-bark-bridge] composer meta unavailable:", result.error);
            }
        }
        catch (error) {
            console.error("[cursor-bark-bridge] composer meta refresh failed", error);
        }
    };
    tick();
    metaTimer = setInterval(tick, Math.max(interval, 2000));
}
async function shutdownBridge() {
    if (metaTimer) {
        clearInterval(metaTimer);
        metaTimer = undefined;
    }
    if (bridgeMode === "started") {
        await server?.stop();
    }
}
async function deactivate() {
    await shutdownBridge();
}
//# sourceMappingURL=extension.js.map