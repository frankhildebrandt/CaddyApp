#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  echo "usage: $0 <app_bundle> <output_dmg> <volume_name> <background_image>" >&2
  exit 1
fi

APP_BUNDLE="$1"
OUTPUT_DMG="$2"
VOLUME_NAME="$3"
BACKGROUND_IMAGE="$4"

if [ ! -d "$APP_BUNDLE" ]; then
  echo "app bundle not found: $APP_BUNDLE" >&2
  exit 1
fi

if [ ! -f "$BACKGROUND_IMAGE" ]; then
  echo "background image not found: $BACKGROUND_IMAGE" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/caddyapp-dmg.XXXXXX")
RW_DMG="$TMP_DIR/${VOLUME_NAME}-rw.dmg"
MOUNT_ROOT="$TMP_DIR/mount"
APP_BUNDLE_NAME=$(basename "$APP_BUNDLE")
VOLUME_PATH="$MOUNT_ROOT/$VOLUME_NAME"
BACKGROUND_NAME=$(basename "$BACKGROUND_IMAGE")

cleanup() {
  if [ -d "$VOLUME_PATH" ] && mount | grep -Fq "$VOLUME_PATH"; then
    hdiutil detach "$VOLUME_PATH" -quiet || hdiutil detach "$VOLUME_PATH" -force -quiet || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

rm -f "$OUTPUT_DMG"
mkdir -p "$MOUNT_ROOT"

SIZE_MB=$(du -sm "$APP_BUNDLE" | awk '{print $1}')
SIZE_MB=$((SIZE_MB + 40))

hdiutil create \
  -size "${SIZE_MB}m" \
  -fs HFS+ \
  -volname "$VOLUME_NAME" \
  "$RW_DMG"

hdiutil attach \
  -nobrowse \
  -mountpoint "$VOLUME_PATH" \
  "$RW_DMG"

cp -R "$APP_BUNDLE" "$VOLUME_PATH/"
mkdir -p "$VOLUME_PATH/.background"
cp "$BACKGROUND_IMAGE" "$VOLUME_PATH/.background/$BACKGROUND_NAME"
ln -s /Applications "$VOLUME_PATH/Applications"

osascript <<APPLESCRIPT
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set bounds of container window to {100, 100, 860, 500}
    set viewOptions to the icon view options of container window
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128
    set text size of viewOptions to 14
    set background picture of viewOptions to file ".background:$BACKGROUND_NAME"
    set position of item "$APP_BUNDLE_NAME" of container window to {180, 220}
    set position of item "Applications" of container window to {580, 220}
    close
    open
    update without registering applications
    delay 2
  end tell
end tell
APPLESCRIPT

chmod -Rf go-w "$VOLUME_PATH"
sync
hdiutil detach "$VOLUME_PATH" -quiet

hdiutil convert \
  "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG"
