#!/bin/bash
set -e

# フォーマットしたいフォルダを指定
TARGET_DIR="$SRCROOT"

# Xcode内蔵のswift-formatを使用してフォーマットを実行
if xcrun --find swift-format >/dev/null; then
    xcrun swift-format format --in-place --recursive "$TARGET_DIR"
    echo "Swift files in '$TARGET_DIR' have been formatted successfully."
else
    echo "warning: Xcodeにswift-formatが見つかりません。Xcode 16以降を使用してください。"
fi
