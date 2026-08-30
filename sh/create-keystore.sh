#!/usr/bin/env bash
# Gera um keystore de upload local (não é a chave debug compartilhada do Android SDK).
# Necessário para APKs release sem falso positivo do Play Protect.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SECRETS_DIR="$ROOT/secrets"
KEYSTORE="$SECRETS_DIR/upload-keystore.jks"
KEY_PROPS="$ROOT/android/key.properties"
ALIAS="upload"

if [[ -f "$KEYSTORE" && -f "$KEY_PROPS" ]]; then
  echo "Keystore já existe: $KEYSTORE"
  echo "SHA-1 / SHA-256 (cadastre no Firebase Console → Configurações do app Android):"
  keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" \
    -storepass "$(grep '^storePassword=' "$KEY_PROPS" | cut -d= -f2-)" 2>/dev/null \
    | grep -iE 'SHA1:|SHA-256:|SHA256:'
  exit 0
fi

if ! command -v keytool >/dev/null 2>&1; then
  echo "keytool não encontrado. Instale um JDK e tente de novo." >&2
  exit 1
fi

mkdir -p "$SECRETS_DIR"

# Senhas locais aleatórias (ficam só em android/key.properties, ignorado pelo git).
STORE_PASS="$(openssl rand -base64 24 | tr -d '/+=' | head -c 24)"
KEY_PASS="$STORE_PASS"

keytool -genkeypair \
  -v \
  -keystore "$KEYSTORE" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -dname "CN=Conecta Creche Lab, OU=Lab Mobile, O=Univates, L=Lajeado, ST=RS, C=BR"

cat > "$KEY_PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=$KEYSTORE
EOF

chmod 600 "$KEY_PROPS" "$KEYSTORE"

echo
echo "Keystore criado em $KEYSTORE"
echo "Propriedades em $KEY_PROPS (não versionados)."
echo
echo "Cadastre estes fingerprints no Firebase (Configurações do projeto → seu app Android → Adicionar impressão digital):"
keytool -list -v -keystore "$KEYSTORE" -alias "$ALIAS" -storepass "$STORE_PASS" \
  | grep -iE 'SHA1:|SHA-256:|SHA256:'
echo
echo "Depois: ./sh/make_apk.sh  e reinstale o APK (desinstale a versão anterior se a assinatura mudou)."
