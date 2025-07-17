#!/bin/bash
set -e

# フォーマットしたいフォルダを指定
TARGET_DIR="${SRCROOT:-.}"

# swift-format が存在するか
if ! xcrun --find swift-format >/dev/null; then
    echo "warning: Xcodeにswift-formatが見つかりません。Xcode 16以降を使用してください。"
    exit 0
fi

# GitHub Actions 上ではフォーマットのチェックのみ行い、差分があればエラーを返す
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "Checking Swift format in '$TARGET_DIR'..."
    if ! xcrun swift-format format --recursive "$TARGET_DIR" --dry-run; then
        echo "::error Swift files are not properly formatted. Run swift-format with --in-place to fix."
        exit 1
    else
        echo "All Swift files are properly formatted."
    fi
else
    # ローカルでは in-place フォーマットを実行
    xcrun swift-format format --in-place --recursive "$TARGET_DIR"
    echo "Swift files in '$TARGET_DIR' have been formatted successfully."
fi
