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

Alteração manual no console Firestore: editar `users/{uid}` e definir `role` (ex.: `gestao`). Sem automação de allowlist nesta fase.
