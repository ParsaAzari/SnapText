#!/bin/bash
set -e

APP_NAME="SnapText"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "==> Cleaning old build..."
rm -rf "$BUILD_DIR"
mkdir -p "$MACOS" "$RESOURCES"

echo "==> Compiling Swift sources..."
swiftc \
    -O \
    -target arm64-apple-macosx12.0 \
    -framework Cocoa \
    -framework SwiftUI \
    -framework Vision \
    -framework Carbon \
    -framework UserNotifications \
    -lsqlite3 \
    "$PROJECT_DIR/Sources/BidiReconstructor.swift" \
    "$PROJECT_DIR/Sources/PersianNormalizer.swift" \
    "$PROJECT_DIR/Sources/ImagePreProcessor.swift" \
    "$PROJECT_DIR/Sources/AppPreferences.swift" \
    "$PROJECT_DIR/Sources/HistoryStore.swift" \
    "$PROJECT_DIR/Sources/OCRService.swift" \
    "$PROJECT_DIR/Sources/CaptureService.swift" \
    "$PROJECT_DIR/Sources/HotKeyManager.swift" \
    "$PROJECT_DIR/Sources/Views/MacPopUpButton.swift" \
    "$PROJECT_DIR/Sources/Views/GlassHUDNotification.swift" \
    "$PROJECT_DIR/Sources/Views/ResultWindowView.swift" \
    "$PROJECT_DIR/Sources/Views/CapturedTextsView.swift" \
    "$PROJECT_DIR/Sources/Views/AboutWindowView.swift" \
    "$PROJECT_DIR/Sources/Views/SettingsView.swift" \
    "$PROJECT_DIR/Sources/AppDelegate.swift" \
    "$PROJECT_DIR/Sources/main.swift" \
    -o "$MACOS/$APP_NAME"

echo "==> Copying Info.plist and resources..."
cp "$PROJECT_DIR/Resources/Info.plist" "$CONTENTS/Info.plist"
cp -r "$PROJECT_DIR/Resources/tessdata" "$RESOURCES/"
cp -r "$PROJECT_DIR/Resources/Fonts" "$RESOURCES/"
cp "$PROJECT_DIR/Resources/AppIcon.icns" "$RESOURCES/"
cp "$PROJECT_DIR/Resources/AppIcon.png" "$RESOURCES/"

echo "==> Ad-hoc signing bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "==> Build successful: $APP_BUNDLE"
