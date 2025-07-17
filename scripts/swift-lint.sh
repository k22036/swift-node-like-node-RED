#!/bin/bash
set -e

# フォーマットしたいフォルダを指定
TARGET_DIR="${SRCROOT:-.}"

# swift-format が存在するか
if ! xcrun --find swift-format >/dev/null; then
    echo "warning: Xcodeにswift-formatが見つかりません。Xcode 16以降を使用してください。"
    exit 1
fi

# xcrun swift-format lint --recursive "$TARGET_DIR"
if output=$(xcrun swift-format lint --recursive "$TARGET_DIR"); then
    echo "No formatting issues found."
else
    echo "Formatting issues found:"
    echo "$output"
    exit 1
fi
