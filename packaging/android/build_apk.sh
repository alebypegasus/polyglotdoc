#!/usr/bin/env bash
set -e

echo "=========================================="
echo " Building PolyGlotDoc AI for Android (APK)"
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/frontend_flutter"
DIST_DIR="$ROOT_DIR/dist/android"

mkdir -p "$DIST_DIR"

cd "$FLUTTER_DIR"

echo ">> Compiling Android Universal Release APK..."
flutter build apk --release --android-skip-build-dependency-validation
if [ -f "$FLUTTER_DIR/build/app/outputs/flutter-apk/app-release.apk" ]; then
    cp "$FLUTTER_DIR/build/app/outputs/flutter-apk/app-release.apk" "$DIST_DIR/PolyGlotDoc_AI_Android_Universal.apk"
fi

echo ">> Compiling Android Release APKs (split per ABI)..."
flutter build apk --release --split-per-abi --android-skip-build-dependency-validation || true

echo ">> Copying Split APKs to dist/android..."
cp "$FLUTTER_DIR/build/app/outputs/flutter-apk/"app-*.apk "$DIST_DIR/" 2>/dev/null || true

echo ">> Compiling Android App Bundle (AAB for Google Play)..."
flutter build appbundle --release --android-skip-build-dependency-validation || true
if [ -f "$FLUTTER_DIR/build/app/outputs/bundle/release/app-release.aab" ]; then
    cp "$FLUTTER_DIR/build/app/outputs/bundle/release/app-release.aab" "$DIST_DIR/PolyGlotDoc_AI_Release.aab"
fi

echo "=========================================="
echo " Android builds available at: $DIST_DIR"
echo "=========================================="
