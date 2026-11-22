#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Default to ad-hoc signing (-) for redistributable DMGs so a personal
# "Apple Development: <name/email>" certificate is never embedded by accident.
export CODESIGN_IDENTITY="${DMG_CODESIGN_IDENTITY:--}"

"$ROOT_DIR/scripts/build_app.sh"

APP_DIR="$ROOT_DIR/build/CleanPaste.app"
BIN_FILE="$APP_DIR/Contents/MacOS/CleanPaste"
DMG_PATH="$ROOT_DIR/build/CleanPaste.dmg"
SHA_PATH="$ROOT_DIR/build/CleanPaste.dmg.sha256"

echo "Running privacy audit on CleanPaste.app..."
if strings "$BIN_FILE" | grep -E '/Users/|@gmail\.com' >/dev/null 2>&1; then
    echo "ERROR: Local user path or email detected in compiled binary:" >&2
    strings "$BIN_FILE" | grep -E '/Users/|@gmail\.com' >&2
    exit 1
fi

if [ "$CODESIGN_IDENTITY" = "-" ]; then
    if codesign -dvvv "$APP_DIR" 2>&1 | grep -E '^Authority=' >/dev/null 2>&1; then
        echo "ERROR: Unexpected certificate Authority in ad-hoc DMG build." >&2
        exit 1
    fi
fi
echo "Privacy audit passed (zero local paths or personal certificate strings)."

STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cleanpaste-dmg.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT

cp -R "$APP_DIR" "$STAGE_DIR/CleanPaste.app"
ln -s /Applications "$STAGE_DIR/Applications"

echo "Creating $DMG_PATH..."
rm -f "$DMG_PATH" "$SHA_PATH"
hdiutil create \
    -volname "CleanPaste" \
    -srcfolder "$STAGE_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH"

shasum -a 256 "$DMG_PATH" | awk '{print $1 "  CleanPaste.dmg"}' > "$SHA_PATH"

echo "Done! DMG ready at: $DMG_PATH"
echo "SHA-256: $(cat "$SHA_PATH")"
