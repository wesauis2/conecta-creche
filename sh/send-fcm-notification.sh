#!/usr/bin/env bash
# Lab: grava notifications/ e tenta FCM HTTP v1 (Admin/ADC).
# Sem credencial: só o doc no feed (graceful).
#
# Exemplos:
#   ./sh/send-fcm-notification.sh --title "Aviso" --body "Olá" --user-id UID
#   ./sh/send-fcm-notification.sh --title "Push" --body "Olá" --token DEVICE_TOKEN
#
# Credenciais/projeto: ver ./sh/firebase-setup.sh e tool/send_fcm_notification.dart
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

exec dart run tool/send_fcm_notification.dart "$@"
