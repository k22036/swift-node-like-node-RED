#!/bin/bash
set -e

# フォーマットしたいフォルダを指定
TARGET_DIRS=("${SRCROOT:-.}/swift-node-like-node-RED" "${SRCROOT:-.}/swift-node-like-node-REDTests" "${SRCROOT:-.}/swift-node-like-node-REDUITests")
# swift-formatの設定ファイルを指定
TARGET_DIR="${SRCROOT:-.}"
config_file="$TARGET_DIR/.swift-format"

# swift-format が存在するか
if ! xcrun --find swift-format >/dev/null; then
    echo "warning: Xcodeにswift-formatが見つかりません。Xcode 16以降を使用してください。"
    exit 1
fi

# GitHub Actions 上ではフォーマットのチェックのみ行い、差分があればエラーを返す
if [ -n "$GITHUB_ACTIONS" ]; then
    echo "Checking diffs before and after swift-format ..."

    exit_code=0
    for dir in "${TARGET_DIRS[@]}"; do
        while IFS= read -r file; do
            if diff_output=$(diff -u "$file" <(xcrun swift-format format "$file" --configuration "$config_file")); then
                continue
            else
                echo "Difference found in $file:"
                exit_code=1
            fi
        done < <(find "$dir" -type f -name '*.swift')
    done

    if [ "$exit_code" -ne 0 ]; then
        echo "::error Swift files are not properly formatted. Run swift-format with --in-place to fix."
        exit 1
    else
        echo "All Swift files are properly formatted."
    fi
else
    # ローカルでは in-place フォーマットを実行
    xcrun swift-format format --in-place --recursive "$TARGET_DIR" --configuration "$config_file"
    echo "Swift files in '$TARGET_DIR' have been formatted successfully."
fi
