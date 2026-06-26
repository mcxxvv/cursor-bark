# Cursor Bark Bridge

Cursor 扩展：在 Cursor 内部监听 Agent 对话生命周期，通过本地 HTTP 端口向 **Cursor Bark** macOS 应用推送状态。

## 安装（拖放安装）

1. 在项目根目录运行打包脚本：

```bash
bash scripts/package-extension.sh
```

2. 打开 Cursor → **扩展** 面板
3. 将 `dist/cursor-bark-bridge-0.1.0.vsix` **拖入**扩展面板
4. 点击 **Install**，然后 **Reload Window**

安装后右下角会出现 `Bark :8766` 状态栏图标。

## 架构

```
Cursor Agent Hooks
       ↓ POST /event
Cursor Bark Bridge 扩展 (:8766)
       ↓ GET /snapshot
Cursor Bark macOS 应用
       ↓
Bark 推送 / 桌面组件 / 菜单栏状态
```

## 配置

Cursor 设置 → 搜索 `Cursor Bark Bridge`：

| 项 | 默认 | 说明 |
|----|------|------|
| `cursorBarkBridge.port` | 8766 | 桥接端口 |
| `cursorBarkBridge.host` | 127.0.0.1 | 监听地址 |
| `cursorBarkBridge.autoInstallHooks` | true | 激活时自动安装 Hooks |

## 命令

- **Cursor Bark: 显示桥接状态**
- **Cursor Bark: 安装/更新 Hooks**
- **Cursor Bark: 打开健康检查**

## 开发

```bash
cd extension
npm install
npm run compile
npm run package
```
