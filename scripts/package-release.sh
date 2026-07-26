#!/usr/bin/env bash
# Build a shareable aipaste.zip for trial / local distribution.
#
# Usage:
#   ./scripts/package-release.sh
#   ./scripts/package-release.sh ~/Desktop
#   OUT_DIR=~/Downloads ./scripts/package-release.sh
#   KEEP_BUILD=1 ./scripts/package-release.sh   # keep build/ for debugging
#
# Output (default: Desktop):
#   aipaste-<version>-<date>.zip   ← only this (contains aipaste.app + 试用说明.txt)
#
# After a successful package, build/ is removed so Spotlight does not index
# leftover .app copies. Pass KEEP_BUILD=1 to retain intermediates.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

OUT_DIR="${1:-${OUT_DIR:-$HOME/Desktop}}"
KEEP_BUILD="${KEEP_BUILD:-0}"
SCHEME="aipaste"
PROJECT="aipaste.xcodeproj"
CONFIGURATION="Release"
DERIVED="$ROOT/build/package-DerivedData"
STAGING="$ROOT/build/package-staging"
LOG="$ROOT/build/package-release.log"

die() { echo "error: $*" >&2; exit 1; }

command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild not found (install full Xcode)"
command -v zip >/dev/null 2>&1 || die "zip not found"

# Regenerate project when XcodeGen is available (keeps project.yml as source of truth).
if command -v xcodegen >/dev/null 2>&1; then
  echo "→ Generating Xcode project…"
  xcodegen generate
else
  echo "warn: xcodegen not found; using existing $PROJECT"
  [[ -d "$PROJECT" ]] || die "missing $PROJECT (install xcodegen: brew install xcodegen)"
fi

VERSION="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' \
    "$ROOT/aipaste/Resources/Info.plist" 2>/dev/null || echo "0.0.0"
)"
BUILD="$(
  /usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' \
    "$ROOT/aipaste/Resources/Info.plist" 2>/dev/null || echo "0"
)"
DATE_TAG="$(date +%Y%m%d)"
ZIP_NAME="aipaste-${VERSION}-${DATE_TAG}.zip"
APP_NAME="aipaste.app"

mkdir -p "$OUT_DIR" "$ROOT/build"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"

echo "→ Building $CONFIGURATION ($VERSION build $BUILD)…"
rm -rf "$DERIVED"
set +e
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED" \
  build \
  >"$LOG" 2>&1
BUILD_STATUS=$?
set -e

if [[ $BUILD_STATUS -ne 0 ]]; then
  echo "error: xcodebuild failed (exit $BUILD_STATUS). Last 40 lines:" >&2
  tail -40 "$LOG" >&2
  echo "Full log: $LOG" >&2
  exit "$BUILD_STATUS"
fi

grep -E '\*\* BUILD SUCCEEDED \*\*|warning:.*aipaste' "$LOG" || true

APP_SRC="$DERIVED/Build/Products/$CONFIGURATION/$APP_NAME"
[[ -d "$APP_SRC" ]] || die "build product missing: $APP_SRC (see $LOG)"

echo "→ Staging…"
rm -rf "$STAGING"
mkdir -p "$STAGING"
ditto "$APP_SRC" "$STAGING/$APP_NAME"

cat > "$STAGING/试用说明.txt" <<EOF
ai paste 试用说明
================
版本: ${VERSION} (${BUILD})
打包日期: ${DATE_TAG}

1. 把 aipaste.app 拖到「应用程序」文件夹（或任意位置）
2. 双击打开；若提示无法验证开发者：
   - 右键 aipaste.app →「打开」→ 确认打开
   - 或：系统设置 → 隐私与安全性 → 仍要打开
3. 菜单栏出现剪贴板图标（无 Dock 图标，属正常）
4. 快捷键 ⇧⌘V 打开历史面板
5. 需要「自动粘贴」时：
   系统设置 → 隐私与安全性 → 辅助功能 → 打开 ai paste
6. 数据仅保存在本机，不上传云端
7. 需要 macOS 13 或更高

问题反馈请联系分发者。
EOF

echo "→ Zipping → $ZIP_PATH"
rm -f "$ZIP_PATH"
(
  cd "$STAGING"
  zip -r -y "$ZIP_PATH" "$APP_NAME" "试用说明.txt" >/dev/null
)

# Do NOT leave a bare .app next to the zip (avoids Spotlight duplicates).
# Remove any leftover bare app from older script runs in the same OUT_DIR.
if [[ -d "$OUT_DIR/$APP_NAME" ]]; then
  echo "→ Removing leftover $OUT_DIR/$APP_NAME"
  rm -rf "$OUT_DIR/$APP_NAME"
fi

if [[ "$KEEP_BUILD" == "1" ]]; then
  echo "→ KEEP_BUILD=1: leaving $ROOT/build in place"
else
  echo "→ Cleaning build intermediates (no local .app left for Spotlight)…"
  # Preserve log outside build/ for a moment? Log is only useful on failure; drop it.
  rm -rf "$ROOT/build"
fi

echo
echo "✓ Package ready"
echo "  Zip only: $ZIP_PATH"
echo "  Size:     $(du -h "$ZIP_PATH" | awk '{print $1}')"
echo
echo "Share the zip. Recipients: unzip → open aipaste.app → enable Accessibility for auto-paste."
echo "Tip: after testing a local unzip, delete the extracted folder so search stays clean."
