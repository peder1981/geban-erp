# GEBAN — ERP República das Bananas (Bananias) — Documentação Técnica

> **Autor:** Peder Munksgaard · **Data:** 23/09/2026 · **Idioma:** PT-BR
> **Fontes primárias:** `src/*.prw` (38 arquivos), `documentacao interna`,
> `documentacao interna`.
> **Evidência de build:** a contagem "84 ok / 46 PASS, 0 FAIL" publicada originalmente aqui é da
> era SQLite (23/09/2026, ver seção 8) e não vale mais — a suite foi migrada para Postgres e
> cresceu desde então, com arquivos em estados diferentes (PASS, FAIL conhecido, bloqueio de
> arquitetura). Status atual por teste: ledgers SDD de cada plano (`registro interno`) e seção
> `## Pendências` de `documentacao interna` (testes ainda em
> FAIL/bloqueados). `advplc serve src/GEBTUI.prw` → interface web no ar (porta 8081).
> Sem mocks: todo comportamento abaixo foi lido dos fontes e executado no AdvPP.

---

## 1. Arquitetura

Monolito modular **AdvPL** (`.prw`, CP-1252, `#include "totvs.ch"` único, só `User`/`Static Function`)
sobre **Postgres multi-tenant**, validado pelo compilador/runtime **AdvPP** (`advplc check/run/serve/build`).
A conexão (`GEBDBConecta()`, `src/GEBDB_TENANT.prw`) lê `GEBAN_PG_HOST`, `GEBAN_PG_PORT`,
`GEBAN_PG_DB`, `GEBAN_PG_USER` e `GEBAN_PG_PASSWORD` do ambiente — não há mais `geban.db`
(SQLite) nem flag `--db-path`.

- **Modelo multi-tenant:** um schema Postgres por empresa (`emp_<código em minúsculas>`) para
  as tabelas de módulo (`GF*`, `GD*`, `GC*`, `GV*`, `GFN*`, `GCP*`, `GEI`, `GEH`, `GEX`, ...).
  O catálogo compartilhado entre todas as empresas vive no schema `public`: `GE1` (empresas),
  `GE2` (usuários), `GE2_SEC` (credenciais/hash de senha), `GE2_TOK` (tokens), `GE2_EMP`
  (vínculo usuário↔empresa, many-to-many — substitui a antiga coluna `GE2_EMPRESA`), `SEC_PERM`,
  `SEC_ADMIN_SESSION`. `GEBDBProvisionaCatalogo()` garante o catálogo; `GEBDBProvisionaEmpresa()`
  provisiona o schema de uma empresa nova.
- **Entrada:** `advplc serve src/GEBTUI.prw` → `User Function GEBTUI()` roda, nesta ordem:
  (1) `GEBDBConecta()`; (2) `GEBDBProvisionaCatalogo()` (catálogo + `GEBSECBOOT()`, que cria o
  `super` numa instalação nova); (3) tela de login → `GEBSECLOGIN()` (Argon2id contra `GE2_SEC`,
  recusa genérica para não virar oráculo de enumeração de usuário; troca obrigatória/expirada antes
  de seguir); (4) empresa (vínculo em `GE2_EMP`) e filial; (5) `GEBDBSetTenant()`, depois
  `GBAUDINIC()`/`GEBMONINIC()` (auditoria/monitor por-tenant) e `GEBEXPCONTEXTO()` (contexto de
  sessão); (6) monta o menu e as páginas (capítulo 4.1). Outras entradas: `src/GEBWEB.prw` (API
  REST, porta 8090) e `src/GEBSCHJOB.prw` (agendador).
- **Decomposição em 7 sub-projetos** (ordem de construção): `GEB_NUCLEO` → `GEB_FISCAL` →
  `GEB_DERRAMA` → `GEB_ESTOQ_VENDA` → `GEB_CONTABIL` → `GEB_FIN` → `GEB_COM`.
- **Auditoria/contexto por-tenant** (`GEBEXP_CTX`, `src/GEBEXP_CTX.prw`; `GEBEXPCriaAuditoria()`,
  `src/GEBEXP_MIG.prw`): `GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)` valida usuário em GE2
  (catálogo) e vínculo em `GE2_EMP`, grava entrada em `GEH` e armazena em `GEX` (contexto
  temporário, dentro do schema do tenant já selecionado); `GEBEXPIST()` verifica sessão ativa;
  `GEBEXPCONTEXT()` retorna `{empresa, filial, usuario}`; `GEBEXPCLEAR()` encerra sessão.
  `GEBEXPCriaAuditoria()` cria `GEH`/`GEI` dentro do schema do tenant corrente; **não existe mais**
  uma função `GEBEXPmig()`/bootstrap que adicione coluna `EMPRESA` a tabelas compartilhadas — o
  isolamento é por schema, não por coluna.
- **Decomposição em 7 sub-projetos + 2 novas camadas** (ordem de construção): `GEB_NUCLEO` → `GEB_FISCAL` →
  `GEB_DERRAMA` → `GEB_ESTOQ_VENDA` → `GEB_CONTABIL` → `GEB_FIN` → `GEB_COM` → `GEB_EXPANSAO` → `GEB_GUI`.
- **Regras globais aplicadas em todos os fontes:** toda tabela tem `<TAB>_FILIAL` + `D_E_L_E_T_`
  (soft-delete, `' '` ativo / `'*'` baixado); `GetArea()`/`RestArea()` guardados em torno de DB;
  `RecLock()` + `MsUnlock()`; escrita via `DbAppend()` + `RecLock(.T.)`; leitura via workarea
  (`DbSelectArea`/`DbGoTop`/scan/`DbSkip`); guardas de existência via `GEBDBTableExists()`/
  `GEBDBTableExistsHere()` (`src/GEBDB_CORE.prw`, sobre `pg_tables`/`information_schema` do
  Postgres); sem `IIF()`, sem `Function` bare, sem `SELECT *`, sem concatenar SQL,
  sem variável `cFilial`, sem UI em transação, sem `Recover` vazio.
- **Fluxos configuráveis via GE4/Mentor B padrão** (ver §5): `EMISSAO` =
  `ONLINE_PURO` | `ONLINE_FILA` (padrão) | `SO_FILA`; `APURACAO` = `AUTO` (padrão) |
  `MANUAL` | `DIRETA`; Mentor por evento = `AVISA_E_TRAVA` | `AVISA_E_LIBERA_COM_BO`
  (padrão B) | `DESLIGADO`. Botão "Assumo o B.O." grava GE3. Nenhum caminho pula
  `CTBLAN()` — muda só quem inicia.
- **MVP:** MEI emite NF-e/NFS-e com IBS/CBS e quita a derrama (DARF-CBS) sem multa;
  cobre Simples + Regular, com split, transferência/ressarcimento, parcelamento/protesto,
  operação mista online/fila offline (GE5).

---

## 2. Diagrama textual dos módulos

```
                        ┌─────────────┐
                        │ GEBTUI.prw  │  entrada: GEBTUI() (PoApp, PO-UI)
                        │  + GEBWEB   │  menu de módulos, formulários, Início
                        └──────┬──────┘
                               │ GENMIG()
               ┌───────────────┼────────────────┐
               ▼               ▼                ▼
   ┌──────────────────┐ ┌─────────────┐ ┌──────────────────┐
   │ GEB_NUCLEO       │ │ GEB_FISCAL  │ │ GEB_DERRAMA      │
   │ GENUC_MIG  GE1-5 │ │ GEBFIS_MIG  │ │ GEBDER_MIG GD1-3 │
   │ GENUC_CAD  GE1-3 │ │  GF1-GF6    │ │ GEBDER_GUI GD1   │
   │ GENUC_MNT  GE4/5 │ │ GEBFIS_CAD  │ │ GEBDER_COB GD1-3 │
   │  + CTB_Lanca real│ │ GEBFIS_EMI  │ │ GEBDER_BAI GD1   │
   │  (CTBLAN/CTBGRV) │ │ GEBFIS_APU  │ └────────┬─────────┘
   └────────┬─────────┘ └──────┬──────┘          │ GEBDGER() lê
             │  GEBMNT/GEBFILA/  │ GEBFEMI() grava saldo GF5 (guia GD+comp)
             │  GEBAUD/GEBUSR/   │ GF3/GF4 + CTBLAN
             │  CTBLAN usados    ▼
             │  por todos  ┌──────────────────┐ ┌──────────────────┐
             └────────────►│ GEB_ESTOQ_VENDA  │ │ GEB_CONTABIL     │
                           │ GEBV_MIG  GV1-3  │ │ GEBCTB_MIG GC1-4 │
                           │ GEBV_EST  GV1    │ │ GEBCTB_DIR direta│
                           │ GEBV_VEN  GV1/2  │ │ GEBCTB_BAL bal/  │
                           │ GEBV_FIA  GV3    │ │  DRE (lê GC2/3)  │
                           └────────┬─────────┘ └────────┬─────────┘
                                    │ GEBVEST usado      │ CTBLAN usado
                                    │ pela entrada       │ pela baixa
                                    ▼                    ▼
                           ┌──────────────────┐ ┌──────────────────┐
                            │ GEB_FIN          │ │ GEB_COM          │
                            │ GEBFIN_MIG GFN1-4│ │ GEBCOM_MIG GCP1-5│
                            │ GEBFIN_CON GFN2/3│ │ GEBCOM_FOR GCP1/2│
                            │ GEBFIN_BAI GFN2-4│ │ GEBCPX GCP3/4+GCQ │
                            │ GEBFIN_FLX GFN2/3│ │ GEBCPXENT GCP/GCQ │
                            └──────────────────┘ └──────────────────┘
                             │                    │
                             └────────┬───────────┘
                                      │
                              ┌───────▼────────┐
                              │ GEB_EXPANSAO   │
                              │ (multi-empresa)│
                              │ GEBEXP_MIG:    │
                              │  +EMPRESA em   │
                              │  28 tabelas    │
                              │  +GEH/GEI aud  │
                              │ GEBEXP_CTX:    │
                              │  contexto sess │
                              │ GEBEXP_REL_*:  │
                              │  relatorios +  │
                              │  trackers      │
                              └───────┬────────┘
                                      │
                              ┌───────▼────────┐
                              │ GEB_TUI        │
                              │ (interface)    │
                              │ GEBTUI:        │
                              │  login, menu,  │
                              │  formularios,  │
                              │  Inicio, rastro│
                              └────────────────┘
            PDV web: GEBWEB (API :8090) serve public/pdv.html
            com backend GEBPDV_API/GEBLOJ* (capítulo 4.1)
    Dependências reais (chamadas sem prefixo U_):
    GEBFEMI → GEBMNT + GEBCFG + GEBFPRO + GEBFALI + CALCIBS + GEBFILA + CTBLAN
    GEBFAPU → GEBCFG + GF3/GF4/GF5 + GE1(regime) · GEBDGER → GF5 saldo → GD1
    GEBDBAI → CTBLAN · GEBVVEN → GEBMNT + GV1/GV2 + GEBFEMI (se fiscal) ou CTBLAN
    GEBCDIR → GEBCFG + GEBUSR + GEBMNT + CTBGRV · CTBLAN/CTBGRV → GC2/GC3/GC4
    GEBFNPAG → GEBMNT("PAG_IMPULSIVO") · GEBFNBAI → GEBMNT("PAG_IMPULSIVO", só PAG) + GFN4/GFN1 + CTBLAN
    GEBCPXPED/GEBCPXGERA → GCP3/GCP4 + GCQ2 (alçada COM_ALCADA) · GEBCPXAPR → GCQ2 · GEBCPXENT → GCQ5 + GEBVEST + GEBFXTIT + CTBLAN
```
Ordem de dependência de migração: `GENMIG` (GE1–GE5) → `GEBFMIG` (GF1–GF6) →
`GEBDMIG` (GD1–GD3) → `GEBVMIG` (GV1–GV3) → `GEBCMIG` (GC1–GC4 + seeds) →
`GEBFNMIG` (GFN1–GFN4) → `GEBCMMIG` (GCP1–GCP5) → `GEBCPXMIG` (GCQ1–GCQ7).

---

## 3. Dicionário de dados

Todas as tabelas: `R_E_C_N_O_ INTEGER PRIMARY KEY AUTOINCREMENT` + `D_E_L_E_T_ TEXT DEFAULT ' '`
+ `<TAB>_FILIAL TEXT NOT NULL` + índice `(FILIAL, chave)`. Abaixo só as colunas de negócio
(extraídas dos `CREATE TABLE` em cada `*_MIG.prw`).

### 3.1 Núcleo — `src/GENUC_MIG.prw` (`GENMIG()`)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GE1 | `GE1_COD`, `GE1_NOME` | `GE1_FILIAL_COD` | Empresas. Convenção: `GE1_NOME == "SIMPLES"` ⇒ regime Simples (`src/GEBFIS_APU.prw` `RegimeGE1()`; GE1 não tem coluna de regime no DDL) |
| GE2 | `GE2_COD`, `GE2_NOME`, `GE2_PERFIL` | `GE2_FILIAL_COD` | Usuários. Perfil `CAIXA` só autoriza direta se `GEBCFG("PERMITE_DIRETA") == "S"` (`src/GENUC_CAD.prw` `GEBUSR()`) |
| GE3 | `GE3_COD`, `GE3_USUAR`, `GE3_EVENT`, `GE3_MOTIV`, `GE3_DATA` (DToS) | `GE3_FILIAL_COD` | Auditoria/B.O. — escrita real via `GEBAUD()` |
| GE4 | `GE4_EVENTO`, `GE4_MODO` | `GE4_FILIAL_EVE` | Regras do Mentor (`EMISSAO`, `APURACAO`, `PERMITE_DIRETA`, `LANC_DIRETO`, `VENDA_IMPULSIVA`, `ESTOQUE_MINIMO`, …). Leitura via `GEBCFG()` com scan sequencial FILIAL+EVENTO+`D_E_L_E_T_` (DbSetOrder não casa com a chave) |
| GE5 | `GE5_CHAVE`, `GE5_PAYLD`, `GE5_STATUS` (`PENDENTE`) | `GE5_FILIAL_CHA` | Fila offline — escrita real via `GEBFILA()` |

### 3.2 Fiscal — `src/GEBFIS_MIG.prw` (`GEBFMIG()`)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GF1 | `GF1_COD`, `GF1_NCM`, `GF1_DESC` | `GF1_FILIAL_COD` | Produto/serviço (NCM/NBS). Leitura via `GEBFPRO()` → `{COD, NCM, DESC}` ou `{}` |
| GF2 | `GF2_NCM`, `GF2_IBS REAL`, `GF2_CBS REAL`, `GF2_INI TEXT`, `GF2_FIM TEXT` (vigência `YYYYMMDD`) | `GF2_FILIAL_NCM` | Alíquotas IBS/CBS com vigência. Leitura via `ALIQF()`; última vigência válida vence; `{0,0}` se ausente |
| GF3 | `GF3_CHAVE`, `GF3_TIPO` (`NFE`), `GF3_STATUS` (`AUTORIZADA`/`EM_FILA`), `GF3_BASE/IBS/CBS REAL`, `GF3_EMIS` (DToS) | `GF3_FILIAL_CHA` | Header da NF. Escrita via `GrvGF3()` em `src/GEBFIS_EMI.prw` |
| GF4 | `GF4_CHAVE`, `GF4_ITEM` (`001`), `GF4_PROD`, `GF4_QTD/PRECO/BASE/IBS/CBS REAL` | `GF4_FILIAL_CHA` | Itens. Escrita via `GrvGF4()`; soma por competência em `SomaGF4()` |
| GF5 | `GF5_COMP` (`YYYYMM`), `GF5_DEB/CRED/SALDO REAL`, `GF5_REGIME` (`SIMPLES`/`REGULAR`) | `GF5_FILIAL_COM` | Apuração. `DEB = soma(IBS+CBS)` dos itens do mês, `CRED = 0`, `SALDO = DEB-CRED`. Idempotência por competência: baixa lógica prévia (`BaixaGF5()`) |
| GF6 | `GF6_COMP`, `GF6_ORIG`, `GF6_VALOR REAL`, `GF6_TIPO` (`TRANSF`/`RESSARC`) | `GF6_FILIAL_COM` | Créditos (transferência/ressarcimento). Escrita via `GEBFCRE()` |

### 3.3 Derrama — `src/GEBDER_MIG.prw` (`GEBDMIG()`)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GD1 | `GD1_GUIA`, `GD1_COMP`, `GD1_VALOR/JUROS/MULTA/TOTAL REAL`, `GD1_STATUS` (`ABERTA`/`PARCELADA`/`PROTESTADA`/`BAIXADA`) | `GD1_FILIAL_GUIA` | Guia DARF-CBS. `GUIA = "GD" + cComp`; idempotente (guia ativa existente retorna sem duplicar) |
| GD2 | `GD2_GUIA`, `GD2_PARC` (3 dígitos), `GD2_VALOR REAL`, `GD2_STATUS` | `GD2_FILIAL_GUIA` | Parcelas. Baixa lógica prévia + última parcela ajusta resíduo (soma exata) |
| GD3 | `GD3_GUIA`, `GD3_ACAO` (`PROTESTO`), `GD3_DATA`, `GD3_STATUS` | `GD3_FILIAL_GUIA` | Cobrança/protesto |

### 3.4 Estoque/Venda — `src/GEBV_MIG.prw` (`GEBVMIG()`)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GV1 | `GV1_PROD`, `GV1_SALDO REAL`, `GV1_MIN REAL` (padrão 10 em linha nova) | `GV1_FILIAL_PROD` | Saldo. `GEBVEST()` soma `nQtd` (positivo=entrada, negativo=saída); abaixo do mínimo chama `GEBMNT("ESTOQUE_MINIMO")` só como alerta |
| GV2 | `GV2_VENDA`, `GV2_PROD`, `GV2_QTD REAL`, `GV2_STATUS` (`VENDIDA`) | `GV2_FILIAL_VENDA` | Venda (item simplificado) |
| GV3 | `GV3_CLI`, `GV3_VALOR/JUROS/MULTA/TOTAL REAL`, `GV3_STATUS` (`ABERTA`) | `GV3_FILIAL_CLI` | Fiado. Limite: soma em aberto + novo ≤ 1000 (`SomaAberto()` usa `TOTAL`, ou `VALOR` se zerado) |

### 3.5 Contábil — `src/GEBCTB_MIG.prw` (`GEBCMIG()` + seeds idempotentes)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GC1 | `GC1_CONTA`, `GC1_NOME`, `GC1_TIPO` (`A`/`S`) | `GC1_FILIAL_CONTA` | Plano de contas. Seeds: `1.01.001` CAIXA, `2.01.001` FORNECEDORES, `3.01.001` RECEITA VENDAS, `4.01.001` CUSTO MERCADORIAS |
| GC2 | `GC2_LOTE` (`L<n>` sequencial), `GC2_ORIGEM`, `GC2_VALOR REAL`, `GC2_DATA` (`AAAAMMDD`), `GC2_COMP` (`AAAAMM`), `GC2_TIPO` (`AUTO`/`DIRETO`) | `GC2_FILIAL_LOTE` | Lote contábil |
| GC3 | `GC3_LOTE`, `GC3_DC` (`D`/`C`), `GC3_CONTA`, `GC3_VALOR REAL` | `GC3_FILIAL_LOTE` | Partida dobrada, uma linha por perna; conferência débito == crédito após gravar |
| GC4 | `GC4_EVENTO`, `GC4_CTADEB`, `GC4_CTACRED`, `GC4_PERM` (`S`/`N`) | `GC4_FILIAL_EVE` | Parâmetros por evento origem→contas. Seed: `PADRAO` (DEB `1.01.001` / CRED `3.01.001` / PERM `S`), fallback do `CTBLAN` |

### 3.6 Financeiro — `src/GEBFIN_MIG.prw` (`GEBFNMIG()` + `GEBFNCON()`)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GFN1 | `GFN1_CONTA`, `GFN1_NOME`, `GFN1_SALDO REAL` | `GFN1_FILIAL_CONTA` | Contas (caixa). Escrita via `GEBFNCON()` (`SALDO=0`, idempotente por conta) |
| GFN2 | `GFN2_DOC`, `GFN2_CLI`, `GFN2_VALOR/SALDO REAL`, `GFN2_VENC` (texto `YYYYMMDD`), `GFN2_STATUS` (`ABERTO`/`RECEBIDA`) | `GFN2_FILIAL_DOC` | Receber. `SALDO=VALOR` na criação; quitação zera e vira `RECEBIDA`, parcial mantém `ABERTO` |
| GFN3 | `GFN3_DOC`, `GFN3_FORN`, `GFN3_VALOR/SALDO REAL`, `GFN3_VENC`, `GFN3_STATUS` (`ABERTO`/`PAGA`) | `GFN3_FILIAL_DOC` | Pagar. Mesma máquina de `SALDO`/`STATUS` (`PAGA` no total); lançamento e baixa de PAG passam pelo Mentor `PAG_IMPULSIVO` |
| GFN4 | `GFN4_CONTA` (`CAIXA`), `GFN4_TIPO` (`REC`/`RECEBER`/`PAG`/`PAGAR`), `GFN4_VALOR REAL`, `GFN4_DATA` (DToS) | `GFN4_FILIAL_CONTA` | Movimento de caixa — 1 linha por baixa via `GravMOV()`; `REC` soma / `PAG` subtrai `GFN1 CAIXA` (se existir) |

### 3.7 Compras — `src/GEBCOM_MIG.prw` (`GEBCMMIG()`)

| Tab. | Campos | Índice | Uso |
|------|--------|--------|-----|
| GCP1 | `GCP1_COD`, `GCP1_NOME`, `GCP1_CNPJ` (vazio — `GEBCMFOR()` grava `""`) | `GCP1_FILIAL_COD` | Fornecedor. Idempotente por código (`GEBCMFOR()` retorna `.T.` sem duplicar) |
| GCP2 | `GCP2_FORN`, `GCP2_PROD`, `GCP2_PRECO REAL` | `GCP2_FILIAL_PROD` | Cotação. Múltiplas linhas por produto; menor preço via `GEBCMMEL()` (`0` se vazio/ausente) |
| GCP3 | `GCP3_NUM`, `GCP3_FORN`, `GCP3_STATUS` | `GCP3_FILIAL_NUM` | Pedido header. Criação via `GEBCPXPED()`/`GEBCPXGERA()` (`GEBCPX.prw`); status acompanha a entrada (`PARCIAL`/`RECEBIDO`) |
| GCP4 | `GCP4_PED`, `GCP4_PROD`, `GCP4_QTD/PRECO REAL` | `GCP4_FILIAL_PED` | Item do pedido. Escrita na criação do pedido (itens `{prod,qtd,preco}`) |
| GCP5 | `GCP5_NF`, `GCP5_PED`, `GCP5_STATUS` (`RECEBIDA`) | `GCP5_FILIAL_NF` | Entrada. Documento de NF via `GEBCPXENT()`; NF duplicada recusada |

Acesso em todos os módulos: `RetSqlName()` + `%notDel`/`%xfilial`/`%exp`, `TCSetField()` pós-query
(conforme spec §2); no runtime AdvPP leitura/escrita via workarea + `TCSqlExec`/`TCSqlQuery`
literais (ver §7 — gap BeginSql).

---

## 4. Interfaces (por arquivo, com assinatura real)

> Chamadas **sem prefixo `U_`** em todo o projeto: o runtime AdvPP só resolve `U_` em
> `StartJob`/`FindFunction`; chamada direta `U_X()` dá "unknown function"
> (documentado no Protheus.doc de cada fonte).

### 4.1 Interface — `src/GEBTUI.prw`

**Fontes:** `src/GEBTUI.prw` (aplicação, formulários e páginas),
`src/GEBTUIBO.prw` (DANFE da NFC-e), `src/GEBEXP_TRAK.prw` (rastreabilidade). Componentes PO-UI do
runtime AdvPP (`PoApp`, `PoMenu`, `PoPage`, `PoTabs`, `PoWidget`, `PoTable`, `PoChart`, `PoTree`...).
**Entrada:** `advplc serve src/GEBTUI.prw --port 8081` → `User Function GEBTUI()`; cada janela do
navegador é uma sessão (VM própria).

**Fluxo de entrada**
1. `TUILogin`: usuário e senha → `GEBSECLOGIN` (Argon2id, bloqueio após 5 erros; recusa genérica).
2. `TROCA_OBRIGATORIA`/`SENHA_EXP` → `TUISenhaPg` → `GEBTUITROCASENHA` (política `GEBSECPOL_VERIFICA`).
3. Empresa (`GEBTUIEMPRESAS`): uma só → automática; várias → escolha; catálogo vazio → o `super`
   cria a primeira (`TUIPrimeira`). Filial (`GEBTUIFILIAL`, "" = matriz).
4. `TUIAbre`: menu lateral só com os módulos em que o usuário tem ao menos um item permitido
   (`TUIPode`/RBAC), Início, Rastreabilidade, Minha senha e Sair.

**Páginas**
- **Início** (`TUIInicio`): sessão, indicadores (saldo em contas, títulos em aberto, guias da Derrama,
  estoque abaixo do mínimo), gráfico de saldo por conta e acesso rápido aos módulos.
- **Módulo** (`TUIModulos` → `TUIModPg`): tabelas do módulo em abas (`TUICarrega`: colunas lidas
  do `information_schema`, filtro `D_E_L_E_T_` e filial — exceto GE1/GE2 —, até 500 linhas, sem
  colunas de credencial (`TUISigilo`)); clicar numa linha preenche os campos ligados dos formulários.
  Abaixo, os formulários em abas pelo prefixo do título: Operações, Relatórios, Banco,
  NF-e de fornecedores, Simples Nacional e Documentos eletrônicos.
- **PDV embutido no TUI** (`GEBTUIPDV.prw`, módulo "Frente de loja"): a frente de caixa vive dentro do
  ERP, na mesma sessão e permissão LOJA — sem aba extra e sem segundo login. Abas: Venda, Caixa,
  Orçamentos, Devolução, Consultas, Cadastros, Relatórios e TEF/NFC-e. Chama direto as funções de
  negócio `GEBLOJ*`/`GEBCRY*`/`GEBTEF*` (as mesmas da API `/api/pdv/*`).
- **PDV web** (`public/pdv.html`, servido pelo GEBWEB em `/pdv`): mesma frente de caixa acessível por
  navegador dedicado, com login próprio — útil para totens/tablets fora do TUI.
- **Rastreabilidade** (`TUIRastreio`): origem + número → árvore com os registros de cada etapa (`GEBTRAK*`).
- **Resultado**: relatórios (`GBR1` ou a tabela do relatório) com botão Voltar (`GEBTUIBRW`).

**Formulários** (`TUIFormularios` = `TUIFormBase` + `TUIFormDfe` + `TUIFormNuc`, mais os do PDV):
cada operação é uma especificação `{módulo, 0, 0, título, campos, bloco, retorno, msg|tabela, permissão[, cálculo, itens]}`.
Campo: `{rótulo, "C" | "N" | "P" (senha) | {opções}, padrão[, coluna ligada]}`. `TUIExecuta`
confere a permissão (`GEBSECRBAC(usuário, menu, item)`) antes de chamar o bloco, que usa as mesmas
funções de negócio da API REST — a validação fica na regra de negócio, não na tela. Retorno `"BO"`
= `{lOk, cMsg}`; `"REL"` = relatório na página Resultado; `"201"`/`"200"` = status REST
(`GEBTUIMOTIVO` traduz a recusa). Operações com vários itens têm grade (`TUIFormItens`: incluir e
remover item; o bloco recebe os itens).

**Testes:** `T_GEBTUI_OPS` (executa todos os formulários com valores padrão + verificações
dirigidas), `T_GEBTUI_FLUXOS`, `T_GEBTUI_PERM`, `T_GEBTUIBO`, `T_GEBTUITROCA`, `T_GEBPDV_API`,
`T_GEBWEB_API`, `T_GEBWEB_OPS`; lints `tests/local/T_LOCAL_FUNCOES.sh` (função inexistente),
`T_NOMES_RESERVADOS.sh` (variável com nome de palavra-chave) e `T_LOCAL_APOS_RETURN.sh`, rodados
pelo `o script de publicacao` antes de publicar.

### 4.2 Núcleo — `src/GENUC_MIG.prw`, `src/GENUC_CAD.prw`, `src/GENUC_MNT.prw`

- `GENMIG()` → `.T.`/`.F.` — cria GE1–GE5 no schema corrente, idempotente (propaga `TCSqlExec`).
- `GEBCFG(cChave)` → modo do evento em GE4 ou `""` (GE4 ausente incluído).
- `GEBAUD(cUsuario, cEvento, cMotivo)` → `.T.` — trilha real em GE3 (filial + `D_E_L_E_T_`;
  `DbAppend()` **antes** de `RecLock("GE3", .T.)` — obrigatório em tabela vazia).
- `GEBUSR(cCodUser)` → `.T.` autorizado / `.F.` miss; `CAIXA` exige `PERMITE_DIRETA == "S"`.
- `GEBCAD()` → `.T.` — ponto de entrada dos cadastros; `CADMenu()` Empresas/Usuários/Auditoria
  (stubs `BrowseDef` futuro).
- `GEBMNT(cEvento)` → `.T.` liberado / `.F.` travado. `AVISA_E_TRAVA` ⇒ `.F.`;
  `AVISA_E_LIBERA_COM_BO` ⇒ grava GE3 via `GEBAUD` e libera; `DESLIGADO`/`""`/miss ⇒ `.T.` sem BO
  (miss sem BO evita trilhas espúrias — desvio documentado do default B do plano).
- `GEBFILA(cChave, cPayload)` → `.T.` enfileirado (`PENDENTE`) / `.F.` se GE5 ausente.
- `CTBLAN(cOrigem, nValor)` → partida dobrada **real**: param do evento em GC4 (fallback `PADRAO`),
  grava GC2 + 2×GC3 via `CTBGRV(..., "AUTO")`, confere débito == crédito; `.F.` se desbalancear,
  sem param ou valor ≤ 0. **Compat:** GC4 ausente ou sem params ⇒ stub antigo (`.T.`, só loga).
- `CTBGRV(cOrigem, cDeb, cCred, nValor, cTipo)` → lote (`"L<n>"`) ou `""` se falhar. Writer
  compartilhado (`CTBLAN` + `GEBCDIR`): GC2 + perna D + perna C + conferência das somas.

### 4.3 Fiscal — `src/GEBFIS_MIG.prw`, `src/GEBFIS_CAD.prw`, `src/GEBFIS_EMI.prw`, `src/GEBFIS_APU.prw`

- `GEBFMIG()` → `.T.`/`.F.` — GF1–GF6 idempotente.
- `CALCIBS(nBase, nAliqIBS, nAliqCBS)` → `{nIBS, nCBS}` (`base*aliq/100`).
- `ALIQF(cNCM, dData)` → `{IBS, CBS}` da vigência (`YYYYMMDD`, string ou Date via `DToS`);
  `{0,0}` se GF2 ausente/sem vigência.
- `GEBFPRO(cCod)` → `{COD, NCM, DESC}` ou `{}` (GF1 ausente/código inexistente).
- `GEBFALI(cNCM[, dData])` → delega a `ALIQF()` (sem dData usa hoje); `{IBS, CBS}`.
- `GEBFEMI(cChave, cCod, nQtd, nPreco)` → `"AUTORIZADA"` / `"EM_FILA"`. Intercept
  `GEBMNT("EMISSAO")`; modo `GEBCFG("EMISSAO")` (miss ⇒ `ONLINE_FILA`); produto+alíquotas
  (miss tributa a zero); mock SEFAZ autoriza se base > 0 (`SO_FILA` força fila); grava GF3+GF4;
  `AUTORIZADA` ⇒ `CTBLAN`; `EM_FILA` ⇒ `GEBFILA` (exceto `ONLINE_PURO` puro) + `CTBLAN`.
- `GEBFSPL(nTotal, nPartes)` → array de parcelas (última ajusta resíduo); `nPartes ≤ 0` ⇒ `{nTotal}`.
- `GEBFAPU(cComp)` → `.T.` apurado / `.F.` se GF3/GF4/GF5 ausentes. Soma GF4 do mês
  (`SubStr(GF3_EMIS,1,6)` via `GF3_CHAVE`), grava GF5 (`DEB=soma`, `CRED=0`, regime via GE1);
  modos `AUTO`/`MANUAL`/`DIRETA` gravam igual (chamada direta = ato manual), diferem só no log.
- `GEBFCRE(cComp, cOrig, nValor, cTipo)` → `.T.`/`.F.` — GF6 (`TRANSF` default/`RESSARC`).

### 4.4 Derrama — `src/GEBDER_MIG.prw`, `src/GEBDER_GUI.prw`, `src/GEBDER_COB.prw`, `src/GEBDER_BAI.prw`

- `GEBDMIG()` → `.T.`/`.F.` — GD1–GD3 idempotente.
- `GEBDGER(cComp)` → guia `"GD"+cComp` ou `""` (comp vazio, tabelas ausentes, sem saldo).
  Lê saldo ativo GF5, grava GD1 (`VALOR=TOTAL=saldo`, juros/multa 0, `ABERTA`).
- `GEBDJUR(cGuia, nDias)` → total. Juros banânicos **0,33%/dia com teto 20%** + **multa fixa 2%**
  sobre `VALOR`; grava `JUROS`/`MULTA`/`TOTAL`. `0` se guia vazia/inexistente/tabela ausente.
- `GEBDPAR(cGuia, nParc)` → `.T.`/`.F.` — parcela `TOTAL` (ou `VALOR` se zerado) em `nParc ≥ 2`
  linhas GD2 (baixa prévia, `PARC` 3 dígitos, última ajusta); marca GD1 `PARCELADA`.
- `GEBDPRO(cGuia)` → `.T.`/`.F.` — GD3 (`PROTESTO`, hoje, `ABERTA`) + GD1 `PROTESTADA`.
- `GEBDBAI(cGuia)` → `.T.`/`.F.` — GD1 `BAIXADA` + concilia via `CTBLAN(cGuia, nTotal)`.

### 4.5 Estoque/Venda — `src/GEBV_MIG.prw`, `src/GEBV_EST.prw`, `src/GEBV_VEN.prw`, `src/GEBV_FIA.prw`

- `GEBVMIG()` → `.T.`/`.F.` — GV1–GV3 idempotente.
- `GEBVEST(cProd, nQtd)` → novo saldo (`0` se produto vazio/GV1 ausente). Cria linha
  (`SALDO=nQtd`, `MIN=10`) se inexistente; alerta `ESTOQUE_MINIMO` sem travar.
- `GEBVVEN(cVenda, cProd, nQtd[, nPreco=10])` → `"VENDIDA"` / `"BLOQUEADA"` / `"SEM_ESTOQUE"`.
  Mentor `VENDA_IMPULSIVA` trava sem tocar o banco; confere GV1 (baixa + grava GV2);
  com fiscal (GF1+GF3+GF4) chama `GEBFEMI` (fiscal grava GF3/GF4 + CTB), senão `CTBLAN` direto —
  **uma única contabilização** em qualquer caminho.
- `GEBVFIA(cCli, nValor)` → `.T.` aberto (`ABERTA`) / `.F.` (limite 1000, guards).
- `GEBVJUR(cCli, nDias)` → soma dos totais. Mesma regra banânica (0,33%/dia, teto 20%, multa 2%)
  por linha `ABERTA` do cliente.

### 4.7 Financeiro — `src/GEBFIN_MIG.prw`, `src/GEBFIN_CON.prw`, `src/GEBFIN_BAI.prw`, `src/GEBFIN_FLX.prw`

- `GEBFNMIG()` → `.T.`/`.F.` — GFN1–GFN4 idempotente (propaga `TCSqlExec`).
- `GEBFNCON(cConta, cNome)` → `.T.`/`.F.` — conta GFN1 com `SALDO=0`; idempotente
  (existente retorna `.T.`); `.F.` se conta vazia ou GFN1 ausente.
- `GEBFNREC(cDoc, cCli, nValor[, dVenc])` → `.T.`/`.F.` — título a receber GFN2
  (`SALDO=VALOR`, `ABERTO`); `dVenc` string `YYYYMMDD` ou Date (via `DToS`);
  `.F.` se doc vazio, valor ≤ 0, GFN2 ausente ou DOC duplicado na filial.
- `GEBFNPAG(cDoc, cForn, nValor[, dVenc])` → `.T.`/`.F.` — título a pagar GFN3,
  mesmas regras; **antes** de tocar o banco passa pelo Mentor
  `GEBMNT("PAG_IMPULSIVO")` (travado ⇒ `.F.` sem gravar).
- `GEBFNBAI(cTipo, cDoc, nValor)` → `.T.`/`.F.` — baixa receber (`REC`/`RECEBER`
  em GFN2) ou pagar (`PAG`/`PAGAR` em GFN3): `SALDO` subtrai o valor (limitado ao
  saldo; pago a maior quita); zerado vira `RECEBIDA`/`PAGA`, parcial mantém `ABERTO`.
  Cada baixa grava 1 movimento GFN4 (`CAIXA`, `TIPO`, `VALOR`, hoje), atualiza
  `GFN1 CAIXA` (+REC/−PAG, se existir) e concilia via `CTBLAN(cDoc, nValor)`;
  baixa de PAG passa antes pelo Mentor `PAG_IMPULSIVO`. `.F.` se tipo inválido,
  doc vazio, valor ≤ 0, tabela ausente ou título inexistente.
- `GEBNFLX()` → `{nReceber, nPagar, nSaldo}` — soma dos `SALDOS` com `STATUS ABERTO`
  em GFN2/GFN3 (`nSaldo = receber−pagar`); tabelas ausentes valem zero; quitados
  (`RECEBIDA`/`PAGA`) fora da soma.

### 4.8 Compras — `src/GEBCOM_MIG.prw`, `src/GEBCOM_FOR.prw`, `src/GEBCPX.prw`

- `GEBCMMIG()` → `.T.`/`.F.` — GCP1–GCP5 idempotente.
- `GEBCMFOR(cCod, cNome)` → `.T.`/`.F.` — fornecedor GCP1 (`CNPJ=""`);
  idempotente; `.F.` se cód/nome vazio ou GCP1 ausente.
- `GEBCMCOT(cForn, cProd, nPreco)` → `.T.`/`.F.` — cotação GCP2;
  `.F.` se forn/prod vazio, preço ≤ 0 ou GCP2 ausente.
- `GEBCMMEL(cProd)` → menor `PRECO` em GCP2 na filial (`0` se vazio/ausente/sem cotação).
- `GEBCPXPED(cPed, cForn, aItens, cCond, cLocal, cData)` → `{lOk, msg, {cPed, nTotal, cLiberacao}}`
  — pedido direto: GCP3/GCP4 + GCQ2 (condição, local, emissão, total, liberação).
  `cPed` vazio gera `PC`+sequencial; total > `COM_ALCADA` ⇒ `GCQ2_LIB=PENDENTE`
  (entrada bloqueada até aprovação); senão `LIBERADO`.
- `GEBCPXSC(cNum, aItens, cSolic)` → solicitação de compra em GCQ1 (`ABERTA`).
- `GEBCPXGERA(cNumSC, cCond, cLocal, cData)` → um pedido por fornecedor pelo menor
  preço cotado (GCP2); item sem cotação recusa tudo; GCQ1 → `ATENDIDA`.
- `GEBCPXAPR(cPed, cUsuario, lAprova)` → `PENDENTE` ⇒ `LIBERADO`/`REJEITADO` + aprovador.
- `GEBCPXENT(cNF, cPed, aItens, nFrete, cData, aRet, cChaveNF)` → `{lOk, msg, {nTotal,
  cStatusPedido, aTitulos, nRetido}}` — entrada: estoque a custo de entrada (GCQ5,
  frete rateado) + `GEBVEST`, título via `GEBFXTIT` menos retenções (Derrama),
  `COMPRA_ESTOQUE`, crédito IBS/CBS (GCQ7), GCQ3 recebido por item, GCQ4 documento;
  pedido fica `PARCIAL`/`RECEBIDO`.
- `GEBCPXDEV(cNF, cForn, aItens, cData, cChaveForn)` → devolução de compra (GCQ6).
- `GEBCPXABERTOS()` / `GEBCPXPORFORN(cIni, cFim)` / `GEBCPXSCPEND()` → consultas.
- `GEBCPXMIG()` → `.T.`/`.F.` — GCQ1–GCQ7 idempotente.

### 4.6 Contábil — `src/GEBCTB_MIG.prw`, `src/GENUC_MNT.prw` (`CTBLAN`/`CTBGRV`), `src/GEBCTB_DIR.prw`, `src/GEBCTB_BAL.prw`

- `GEBCMIG()` → `.T.`/`.F.` — GC1–GC4 + seeds idempotentes (4 contas + `PADRAO`).
- `GEBCDIR(cContaD, cContaC, nValor[, cUser])` → `.T.` direto / `.F.` se qualquer trava negar,
  nesta ordem: (1) `GEBCFG("PERMITE_DIRETA") == "S"`; (2) `GEBUSR(cUser)` (miss nega);
  (3) GC4 `LANC_DIRETO` com `PERM N` nega (ausente libera); (4) `GEBMNT("LANC_DIRETO")`.
  Grava via `CTBGRV("DIRETO", ..., "DIRETO")` (carimbo).
- `GEBBAL(cComp)` → array `{conta, débito, crédito}` por conta, dos lotes GC2 com `GC2_COMP`.
  Competência vazia/contábil ausente ⇒ `{}`.
- `GEBDRE(cComp)` → resultado numérico: receitas (grupo `3`: crédito−débito) menos
  despesas/custos (grupo `4`: débito−crédito); `0` se vazio.

---

## 5. Fluxos ponta a ponta (com arquivos)

1. **Emissão MEI:** `GEBVVEN()` (`src/GEBV_VEN.prw`) → mentor → baixa GV1/GV2 →
   `GEBFEMI()` (`src/GEBFIS_EMI.prw`) → GF3/GF4 + `GEBFILA()` se fila + `CTBLAN()` (GC2/GC3).
2. **Apuração→derrama:** `GEBFAPU()` (GF5) → `GEBDGER()` (GD1 `ABERTA`) → `GEBDJUR()` /
   `GEBDPAR()` / `GEBDPRO()` (`src/GEBDER_COB.prw`) → `GEBDBAI()` + `CTBLAN()`.
3. **Venda com fiado:** `GEBVFIA()`/`GEBVJUR()` (`src/GEBV_FIA.prw`, limite 1000, juros banânicos).
4. **Direta optativa:** `GEBCDIR()` com 4 travas (flag + perfil + GC4 + mentor).
5. **Leituras:** `GEBBAL()`/`GEBDRE()` agregam GC2/GC3 por competência.
6. **Financeiro:** `GEBFNCON()` (GFN1 `CAIXA`) → `GEBFNREC()`/`GEBFNPAG()` (GFN2/GFN3
   `ABERTO`, PAG sob Mentor `PAG_IMPULSIVO`) → `GEBFNBAI()` (GFN2/GFN3 + GFN4/GFN1
   + `CTBLAN()`) → `GEBNFLX()` (`{receber, pagar, saldo}` só `ABERTO`).
7. **Entrada de compra:** `GEBCMFOR()` (GCP1) → `GEBCMCOT()`/`GEBCMMEL()` (GCP2) →
   `GEBCPXPED()`/`GEBCPXGERA()` (GCP3/GCP4 + GCQ2; `PENDENTE` acima de `COM_ALCADA`)
   → `GEBCPXAPR()` libera → `GEBCPXENT()` (`src/GEBCPX.prw`): estoque a custo de
   entrada (GCQ5/GV1) + `GEBFXTIT`/`GEBFNPAG` (condição do pedido − retenções) +
   `CTBLAN` (`COMPRA_ESTOQUE`) + GCQ7 (crédito IBS/CBS) → pedido `PARCIAL`/`RECEBIDO`.

---

## 6. Padrões de código (obrigatórios, verificados nos 84 fontes)

`totvs.ch` único · `User`/`Static` só · `If Nil` p/ defaults · `GetArea`/`RestArea` guardados ·
alias literal · workarea p/ leitura · `DbAppend()+RecLock(.T.)+MsUnlock()` p/ insert ·
`RecLock(.F.)` p/ update · `D_E_L_E_T_=' '` + filial em todo acesso · guarda `GEBDBTableExists()`/
`GEBDBTableExistsHere()` antes de `DbSelectArea` · SQL só literal (`TCSqlExec`/`TCSqlQuery`, sem `+`, sem `*`) ·
`ConOut()` p/ log · sem `IIF`/`cFilial`/UI-em-transação · chamadas sem `U_`.

---

## 7. Gaps AdvPP × AdvPL clássico — 7 workarounds aplicados

| # | Gap (runtime AdvPP) | Workaround aplicado nos fontes | Evidência |
|---|---------------------|--------------------------------|-----------|
| 1 | `FWLogMsg()` **não existe** no runtime | Log via `ConOut()` | Todos os 84 `src/*.prw` |
| 2 | `GetNextAlias()` **não existe** | Alias literal (`"GE4"`, `"GF2"`, …) | ex. `src/GENUC_MIG.prw` `GEBCFG()` |
| 3 | `Default` **sobrescreve incondicionalmente** | `If x == Nil` em vez de `Default` | Todos os `User Function` com params |
| 4 | `GetArea()` retorna `""` sem workarea aberta; `RestArea("")` **aborta** | Guarda `If Len(aArea) > 0` em **todas** as saídas | ex. `src/GEBSEC_LOGIN.prw` |
| 5 | `BeginSql` standalone é **no-op** no pré-processador (`preprocessor.go:345`, vira atribuição de string) | Leitura via workarea (`DbSelectArea`/`DbGoTop`/scan/`DbSkip`); SQL só via `TCSqlExec`/`TCSqlQuery` literais | ex. `src/GENUC_MIG.prw:75-90`, `src/GEBFIS_APU.prw` `SomaGF4()`, `src/GEBCPX.prw` `CPXPendentes()` |
| 6 | `Select()` e `Used()` são **stubs** (sempre `0`/`.F.`); `DbSelectArea` em tabela ausente **aborta** | Guarda de existência via `TCSqlQuery` antes de abrir — originalmente `SELECT name FROM sqlite_master …` (evidência da era SQLite); após a migração para Postgres (Fase 1c), o guard vive centralizado em `GEBDBTableExists()`/`GEBDBTableExistsHere()` (`src/GEBDB_CORE.prw`, sobre `pg_tables`/`information_schema`) | ex. `src/GENUC_MIG.prw:67-73`, `src/GEBFIS_EMI.prw:110-125`, `src/GEBDB_CORE.prw` |
| 7 | Escrita via workarea: `DbAppend()` puro **não persiste**; `RecLock()` sozinho **aborta** ("no current record") em tabela vazia | `DbAppend()` + `RecLock(alias, .T.)` + atribuições + `MsUnlock()` — único caminho que persiste (probes Task 3: gravou em vazia e em duplo insert N=2) | ex. `src/GENUC_CAD.prw:60-70`, `src/GENUC_MNT.prw:103-112` |
| 8 | Colunas `EMPRESA` adicionadas via `ALTER TABLE` **não aparecem no workarea** do AdvPP (`GEX->EMPRESA` retorna Nil) | Uso de `TCSqlQuery` para consultas que filtram por EMPRESA em `GEBEXP_CTX.prw`; workarea usado SOMENTE para tabelas criadas no mesmo módulo (`GEX`, `GEH`) | `src/GEBEXP_CTX.prw:55-73` (validação via `TCSqlQuery`); workarea só em `GEBEXPIST`/`GEBEXPCONTEXT` (GEX criada localmente) |
| 9 | `SET ORDER TO` em tabelas com `EMPRESA` recém-adicionada pode retornar ordem incorreta no migration | Uso de `DbSetOrder(1)` apenas nos relatórios de núcleo (`GEBEXP_REL_NUC.prw`); migração `GEBEXP_MIG` usa `TCSqlExec` sem workarea | `src/GEBEXP_REL_NUC.prw:40`, `src/GEBEXP_MIG.prw` |

**Extras documentados nos headers:** `U_` só resolve em `StartJob`/`FindFunction` ⇒ chamadas
diretas sem prefixo (todos os Protheus.doc); `FWxFilial()` retorna 6 espaços sem `RpcSetEnv`;
`DbSetOrder(1)` não casa com `GE4_FILIAL_EVE` ⇒ scan com filtros; sem passagem por referência
(`@` não garantido nos `Static` ⇒ `SomaGF4()` retorna array); `CTBLAN` com fallback stub quando
GC4 ausente/sem params (compat fiscal/derrama/venda); `GE1` sem coluna de regime ⇒ convenção
`GE1_NOME == "SIMPLES"`.

**Corrigidos no runtime desde então** (o código antigo segue válido): chamada com `U_` resolve
em qualquer lugar (AdvPP 4.8.3); passagem por referência `@var` funciona em local, `Private`,
`Static`, codeblock e métodos (4.8.4); `Nil` convertido em texto vira `""` (4.8.4) e o `NULL`
do Postgres chega ao `TCSqlQuery` como `""` (4.8.5); `GetEnv` de variável ausente devolve `""`.

---

## 8. Build e testes (evidência executada em 23/09/2026)

> Evidência abaixo é da era SQLite, anterior à migração para Postgres (Fase 1c) e ao login real
> (Fase 2). A flag `--db-path` usada nos comandos abaixo **não existe mais**: a conexão hoje é via
> `GEBAN_PG_HOST`/`GEBAN_PG_PORT`/`GEBAN_PG_DB`/`GEBAN_PG_USER`/`GEBAN_PG_PASSWORD` no ambiente
> (`GEBDBConecta()`, `src/GEBDB_TENANT.prw`).

| Etapa | Comando | Resultado real |
|-------|---------|----------------|
| Check | `advplc check src/*.prw tests/*.prw` | **84 files: 84 ok, 0 failed** (8 workers) |
| Suite | `advplc run tests/T_*.prw --db-path …` (46 arquivos, comando da era SQLite) | **46 PASS, 0 FAIL** (contagem por grep `PASS` por teste) |
| Serve | `advplc serve src/GEBTUI.prw --port 8081` | `AdvPP web: http://0.0.0.0:8081 (fonte: GEBTUI.prw)` |
| Massa | `T_GEBAN_MASSA` (100 auditorias), `T_GEBFIS_MASSA` (100 notas), `T_GEBV_MASSA` (100 vendas), `T_GEBDER_MASSA` (50 guias), `T_GEBCTB_MASSA` (200 lançamentos, `BAL`+`DRE`), `T_GEBFIN_MASSA` (100 títulos: 50 receber de 100 + 50 pagar de 50, `FLX {5000,2500,2500}` → baixa total → `{0,0,0}`, `CAIXA` 2500, 100 mov), `T_GEBCOM_MASSA` (50× `GEBCPXPED`+`GEBCPXENT`: 50 pedidos recebidos + GCQ4/GCQ5 + títulos), `T_GeExp_MASSA` (3 empresas 01/02/99 isoladas; cada uma: 20 NFs emitidas, 5 guias derrama, 10 pedidos entrada, 10 CTB; `GEBRELGERAL` por empresa confere contagens; 5 trackers validados) | Todos `PASS` na suite acima |

Testes por módulo (`tests/`): núcleo `T_GENUC_{MIG,CAD,MNT}` + `T_GEBAN_MASSA`;
fiscal `T_GEBFIS_{MIG,CAD,EMI,APU,MASSA}`; derrama `T_GEBDER_{MIG,GUI,COB,BAI,MASSA}`;
estoque `T_GEBV_{MIG,EST,VEN,FIA,MASSA}`; contábil `T_GEBCTB_{MIG,CTB,DIR,BAL,MASSA}`;
financeiro `T_GEBFIN_{MIG,CON_LAN,BAI,FLX,MASSA}`; compras
`T_GEBCOM_{MIG,FOR_COT,MASSA}` + `T_GEBCPX`; multi-empresa `T_GeExp_{MIG,CTX,REL_BIZ,REL_NUC,MASSA}`;
interface `T_GEBTUI_{OPS,FLUXOS,PERM}`, `T_GEBTUIBO`, `T_GEBPDV_API` e `T_GEBLOJ*` (PDV web).
Padrão dos testes: cleanup por `DELETE` p/ rerun limpo, regressão das tasks anteriores.

> **Estado atual:** a suíte cresceu para **90 testes** (`tests/run-all.sh`, Postgres
> `geban_test`, `advplc run`) — ver `docs/05-referencia-tecnica.md`, seção 9. Existe um
> **ambiente de demonstração** pronto na empresa 99 (`emp_99`): `scripts/geban-demo.sh`
> (up/down/reset/status/seed), watchdog `tests/emuladores/demo_watchdog.py` (:18768) que
> sobe sob demanda os emuladores SEFAZ :18766, Cielo :18765, banco CNAB :18767 e o
> periférico :9100, hook de auto-spawn no login (`GEBDEMOENSURE`, `src/GEBDEMO.prw`),
> seed `tests/local/seed_full.prw` e health-check `tests/T_GEBAN_DEMO.prw`. Detalhes na
> seção 14 da referência técnica e roteiro em `docs/demo-roteiro.md`.

---

## 9. Segurança

- **Certificado:** via `GetNewPar`, sem hardcode (spec §4).
- **SQL injection:** `FWExecStatement`/`%exp` + SQL só com literais; sem concatenação com `+`,
  sem `SELECT *` (planos §Global Constraints).
- **Locks:** `RecLock(alias, .F.)` não-bloqueante p/ update; `.T.` só como append (registro novo);
  todo `RecLock` fechado com `MsUnlock()`.
- **Perfis:** `GEBUSR()` valida `GE2_PERFIL`; `CAIXA` sem `PERMITE_DIRETA` é negado em `GEBCDIR()`
  e na validação de usuário; GC4 `LANC_DIRETO`/`PERM` + mentor como travas adicionais.
- **Auditoria:** toda liberação `AVISA_E_LIBERA_COM_BO` grava GE3 via `GEBAUD()` (`USER`, evento,
  `"assumiu BO mentor"`); miss de regra libera **sem** BO (sem trilhas espúrias).
- **Transações:** `Begin Transaction` só multi-tabela; erro ⇒ `DisarmTransaction()` +
  `FWLogMsg(ERROR)` com contexto (spec §4); sem UI em transação; sem `Recover` vazio.
- **Fila:** `GEBFILA()` com retry exponencial previsto; pendência vai pro Mentor, nunca erro
  mudo (spec §4). Segredos nunca em código (Lei 6).

---

## 10. Mapa arquivo → responsabilidade → teste

| Fonte | Responsabilidade | Teste(s) |
|-------|------------------|----------|
| `src/GENUC_MIG.prw` | `GENMIG`, `GEBCFG` (GE1–GE5) | `tests/T_GENUC_MIG.prw` |
| `src/GENUC_CAD.prw` | `GEBAUD`, `GEBUSR`, `GEBCAD` | `tests/T_GENUC_CAD.prw` |
| `src/GENUC_MNT.prw` | `GEBMNT`, `GEBFILA`, `CTBLAN`, `CTBGRV` | `tests/T_GENUC_MNT.prw`, `tests/T_GEBCTB_CTB.prw` |
| `src/GEBFIS_MIG.prw` | `GEBFMIG`, `CALCIBS`, `ALIQF` (GF1–GF6) | `tests/T_GEBFIS_MIG.prw` |
| `src/GEBFIS_CAD.prw` | `GEBFPRO`, `GEBFALI` | `tests/T_GEBFIS_CAD.prw` |
| `src/GEBFIS_EMI.prw` | `GEBFEMI`, `GEBFSPL` | `tests/T_GEBFIS_EMI.prw` |
| `src/GEBFIS_APU.prw` | `GEBFAPU`, `GEBFCRE` | `tests/T_GEBFIS_APU.prw` |
| `src/GEBDER_MIG.prw` | `GEBDMIG` (GD1–GD3) | `tests/T_GEBDER_MIG.prw` |
| `src/GEBDER_GUI.prw` | `GEBDGER` | `tests/T_GEBDER_GUI.prw` |
| `src/GEBDER_COB.prw` | `GEBDJUR`, `GEBDPAR`, `GEBDPRO` | `tests/T_GEBDER_COB.prw` |
| `src/GEBDER_BAI.prw` | `GEBDBAI` | `tests/T_GEBDER_BAI.prw` |
| `src/GEBV_MIG.prw` | `GEBVMIG` (GV1–GV3) | `tests/T_GEBV_MIG.prw` |
| `src/GEBV_EST.prw` | `GEBVEST` | `tests/T_GEBV_EST.prw` |
| `src/GEBV_VEN.prw` | `GEBVVEN` | `tests/T_GEBV_VEN.prw` |
| `src/GEBV_FIA.prw` | `GEBVFIA`, `GEBVJUR` | `tests/T_GEBV_FIA.prw` |
| `src/GEBCTB_MIG.prw` | `GEBCMIG` + seeds (GC1–GC4) | `tests/T_GEBCTB_MIG.prw` |
| `src/GEBCTB_DIR.prw` | `GEBCDIR` | `tests/T_GEBCTB_DIR.prw` |
| `src/GEBCTB_BAL.prw` | `GEBBAL`, `GEBDRE` | `tests/T_GEBCTB_BAL.prw` |
| `src/GEBFIN_MIG.prw` | `GEBFNMIG`, `GEBFNCON` (GFN1–GFN4) | `tests/T_GEBFIN_MIG.prw` |
| `src/GEBFIN_CON.prw` | `GEBFNREC`, `GEBFNPAG` | `tests/T_GEBFIN_CON_LAN.prw` |
| `src/GEBFIN_BAI.prw` | `GEBFNBAI` | `tests/T_GEBFIN_BAI.prw` |
| `src/GEBFIN_FLX.prw` | `GEBNFLX` | `tests/T_GEBFIN_FLX.prw` |
| `src/GEBCOM_MIG.prw` | `GEBCMMIG` (GCP1–GCP5) | `tests/T_GEBCOM_MIG.prw` |
| `src/GEBCOM_FOR.prw` | `GEBCMFOR`, `GEBCMCOT`, `GEBCMMEL` | `tests/T_GEBCOM_FOR_COT.prw` |
| `src/GEBCPX.prw` | `GEBCPXMIG`, `GEBCPXSC`, `GEBCPXGERA`, `GEBCPXPED`, `GEBCPXAPR`, `GEBCPXENT`, `GEBCPXDEV`, `GEBCPXABERTOS`, `GEBCPXPORFORN`, `GEBCPXSCPEND` | `tests/T_GEBCPX.prw`, `tests/T_GEBCOM_MASSA.prw` |
| `src/GEBEXP_MIG.prw` | `GEBEXPCriaAuditoria` (cria GEH/GEI no schema do tenant corrente) | `tests/T_GeExp_MIG.prw` |
| `src/GEBEXP_CTX.prw` | `GEBEXPCONTEXTO`, `GEBEXPIST`, `GEBEXPCONTEXT`, `GEBEXPCLEAR` | `tests/T_GeExp_CTX.prw` |
| `src/GEBEXP_REL_BIZ.prw` | `GEBRELFISCAL`, `GEBRELDERRAMA`, `GEBRELFIN`, `GEBRELSTOQUE`, `GEBRELCOMPRAS`, `GEBRELCONTABIL`, `GEBRELGERAL` | `tests/T_GeExp_REL_BIZ.prw` |
| `src/GEBEXP_TRAK.prw` | `GEBTRAKCOMPRA`, `GEBTRAKVENDA`, `GEBTRAKNOTAFISCAL`, `GEBTRAKDERRAMA` | `tests/T_GeExp_REL_BIZ.prw` |
| `src/GEBEXP_REL_NUC.prw` | `GEBRELEMPRESAS`, `GEBRELUSUARIOS`, `GEBRELAUDITORIA`, `GEBRELMENTOR`, `GEBRELCADASTROS` | `tests/T_GeExp_REL_NUC.prw` |
| `src/GEBTUI.prw` | Interface PO-UI: login, empresa/filial, menu, Início, páginas de módulo, formulários (`TUIFormularios`), rastreabilidade | `tests/T_GEBTUI_OPS.prw`, `tests/T_GEBTUI_FLUXOS.prw`, `tests/T_GEBTUI_PERM.prw` |
| `public/pdv.html` | PDV web (frente de caixa): venda, caixa, crypto, regime | — |
| `src/GEBTUIBO.prw` | DANFE da NFC-e do cupom | `tests/T_GEBTUIBO.prw` |
| massas | carga + regressão | `tests/T_GeExp_MASSA.prw` (3 empresas × 20 NFs + 5 guias + 10 pedidos + 10 CTB) + `tests/T_GEBAN_MASSA.prw`, `T_GEBFIS_MASSA`, `T_GEBDER_MASSA`, `T_GEBV_MASSA`, `T_GEBCTB_MASSA`, `T_GEBFIN_MASSA`, `T_GEBCOM_MASSA` |

Spec: `documentacao interna`.
Planos: `documentacao interna`.
