#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/package-mac.sh
task_probe="$PWD/.build/Memory Catcher Model Diagnostics.app"
mkdir -p "$task_probe/Contents/MacOS"
cp '.build/Memory Catcher 3.app/Contents/MacOS/MemoryCatcherHost' "$task_probe/Contents/MacOS/MemoryCatcherHost"
cp '.build/Memory Catcher 3.app/Contents/Info.plist' "$task_probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleIdentifier org.example.MemoryCatcher3.ModelDiagnostics' "$task_probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName Memory Catcher Model Diagnostics' "$task_probe/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :MemoryCatcherDevelopmentDiagnostics bool true' "$task_probe/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$task_probe"
codesign --verify --deep --strict "$task_probe"
printf '%s\n' "Open in Finder, then click Run synthetic model test: $task_probe"
