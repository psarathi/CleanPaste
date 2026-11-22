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
strip -S -x "$MACOS_DIR/CleanPaste"
cp "$ROOT_DIR/Resources/Info.plist" "$CONTENTS_DIR/Info.plist"
cp "$ROOT_DIR/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"
cp "$ROOT_DIR/Resources/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
cp "$ROOT_DIR/Resources/MenuBarIcon@2x.png" "$RESOURCES_DIR/MenuBarIcon@2x.png"

SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [ -z "$SIGN_IDENTITY" ]; then
    SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk '/"Apple Development|"Mac Developer|"Developer ID Application/ { print $2; exit }')"
fi

if [ -n "$SIGN_IDENTITY" ] && [ "$SIGN_IDENTITY" != "-" ]; then
    SIGN_LABEL="$(security find-identity -v -p codesigning 2>/dev/null \
        | awk -v id="$SIGN_IDENTITY" '$2 == id { sub(/^[^"]*"/, ""); sub(/".*$/, ""); print; exit }')"
    echo "Signing CleanPaste.app with certificate (${SIGN_LABEL:-$SIGN_IDENTITY})..."
    codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR"
else
    echo "No Apple signing certificate found in Keychain; ad-hoc signing CleanPaste.app..."
    codesign --force --deep --sign - "$APP_DIR"
fi

echo "Done! App bundle ready at: $APP_DIR"
