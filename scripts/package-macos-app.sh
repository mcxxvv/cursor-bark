#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/CursorBark"
BUILD_DIR="$APP_DIR/.build/release"
APP_NAME="Cursor Bark"
BUNDLE_DIR="$ROOT_DIR/dist/CursorBark.app"

cd "$APP_DIR"
swift build -c release

mkdir -p "$BUNDLE_DIR/Contents/MacOS"
mkdir -p "$BUNDLE_DIR/Contents/Resources"

cp "$BUILD_DIR/CursorBark" "$BUNDLE_DIR/Contents/MacOS/CursorBark"
chmod +x "$BUNDLE_DIR/Contents/MacOS/CursorBark"

RESOURCES_DIR="$BUILD_DIR/CursorBark_CursorBark.bundle/Contents/Resources"
BUNDLE_RESOURCES="$BUNDLE_DIR/Contents/Resources"
if [[ -d "$RESOURCES_DIR" ]]; then
  cp -R "$RESOURCES_DIR/." "$BUNDLE_RESOURCES/"
fi

# Keep SPM resource bundle available when running as .app
if [[ -d "$BUILD_DIR/CursorBark_CursorBark.bundle" ]]; then
  cp -R "$BUILD_DIR/CursorBark_CursorBark.bundle" "$BUNDLE_DIR/Contents/MacOS/"
fi

cat >"$BUNDLE_DIR/Contents/Info.plist" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh-Hans</string>
  <key>CFBundleExecutable</key>
  <string>CursorBark</string>
  <key>CFBundleIdentifier</key>
  <string>com.cursorbark.app</string>
  <key>CFBundleName</key>
  <string>Cursor Bark</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Built: $BUNDLE_DIR"
echo "Run: open \"$BUNDLE_DIR\""
