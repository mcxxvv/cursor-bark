# 🐶 cursor-bark

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Version](https://img.shields.io/badge/Plugin-v0.1.3-blue.svg)]()

**将 Cursor 的 AI 会话消息实时推送到你的手机。**

`cursor-bark` 是一个轻量级的消息桥接工具。它能让你在 Cursor IDE 中编写代码、与 AI 交互时，通过 Bark 将关键的会话状态或结果实时推送到你的移动设备上。无论你是在倒水、摸鱼还是在处理其他事务，都能第一时间掌握 Cursor 的任务进度。

## ✨ 特性

- **无缝集成**：通过安装 VSIX 插件，一键接入 Cursor IDE。
- **实时推送**：基于 Bark 的成熟推送服务，消息直达手机，低延迟。
- **按需监听**：支持多会话环境，你可以自由选择需要监听的具体会话，避免无效打扰。
- **原生体验**：提供独立的配套 App，可视化管理 Bark 连接与会话监听，开箱即用。

## 🚀 快速开始

使用 `cursor-bark` 只需简单三个步骤：

### 第一步：安装 IDE 插件

1. 下载本仓库中的插件包 `cursor-bark-bridge-0.1.3.vsix`。
2. 打开 Cursor (或 VSCode)，进入扩展面板 (`Ctrl+Shift+X` / `Cmd+Shift+X`)。
3. 点击右上角的 `...` 菜单，选择 **“从 VSIX 安装...”**。
4. 选中下载好的 `cursor-bark-bridge-0.1.3.vsix` 文件完成安装。
5. 安装完成后，在插件设置中配置与 App 通信的 **端口号**。

### 第二步：配置 App 与 Bark 连接

1. 下载并打开配套的 `cursorbark` App。
2. 在 App 中输入你的 Bark 推送 Key 或完整的 Bark 连接信息。
3. 确保 App 与运行 Cursor 的电脑处于同一网络环境（或已配置好端口转发）。

### 第三步：选择会话并开始监听

1. 在 Cursor IDE 中发起或进行 AI 会话。
2. 回到 `cursorbark` App 中，在会话列表里 **选择你需要监听的会话**。
3. 开启监听。此时，该会话产生的相关消息就会自动推送到你的手机上啦！📱

## 🛠️ 工作原理

1. **IDE 插件** 作为监听器，捕获 Cursor 中指定会话的消息。
2. 插件通过你配置的 **端口** 将消息发送给 `cursorbark` App。
3. App 将消息格式化后，通过 **Bark API** 发送到推送服务器。
4. 你的手机收到实时通知。

## 📦 下载与安装

前往本项目的 [Releases 页面](./releases) 下载最新版本的资源：
- `cursor-bark-bridge-0.1.3.vsix` (Cursor 插件)
- `cursorbark` App 安装包

## 📖 使用场景

- **长时间运行的任务**：让 AI 编写大量代码或进行复杂重构时，去干点别的，完成后手机震动提醒。
- **报错捕获**：当 AI 在执行过程中遇到无法解决的报错时，第一时间收到通知并回来接管。
- **多设备协同**：在电脑上跑着 Cursor，人离开工位时用手机随时掌握进度。

## 🤝 贡献

欢迎提交 Issue 和 Pull Request！如果你有任何功能建议或遇到了 Bug，请随时告诉我们。

## 📄 许可证

本项目采用 [MIT License](./LICENSE) 开源。

---

**提示**：使用本工具前，请确保你的手机已安装 Bark 客户端，并已获取有效的推送 Key。
