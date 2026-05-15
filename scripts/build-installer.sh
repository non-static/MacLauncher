#!/usr/bin/env bash

set -euo pipefail

export COPYFILE_DISABLE=1

APP_NAME="MacLauncher"
BUNDLE_ID="${BUNDLE_ID:-com.nonstatic.MacLauncher}"
VERSION="${VERSION:-0.0.2}"
BUILD_CONFIG="${BUILD_CONFIG:-release}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/installer"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
PKG_ROOT="$BUILD_DIR/pkgroot"
PKG_OUTPUT="${PKG_OUTPUT:-$BUILD_DIR/$APP_NAME-$VERSION.pkg}"
ICON_SOURCE="$ROOT_DIR/Sources/MacLauncher/Resources/AppIcon.icns"
GIT_COMMIT="${GIT_COMMIT:-$(git -C "$ROOT_DIR" rev-parse HEAD 2>/dev/null || true)}"

if ! command -v swift >/dev/null 2>&1; then
    echo "error: swift not found" >&2
    exit 1
fi

if ! command -v pkgbuild >/dev/null 2>&1; then
    echo "error: pkgbuild not found" >&2
    exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
mkdir -p "$(dirname "$PKG_OUTPUT")"

swift build \
    --configuration "$BUILD_CONFIG" \
    --product "$APP_NAME" \
    --package-path "$ROOT_DIR"

BIN_DIR="$(swift build \
    --configuration "$BUILD_CONFIG" \
    --show-bin-path \
    --package-path "$ROOT_DIR")"

install -m 755 "$BIN_DIR/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

if [[ -f "$ICON_SOURCE" ]]; then
    install -m 644 "$ICON_SOURCE" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

cat >"$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>LSMinimumSystemVersion</key>
    <string>15.0</string>
    <key>MacLauncherGitCommit</key>
    <string>$GIT_COMMIT</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

plutil -lint "$APP_BUNDLE/Contents/Info.plist" >/dev/null

xattr -cr "$APP_BUNDLE" 2>/dev/null || true

if [[ "${CODE_SIGN_IDENTITY:-}" == "skip" ]]; then
    echo "Skipping app code signing"
elif [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --sign "$CODE_SIGN_IDENTITY" "$APP_BUNDLE"
else
    codesign --force --deep --sign - "$APP_BUNDLE"
fi

mkdir -p "$PKG_ROOT/Applications"
ditto --noqtn "$APP_BUNDLE" "$PKG_ROOT/Applications/$APP_NAME.app"
xattr -cr "$PKG_ROOT" 2>/dev/null || true

PKG_ARGS=(
    --root "$PKG_ROOT"
    --install-location "/"
    --identifier "$BUNDLE_ID.pkg"
    --version "$VERSION"
)

if [[ -n "${PKG_SIGN_IDENTITY:-}" ]]; then
    PKG_ARGS+=(--sign "$PKG_SIGN_IDENTITY")
fi

pkgbuild "${PKG_ARGS[@]}" "$PKG_OUTPUT"

echo "Built app: $APP_BUNDLE"
echo "Built pkg: $PKG_OUTPUT"
shasum -a 256 "$PKG_OUTPUT"
