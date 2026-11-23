#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
npm run build
mkdir -p apps/apple/WebAssets
cp -R apps/web/dist/. apps/apple/WebAssets/
printf '%s\n' 'Web assets ready. Open apps/apple/MemoryCatcher.xcodeproj in full Xcode and choose the MemoryCatcher3 scheme.'
