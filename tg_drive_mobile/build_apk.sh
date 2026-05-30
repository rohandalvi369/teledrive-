#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

echo "Building TeleDrive APK..."
flutter build apk --debug

OUTPUT_DIR="build/app/outputs/flutter-apk"
NEW_APK="$OUTPUT_DIR/app-debug.apk"
DEST="$OUTPUT_DIR/tele_drive.apk"

rm -f "$OUTPUT_DIR/install teledrive.apk"
cp "$NEW_APK" "$DEST"

echo "APK ready: $DEST"
