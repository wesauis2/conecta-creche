# Regras Firestore — `users` e `user_roles`

Regras versionadas em [`firestore.rules`](../firestore.rules).

- **`users/{uid}`** — perfil editável pelo próprio usuário (nome, e-mail espelhado do Google, foto). O campo `role` **não** pertence a esta coleção.
- **`user_roles/{uid}`** — papel do usuário (`convidado`, `gestao`, etc.). Leitura pelo dono; criação única no primeiro login apenas com `role: convidado`; alteração e exclusão **somente via console** (admin SDK) nesta fase.

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
| Próprio perfil | `users` | `abc123` | `abc123` | get / update | **Permitido** |
| Perfil alheio | `users` | `xyz789` | `abc123` | get | **Negado** |
| Escrita alheia | `users` | `xyz789` | `abc123` | create / update | **Negado** |
| Próprio papel | `user_roles` | `abc123` | `abc123` | get | **Permitido** |
| Criar papel (1º login) | `user_roles` | `abc123` | `abc123` | create com `role: convidado` | **Permitido** |
| Auto-promoção | `user_roles` | `abc123` | `abc123` | update `role` → `admin` | **Negado** |
| Papel alheio | `user_roles` | `xyz789` | `abc123` | get / write | **Negado** |
| Sem auth | `users` ou `user_roles` | `abc123` | *(nenhum)* | get | **Negado** |

Passos no playground:

1. Cole o conteúdo de `firestore.rules` se ainda não estiver publicado.
2. Em **Authentication**, defina `request.auth.uid` como `abc123`.
3. Simule `get` em `/users/abc123` → deve permitir.
4. Mantenha `request.auth.uid` como `abc123` e simule `get` em `/users/xyz789` → deve negar.
5. Simule `update` em `/user_roles/abc123` com `role: admin` → deve negar (promoção só via console).

Isso cobre o requisito de que o usuário A não lê nem grava o documento do usuário B.

## Promoção manual de papéis

Ver [`credentials.md`](credentials.md#promoção-de-admin-esta-semana).
