#!/usr/bin/env bash
# Optimized release APK build for MPorT Go
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> analyze (lib only)"
flutter analyze --no-fatal-infos lib || true

MODE="${1:-split}"  # split | universal | appbundle

case "$MODE" in
  split)
    echo "==> build APK split-per-abi (arm64 + armv7) + obfuscate"
    flutter build apk --release \
      --split-per-abi \
      --obfuscate \
      --split-debug-info=build/debug-info \
      --tree-shake-icons \
      --target-platform=android-arm,android-arm64
    echo ""
    echo "APKs:"
    ls -lh build/app/outputs/flutter-apk/*.apk 2>/dev/null || true
    ;;
  universal)
    echo "==> build universal APK (arm only via abiFilters) + obfuscate"
    flutter build apk --release \
      --obfuscate \
      --split-debug-info=build/debug-info \
      --tree-shake-icons \
      --target-platform=android-arm,android-arm64
    ls -lh build/app/outputs/flutter-apk/app-release.apk 2>/dev/null || true
    ;;
  appbundle|aab)
    echo "==> build App Bundle (Play Store)"
    flutter build appbundle --release \
      --obfuscate \
      --split-debug-info=build/debug-info \
      --tree-shake-icons
    ls -lh build/app/outputs/bundle/release/*.aab 2>/dev/null || true
    ;;
  *)
    echo "Usage: $0 [split|universal|appbundle]"
    exit 1
    ;;
esac

echo "Done."
