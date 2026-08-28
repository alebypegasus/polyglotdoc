#!/usr/bin/env bash
set -e

echo "=========================================="
echo " Building PolyGlotDoc AI for iOS (.ipa)   "
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/frontend_flutter"
DIST_DIR="$ROOT_DIR/dist/ios"

mkdir -p "$DIST_DIR"

cd "$FLUTTER_DIR"
echo ">> Running Flutter build ios --release --no-codesign..."
flutter build ios --release --no-codesign

BUILD_DIR="$FLUTTER_DIR/build/ios/iphoneos"
IPA_NAME="PolyGlotDoc_AI_iOS_Unsigned.ipa"
IPA_PATH="$DIST_DIR/$IPA_NAME"

if [ -d "$BUILD_DIR/Runner.app" ]; then
    echo ">> Packaging Runner.app into IPA archive..."
    cd "$BUILD_DIR"
    rm -rf Payload "$IPA_PATH"
    mkdir -p Payload
    cp -R Runner.app Payload/
    zip -r -q "$IPA_PATH" Payload
    rm -rf Payload
    echo "=========================================="
    echo " iOS IPA generated successfully at:"
    echo " $IPA_PATH"
    echo "=========================================="
else
    echo "Error: Runner.app not found in $BUILD_DIR"
    exit 1
fi
