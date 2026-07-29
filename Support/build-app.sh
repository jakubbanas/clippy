#!/bin/bash
# Build Clippy.app from the SPM package. Usage: Support/build-app.sh [debug|release]
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-release}"
swift build -c "$CONFIG"

BIN=".build/$CONFIG"
APP="dist/Clippy.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/Clippy" "$APP/Contents/MacOS/Clippy"
cp Support/Info.plist "$APP/Contents/Info.plist"
if [ -d "$BIN/Clippy_Clippy.bundle" ]; then
    cp -R "$BIN/Clippy_Clippy.bundle" "$APP/Contents/Resources/"
fi

codesign --force --deep --sign - "$APP"
echo "Built $APP"
