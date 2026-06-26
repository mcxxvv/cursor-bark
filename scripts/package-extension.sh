#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
EXT="$ROOT/extension"
DIST="$ROOT/dist"

mkdir -p "$DIST"

echo "Building Cursor Bark Bridge VSIX..."
cd "$EXT"
npm install
npm run package

VSIX="$(ls -t "$EXT"/cursor-bark-bridge-*.vsix 2>/dev/null | head -1)"
if [[ -z "$VSIX" ]]; then
  echo "VSIX build failed" >&2
  exit 1
fi

cp "$VSIX" "$DIST/"
BASENAME="$(basename "$VSIX")"

echo
echo "已生成: $DIST/$BASENAME"
echo
echo "安装方式："
echo "  1. 打开 Cursor → 扩展 (Extensions)"
echo "  2. 把 $DIST/$BASENAME 拖进扩展面板"
echo "  3. 点击安装，然后重载窗口"
