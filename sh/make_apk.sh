#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

KEY_PROPS="$ROOT/android/key.properties"
if [[ ! -f "$KEY_PROPS" ]]; then
  echo "Falta assinatura de release (android/key.properties)." >&2
  echo "APKs assinados com a chave debug do Android disparam o Play Protect" >&2
  echo "(\"App nocivo detectado\" / burlar proteções de segurança)." >&2
  echo >&2
  echo "Gere o keystore local e cadastre o SHA no Firebase:" >&2
  echo "  ./sh/create-keystore.sh" >&2
  exit 1
fi

"$ROOT/sh/verify-google-sign-in.sh"

# Stale daemons may still hold a large heap from a previous gradle.properties.
if [[ -x android/gradlew ]]; then
  (cd android && ./gradlew --stop) >/dev/null 2>&1 || true
fi

flutter pub get

build_apk() {
  # Sem --obfuscate: menos atrito com análise do Play Protect em sideload de lab.
  flutter build apk --release \
    --split-per-abi
}

if build_apk; then
  echo
  echo "APKs em build/app/outputs/flutter-apk/"
  echo "Se o dispositivo já tinha o app com outra assinatura, desinstale antes de instalar de novo."
  exit 0
fi

echo "Build failed; stopping Gradle daemons and retrying once..." >&2
(cd android && ./gradlew --stop) >/dev/null 2>&1 || true
build_apk
