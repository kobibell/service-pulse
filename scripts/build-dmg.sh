#!/bin/bash
#
# Builds Service Pulse in Release configuration and packages it into a DMG.
#
# Usage:
#   ./scripts/build-dmg.sh
#
# Notarization (needs a paid Apple Developer account + Developer ID cert):
#   NOTARIZE=1
#   APPLE_ID="you@example.com"
#   APPLE_TEAM_ID="DJ5F2VD3UK"
#   APPLE_APP_PASSWORD="app-specific-password"
#
# Without it, users have to bypass the Gatekeeper warning on first launch
# since the app isn't from the App Store.

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

DEVELOPER_ID="Developer ID Application: Kobi Bell (DJ5F2VD3UK)"
APP_PATH="$EXPORT_PATH/$APP_NAME.app"

echo "==> Re-signing with Developer ID (hardened runtime + secure timestamp)..."
codesign \
  --force \
  --options runtime \
  --timestamp \
  --sign "$DEVELOPER_ID" \
  "$APP_PATH"

echo "==> Verifying signature..."
CODESIGN_OUT=$(codesign -dvvv "$APP_PATH" 2>&1)
if ! echo "$CODESIGN_OUT" | grep -q "Authority=Developer ID Application"; then
  echo "ERROR: Signed app does not contain a Developer ID Application authority. Aborting."
  exit 1
fi
if ! echo "$CODESIGN_OUT" | grep -q "Timestamp="; then
  echo "ERROR: Signature does not include a secure timestamp. Aborting."
  exit 1
fi
echo "    Signature OK (Developer ID + timestamp confirmed)."

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
