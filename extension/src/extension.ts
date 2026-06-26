import * as vscode from "vscode";
import { loadComposerSnapshot } from "./composerMeta";
import { installBridgeHooks } from "./hookInstaller";
import { fetchBridgeSnapshot, probeBridge, StatusServer } from "./statusServer";
import { StatusTracker } from "./statusTracker";

let tracker: StatusTracker | undefined;
let server: StatusServer | undefined;
let metaTimer: NodeJS.Timeout | undefined;
let bridgeHost = "127.0.0.1";
let bridgePort = 8766;
let bridgeMode: "started" | "attached" | "failed" = "failed";
let bridgeError: string | undefined;

export async function activate(context: vscode.ExtensionContext): Promise<void> {
  tracker = new StatusTracker();
  server = new StatusServer(tracker);

  bridgeHost = vscode.workspace.getConfiguration("cursorBarkBridge").get<string>("host", "127.0.0.1");
  bridgePort = vscode.workspace.getConfiguration("cursorBarkBridge").get<number>("port", 8766);

  const statusItem = vscode.window.createStatusBarItem(vscode.StatusBarAlignment.Right, 100);
  statusItem.command = "cursorBarkBridge.showStatus";
  context.subscriptions.push(statusItem);

  context.subscriptions.push(
    vscode.commands.registerCommand("cursorBarkBridge.showStatus", async () => {
      const snapshot = await readSnapshot();
      const running = snapshot?.conversations.filter((item) => item.status === "running").length ?? 0;
      const total = snapshot?.conversations.length ?? 0;
      const modeLabel =
        bridgeMode === "attached" ? "（复用已有服务）" : bridgeMode === "started" ? "" : "（未启动）";
      const errorSuffix = bridgeError ? ` · 错误: ${bridgeError}` : "";
      vscode.window.showInformationMessage(
        `Cursor Bark Bridge · :${bridgePort}${modeLabel} · 对话 ${total} · 进行中 ${running}${errorSuffix}`
      );
    }),
    vscode.commands.registerCommand("cursorBarkBridge.installHooks", () => {
      const hooksFile = installBridgeHooks(bridgePort);
      vscode.window.showInformationMessage(`Cursor Bark Hooks 已更新: ${hooksFile}`);
    }),
    vscode.commands.registerCommand("cursorBarkBridge.openHealth", async () => {
      const healthUrl = `http://${bridgeHost}:${bridgePort}/health`;
      try {
        const response = await fetch(healthUrl);
        const body = await response.text();
        vscode.window.showInformationMessage(`健康检查 ${healthUrl} → ${body}`);
      } catch (error) {
        const message = error instanceof Error ? error.message : String(error);
        vscode.window.showErrorMessage(`无法访问 ${healthUrl}: ${message}`);
      }
    }),
    vscode.workspace.onDidChangeConfiguration(async (event) => {
      if (!event.affectsConfiguration("cursorBarkBridge")) {
        return;
      }
      bridgeHost = vscode.workspace.getConfiguration("cursorBarkBridge").get<string>("host", "127.0.0.1");
      bridgePort = vscode.workspace.getConfiguration("cursorBarkBridge").get<number>("port", 8766);
      await startBridge(statusItem);
    }),
    {
      dispose: () => {
        void shutdownBridge();
      },
    }
  );

  await startBridge(statusItem);
}

async function readSnapshot() {
  if (bridgeMode === "started") {
    return tracker?.peekSnapshot(bridgePort);
  }
  return fetchBridgeSnapshot(bridgeHost, bridgePort);
}

async function startBridge(statusItem: vscode.StatusBarItem): Promise<void> {
  const autoInstallHooks = vscode.workspace
    .getConfiguration("cursorBarkBridge")
    .get<boolean>("autoInstallHooks", true);

  try {
    const mode = await server!.start(bridgeHost, bridgePort);
    bridgeMode = mode;
    bridgeError = undefined;

    if (mode === "started") {
      statusItem.text = `$(radio-tower) Bark :${bridgePort}`;
      statusItem.tooltip = `Cursor Bark Bridge 运行中 · ${bridgeHost}:${bridgePort}`;
      statusItem.backgroundColor = undefined;
      if (autoInstallHooks) {
        installBridgeHooks(bridgePort);
      }
      startMetaPolling();
    } else {
      statusItem.text = `$(radio-tower) Bark :${bridgePort}`;
      statusItem.tooltip = `已连接到现有桥接服务 · ${bridgeHost}:${bridgePort}`;
      statusItem.backgroundColor = undefined;
      if (autoInstallHooks) {
        installBridgeHooks(bridgePort);
      }
    }

    statusItem.show();
  } catch (error) {
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

function startMetaPolling(): void {
  if (bridgeMode !== "started") {
    return;
  }
  if (metaTimer) {
    clearInterval(metaTimer);
  }
  const interval = vscode.workspace
    .getConfiguration("cursorBarkBridge")
    .get<number>("pollComposerMetaMs", 5000);

  const tick = () => {
    if (!tracker) {
      return;
    }
    try {
      const result = loadComposerSnapshot();
      tracker.applyComposerMeta(result.entries, result.ok);
      if (!result.ok && result.error) {
        console.warn("[cursor-bark-bridge] composer meta unavailable:", result.error);
      }
    } catch (error) {
      console.error("[cursor-bark-bridge] composer meta refresh failed", error);
    }
  };

  tick();
  metaTimer = setInterval(tick, Math.max(interval, 2000));
}

async function shutdownBridge(): Promise<void> {
  if (metaTimer) {
    clearInterval(metaTimer);
    metaTimer = undefined;
  }
  if (bridgeMode === "started") {
    await server?.stop();
  }
}

export async function deactivate(): Promise<void> {
  await shutdownBridge();
}
