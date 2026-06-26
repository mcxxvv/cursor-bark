#!/bin/bash
set -euo pipefail

export CURSOR_BARK_EVENT="stop"
exec "$(dirname "$0")/notify.sh"
