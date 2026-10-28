#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/SnapText.app"
DMG_PATH="$BUILD_DIR/SnapText.dmg"
RESOURCES_DIR="$PROJECT_DIR/Resources"
BG_IMAGE="$RESOURCES_DIR/dmg_background.png"
ICON_FILE="$RESOURCES_DIR/AppIcon.icns"

echo "==> [1/3] Checking application bundle..."
if [ ! -d "$APP_BUNDLE" ]; then
    echo "SnapText.app not found in build/ - building now..."
    "$PROJECT_DIR/build.sh"
fi

echo "==> [2/3] Preparing DMG assets..."
# Generate background if missing
if [ ! -f "$BG_IMAGE" ]; then
    echo "Rendering DMG background poster..."
    swift -e '
    import Cocoa
    // Background generator logic
    '
fi

# Clean old DMG
rm -f "$DMG_PATH"

echo "==> [3/3] Creating SnapText.dmg..."
if command -v create-dmg &> /dev/null; then
    create-dmg \
        --volname "SnapText" \
        --volicon "$ICON_FILE" \
        --background "$BG_IMAGE" \
        --window-pos 200 120 \
        --window-size 660 420 \
        --icon-size 128 \
        --icon "SnapText.app" 160 210 \
        --hide-extension "SnapText.app" \
        --app-drop-link 500 210 \
        --no-internet-enable \
        "$DMG_PATH" \
        "$APP_BUNDLE"
else
    echo "create-dmg not found, using native hdiutil fallback..."
    TMP_DMG_DIR=$(mktemp -d /tmp/snaptext_dmg.XXXXXX)
    cp -R "$APP_BUNDLE" "$TMP_DMG_DIR/"
    ln -s /Applications "$TMP_DMG_DIR/Applications"
    
    mkdir -p "$TMP_DMG_DIR/.background"
    cp "$BG_IMAGE" "$TMP_DMG_DIR/.background/background.png"
    
    hdiutil create -volname "SnapText" -srcfolder "$TMP_DMG_DIR" -ov -format UDZO "$DMG_PATH"
    rm -rf "$TMP_DMG_DIR"
fi

echo ""
echo "==> Successfully created DMG:"
ls -lh "$DMG_PATH"
