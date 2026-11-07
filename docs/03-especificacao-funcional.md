# 03 — Especificação Funcional — ERP GEBAN (República das Bananas / Bananias)

> **Data:** 23/09/2026 · **Idioma:** PT-BR · **Autor:** Peder Munksgaard
> **Base real:** `src/*.prw` (38 fontes) + `documentacao interna` + `documentacao interna`
> **Banco:** SQLite `geban.db` · **Entrada:** `GEBAN()` (`src/GEBAN.prw`) · **Include único:** `totvs.ch`
> **Expansão:** `GEB_EXPANSAO` (multi-empresa + sessao + relatorios + trackers + web) + `GEB_GUI` (validadores + menu 9 opcoes + browses + config + main terminal).

## 0. Convenções válidas para todos os módulos

- **Chamada sem prefixo `U_`:** as interfaces do plano (`U_GENMIG`, `U_GEBMNT`, …) são chamadas
  sem `U_` (`GENMIG()`, `GEBMNT()`, …) porque o runtime AdvPP só resolve `U_` em
  `StartJob`/`FindFunction`; chamada direta `U_X()` dá `unknown function`.
- **Toda leitura filtra `FILIAL + D_E_L_E_T_ = ' '`** via workarea (`DbSelectArea`/`DbGoTop`/scan/`DbSkip`).
  `FWxFilial()` retorna 6 espaços sem ambiente (`'      '`).
- **Toda escrita usa `DbAppend() + RecLock(.T.) + MsUnlock()`** (insert) ou `RecLock(.F.) + MsUnlock()`
  (update/baixa lógica `D_E_L_E_T_ := "*"`). `GetArea()`/`RestArea()` guardados (`Len(aArea) > 0`).
- **Guarda de existência:** `TCSqlQuery("SELECT name FROM sqlite_master …")` antes de abrir a tabela
  (`DbSelectArea` em tabela ausente aborta; `Select()`/`Used()` são stubs).
- **Log via `ConOut()`** (`FWLogMsg` não existe no runtime AdvPP). Sem `BeginSql` standalone,
  sem `SELECT *`, sem concatenação SQL, sem `cFilial`, sem `IIF`.
- **Mentor (`GEBMNT`, `src/GENUC_MNT.prw`):** lê o modo em GE4 via `GEBCFG(cEvento)`:
  `AVISA_E_TRAVA` → retorna `.F.` (log `Mentor travou <evento>`);
  `AVISA_E_LIBERA_COM_BO` → grava GE3 via `GEBAUD("USER", cEvento, "assumiu BO mentor")` e retorna `.T.`
  (log `Mentor liberou com BO <evento>`); `DESLIGADO`, `""` (miss) ou outro → `.T.` sem BO
  (log `Mentor liberou <evento>`). Miss sem BO é desvio documentado do plano (evita trilha espúria).
- **Fila (`GEBFILA`, `src/GENUC_MNT.prw`):** insere em GE5 `FILIAL + D_E_L_E_T_=' ' + CHAVE + PAYLD + STATUS='PENDENTE'`
  (log `FILA <chave>`). Retorna `.F.` se GE5 não existir.
- **Contábil (`CTBLAN`/`CTBGRV`, `src/GENUC_MNT.prw`):** partida dobrada real via GC4 (evento → DEB/CRED,
  fallback `PADRAO` = DEB `1.01.001` / CRED `3.01.001`), grava GC2 + 2×GC3 com `TIPO AUTO` via `CTBGRV`,
  confere débito = crédito (desbalanceado → lote `""`). **Compat:** GC4 ausente ou vazia → modo stub
  (só loga `CTB stub <origem> <valor>`, retorna `.T.`), preservando fiscal/derrama/venda.
  Valor ≤ 0, conta vazia ou param ausente → `.F.`/`""`. Lote sequencial `"L" + (nLotes+1)`.
- **Auditoria (`GEBAUD`, `src/GENUC_CAD.prw`):** insere em GE3 `FILIAL + D_E_L_E_T_=' ' + COD=evento + USUAR + EVENT + MOTIV + DATA=DToS(Date())`
  (log `AUD <usuario> <evento> <motivo>`). Nil → `SYSTEM`/`EVENTO`/`""`.
- **Perfil (`GEBUSR`, `src/GENUC_CAD.prw`):** miss em GE2 → `.F.`; perfil `CAIXA` só autoriza se
  `GEBCFG("PERMITE_DIRETA") == "S"`; demais perfis → `.T.`.

---

## 1. MÓDULO NUCLEO (GE1–GE5)

**Fontes:** `src/GENUC_MIG.prw` (`GENMIG`, `GEBCFG`), `src/GEBAN.prw` (`GEBAN`, `MenuDef`),
`src/GENUC_CAD.prw` (`GEBAUD`, `GEBUSR`, `GEBCAD`), `src/GENUC_MNT.prw` (`GEBMNT`, `GEBFILA`, `CTBLAN`, `CTBGRV`)
**Tabelas:** GE1 empresas (`FILIAL/COD/NOME`), GE2 usuários (`FILIAL/COD/NOME/PERFIL`),
GE3 auditoria (`FILIAL/COD/USUAR/EVENT/MOTIV/DATA`), GE4 mentor (`FILIAL/EVENTO/MODO`),
GE5 fila (`FILIAL/CHAVE/PAYLD/STATUS`).

### 1.1 Atores

| Ator | Papel |
|------|-------|
| Operador / Administrador | Roda `GEBAN()`, cadastra empresa/usuário, parametriza GE4 |
| Jobs dos demais módulos | Consomem `GEBCFG`, `GEBMNT`, `GEBFILA`, `GEBAUD`, `CTBLAN` |
| Caixa | Validado via `GEBUSR` (trava `PERMITE_DIRETA`) |

### 1.2 Pré-condições

1. `geban.db` acessível; migração `GENMIG()` executada (idempotente, `CREATE TABLE/INDEX IF NOT EXISTS`).
2. Para `GEBAUD`: GE3 existe. Para `GEBUSR`: GE2 existe (senão `.F.`). Para `GEBCFG`/`GEBFILA`: GE4/GE5 existem (senão `""`/`.F.`).

### 1.3 Fluxo principal (numerado)

1. Operador chama `GEBAN()` → `GENMIG()` cria GE1–GE5 + índices → log `GEBAN Nucleo online - Bananias`, retorna `.T.`
   (falha em qualquer `CREATE` → log `GEBAN Nucleo FAIL - GENMIG falhou`, `.F.`).
2. `MenuDef()` expõe Núcleo/Fiscal/Derrama/Estoque/Contábil (ações ainda stubs via `ConOut`).
3. Cadastro/auditoria: `GEBAUD(cUsuario, cEvento, cMotivo)` grava GE3 (seção 0).
4. Parametrização: linhas GE4 (`EVENTO` → `MODO`) lidas por `GEBCFG(cChave)` (scan `FILIAL+EVENTO+D_E_L_E_T_`).
5. Consumo: demais módulos chamam `GEBMNT` (trava/libera), `GEBFILA` (offline) e `CTBLAN` (partida dobrada).

### 1.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| N-A1 | Offline / fila | `GEBFILA(cChave, cPayload)` grava GE5 `PENDENTE`; GE5 ausente → `.F.` sem abortar |
| N-A2 | Trava mentor | `GEBMNT` com `AVISA_E_TRAVA` → `.F.`; chamador decide (emissão/venda/direta recusam, estoque só alerta) |
| N-A3 | Sem estoque | Não se aplica ao núcleo (ver ESTOQ_VENDA); núcleo não bloqueia |
| N-A4 | Inadimplência | Não se aplica ao núcleo (ver ESTOQ_VENDA fiado / DERRAMA protesto) |
| N-A5 | Tabela ainda não migrada | `GEBCFG` → `""`, `GEBUSR`/`GEBFILA` → `.F.`, `CTBLAN` → stub `.T.` (compat) |
| N-A6 | Evento mentor desconhecido | `GEBCFG` miss → `GEBMNT` libera `.T.` **sem** gravar BO |

### 1.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GENMIG` | GE1–GE5 + índices `GE*_FILIAL_*` (se ausentes) |
| `GEBAUD` | GE3: 1 linha `COD=EVENTO, USUAR, EVENT, MOTIV, DATA, FILIAL, D_E_L_E_T_=' '` |
| `GEBFILA` | GE5: 1 linha `CHAVE, PAYLD, STATUS='PENDENTE'` |
| `CTBLAN`/`CTBGRV` | GC2: 1 lote (`LOTE, ORIGEM, VALOR, DATA AAAAMMDD, COMP AAAAMM, TIPO`); GC3: 2 pernas (`LOTE, DC D/C, CONTA, VALOR`) |

### 1.6 Regras + mensagens

| Regra | Mensagem (`ConOut`) |
|-------|---------------------|
| GENMIG inicia | `GENMIG criando GE1-GE5 em geban.db` |
| GEBAN OK / FAIL | `GEBAN Nucleo online - Bananias` / `GEBAN Nucleo FAIL - GENMIG falhou` |
| Auditoria gravada | `AUD <usuario> <evento> <motivo>` |
| Mentor trava / libera / libera com BO | `Mentor travou <ev>` / `Mentor liberou <ev>` / `Mentor liberou com BO <ev>` |
| Fila gravada | `FILA <chave>` |
| CTB stub / real / desbalanceado | `CTB stub <origem> <valor>` / `CTB <origem> <valor>` + `CTBGRV <lote> <tipo>` / `CTB desbalanceado <lote>` |
| `GEBCAD`/menu stubs | `GEBCAD Cadastros GE1/GE2/GE3 online`, `GEBAN <modulo> - stub …` |

### 1.7 Parâmetros GE4 (núcleo)

| Evento GE4 | Valores | Default (miss) | Consumidor |
|------------|---------|----------------|------------|
| `PERMITE_DIRETA` | `S` / outro | `""` (= negado) | `GEBUSR` (CAIXA), `GEBCDIR` trava 1 |
| `EMISSAO` | `ONLINE_PURO` / `ONLINE_FILA` / `SO_FILA` | `ONLINE_FILA` | `GEBFEMI` |
| `APURACAO` | `AUTO` / `MANUAL` / `DIRETA` | `AUTO` (os 3 gravam; só muda o log) | `GEBFAPU` |
| `VENDA_IMPULSIVA`, `ESTOQUE_MINIMO`, `LANC_DIRETO`, demais eventos mentor | `AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO` | `""` (= libera sem BO) | `GEBMNT` via `GEBFEMI`, `GEBVEST`, `GEBVVEN`, `GEBCDIR` |

---

## 2. MÓDULO FISCAL (GF1–GF6)

**Fontes:** `src/GEBFIS_MIG.prw` (`GEBFMIG`, `CALCIBS`, `ALIQF`), `src/GEBFIS_CAD.prw` (`GEBFPRO`, `GEBFALI`),
`src/GEBFIS_EMI.prw` (`GEBFEMI`, `GEBFSPL`), `src/GEBFIS_APU.prw` (`GEBFAPU`, `GEBFCRE`)
**Tabelas:** GF1 produto (`COD/NCM/DESC`), GF2 alíquotas (`NCM/IBS/CBS/INI/FIM` YYYYMMDD),
GF3 nota header (`CHAVE/TIPO=NFE/STATUS/BASE/IBS/CBS/EMIS`), GF4 item (`CHAVE/ITEM=001/PROD/QTD/PRECO/BASE/IBS/CBS`),
GF5 apuração (`COMP YYYYMM/DEB/CRED/SALDO/REGIME`), GF6 créditos (`COMP/ORIG/VALOR/TIPO`).

### 2.1 Atores

| Ator | Papel |
|------|-------|
| Caixa / Faturista | Cadastra produto/alíquota, emite NF-e/NFS-e, apura competência |
| Contador | Apura (`GEBFAPU`), lança créditos (`GEBFCRE` TRANSF/RESSARC) |
| SEFAZ mock (ISeedFaz futuro) | Hoje: autoriza se `base > 0` (exceto `SO_FILA`) |

### 2.2 Pré-condições

1. `GEBFMIG()` executada (GF1–GF6 idempotentes).
2. Emissão: produto em GF1 + vigência GF2 válida para o NCM na data (miss → tributa a zero, não bloqueia).
3. Apuração: GF3/GF4/GF5 existem (senão `GEBFAPU` → `.F.`); GF6 existe para `GEBFCRE` (senão `.F.`).

### 2.3 Fluxo principal (numerado)

1. Migração: `GEBFMIG()` cria GF1–GF6 + índices → `.T.` (qualquer `CREATE` falha → `.F.`).
2. Cadastro: produto em GF1 (`GEBFPRO(cCod)` lê e retorna `{COD,NCM,DESC}`, `{}` se miss);
   alíquota via `ALIQF(cNCM, dData)` / `GEBFALI(cNCM[, dData])` (data `Date` ou `YYYYMMDD`; sem `dData` = hoje;
   última vigência válida `INI ≤ data ≤ FIM` vence; miss → `{0,0}`).
3. Cálculo: `CALCIBS(nBase, nAliqIBS, nAliqCBS)` → `{base*IBS/100, base*CBS/100}`.
4. Emissão `GEBFEMI(cChave, cCod, nQtd, nPreco)`:
   1. `GEBMNT("EMISSAO")` (trava → força fila); 2. modo `GEBCFG("EMISSAO")` (miss → `ONLINE_FILA`);
   3. produto + alíquotas; 4. `base = qtd*preco`, `CALCIBS`; 5. mock autoriza se `base>0` (`SO_FILA` nunca autoriza);
   6. grava GF3 + GF4(`001`); 7. `AUTORIZADA` → `CTBLAN` + retorna `AUTORIZADA`;
   `EM_FILA` → `GEBFILA` (exceto `ONLINE_PURO` puro, que não enfileira) + `CTBLAN`.
5. Split: `GEBFSPL(nTotal, nPartes)` divide em parcelas (última ajusta resíduo p/ soma exata; `nPartes ≤ 0` → `{nTotal}`).
6. Apuração `GEBFAPU(cComp YYYYMM)`: chaves GF3 do mês (`SubStr(EMIS,1,6)==cComp`) → soma GF4 (`IBS+CBS`) →
   `DEB=soma, CRED=0, SALDO=DEB`, regime via GE1 (`NOME==SIMPLES` → `SIMPLES`, senão `REGULAR`) →
   baixa idempotente (linhas GF5 ativas da competência → `"*"`) + insert GF5. Os 3 modos gravam; só o log muda
   (`APU AUTO/MANUAL/DIRETA <comp> <regime>` + `APU <comp> DEB <valor>`).
7. Créditos `GEBFCRE(cComp, cOrig, nValor, cTipo)`: grava GF6 (`TRANSF` default; inválido → `TRANSF`).

### 2.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| F-A1 | Offline / fila | `EM_FILA`: GF3 `STATUS=EM_FILA` + GF4 gravados + `GEBFILA(cChave, cChave)` + `CTBLAN`; `ONLINE_PURO` puro falha sem enfileirar |
| F-A2 | Trava mentor | `GEBMNT("EMISSAO") = .F.` → `lAutoriza=.F.` → `EM_FILA` + fila (exceto `ONLINE_PURO`) |
| F-A3 | Sem estoque | Não bloqueia no fiscal; venda (`GEBVVEN`) barra antes com `SEM_ESTOQUE` |
| F-A4 | Inadimplência | Não bloqueia emissão; tratada no fiado (GV3) e protesto (GD3) |
| F-A5 | Produto/alíquota ausente | Miss → `base` tributada a zero (`{0,0}`), emissão prossegue |
| F-A6 | Base zerada | Mock não autoriza → `EM_FILA` |
| F-A7 | GF3/GF4 ausentes | Guarda `sqlite_master` → `GEBFILA` + retorna `EM_FILA` sem gravar |
| F-A8 | Re-apuração | Baixa lógica da competência + novo insert (idempotente, sem duplicar ativo) |

### 2.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GEBFMIG` | GF1–GF6 + índices |
| `GEBFEMI` AUTORIZADA/EM_FILA | GF3 (`CHAVE, TIPO=NFE, STATUS, BASE, IBS, CBS, EMIS=DToS`) + GF4 (`CHAVE, 001, PROD, QTD, PRECO, BASE, IBS, CBS`); fila GE5 se `EM_FILA` (exceto puro); GC2/GC3 via `CTBLAN(cChave, base)` |
| `GEBFAPU` | GF5 (`COMP, DEB, CRED=0, SALDO, REGIME`); baixa prévia `"*"` da competência |
| `GEBFCRE` | GF6 (`COMP, ORIG, VALOR, TIPO TRANSF/RESSARC`) |

### 2.6 Regras + mensagens

| Regra | Mensagem |
|-------|----------|
| Migração | `GEBFMIG criando GF1-GF6 em geban.db` |
| Emissão | `EMI AUTORIZADA <chave>` / `EMI EM_FILA <chave>` / `EMI EM_FILA puro <chave>` |
| Split | `SPL <total> x<partes>` / `SPL <total> x1` |
| Apuração | `APU AUTO/MANUAL/DIRETA <comp> <regime>`, `APU <comp> DEB <valor>` |
| Crédito | `CRE <comp> <tipo> <valor>` |
| Vigências sobrepostas sem ordem: última vence. `REAL` sem tolerância (armadilha documentada). Statics retornam arrays (sem `@` por referência — falha silenciosa no AdvPP). |

### 2.7 Parâmetros GE4 (fiscal)

| Evento | Valores | Default | Efeito |
|--------|---------|---------|--------|
| `EMISSAO` | `ONLINE_PURO` (falha não enfileira) / `ONLINE_FILA` / `SO_FILA` (sempre fila) | `ONLINE_FILA` | Roteamento emissão |
| `APURACAO` | `AUTO` / `MANUAL` / `DIRETA` | `AUTO` | Só muda o log; os 3 gravam GF5 |
| Mentor `EMISSAO` | `AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO` | libera sem BO | Trava força `EM_FILA` |

---

## 3. MÓDULO DERRAMA (GD1–GD3)

**Fontes:** `src/GEBDER_MIG.prw` (`GEBDMIG`), `src/GEBDER_GUI.prw` (`GEBDGER`),
`src/GEBDER_COB.prw` (`GEBDJUR`, `GEBDPAR`, `GEBDPRO`), `src/GEBDER_BAI.prw` (`GEBDBAI`)
**Tabelas:** GD1 guia (`GUIA/COMP/VALOR/JUROS/MULTA/TOTAL/STATUS`), GD2 parcelas (`GUIA/PARC 3 dígitos/VALOR/STATUS`),
GD3 cobrança (`GUIA/ACAO/DATA/STATUS`).

### 3.1 Atores

| Ator | Papel |
|------|-------|
| Contador / Caixa | Gera guia da apuração, aplica juros, parcela, protesta, baixa |
| Contribuinte (MEI) | Quita DARF-CBS (guia `BAIXADA`) |

### 3.2 Pré-condições

1. `GEBDMIG()` executada (GD1–GD3 idempotentes).
2. Geração: GF5 com saldo ativo na competência + GD1 existe (senão `""`); `cComp` não vazio.
3. Cobrança/baixa: GD1 (+GD2/GD3 conforme a função) existe; guia identificada.

### 3.3 Fluxo principal (numerado)

1. `GEBDMIG()` cria GD1–GD3 + índices → `.T.`/`.F.`.
2. `GEBDGER(cComp)`: lê saldo GF5 ativo da competência → `GUIA = "GD"+cComp` →
   idempotente (guia ativa existente → retorna sem duplicar) → senão insere GD1
   (`VALOR=saldo, JUROS=0, MULTA=0, TOTAL=saldo, STATUS=ABERTA`) → retorna guia.
3. `GEBDJUR(cGuia, nDias)`: juros banânicos `0,33%/dia` com **teto 20%** + multa fixa **2%** sobre `VALOR` →
   grava `JUROS/MULTA/TOTAL` → retorna total.
4. `GEBDPAR(cGuia, nParc)`: exige `nParc ≥ 2`; base = `TOTAL` (ou `VALOR` se zerado) →
   baixa lógica das parcelas ativas + `nParc` linhas GD2 (`PARC` 3 dígitos, última ajusta resíduo,
   `STATUS=ABERTA`) + GD1 → `PARCELADA` → `.T.`.
5. `GEBDPRO(cGuia)`: GD3 (`ACAO=PROTESTO, DATA=hoje, STATUS=ABERTA`) + GD1 → `PROTESTADA` → `.T.`.
6. `GEBDBAI(cGuia)`: GD1 ativa → `BAIXADA` + `CTBLAN(cGuia, TOTAL ou VALOR)` → `.T.`.

### 3.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| D-A1 | Offline / fila | Indireto: emissão fiscal que originou a base pode estar em GE5; guia só nasce de GF5 gravada |
| D-A2 | Trava mentor | Nenhuma trava direta na derrama; mentor atua na origem (emissão) e no CTB |
| D-A3 | Sem estoque | Não se aplica |
| D-A4 | Inadimplência | `GEBDJUR` (juros+multa) → `GEBDPAR` (parcela) → `GEBDPRO` (protesto, `PROTESTADA` + GD3 `ABERTA`) |
| D-A5 | Guia inexistente / vazia / tabela ausente | `GEBDJUR` → `0`; `GEBDPAR`/`GEBDPRO`/`GEBDBAI` → `.F.`; `GEBDGER` → `""` |
| D-A6 | Guia já existe | `GEBDGER` retorna a guia sem duplicar |
| D-A7 | `nParc < 2` | `GEBDPAR` → `.F.` sem tocar o banco |

### 3.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GEBDMIG` | GD1–GD3 + índices |
| `GEBDGER` | GD1 (`GUIA=GD+comp, COMP, VALOR/JUROS=0/MULTA=0/TOTAL=saldo, ABERTA`) |
| `GEBDJUR` | GD1: update `JUROS/MULTA/TOTAL` |
| `GEBDPAR` | GD2: baixa `"*"` + N inserts (`PARC, VALOR, ABERTA`); GD1 → `PARCELADA` |
| `GEBDPRO` | GD3 (`PROTESTO, hoje, ABERTA`); GD1 → `PROTESTADA` |
| `GEBDBAI` | GD1 → `BAIXADA`; GC2/GC3 via `CTBLAN` |

### 3.6 Regras + mensagens

| Regra | Mensagem |
|-------|----------|
| Migração | `GEBDMIG criando GD1-GD3 em geban.db` |
| Guia gerada / existente | `GER guia <guia> <saldo>` / `GER guia existente <guia>` |
| Juros | `JUR <guia> <total>` |
| Parcelamento | `PAR <guia> <nParc>` |
| Protesto | `PRO <guia>` |
| Baixa | `BAI <guia> <total>` |
| Fórmula: `JUROS = min(VALOR×0,0033×dias, VALOR×0,20)`; `MULTA = VALOR×0,02`; `TOTAL = VALOR+JUROS+MULTA`. |

### 3.7 Parâmetros GE4 (derrama)

Nenhum evento próprio. Usa `CTBLAN` na baixa (GC4, ver §5.7) e herda a base da apuração (`APURACAO`, §2.7).

---

## 4. MÓDULO ESTOQ_VENDA (GV1–GV3)

**Fontes:** `src/GEBV_MIG.prw` (`GEBVMIG`), `src/GEBV_EST.prw` (`GEBVEST`),
`src/GEBV_VEN.prw` (`GEBVVEN`), `src/GEBV_FIA.prw` (`GEBVFIA`, `GEBVJUR`)
**Tabelas:** GV1 saldo (`PROD/SALDO/MIN`), GV2 venda (`VENDA/PROD/QTD/STATUS`),
GV3 fiado (`CLI/VALOR/JUROS/MULTA/TOTAL/STATUS`).

### 4.1 Atores

| Ator | Papel |
|------|-------|
| Estoquista | Movimenta saldo (`GEBVEST`) |
| Vendedor / Caixa | Vende (`GEBVVEN`), abre fiado (`GEBVFIA`) |
| Mentor | `ESTOQUE_MINIMO` (alerta), `VENDA_IMPULSIVA` (trava) |

### 4.2 Pré-condições

1. `GEBVMIG()` executada (GV1–GV3 idempotentes).
2. Venda: GV1+GV2 existem (senão `SEM_ESTOQUE`); `cVenda`/`cProd` não vazios; `qtd > 0`.
3. Fiado: GV3 existe (senão `.F.`/`0`); `cCli` não vazio; `nValor > 0`.

### 4.3 Fluxo principal (numerado)

1. `GEBVMIG()` cria GV1–GV3 + índices → `.T.`/`.F.`.
2. `GEBVEST(cProd, nQtd)`: produto vazio ou GV1 ausente → `0`; existente soma `nQtd`
   (positivo entra, negativo sai); inexistente cria (`SALDO=nQtd, MIN=10`) → retorna novo saldo;
   saldo < mínimo → `GEBMNT("ESTOQUE_MINIMO")` **só alerta** (não trava) + `EST MINIMO <prod>`, senão `EST <prod>`.
3. `GEBVVEN(cVenda, cProd, nQtd[, nPreco=10])`: guardas → `BLOQUEADA` (vazio/zerado);
   GV1/GV2 ausentes → `SEM_ESTOQUE`; `GEBMNT("VENDA_IMPULSIVA")` travado → `BLOQUEADA` sem tocar o banco;
   produto ausente ou `saldo < qtd` → `SEM_ESTOQUE` sem tocar o banco;
   senão baixa GV1, grava GV2 `VENDIDA` → integração: se GF1+GF3+GF4 existem chama
   `GEBFEMI(cVenda, cProd, nQtd, nPreco)` (fiscal grava GF3/GF4 + CTB), senão `CTBLAN(cVenda, qtd*preco)` direto →
   retorna `VENDIDA`.
4. `GEBVFIA(cCli, nValor)`: soma em aberto (GV3 `ABERTA`, `TOTAL` ou `VALOR`) + novo ≤ **limite 1000** →
   insere GV3 (`JUROS=0, MULTA=0, TOTAL=nValor, ABERTA`) → `.T.`; acima → `FIA LIMITE <cli>`, `.F.` sem gravar.
5. `GEBVJUR(cCli, nDias)`: por linha `ABERTA`: mesma fórmula banânica (0,33%/dia, teto 20%, multa 2%) →
   update `JUROS/MULTA/TOTAL` → retorna soma dos totais (`0` se vazio/sem aberto).

### 4.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| V-A1 | Offline / fila | Indireto: com fiscal presente, `GEBFEMI` enfileira em GE5 (`EM_FILA`); sem fiscal, `CTBLAN` direto |
| V-A2 | Trava mentor | `VENDA_IMPULSIVA=AVISA_E_TRAVA` → `BLOQUEADA` sem tocar o banco (com BO: `GEBAUD` + libera); `ESTOQUE_MINIMO` nunca trava, só alerta |
| V-A3 | Sem estoque | `SEM_ESTOQUE` sem tocar o banco (tabela ausente, produto ausente, `saldo < qtd`); log `VEN SEM_ESTOQUE <venda>` |
| V-A4 | Inadimplência | `GEBVFIA` nega acima do limite 1000 (`.F.`); `GEBVJUR` acresce juros/multa por linha aberta |
| V-A5 | Guardas | `cVenda`/`cProd` vazios ou `qtd ≤ 0` → `BLOQUEADA`; `cProd` vazio em `GEBVEST` → `0` |

### 4.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GEBVMIG` | GV1–GV3 + índices |
| `GEBVEST` | GV1: update `SALDO` ou insert (`PROD, SALDO, MIN=10`) |
| `GEBVVEN` | GV1: baixa `SALDO-qtd`; GV2 (`VENDA, PROD, QTD, VENDIDA`); fiscal GF3/GF4 + GE5 (se fiscal) ou GC2/GC3 via `CTBLAN` |
| `GEBVFIA` | GV3 (`CLI, VALOR, JUROS=0, MULTA=0, TOTAL, ABERTA`) |
| `GEBVJUR` | GV3: update `JUROS/MULTA/TOTAL` por linha aberta |

### 4.6 Regras + mensagens

| Regra | Mensagem |
|-------|----------|
| Migração | `GEBVMIG criando GV1-GV3 em geban.db` |
| Estoque | `EST <prod>` / `EST MINIMO <prod>` |
| Venda | `VEN VENDIDA <venda>` / `VEN BLOQUEADA <venda>` / `VEN SEM_ESTOQUE <venda>` |
| Fiado | `FIA <cli>` / `FIA LIMITE <cli>` / `JUR FIA <cli>` |
| Limite fiado fixo: **1000** (soma `ABERTA` + novo). Mínimo default: **10**. Preço default venda: **10**. |

### 4.7 Parâmetros GE4 (estoq_venda)

| Evento | Valores | Default | Efeito |
|--------|---------|---------|--------|
| Mentor `VENDA_IMPULSIVA` | `AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO` | libera sem BO | Trava → `BLOQUEADA` |
| Mentor `ESTOQUE_MINIMO` | idem | libera sem BO | Só alerta, nunca trava |
| `EMISSAO` (indireto) | ver §2.7 | `ONLINE_FILA` | Roteia `GEBFEMI` chamado pela venda |

---

## 5. MÓDULO CONTABIL (GC1–GC4)

**Fontes:** `src/GEBCTB_MIG.prw` (`GEBCMIG`), `src/GENUC_MNT.prw` (`CTBLAN`, `CTBGRV`),
`src/GEBCTB_DIR.prw` (`GEBCDIR`), `src/GEBCTB_BAL.prw` (`GEBBAL`, `GEBDRE`)
**Tabelas:** GC1 plano (`CONTA/NOME/TIPO A/S`), GC2 lote (`LOTE/ORIGEM/VALOR/DATA AAAAMMDD/COMP AAAAMM/TIPO AUTO/DIRETO`),
GC3 pernas (`LOTE/DC D-C/CONTA/VALOR`), GC4 params (`EVENTO→CTADEB/CTACRED/PERM S-N`).

### 5.1 Atores

| Ator | Papel |
|------|-------|
| Contador | Parametriza GC4, lança direto (`GEBCDIR`), consulta balancete/DRE |
| Jobs fiscal/derrama/venda | Lançam via `CTBLAN` (origem → contas GC4) |
| Caixa | **Negado** na direta salvo `PERMITE_DIRETA=S` (via `GEBUSR`) |

### 5.2 Pré-condições

1. `GEBCMIG()` executada (GC1–GC4 + seeds idempotentes: `1.01.001 CAIXA`, `2.01.001 FORNECEDORES`,
   `3.01.001 RECEITA VENDAS`, `4.01.001 CUSTO MERCADORIAS`; GC4 `PADRAO` DEB `1.01.001`/CRED `3.01.001`/`PERM S`).
2. `CTBLAN`: GC4 parametrizada (senão stub compat `.T.`); valor > 0.
3. `GEBCDIR`: 4 travas liberadas (abaixo) + contas não vazias + valor > 0 + GC2/GC3 existentes.
4. `GEBBAL`/`GEBDRE`: GC2+GC3 existentes (senão array vazio / `0`).

### 5.3 Fluxo principal (numerado)

1. `GEBCMIG()` cria GC1–GC4 + índices + seeds (só insere se ainda não existir) → `.T.`/`.F.`.
2. `CTBLAN(cOrigem, nValor)` (chamado por emissão, baixa de guia e venda sem fiscal): resolve GC4 do evento
   (fallback `PADRAO`; falta → `.F.`) → `CTBGRV(cOrigem, DEB, CRED, nValor, "AUTO")` → `.T.` se lote gerado.
3. `CTBGRV`: lote `"L"+(n+1)` → GC2 + perna D + perna C → confere somas (desbalanceado → `""`) → retorna lote.
4. `GEBCDIR(cContaD, cContaC, nValor[, cUser])` — 4 travas em ordem:
   1. `GEBCFG("PERMITE_DIRETA")=="S"` (senão `DIR negado flag`, `.F.`);
   2. `GEBUSR(cUser)` (senão `DIR negado perfil <user>`, `.F.`);
   3. GC4 `LANC_DIRETO` com `PERM N` nega (ausente libera; senão `DIR negado GC4`, `.F.`);
   4. `GEBMNT("LANC_DIRETO")` (trava nega: `DIR negado mentor`, `.F.`) →
   `CTBGRV("DIRETO", D, C, valor, "DIRETO")` (carimbo `DIRETO`) → `DIR <lote> <valor>`.
5. `GEBBAL(cComp AAAAMM)`: lotes ativos da competência → soma pernas por conta →
   array `{cConta, nDebito, nCredito}` (log `BAL <comp> <nContas>`).
6. `GEBDRE(cComp)`: `receitas (grupo 3: C−D) − despesas/custos (grupo 4: D−C)` → número (log `DRE <comp> <resultado>`).

### 5.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| C-A1 | Offline / fila | Contábil não enfileira; a origem (emissão) já enfileirou em GE5 |
| C-A2 | Trava mentor | `LANC_DIRETO=AVISA_E_TRAVA` → direta negada (`.F.`); `CTBLAN` AUTO não passa pelo mentor |
| C-A3 | Sem estoque | Não se aplica |
| C-A4 | Inadimplência | Não bloqueia lançamento; refletida via DRE/balancete |
| C-A5 | Direta sem permissão | Flag `≠S`, perfil negado, `GC4 LANC_DIRETO PERM N`, contas vazias, valor ≤ 0 ou writer falha → `.F.` |
| C-A6 | Contábil ainda não parametrizada | `CTBLAN` modo stub `.T.` (GC4 ausente/vazia) — compat fiscal/derrama/venda |
| C-A7 | Desbalanceamento | `CTBGRV` retorna `""` (`CTB desbalanceado <lote>`), `CTBLAN`/`GEBCDIR` → `.F.` |

### 5.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GEBCMIG` | GC1 (4 contas seed) + GC4 (`PADRAO`) + índices |
| `CTBLAN`/`CTBGRV` | GC2 (`LOTE, ORIGEM, VALOR, DATA, COMP, TIPO AUTO`) + GC3 2 pernas (`D` + `C`) |
| `GEBCDIR` | GC2 (`ORIGEM=DIRETO, TIPO=DIRETO`) + GC3 2 pernas; + GE3 (BO) se mentor `AVISA_E_LIBERA_COM_BO` |
| `GEBBAL`/`GEBDRE` | Somente leitura (nenhuma escrita) |

### 5.6 Regras + mensagens

| Regra | Mensagem |
|-------|----------|
| Migração | `GEBCMIG criando GC1-GC4 em geban.db` |
| Lançamento | `CTB <origem> <valor>` / `CTBGRV <lote> <tipo>` / `CTB desbalanceado <lote>` / `CTB stub <origem> <valor>` |
| Direta | `DIR <lote> <valor>` / `DIR negado flag|perfil|GC4|mentor` |
| Balancete/DRE | `BAL <comp> <nContas>` / `DRE <comp> <resultado>` |
| Invariante: **débito = crédito** por lote (conferido em `CTBGRV`). DRE banânica: grupos `3` e `4` pelo 1º dígito da conta. |

### 5.7 Parâmetros GE4 + GC4 (contábil)

| Parâmetro | Onde | Valores | Default | Efeito |
|-----------|------|---------|---------|--------|
| `PERMITE_DIRETA` | GE4 (`GEBCFG`) | `S` / outro | `""` (= negado) | Trava 1 da direta + `GEBUSR` CAIXA |
| Mentor `LANC_DIRETO` | GE4 (`GEBMNT`) | `AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO` | libera sem BO | Trava 4 da direta |
| `LANC_DIRETO` | GC4 (`GC4_PERM`) | `S` / `N` | ausente = libera | Trava 3 da direta |
| `PADRAO` + eventos | GC4 (`CTADEB/CTACRED`) | contas GC1 | `PADRAO 1.01.001/3.01.001` | Origem → contas do `CTBLAN` |
| `APURACAO=DIRETA` | GE4 | `DIRETA` | `AUTO` | Só muda o log de `GEBFAPU`; quem grava `DIRETO` é `GEBCDIR` |

**Nenhum caminho pula `CTBLAN`/`CTBGRV`** — muda só quem inicia (AUTO via origem, DIRETO via `GEBCDIR` com carimbo).

---

## 6. MÓDULO FINANCEIRO (GFN1–GFN4)

**Fontes:** `src/GEBFIN_MIG.prw` (`GEBFNMIG`, `GEBFNCON`), `src/GEBFIN_CON.prw` (`GEBFNREC`, `GEBFNPAG`),
`src/GEBFIN_BAI.prw` (`GEBFNBAI`), `src/GEBFIN_FLX.prw` (`GEBNFLX`)
**Tabelas:** GFN1 contas (`CONTA/NOME/SALDO`), GFN2 receber (`DOC/CLI/VALOR/SALDO/VENC/STATUS ABERTO/RECEBIDA`),
GFN3 pagar (`DOC/FORN/VALOR/SALDO/VENC/STATUS ABERTO/PAGA`), GFN4 movimento (`CONTA=CAIXA/TIPO/VALOR/DATA DToS`).

### 6.1 Atores

| Ator | Papel |
|------|-------|
| Caixa / Financeiro | Cria conta (`GEBFNCON`), lança receber/pagar, baixa, consulta fluxo |
| Mentor | `PAG_IMPULSIVO` trava lançamento **e** baixa de pagar (receber nunca trava) |
| Compras (`GEBCMENT`) | Consome `GEBFNPAG(cNF, cForn, nTotal, "20261231")` na entrada |
| Contábil (`CTBLAN`) | Cada `GEBFNBAI` concilia via `CTBLAN(cDoc, nEfetivo)` (stub compat se GC4 ausente) |

### 6.2 Pré-condições

1. `GEBFNMIG()` executada (GFN1–GFN4 idempotentes, índices `GFN*_FILIAL_*`).
2. Conta: `cConta` não vazio + GFN1 existe (senão `.F.`); idempotente (existente → `.T.` sem duplicar).
3. Lançamento: `cDoc` não vazio, `nValor > 0`, tabela GFN2/GFN3 existe, DOC sem duplicata ativa na filial;
   `dVenc` aceita `Date` (via `DToS`) ou texto `YYYYMMDD`.
4. Baixa: `cTipo` em `REC/RECEBER/PAG/PAGAR` (case/space-insensitive via `Upper(AllTrim())`),
   `cDoc` não vazio, `nValor > 0`, título existe com `SALDO > 0`.
5. Fluxo: nenhuma (tabelas ausentes valem zero, sem abortar).

### 6.3 Fluxo principal (numerado)

1. `GEBFNMIG()` cria GFN1–GFN4 + índices → `.T.` (qualquer `CREATE` falha → `.F.`).
2. `GEBFNCON(cConta, cNome)`: guarda vazio/ausência → `.F.`; existente → `CON existe <conta>`, `.T.`;
   senão insere GFN1 (`SALDO=0`) → `CON <conta>`, `.T.`.
3. `GEBFNREC(cDoc, cCli, nValor, dVenc)`: guardas → `.F.`; duplicata → `REC duplicado <doc>`, `.F.`;
   senão insere GFN2 (`SALDO=VALOR, STATUS=ABERTO`) → `REC <doc> <valor>`, `.T.`.
4. `GEBFNPAG(cDoc, cForn, nValor, dVenc)`: guardas → `.F.`; `GEBMNT("PAG_IMPULSIVO")=.F.` →
   `PAG bloqueado <doc>`, `.F.` sem tocar o banco; duplicata → `PAG duplicado <doc>`, `.F.`;
   senão insere GFN3 (`SALDO=VALOR, ABERTO`) → `PAG <doc> <valor>`, `.T.`.
5. `GEBFNBAI(cTipo, cDoc, nValor)`: tipo inválido/vazio/zerado → `.F.`; pagar com mentor travado →
   `BAI bloqueada <doc>`, `.F.`; título inexistente/zerado → `.F.`;
   senão `SALDO -= min(nValor, SALDO)` (`RecLock(.F.)`): zerou → `RECEBIDA` (receber) / `PAGA` (pagar),
   parcial mantém `ABERTO`; depois `GravMOV` (GFN4 `CAIXA/TIPO/VALOR/hoje` + GFN1 `CAIXA += sinal×valor`,
   `+1` receber / `−1` pagar, só se `CAIXA` existir) + `CTBLAN(cDoc, nEfetivo)` →
   `BAI <tipo> <doc> <efetivo>`, `.T.`. Pago a maior quita (limita ao saldo).
6. `GEBNFLX()`: soma `SALDO` com `STATUS=ABERTO` em GFN2/GFN3 (quitados `RECEBIDA`/`PAGA`
   fora da soma) → `{nRec, nPag, nRec−nPag}` + `FLX <rec> <pag>`. Tabelas ausentes = zero.

### 6.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| FN-A1 | Offline / fila | Financeiro não enfileira em GE5; conciliação `CTBLAN` é stub se GC4 ausente (`.T.` sem gravar) |
| FN-A2 | Trava mentor | `PAG_IMPULSIVO=AVISA_E_TRAVA` → `GEBFNPAG` e `GEBFNBAI(PAG)` recusam `.F.` sem tocar o banco (com BO: `GEBAUD` + libera); receber/baixa de receber nunca passam pelo mentor |
| FN-A3 | Sem estoque | Não se aplica (ver ESTOQ_VENDA / COMPRAS entrada movimenta `GEBVEST`) |
| FN-A4 | Inadimplência | Baixa parcial mantém `ABERTO`; `GEBNFLX` reflete o saldo em aberto; sem protesto neste módulo |
| FN-A5 | Duplicata / guardas | DOC duplicado, vazio, `≤ 0`, tipo inválido, tabela ausente, título inexistente → `.F.` sem gravar |
| FN-A6 | Pago a maior | `nEfetivo = min(nValor, SALDO)`; só o efetivo vai a GFN4/GFN1/`CTBLAN` |

### 6.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GEBFNMIG` | GFN1–GFN4 + índices |
| `GEBFNCON` | GFN1 (`CONTA, NOME, SALDO=0`) — idempotente |
| `GEBFNREC` | GFN2 (`DOC, CLI, VALOR, SALDO=VALOR, VENC, ABERTO`) |
| `GEBFNPAG` | GFN3 (`DOC, FORN, VALOR, SALDO=VALOR, VENC, ABERTO`) |
| `GEBFNBAI` | GFN2/GFN3: update `SALDO` + `STATUS` (`RECEBIDA`/`PAGA` se zerou); GFN4 (`CAIXA, TIPO, VALOR, DATA`); GFN1 `CAIXA` (`SALDO ± efetivo`); GC2/GC3 via `CTBLAN` |
| `GEBNFLX` | Somente leitura (nenhuma escrita) |

### 6.6 Regras + mensagens

| Regra | Mensagem (`ConOut`) |
|-------|---------------------|
| Migração | `GEBFNMIG criando GFN1-GFN4 em geban.db` |
| Conta | `CON <conta>` / `CON existe <conta>` |
| Receber | `REC <doc> <valor>` / `REC duplicado <doc>` |
| Pagar | `PAG <doc> <valor>` / `PAG duplicado <doc>` / `PAG bloqueado <doc>` |
| Baixa | `BAI <tipo> <doc> <efetivo>` / `BAI bloqueada <doc>` |
| Fluxo | `FLX <receber> <pagar>` |
| Vencimento: `Date` → `DToS`, texto gravado como está. `CAIXA` em GFN1/GFN4 é literal fixo (não parametrizado). |

### 6.7 Parâmetros GE4 (financeiro)

| Evento | Valores | Default | Efeito |
|--------|---------|---------|--------|
| Mentor `PAG_IMPULSIVO` | `AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO` | libera sem BO | Trava `GEBFNPAG` + `GEBFNBAI(PAG)`; receber/fluxo livres |

---

## 7. MÓDULO COMPRAS (GCP1–GCP5)

**Fontes:** `src/GEBCOM_MIG.prw` (`GEBCMMIG`), `src/GEBCOM_FOR.prw` (`GEBCMFOR`, `GEBCMCOT`, `GEBCMMEL`),
`src/GEBCOM_PED.prw` (`GEBCMPED`, `GEBCMIT`), `src/GEBCOM_ENT.prw` (`GEBCMENT`)
**Tabelas:** GCP1 fornecedor (`COD/NOME/CNPJ=""`), GCP2 cotação (`FORN/PROD/PRECO`),
GCP3 pedido header (`NUM/FORN/STATUS ABERTO/RECEBIDO`), GCP4 item (`PED/PROD/QTD/PRECO`),
GCP5 entrada (`NF/PED/STATUS RECEBIDA`).

### 7.1 Atores

| Ator | Papel |
|------|-------|
| Comprador | Cadastra fornecedor, cota, abre pedido, adiciona itens, recebe entrada |
| Mentor | `COMPRA_IMPULSIVA` trava abertura de pedido (itens/entrada não passam pelo mentor) |
| Estoque (`GEBVEST`) | Entrada movimenta cada item (`cProd, nQtd`) — cria com `MIN=10` se inexistente |
| Financeiro (`GEBFNPAG`) | Entrada lança `cNF` a pagar com vencimento fixo `"20261231"` |
| Contábil (`CTBLAN`) | Entrada concilia `CTBLAN(cNF, nTotal)` (stub compat se GC4 ausente) |

### 7.2 Pré-condições

1. `GEBCMMIG()` executada (GCP1–GCP5 idempotentes).
2. Fornecedor: `cCod`/`cNome` não vazios + GCP1 existe. Cotação: `cForn`/`cProd` não vazios,
   `nPreco > 0` + GCP2 existe. Menor preço: `cProd` não vazio + GCP2 existe (senão `0`).
3. Pedido: `cPed`/`cForn` não vazios + GCP3 existe. Item: `cPed`/`cProd` não vazios,
   `nQtd > 0`, `nPreco > 0` + GCP4/GCP3 existem + pedido existe em GCP3.
4. Entrada: `cNF`/`cPed` não vazios + GCP3/GCP4/GCP5 existem + pedido existe e não `RECEBIDO` +
   pedido com itens (`total > 0`) + NF sem duplicata em GCP5.

### 7.3 Fluxo principal (numerado)

1. `GEBCMMIG()` cria GCP1–GCP5 + índices → `.T.`/`.F.`.
2. `GEBCMFOR(cCod, cNome)`: vazio/ausente → `.F.`; existente → `FOR existe <cod>`, `.T.`;
   senão insere GCP1 (`CNPJ=""`) → `FOR <cod>`, `.T.`.
3. `GEBCMCOT(cForn, cProd, nPreco)`: guardas → `.F.`; senão insere GCP2 → `COT <prod> <preco>`, `.T.`
   (permite múltiplas cotações do mesmo produto/fornecedor; sem update).
4. `GEBCMMEL(cProd)`: vazio/ausente/sem cotação → `0`; senão menor `PRECO` ativo na filial →
   `MEL <prod> <menor>`.
5. `GEBCMPED(cPed, cForn)`: vazio/ausente → `BLOQUEADO`; `GEBMNT("COMPRA_IMPULSIVA")=.F.` →
   `PED bloqueado <ped>`, `BLOQUEADO` sem tocar o banco; existente → `PED existe <ped>`, `ABERTO`;
   senão insere GCP3 (`ABERTO`) → `PED ABERTO <ped>`, `ABERTO`.
6. `GEBCMIT(cPed, cProd, nQtd, nPreco)`: guardas/pedido inexistente → `.F.` (+ `ITEM sem pedido <ped>`);
   senão insere GCP4 → `ITEM <ped> <prod>`, `.T.`.
7. `GEBCMENT(cNF, cPed)`: guardas/pedido inexistente → `.F.` (+ `ENT sem pedido`);
   já `RECEBIDO` → `ENT ja recebida`, `.F.`; NF duplicada → `ENT duplicada`, `.F.`;
   sem itens → `ENT sem itens`, `.F.`; `GEBFNPAG(cNF, cForn, nTotal, "20261231")=.F.` →
   `ENT pag recusou`, `.F.` (mentor `PAG_IMPULSIVO` pode recusar aqui);
   senão `EntraEstoque` (cada item via `GEBVEST`) + `CTBLAN(cNF, nTotal)` + GCP3 → `RECEBIDO` +
   GCP5 (`NF, PED, RECEBIDA`) → `ENT RECEBIDA <nf> <total>`, `.T.`.
   `nTotal = Σ(QTD×PRECO)` dos itens ativos.

### 7.4 Fluxos alternativos

| ID | Cenário | Comportamento |
|----|---------|---------------|
| CP-A1 | Offline / fila | Compras não enfileira em GE5; `CTBLAN` stub se GC4 ausente; `GEBVEST` cria produto com `MIN=10` |
| CP-A2 | Trava mentor | `COMPRA_IMPULSIVA=AVISA_E_TRAVA` → pedido `BLOQUEADO` sem tocar o banco (com BO: `GEBAUD` + libera); entrada herda trava indireta via `GEBFNPAG` (`PAG_IMPULSIVO`) |
| CP-A3 | Sem estoque | Não bloqueia: entrada **soma** estoque; `ESTOQUE_MINIMO` só alerta em `GEBVEST` |
| CP-A4 | Inadimplência | Entrada sempre gera título a pagar (`ABERTO`); inadimplência aparece no fluxo financeiro |
| CP-A5 | Duplicatas/guardas | Fornecedor existente → `.T.` idempotente; NF duplicada, pedido `RECEBIDO`, sem itens, item sem pedido → `.F.` |
| CP-A6 | Vencimento fixo | Entrada lança pagar com `VENC="20261231"` (literal fixo, não parametrizado) |

### 7.5 Pós-condições (tabelas gravadas)

| Função | Grava |
|--------|-------|
| `GEBCMMIG` | GCP1–GCP5 + índices |
| `GEBCMFOR` | GCP1 (`COD, NOME, CNPJ=""`) — idempotente |
| `GEBCMCOT` | GCP2 (`FORN, PROD, PRECO`) — sempre insert |
| `GEBCMPED` | GCP3 (`NUM, FORN, ABERTO`) — idempotente |
| `GEBCMIT` | GCP4 (`PED, PROD, QTD, PRECO`) |
| `GEBCMENT` | GFN3 (título pagar `NF/FORN/TOTAL/ABERTO` via `GEBFNPAG`); GV1 (soma por item via `GEBVEST`); GCP3 → `RECEBIDO`; GCP5 (`NF, PED, RECEBIDA`); GC2/GC3 via `CTBLAN` |

### 7.6 Regras + mensagens

| Regra | Mensagem |
|-------|----------|
| Migração | `GEBCMMIG criando GCP1-GCP5 em geban.db` |
| Fornecedor | `FOR <cod>` / `FOR existe <cod>` |
| Cotação/menor | `COT <prod> <preco>` / `MEL <prod> <menor>` |
| Pedido/item | `PED ABERTO <ped>` / `PED existe <ped>` / `PED bloqueado <ped>` / `ITEM <ped> <prod>` / `ITEM sem pedido <ped>` |
| Entrada | `ENT RECEBIDA <nf> <total>` / `ENT sem pedido <ped>` / `ENT ja recebida <ped>` / `ENT duplicada <nf>` / `ENT sem itens <ped>` / `ENT pag recusou <nf>` |

### 7.7 Parâmetros GE4 (compras)

| Evento | Valores | Default | Efeito |
|--------|---------|---------|--------|
| Mentor `COMPRA_IMPULSIVA` | `AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO` | libera sem BO | Trava `GEBCMPED` |
| Mentor `PAG_IMPULSIVO` (indireto) | idem | libera sem BO | Pode recusar `GEBCMENT` via `GEBFNPAG` |
| Mentor `ESTOQUE_MINIMO` (indireto) | idem | libera sem BO | `GEBVEST` só alerta na entrada, nunca trava |

---

## 8. Matriz requisitos → funções → testes

Planos: `documentacao interna`.
Convencao: testes `T_*` incluem os fontes e validam `check` + `run` + `rerun` + regressao, com `DELETE` cleanup.
Total: **46 testes** (25 legados + 5 FIN + 5 COM + 6 EXPANSAO + 5 GUI).

| Req (plano) | Funções (`src/`) | Testes (`tests/`) | Tabelas |
|-------------|------------------|-------------------|---------|
| NUCLEO T1: migração GE1–GE5 + `GEBCFG` | `GENMIG`, `GEBCFG` (`GENUC_MIG.prw`) | `T_GENUC_MIG.prw` | GE1–GE5 |
| NUCLEO T2: entrada + MenuDef | `GEBAN`, `MenuDef` (`GEBAN.prw`) | `T_GEBAN_MENU.prw` | — (lê via `GENMIG`) |
| NUCLEO T3: empresas/usuários/auditoria | `GEBAUD`, `GEBUSR`, `GEBCAD` (`GENUC_CAD.prw`) | `T_GENUC_CAD.prw` | GE1, GE2, GE3 |
| NUCLEO T4: mentor + fila + CTB stub/real | `GEBMNT`, `GEBFILA`, `CTBLAN`, `CTBGRV` (`GENUC_MNT.prw`) | `T_GENUC_MNT.prw` | GE4, GE5, GC2–GC4 |
| NUCLEO T5: massa 100 + serve | (todas acima) | `T_GEBAN_MASSA.prw` (100× `GEBAUD` + `GEBFILA` round-trip) | GE3, GE5 |
| FISCAL T1: GF1–GF6 + cálculo | `GEBFMIG`, `CALCIBS`, `ALIQF` (`GEBFIS_MIG.prw`) | `T_GEBFIS_MIG.prw` | GF1–GF6 |
| FISCAL T2: produto + alíquotas | `GEBFPRO`, `GEBFALI` (`GEBFIS_CAD.prw`) | `T_GEBFIS_CAD.prw` | GF1, GF2 |
| FISCAL T3: emissão + split | `GEBFEMI`, `GEBFSPL` (`GEBFIS_EMI.prw`) | `T_GEBFIS_EMI.prw` | GF3, GF4, GE5, GC2/GC3 |
| FISCAL T4: apuração + créditos | `GEBFAPU`, `GEBFCRE` (`GEBFIS_APU.prw`) | `T_GEBFIS_APU.prw` (2 notas base 2500 → GF5 DEB 375; GF6 2 linhas) | GF5, GF6 (+GF3/GF4/GE1) |
| FISCAL T5: massa 100 notas + serve | (todas fiscal) | `T_GEBFIS_MASSA.prw` (mix Simples/Regular + apuração) | GF1–GF6 |
| DERRAMA T1: mig GD1–GD3 | `GEBDMIG` (`GEBDER_MIG.prw`) | `T_GEBDER_MIG.prw` | GD1–GD3 |
| DERRAMA T2: gera guia da GF5 | `GEBDGER` (`GEBDER_GUI.prw`) | `T_GEBDER_GUI.prw` | GF5 → GD1 |
| DERRAMA T3: juros/multa + parcela + protesto | `GEBDJUR`, `GEBDPAR`, `GEBDPRO` (`GEBDER_COB.prw`) | `T_GEBDER_COB.prw` | GD1, GD2, GD3 |
| DERRAMA T4: baixa/concilia + CTBLAN | `GEBDBAI` (`GEBDER_BAI.prw`) | `T_GEBDER_BAI.prw` | GD1 → GC2/GC3 |
| DERRAMA T5: massa 50 guias | (todas derrama) | `T_GEBDER_MASSA.prw` | GD1–GD3 |
| ESTOQ T1: mig GV1–GV3 | `GEBVMIG` (`GEBV_MIG.prw`) | `T_GEBV_MIG.prw` | GV1–GV3 |
| ESTOQ T2: saldo/movimento + mínimo | `GEBVEST` (`GEBV_EST.prw`) | `T_GEBV_EST.prw` | GV1 |
| ESTOQ T3: venda guiada | `GEBVVEN` (`GEBV_VEN.prw`) | `T_GEBV_VEN.prw` | GV1, GV2 (+GF3/GF4/GC2/GC3) |
| ESTOQ T4: fiado limite/juros | `GEBVFIA`, `GEBVJUR` (`GEBV_FIA.prw`) | `T_GEBV_FIA.prw` | GV3 |
| ESTOQ T5: massa 100 vendas | (todas estoq/venda) | `T_GEBV_MASSA.prw` | GV1–GV3 |
| CTB T1: mig GC1–GC4 + seeds | `GEBCMIG` (`GEBCTB_MIG.prw`) | `T_GEBCTB_MIG.prw` | GC1–GC4 |
| CTB T2: `CTBLAN` real + compat stub | `CTBLAN`, `CTBGRV` (`GENUC_MNT.prw`) | `T_GEBCTB_CTB.prw` | GC2, GC3 (via GC4) |
| CTB T3: lançamento direto 4 travas | `GEBCDIR` (`GEBCTB_DIR.prw`) | `T_GEBCTB_DIR.prw` | GC2, GC3 (+GE2/GE4/GC4) |
| CTB T4: balancete + DRE | `GEBBAL`, `GEBDRE` (`GEBCTB_BAL.prw`) | `T_GEBCTB_BAL.prw` | GC2, GC3 (leitura) |
| CTB T5: massa 200 lançamentos | (todas contábil) | `T_GEBCTB_MASSA.prw` (100 `CTBLAN` + 100 `DIR`, DRE 500) | GC1–GC4 |
| FIN T1: mig GFN1–GFN4 + conta | `GEBFNMIG`, `GEBFNCON` (`GEBFIN_MIG.prw`) | `T_GEBFIN_MIG.prw` (round-trip `CX_T1_RT` + `DELETE`) | GFN1–GFN4 |
| FIN T2: contas + receber/pagar + mentor | `GEBFNCON`, `GEBFNREC`, `GEBFNPAG` (`GEBFIN_CON.prw` + `GEBFIN_MIG.prw`) | `T_GEBFIN_CON_LAN.prw` (`REC-T2-01` 500 `ABERTO`; duplicata/zero negados; `PAG_IMPULSIVO` trava) | GFN1, GFN2, GFN3 (+GE4) |
| FIN T3: baixa parcial/total + caixa + CTBLAN | `GEBFNBAI` (`GEBFIN_BAI.prw`) | `T_GEBFIN_BAI.prw` (`REC-T3-01` 500→300 `ABERTO`→0 `RECEBIDA`; `PAG-T3-01`→`PAGA`; GFN4 3×`CAIXA`; GFN1 `CAIXA`=200) | GFN2, GFN3 → GFN4, GFN1 (+GC2/GC3) |
| FIN T4: fluxo `{rec, pag, saldo}` | `GEBNFLX` (`GEBFIN_FLX.prw`) | `T_GEBFIN_FLX.prw` ({700,300,400} → baixa 100 → {600,300,300} → quita pagar → {600,0,600} → vazio {0,0,0}) | GFN2, GFN3 (leitura) |
| FIN T5: massa 100 títulos | (todas financeiro) | `T_GEBFIN_MASSA.prw` (50×`REC` 100 + 50×`PAG` 50; `FLX` {5000,2500,2500} → baixa total → {0,0,0}; `CAIXA`=2500; GFN4 100) | GFN1–GFN4 |
| COM T1: mig GCP1–GCP5 | `GEBCMMIG` (`GEBCOM_MIG.prw`) | `T_GEBCOM_MIG.prw` (idempotente 2× + `sqlite_master` GCP1/GCP5) | GCP1–GCP5 |
| COM T2: fornecedor + cotação + menor preço | `GEBCMFOR`, `GEBCMCOT`, `GEBCMMEL` (`GEBCOM_FOR.prw`) | `T_GEBCOM_FOR_COT.prw` (idempotente `F-T2-01`; cota 10/7 → `MEL`=7; miss=`0`; zero/vazio negados) | GCP1, GCP2 |
| COM T3: pedido + item + mentor | `GEBCMPED`, `GEBCMIT` (`GEBCOM_PED.prw`) | `T_GEBCOM_PED.prw` (`PED-T3-01` `ABERTO` idempotente; vazio/`COMPRA_IMPULSIVA`→`BLOQUEADO`; item sem pedido/qtd 0 negados) | GCP3, GCP4 (+GE4) |
| COM T4: entrada → estoque + pagar + CTBLAN | `GEBCMENT` (`GEBCOM_ENT.prw`) | `T_GEBCOM_ENT.prw` (`PED-T4-01` 5×10+2×20 → `NF-T4-01`; 2ª via/NF dup/sem pedido negadas; GCP3 `RECEBIDO`+GCP5+GFN3+GV1) | GCP3→`RECEBIDO`, GCP5, GFN3, GV1 (+GC2/GC3) |
| COM T5: massa 50 pedidos round-trip | (todas compras) | `T_GEBCOM_MASSA.prw` (50× pedido 2×10 + entrada; 50 GCP3 `RECEBIDO` + 50 GCP5 + 50 GFN3) | GCP1–GCP5, GFN3, GV1 |
| EXPANSAO T1: multi-empresa + GEH/GEI | `GEBEXPmig` (`GEBEXP_MIG.prw`) | `T_GeExp_MIG.prw` (verifica EMPRESA em 28 tabelas + GEH/GEI existentes) | GE1–GC4 + GEH + GEI |
| EXPANSAO T2: contexto sessao | `GEBEXPCONTEXTO`, `GEBEXPIST`, `GEBEXPCONTEXT`, `GEBEXPCLEAR` (`GEBEXP_CTX.prw`) | `T_GeExp_CTX.prw` (sessao A valida, sessao B falha, clear encerra) | GE2, GEH, GEX |
| EXPANSAO T3: web dashboard | `GEBEXP_WEB` (`GEBEXP_WEB.prw`) | `T_GeExp_WEB.prw` (8 asserts: context valido/invalido, dados empresa, resumo fin/fisc/mentor, GEBAN fluxo) | GE1, GE2, GEH, GEX, todas negocio |
| EXPANSAO T4: relatorios nucleo | `GEBRELEMPRESAS`, `GEBRELUSUARIOS`, `GEBRELAUDITORIA`, `GEBRELMENTOR`, `GEBRELCADASTROS` (`GEBEXP_REL_NUC.prw`) | `T_GeExp_REL_NUC.prw` (5 asserts: cada funcao retorna array nao vazio com campos corretos) | GE1, GE2, GEH, GE4, GF1, GCP1, GV3, GFN1 |
| EXPANSAO T5: relatorios negocio + trackers | `GEBRELFISCAL`, `GEBRELDERRAMA`, `GEBRELFIN`, `GEBRELSTOQUE`, `GEBRELCOMPRAS`, `GEBRELCONTABIL`, `GEBRELGERAL`, `GEBTRAKCOMPRA`, `GEBTRAKVENDA`, `GEBTRAKNOTAFISCAL`, `GEBTRAKDERRAMA` (`GEBEXP_REL_BIZ.prw` + `GEBEXP_TRAK.prw`) | `T_GeExp_REL_BIZ.prw` (11 asserts: cada relatorio retorna array com len correta + trackers rastreiam cadeia completa) | Todas negocio |
| EXPANSAO T6: massa multi-empresa | (todas expansao) | `T_GeExp_MASSA.prw` (3 empresas isoladas; 20 NFs cada + 5 guias + 10 pedidos + 10 CTB; `GEBRELGERAL` confere; 5 trackers validados) | Todas |
| GUI T1: validadores | 13 validadores (`GEBGUI_VLD.prw`) | `T_GEBGUI_VLD.prw` (migracoes + todos validadores valid/invalido/miss) | Todas |
| GUI T2: menu terminal | `GEBGUIMAIN` (`GEBGUI_MAIN.prw`) | `T_GEBGUI_MAIN.prw` (MENU e CONFIG modos; 2/2 passam) | — |
| GUI T3: browses | 17 browses (`GEBGUI_BRW.prw`) | `T_GEBGUI_BRW.prw` (GEBGUIMENU + 17 BRW_* criam alias sem erro) | Todas |
| GUI T4: configuracao | `GEBGUICONF_*`, `GEBGUIMIG` (`GEBGUI_CFG.prw`) | `T_GEBGUI_CFG.prw` (SHOW, PARAM EMISSAO/APURACAO, ALIQ, CAD_*, RESUMO; GEBGUIMIG cria SC/LC) | GE4, GEBGUICONFIG_SC/LC |
| GUI T5: integracao | GEBGUIMAIN + migracoes + operacoes | `T_GEBGUI_INTEG.prw` (fluxo end-to-end: nucleo → fiscal → derrama → estoque → contabil → fin → compras → fluxo) | Todas |

## 9. MÓDULO GUI — Interface (GEBGUI_*.prw)

**Fontes:** `src/GEBGUI_VLD.prw` (validadores), `src/GEBGUI_MNU.prw` (menu),
`src/GEBGUI_BRW.prw` (browses), `src/GEBGUI_CFG.prw` (configuracao),
`src/GEBGUI_MAIN.prw` (entrada terminal)
**Tabelas:** GE1–GC4 (leitura via workarea), GEBGUICONFIG_SC, GEBGUICONFIG_LC (escrita).

### 9.1 Validadores centrais (`GEBGUI_VLD.prw`)

| Funcao | Tabela | Regra | Retorna |
|--------|--------|-------|---------|
| `GEBGUIPROD_CK(cCod)` | GF1 | Produto existe, ativo, na filial | `.T.`/`.F.` |
| `GEBGUIFORN_CK(cCod)` | GCP1 | Fornecedor existe, ativo, na filial | `.T.`/`.F.` |
| `GEBGUICLI_CK(cCod)` | GV3 | Cliente/fiado existe, ativo, na filial | `.T.`/`.F.` |
| `GEBGUIPROD_EST(cProd, nQtd)` | GV1 | Estoque >= qtd; alerta minimo se < MIN | `.T.`/`.F.` |
| `GEBGUIFIADO_LIM(cCli, nValor)` | GV3 | Soma ABERTA + novo <= 1000 | `.T.`/`.F.` |
| `GEBGUIFIN_BAI(cTipo, cDoc, nValor)` | GFN2/GFN3 | Tipo REC/PAG valido; doc existe; saldo >= valor; delega `GEBFNBAI` | `.T.`/`.F.` |
| `GEBGUIFIN_FLX()` | GFN2+GFN3 | Retorna `{rec, pag, saldo}` | Array 3 |
| `GEBGUIFIS_EMI(cChave, cCod, nQtd, nPreco)` | GF1+GF3+GF4 | Params nao vazios, qtd/preco > 0; delega `GEBFEMI` | `.T.`/`.F.` |
| `GEBGUIFIS_APU(cComp)` | GF3+GF4+GF5 | Comp nao vazio; delega `GEBFAPU` | `.T.`/`.F.` |
| `GEBGUIFIS_GER(cComp)` | GF5+GD1 | Comp nao vazio; delega `GEBDGER` | `cGuia`/`""` |
| `GEBGUICTB_DIR(cCli, cContaD, cContaC, nValor)` | GC4 | Flag PERMITE_DIRETA==`"S"`; delega `GEBCDIR` | `.T.`/`.F.` |
| `GEBGUICONFIG_LC(cChave)` | GE4 | Leitura via `GEBCFG` | `cValor` |
| `GEBGUICONFIG_SC(cChave, cValor)` | GE4 | Upsert: update se existir, insert se nao | `.T.`/`.F.` |

### 9.2 Menu terminal (`GEBGUI_MAIN.prw`)

`GEBGUIMAIN(cModo)` orquestra menu numerado 1–9 via ConOut/ConIn. Cada opcao chama handler static que executa a migracao do modulo. Modos: `"MENU"` (padrao, iterativo) e `"CONFIG"` (abre configuracoes rapidas). Retorno `.T.` se sem erro.

```
1 - Nucleo      → GEBGUINUC()     → GENMIG + GEBFMIG
2 - Fiscal      → GEBGUIFIS()     → GEBFMIG
3 - Derrama     → GEBGUIDER()     → GEBDMIG
4 - Estoque     → GEBGUIEST()     → GEBVMIG
5 - Contabil    → GEBGUICtb()     → GEBCMIG
6 - Financeiro  → GEBGUIFIN()     → GEBFNMIG
7 - Compras     → GEBGUICOM()     → GEBCMMIG
8 - Configurac. → GEBGUICFG()     → GEBCFG leitura
9 - Sair        → encerra
```

### 9.3 Browses (`GEBGUI_BRW.prw`)

17 funcoes `BRW_*` criam `FWMBrowse` sobre cada tabela. Cada uma guarda existencia via `sqlite_master`; se tabela ausente retorna `.F.` com log. Alias e Description configurados; Activate/Destroy pulados no modo balisador (requerem `advplc serve`).

Tabelas mapeadas: GE1, GE2, GF1, GF2, GF3, GF5, GD1, GV1, GV2, GFN1, GFN2, GFN3, GFN4, GCP1, GCP3, GC1, GC3.

### 9.4 Configuracao (`GEBGUI_CFG.prw`)

- `GEBGUICONF_SHOW`: exibe secoes navegaveis (parametros, alíquota, cadastro rapido, ajuda).
- `GEBGUICONF_PARAM(cSeccao)`: garante linha em GE4 com valor padrao (`ONLINE_FILA`, `AUTO`, `N`, `AVISA_E_LIBERA_COM_BO`).
- `GEBGUICONF_ALIQ(cNCM)`: mostra alíquota vigente + exemplo calculo.
- `GEBGUICONF_CAD_*`: stubs para cadastros rapidos (GE1, GE2, GF1, GCP1, GFN1).
- `GEBGUICONF_RESUMO`: dashboard numerico (`GEBNFLX` + `GEBBAL` + `GEBDRE`).
- `GEBGUIMIG`: cria tabelas `GEBGUICONFIG_SC` (char) e `GEBGUICONFIG_LC` (logical) com indices.

---

## 10. MÓDULO EXPANSAO — Multi-empresa (GEBEXP_*.prw)

**Fontes:** `src/GEBEXP_MIG.prw`, `src/GEBEXP_CTX.prw`, `src/GEBEXP_REL_BIZ.prw`,
`src/GEBEXP_TRAK.prw`, `src/GEBEXP_WEB.prw`, `src/GEBEXP_REL_NUC.prw`
**Tabelas novas:** `GEH` (historico acesso), `GEI` (audit log), `GEX` (contexto sessao),
`GEBGUICONFIG_SC`, `GEBGUICONFIG_LC`.

### 10.1 Migracao multi-empresa (`GEBEXP_MIG`)

`GEBEXPmig()` adiciona coluna `EMPRESA CHAR(02) DEFAULT '  '` a todas as 28 tabelas existentes (`GE1`–`GC4`) via `ALTER TABLE IF EXISTS`. Cria `GEH` (indice `GEH_DATA_USU`) e `GEI` (indice `GEI_TABELA_REG`) se nao existirem. Idempotente: skip se coluna/tabela ja existe. Retorna `.T.` se todas as operacoes OK, `.F.` se qualquer uma falhar.

### 10.2 Contexto de sessao (`GEBEXP_CTX`)

- `GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)`: valida triplete em GE2 via `TCSqlQuery SELECT *` (porque `COUNT(*)` sempre retorna Len≥1); grava GEH (data/hora/usuario/empresa/acao/ip); armazena em `GEX` (linha unica ativa, limpa anteriores). Retorna `.T.` se sucesso.
- `GEBEXPIST()`: workarea em GEX, procura linha com `D_E_L_E_T_=' '` → `.T.` se encontrada.
- `GEBEXPCONTEXT()`: workarea em GEX, retorna `{empresa, filial, usuario}` ou `{"","",""}`.
- `GEBEXPCLEAR()`: remove linha ativa de GEX (`DELETE WHERE D_E_L_E_T_=' '`).
- `GEXBINIT()`: funcao auxiliar de teste que cria GEH e GEX se ausentes.

**Nota tecnica:** colunas `EMPRESA` adicionadas via `ALTER TABLE` **não aparecem em workarea** (`GEX->EMPRESA` retorna Nil). Por isso, a validacao de usuario usa `TCSqlQuery` direto; workarea so eh usado para GEX (criada no proprio modulo, sem ALTER posterior).

### 10.3 Relatorios nucleo (`GEBEXP_REL_NUC`)

| Funcao | Retorno | Fonte |
|--------|---------|-------|
| `GEBRELEMPRESAS()` | `{{COD, NOME, NUSUARIOS, NREGRE}, ...}` | GE1 (catalogo) + COUNT DISTINCT em GE2_EMP (catalogo) por empresa + COUNT de GE3 por tenant |
| `GEBRELUSUARIOS(cEmpresa)` | `{{COD, NOME, PERFIL}, ...}` | GE2_EMP (catalogo) filtrado por empresa, juntado a GE2 |
| `GEBRELAUDITORIA(cEmpresa, cInicio, cFim)` | `{{DATA, HORA, USUARIO, FUNCAO, IP}, ...}` | GEH ordenado DESC |
| `GEBRELMENTOR(cEmpresa)` | `{{evento, modo}, ...}` | GE4 filtrado por empresa |
| `GEBRELCADASTROS(cEmpresa)` | `{nProd, nForn, nCli, nCont}` | COUNT em GF1, GCP1, GV3, GFN1 |

### 10.4 Relatorios negocio (`GEBEXP_REL_BIZ`)

| Funcao | Retorno | O que agrega |
|--------|---------|-------------|
| `GEBRELFISCAL(cEmpresa, cComp)` | `{nNotas, nBase, nIBS, nCBS, nDeb, nCred, nSaldo, nApur, cRegime}` | GF3 + GF5 por competncia |
| `GEBRELDERRAMA(cEmpresa, cComp)` | `{nGuias, nPagas, nVencidas, nValTot, nParc, nProv}` | GD1/GD2/GD3 |
| `GEBRELFIN(cEmpresa)` | `{nContas, nRec, nPag, nValRec, nValPag, nSaldo, nMov}` | GFN1–GFN4 ABERTO |
| `GEBRELSTOQUE(cEmpresa)` | `{nProd, nBaixMin, nValTot, nMov}` | GV1 +GV2 |
| `GEBRELCOMPRAS(cEmpresa)` | `{nForn, nPed, nRecb, nValTot, nCot}` | GCP1–GCP4 |
| `GEBRELCONTABIL(cEmpresa, cComp)` | `{nLan, nDec, nCred, valDec, valCred, nSaldo}` | GC2/GC3 por lote |
| `GEBRELGERAL(cEmpresa)` | `{aFiscal, aDerrama, aFin, aEstoque, aCompras, aContabil}` | Consolidado de todos |

### 10.5 Trackers (`GEBEXP_TRAK`)

Cada tracker retorna `array` de `arrays`, uma posicao por etapa do fluxo. Linhas ausentes sao arrays vazios.

| Funcao | Cadeia rastreada |
|--------|----------------|
| `GEBTRAKCOMPRA(cPedido)` | GCP3 → GCP4 → GCP5 → GV1 → GFN3 → GC3 |
| `GEBTRAKVENDA(cVenda)` | GV2 → GV1 → GFN2 → GC3 |
| `GEBTRAKNOTAFISCAL(cChave)` | GF3 → GF4 → calculo → GFN2 → GF5 → GD1 |
| `GEBTRAKDERRAMA(cGuia)` | GF5 → GD1 → GD2 → GD3 → GFN3 → GFN4 → GC3 |

### 10.6 Dashboard web (`GEBEXP_WEB`)

`GEBEXP_WEB(cEmpresa, cUsuario)`:
1. Chama `GEBEXPCONTEXTO` — falha ⇒ `.F.`.
2. Busca GE1 (nome), GE4 (`REGIME`), GCP1 (CNPJ ficticio se vazio).
3. Exibe dashboard com: dados empresa, resumo financeiro (`GEBRELFIN`), resumo fiscal (`GEBRELFISCAL`), alertas mentor (`GEBRELMENTOR`), acoes rapidas 1–9.
4. Retorna `.T.` se dashboard exibido com sucesso.

- Fluxos `EMISSAO`/`APURACAO` configuráveis via GE4: **implementado** (§2.7; `DIRETA` só muda log — direta real é `GEBCDIR`).
- Misto online/fila offline GE5: **implementado** (emissão; fila `PENDENTE`, retry exponencial é futuro).
- Mentor B (`AVISA_E_LIBERA_COM_BO` com BO auditado em GE3): **implementado** como um dos 3 modos por evento.
- Derrama com parcelamento/protesto: **implementado** (GD2/GD3 + juros banânicos).
- Simples + Regular com split/transferência/ressarcimento: **implementado**
  (regime via `GE1_NOME`, `GEBFSPL`, `GEBFCRE TRANSF/RESSARC`).
- `GEB_CONTABIL` com `CTBLAN` + flag `PERMITE_DIRETA` configurável: **implementado** (4 travas + carimbo `DIRETO`).
- `GEB_FIN` (GFN1–GFN4): **implementado** (§6; contas + receber/pagar com anti-duplicata,
  baixa parcial/total com `RECEBIDA`/`PAGA` + GFN4/GFN1 `CAIXA` + `CTBLAN`, fluxo `{rec,pag,saldo}` só `ABERTO`,
  mentor `PAG_IMPULSIVO` trava pagar; 5 testes `T_GEBFIN_*`, massa 100 títulos).
- `GEB_COM` (GCP1–GCP5): **implementado** (§7; fornecedor idempotente + cotação + menor preço,
  pedido `ABERTO`/`BLOQUEADO` + item, entrada soma itens → `GEBFNPAG` venc `20261231` + `GEBVEST` +
  `CTBLAN` + `RECEBIDO`/`RECEBIDA`, mentor `COMPRA_IMPULSIVA`; 5 testes `T_GEBCOM_*`, massa 50 pedidos).
- MVP MEI (NF-e/NFS-e IBS/CBS + quitar DARF-CBS): **implementado** com mock SEFAZ (SEFAZ real/ISeedFaz futuro).
