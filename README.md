# Conecta Creche

Canal entre a rotina diária na creche e os pais de crianças de 1 a 5 anos — presença, avisos, relatórios e mais no produto completo.

**Esta semana:** fundação técnica com Firebase por desenvolvedor, login Google, modelo mínimo de usuários e perfil. Ver [`docs/backlog/conecta-creche/SPEC.md`](docs/backlog/conecta-creche/SPEC.md).

## Credenciais locais

Firebase e Google Sign-In exigem arquivos que **não** são versionados. Onde colocar cada um: [`docs/credentials.md`](docs/credentials.md).

Para configurar seu projeto Firebase passo a passo (console + `google-services.json` local — **sem** exigir `firebase login` para rodar o app):

```bash
./sh/firebase-setup.sh
```

Publicar regras Firestore na nuvem **sim** exige `firebase login` (ver abaixo).

APK release para instalar no celular: gere o keystore uma vez (`./sh/create-keystore.sh`), cadastre o SHA no Firebase, depois `./sh/make_apk.sh`. Sem isso o Play Protect pode marcar o APK como nocivo — ver [`docs/credentials.md`](docs/credentials.md#assinatura-android-e-play-protect).

## Desenvolvimento

```bash
flutter pub get
flutter analyze
flutter run
```

Requisitos: Flutter SDK compatível com `sdk: ^3.12.2` em `pubspec.yaml`.

## Firestore

Após o primeiro login Google, o app grava `users/{uid}` no Firestore. Para publicar as regras na nuvem (requer `firebase login` uma vez):

```bash
firebase login
firebase deploy --only firestore:rules
```

Passo a passo completo, simulador de hierarquia e bootstrap do primeiro admin: [`docs/firestore-rules.md`](docs/firestore-rules.md) e [`docs/credentials.md`](docs/credentials.md).
