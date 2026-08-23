#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Stale daemons may still hold a large heap from a previous gradle.properties.
if [[ -x android/gradlew ]]; then
  (cd android && ./gradlew --stop) >/dev/null 2>&1 || true
fi

flutter pub get

build_apk() {
  flutter build apk --release \
    --split-debug-info=build/app/outputs/symbols \
    --obfuscate \
    --split-per-abi
}

if build_apk; then
  exit 0
fi

echo "Build failed; stopping Gradle daemons and retrying once..." >&2
(cd android && ./gradlew --stop) >/dev/null 2>&1 || true
build_apk
