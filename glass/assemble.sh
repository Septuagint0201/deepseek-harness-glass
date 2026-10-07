#!/bin/bash
# Compile and verify in a unique directory on the destination filesystem.
# The installer atomically swaps an existing app, preserving it on failure.
set -euo pipefail
cd "$(dirname "$0")"

APP="${APP_PATH:-/Applications/DeepSeek Harness.app}"
case "$APP" in
  /*.app) ;;
  *) echo "APP_PATH must be an absolute .app path" >&2; exit 2 ;;
esac
PARENT="$(dirname "$APP")"
mkdir -p "$PARENT"
STAGING_ROOT=$(mktemp -d "$PARENT/.glass-staging.XXXXXX")
trap 'rm -rf "$STAGING_ROOT"' EXIT
STAGE="$STAGING_ROOT/DeepSeek Harness.app"
mkdir -p "$STAGE/Contents/MacOS" "$STAGE/Contents/Resources"

echo "== 1/3 编译 Swift 壳 =="
swiftc -O -parse-as-library -target arm64-apple-macosx26.0 \
  Sources/*.swift -o "$STAGE/Contents/MacOS/DeepSeek Harness"
swiftc -O -parse-as-library Tools/AtomicInstall.swift \
  -o "$STAGING_ROOT/atomic-install"

echo "== 2/3 Info.plist / 图标 / 签名验证 =="
cp Info.plist "$STAGE/Contents/Info.plist"
cp ../build/icon.icns "$STAGE/Contents/Resources/icon.icns"
cp assets/fish.svg "$STAGE/Contents/Resources/fish.svg"
codesign --force --deep -s - "$STAGE"
codesign --verify --deep --strict "$STAGE"

echo "== 3/3 原子安装 =="
"$STAGING_ROOT/atomic-install" "$STAGE" "$APP"
du -sh "$APP"
