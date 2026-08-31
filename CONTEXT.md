# Conecta Creche

Canal móvel entre a rotina diária da creche (crianças 1–5) e a operação da equipe; presença e parecer do dia são o núcleo operacional do cuidador.

## Language

**Criança**:
Pessoa atendida na creche, identificada neste produto só por nome (ou apelido). Pode estar ativa ou inativa.
_Avoid_: Aluno, estudante, perfil completo

**Registro de presença**:
Uma visita da criança à creche (chegada, saída opcional enquanto aberta, parecer na saída). No mesmo dia civil pode haver vários registros da mesma criança; nova chegada só é bloqueada se já existir um registro **aberto** naquele dia.
_Avoid_: Frequência, um-único-por-dia, check-in genérico

**Registro aberto**:
Registro de presença com chegada e sem saída. À virada do dia não entra no fluxo de correção do cuidador; a criança pode ter nova chegada no dia seguinte.
_Avoid_: Pendência obrigatória, bloqueio entre dias

**Chegada**:
Momento em que a criança entra na creche; gravado como datahora no ato. Fora do admin, imutável depois de criado.
_Avoid_: Check-in editável

**Saída**:
Momento em que a criança deixa a creche; gravado como datahora no ato. Fora do admin, imutável depois de criado.
_Avoid_: Check-out editável

**Parecer**:
Conjunto fixo de respostas rápidas sobre o período da visita, preenchido na saída; editável depois (com auditoria). Perguntas v1: Chorou?, Comportamento?, Comeu?, Dormiu?, Evacuações?, Humor geral?. Na UI, cada pergunta é um **grupo de botões** (uma opção ativa; default pré-selecionado) — não dropdown/select.
_Avoid_: Formulário configurável, RF0008, `<select>` multi-passo

**Auditoria de registro**:
Quem criou e quando; quem editou por último e quando (ids de usuário + timestamps).
_Avoid_: Histórico completo de versões (por enquanto)

**Inativação de criança**:
Ação da gestão que marca a criança como não atendida mais na creche, sem apagar o histórico; some da lista operacional de presença.
_Avoid_: Hard delete de criança

**Filtro de presença (cuidador)**:
Chips exclusivos Presentes / Saíram / Todos; default Presentes.
_Avoid_: Multi-select na home do cuidador

**Filtro de presença (gestão, detalhe do dia)**:
Chips Presentes e Saíram com **multi-seleção**; nenhum selecionado mostra ambos; selecionados restringem a lista.
_Avoid_: Chip Todos; default com Presentes pré-selecionado

**Calendário da gestão**:
Semana e mês na ordem brasileira **domingo → sábado**; visão semanal em uma única linha.
_Avoid_: Semana começando na segunda; hint textual de gestos na UI

**Visão do cuidador**:
Começa no detalhe operacional do dia (lista filtrável; toque na criança → confirmação de chegada/saída). Cadastro pontual de criança na app bar; edição de catálogo em tela aparte.
_Avoid_: Dashboard semanal como home do cuidador; editar nome na lista de presença

**Gestão de crianças**:
Tela de catálogo (nome, inativar) separada da lista operacional de presença; atalho a partir da presença.
_Avoid_: CRUD inline na lista do dia

**Visão da gestão**:
Começa em visão agregada mobile (semana Dom–Sáb em uma linha; mês Dom–Sáb compacto). Navegação por gesto ←→ muda período; ↑ no mês aprofunda para semana — sem hint textual na UI. Dia selecionado embute a lista operacional abaixo (chips multi Presentes/Saíram), com aviso se houver abertos.
_Avoid_: Mesma home do cuidador; grade desktop larga; texto explicando gestos

**Cuidador+**:
Papéis com rank ≥ cuidador (`cuidador`, `gestao`, `admin`) com acesso à superfície de presença nesta fatia (com poderes distintos por papel). Helpers: `canOperatePresence`, `canInactivateChild`, `canAdminPresence`.
_Avoid_: Staff genérico
