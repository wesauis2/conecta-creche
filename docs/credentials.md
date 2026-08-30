# Credenciais locais (Firebase / Google)

Cada desenvolvedor usa **seu próprio projeto Firebase**. Os arquivos abaixo ficam **somente na máquina local** — nunca entram no git (ver `.gitignore` e `.cursorignore`).

| Arquivo / pasta | Caminho no repositório | Origem | Obrigatório (Android) |
|-----------------|------------------------|--------|------------------------|
| Config Android (Google Services) | `android/app/google-services.json` | Console Firebase → Configurações do projeto → seus apps → Android | **Sim** — build e execução |
| Opções FlutterFire | `lib/firebase_options.dart` | `flutterfire configure` (exige `firebase login`) | **Não** nesta semana — o app usa a config nativa do `google-services.json` |
| Config iOS (Google Services) | `ios/Runner/GoogleService-Info.plist` | Console Firebase → iOS | Não (só Android esta semana) |
| Outros segredos (opcional) | `secrets/` | Chaves ou JSON extras; keystore de upload | Keystore para APK release |
| Assinatura Android release | `android/key.properties` + `secrets/upload-keystore.jks` | `./sh/create-keystore.sh` | **Sim** para `./sh/make_apk.sh` |
| Variáveis de ambiente | `.env`, `.env.local`, etc. | Wizard / cópia de `.env.example` | Não |
| Cache CLI Firebase | `.firebase/` | `firebase deploy` / emuladores | Só se for publicar regras pela CLI |

## Firebase CLI — quando precisa de login

| Tarefa | Precisa de `firebase login`? |
|--------|------------------------------|
| Rodar o app Android (`flutter run` / build APK) | **Não** — basta `android/app/google-services.json` |
| Wizard (`./sh/firebase-setup.sh`) até o passo do `google-services.json` | **Não** |
| Gerar `lib/firebase_options.dart` com `flutterfire configure` | **Sim** (opcional nesta semana) |
| Publicar `firestore.rules` (`firebase deploy --only firestore:rules`) | **Sim** |

## Verificação rápida

Depois de colocar os arquivos, confirme que o git não os enxerga:

```bash
git status --short
```

Nenhum dos caminhos acima deve aparecer. Para testar, crie um arquivo falso e confirme que está ignorado:

```bash
touch android/app/google-services.json lib/firebase_options.dart
git status --short   # deve estar vazio
```

## Google Sign-In (`serverClientId`)

O plugin `google_sign_in` 7+ no Android exige um **cliente OAuth Web** no `google-services.json` (`oauth_client` com `client_type: 3`). Sem isso aparece:

`GoogleSignInException … serverClientId must be provided on Android`

O JSON atual fica incompleto se o provedor Google foi ativado sem app Web / sem baixar o arquivo de novo, ou se o SHA-1 não foi cadastrado.

### Correção

1. Firebase Console → **Authentication** → Sign-in method → **Google** → ativar e salvar.
2. Configurações do projeto → **Adicionar app → Web** (apelido qualquer) se ainda não existir app Web.
3. No app **Android**, adicione impressões digitais SHA-1:
   - Debug: `keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android`
   - Release/upload: `./sh/create-keystore.sh`
4. **Baixe de novo** `google-services.json` e substitua `android/app/google-services.json`.
5. Valide:

   ```bash
   ./sh/verify-google-sign-in.sh
   ```

6. Reinstale o app (`flutter run` ou `./sh/make_apk.sh`).

Opcional: passar o ID Web explicitamente no build:

```bash
flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=123456789-xxxx.apps.googleusercontent.com
```

## Assinatura Android e Play Protect

O aviso **“App nocivo detectado… tenta burlar as proteções de segurança do Android”** costuma ser um **falso positivo do Google Play Protect** ao instalar um APK **fora da Play Store** assinado com a **chave debug padrão** do Android SDK (o mesmo certificado em todas as máquinas de desenvolvimento — e também usado por malware).

O app **não** pede permissões sensíveis nem tenta burlar o sistema. O que estava errado no projeto era o `build` release (`./sh/make_apk.sh`) assinar com `signingConfigs.debug`.

### Correção

1. Gere um keystore **só deste projeto** (ignorado pelo git):

   ```bash
   ./sh/create-keystore.sh
   ```

2. No [Firebase Console](https://console.firebase.google.com/) → seu projeto → ⚙️ Configurações → app Android, **adicione** os SHA-1 e SHA-256 impressos pelo script (Google Sign-In exige o SHA do certificado que assina o APK).

3. Gere o APK de novo:

   ```bash
   ./sh/make_apk.sh
   ```

4. No celular: **desinstale** a versão antiga (assinatura diferente) e instale o APK novo em `build/app/outputs/flutter-apk/`.

Se o Play Protect ainda pedir verificação numa instalação sideload, use **Verificar** / **Instalar mesmo assim** — isso é esperado para apps que não vêm da Play Store.

`flutter run` (debug via USB) continua usando a chave debug automática; o problema crítico era distribuir **release** com essa chave.

## Bootstrap do primeiro admin

O primeiro administrador do projeto ainda é promovido **uma vez** no console Firestore. Depois disso, gestão e admin alteram papéis pela tela **Usuários** no app (respeitando a hierarquia).

1. Abra [Firebase Console](https://console.firebase.google.com/) → seu projeto → **Firestore Database** → **Dados**.
2. Faça login no app com Google e anote o `uid` (visível no perfil / documentos criados).
3. Localize `user_roles/{uid}` (o perfil fica em `users/{uid}` separadamente).
4. Edite o campo `role` para `admin` (valores válidos: `admin`, `gestao`, `cuidador`, `responsavel`, `convidado`).
5. Publique as regras atualizadas (`firebase deploy --only firestore:rules`) para habilitar listagem e promoção in-app — ver [`firestore-rules.md`](firestore-rules.md).
6. No app, abra **Usuários** (ícone de grupo no home) para buscar convidados e definir o acesso.

Deploy das regras: [`docs/firestore-rules.md`](firestore-rules.md).
