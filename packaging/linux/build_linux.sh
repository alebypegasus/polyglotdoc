#!/usr/bin/env bash
set -e

echo "=========================================="
echo " Building PolyGlotDoc AI for Linux        "
echo "=========================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
FLUTTER_DIR="$ROOT_DIR/frontend_flutter"
DIST_DIR="$ROOT_DIR/dist/linux"

mkdir -p "$DIST_DIR"

cd "$FLUTTER_DIR"
echo ">> Compiling Flutter Linux release..."
flutter build linux --release

RELEASE_DIR="$FLUTTER_DIR/build/linux/x64/release/bundle"
TAR_PATH="$DIST_DIR/PolyGlotDoc_AI_Linux_x86_64.tar.gz"

echo ">> Creating .tar.gz bundle..."
tar -czf "$TAR_PATH" -C "$RELEASE_DIR" .

echo ">> Creating .deb package structure..."
DEB_ROOT="/tmp/polyglotdoc_deb"
rm -rf "$DEB_ROOT"
mkdir -p "$DEB_ROOT/usr/bin"
mkdir -p "$DEB_ROOT/usr/share/polyglotdoc"
mkdir -p "$DEB_ROOT/usr/share/applications"
mkdir -p "$DEB_ROOT/usr/share/pixmaps"
mkdir -p "$DEB_ROOT/DEBIAN"

cp -r "$RELEASE_DIR"/* "$DEB_ROOT/usr/share/polyglotdoc/"
ln -sf "/usr/share/polyglotdoc/frontend_flutter" "$DEB_ROOT/usr/bin/polyglotdoc"

cp "$FLUTTER_DIR/assets/icon/app_icon_128.png" "$DEB_ROOT/usr/share/pixmaps/polyglotdoc.png"

cat <<EOF > "$DEB_ROOT/usr/share/applications/polyglotdoc.desktop"
[Desktop Entry]
Name=PolyGlotDoc AI
Comment=High performance AI document translation & layout reconstruction
Exec=/usr/bin/polyglotdoc
Icon=polyglotdoc
Terminal=false
Type=Application
Categories=Office;Utility;
EOF

cat <<EOF > "$DEB_ROOT/DEBIAN/control"
Package: polyglotdoc-ai
Version: 1.0.0
Section: utils
Priority: optional
Architecture: amd64
Maintainer: PolyGlotDoc AI Contributors <dev@polyglotdoc.ai>
Description: High-performance AI document translation and editorial reconstruction.
EOF

if command -v dpkg-deb &> /dev/null; then
    dpkg-deb --build "$DEB_ROOT" "$DIST_DIR/PolyGlotDoc_AI_1.0.0_amd64.deb"
    echo ">> Created .deb installer at: $DIST_DIR/PolyGlotDoc_AI_1.0.0_amd64.deb"
fi

rm -rf "$DEB_ROOT"

echo "=========================================="
echo " Linux packages generated in: $DIST_DIR"
echo "=========================================="
