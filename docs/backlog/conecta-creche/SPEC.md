# Conecta Creche — Week 1 foundation

## Problem Statement

Creches lack a centralized, real-time channel between the daily routine of children (ages 1–5) and their parents. Manual notes and phone calls create noise and uncertainty. The full product (see project requirements PDF) addresses presence, notices, reports, push, incidents, and more.

**This week** is not that product. The team needs course ops (Trello backlog import, Sistema de Extensão registration) and a safe technical foundation: per-developer Firebase, Google Sign-In, a minimal `users` model with roles, committed security rules, and a simple profile surface.

## Solution

Deliver a Flutter app skeleton wired to **each developer’s own Firebase project** (credentials never in version control), with:

- Google Sign-In (RF0007)
- Firestore `users/{uid}` created on first login as `convidado` until a gestor promotes the account (RF0006/RF0007)
- Security rules committed in-repo
- A user page to view/edit own profile (except email) and log out
- A `/wizard`-style bash script that guides Firebase console setup and writes config into the correct ignored paths
- A markdown packet for the university Sistema de Extensão form
- A Trello CSV import for **this week’s tasks only** (list name `Backlog`)

Product requirements remain in the software documentation PDF; Trello holds task-sized work (roughly 1–4 hours per card), not the RF text itself.

## User Stories

- Como integrante do time, quero um wizard de Firebase para criar meu próprio projeto e gravar credenciais nos caminhos locais corretos sem versioná-las.
- Como usuário novo, quero entrar com Google para ter conta imediata como `convidado`, sem acesso até ser vinculado/promovido.
- Como usuário autenticado, quero uma página de usuário em pt-BR para ver meus dados, corrigir o nome de exibição e sair (e-mail somente leitura).
- Como grupo, quero os RFs/RNFs do documento importados no Trello (lista Backlog, pt-BR) para o backlog do produto ficar rastreável.
- Como grupo, quero um pacote markdown em pt-BR do formulário de extensão com título, ODS, território e dados da cliente consistentes.

## Implementation Decisions

- **Roles:** `admin` | `gestao` | `cuidador` | `responsavel` | `convidado` (default on first Google login).
- **User document:** minimal fields from Google Auth (`uid`, `email`, `displayName`, photo URL if present) plus `role` and timestamps. No child links this week.
- **Credentials:** per-developer Firebase; files live outside VCS (`.gitignore` + `.cursorignore`). Example paths: `android/app/google-services.json`, `lib/firebase_options.dart`, `secrets/` as needed.
- **Admin promotion:** manual Firestore console edit this week (document the step); no allowlist/seed automation required.
- **Auth UX:** Google sign-in → role gate (`convidado` sees waiting/no-access) → user page for profile + logout. All user-visible strings in **pt-BR**.
- **Firestore rules:** versioned in the repo; at minimum enforce authenticated access to own `users/{uid}` document.
- **Locale:** App UI copy is **pt-BR**. Trello card names/descriptions and the Sistema de Extensão markdown packet are also **pt-BR**. Code identifiers may stay English.
- **Trello:** CSV import, list `Backlog`, no Members. Cards are a **1:1 mapping of RFs/RNFs** from the software documentation (nothing else). Labels distinguish `RF`/`RNF` and prioridade (`alta`/`media`/`baixa`).
- **Client / território (extensão):** EEI Creche Tia Edri, Anta Gorda–RS; responsável “Edriane” (surname/email TBD); public phone/address captured in the markdown packet (pt-BR).
- **Extensão defaults:** título `Conecta Creche`; programa `5 - Educação e Formação`; ODS `4 - Educação de Qualidade` (optional add `3 - Saúde e Bem-estar`); projeto de extensão selected in-portal when options are known.

## Testing Decisions

- Sign in with Google creates/upserts `users/{uid}` with `role: convidado`.
- Convidado cannot reach privileged shells; waiting/gate UI is shown.
- Profile edit updates allowed fields and refuses email changes in UI.
- Logout returns to sign-in.
- Security rules: user A cannot read/write user B’s document (verify in rules unit test or console simulator).
- Wizard run places config only under ignored paths; `git status` shows no secrets staged.

## Out of Scope

- RF0001–RF0005, RF0008–RF0009 product features (presence, mural, reports, push, incidents, feedback forms, children registry)
- Offline mode (RNF0001), FCM wiring, iOS-first delivery (Android is enough if only one platform is configured this week)
- Shared/team single Firebase project
- Automatic role promotion or child↔responsible linking
- Full-product task decomposition beyond the RF/RNF cards already imported to Trello
- Week-1 ops tasks (wizard, extensão submit, etc.) as Trello cards — those live only in the local orchestrate backlog

## Further Notes

- Team: Guilherme Delavi, Henrique Caron, Wesley A. Isotton (Lab Mobile — Monday).
- Source of truth for product RFs: `/w/tmp/Conecta Creche.pdf` (or a copy under the repo later).
- Existing `/w/conecta_creche` scaffold is not authoritative; this directory is the working project root.
- Trello CSV artifact: `.scratch/conecta-creche/trello-backlog.csv` (disposable import file).
