#!/bin/bash
#
# Builds Service Pulse in Release configuration and packages it into a DMG.
#
# Usage:
#   ./scripts/build-dmg.sh
#
# Notarization (optional, requires a paid Apple Developer account):
#   Once you have a Developer ID Application certificate, set these env vars
#   before running this script to enable notarization + stapling:
#     NOTARIZE=1
#     APPLE_ID="you@example.com"
#     APPLE_TEAM_ID="DJ5F2VD3UK"
#     APPLE_APP_PASSWORD="app-specific-password"
#
# Without notarization, users will need to right-click the app and choose
# "Open" the first time (Gatekeeper warning) since it isn't from the App Store.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Service Pulse"
SCHEME="Service Pulse"
PROJECT="Service Pulse.xcodeproj"

BUILD_DIR="$ROOT_DIR/build"
ARCHIVE_PATH="$BUILD_DIR/$APP_NAME.xcarchive"
EXPORT_PATH="$BUILD_DIR/export"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DMG_STAGING="$BUILD_DIR/dmg-staging"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving (Release)..."
xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  | { grep -E "error:|warning:|BUILD" || true; }

echo "==> Exporting app from archive..."
mkdir -p "$EXPORT_PATH"
cp -R "$ARCHIVE_PATH/Products/Applications/$APP_NAME.app" "$EXPORT_PATH/"

echo "==> Staging DMG contents..."
mkdir -p "$DMG_STAGING"
cp -R "$EXPORT_PATH/$APP_NAME.app" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

echo "==> Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_STAGING" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [ "${NOTARIZE:-0}" = "1" ]; then
  echo "==> Submitting for notarization..."
  xcrun notarytool submit "$DMG_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$APPLE_TEAM_ID" \
    --password "$APPLE_APP_PASSWORD" \
    --wait

  echo "==> Stapling notarization ticket..."
  xcrun stapler staple "$DMG_PATH"
else
  echo "==> Skipping notarization (set NOTARIZE=1 with Apple credentials to enable)."
fi

echo "==> Done: $DMG_PATH"
