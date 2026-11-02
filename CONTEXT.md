# Conecta Creche

Canal móvel entre a rotina diária da creche (crianças 1–5) e a operação da equipe; presença, ocorrências no dia e mural são o núcleo operacional.

Requisitos técnicos por feature (locais, não versionados): `docs/requisitos/`.

## Language

**Criança**:
Pessoa atendida na creche, identificada neste produto só por nome (ou apelido). Pode estar ativa ou inativa.
_Avoid_: Aluno, estudante, perfil completo

**Registro de presença**:
Uma visita da criança à creche (chegada; ocorrências enquanto aberto; saída fecha o registro). No mesmo dia civil pode haver vários registros da mesma criança; nova chegada só é bloqueada se já existir um registro **aberto** naquele dia.
_Avoid_: Frequência, um-único-por-dia, check-in genérico

**Registro aberto**:
Registro de presença com chegada e sem saída. Aceita novas respostas/ocorrências. À virada do dia não entra no fluxo de correção do cuidador; a criança pode ter nova chegada no dia seguinte.
_Avoid_: Pendência obrigatória, bloqueio entre dias

**Registro fechado**:
Após a saída: somente leitura operacional (sem novas respostas de rotina). Edições pontuais podem existir dentro da janela de 24h da resposta.
_Avoid_: Reabrir livremente pelo cuidador

**Chegada**:
Momento em que a criança entra na creche; gravado como datahora no ato. Fora do admin, imutável depois de criado.
_Avoid_: Check-in editável

**Saída**:
Momento em que a criança deixa a creche; gravado como datahora no ato; fecha o registro. Fora do admin, imutável depois de criado (salvo política de janela/admin).
_Avoid_: Check-out editável pelo cuidador sem form

**Resposta (answer)**:
Objeto persistido com snapshot da pergunta, valor e metadados (opcional, incidente, fase durante_dia|saida, auditoria, edições). Histórico não depende do template atual.
_Avoid_: Só enum solto sem snapshot

**Incidente**:
Ocorrência importante (ex. saúde) registrada como resposta com flag de incidente; entra em visão global da gestão e na ciência da família (relatórios/mural; FCM depois).
_Avoid_: Canal paralelo sem vínculo ao registro/dia

**Formulário configurável**:
Lista única de perguntas da gestão (flags de visibilidade/opcional/incidente, ordem drag-and-drop); cuidador preenche via filtros de contexto.
_Avoid_: Dois CRUDs separados saída vs incidente; `<select>` multi-passo

**Parecer**:
Nome legado da fatia v1 (perguntas fixas na saída). Evolui para respostas do formulário configurável na saída.
_Avoid_: Tratar parecer v1 como contrato eterno

**Auditoria de registro**:
Quem criou e quando; quem editou por último e quando (ids de usuário + timestamps). Edição de respostas: janela de 24h atualizando `updatedBy`/`updatedAt`.
_Avoid_: Histórico completo de versões (por enquanto)

**Inativação de criança**:
Ação da gestão que marca a criança como não atendida mais na creche, sem apagar o histórico; some da lista operacional de presença.
_Avoid_: Hard delete de criança

**Vínculo criança↔responsável**:
Associação n–n; responsável só acessa dados das crianças vinculadas. Editável na criança e no usuário responsável (gestão+).
_Avoid_: Conta familiar compartilhada sem uid

**Mural**:
Timeline por **efetividade** (`effectiveAt`; default copia `releasedAt`). Itens liberados após `releasedAt`; formatos compacto/expandido; feed pode misturar posts, notificações registradas, presenças/incidentes relevantes. Expandir detalhe registra leitura em `mural_reads` (`channel` mural|notification); gestão vê contagem simples de lidos.
_Avoid_: Feed só por createdAt; pin manual na v1

**Liberação / efetividade**:
Liberação = fica visível; efetividade = âncora na timeline. Imediato ⇒ ambas iguais.
_Avoid_: Visível antes da liberação

**Filtro de presença (cuidador)**:
Chips exclusivos Presentes / Saíram / Todos; default Presentes.
_Avoid_: Multi-select na home do cuidador

**Filtro de presença (gestão, detalhe do dia)**:
Chips Presentes e Saíram com **multi-seleção**; nenhum selecionado mostra ambos; selecionados restringem a lista.
_Avoid_: Chip Todos; default com Presentes pré-selecionado

**Calendário da gestão**:
Semana e mês na ordem brasileira **domingo → sábado**; visão semanal em uma única linha.
_Avoid_: Semana começando na segunda; hint textual de gestos na UI

**Shell / tabs**:
Navegação inferior por módulos; default = foco do perfil; Menu do usuário = conta + sitemap (inclui destinos que já são tabs).
_Avoid_: Home única sem módulos

**Visão do cuidador**:
Tab Presença no detalhe do dia (lista filtrável; chegada / ocorrência / saída). Cadastro pontual de criança; catálogo em tela aparte.
_Avoid_: Dashboard semanal como home do cuidador

**Gestão de crianças**:
Tela de catálogo (nome, inativar, vínculos, nível/turma opcionais) separada da lista operacional de presença.
_Avoid_: CRUD inline na lista do dia

**Nível**:
Rótulo institucional de agrupamento etário/pedagógico (`levels/{id}`: nome, ordem, ativo). Opcional na ficha da criança (`levelId`); sem nível a presença segue normal.
_Avoid_: Faixa etária rígida obrigatória; hard delete

**Turma**:
Oferta no ano letivo (`classes/{id}`: ano, níveis, sala como texto opcional, cuidadores, crianças). Vínculo atual na criança via `classId` opcional; sem turma a presença segue normal.
_Avoid_: Grade horária; histórico completo de transferências na v1

**Visão da gestão**:
Tab Incidentes (global) + tab Presença agregada (semana/mês Dom–Sáb). Menu para Usuários, Formulários, Níveis, Turmas, etc.
_Avoid_: Mesma home do cuidador sem incidentes

**Relatórios do responsável**:
UI interativa macro→micro (bem-estar, o que ocorreu, mediana chegada/saída e outliers) só das crianças vinculadas.
_Avoid_: Dump tabular cru como tela principal

**Cuidador+**:
Papéis com rank ≥ cuidador (`cuidador`, `gestao`, `admin`) com acesso à operação de presença (poderes distintos por papel).
_Avoid_: Staff genérico
