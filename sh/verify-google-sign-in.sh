#!/usr/bin/env bash
# Valida que google-services.json tem o cliente OAuth Web exigido pelo google_sign_in 7+.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JSON="$ROOT/android/app/google-services.json"

if [[ ! -f "$JSON" ]]; then
  echo "Falta $JSON" >&2
  exit 1
fi

python3 - "$JSON" <<'PY'
import json, sys
path = sys.argv[1]
data = json.load(open(path))
clients = data.get("client") or []
web_ids = []
android_hashes = []
for c in clients:
    for o in c.get("oauth_client") or []:
        if o.get("client_type") == 3:
            web_ids.append(o.get("client_id"))
        if o.get("client_type") == 1:
            info = o.get("android_info") or {}
            android_hashes.append(info.get("certificate_hash"))

if not web_ids:
    print(
        "ERRO: google-services.json não tem oauth_client com client_type: 3 "
        "(cliente Web / serverClientId).\n"
        "Corrija no Firebase Console:\n"
        "  1. Authentication → Sign-in method → Google → ativar e salvar\n"
        "  2. Configurações do projeto → Adicionar app → Web (ou use o "
        "ID do cliente Web já criado)\n"
        "  3. No app Android, adicione SHA-1 (debug e upload: "
        "./sh/create-keystore.sh)\n"
        "  4. Baixe de novo google-services.json → android/app/\n"
        "Detalhes: docs/credentials.md#google-sign-in-serverclientid",
        file=sys.stderr,
    )
    sys.exit(1)

print("OK: serverClientId (Web) encontrado:")
for wid in web_ids:
    print(f"  {wid}")
if android_hashes:
    print("SHA cadastrados no JSON:")
    for h in android_hashes:
        print(f"  {h}")
else:
    print(
        "AVISO: nenhum oauth_client Android (client_type: 1). "
        "Cadastre o SHA-1 no app Android e baixe o JSON de novo."
    )
PY
