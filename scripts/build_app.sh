#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "Building CleanPaste (release)..."
swift build --disable-sandbox -c release

BUILD_BIN_DIR="$(swift build --disable-sandbox -c release --show-bin-path)"
BIN_PATH="$BUILD_BIN_DIR/CleanPaste"
APP_DIR="$ROOT_DIR/build/CleanPaste.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Generating AppIcon.icns..."
swift "$ROOT_DIR/scripts/generate_icon.swift" "$ROOT_DIR/Resources/AppIcon.icns"

echo "Packaging CleanPaste.app..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$BIN_PATH" "$MACOS_DIR/CleanPaste"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
cp "$ROOT_DIR/Resources/MenuBarIcon@2x.png" "$RESOURCES_DIR/MenuBarIcon@2x.png"
if [ -d "$BUILD_BIN_DIR/CleanPaste_CleanPaste.bundle" ]; then
    cp -R "$BUILD_BIN_DIR/CleanPaste_CleanPaste.bundle" "$RESOURCES_DIR/"
fi

echo "Ad-hoc signing CleanPaste.app..."
codesign --force --deep --sign - "$APP_DIR"

echo "Done! App bundle ready at: $APP_DIR"
