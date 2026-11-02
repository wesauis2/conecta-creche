# Regras Firestore

Regras versionadas em [`firestore.rules`](../firestore.rules). Índices em [`firestore.indexes.json`](../firestore.indexes.json).

## Coleções cobertas (leva)

| Coleção | Leva (lab) | Intenção final (endurecer depois) |
|---------|------------|-----------------------------------|
| `users/{uid}` | dono edita perfil (sem `role`); gestão+ lista | igual |
| `user_roles/{uid}` | create self=`convidado`; update gestão+ com hierarquia | igual |
| `children/{id}` | **read** `signedIn()`; **write** Cuidador+ (inclui `responsibleUids`); só gestão+ `active` | read Cuidador+ **ou** uid ∈ `responsibleUids`; write vínculos/`active` só gestão+ |
| `presence_records/{id}` | **read** `signedIn()`; create/close/parecer Cuidador+; admin corrige/apaga | read Cuidador+ **ou** responsável vinculado à criança; writes iguais |
| `presence_records/{id}/answers/{id}` | **read/write** `signedIn()`; sem hard delete | mesmos leitores do registro; write Cuidador+ (janela 24h no app) |
| `form_questions/{id}` | **read/write** `signedIn()`; sem hard delete | read Cuidador+; write gestão+ |
| `mural_posts/{id}` | **read/write** `signedIn()`; sem hard delete | read rank ≥ responsável + `releasedAt`; write gestão+ |
| `notifications/{id}` | **read/write** `signedIn()`; sem hard delete | destinatário (+ broadcast); write gestão+ |
| `mural_reads/{id}` | **read/write** `signedIn()`; sem hard delete | dono (próprio uid) create/update; gestão+ lista agregados |

Hierarquia (rank): `admin` (4) > `gestao` (3) > `cuidador` (2) > `responsavel` (1) > `convidado` (0). Helpers `isCaregiverPlus()` / `isGestaoPlus()` / `isAdmin()` espelham `lib/users/user_role.dart`. Matriz comentada no topo de `firestore.rules`.

**Vínculos:** campo `children.responsibleUids` (array). Query do responsável: `array-contains` (índice single-field automático). Sem coleção `child_responsibles` na v1.

## Checklist — publish manual (fim da leva)

**Não há deploy automático.** Publique só quando a equipe decidir endurecer/propagar o arquivo do repo.

1. **Pré-checagem local**
   - [ ] `git status` limpo no commit que contém `firestore.rules` / `firestore.indexes.json`
   - [ ] Diff revisado: nenhuma regra “nega tudo” por acidente nas coleções novas
   - [ ] `flutter test` passou no branch

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
   - [ ] Login cuidador: chegada → ocorrência (answer) → saída
   - [ ] Login gestão: editar `responsibleUids`, publicar mural, ver incidentes
   - [ ] Login responsável: listar crianças vinculadas + relatórios / feed
   - [ ] Sem auth: leituras negadas no playground

6. **Rollback rápido (se precisar)**
   - [ ] Restaurar `firestore.rules` do commit anterior e `firebase deploy --only firestore:rules`
   - [ ] Índices compostos não se “desfazem” com rollback de rules; remova no console só se necessário

### Índices compostos versionados

Em [`firestore.indexes.json`](../firestore.indexes.json) (`firebase.json` → `firestore.indexes`):

| Coleção | Campos | Uso |
|---------|--------|-----|
| `presence_records` | `dayKey`, `isOpen`, `arrivedAt` | gestão: dia + Presentes/Saíram ordenado por chegada |
| `presence_records` | `dayKey`, `isOpen`, `departedAt` | gestão: dia + Saíram ordenado por saída |
| `presence_records` | `childId`, `dayKey`, `isOpen` | open-guard / “já tem registro aberto hoje?” |

Single-field (automáticos): `children.responsibleUids` (`array-contains`), `children.active`, `form_questions.active`, `presence_records.childId`, etc. Mural/notifications ordenam no client — sem composto obrigatório na v1.

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
| Criar criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | create `{name, active:true, createdBy:'cui1', updatedBy:'cui1', ...}` | **Permitido** |
| Renomear criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{name}` | **Permitido** |
| Vincular responsável (leva) | `children` | `child1` | `cui1` (cuidador) | update `{responsibleUids:['resp1']}` | **Permitido** (leva; final = gestão+) |
| Inativar criança (cuidador) | `children` | `child1` | `cui1` (cuidador) | update `{active:false}` | **Negado** |
| Inativar criança (gestão) | `children` | `child1` | `mgr1` (gestao) | update `{active:false}` | **Permitido** |
| Ler catálogo (responsável, leva) | `children` | — | `resp1` (responsavel) | get / list | **Permitido** (leva; final = só vinculados) |
| Apagar criança (admin) | `children` | `child1` | `adm1` (admin) | delete | **Negado** (sem hard delete) |
| Registrar chegada (cuidador) | `presence_records` | `pr1` | `cui1` (cuidador) | create `{childId, dayKey, arrivedAt, departedAt:null, isOpen:true, createdBy:'cui1', updatedBy:'cui1'}` | **Permitido** |
| Registrar saída+parecer (cuidador) | `presence_records` | `pr1` (aberto) | `cui1` (cuidador) | update `{departedAt, isOpen:false, parecer}` | **Permitido** |
| Editar parecer depois (cuidador) | `presence_records` | `pr1` (fechado) | `cui1` (cuidador) | update `{parecer}` | **Permitido** |
| Alterar `arrivedAt` (cuidador) | `presence_records` | `pr1` | `cui1` (cuidador) | update `{arrivedAt}` | **Negado** |
| Reabrir `departedAt` (cuidador) | `presence_records` | `pr1` (fechado) | `cui1` (cuidador) | update `{departedAt: outro valor}` | **Negado** |
| Alterar timestamps (admin) | `presence_records` | `pr1` | `adm1` (admin) | update `{arrivedAt, dayKey, isOpen}` | **Permitido** |
| Apagar registro (admin) | `presence_records` | `pr1` | `adm1` (admin) | delete | **Permitido** |
| Apagar registro (gestão) | `presence_records` | `pr1` | `mgr1` (gestao) | delete | **Negado** |
| Ler presença (responsável, leva) | `presence_records` | — | `resp1` (responsavel) | get / list | **Permitido** (leva) |
| Criar answer (signed-in, leva) | `…/answers` | `a1` | `cui1` | create | **Permitido** |
| Ler formulário (signed-in, leva) | `form_questions` | — | `cui1` (cuidador) | get / list | **Permitido** |
| Criar pergunta (signed-in, leva) | `form_questions` | `fq1` | `mgr1` (gestao) | create | **Permitido** |
| Apagar pergunta | `form_questions` | `fq1` | `adm1` (admin) | delete | **Negado** |
| Ler/criar mural (signed-in, leva) | `mural_posts` | `mp1` | `mgr1` | get / create | **Permitido** |
| Ler/criar notification (leva) | `notifications` | `n1` | `mgr1` | get / create | **Permitido** |
| Registrar leitura (leva) | `mural_reads` | `mr1` | `resp1` | create | **Permitido** |
| Sem auth (formulário/mural) | `form_questions` / `mural_posts` | — | *(nenhum)* | get | **Negado** |

Passos no playground:

1. Publique ou cole o conteúdo de `firestore.rules`.
2. Em **Authentication**, defina `request.auth.uid` e garanta `user_roles/{uid}` com o papel desejado.
3. Simule os cenários da tabela.

## Bootstrap do primeiro admin

O primeiro administrador ainda precisa ser promovido **uma vez** pelo console. Depois, gestão/admin promovem pela tela **Usuários**. Ver [`credentials.md`](credentials.md#bootstrap-do-primeiro-admin).
