#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_NAME="TidyText"
BUNDLE_DIR="$PROJECT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "==> 正在编译 Release 版本..."
swift build -c release

echo "==> 创建应用 Bundle 结构..."
rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

echo "==> 拷贝可执行文件..."
cp "$PROJECT_DIR/.build/release/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"

echo "==> 拷贝 Info.plist..."
cp "$PROJECT_DIR/Info.plist" "$CONTENTS_DIR/Info.plist"

echo "==> 进行 Ad-hoc 本地代码签名..."
codesign --force --deep --sign - "$BUNDLE_DIR"

echo ""
echo "🎉 构建成功! 应用位于: $BUNDLE_DIR"
echo "您可以通过双击或运行命令打开它: open \"$BUNDLE_DIR\""
