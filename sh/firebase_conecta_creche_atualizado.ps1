#requires -Version 5.1
<#
    Firebase - Conecta Creche
    Conversao do wizard Bash para Windows PowerShell 5.1+
#>

$ErrorActionPreference = "Stop"

$TOTAL_STAGES = 6
$TOTAL_MINUTES = 23

$script:_STAGE_INDEX = 0
$script:_MINUTES_ELAPSED = 0
$script:WRITTEN_ENV = @()
$script:WRITTEN_SECRET = @()
$script:SKIPPED = @()
$script:WRITTEN_FILES = @()

function Clear-ScreenSafe {
    try { Clear-Host } catch {}
}

function Pause-Wizard([string]$Message = "Press Enter to continue") {
    Write-Host -NoNewline "  $Message "
    [void](Read-Host)
}

function Banner([string]$Title) {
    Clear-ScreenSafe
    Write-Host ""
    Write-Host "  $Title" -ForegroundColor Blue
    Write-Host "  $TOTAL_STAGES stages - about $TOTAL_MINUTES minutes"
    Write-Host ""
    Write-Host "  You drive the browser; this wizard tells you exactly what to do and"
    Write-Host "  captures the values you copy back. Stop any time with Ctrl-C and re-run"
    Write-Host "  later - it remembers values already saved."
    Pause-Wizard "Ready to start?"
}

function Stage([string]$Name, [int]$Minutes = 0) {
    Clear-ScreenSafe
    $script:_STAGE_INDEX++
    $remaining = $TOTAL_MINUTES - $script:_MINUTES_ELAPSED
    if ($remaining -lt 0) { $remaining = 0 }
    $script:_MINUTES_ELAPSED += $Minutes
    Write-Host ""
    Write-Host "> Stage $script:_STAGE_INDEX/$TOTAL_STAGES - $Name  (~$remaining min left)" -ForegroundColor Blue
}

function Say([string]$Text)  { Write-Host "  $Text" }
function Step([string]$Text) { Write-Host "  - $Text" -ForegroundColor Blue }
function Note([string]$Text) { Write-Host "  $Text" -ForegroundColor DarkGray }
function Warn([string]$Text) { Write-Host "  [AVISO] $Text" -ForegroundColor Yellow }

function Open-Url([string]$Url) {
    Write-Host "  -> opening $Url" -ForegroundColor Green
    try {
        Start-Process $Url | Out-Null
    } catch {
        Warn "Nao foi possivel abrir o navegador. Acesse manualmente: $Url"
    }
}

function Confirm([string]$Question) {
    $reply = Read-Host "  ? $Question [y/N]"
    return $reply -match '^[Yy]'
}

function Get-Existing([string]$Key) {
    if (-not (Test-Path -LiteralPath $script:ENV_FILE -PathType Leaf)) {
        return $null
    }

    $pattern = "^$([regex]::Escape($Key))="
    $line = Get-Content -LiteralPath $script:ENV_FILE -ErrorAction SilentlyContinue |
        Where-Object { $_ -match $pattern } |
        Select-Object -Last 1

    if ($null -eq $line) { return $null }
    return ($line -replace $pattern, "")
}

function Write-Env([string]$Key, [string]$Value) {
    if (-not (Test-Path -LiteralPath $script:ENV_FILE)) {
        New-Item -ItemType File -Path $script:ENV_FILE -Force | Out-Null
    }

    $lines = @(Get-Content -LiteralPath $script:ENV_FILE -ErrorAction SilentlyContinue)
    $pattern = "^$([regex]::Escape($Key))="
    $lines = @($lines | Where-Object { $_ -notmatch $pattern })
    $lines += "$Key=$Value"

    # UTF-8 BOM keeps compatibility with Windows PowerShell 5.1.
    Set-Content -LiteralPath $script:ENV_FILE -Value $lines -Encoding UTF8

    $script:WRITTEN_ENV += $Key
    Write-Host "  [OK] wrote $Key -> $script:ENV_FILE" -ForegroundColor Green
}

function Write-Credential-File([string]$Dest, [string]$Src) {
    $parent = Split-Path -Parent $Dest

    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    Copy-Item -LiteralPath $Src -Destination $Dest -Force
    $script:WRITTEN_FILES += $Dest
    Write-Host "  [OK] gravou $Dest" -ForegroundColor Green
}

function Firebase-Project-Url([string]$Path) {
    $project = if ($env:FIREBASE_PROJECT_ID) {
        $env:FIREBASE_PROJECT_ID
    } else {
        "_"
    }

    return "https://console.firebase.google.com/project/$project/$Path"
}

function Verify-Google-SignIn([string]$JsonPath) {
    if (-not (Test-Path -LiteralPath $JsonPath -PathType Leaf)) {
        return $false
    }

    try {
        $json = Get-Content -LiteralPath $JsonPath -Raw | ConvertFrom-Json

        # google-services.json normally stores oauth_client inside client[].client_info
        # or at project_info level depending on the generated configuration.
        $clients = @()

        if ($json.client) {
            foreach ($client in @($json.client)) {
                if ($client.oauth_client) {
                    $clients += @($client.oauth_client)
                }
            }
        }

        if ($json.project_info -and $json.project_info.oauth_client) {
            $clients += @($json.project_info.oauth_client)
        }

        # Web OAuth client = client_type 3.
        $webClient = $clients | Where-Object {
            "$($_.client_type)" -eq "3"
        } | Select-Object -First 1

        if ($webClient) {
            return $true
        }

        return $false
    } catch {
        Warn "Nao foi possivel ler o JSON: $($_.Exception.Message)"
        return $false
    }
}

function Finish-Wizard {
    Clear-ScreenSafe
    Write-Host ""
    Write-Host "  [OK] Configuracao concluida" -ForegroundColor Green

    if ($script:WRITTEN_FILES.Count -gt 0) {
        Note "Arquivos gravados nesta execucao:"
        foreach ($f in $script:WRITTEN_FILES) {
            Note "  - $f"
        }
    }

    if ($script:WRITTEN_ENV.Count -gt 0) {
        Note "Valores em $script:ENV_FILE`: $($script:WRITTEN_ENV -join ' ')"
    }

    if ($script:WRITTEN_SECRET.Count -gt 0) {
        Note "Secrets GitHub configurados: $($script:WRITTEN_SECRET -join ' ')"
    }

    if ($script:SKIPPED.Count -gt 0) {
        Write-Host ""
        Warn "Ainda manualmente:"
        foreach ($s in $script:SKIPPED) {
            Note "  - $s"
        }
    }

    Write-Host ""
    Note "Proximo passo: flutter pub get; flutter run"
    Note "Referencia: docs/credentials.md"
    Write-Host ""
}

# --------------------------------------------------------------------------
# Repository paths
# --------------------------------------------------------------------------

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$REPO_ROOT = Split-Path -Parent $SCRIPT_DIR
Set-Location $REPO_ROOT

$script:ENV_FILE = Join-Path $REPO_ROOT ".env"
$ANDROID_PACKAGE = "br.univates.labmobile.conecta_creche"

# --------------------------------------------------------------------------
# Wizard
# --------------------------------------------------------------------------

Banner "Firebase - Conecta Creche"

# 1. Projeto Firebase
Stage "Projeto Firebase" 3
Say "Cada desenvolvedor usa seu proprio projeto Firebase - credenciais ficam so na sua maquina."
Open-Url "https://console.firebase.google.com/"
Step "Entre com sua conta Google."
Step "Crie um projeto novo (ex.: conecta-creche-seunome) ou selecione um existente."
Step "Anote o ID do projeto em Configuracoes do projeto -> Geral -> ID do projeto."

$FIREBASE_PROJECT_ID = Read-Host "ID do projeto Firebase:"
if (-not [string]::IsNullOrWhiteSpace($FIREBASE_PROJECT_ID)) {
    Write-Env "FIREBASE_PROJECT_ID" $FIREBASE_PROJECT_ID
    $env:FIREBASE_PROJECT_ID = $FIREBASE_PROJECT_ID
} else {
    $script:SKIPPED += "definir FIREBASE_PROJECT_ID em .env"
    Warn "ID do projeto vazio - URLs das proximas etapas usam o console generico."
}
Pause-Wizard "Projeto criado ou selecionado?"

# 2. Authentication + Google
Stage "Authentication e Google Sign-In" 5
Say "Habilite login com Google para o app Conecta Creche."
Open-Url (Firebase-Project-Url "authentication/providers")
Step "Clique em 'Comecar' se Authentication ainda nao estiver ativo."
Step "Na aba 'Sign-in method', abra o provedor 'Google'."
Step "Ative o provedor e escolha um e-mail de suporte do projeto (obrigatorio)."
Step "Salve as alteracoes - isso cria o cliente OAuth Web (serverClientId)."
Pause-Wizard "Google Sign-In habilitado?"

# 3. Firestore
Stage "Firestore Database" 3
Say "Crie o banco Firestore para usuarios e dados do app."
Open-Url (Firebase-Project-Url "firestore")
Step "Clique em 'Criar banco de dados' se ainda nao existir."
Step "Escolha o modo de producao (as regras versionadas no repo serao aplicadas depois)."
Step "Selecione a regiao mais proxima (ex.: southamerica-east1 - Sao Paulo)."
Pause-Wizard "Firestore criado?"
Note "Promocao de admin (role gestao): edicao manual no console - ver docs/credentials.md"

# 4. google-services.json
Stage "App Android e google-services.json" 8
Say "Registre o app Android, cadastre SHA-1 e baixe a configuracao Google Services."
Say "O google_sign_in 7+ exige um oauth_client Web (client_type: 3) no JSON."
Open-Url (Firebase-Project-Url "settings/general")
Step "Em 'Seus apps', adicione um app Android (icone Android) se ainda nao existir."
Step "Package name (applicationId): $ANDROID_PACKAGE"
Step "Se ainda nao houver app Web no projeto: Adicionar app -> Web (apelido livre) -> registrar."
Step "No app Android -> 'Adicionar impressao digital', cadastre SHA-1 do debug e do upload."
Note "Debug: keytool -list -v -keystore `$env:USERPROFILE\.android\debug.keystore -alias androiddebugkey -storepass android | Select-String SHA1"
Note "Upload: .\sh\create-keystore.ps1  (se existir; imprime SHA-1 / SHA-256)"
Step "Baixe google-services.json novamente depois de ativar Google + SHA + app Web."
Note "Destino no repo: android/app/google-services.json (gitignored)"

$GOOGLE_SERVICES_SRC = Read-Host "Caminho completo do google-services.json baixado (vazio para pular):"

$googleServicesPath = Join-Path $REPO_ROOT "android/app/google-services.json"

if (-not [string]::IsNullOrWhiteSpace($GOOGLE_SERVICES_SRC)) {
    if (Test-Path -LiteralPath $GOOGLE_SERVICES_SRC -PathType Leaf) {
        Write-Credential-File $googleServicesPath $GOOGLE_SERVICES_SRC
    } else {
        $script:SKIPPED += "copiar google-services.json -> android/app/google-services.json"
        Warn "Arquivo nao encontrado: $GOOGLE_SERVICES_SRC"
    }
} elseif (Test-Path -LiteralPath $googleServicesPath -PathType Leaf) {
    Note "android/app/google-services.json ja existe - mantido."
} else {
    $script:SKIPPED += "copiar google-services.json -> android/app/google-services.json"
}

if (Test-Path -LiteralPath $googleServicesPath -PathType Leaf) {
    if (Verify-Google-SignIn $googleServicesPath) {
        Write-Host "  [OK] google-services.json possui oauth_client Web (serverClientId)" -ForegroundColor Green
    } else {
        $script:SKIPPED += "corrigir oauth Web em google-services.json (serverClientId)"
        Warn "JSON incompleto - verifique o app Web/OAuth client_type 3 em docs/credentials.md"
    }
}

Note "iOS (ios/Runner/GoogleService-Info.plist) e opcional esta semana - veja docs/credentials.md"

# 5. FlutterFire configure
Stage "FlutterFire - firebase_options.dart (opcional)" 2
Say "No Android desta semana, so o google-services.json ja basta para build e execucao."
Say "Este passo gera lib/firebase_options.dart - util no futuro (iOS/web), mas nao e obrigatorio."

if (Test-Path -LiteralPath $googleServicesPath -PathType Leaf) {
    Write-Host "  [OK] android/app/google-services.json presente - pode pular o FlutterFire." -ForegroundColor Green
}

Note "flutterfire configure exige firebase login. Sem CLI logado, ignore este estagio."
Step "Opcional: dart pub global activate flutterfire_cli; firebase login"
Step "Opcional: flutterfire configure --project=<id> --platforms=android --out=lib/firebase_options.dart"

$flutterfire = Get-Command flutterfire -ErrorAction SilentlyContinue
if ($flutterfire -and $FIREBASE_PROJECT_ID) {
    if (Confirm "Executar flutterfire configure agora (opcional)") {
        try {
            & flutterfire configure `
                --project="$FIREBASE_PROJECT_ID" `
                --platforms=android `
                --yes `
                --out="lib/firebase_options.dart"

            if ($LASTEXITCODE -eq 0) {
                $script:WRITTEN_FILES += "lib/firebase_options.dart"
                Write-Host "  [OK] gerou lib/firebase_options.dart" -ForegroundColor Green
            } else {
                Note "FlutterFire falhou (ex.: sem firebase login) - ok para Android se google-services.json existir."
            }
        } catch {
            Note "FlutterFire falhou - ok para Android se google-services.json existir."
        }
    } else {
        Note "FlutterFire ignorado - use so google-services.json no Android."
    }
} elseif (Test-Path -LiteralPath (Join-Path $REPO_ROOT "lib/firebase_options.dart") -PathType Leaf) {
    Note "lib/firebase_options.dart ja existe - mantido."
} else {
    Note "Sem flutterfire/login: pule. android/app/google-services.json e suficiente para flutter run."
}

# 6. Verificar .gitignore
Stage "Verificar .gitignore" 2
Say "Confirmamos que credenciais nao entram no git."
Note "Referencia: docs/credentials.md"

$CREDENTIAL_PATHS = @(
    "android/app/google-services.json",
    "lib/firebase_options.dart",
    "ios/Runner/GoogleService-Info.plist",
    "secrets/",
    ".env"
)

$git = Get-Command git -ErrorAction SilentlyContinue

if ($git) {
    foreach ($p in $CREDENTIAL_PATHS) {
        & git check-ignore -q -- $p 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  [OK] ignorado: $p" -ForegroundColor Green
        } else {
            Warn "$p nao esta no .gitignore"
            $script:SKIPPED += "garantir que $p esta no .gitignore"
        }
    }

    $status = & git status --short -- `
        "android/app/google-services.json" `
        "lib/firebase_options.dart" `
        "ios/Runner/GoogleService-Info.plist" `
        "secrets/" `
        ".env" 2>$null

    if ($status) {
        Warn "git status mostra arquivos sensiveis - nao faca commit deles."
    } else {
        Write-Host "  [OK] git status limpo (credenciais nao rastreadas)" -ForegroundColor Green
    }
} else {
    Warn "Git nao foi encontrado no PATH. A verificacao do .gitignore foi ignorada."
    $script:SKIPPED += "instalar/configurar Git e verificar os arquivos sensiveis"
}

Say "Teste opcional: crie um arquivo temporario em android/app/google-services.json e rode git status --short (deve ficar vazio se estiver ignorado)."
Pause-Wizard "Verificacao concluida?"

Finish-Wizard
