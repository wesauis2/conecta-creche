# Regras Firestore — `users`

Regras versionadas em [`firestore.rules`](../firestore.rules). Cada usuário autenticado só pode ler e gravar o próprio documento `users/{uid}`.

## Deploy

1. Instale a [Firebase CLI](https://firebase.google.com/docs/cli) e faça login (`firebase login`).
2. Na raiz do repositório, associe o projeto local (uma vez por máquina):

   ```bash
   firebase use --add
   ```

   Escolha **seu** projeto Firebase de desenvolvimento (credenciais locais — ver [`credentials.md`](credentials.md)).

3. Publique apenas as regras:

   ```bash
   firebase deploy --only firestore:rules
   ```

4. Confirme no console Firebase → Firestore → **Regras** que a versão publicada coincide com o arquivo do repositório.

## Simulador — negação entre usuários

Use o simulador do console (Firestore → Regras → **Playground**) ou a CLI com os parâmetros abaixo.

| Cenário | Coleção | Doc ID | Auth UID | Operação | Resultado esperado |
|---------|---------|--------|----------|----------|-------------------|
| Próprio doc | `users` | `abc123` | `abc123` | get / update | **Permitido** |
| Doc alheio | `users` | `xyz789` | `abc123` | get | **Negado** |
| Escrita alheia | `users` | `xyz789` | `abc123` | create / update | **Negado** |
| Sem auth | `users` | `abc123` | *(nenhum)* | get | **Negado** |

Passos no playground:

1. Cole o conteúdo de `firestore.rules` se ainda não estiver publicado.
2. Em **Authentication**, defina `request.auth.uid` como `abc123`.
3. Simule `get` em `/users/abc123` → deve permitir.
4. Mantenha `request.auth.uid` como `abc123` e simule `get` em `/users/xyz789` → deve negar.

Isso cobre o requisito de que o usuário A não lê nem grava o documento do usuário B.

## Promoção manual de papéis

Ver [`credentials.md`](credentials.md#promoção-de-admin-esta-semana).
