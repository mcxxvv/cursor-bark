#!/bin/bash
set -euo pipefail

export CURSOR_BARK_EVENT="subagentStop"
exec "$(dirname "$0")/notify.sh"
