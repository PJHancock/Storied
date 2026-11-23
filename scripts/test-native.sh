#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/swift-env.sh
task_frameworks="$task_developer_dir/Library/Developer/Frameworks"
swift test --package-path packages/JournalServices "${task_swift_flags[@]}" --disable-xctest -Xswiftc -F -Xswiftc "$task_frameworks" -Xlinker -F -Xlinker "$task_frameworks" -Xlinker -rpath -Xlinker "$task_frameworks" -Xlinker -rpath -Xlinker "$task_developer_dir/Library/Developer/usr/lib"
