#!/bin/bash
set -euo pipefail

export CURSOR_BARK_EVENT="subagentStop"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
exec "$SCRIPT_DIR/cursor-bark-notify.sh"
