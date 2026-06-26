#!/bin/bash
set -euo pipefail

INPUT="$(cat)"
LOG_DIR="$HOME/Library/Application Support/CursorBark"
LOG_FILE="$LOG_DIR/hook.log"
CONFIG_FILE="$LOG_DIR/config.json"
mkdir -p "$LOG_DIR"

PORT="8765"
if [[ -f "$CONFIG_FILE" ]]; then
  PARSED_PORT="$(python3 - <<'PY' 2>/dev/null || true
import json, os
path = os.path.expanduser("~/Library/Application Support/CursorBark/config.json")
try:
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    print(data.get("monitor", {}).get("listen_port", 8765))
except Exception:
    print(8765)
PY
)"
  if [[ -n "$PARSED_PORT" ]]; then
    PORT="$PARSED_PORT"
  fi
fi

PAYLOAD="$(printf '%s' "$INPUT" | python3 - <<'PY'
import json
import os
import sys

raw = sys.stdin.read()
try:
    data = json.loads(raw) if raw.strip() else {}
except json.JSONDecodeError:
    data = {"raw_input": raw}

event = os.environ.get("CURSOR_BARK_EVENT", "stop")
data["_event"] = event
data["_source"] = "cursor-hook"
print(json.dumps(data, ensure_ascii=False))
PY
)"

HTTP_CODE="$(curl -sS -o /dev/null -w "%{http_code}" \
  -X POST "http://127.0.0.1:${PORT}/hook" \
  -H "Content-Type: application/json; charset=utf-8" \
  --data-binary "$PAYLOAD" \
  --connect-timeout 2 \
  --max-time 5 || echo "000")"

{
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] hook event=${CURSOR_BARK_EVENT:-stop} http=${HTTP_CODE}"
} >>"$LOG_FILE"

echo '{}'
exit 0
