#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
npm run build
source scripts/swift-env.sh
swift build --package-path apps/apple "${task_swift_flags[@]}"
task_bin="$(swift build --package-path apps/apple "${task_swift_flags[@]}" --show-bin-path)"
task_app="$PWD/.build/Memory Catcher 3.app"
mkdir -p "$task_app/Contents/MacOS" "$task_app/Contents/Resources/WebAssets"
cp "$task_bin/MemoryCatcherHost" "$task_app/Contents/MacOS/MemoryCatcherHost"
cp -R apps/web/dist/. "$task_app/Contents/Resources/WebAssets/"
cat > "$task_app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict><key>CFBundleName</key><string>Memory Catcher 3</string><key>CFBundleExecutable</key><string>MemoryCatcherHost</string><key>CFBundleIdentifier</key><string>org.example.MemoryCatcher3.Development</string><key>CFBundleVersion</key><string>1</string><key>CFBundleShortVersionString</key><string>0.1.0</string><key>CFBundlePackageType</key><string>APPL</string><key>LSMinimumSystemVersion</key><string>14.0</string><key>NSPhotoLibraryUsageDescription</key><string>Show photos from a day in your scrapbook when you enable Photos.</string><key>NSCalendarsFullAccessUsageDescription</key><string>Show calendar events on their matching journal day when you enable Calendar.</string><key>NSSpeechRecognitionUsageDescription</key><string>Transcribe speech when you choose Dictate text or include an audio or video recording in summaries. Recognition runs on this device.</string><key>NSMicrophoneUsageDescription</key><string>Use the microphone only when you choose Dictate text, Record audio or Record video.</string><key>NSCameraUsageDescription</key><string>Record a video memory only when you tap Record video.</string></dict></plist>
PLIST
codesign --force --sign - --timestamp=none "$task_app"
codesign --verify --deep --strict "$task_app"
printf '%s\n' "$task_app"
