#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
APP="$BUILD_DIR/PromptBar.app"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
LOCAL_SWIFT_RESOURCE_DIR="$BUILD_DIR/toolchain/usr/lib/swift"
SOURCES=("$ROOT"/Sources/PromptBar/*.swift)
ICON_GENERATOR="$BUILD_DIR/make-app-icon"
ICON_SOURCE="$BUILD_DIR/icon_1024.png"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"

rm -rf "$BUILD_DIR"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
mkdir -p "$LOCAL_SWIFT_RESOURCE_DIR" "$BUILD_DIR/toolchain/usr/include/swift"

for resource in /Library/Developer/CommandLineTools/usr/lib/swift/*; do
    ln -s "$resource" "$LOCAL_SWIFT_RESOURCE_DIR/$(basename "$resource")"
done
ln -s /Library/Developer/CommandLineTools/usr/include/swift/bridging.modulemap \
    "$BUILD_DIR/toolchain/usr/include/swift/bridging.modulemap"
ln -s /Library/Developer/CommandLineTools/usr/include/swift/bridging \
    "$BUILD_DIR/toolchain/usr/include/swift/bridging"
printf '// local Swift resource modulemap\n' \
    > "$BUILD_DIR/toolchain/usr/include/swift/module.modulemap"

swiftc \
    "${SOURCES[@]}" \
    -sdk "$SDK" \
    -resource-dir "$LOCAL_SWIFT_RESOURCE_DIR" \
    -target arm64-apple-macosx14.0 \
    -O \
    -framework AppKit \
    -framework ApplicationServices \
    -framework Carbon \
    -o "$APP/Contents/MacOS/PromptBar"

swiftc \
    "$ROOT/Tools/MakeAppIcon.swift" \
    -sdk "$SDK" \
    -resource-dir "$LOCAL_SWIFT_RESOURCE_DIR" \
    -target arm64-apple-macosx14.0 \
    -O \
    -framework AppKit \
    -o "$ICON_GENERATOR"

mkdir -p "$ICONSET_DIR"
"$ICON_GENERATOR" "$ICON_SOURCE"
sips -z 16 16 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$APP/Contents/Resources/AppIcon.icns"

cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

codesign --force --deep --sign - \
    --identifier com.quickinsert.mac \
    --requirements '=designated => identifier "com.quickinsert.mac"' \
    "$APP"

hdiutil create \
    -volname "PromptBar" \
    -srcfolder "$APP" \
    -ov \
    -format UDZO \
    "$BUILD_DIR/PromptBar-1.0.0.dmg" >/dev/null

pkgbuild \
    --component "$APP" \
    --install-location /Applications \
    "$BUILD_DIR/PromptBar-1.0.0.pkg" >/dev/null

ditto -c -k --sequesterRsrc --keepParent \
    "$APP" \
    "$BUILD_DIR/PromptBar-1.0.0.zip"

echo "Built:"
echo "  $APP"
echo "  $BUILD_DIR/PromptBar-1.0.0.dmg"
echo "  $BUILD_DIR/PromptBar-1.0.0.pkg"
echo "  $BUILD_DIR/PromptBar-1.0.0.zip"
