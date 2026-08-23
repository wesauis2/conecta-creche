# Credenciais locais (Firebase / Google)

Cada desenvolvedor usa **seu próprio projeto Firebase**. Os arquivos abaixo ficam **somente na máquina local** — nunca entram no git (ver `.gitignore` e `.cursorignore`).

| Arquivo / pasta | Caminho no repositório | Origem |
|-----------------|------------------------|--------|
| Config Android (Google Services) | `android/app/google-services.json` | Console Firebase → Configurações do projeto → seus apps → Android |
| Config iOS (Google Services) | `ios/Runner/GoogleService-Info.plist` | Console Firebase → Configurações do projeto → seus apps → iOS |
| Opções FlutterFire | `lib/firebase_options.dart` | `flutterfire configure` ou wizard do projeto |
| Outros segredos (opcional) | `secrets/` | Chaves ou JSON extras que não devem ir em caminhos padrão |
| Variáveis de ambiente | `.env`, `.env.local`, etc. | Copiar de `.env.example` quando existir |
| Cache CLI Firebase | `.firebase/` | Gerado por `firebase deploy` / emuladores localmente |

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
