#!/bin/bash
set -e

# フォーマットしたいフォルダを指定
TARGET_DIR="${SRCROOT:-.}"

# swift-format が存在するか
if ! xcrun --find swift-format >/dev/null; then
    echo "warning: Xcodeにswift-formatが見つかりません。Xcode 16以降を使用してください。"
    exit 1
fi

# GitHub Actions 上ではフォーマットのチェックのみ行い、差分があればエラーを返す
if [ -n "$GITHUB_ACTIONS" ]; then
    # format前とformat後で差分があるか確認
    echo "Checking diffs before and after swift-format ..."

    exit_code=0
    while IFS= read -r file; do
        if diff_output=$(diff -u "$file" <(xcrun swift-format format "$file")); then
            continue
        else
            echo "Difference found in $file:"
            # echo "$diff_output"
            exit_code=1
        fi
    done < <(find "$TARGET_DIR" -type f -name '*.swift')

    if [ "$exit_code" -ne 0 ]; then
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
