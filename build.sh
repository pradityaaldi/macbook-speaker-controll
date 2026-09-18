#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Speaker Control"
EXECUTABLE="SpeakerControl"
APP="/Applications/${APP_NAME}.app"
ARCH="$(uname -m)"

osascript -e "quit app \"${APP_NAME}\"" >/dev/null 2>&1 || true
sleep 1

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp Resources/Info.plist "$APP/Contents/Info.plist"

swiftc \
  -O \
  -parse-as-library \
  -swift-version 5 \
  -target "${ARCH}-apple-macos13.0" \
  -framework AppKit \
  -framework SwiftUI \
  -framework CoreAudio \
  Sources/*.swift \
  -o "$APP/Contents/MacOS/${EXECUTABLE}"

codesign --force --sign - "$APP" >/dev/null 2>&1

mdimport "$APP" >/dev/null 2>&1 || true

echo "Built and installed: $APP"
