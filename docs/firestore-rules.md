# Regras Firestore — `users` e `user_roles`

Regras versionadas em [`firestore.rules`](../firestore.rules).

- **`users/{uid}`** — perfil editável pelo próprio usuário (nome, e-mail espelhado do Google, foto). O campo `role` **não** pertence a esta coleção. Gestão/admin podem **ler/listar** todos os perfis.
- **`user_roles/{uid}`** — papel do usuário (`convidado`, `gestao`, etc.). Leitura pelo dono ou por gestão/admin; criação única no primeiro login apenas com `role: convidado`; **update** por gestão/admin com hierarquia (papel alvo atual e novo papel ≤ ao do caller; sem alterar o próprio documento).

Hierarquia (rank): `admin` (4) > `gestao` (3) > `cuidador` (2) > `responsavel` (1) > `convidado` (0).

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

## Simulador — cenários

Use o simulador do console (Firestore → Regras → **Playground**) ou a CLI.

| Cenário | Coleção | Doc ID | Auth UID (papel) | Operação | Resultado esperado |
|---------|---------|--------|------------------|----------|-------------------|
| Próprio perfil | `users` | `abc123` | `abc123` | get / update | **Permitido** |
| Perfil alheio (não-manager) | `users` | `xyz789` | `abc123` (cuidador) | get | **Negado** |
| Listar usuários (gestão) | `users` | — | `mgr1` (gestao) | list | **Permitido** |
| Listar usuários (responsável) | `users` | — | `resp1` (responsavel) | list | **Negado** |
| Criar papel (1º login) | `user_roles` | `abc123` | `abc123` | create com `role: convidado` | **Permitido** |
| Auto-promoção | `user_roles` | `abc123` | `abc123` (gestao) | update `role` → `admin` | **Negado** |
| Elevar convidado (gestão) | `user_roles` | `guest1` (convidado) | `mgr1` (gestao) | update `role` → `responsavel` | **Permitido** |
| Gestão atribui admin | `user_roles` | `guest1` | `mgr1` (gestao) | update `role` → `admin` | **Negado** |
| Gestão altera admin | `user_roles` | `adm1` (admin) | `mgr1` (gestao) | update `role` → `cuidador` | **Negado** |
| Admin eleva para gestao | `user_roles` | `guest1` | `adm1` (admin) | update `role` → `gestao` | **Permitido** |
| Sem auth | `users` ou `user_roles` | `abc123` | *(nenhum)* | get | **Negado** |

Passos no playground (básico):

1. Publique ou cole o conteúdo de `firestore.rules`.
2. Em **Authentication**, defina `request.auth.uid` e garanta que exista `user_roles/{uid}` com o papel desejado no banco simulado.
3. Simule os cenários da tabela acima.

## Bootstrap do primeiro admin

O primeiro administrador ainda precisa ser promovido **uma vez** pelo console (o app não pode elevar ninguém antes de existir um manager). Depois disso, gestão e admin promovem pela tela **Usuários**. Ver [`credentials.md`](credentials.md#bootstrap-do-primeiro-admin).
