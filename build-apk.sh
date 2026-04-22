#!/bin/bash
set -e

echo "========================================"
echo "  Link Game APK 一键构建脚本"
echo "========================================"
echo ""

# 检查 Flutter 是否安装
if ! command -v flutter &> /dev/null; then
    echo "❌ 错误: 未找到 Flutter，请先安装 Flutter SDK"
    exit 1
fi

echo "📦 Flutter 版本:"
flutter --version | head -1
echo ""

# 清理旧构建
echo "🧹 清理旧构建..."
flutter clean > /dev/null 2>&1

# 安装依赖
echo "📥 安装依赖..."
flutter pub get
echo ""

# 构建 Release APK
echo "🔨 构建 Release APK..."
flutter build apk --release
echo ""

# 复制到根目录
APK_NAME="linkgame-release.apk"
cp build/app/outputs/flutter-apk/app-release.apk "./${APK_NAME}"

echo "========================================"
echo "✅ 构建完成!"
echo "📁 APK 位置: ./${APK_NAME}"
ls -lh "./${APK_NAME}" | awk '{print "📏 文件大小: " $5}'
echo "========================================"
