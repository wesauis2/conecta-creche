#!/usr/bin/env bash
# Seed / replace do pacote default de form_questions (RF0012–0015 + incidentes).
#
# Seguro (default): cria só se seedKey ainda não existir.
# --replace: desativa ativas e regrava o pacote versionado no repo.
#
# Credenciais/projeto locais: lib/firebase_options.dart + env FIREBASE_*
# (ver ./sh/firebase-setup.sh) ou FIRESTORE_EMULATOR_HOST.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec dart run tool/seed_form_questions.dart "$@"
