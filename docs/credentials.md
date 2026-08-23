# Credenciais locais (Firebase / Google)

Cada desenvolvedor usa **seu próprio projeto Firebase**. Os arquivos abaixo ficam **somente na máquina local** — nunca entram no git (ver `.gitignore` e `.cursorignore`).

| Arquivo / pasta | Caminho no repositório | Origem | Obrigatório (Android) |
|-----------------|------------------------|--------|------------------------|
| Config Android (Google Services) | `android/app/google-services.json` | Console Firebase → Configurações do projeto → seus apps → Android | **Sim** — build e execução |
| Opções FlutterFire | `lib/firebase_options.dart` | `flutterfire configure` (exige `firebase login`) | **Não** nesta semana — o app usa a config nativa do `google-services.json` |
| Config iOS (Google Services) | `ios/Runner/GoogleService-Info.plist` | Console Firebase → iOS | Não (só Android esta semana) |
| Outros segredos (opcional) | `secrets/` | Chaves ou JSON extras | Não |
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

## Promoção de admin (esta semana)

Promoção de papéis é **manual** no console Firestore — não há allowlist nem seed automático nesta fase.

1. Abra [Firebase Console](https://console.firebase.google.com/) → seu projeto → **Firestore Database** → **Dados**.
2. Localize o documento `user_roles/{uid}` (o `uid` aparece na tela de sessão após o primeiro login Google). O perfil fica em `users/{uid}` separadamente.
3. Edite o campo `role` em `user_roles/{uid}` para um dos valores válidos: `admin`, `gestao`, `cuidador`, `responsavel` ou `convidado` (padrão no primeiro login).
4. Para liberar um colega como administrador da equipe, defina `role: admin` em `user_roles/{uid}` **uma vez**; o app não consegue alterar papéis pelo cliente (regras bloqueiam `update`/`delete` em `user_roles`).

Deploy das regras que protegem esses documentos: [`docs/firestore-rules.md`](firestore-rules.md).
