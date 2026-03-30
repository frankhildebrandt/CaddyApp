#!/bin/sh
set -eu

ROOT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
SRC_SVG="$ROOT_DIR/assets/AppIcon.svg"
OUT_ICNS="$ROOT_DIR/assets/CaddyApp.icns"
OUT_PREVIEW="$ROOT_DIR/assets/AppIcon-preview.png"
SYSTRAY_SVG="$ROOT_DIR/assets/SystrayIconTemplate.svg"
SYSTRAY_PREVIEW="$ROOT_DIR/assets/SystrayIconTemplate.png"

if [ ! -f "$SRC_SVG" ]; then
  echo "Missing source SVG: $SRC_SVG" >&2
  exit 1
fi

if ! command -v qlmanage >/dev/null 2>&1; then
  echo "qlmanage is required" >&2
  exit 1
fi
if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required" >&2
  exit 1
fi
if ! command -v iconutil >/dev/null 2>&1; then
  echo "iconutil is required" >&2
  exit 1
fi

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/caddyapp-icon.XXXXXX")
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

ICONSET_DIR="$TMP_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"

qlmanage -t -s 1024 -o "$TMP_DIR" "$SRC_SVG" >/dev/null 2>&1 || true
MASTER_PNG="$TMP_DIR/$(basename "$SRC_SVG").png"

if [ ! -f "$MASTER_PNG" ]; then
  if [ -f "$OUT_ICNS" ] && [ -f "$OUT_PREVIEW" ]; then
    echo "Skipping icon regeneration; using existing assets" >&2
    exit 0
  fi

  echo "Failed to render SVG preview via qlmanage and no existing icon assets found" >&2
  exit 1
fi

cp "$MASTER_PNG" "$OUT_PREVIEW"

resize_copy() {
  size="$1"
  dest="$2"
  sips -s format png -z "$size" "$size" "$MASTER_PNG" --out "$dest" >/dev/null
}

resize_copy 16   "$ICONSET_DIR/icon_16x16.png"
resize_copy 32   "$ICONSET_DIR/icon_16x16@2x.png"
resize_copy 32   "$ICONSET_DIR/icon_32x32.png"
resize_copy 64   "$ICONSET_DIR/icon_32x32@2x.png"
resize_copy 128  "$ICONSET_DIR/icon_128x128.png"
resize_copy 256  "$ICONSET_DIR/icon_128x128@2x.png"
resize_copy 256  "$ICONSET_DIR/icon_256x256.png"
resize_copy 512  "$ICONSET_DIR/icon_256x256@2x.png"
resize_copy 512  "$ICONSET_DIR/icon_512x512.png"
cp "$MASTER_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

iconutil -c icns "$ICONSET_DIR" -o "$OUT_ICNS"

echo "Generated: $OUT_ICNS"
echo "Preview:   $OUT_PREVIEW"

if [ -f "$SYSTRAY_SVG" ]; then
  qlmanage -t -s 64 -o "$(dirname "$SYSTRAY_SVG")" "$SYSTRAY_SVG" >/dev/null 2>&1 || true
  if [ -f "${SYSTRAY_SVG}.png" ]; then
    mv "${SYSTRAY_SVG}.png" "$SYSTRAY_PREVIEW"
    echo "Systray:   $SYSTRAY_PREVIEW"
  fi
fi
