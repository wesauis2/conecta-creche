# Registro de presença

## Problem Statement

A creche precisa registrar chegada, saída e parecer do dia de cada criança de forma rápida no celular. A week-1 entregou só autenticação e papéis; sem catálogo de crianças nem presença, a rotina operacional não existe no app.

## Solution

Entregar no Flutter + Firestore:

- Catálogo `children` (nome, ativa/inativa) e registros `presence_records` (chegada, saída, parecer fixo, auditoria, `dayKey` civil em `America/Sao_Paulo`)
- UI do **cuidador**: detalhe do dia (chips Presentes/Saíram/Todos), toque → confirmação, parecer em grupos de botões; Nova criança na app bar; catálogo **Crianças** separado
- UI da **gestão/admin**: agregado semana/mês (Dom→Sáb), dia selecionado com lista embutida (chips multi), aviso de abertos
- Rules e helpers alinhados à matriz de papéis (`canOperatePresence`, `canInactivateChild`, `canAdminPresence`)

Referência visual: `.scratch/registro-presenca/prototypes/`. Decisões: `.scratch/registro-presenca/PLAN.md` e `decisions/`.

## User Stories

- Como **cuidador**, quero ver presentes/saíram/todos no dia, tocar na criança, confirmar chegada ou saída e preencher o parecer com botões, para a rotina ser rápida.
- Como **cuidador**, quero criar uma criança só com nome pela app bar e editar nomes na tela Crianças, sem misturar CRUD com a lista do dia.
- Como **gestão**, quero navegar semana/mês (Dom–Sáb), selecionar um dia e ver presentes/saíram (multi-chip; nenhum = ambos), com aviso se houver registros abertos.
- Como **gestão**, quero inativar uma criança no catálogo para ela sumir da operação do dia.
- Como **admin**, quero editar datahora de chegada/saída e apagar um registro (hard delete) quando precisar corrigir.
- Como **responsável** ou **convidado**, não acesso estas superfícies neste plano.

## Implementation Decisions

- Coleções: `children/{id}`, `presence_records/{id}` (ids em inglês, como `users`).
- Criança: `name`, `active`, `createdAt`/`updatedAt` (serverTimestamp), `createdBy`/`updatedBy`. Sem hard delete.
- Presença: `childId`, `dayKey` (`YYYY-MM-DD` SP), `arrivedAt`/`departedAt` (Timestamp; `departedAt: null` na criação), `isOpen`, `parecer` map (`chorou`, `comportamento`, `comeu`, `dormiu`, `evacuacoes`, `humor`) ou null, auditoria create/update.
- “Agora” operacional: Timestamp do mesmo `TZDateTime` SP que gera `dayKey`; audit com `serverTimestamp`.
- Vários registros/dia; bloqueio de nova chegada só se `childId+dayKey+isOpen==true` (transaction).
- Admin: pode alterar `arrivedAt`/`departedAt` (recalcula `dayKey`/`isOpen`) e hard-delete do doc; demais papéis não.
- Índices compostos: `dayKey+isOpen+arrivedAt`, `dayKey+isOpen+departedAt`; range gestão em `dayKey`.
- Parecer UI: button groups com default, não `<select>`.
- Inativar só na tela Crianças. Cuidador não lista inativas.
- Home: cuidador → detalhe do dia; gestão/admin → agregado.

## Testing Decisions

- Nova chegada falha (ou é recusada) se já existe registro aberto no mesmo `dayKey` para a criança.
- Chips cuidador exclusivos (default Presentes); gestão multi (nenhum selecionado = presentes+saíram).
- Rules: responsável/convidado sem read/write em `children`/`presence_records`; não-admin não altera timestamps nem delete; não-gestão não inativa.
- `dayKey` coerente com fuso SP na virada do dia.
- Admin consegue editar horários e apagar; UI esconde essas ações para outros.

## Out of Scope

- Formulário configurável (RF0008), turmas, offline (RNF0001), push (RF0004), mural, incidentes, relatórios de produto além do agregado de presença.
- Visão do responsável / vínculo n–n criança↔responsável.
- Correção operacional de dias anteriores pelo cuidador.
- Hard delete de criança; Cloud Functions / custom claims; iOS-first.

## Further Notes

- Glossário: `CONTEXT.md`. Research de dia civil: `.scratch/registro-presenca/research/dia-civil-firestore.md`.
- Parecer v1 (opções/defaults): Chorou? Não/Um pouco/Muito (Não); Comportamento? Tranquilo/Agitado/Precisou de atenção (Tranquilo); Comeu? Bem/Parcial/Pouco/Não (Bem); Dormiu? Sim/Cochilou/Não (Cochilou); Evacuações? Normal/Não fez/Atenção (Normal); Humor? Contente/Neutro/Irritado (Contente).
