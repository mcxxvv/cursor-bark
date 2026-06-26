#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PLIST="$HOME/Library/LaunchAgents/com.cursorbark.app.plist"
PYTHON_BIN="$(command -v python3)"

mkdir -p "$HOME/Library/LaunchAgents"

cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.cursorbark.app</string>
    <key>ProgramArguments</key>
    <array>
      <string>${PYTHON_BIN}</string>
      <string>-m</string>
      <string>cursor_bark</string>
      <string>run</string>
    </array>
    <key>WorkingDirectory</key>
    <string>${ROOT_DIR}</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>${HOME}/Library/Application Support/CursorBark/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${HOME}/Library/Application Support/CursorBark/stderr.log</string>
  </dict>
</plist>
EOF

launchctl bootout "gui/$(id -u)/com.cursorbark.app" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
launchctl enable "gui/$(id -u)/com.cursorbark.app"
launchctl kickstart -k "gui/$(id -u)/com.cursorbark.app"

echo "LaunchAgent installed: $PLIST"
