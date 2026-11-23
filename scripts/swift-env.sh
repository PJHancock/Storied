#!/bin/bash
set -euo pipefail
export CLANG_MODULE_CACHE_PATH="${TMPDIR:-/private/tmp}/memory-catcher-3-clang"
export SWIFTPM_MODULECACHE_OVERRIDE="${TMPDIR:-/private/tmp}/memory-catcher-3-swift"
task_developer_dir="$(xcode-select -p)"
if [[ "$task_developer_dir" == *CommandLineTools && -d "$task_developer_dir/SDKs/MacOSX26.5.sdk" ]]; then
    task_sdk="$task_developer_dir/SDKs/MacOSX26.5.sdk"
else
    task_sdk="$task_developer_dir/SDKs/MacOSX27.2.sdk"
    if [[ ! -d "$task_sdk" ]]; then task_sdk="$task_developer_dir/SDKs/MacOSX27.sdk"; fi
    if [[ ! -d "$task_sdk" ]]; then task_sdk="$task_developer_dir/SDKs/MacOSX26.5.sdk"; fi
fi
if [[ ! -d "$task_sdk" ]]; then task_sdk="$(xcrun --show-sdk-path)"; fi
task_swift_flags=(--disable-sandbox --build-system native --sdk "$task_sdk")
if [[ "$task_sdk" == */MacOSX26.5.sdk ]]; then
    task_swift_flags+=( -Xswiftc -DMEMORY_CATCHER_DISABLE_FOUNDATION_MODELS_VISION )
fi
