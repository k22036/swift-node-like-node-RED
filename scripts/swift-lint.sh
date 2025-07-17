#!/bin/bash
set -e

# lintしたいフォルダを指定
TARGET_DIR="${SRCROOT:-.}"

# swift-format が存在するか
if ! xcrun --find swift-format >/dev/null; then
    echo "warning: Xcodeにswift-formatが見つかりません。Xcode 16以降を使用してください。"
    exit 1
fi

# lintの実行
if output=$(xcrun swift-format lint --recursive "$TARGET_DIR"); then
    echo "No lint issues found."
    exit 0
else
    echo "Lint issues found:"
    echo "$output"
    exit 1
fi
