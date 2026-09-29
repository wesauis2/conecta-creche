#requires -Version 5.1
<#
    Gera um keystore de upload local para o app Conecta Creche.
    Conversao do script Bash para Windows PowerShell 5.1+.

    IMPORTANTE:
    - Este keystore e local e deve permanecer fora do Git.
    - Nao e a chave debug compartilhada do Android SDK.
    - O Java/JDK precisa estar instalado e o comando keytool precisa estar no PATH.
#>

$ErrorActionPreference = "Stop"

# --------------------------------------------------------------------------
# Caminhos
# --------------------------------------------------------------------------

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$ROOT = Split-Path -Parent $SCRIPT_DIR

Set-Location $ROOT

$SECRETS_DIR = Join-Path $ROOT "secrets"
$KEYSTORE = Join-Path $SECRETS_DIR "upload-keystore.jks"
$KEY_PROPS = Join-Path $ROOT "android/key.properties"
$ALIAS = "upload"

# --------------------------------------------------------------------------
# Verificar se o keystore ja existe
# --------------------------------------------------------------------------

if ((Test-Path -LiteralPath $KEYSTORE -PathType Leaf) -and
    (Test-Path -LiteralPath $KEY_PROPS -PathType Leaf)) {

    Write-Host "Keystore ja existe: $KEYSTORE"
    Write-Host "SHA-1 / SHA-256 (cadastre no Firebase Console -> Configuracoes do app Android):"

    $storePasswordLine = Get-Content -LiteralPath $KEY_PROPS |
        Where-Object { $_ -match '^storePassword=' } |
        Select-Object -First 1

    if (-not $storePasswordLine) {
        Write-Error "storePassword nao encontrado em $KEY_PROPS"
        exit 1
    }

    $STORE_PASS = $storePasswordLine -replace '^storePassword=', ''

    & keytool -list -v `
        -keystore "$KEYSTORE" `
        -alias "$ALIAS" `
        -storepass "$STORE_PASS" 2>$null |
        Select-String -Pattern 'SHA1:|SHA-256:|SHA256:'

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Nao foi possivel consultar o keystore."
        exit 1
    }

    exit 0
}

# --------------------------------------------------------------------------
# Verificar keytool
# --------------------------------------------------------------------------

$keytool = Get-Command keytool -ErrorAction SilentlyContinue

if (-not $keytool) {
    Write-Error "keytool nao encontrado. Instale um JDK e tente novamente."
    exit 1
}

# --------------------------------------------------------------------------
# Criar pasta secrets
# --------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $SECRETS_DIR)) {
    New-Item -ItemType Directory -Path $SECRETS_DIR -Force | Out-Null
}

# --------------------------------------------------------------------------
# Gerar senha aleatoria
# --------------------------------------------------------------------------
# Equivalente ao:
# openssl rand -base64 24 | tr -d '/+=' | head -c 24
#
# Aqui usamos System.Security.Cryptography para nao depender do OpenSSL.

$randomBytes = New-Object byte[] 32

try {
    $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
    $rng.GetBytes($randomBytes)
    $rng.Dispose()
} catch {
    Write-Error "Nao foi possivel gerar uma senha aleatoria segura."
    exit 1
}

$STORE_PASS = [Convert]::ToBase64String($randomBytes) `
    -replace '[\/+=]', ''

if ($STORE_PASS.Length -lt 24) {
    Write-Error "A senha aleatoria gerada ficou menor que 24 caracteres."
    exit 1
}

$STORE_PASS = $STORE_PASS.Substring(0, 24)
$KEY_PASS = $STORE_PASS

# --------------------------------------------------------------------------
# Gerar keystore
# --------------------------------------------------------------------------

Write-Host ""
Write-Host "Gerando keystore de upload..." -ForegroundColor Cyan

& keytool -genkeypair `
    -v `
    -keystore "$KEYSTORE" `
    -alias "$ALIAS" `
    -keyalg RSA `
    -keysize 2048 `
    -validity 10000 `
    -storepass "$STORE_PASS" `
    -keypass "$KEY_PASS" `
    -dname "CN=Conecta Creche Lab, OU=Lab Mobile, O=Univates, L=Lajeado, ST=RS, C=BR"

if ($LASTEXITCODE -ne 0) {
    Write-Error "Falha ao criar o keystore."
    exit 1
}

# --------------------------------------------------------------------------
# Criar android/key.properties
# --------------------------------------------------------------------------

$KEY_PROPS_CONTENT = @"
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=$KEYSTORE
"@

Set-Content `
    -LiteralPath $KEY_PROPS `
    -Value $KEY_PROPS_CONTENT `
    -Encoding UTF8

# --------------------------------------------------------------------------
# Resultado
# --------------------------------------------------------------------------

Write-Host ""
Write-Host "Keystore criado em $KEYSTORE" -ForegroundColor Green
Write-Host "Propriedades em $KEY_PROPS (nao versionados)."
Write-Host ""

Write-Host "Cadastre estes fingerprints no Firebase:" -ForegroundColor Cyan
Write-Host "(Configuracoes do projeto -> seu app Android -> Adicionar impressao digital)"
Write-Host ""

& keytool -list -v `
    -keystore "$KEYSTORE" `
    -alias "$ALIAS" `
    -storepass "$STORE_PASS" |
    Select-String -Pattern 'SHA1:|SHA-256:|SHA256:'

if ($LASTEXITCODE -ne 0) {
    Write-Warning "Nao foi possivel consultar os fingerprints do keystore."
}

Write-Host ""
Write-Host "Depois, execute:" -ForegroundColor Cyan
Write-Host "  .\sh\make_apk.ps1"
Write-Host ""
Write-Host "Se a assinatura mudou, desinstale a versao anterior do APK antes de reinstalar."
Write-Host ""

# --------------------------------------------------------------------------
# Lembrete de seguranca
# --------------------------------------------------------------------------

Write-Host "IMPORTANTE:" -ForegroundColor Yellow
Write-Host "  - Nao envie secrets/upload-keystore.jks para o Git."
Write-Host "  - Nao envie android/key.properties para o Git."
Write-Host "  - Mantenha backup seguro do keystore e das senhas."
Write-Host ""
