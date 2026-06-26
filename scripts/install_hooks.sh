#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
HOOKS_DIR="$HOME/.cursor/hooks"
HOOKS_JSON="$HOME/.cursor/hooks.json"
SOURCE_HOOK="$ROOT_DIR/hooks/notify.sh"
TARGET_HOOK="$HOOKS_DIR/cursor-bark-notify.sh"

mkdir -p "$HOOKS_DIR"
cp "$SOURCE_HOOK" "$TARGET_HOOK"
cp "$ROOT_DIR/hooks/stop.sh" "$HOOKS_DIR/cursor-bark-stop.sh"
cp "$ROOT_DIR/hooks/subagent_stop.sh" "$HOOKS_DIR/cursor-bark-subagent-stop.sh"
chmod +x "$TARGET_HOOK" "$HOOKS_DIR/cursor-bark-stop.sh" "$HOOKS_DIR/cursor-bark-subagent-stop.sh"

python3 - <<'PY'
import json
from pathlib import Path

hooks_json = Path.home() / ".cursor" / "hooks.json"

if hooks_json.exists():
    try:
        data = json.loads(hooks_json.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        data = {"version": 1, "hooks": {}}
else:
    data = {"version": 1, "hooks": {}}

data.setdefault("version", 1)
hooks = data.setdefault("hooks", {})

def upsert(event, command):
    items = hooks.setdefault(event, [])
    items[:] = [item for item in items if item.get("command") != command]
    items.append({"command": command})

upsert("stop", "./hooks/cursor-bark-stop.sh")
upsert("subagentStop", "./hooks/cursor-bark-subagent-stop.sh")

hooks_json.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
print(f"Updated {hooks_json}")
PY

echo "Cursor Bark hook installed."
echo "Restart Cursor to load hooks."
