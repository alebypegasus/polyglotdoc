#!/usr/bin/env bash
set -e

echo "=========================================="
echo " Building PolyGlotDoc AI for macOS (DMG)  "
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/frontend_flutter"
DIST_DIR="$ROOT_DIR/dist/macos"

mkdir -p "$DIST_DIR"

cd "$FLUTTER_DIR"
if [ ! -d "build/macos/Build/Products/Release" ]; then
    echo ">> Running Flutter build macos --release..."
    flutter build macos --release
fi

APP_PATH=$(find "$FLUTTER_DIR/build/macos/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo ">> Release app not found, running Flutter build macos --release..."
    flutter build macos --release
    APP_PATH=$(find "$FLUTTER_DIR/build/macos/Build/Products/Release" -maxdepth 1 -name "*.app" | head -n 1)
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: No .app bundle found in $FLUTTER_DIR/build/macos/Build/Products/Release"
    exit 1
fi

echo ">> Found App bundle: $APP_PATH"

DMG_NAME="PolyGlotDoc_AI_macOS_Universal.dmg"
DMG_PATH="$DIST_DIR/$DMG_NAME"
TMP_DMG_DIR="/tmp/polyglotdoc_dmg_build"

rm -rf "$TMP_DMG_DIR" "$DMG_PATH"
mkdir -p "$TMP_DMG_DIR"

echo ">> Preparing DMG contents..."
cp -R "$APP_PATH" "$TMP_DMG_DIR/"
ln -s /Applications "$TMP_DMG_DIR/Applications"

echo ">> Creating DMG disk image..."
hdiutil create -volname "PolyGlotDoc AI" \
  -srcfolder "$TMP_DMG_DIR" \
  -ov -format UDZO \
  "$DMG_PATH"

rm -rf "$TMP_DMG_DIR"

echo ">> Creating macOS ZIP bundle..."
ZIP_NAME="PolyGlotDoc_AI_macOS.zip"
cd "$FLUTTER_DIR/build/macos/Build/Products/Release"
zip -r -q "$DIST_DIR/$ZIP_NAME" "$(basename "$APP_PATH")"

echo "=========================================="
echo " macOS DMG created at: $DMG_PATH"
echo " macOS ZIP created at: $DIST_DIR/$ZIP_NAME"
echo "=========================================="
