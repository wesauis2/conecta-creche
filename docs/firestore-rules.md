# Regras Firestore — `users`, `user_roles`, `children` e `presence_records`

Regras versionadas em [`firestore.rules`](../firestore.rules).

- **`users/{uid}`** — perfil editável pelo próprio usuário (nome, e-mail espelhado do Google, foto). O campo `role` **não** pertence a esta coleção. Gestão/admin podem **ler/listar** todos os perfis.
- **`user_roles/{uid}`** — papel do usuário (`convidado`, `gestao`, etc.). Leitura pelo dono ou por gestão/admin; criação única no primeiro login apenas com `role: convidado`; **update** por gestão/admin com hierarquia (papel alvo atual e novo papel ≤ ao do caller; sem alterar o próprio documento).
- **`children/{id}`** — catálogo (CONTEXT.md "Criança"). Cuidador+ lê/lista, cria e renomeia; só gestão+ altera `active` (inativação); sem hard delete.
- **`presence_records/{id}`** — registros de presença (CONTEXT.md "Registro de presença"). Cuidador+ lê/lista, cria chegada e fecha com parecer (e edita o parecer depois); `childId`/`dayKey`/`arrivedAt` e um `departedAt` já definido são imutáveis fora do admin; só admin altera `arrivedAt`/`departedAt` já definidos ou apaga (hard delete).

Hierarquia (rank): `admin` (4) > `gestao` (3) > `cuidador` (2) > `responsavel` (1) > `convidado` (0). Helpers `isCaregiverPlus()` (rank ≥ 2), `isGestaoPlus()` (rank ≥ 3, usado por `isManager()`) e `isAdmin()` (rank == 4) espelham `canOperatePresence`/`canInactivateChild`/`canAdminPresence` em `lib/users/user_role.dart`.

## Deploy

1. Instale a [Firebase CLI](https://firebase.google.com/docs/cli) e faça login (`firebase login`).
2. Na raiz do repositório, associe o projeto local (uma vez por máquina):

   ```bash
   firebase use --add
   ```

   Escolha **seu** projeto Firebase de desenvolvimento (credenciais locais — ver [`credentials.md`](credentials.md)).

3. Publique regras e índices:

   ```bash
   firebase deploy --only firestore:rules,firestore:indexes
   ```

4. Confirme no console Firebase → Firestore → **Regras** que a versão publicada coincide com o arquivo do repositório, e em **Índices** que os compostos de `presence_records` (abaixo) existem.

### Índices compostos

Versionados em [`firestore.indexes.json`](../firestore.indexes.json) (referenciado em `firebase.json` → `firestore.indexes`). Suportam a listagem/range da gestão por `dayKey` filtrando abertos/fechados ordenados por horário:

- `presence_records`: `dayKey` ASC, `isOpen` ASC, `arrivedAt` ASC
- `presence_records`: `dayKey` ASC, `isOpen` ASC, `departedAt` ASC

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
| Criar criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | create `{name, active:true, createdBy:'cui1', updatedBy:'cui1', ...}` | **Permitido** |
| Renomear criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{name}` | **Permitido** |
| Inativar criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{active:false}` | **Negado** |
| Inativar criança (gestão) | `children` | `child1` | `mgr1` (gestao) | update `{active:false}` | **Permitido** |
| Ler catálogo (responsável) | `children` | — | `resp1` (responsavel) | get / list | **Negado** |
| Apagar criança (admin) | `children` | `child1` | `adm1` (admin) | delete | **Negado** (sem hard delete) |
| Registrar chegada (cuidador) | `presence_records` | `pr1` | `cui1` (cuidador) | create `{childId, dayKey, arrivedAt, departedAt:null, isOpen:true, createdBy:'cui1', updatedBy:'cui1'}` | **Permitido** |
| Registrar saída+parecer (cuidador) | `presence_records` | `pr1` (aberto) | `cui1` (cuidador) | update `{departedAt, isOpen:false, parecer}` | **Permitido** |
| Editar parecer depois (cuidador) | `presence_records` | `pr1` (fechado) | `cui1` (cuidador) | update `{parecer}` | **Permitido** |
| Alterar `arrivedAt` (cuidador) | `presence_records` | `pr1` | `cui1` (cuidador) | update `{arrivedAt}` | **Negado** |
| Reabrir `departedAt` (cuidador) | `presence_records` | `pr1` (fechado) | `cui1` (cuidador) | update `{departedAt: outro valor}` | **Negado** |
| Alterar `arrivedAt`/`departedAt` (admin) | `presence_records` | `pr1` | `adm1` (admin) | update `{arrivedAt, dayKey, isOpen}` | **Permitido** |
| Apagar registro (admin) | `presence_records` | `pr1` | `adm1` (admin) | delete | **Permitido** |
| Apagar registro (gestão) | `presence_records` | `pr1` | `mgr1` (gestao) | delete | **Negado** |
| Ler presença (convidado) | `presence_records` | — | `guest1` (convidado) | get / list | **Negado** |

Passos no playground (básico):

1. Publique ou cole o conteúdo de `firestore.rules`.
2. Em **Authentication**, defina `request.auth.uid` e garanta que exista `user_roles/{uid}` com o papel desejado no banco simulado.
3. Simule os cenários da tabela acima.

## Bootstrap do primeiro admin

O primeiro administrador ainda precisa ser promovido **uma vez** pelo console (o app não pode elevar ninguém antes de existir um manager). Depois disso, gestão e admin promovem pela tela **Usuários**. Ver [`credentials.md`](credentials.md#bootstrap-do-primeiro-admin).
