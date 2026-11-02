# Regras Firestore

Regras versionadas em [`firestore.rules`](../firestore.rules). Índices em [`firestore.indexes.json`](../firestore.indexes.json).

## Coleções cobertas (matriz final)

| Coleção | Read | Write |
|---------|------|-------|
| `users/{uid}` | dono ou gestão+ | dono (sem `role`) |
| `user_roles/{uid}` | dono ou gestão+ | create self=`convidado`; update gestão+ com hierarquia |
| `children/{id}` | Cuidador+ **ou** uid ∈ `responsibleUids` | create/rename Cuidador+; `active` e `responsibleUids` só gestão+ |
| `presence_records/{id}` | Cuidador+ **ou** responsável vinculado à criança | create/close/parecer Cuidador+; admin corrige/apaga |
| `presence_records/{id}/answers/{id}` | mesmos leitores do registro | create/update Cuidador+ (janela 24h no app) |
| `form_questions/{id}` | Cuidador+ | gestão+ |
| `mural_posts/{id}` | rank ≥ responsável + `releasedAt` (gestão+ vê pré-liberação) | gestão+ |
| `notifications/{id}` | destinatário (`userId`) ou broadcast (`userId` ausente/null) | gestão+ |
| `fcm_tokens/{id}` | dono (`uid`) | dono |
| `levels` / `classes` / `classrooms` | Cuidador+ | gestão+ |
| `mural_reads/{id}` | dono; gestão+ lista | dono (próprio `uid`) |

Hierarquia (rank): `admin` (4) > `gestao` (3) > `cuidador` (2) > `responsavel` (1) > `convidado` (0). Helpers `isCaregiverPlus()` / `isGestaoPlus()` / `isAdmin()` / `isLinkedResponsible(childId)` espelham `lib/users/user_role.dart` e `docs/requisitos/papeis-acesso.md`. Matriz comentada no topo de `firestore.rules`.

**Vínculos:** campo `children.responsibleUids` (array). Query do responsável: `array-contains` (índice single-field automático). Sem coleção `child_responsibles` na v1.

**Queries após endurecer:** listagens do cliente devem restringir o conjunto ao que o papel pode ler (ex.: responsável → `children` com `array-contains`; presença por `childId` vinculado; mural com `releasedAt <= now` se não for gestão+; notifications só do `userId` + broadcasts). Queries “pega tudo e filtra no client” falham se existir doc ilegível no resultado.

## Checklist — publish manual

**Não há deploy automático.** Publique só quando a equipe decidir propagar o arquivo do repo.

1. **Pré-checagem local**
   - [ ] `git status` limpo no commit que contém `firestore.rules` / `firestore.indexes.json`
   - [ ] Diff revisado: matriz final (vínculos, presença, forms, mural, notifications, placeholders)
   - [ ] `flutter test` passou no branch
   - [ ] App/queries alinhados às rules (responsável não lista `presence_records`/`mural_posts`/`notifications` sem filtro)

2. **CLI / projeto**
   - [ ] Firebase CLI instalada e logada: `firebase login`
   - [ ] Na raiz do repo: `firebase use` aponta para o **projeto de lab/dev** (ver [`credentials.md`](credentials.md))
   - [ ] Confirme o project id: `firebase projects:list` / `firebase use`

3. **Deploy de regras**
   ```bash
   firebase deploy --only firestore:rules
   ```
   - [ ] Comando terminou sem erro
   - [ ] Console Firebase → Firestore → **Regras**: versão publicada = conteúdo do repo

4. **Deploy de índices (se o JSON mudou ou o console pediu índice)**
   ```bash
   firebase deploy --only firestore:indexes
   ```
   - [ ] Ou combined: `firebase deploy --only firestore:rules,firestore:indexes`
   - [ ] Console → **Índices**: compostos abaixo em estado *Enabled* (build pode demorar)

5. **Smoke manual pós-deploy**
   - [ ] Login cuidador: chegada → ocorrência (answer) → saída; **não** altera `responsibleUids` / `active`
   - [ ] Login gestão: editar `responsibleUids`, publicar mural (incl. pré-liberação), forms, incidentes
   - [ ] Login responsável: listar só crianças vinculadas + presença/answers delas; mural só liberado; notifications próprias + broadcast
   - [ ] Sem auth: leituras negadas no playground
   - [ ] Placeholders: `fcm_tokens` só dono; `levels`/`classes`/`classrooms` read Cuidador+ / write gestão+; `mural_reads` dono write / gestão+ lista

6. **Rollback rápido (se precisar)**
   - [ ] Restaurar `firestore.rules` do commit anterior e `firebase deploy --only firestore:rules`
   - [ ] Índices compostos não se “desfazem” com rollback de rules; remova no console só se necessário

### Índices compostos versionados

Em [`firestore.indexes.json`](../firestore.indexes.json) (`firebase.json` → `firestore.indexes`):

| Coleção | Campos | Uso |
|---------|--------|-----|
| `presence_records` | `dayKey`, `isOpen`, `arrivedAt` | gestão/cuidador: dia + Presentes/Saíram ordenado por chegada |
| `presence_records` | `dayKey`, `isOpen`, `departedAt` | gestão/cuidador: dia + Saíram ordenado por saída |
| `presence_records` | `childId`, `dayKey`, `isOpen` | open-guard / “já tem registro aberto hoje?” |
| `presence_records` | `childId`, `dayKey`, `arrivedAt` | responsável/relatórios: registros por criança+dia ordenados por chegada |

Single-field (automáticos): `children.responsibleUids` (`array-contains`), `children.active`, `form_questions.active`, `presence_records.childId`, `mural_posts.releasedAt`, `notifications.userId`, `fcm_tokens.uid`, `mural_reads.uid`. Mural/notifications ainda podem ordenar no client **depois** de uma query já restrita ao legível — sem composto obrigatório extra na v1.

## Simulador — cenários

Use o playground (Firestore → Regras) ou a CLI.

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
| Criar criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | create `{name, active:true, responsibleUids:[], createdBy:'cui1', ...}` | **Permitido** |
| Renomear criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{name}` | **Permitido** |
| Vincular responsável (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{responsibleUids:['resp1']}` | **Negado** |
| Vincular responsável (gestão) | `children` | `child1` | `mgr1` (gestao) | update `{responsibleUids:['resp1']}` | **Permitido** |
| Inativar criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{active:false}` | **Negado** |
| Inativar criança (gestão) | `children` | `child1` | `mgr1` (gestao) | update `{active:false}` | **Permitido** |
| Ler criança vinculada (responsável) | `children` | `child1` (`responsibleUids`∋`resp1`) | `resp1` | get | **Permitido** |
| Ler criança não vinculada (responsável) | `children` | `child2` | `resp1` | get | **Negado** |
| Apagar criança (admin) | `children` | `child1` | `adm1` (admin) | delete | **Negado** (sem hard delete) |
| Registrar chegada (cuidador) | `presence_records` | `pr1` | `cui1` (cuidador) | create `{childId, dayKey, arrivedAt, departedAt:null, isOpen:true, ...}` | **Permitido** |
| Registrar saída+parecer (cuidador) | `presence_records` | `pr1` (aberto) | `cui1` (cuidador) | update `{departedAt, isOpen:false, parecer}` | **Permitido** |
| Editar parecer depois (cuidador) | `presence_records` | `pr1` (fechado) | `cui1` (cuidador) | update `{parecer}` | **Permitido** |
| Alterar `arrivedAt` (cuidador) | `presence_records` | `pr1` | `cui1` (cuidador) | update `{arrivedAt}` | **Negado** |
| Reabrir `departedAt` (cuidador) | `presence_records` | `pr1` (fechado) | `cui1` (cuidador) | update `{departedAt: outro valor}` | **Negado** |
| Alterar timestamps (admin) | `presence_records` | `pr1` | `adm1` (admin) | update `{arrivedAt, dayKey, isOpen}` | **Permitido** |
| Apagar registro (admin) | `presence_records` | `pr1` | `adm1` (admin) | delete | **Permitido** |
| Apagar registro (gestão) | `presence_records` | `pr1` | `mgr1` (gestao) | delete | **Negado** |
| Ler presença da criança vinculada (responsável) | `presence_records` | `pr1` (`childId` vinculado) | `resp1` | get | **Permitido** |
| Ler presença de outra criança (responsável) | `presence_records` | `pr2` | `resp1` | get | **Negado** |
| Criar answer (cuidador) | `…/answers` | `a1` | `cui1` | create | **Permitido** |
| Criar answer (responsável) | `…/answers` | `a1` | `resp1` | create | **Negado** |
| Ler formulário (cuidador) | `form_questions` | — | `cui1` | get / list | **Permitido** |
| Ler formulário (responsável) | `form_questions` | — | `resp1` | get | **Negado** |
| Criar pergunta (gestão) | `form_questions` | `fq1` | `mgr1` | create | **Permitido** |
| Criar pergunta (cuidador) | `form_questions` | `fq1` | `cui1` | create | **Negado** |
| Apagar pergunta | `form_questions` | `fq1` | `adm1` (admin) | delete | **Negado** |
| Ler mural liberado (responsável) | `mural_posts` | `mp1` (`releasedAt`≤now) | `resp1` | get | **Permitido** |
| Ler mural pré-liberação (responsável) | `mural_posts` | `mp2` (`releasedAt`>now) | `resp1` | get | **Negado** |
| Ler mural pré-liberação (gestão) | `mural_posts` | `mp2` | `mgr1` | get | **Permitido** |
| Criar mural (gestão) | `mural_posts` | `mp1` | `mgr1` | create | **Permitido** |
| Criar mural (cuidador) | `mural_posts` | `mp1` | `cui1` | create | **Negado** |
| Ler notification própria | `notifications` | `n1` (`userId`=`resp1`) | `resp1` | get | **Permitido** |
| Ler notification alheia | `notifications` | `n2` (`userId`=`outro`) | `resp1` | get | **Negado** |
| Ler broadcast | `notifications` | `n3` (sem `userId`) | `resp1` | get | **Permitido** |
| Criar notification (gestão) | `notifications` | `n1` | `mgr1` | create | **Permitido** |
| Criar notification (cuidador) | `notifications` | `n1` | `cui1` | create | **Negado** |
| fcm_token dono | `fcm_tokens` | `t1` (`uid`=`u1`) | `u1` | create / get | **Permitido** |
| fcm_token alheio | `fcm_tokens` | `t1` | `u2` | get | **Negado** |
| levels read (cuidador) | `levels` | — | `cui1` | get | **Permitido** |
| levels write (cuidador) | `levels` | `l1` | `cui1` | create | **Negado** |
| levels write (gestão) | `levels` | `l1` | `mgr1` | create | **Permitido** |
| mural_reads próprio | `mural_reads` | `r1` (`uid`=`resp1`) | `resp1` | create / get | **Permitido** |
| mural_reads lista (gestão) | `mural_reads` | — | `mgr1` | list | **Permitido** |
| Sem auth (formulário/mural) | `form_questions` / `mural_posts` | — | *(nenhum)* | get | **Negado** |

Passos no playground:

1. Publique ou cole o conteúdo de `firestore.rules`.
2. Em **Authentication**, defina `request.auth.uid` e garanta `user_roles/{uid}` com o papel desejado.
3. Simule os cenários da tabela.

## Bootstrap do primeiro admin

O primeiro administrador ainda precisa ser promovido **uma vez** pelo console. Depois, gestão/admin promovem pela tela **Usuários**. Ver [`credentials.md`](credentials.md#bootstrap-do-primeiro-admin).
