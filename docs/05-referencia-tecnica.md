# 05 — Referência Técnica Completa do ERP GEBAN

> **Autor:** Peder Munksgaard · **Data:** 26/09/2026 · **Idioma:** PT-BR
> **Fontes primárias:** `src/*.prw` (83 arquivos, 590 `User Function` — todas catalogadas na seção 8,
> gerada por `scripts/doc-funcoes.py`), `docs/02-regras-negocio.md`, planos e ledgers em `documentacao interna`.
> **Estado verificado (21/11/2026):** suíte completa **89/89 PASS** contra Postgres real sob o runtime
> **AdvPP advplc v4.8.5**. Interface em componentes PO-UI (`src/GEBTUI.prw`), todas as operações
> em formulários de tela única.
> PDFs gerados com o template `jmpm` (`md2pdf.py --template jmpm --cover`).

---

## 1. Visão geral

O GEBAN é o ERP da fictícia República das Bananias: monolito modular em **AdvPL** (`.prw`,
encoding CP-1252, `#include "totvs.ch"`, só `User`/`Static Function`, notação húngara) sobre
**Postgres multi-tenant**, compilado e executado pelo runtime próprio **AdvPP** (`advplc
check/run/serve/build`). Entradas: `advplc serve src/GEBTUI.prw` (interface web PO-UI, porta 8081), `advplc run src/GEBWEB.prw` (API REST, porta 8090) e `advplc run src/GEBSCHJOB.prw` (agendador, a cada minuto).
Ordem de construção dos 9 subprojetos:

```
GEB_NUCLEO → GEB_FISCAL → GEB_DERRAMA → GEB_ESTOQ_VENDA → GEB_CONTABIL
    → GEB_FIN → GEB_COM → GEB_EXPANSAO → GEB_TUI (+ GEB_SEGURANCA e GEB_REST transversais)
```

Regra de ouro que atravessa todos os módulos: **nenhum caminho pula o contábil** — toda
mutação de valor passa pelo lançamento padrão do seu evento (`GEBCTXLP`; o `CTBLAN()` antigo
continua para quem o chama pelo nome do evento — ver docs/02 §20), e todo caminho grava com `GetArea()`/`RestArea()`, `RecLock()`+`MsUnlock()`,
filtro de filial e `D_E_L_E_T_ = ' '` (soft-delete Protheus).

## 2. Arquitetura de dados multi-tenant

- **Um schema Postgres por empresa** (`emp_<código em minúsculas>`) com as tabelas de
  módulo: `GE3–GE5`, `GF1–GF6`, `GD1–GD3`, `GV1–GV3`, `GFN1–GFN4`, `GCP1–GCP5`, `GC1–GC4`,
  `GEF1` (filiais), `GEU1` (unidades), `GEH`/`GEI` (auditoria), `GEX` (sessão).
- **Catálogo compartilhado** no schema `public`: `GE1` (empresas), `GE2` (usuários),
  `GE2_SEC` (credenciais: salt/hash/failcnt/lock), `GE2_TOK` (tokens), `GE2_EMP`
  (vínculo usuário↔empresa↔filial, many-to-many), `SEC_PERM` (RBAC), `SEC_MON`,
  `SEC_ADMIN_SESSION`.
- Conexão: `GEBDBConecta()` lê `GEBAN_PG_HOST/PORT/DB/USER/PASSWORD` do ambiente e ativa
  `DBSetDriver("TOPCONN")`. Troca de tenant: `GEBDBSetTenant(cCod)` **só aceita empresa
  com schema provisionado** (regra estrita anti-vazamento); `GEBDBProvisionaEmpresa()`
  cria o schema, roda todas as MIGs e registra em `GE1` — empresa criada já nasce utilizável.
- Modelo de filiais **EEUUFF** (decisão 25/09/2026): filial = 6 chars `EE+UU+FF`, `EE` igual
  aos 2 primeiros da empresa; cadastro `GEF1` por tenant; vínculo triplo `GE2_EMP`;
  filial vazia vale se houver vínculo; filial é identidade de sessão, dados ainda não são
  filtrados por filial.

## 3. Convenções e padrões mandatórios (resumo operacional)

Notação húngara (`c/n/d/l/a/o/b/x/j`); `Local` no topo, nunca após executável; `User
Function` (externa) vs `Static Function` (interna); sem `IIF()`, sem `Function` bare, sem
`SELECT *`, sem concatenação SQL (macros `%table:`, `%notDel%`, `%xfilial:`, `%exp:` ou
`FWExecStatement`); sem UI dentro de transação; sem `ConOut` (só `FWLogMsg`/logging);
`%nolock%` em leitura; `RetSqlName()` em vez de hardcode `SIGA.*`; `FWxFilial()`,
`GetNewPar()`; `FWRest` para consumo REST; `AvKey()` para chaves; `GetNextAlias()` +
`DbCloseArea()`; `FWTemporaryTable` em vez de ISAM; `Destroy()` em vez de `FwFreeObj()`.
SonarQube: CA4000/CA1002/CA1000/CA1004 e segurança CA2050–CA2052. Toda API externa deve
ser validada antes do uso; toda geração fecha com gap analysis.

## 4. Inventário de tabelas (119 tabelas)

Gerado por `scripts/doc-tabelas.py` a partir das definições nos fontes (`CREATE TABLE`,
`BOTAB`, `SNTab` e `ALTER TABLE ... ADD COLUMN`). Toda tabela tem ainda `R_E_C_N_O_`
(identidade) e `D_E_L_E_T_` (exclusão lógica). As do catálogo (`GE1`, `GE2*`, `SEC_*`)
ficam no schema `public`; as demais, no schema de cada empresa.

| Tabela | Módulo | Conteúdo | Colunas |
|---|---|---|---|
| `GBC1` | Backoffice | — | `GBC1_FILIAL`, `GBC1_CONTA`, `GBC1_BANCO`, `GBC1_AGENCIA`, `GBC1_AGDV`, `GBC1_CC`, `GBC1_CCDV`, `GBC1_CARTEIRA`, `GBC1_CODEMP`, `GBC1_BENEF`, `GBC1_CNPJ`, `GBC1_LAYOUT`, `GBC1_MODAL` |
| `GBC2` | Backoffice | — | `GBC2_FILIAL`, `GBC2_DOC`, `GBC2_CONTA`, `GBC2_NN`, `GBC2_NNDV`, `GBC2_NNFULL`, `GBC2_VENC`, `GBC2_VALOR`, `GBC2_LINHA`, `GBC2_BARRAS`, `GBC2_STATUS`, `GBC2_REMESSA` |
| `GBC3` | Backoffice | — | `GBC3_FILIAL`, `GBC3_CONTA`, `GBC3_FITID`, `GBC3_DATA`, `GBC3_VALOR`, `GBC3_MEMO`, `GBC3_STATUS`, `GBC3_MOVRN` |
| `GBR1` | Backoffice | — | `GBR1_FILIAL`, `GBR1_ORDEM`, `GBR1_C1`, `GBR1_C2`, `GBR1_C3`, `GBR1_C4`, `GBR1_C5`, `GBR1_C6`, `GBR1_C7`, `GBR1_C8`, `GBR1_SESSAO` |
| `GBS1` | Backoffice | — | `GBS1_FILIAL`, `GBS1_CHAVE`, `GBS1_ULT` |
| `GC1` | Contábil | Plano de contas | `GC1_FILIAL`, `GC1_CONTA`, `GC1_NOME`, `GC1_TIPO` |
| `GC2` | Contábil | Lotes (`LOTE`, `ORIGEM`, `VALOR`, `COMP`, `TIPO AUTO/DIRETO`) / pernas `D` e `C` | `GC2_FILIAL`, `GC2_LOTE`, `GC2_ORIGEM`, `GC2_VALOR`, `GC2_DATA`, `GC2_COMP`, `GC2_TIPO` |
| `GC3` | Contábil | Lotes (`LOTE`, `ORIGEM`, `VALOR`, `COMP`, `TIPO AUTO/DIRETO`) / pernas `D` e `C` | `GC3_FILIAL`, `GC3_LOTE`, `GC3_DC`, `GC3_CONTA`, `GC3_VALOR` |
| `GC4` | Contábil | Parâmetros evento → conta débito/crédito (+ `LANC_DIRETO`) | `GC4_FILIAL`, `GC4_EVENTO`, `GC4_CTADEB`, `GC4_CTACRED`, `GC4_PERM` |
| `GCC1` | Backoffice | — | `GCC1_FILIAL`, `GCC1_COD`, `GCC1_DESC`, `GCC1_BLOQ` |
| `GCC2` | Backoffice | — | `GCC2_FILIAL`, `GCC2_COD`, `GCC2_CC`, `GCC2_PCT` |
| `GCP1` | Compras | Fornecedores (`COD`, `NOME`, `CNPJ`) | `GCP1_FILIAL`, `GCP1_COD`, `GCP1_NOME`, `GCP1_CNPJ` |
| `GCP2` | Compras | Cotações (`FORN`, `PROD`, `PRECO`) | `GCP2_FILIAL`, `GCP2_FORN`, `GCP2_PROD`, `GCP2_PRECO` |
| `GCP3` | Compras | Pedidos (`NUM`, `FORN`, `ABERTO/BLOQUEADO/RECEBIDO`) / itens | `GCP3_FILIAL`, `GCP3_NUM`, `GCP3_FORN`, `GCP3_STATUS` |
| `GCP4` | Compras | Pedidos (`NUM`, `FORN`, `ABERTO/BLOQUEADO/RECEBIDO`) / itens | `GCP4_FILIAL`, `GCP4_PED`, `GCP4_PROD`, `GCP4_QTD`, `GCP4_PRECO` |
| `GCP5` | Compras | Entradas (`NF`, `PED`, `RECEBIDA`) | `GCP5_FILIAL`, `GCP5_NF`, `GCP5_PED`, `GCP5_STATUS` |
| `GCQ1` | Backoffice | — | `GCQ1_FILIAL`, `GCQ1_NUM`, `GCQ1_PROD`, `GCQ1_QTD`, `GCQ1_NECESS`, `GCQ1_SOLIC`, `GCQ1_STATUS`, `GCQ1_PED` |
| `GCQ2` | Backoffice | — | `GCQ2_FILIAL`, `GCQ2_PED`, `GCQ2_COND`, `GCQ2_LOCAL`, `GCQ2_EMISSAO`, `GCQ2_TOTAL`, `GCQ2_LIB`, `GCQ2_APROV` |
| `GCQ3` | Backoffice | — | `GCQ3_FILIAL`, `GCQ3_PED`, `GCQ3_PROD`, `GCQ3_QTDREC` |
| `GCQ4` | Backoffice | — | `GCQ4_FILIAL`, `GCQ4_NF`, `GCQ4_FORN`, `GCQ4_PED`, `GCQ4_DATA`, `GCQ4_VALMERC`, `GCQ4_FRETE`, `GCQ4_TOTAL` |
| `GCQ5` | Backoffice | — | `GCQ5_FILIAL`, `GCQ5_NF`, `GCQ5_PROD`, `GCQ5_QTD`, `GCQ5_PRECO`, `GCQ5_FRETE`, `GCQ5_CUSTO`, `GCQ5_VALOR` |
| `GCQ6` | Backoffice | — | `GCQ6_FILIAL`, `GCQ6_DEV`, `GCQ6_NF`, `GCQ6_FORN`, `GCQ6_PROD`, `GCQ6_QTD`, `GCQ6_VALOR`, `GCQ6_DATA` |
| `GCQ7` | Backoffice | — | `GCQ7_FILIAL`, `GCQ7_NF`, `GCQ7_FORN`, `GCQ7_PROD`, `GCQ7_DATA`, `GCQ7_BASE`, `GCQ7_IBS`, `GCQ7_CBS` |
| `GCX1` | Backoffice | — | `GCX1_FILIAL`, `GCX1_LOTE`, `GCX1_CC` |
| `GD1` | Derrama | Guias | `GD1_FILIAL`, `GD1_GUIA`, `GD1_COMP`, `GD1_VALOR`, `GD1_JUROS`, `GD1_MULTA`, `GD1_TOTAL`, `GD1_STATUS` |
| `GD2` | Derrama | Parcelas (`PARC` 001–999) | `GD2_FILIAL`, `GD2_GUIA`, `GD2_PARC`, `GD2_VALOR`, `GD2_STATUS` |
| `GD3` | Derrama | Cobrança/protesto (`ACAO`, `DATA`, `STATUS`) | `GD3_FILIAL`, `GD3_GUIA`, `GD3_ACAO`, `GD3_DATA`, `GD3_STATUS` |
| `GD4` | Backoffice | — | `GD4_FILIAL`, `GD4_GUIA`, `GD4_TIPO`, `GD4_COMP`, `GD4_VENC`, `GD4_CTACTB`, `GD4_CREDOR` |
| `GDF1` | Dfe | — | `GDF1_FILIAL`, `GDF1_CNPJ`, `GDF1_IE`, `GDF1_IM`, `GDF1_CNAE`, `GDF1_RAZAO`, `GDF1_FANTASIA`, `GDF1_CRT`, `GDF1_LGR`, `GDF1_NRO`, `GDF1_CPL`, `GDF1_BAIRRO`, `GDF1_CMUN`, `GDF1_XMUN`, `GDF1_UF`, `GDF1_CEP`, `GDF1_FONE`, `GDF1_EMAIL` |
| `GDF2` | Dfe | — | `GDF2_FILIAL`, `GDF2_CNPJ`, `GDF2_TITULAR`, `GDF2_VALIDADE`, `GDF2_CERT`, `GDF2_KEY`, `GDF2_INSTALADO` |
| `GDF4` | Dfe | — | `GDF4_FILIAL`, `GDF4_PROD`, `GDF4_UNID`, `GDF4_GTIN`, `GDF4_CFOP`, `GDF4_CSOSN`, `GDF4_CST`, `GDF4_PICMS`, `GDF4_CEST`, `GDF4_ORIG`, `GDF4_PISCST`, `GDF4_COFCST`, `GDF4_PPIS`, `GDF4_PCOF` |
| `GDF5` | Dfe | — | `GDF5_FILIAL`, `GDF5_CHAVE`, `GDF5_MOD`, `GDF5_SERIE`, `GDF5_NNF`, `GDF5_TPEMIS`, `GDF5_TPAMB`, `GDF5_STATUS`, `GDF5_CSTAT`, `GDF5_MOTIVO`, `GDF5_PROT`, `GDF5_DHEMI`, `GDF5_DHAUT`, `GDF5_ORIGEM`, `GDF5_DOC`, `GDF5_VNF`, `GDF5_XML`, `GDF5_QR`, `GDF5_URLCH`, `GDF5_DEST`, `GDF5_CHORIG`, `GDF5_DATA`, `GDF5_XMLORIG` |
| `GDF6` | Dfe | — | `GDF6_FILIAL`, `GDF6_CHAVE`, `GDF6_TIPO`, `GDF6_SEQ`, `GDF6_CSTAT`, `GDF6_MOTIVO`, `GDF6_PROT`, `GDF6_DH`, `GDF6_JUST`, `GDF6_XML`, `GDF6_MOD`, `GDF6_SERIE`, `GDF6_NINI`, `GDF6_NFIM` |
| `GDF7` | Dfe | — | `GDF7_FILIAL`, `GDF7_TIPO`, `GDF7_COD`, `GDF7_DOC`, `GDF7_IE`, `GDF7_INDIE`, `GDF7_NOME`, `GDF7_LGR`, `GDF7_NRO`, `GDF7_CPL`, `GDF7_BAIRRO`, `GDF7_CMUN`, `GDF7_XMUN`, `GDF7_UF`, `GDF7_CEP`, `GDF7_FONE`, `GDF7_EMAIL` |
| `GDF8` | Dfe | — | `GDF8_FILIAL`, `GDF8_TIPO`, `GDF8_DOC`, `GDF8_PART`, `GDF8_CHAVE` |
| `GDFA` | Dfe | — | `GDFA_FILIAL`, `GDFA_PROD`, `GDFA_PREDBC`, `GDFA_MVA`, `GDFA_PICMSST`, `GDFA_PREDBCST` |
| `GDFB` | Dfe | — | `GDFB_FILIAL`, `GDFB_UF`, `GDFB_NCM`, `GDFB_EX`, `GDFB_NACF`, `GDFB_IMPF`, `GDFB_EST`, `GDFB_MUN`, `GDFB_INI`, `GDFB_FIM`, `GDFB_VERSAO`, `GDFB_FONTE` |
| `GDFC` | Dfe | — | `GDFC_FILIAL`, `GDFC_COD`, `GDFC_DESC`, `GDFC_CTRIBNAC`, `GDFC_CTRIBMUN`, `GDFC_CNBS`, `GDFC_PALIQ` |
| `GDFE` | Dfe | — | `GDFE_FILIAL`, `GDFE_CHAVE`, `GDFE_NSU`, `GDFE_CNPJ`, `GDFE_NOME`, `GDFE_IE`, `GDFE_DHEMI`, `GDFE_VNF`, `GDFE_SIT`, `GDFE_MANIF`, `GDFE_XML`, `GDFE_IMPORT` |
| `GDFF` | Dfe | — | `GDFF_FILIAL`, `GDFF_FORN`, `GDFF_CPROD`, `GDFF_PROD`, `GDFF_FATOR` |
| `GDFG` | Dfe | — | `GDFG_FILIAL`, `GDFG_COMP`, `GDFG_FIN`, `GDFG_SLDCRED`, `GDFG_RECOLHER`, `GDFG_LINHAS`, `GDFG_DATA`, `GDFG_ARQ` |
| `GE1` | Núcleo (catálogo) | Empresas | `GE1_FILIAL`, `GE1_COD`, `GE1_NOME` |
| `GE2` | Núcleo (catálogo) | Usuários | `GE2_BLOQ`, `GE2_VALID`, `GE2_FILIAL`, `GE2_COD`, `GE2_NOME`, `GE2_PERFIL` |
| `GE2_EMP` | Segurança (catálogo) | Vínculos | `GE2_EMP_FILIAL`, `GE2_EMP_USUARIO`, `GE2_EMP_EMPRESA`, `GE2_EMP_PERFIL` |
| `GE2_SEC` | Segurança (catálogo) | Credenciais | `SEC_FILIAL`, `SEC_USUARIO`, `SEC_SALT`, `SEC_HASH`, `SEC_FAILCNT`, `SEC_LOCKED`, `SEC_LASTLOGIN`, `SEC_PWDLAST`, `SEC_IGNEXP`, `SEC_FORCE` |
| `GE2_TOK` | Segurança (catálogo) | Sessões | `TOK_TOKEN`, `TOK_USUARIO`, `TOK_EMPRESA`, `TOK_FILIAL`, `TOK_IP`, `TOK_CREATED`, `TOK_EXPIRES` |
| `GE3` | Núcleo | Trilha de auditoria (B.O.) | `GE3_FILIAL`, `GE3_COD`, `GE3_USUAR`, `GE3_EVENT`, `GE3_MOTIV`, `GE3_DATA` |
| `GE4` | Núcleo | Parâmetros/config | `GE4_FILIAL`, `GE4_EVENTO`, `GE4_MODO` |
| `GE5` | Núcleo | Fila offline (`PENDENTE`) | `GE5_FILIAL`, `GE5_CHAVE`, `GE5_PAYLD`, `GE5_STATUS` |
| `GEF1` | Filiais | Cadastro de filiais do tenant (`GEF1_COD`, `GEF1_NOME`) | `GEF1_FILIAL`, `GEF1_COD`, `GEF1_NOME`, `GEF1_UNI` |
| `GEH` | Expansão | Histórico de acesso / audit log processual | `GEH_DATA`, `GEH_HORA`, `GEH_USUARIO`, `GEH_EMPRESA`, `GEH_FUNCAO`, `GEH_IP` |
| `GEI` | Expansão | Histórico de acesso / audit log processual | `GEI_ORIGEM`, `GEI_TABELA`, `GEI_REGISTRO`, `GEI_ACAO`, `GEI_HORA` |
| `GEI_AUDIT` | Expansão | Histórico de acesso / audit log processual |  |
| `GEP_PERIFERICOS` | Loja | — | `GEP_FILIAL`, `GEP_TIPO`, `GEP_DRIVER`, `GEP_CONFIG`, `GEP_NOME`, `GEP_ATIVO`, `GEP_ULTIMO_TESTE`, `GEP_STATUS`, `GEP_DTALT`, `GEP_USALT` |
| `GES1` | Backoffice | — | `GES1_FILIAL`, `GES1_PROD`, `GES1_LOCAL`, `GES1_QTD`, `GES1_CM`, `GES1_VALOR` |
| `GES2` | Backoffice | — | `GES2_FILIAL`, `GES2_DATA`, `GES2_PROD`, `GES2_LOCAL`, `GES2_TIPO`, `GES2_ORIGEM`, `GES2_DOC`, `GES2_QTD`, `GES2_CUSTO`, `GES2_VALOR`, `GES2_SLDQTD`, `GES2_SLDVAL`, `GES2_CM` |
| `GES3` | Backoffice | — | `GES3_FILIAL`, `GES3_PROD`, `GES3_RASTRO`, `GES3_ENDER` |
| `GES4` | Backoffice | — | `GES4_FILIAL`, `GES4_PROD`, `GES4_LOCAL`, `GES4_LOTE`, `GES4_VALID`, `GES4_ENDER`, `GES4_QTD` |
| `GES5` | Backoffice | — | `GES5_FILIAL`, `GES5_LOCAL`, `GES5_ENDER`, `GES5_DESC` |
| `GES6` | Backoffice | — | `GES6_FILIAL`, `GES6_DATA`, `GES6_DOC`, `GES6_REF`, `GES6_PROD`, `GES6_LOCAL`, `GES6_TIPO`, `GES6_LOTE`, `GES6_VALID`, `GES6_ENDER`, `GES6_QTD` |
| `GES7` | Backoffice | — | `GES7_FILIAL`, `GES7_COMP`, `GES7_PROD`, `GES7_LOCAL`, `GES7_QTD`, `GES7_VALOR`, `GES7_CM` |
| `GEU1` | Unidades | Unidades (`UU`) | `GEU1_FILIAL`, `GEU1_COD`, `GEU1_NOME` |
| `GEX` | Expansão | Sessão ativa (linha temporária) | `GEX_EMPRESA`, `GEX_FILIAL`, `GEX_USUARIO` |
| `GE_REST_RL` | Rest_Web | — | `RL_KEY`, `RL_CNT`, `RL_MIN` |
| `GF1` | Fiscal | Produtos/serviços | `GF1_FILIAL`, `GF1_COD`, `GF1_NCM`, `GF1_DESC` |
| `GF2` | Fiscal | Alíquotas com vigência por NCM | `GF2_FILIAL`, `GF2_NCM`, `GF2_IBS`, `GF2_CBS`, `GF2_INI`, `GF2_FIM` |
| `GF3` | Fiscal | Header da nota (`CHAVE`, `TIPO`, `STATUS`, `EMIS`, `BASE`, `IBS`, `CBS`) / itens | `GF3_FILIAL`, `GF3_CHAVE`, `GF3_TIPO`, `GF3_STATUS`, `GF3_BASE`, `GF3_IBS`, `GF3_CBS`, `GF3_EMIS` |
| `GF4` | Fiscal | Header da nota (`CHAVE`, `TIPO`, `STATUS`, `EMIS`, `BASE`, `IBS`, `CBS`) / itens | `GF4_FILIAL`, `GF4_CHAVE`, `GF4_ITEM`, `GF4_PROD`, `GF4_QTD`, `GF4_PRECO`, `GF4_BASE`, `GF4_IBS`, `GF4_CBS` |
| `GF5` | Fiscal | Apuração por competência | `GF5_FILIAL`, `GF5_COMP`, `GF5_DEB`, `GF5_CRED`, `GF5_SALDO`, `GF5_REGIME` |
| `GF6` | Fiscal | Créditos (`TRANSF`/`RESSARC`) | `GF6_FILIAL`, `GF6_COMP`, `GF6_ORIG`, `GF6_VALOR`, `GF6_TIPO` |
| `GFN1` | Financeiro | Contas (`CONTA`, `NOME`, `SALDO`) | `GFN1_FILIAL`, `GFN1_CONTA`, `GFN1_NOME`, `GFN1_SALDO` |
| `GFN2` | Financeiro | Receber / pagar (`DOC`, `VALOR`, `SALDO`, `VENC`, `ABERTO/RECEBIDA/PAGA`) | `GFN2_FILIAL`, `GFN2_DOC`, `GFN2_CLI`, `GFN2_VALOR`, `GFN2_SALDO`, `GFN2_VENC`, `GFN2_STATUS` |
| `GFN3` | Financeiro | Receber / pagar (`DOC`, `VALOR`, `SALDO`, `VENC`, `ABERTO/RECEBIDA/PAGA`) | `GFN3_FILIAL`, `GFN3_DOC`, `GFN3_FORN`, `GFN3_VALOR`, `GFN3_SALDO`, `GFN3_VENC`, `GFN3_STATUS` |
| `GFN4` | Financeiro | Movimentos de caixa | `GFN4_FILIAL`, `GFN4_CONTA`, `GFN4_TIPO`, `GFN4_VALOR`, `GFN4_DATA` |
| `GFT1` | Backoffice | — | `GFT1_FILIAL`, `GFT1_COD`, `GFT1_NOME`, `GFT1_DOC`, `GFT1_UF`, `GFT1_LIMITE`, `GFT1_COND`, `GFT1_TABELA` |
| `GFT2` | Backoffice | — | `GFT2_FILIAL`, `GFT2_TAB`, `GFT2_PROD`, `GFT2_PRECO` |
| `GFT3` | Backoffice | — | `GFT3_FILIAL`, `GFT3_NUM`, `GFT3_CLI`, `GFT3_COND`, `GFT3_EMISSAO`, `GFT3_LOCAL`, `GFT3_DESC`, `GFT3_STATUS`, `GFT3_MOTIVO`, `GFT3_CC` |
| `GFT4` | Backoffice | — | `GFT4_FILIAL`, `GFT4_NUM`, `GFT4_PROD`, `GFT4_QTD`, `GFT4_PRECO`, `GFT4_QTDFAT` |
| `GFT5` | Backoffice | — | `GFT5_FILIAL`, `GFT5_NOTA`, `GFT5_PED`, `GFT5_CLI`, `GFT5_DATA`, `GFT5_TOTAL`, `GFT5_CUSTO`, `GFT5_IBS`, `GFT5_CBS` |
| `GFT6` | Backoffice | — | `GFT6_FILIAL`, `GFT6_NOTA`, `GFT6_PROD`, `GFT6_QTD`, `GFT6_PRECO`, `GFT6_VALOR`, `GFT6_CUSTO`, `GFT6_QTDDEV` |
| `GFT7` | Backoffice | — | `GFT7_FILIAL`, `GFT7_DEV`, `GFT7_NOTA`, `GFT7_PROD`, `GFT7_QTD`, `GFT7_VALOR`, `GFT7_CUSTO`, `GFT7_DATA` |
| `GFX1` | Backoffice | — | `GFX1_FILIAL`, `GFX1_COD`, `GFX1_DESC`, `GFX1_DIAS` |
| `GFX2` | Backoffice | — | `GFX2_FILIAL`, `GFX2_TIPO`, `GFX2_DOC`, `GFX2_ORIGDOC`, `GFX2_PARC`, `GFX2_PARCEIRO`, `GFX2_EMISSAO`, `GFX2_ORIGEM`, `GFX2_VLORIG`, `GFX2_CTACTB` |
| `GFX3` | Backoffice | — | `GFX3_FILIAL`, `GFX3_TIPO`, `GFX3_DOC`, `GFX3_DATA`, `GFX3_PRINC`, `GFX3_JUROS`, `GFX3_MULTA`, `GFX3_DESC`, `GFX3_TOTAL`, `GFX3_CONTA` |
| `GFX4` | Backoffice | — | `GFX4_FILIAL`, `GFX4_CONTA`, `GFX4_DATA`, `GFX4_DC`, `GFX4_VALOR`, `GFX4_HIST`, `GFX4_DOC` |
| `GLJ1` | Loja | — | `GLJ1_FILIAL`, `GLJ1_COD`, `GLJ1_NOME`, `GLJ1_CONTA`, `GLJ1_LOCAL`, `GLJ1_CC` |
| `GLJ2` | Loja | — | `GLJ2_FILIAL`, `GLJ2_SESSAO`, `GLJ2_CAIXA`, `GLJ2_OPER`, `GLJ2_ABERT`, `GLJ2_HORA`, `GLJ2_FUNDO`, `GLJ2_STATUS`, `GLJ2_FECH`, `GLJ2_CONTADO`, `GLJ2_ESPERADO`, `GLJ2_DIFER` |
| `GLJ3` | Loja | — | `GLJ3_FILIAL`, `GLJ3_CUPOM`, `GLJ3_SESSAO`, `GLJ3_CLI`, `GLJ3_DATA`, `GLJ3_BRUTO`, `GLJ3_DESC`, `GLJ3_TOTAL`, `GLJ3_CUSTO`, `GLJ3_STATUS`, `GLJ3_NOTA` |
| `GLJ4` | Loja | — | `GLJ4_FILIAL`, `GLJ4_CUPOM`, `GLJ4_PROD`, `GLJ4_QTD`, `GLJ4_PRECO`, `GLJ4_VALOR`, `GLJ4_CUSTO` |
| `GLJ5` | Loja | — | `GLJ5_FILIAL`, `GLJ5_CUPOM`, `GLJ5_FORMA`, `GLJ5_VALOR`, `GLJ5_TROCO`, `GLJ5_TAXA`, `GLJ5_DOC`, `GLJ5_PARC`, `GLJ5_TEF` |
| `GLJ6` | Loja | — | `GLJ6_FILIAL`, `GLJ6_SESSAO`, `GLJ6_TIPO`, `GLJ6_VALOR`, `GLJ6_MOTIVO`, `GLJ6_DATA` |
| `GLJ7` | Loja | — | `GLJ7_FILIAL`, `GLJ7_ID`, `GLJ7_REF`, `GLJ7_FORMA`, `GLJ7_VALOR`, `GLJ7_PARC`, `GLJ7_NSU`, `GLJ7_AUT`, `GLJ7_BAND`, `GLJ7_STATUS`, `GLJ7_PROV`, `GLJ7_MSG`, `GLJ7_DATA`, `GLJ7_HORA`, `GLJ7_EXTID` |
| `GLJ8` | Loja | — | `GLJ8_FILIAL`, `GLJ8_COD`, `GLJ8_PROD`, `GLJ8_FATOR` |
| `GLJ9` | Loja | — | `GLJ9_FILIAL`, `GLJ9_COD`, `GLJ9_PROD`, `GLJ9_TIPO`, `GLJ9_QTDMIN`, `GLJ9_VALOR`, `GLJ9_INI`, `GLJ9_FIM` |
| `GLJA` | Loja | — | `GLJA_FILIAL`, `GLJA_CUPOM`, `GLJA_PROD`, `GLJA_PROMO`, `GLJA_DESC` |
| `GLJB` | Loja | — | `GLJB_FILIAL`, `GLJB_CUPOM`, `GLJB_VEND`, `GLJB_CPF`, `GLJB_ORC`, `GLJB_AUTOR`, `GLJB_HORA` |
| `GLJC` | Loja | — | `GLJC_FILIAL`, `GLJC_COD`, `GLJC_NOME`, `GLJC_COMIS` |
| `GLJD` | Loja | — | `GLJD_FILIAL`, `GLJD_ORC`, `GLJD_CLI`, `GLJD_VEND`, `GLJD_DATA`, `GLJD_VALID`, `GLJD_DESC`, `GLJD_TOTAL`, `GLJD_STATUS`, `GLJD_CUPOM` |
| `GLJE` | Loja | — | `GLJE_FILIAL`, `GLJE_ORC`, `GLJE_PROD`, `GLJE_QTD`, `GLJE_PRECO` |
| `GLJF` | Loja | — | `GLJF_FILIAL`, `GLJF_VALE`, `GLJF_CLI`, `GLJF_VALOR`, `GLJF_SALDO`, `GLJF_DATA`, `GLJF_ORIGEM`, `GLJF_STATUS` |
| `GLJH` | Loja | — | `GLJH_FILIAL`, `GLJH_DEV`, `GLJH_CUPOM`, `GLJH_SESSAO`, `GLJH_PROD`, `GLJH_QTD`, `GLJH_VALOR`, `GLJH_CUSTO`, `GLJH_DATA`, `GLJH_MODO`, `GLJH_VALE` |
| `GRT1` | Fiscal | — | `GRT1_FILIAL`, `GRT1_COD`, `GRT1_TRIB`, `GRT1_ALIQ`, `GRT1_DESC` |
| `GRT2` | Fiscal | — | `GRT2_FILIAL`, `GRT2_DOC`, `GRT2_FORN`, `GRT2_COD`, `GRT2_TRIB`, `GRT2_BASE`, `GRT2_ALIQ`, `GRT2_VALOR`, `GRT2_DATA`, `GRT2_COMP`, `GRT2_GUIA` |
| `GSN1` | Fiscal | — | `GSN1_FILIAL`, `GSN1_COMP`, `GSN1_ATIV`, `GSN1_FOLHA`, `GSN1_REC` |
| `GSN2` | Fiscal | — | `GSN2_FILIAL`, `GSN2_COMP`, `GSN2_ANEXO`, `GSN2_RBT12`, `GSN2_RBTEXP`, `GSN2_RBA`, `GSN2_FOL12`, `GSN2_FATORR`, `GSN2_FAIXA`, `GSN2_ALIQEF`, `GSN2_RECMES`, `GSN2_DAS`, `GSN2_FORA`, `GSN2_VENC`, `GSN2_ALERTA` |
| `GSN3` | Fiscal | — | `GSN3_FILIAL`, `GSN3_COD`, `GSN3_DESC`, `GSN3_ANEXO` |
| `GSN4` | Fiscal | — | `GSN4_FILIAL`, `GSN4_COMP`, `GSN4_ATIV`, `GSN4_ANEXO`, `GSN4_TIPO`, `GSN4_REC`, `GSN4_ALIQEF`, `GSN4_IRPJ`, `GSN4_CSLL`, `GSN4_COFINS`, `GSN4_PIS`, `GSN4_CPP`, `GSN4_ICMS`, `GSN4_ISS`, `GSN4_IPI`, `GSN4_DAS`, `GSN4_FORA` |
| `GSN5` | Fiscal | — | `GSN5_FILIAL`, `GSN5_DATA`, `GSN5_DESC` |
| `GSN7` | Fiscal | — | `GSN7_FILIAL`, `GSN7_PROD`, `GSN7_ATIV`, `GSN7_ST`, `GSN7_MONO` |
| `GSN8` | Fiscal | — | `GSN8_FILIAL`, `GSN8_CHAVE`, `GSN8_EXP` |
| `GV1` | Estoque | Saldos | `GV1_FILIAL`, `GV1_PROD`, `GV1_SALDO`, `GV1_MIN` |
| `GV2` | Venda | Vendas (`VENDIDA/BLOQUEADA/SEM_ESTOQUE`) | `GV2_FILIAL`, `GV2_VENDA`, `GV2_PROD`, `GV2_QTD`, `GV2_STATUS` |
| `GV3` | Fiado | Caderninho | `GV3_FILIAL`, `GV3_CLI`, `GV3_VALOR`, `GV3_JUROS`, `GV3_MULTA`, `GV3_TOTAL`, `GV3_STATUS` |
| `GXX1` | Backoffice | — | `GXX1_FILIAL`, `GXX1_A` |
| `SCH_JOB` | Nucleo | — | `SCH_FILIAL`, `SCH_ROTINA`, `SCH_HORA`, `SCH_DIA`, `SCH_ATIVO`, `SCH_ULTEXEC`, `SCH_STATUS`, `SCH_MSG` |
| `SCH_LOG` | Nucleo | — | `SCH_LFILIAL`, `SCH_LROTINA`, `SCH_LDATA`, `SCH_LHORA`, `SCH_LSTATUS`, `SCH_LMSG` |
| `SEC_ADMIN_SESSION` | Segurança | Monitor / sessões admin | `SEC_AST_TOKEN`, `SEC_AST_USUARIO`, `SEC_AST_EMPRESA`, `SEC_AST_FILIAL`, `SEC_AST_IP`, `SEC_AST_LOGINEM`, `SEC_AST_ULTIMAACAO`, `SEC_AST_ROTINA`, `SEC_AST_MEMORIA` |
| `SEC_MON` | Segurança | Monitor / sessões admin |  |
| `SEC_PERM` | Segurança | RBAC (`PERFIL`, `MENU`, `ITEM`, `PERMITE`) | `SEC_PERM_FILIAL`, `SEC_PERM_PERFIL`, `SEC_PERM_MENU`, `SEC_PERM_ITEM`, `SEC_PERM_EMPRESA`, `SEC_PERM_PERMITE` |

## 5. Infra de dados e segurança (funções-base)

- `GEBDB_CORE`: `GEBDBTableExists` (qualquer schema do path), `GEBDBTableExistsHere`
  (primeiro schema — decide `CREATE`), `GEBDBColumnExists`, `GEBDBTableEnsure` (cria +
  adiciona colunas), **`GEBDBQuote(x)`** (literal SQL com aspas escapadas — use em
  TODO valor de fora concatenado num `TCSqlExec`/`TCSqlQuery`, dentro da função que
  monta o SQL), **`GEBDBMoedaFix()`** (converte colunas `REAL` do schema corrente para
  `NUMERIC(18,2)` dinheiro / `(18,4)` quantidade; idempotente).
- `GEBDB_TENANT`: `GEBDBConecta`, `GEBDBSchemaValido`, `GEBDBSchemaExists`,
  `GEBDBSetTenant` (estrito; chama `GEBDBMoedaFix`), **`GEBDBTenantAtual()`** (empresa da
  sessão ou ""), `GEBDBProvisionaCatalogo`, `GEBDBProvisionaEmpresa`.
- Segurança: `GEBSECISSUPER` (conta global `super`, case-insensitive); `GEBSECCRIAUSU`
  (provisiona GE2+SEC+EMP com validação total antes de qualquer escrita e guarda
  `lPermiteSuper`); `GEBSECLOGIN` (níveis `local/web/tui`, fail-count e lock);
  `GEBSECPOL_VERIFICA` (mínimo 8, maiúscula/minúscola/dígito/especial, sem sequência
  ou repetição 3x); `GEBSECRBAC` (+ `GEBSECISSUPER` bypass, `ADD/LIST`);
  `GEBSECTOKEN`/`GEBSECTOKENDEL` (token = 64 hex aleatórios de 2× `UUIDRandom`, 8 h).
- **`GEBSECPODE(cUsuario, cAlvo, lExigeVinc)`** — regra única de autorização sobre
  usuários (API e tela): super pode tudo; os demais precisam ser ADMIN, estar numa
  empresa e o alvo não pode ser o super nem ter vínculo com outra empresa.
  **`GEBSECDERRUBA(cUsu)`** invalida as sessões do usuário (troca de senha por outro).
- Login: 5 senhas erradas bloqueiam por **15 minutos** (relógio do banco), não mais
  para sempre; `GEBWAPIAUTH` exige token válido + usuário ativo + vínculo com a empresa.
- Núcleo: `GENMIG` (catálogo+empresa), `GEBCFG`, `GEBAUD` (B.O. em GE3), `GEBMNT`
  (`AVISA_E_TRAVA` / `AVISA_E_LIBERA_COM_BO` / `DESLIGADO`), `GEBFILA` (fila GE5),
  `GEBMON*` (monitor), `CTBLAN`/`CTBGRV` (partida dobrada + stub compatível).

## 6. Camada HTTP/REST (`GEBREST` + `GEBWEB_API`, 120 funções)

Envelope JSON `{status, timestamp, dados[], erros[]}`; auth por `?token=…&empresa=…`
(validado em `GE2_TOK`, mesma empresa); `POST /api/login` emite token
(`GEBSECLOGIN` → vínculo → tenant). Guardas: RBAC por perfil (`GEBSECRBAC`),
escopo por empresa (não-super só na própria), super exclusivo (criar empresa,
alterar/remover super via REST = 403), escrita negada não executa, 201 verifica
gravação real, token/chave com aspas = 400 sem SQL. Rotas (método + path → handler):


| Método | Path | Handler |
|---|---|---|
| POST | `/api/login` | `U_GEBWEB_LOGINAPI` |
| GET | `/api/health` | `U_GEBWAPI_HEALTH` |
| GET | `/api/public/empresas` | `U_GEBWAPI_PUBEMP` |
| GET | `/api/usuarios` | `U_GEBWAPI_USRLST` |
| GET | `/api/usuarios/{cod}` | `U_GEBWAPI_USRGET` |
| POST | `/api/usuarios` | `U_GEBWAPI_USRPOST` |
| PUT | `/api/usuarios/{cod}` | `U_GEBWAPI_USRPUT` |
| DELETE | `/api/usuarios/{cod}` | `U_GEBWAPI_USRDEL` |
| GET | `/api/empresas` | `U_GEBWAPI_EMPLST` |
| POST | `/api/empresas` | `U_GEBWAPI_EMPLSC` |
| GET | `/api/produtos` | `U_GEBWAPI_PRDLST` |
| POST | `/api/produtos` | `U_GEBWAPI_PRDLSC` |
| GET | `/api/notas` | `U_GEBWAPI_NOTLST` |
| POST | `/api/notas` | `U_GEBWAPI_NOTPOST` |
| GET | `/api/financeiro/fluxo` | `U_GEBWAPI_FLXLST` |
| GET | `/api/financeiro/contas` | `U_GEBWAPI_CONLST` |
| GET | `/api/fiscal/relatorio/{comp}` | `U_GEBWAPI_RELFISC` |
| GET | `/api/relatorios/gerencial` | `U_GEBWAPI_RELGER` |
| GET | `/api/monitor/usuarios` | `U_GEBWAPI_MONUSU` |
| DELETE | `/api/monitor/sessao/{sessao}` | `U_GEBWAPI_MONDEL` |
| GET | `/api/derrama/guias` | `U_GEBWAPI_DERLST` |
| GET | `/api/estoque` | `U_GEBWAPI_ESTLST` |
| GET | `/api/estoque/vendas` | `U_GEBWAPI_VENLST` |
| GET | `/api/contabil/lancamentos` | `U_GEBWAPI_CTBLST` |
| GET | `/api/contabil/contas` | `U_GEBWAPI_CTCLST` |
| GET | `/api/compras/pedidos` | `U_GEBWAPI_COMLST` |
| GET | `/api/compras/fornecedores` | `U_GEBWAPI_FORLST` |
| GET | `/api/unidades` | `U_GEBWAPI_UNILST` |
| POST | `/api/unidades` | `U_GEBWAPI_UNILSC` |
| GET | `/api/filiais` | `U_GEBWAPI_FILLST` |
| POST | `/api/filiais` | `U_GEBWAPI_FILSC` |
| POST | `/api/vinculos` | `U_GEBWAPI_VINCSC` |
| POST | `/api/derrama/gerar` | `U_GEBWAPI_DERGER` |
| POST | `/api/derrama/baixar` | `U_GEBWAPI_DERBAI` |
| POST | `/api/derrama/parcelar` | `U_GEBWAPI_DERPAR` |
| POST | `/api/derrama/juros` | `U_GEBWAPI_DERJUR` |
| POST | `/api/derrama/protestar` | `U_GEBWAPI_DERPRO` |
| POST | `/api/estoque/vender` | `U_GEBWAPI_ESTVEN` |
| POST | `/api/estoque/fiados` | `U_GEBWAPI_ESTFIA` |
| POST | `/api/estoque/fiados/juros` | `U_GEBWAPI_ESTFIJ` |
| POST | `/api/contabil/lancar` | `U_GEBWAPI_CTBDIR` |
| GET | `/api/contabil/balancete/{comp}` | `U_GEBWAPI_CTBBAL` |
| GET | `/api/contabil/dre/{comp}` | `U_GEBWAPI_CTBDRE` |
| POST | `/api/financeiro/contas` | `U_GEBWAPI_FINCON` |
| POST | `/api/financeiro/baixar` | `U_GEBWAPI_FINBAI` |
| POST | `/api/compras/fornecedores` | `U_GEBWAPI_COMFOR` |
| POST | `/api/compras/pedidos` | `U_GEBWAPI_COMPED` |
| POST | `/api/compras/itens` | `U_GEBWAPI_COMIT` |
| POST | `/api/compras/entradas` | `U_GEBWAPI_COMENT` |
| POST | `/api/fiscal/apurar` | `U_GEBWAPI_FISAPU` |
| POST | `/api/fiscal/creditos` | `U_GEBWAPI_FISCRE` |

## 7. TUI serve — mapa de menus (`GEBTUI`, porta 8081)

Login: usuário/senha → empresa (menu) → filial (menu); super entra direto na matriz
com vínculo garantido; **catálogo vazio: o super cria a primeira empresa na hora
(bootstrap)**. Menu principal: Fiscal, Financeiro, Derrama, Estoque, Contabil,
Compras, Núcleo, Sair. Submenus:

- **Fiscal:** Produtos, Notas, + Novo produto, Emitir nota, Apurar competência, Lançar crédito, Voltar.
- **Financeiro:** Contas, + Nova conta, Baixar título, Voltar.
- **Derrama:** Guias, + Gerar guia, Baixar guia, Parcelar guia, Calcular juros, Protestar guia, Voltar.
- **Estoque:** Saldos, Vendas, Vender, Vender fiado, Juros fiado, Voltar.
- **Contábil:** Plano, Lançamentos, Lançar, Ver balancete, Ver DRE, Voltar.
- **Compras:** Fornecedores, Pedidos, + Novo fornecedor, Abrir pedido, Adicionar item, Dar entrada, Voltar.
- **Núcleo (só ADMIN da empresa ou super; os demais só trocam a própria senha):** Empresas, Unidades, Filiais, Usuários, + Nova empresa (só super), + Nova unidade, + Nova filial, + Novo usuário, Vincular usuário (só na empresa da sessão), **Trocar senha** (`GEBTUITROCASENHA`: política e confirmação; outro usuário só via `GEBSECPODE`; ninguém muda o próprio perfil; derruba as sessões do alvo), Voltar.
- **Fiscal** ganhou **+ Nova aliquota (NCM)** (`GEBRESTALISC`: IBS/CBS em %, vigência AAAAMMDD sem sobreposição) — sem alíquota a NCM tributa a zero.
- Browses `FWMBrowse`: as grades do catálogo (GE1, GEU1, GEF1, GE2) são **somente leitura** (`SetMenuDef("")`, AdvPP 4.4.0-geban); as demais seguem editáveis.

## 8. Referência completa de funções por arquivo (590 funções)

Gerada por `scripts/doc-funcoes.py` a partir dos fontes: assinatura exata da
declaração e propósito da primeira linha do `Protheus.doc` (ou do comentário
logo acima). Só `User Function` (as `Static Function` são internas ao fonte).

### GEB_NUCLEO

**`src/GEBAUD.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GBAUDINIC` | `GBAUDINIC()` | — |
| `GBAUDLOG` | `GBAUDLOG(cTabela, cAcao, cRegistro, cUsuario, cEmpresa, cFilial)` | — |
| `GBAUDLISTAR` | `GBAUDLISTAR(cEmpresa, cInicio, cFim, nMax)` | — |
| `GBAUDRESUMO` | `GBAUDRESUMO(cEmpresa)` | — |
| `GBAUDExport` | `GBAUDExport(cEmpresa, cFormato)` | — |

**`src/GEBDB_CORE.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDBQuote` | `GEBDBQuote(xVal)` | em quem chama. |
| `GEBDBTableExists` | `GEBDBTableExists(cTabela)` | use GEBDBTableExistsHere(). |
| `GEBDBTableExistsHere` | `GEBDBTableExistsHere(cTabela)` | schema do tenant -- mascarando a necessidade de cria-la ali. |
| `GEBDBColumnExists` | `GEBDBColumnExists(cTabela, cColuna)` | GEBDBColumnExists(cTabela, cColuna) -> .T./.F. |
| `GEBDBTableEnsure` | `GEBDBTableEnsure(cTabela, cDDL, aColsObrigatorias)` | as que faltarem (tabela ja existente) sao adicionadas como TEXT. |
| `GEBDBMoedaFix` | `GEBDBMoedaFix()` | Migracao: rodar uma vez por empresa (ver o runbook de operacao (interno)), nao a cada login. |

**`src/GEBDB_TENANT.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDBConecta` | `GEBDBConecta()` | — |
| `GEBDBSchemaValido` | `GEBDBSchemaValido(cCod)` | — |
| `GEBDBSchemaExists` | `GEBDBSchemaExists(cCod)` | entao GEBDBSetTenant() precisa desta checagem antes de trocar. |
| `GEBDBTenantAtual` | `GEBDBTenantAtual()` | emp_<cod>), ou "" fora de uma empresa (catalogo/public). |
| `GEBDBSetTenant` | `GEBDBSetTenant(cCod)` | — |
| `GEBDBProvisionaCatalogo` | `GEBDBProvisionaCatalogo()` | — |
| `GEBDBProvisionaEmpresa` | `GEBDBProvisionaEmpresa(cCod, cNome)` | esta funcao de novo para o mesmo cCod sem duplicar o cadastro. |

**`src/GEBFIL_MIG.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEFFILMIG` | `GEFFILMIG()` | — |
| `GEFFILVALIDA` | `GEFFILVALIDA(cEmp, cFil)` | Valida codigo de filial EEUUFF contra a empresa (puro, sem I/O). |
| `GEFFILUNI` | `GEFFILUNI(cFil)` | Extrai a unidade de negocios (UU, posicoes 3-4) do codigo EEUUFF. |

**`src/GEBMON.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBMONINIC` | `GEBMONINIC()` | Inicializa a tabela SEC_MON (monitoramento) se nao existir. |
| `GEBMONATUALIZA` | `GEBMONATUALIZA(cToken, cRotina)` | Atualiza ultima acao e rotina do token na SEC_MON. |
| `GEBMONLISTAR` | `GEBMONLISTAR()` | Lista todos os usuarios monitorados. |
| `GEBMONDESLIGAR` | `GEBMONDESLIGAR(cToken)` | Remove da SEC_MON e encerra sessao via GEBSECTOKENDEL. |
| `GEBMONMETRICAS` | `GEBMONMETRICAS()` | Calcula metricas em tempo real. |
| `GEBMONROTINA` | `GEBMONROTINA(cToken)` | Retorna o nome da rotina em execucao para o token informado. |

**`src/GEBSCH.prw`** — 10 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSCHROTINAS` | `GEBSCHROTINAS()` | GEBSCHROTINAS() -> lista publica de rotinas {codigo, descricao} (para a tela). |
| `GEBSCHROTINAOK` | `GEBSCHROTINAOK(cCod)` | GEBSCHROTINAOK(cCod) -> .T. se a rotina esta na lista fechada. |
| `GEBSCHVALIDA` | `GEBSCHVALIDA(cHora, cDia)` | GEBSCHVALIDA(cHora, cDia) -> .T. se horario HHMM e dia "D" ou "M01".."M28" sao validos. |
| `GEBSCHDEVE` | `GEBSCHDEVE(cHoje, cHoraAgora, cDia, cHora, cUltExec)` | Funcao pura: sem relogio, sem banco. cHoje e cUltExec em AAAAMMDD; horarios em HHMM. |
| `GEBSCHMIG` | `GEBSCHMIG()` | Cria as tabelas de agendamento no tenant corrente (idempotente). |
| `GEBSCHAGENDA` | `GEBSCHAGENDA(cUsuLog, cRotina, cHora, cDia, cAtivo)` | GEBSCHAGENDA(cUsuLog, cRotina, cHora, cDia, cAtivo) -> {lOk, cMsg}. Cria ou altera o agendamento. |
| `GEBSCHDESATIVA` | `GEBSCHDESATIVA(cUsuLog, cRotina)` | GEBSCHDESATIVA(cUsuLog, cRotina) -> {lOk, cMsg}. Desliga sem mexer no horario. |
| `GEBSCHEXEC` | `GEBSCHEXEC(cRot)` | Executa uma rotina da lista fechada. Devolve {lOk, cMsg}. |
| `GEBSCHRODA` | `GEBSCHRODA()` | Roda os agendamentos devidos do tenant corrente. Devolve quantas rotinas rodaram. |
| `GEBSCHALL` | `GEBSCHALL()` | Roda o agendador em todas as empresas provisionadas (chamado pelo timer a cada minuto). |

**`src/GEBSCHJOB.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSCHJOB` | `GEBSCHJOB()` | Executor do agendador. |

**`src/GEBUNI_MIG.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEUNIMIG` | `GEUNIMIG()` | — |
| `GEUVALIDA` | `GEUVALIDA(cUni)` | Valida codigo de unidade (UU): 2 chars alfanumericos+underscore. |

**`src/GENUC_CAD.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBAUD` | `GEBAUD(cUsuario, cEvento, cMotivo)` | — |
| `GEBUSR` | `GEBUSR(cCodUser)` | — |
| `GEBCAD` | `GEBCAD()` | — |

**`src/GENUC_MIG.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GENMIGCatalogo` | `GENMIGCatalogo()` | — |
| `GENMIGEmpresa` | `GENMIGEmpresa()` | — |
| `GENMIG` | `GENMIG()` | — |
| `GEBCFG` | `GEBCFG(cChave)` | — |
| `GEBREGIME` | `GEBREGIME()` | Regime tributario da empresa: SIMPLES ou REGULAR. |

**`src/GENUC_MNT.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBMNT` | `GEBMNT(cEvento)` | — |
| `GEBFILA` | `GEBFILA(cChave, cPayload)` | — |
| `CTBLAN` | `CTBLAN(cOrigem, nValor)` | — |
| `CTBGRV` | `CTBGRV(cOrigem, cDeb, cCred, nValor, cTipo)` | — |

### GEB_FISCAL

**`src/GEBFIS_APU.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFAPU` | `GEBFAPU(cComp)` | — |
| `GEBFCRE` | `GEBFCRE(cComp, cOrig, nValor, cTipo)` | — |

**`src/GEBFIS_CAD.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFPRO` | `GEBFPRO(cCod)` | — |
| `GEBFALI` | `GEBFALI(cNCM, dData)` | — |

**`src/GEBFIS_EMI.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFEMI` | `GEBFEMI(cChave, cCod, nQtd, nPreco)` | — |
| `GEBFSPL` | `GEBFSPL(nTotal, nPartes)` | — |

**`src/GEBFIS_MIG.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFMIG` | `GEBFMIG()` | — |
| `CALCIBS` | `CALCIBS(nBase, nAliqIBS, nAliqCBS)` | — |
| `ALIQF` | `ALIQF(cNCM, dData)` | — |

**`src/GEBRET.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBRETMIG` | `GEBRETMIG()` | Cria GRT1 e GRT2. |
| `GEBRETCAD` | `GEBRETCAD(cCod, cTrib, nAliq, cDesc)` | Cadastra ou altera uma regra de retencao. |
| `GEBRETVAL` | `GEBRETVAL(xCod)` | Valida os codigos de retencao de um documento (lista ou texto separado por virgula): existem e no maximo um por tributo. |
| `GEBRETAPL` | `GEBRETAPL(cDoc, cForn, nBase, aReg, cData, aTit)` | Aplica as retencoes validadas a um documento de entrada: grava GRT2, abate o valor dos titulos do fornecedor (aTit, na ordem), contabiliza RET_FORN e acumula a guia da Derrama... |
| `GEBRETREL` | `GEBRETREL(cComp)` | Relatorio: retencoes da competencia por documento e tributo, com a guia. |

**`src/GEBSN.prw`** — 13 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSNMIG` | `GEBSNMIG()` | — |
| `GEBSNCALC` | `GEBSNCALC(nRBT12, cAnexo, nRecMes)` | Calculo puro (sem banco) de uma receita sem ST/monofasico/exportacao. |
| `GEBSNREPART` | `GEBSNREPART(nRBT12, cAnexo, nRec, lST, lMono, lExp)` | Calculo puro com reparticao por tributo. |
| `GEBSNCFG` | `GEBSNCFG(cAnexo, cInicio)` | Grava o Anexo padrao (I..V ou FR) e o mes de inicio de atividade (AAAAMM ou vazio) da empresa corrente em GE4 (SN_ANEXO / SN_INICIO). |
| `GEBSNATV` | `GEBSNATV(cCod, cDesc, cAnexo)` | Cadastra ou altera uma atividade (codigo, descricao, Anexo I..V ou FR). |
| `GEBSNPRD` | `GEBSNPRD(cProd, cAtiv, cST, cMono)` | Liga um produto (GF1) a uma atividade e marca ST e monofasico (S/N). |
| `GEBSNEXP` | `GEBSNEXP(cChave, cExp)` | Marca (S) ou desmarca (N) uma nota (GF3_CHAVE) como exportacao. |
| `GEBSNFER` | `GEBSNFER(cData, cDesc)` | Cadastra um feriado (municipal/estadual/bancario) AAAAMMDD para o vencimento do DAS. |
| `GEBSNFOL` | `GEBSNFOL(cComp, nFolha, nRecExt, cAtiv)` | Informa a folha de salarios (com pro-labore e encargos, para o Fator R) e a receita de fora do GEBAN de uma competencia. |
| `GEBSNAPU` | `GEBSNAPU(cComp)` | Apura o Simples Nacional da competencia, grava GSN2 (resumo) e GSN4 (por atividade/tipo/tributo), refazendo o mes. |
| `GEBSNVENC` | `GEBSNVENC(cComp, nDia)` | Vencimento de tributo da competencia: dia nDia (padrao 20; 1 a 28) do mes seguinte; sabado, domingo e feriado passam para o proximo dia util. |
| `GEBSNEXTRATO` | `GEBSNEXTRATO(cComp)` | Relatorio: extrato da apuracao de uma competencia (resumo, receita por atividade/tipo com a reparticao por tributo, totais por tributo e situacao da guia). |
| `GEBSNANUAL` | `GEBSNANUAL(cAno)` | Relatorio: acompanhamento do ano-calendario (mes a mes: receita, RBT12, aliquota, DAS, guia; receita acumulada contra o sublimite de 3.600.000 e o limite de 4.800.000). |

### GEB_DFE (documentos eletronicos)

**`src/GEBDFE.prw`** — 14 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEURL` | `GEBDFEURL(cMod, cUF, cAmb, cServ)` | Endereco do servico. |
| `GEBDFEENVIA` | `GEBDFEENVIA(cMod, cUF, cAmb, cServ, cMsg)` | Envia a mensagem ao servico (SOAP 1.2, certificado da filial). |
| `GEBDFERESPTEC` | `GEBDFERESPTEC()` | Responsavel tecnico (opcional; algumas UFs exigem). |
| `GEBDFENFCE` | `GEBDFENFCE(cDoc, aItens, aPag, cCPF)` | NFC-e da venda. |
| `GEBDFEDOC` | `GEBDFEDOC(cChave)` | Documento (GDF5) pela chave: {status, prot, xml, dhaut, mod, serie, nnf, tpamb, doc, chorig, xmlorig, qr, urlch, vnf, dhemi, dest} ou {}. |
| `GEBDFETRANSMITE` | `GEBDFETRANSMITE()` | Transmite as NFC-e em contingencia. |
| `GEBDFECONSULTAR` | `GEBDFECONSULTAR(cChave, lAtualiza)` | Situacao do documento na SEFAZ (consSitNFe). |
| `GEBDFECANCELA` | `GEBDFECANCELA(cChave, cJust)` | Cancela a NF-e/NFC-e autorizada (evento 110111) dentro de DFE_CANC_MIN minutos (padrao 30) da autorizacao. |
| `GEBDFEINUTILIZA` | `GEBDFEINUTILIZA(cMod, nSerie, nIni, nFim, cJust)` | Inutiliza a faixa de numeros (nIni a nFim) do modelo/serie. |
| `GEBDFEPENDINUT` | `GEBDFEPENDINUT()` | Numeros rejeitados ainda nao inutilizados: {{cMod, nSerie, nNNF}...}. |
| `GEBDFEINUTPEND` | `GEBDFEINUTPEND(cJust)` | Inutiliza todos os numeros pendentes (um pedido por numero). |
| `GEBDFESTATSVC` | `GEBDFESTATSVC(cMod)` | Status do servico de autorizacao (consStatServ) do modelo. |
| `GEBDFEROTEIRO` | `GEBDFEROTEIRO(lTestar)` | O que falta para emitir NFC-e (e o que precisa de atencao), na ordem em que o lojista deve resolver. |
| `GEBDFEDOCS` | `GEBDFEDOCS(cIni, cFim, cStatus)` | Relatorio dos documentos do periodo (grade BOREL): numero, chave, situacao, valor, protocolo, motivo. |

**`src/GEBDFE_CAD.prw`** — 16 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFECADMIG` | `GEBDFECADMIG()` | — |
| `GEBDFEDOCOK` | `GEBDFEDOCOK(cDoc)` | CPF (11) ou CNPJ (14) com digitos verificadores; recusa digitos repetidos. |
| `GEBDFEMUNNOME` | `GEBDFEMUNNOME(cCod)` | Nome do municipio pelo codigo IBGE ("" se nao existir). |
| `GEBDFEMUNBUSCA` | `GEBDFEMUNBUSCA(cTexto, cUF)` | Municipios da UF cujo nome contem cTexto (sem acento, maiusculas): {{codigo, nome}...}. |
| `GEBDFEEMIT` | `GEBDFEEMIT(o)` | Grava o emitente da filial. |
| `GEBDFEEMITLE` | `GEBDFEEMITLE()` | Emitente da filial no formato do montador de XML (EMIT de GEBDFEMONTA), ou Nil se nao houver. |
| `GEBDFECERTDIR` | `GEBDFECERTDIR()` | Pasta dos certificados da empresa/filial corrente. |
| `GEBDFECERT` | `GEBDFECERT(cPfxB64, cSenha)` | Instala o certificado A1 da filial. |
| `GEBDFECERTLE` | `GEBDFECERTLE()` | Certificado instalado da filial. |
| `GEBDFEPRODFIS` | `GEBDFEPRODFIS(o)` | Perfil fiscal do produto (GDF4). |
| `GEBDFEPRODITEM` | `GEBDFEPRODITEM(cProd, lSimples)` | Item do XML (ITENS de GEBDFEMONTA) do produto: GF1 + perfil (GDF4) + padroes da empresa; GTIN do cadastro de codigos de barras da loja (GLJ8) quando o perfil nao tiver. |
| `GEBDFECONFIG` | `GEBDFECONFIG(o)` | Configuracao dos documentos eletronicos da empresa (parametros DFE_*). |
| `GEBDFEPROXNUM` | `GEBDFEPROXNUM(cMod, nSerie)` | Proximo numero do modelo/serie (GBS1). |
| `GEBDFESETNUM` | `GEBDFESETNUM(cMod, nSerie, nProximo)` | Ajusta a numeracao para que o proximo seja nProximo. |
| `GEBDFEIBPTIMP` | `GEBDFEIBPTIMP(cConteudo, cUF)` | Importa a tabela do IBPT (Lei 12.741/2012, "De Olho no Imposto"): o CSV oficial da UF (codigo;ex;tipo;descricao;nacionalfederal;importadosfederal;... |
| `GEBDFETRIB` | `GEBDFETRIB(aIt, cUF, cCRT, cData)` | Completa os itens antes do XML: tributos aproximados (Lei 12.741, tabela IBPT da UF do emitente: federal nacional ou importado pela origem, estadual e municipal) e, se... |

**`src/GEBDFE_DANFE.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEDANFE` | `GEBDFEDANFE(cChave)` | DANFE em HTML: NFC-e (80 mm) ou, para modelo 55, o A4 (GEBDFEDANFE55). |
| `GEBDFEDANFETXT` | `GEBDFEDANFETXT(cChave)` | Linhas do DANFE NFC-e (marcadores: "== " titulo, "!! " aviso, "// a/b" linha com valor a direita, "QR " conteudo do QR, "---" linha). |

**`src/GEBDFE_DANFE55.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBC128` | `GEBC128(cDig)` | — |
| `GEBC128SVG` | `GEBC128SVG(cDig, nAltura)` | — |
| `GEBDFEDANFE55` | `GEBDFEDANFE55(cChave)` | DANFE A4 da NF-e. |

**`src/GEBDFE_DIST.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEDISTMIG` | `GEBDFEDISTMIG()` | — |
| `GEBDFEDISTBUSCA` | `GEBDFEDISTBUSCA()` | Busca as notas novas do CNPJ (a partir do ultimo NSU). |
| `GEBDFEDISTCHAVE` | `GEBDFEDISTCHAVE(cChave)` | Nota completa de uma chave (consChNFe), depois da ciencia. |
| `GEBDFEMANIF` | `GEBDFEMANIF(cChave, cTipo, cJust)` | Manifestacao do destinatario. |
| `GEBDFEDEPARA` | `GEBDFEDEPARA(cForn, cProdForn, cProd, nFator)` | De-para do produto do fornecedor. |
| `GEBDFEIMPORTA` | `GEBDFEIMPORTA(cChave, cPed, cData)` | Importa a nota recebida (completa) como entrada de compra. |
| `GEBDFERECEBIDAS` | `GEBDFERECEBIDAS(cSituacao)` | Relatorio das notas recebidas (grade BOREL). |

**`src/GEBDFE_EFD.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEEFDMIG` | `GEBDFEEFDMIG()` | — |
| `GEBDFEEFDVER` | `GEBDFEEFDVER(cComp)` | Versao do leiaute pelo ano da competencia (DFE_EFD_CODVER sobrepoe). |
| `GEBDFEEFD` | `GEBDFEEFD(cComp, cFin)` | Gera, guarda (GDFG) e devolve a EFD ICMS/IPI da competencia. |
| `GEBDFEEFDLE` | `GEBDFEEFDLE(cComp)` | Arquivo guardado da competencia ("" se nao gerado). |
| `GEBDFEEFDTXT` | `GEBDFEEFDTXT(oE, oP, aDocs)` | Monta o arquivo (funcao pura, sem banco). |
| `GEBDFEEFDBLOCOS` | `GEBDFEEFDBLOCOS(cXml, cTag)` | Blocos <cTag ...>...</cTag> em ordem. |

**`src/GEBDFE_IE.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEIEOK` | `GEBDFEIEOK(cIE, cUF, lIsento)` | — |

**`src/GEBDFE_MUN.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEMUNTAB` | `GEBDFEMUNTAB()` | — |

**`src/GEBDFE_NFE.prw`** — 11 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFENFEMIG` | `GEBDFENFEMIG()` | — |
| `GEBDFEPART` | `GEBDFEPART(o)` | Cadastro fiscal do cliente (TIPO C, codigo da GFT1) ou do fornecedor (TIPO F, codigo da GCP1). |
| `GEBDFEPARTLE` | `GEBDFEPARTLE(cTipo, cCod)` | Destinatario do XML (DEST de GEBDFEMONTA) ou Nil. |
| `GEBDFEVINC` | `GEBDFEVINC(cTipo, cDoc, cPart, cChave)` | Vinculo de chave (ENT: NF-e do fornecedor da entrada; DEVCLI: NF-e de devolucao do cliente). |
| `GEBDFEVINCLE` | `GEBDFEVINCLE(cTipo, cDoc, cPart)` | — |
| `GEBDFEALIQINT` | `GEBDFEALIQINT(cUF)` | Aliquota interna modal do ICMS da UF (padrao: tabela publicada em 2026; DFE_ALIQ_INT_<UF> sobrepoe). |
| `GEBDFEFCPPAD` | `GEBDFEFCPPAD(cUF)` | FCP geral do destino (RJ 2%, SE 1%; nas demais UFs o FCP e' por produto e fica no parametro). |
| `GEBDFEALIQINTER` | `GEBDFEALIQINTER(cUFOrig, cUFDest, cOrigem)` | Aliquota interestadual do ICMS (Res. Senado 22/1989 e 13/2012). |
| `GEBDFENFE` | `GEBDFENFE(oP)` | Emite a NF-e (modelo 55). |
| `GEBDFERESOLVE` | `GEBDFERESOLVE()` | Resolve as NF-e PENDENTE (sem resposta da SEFAZ): consulta cada chave. |
| `GEBDFECCE` | `GEBDFECCE(cChave, cTexto)` | Carta de correcao (evento 110110) da NF-e autorizada; texto de 15 a 1000 letras; ate 20 por nota (cada uma substitui a anterior). |

**`src/GEBDFE_NFSE.prw`** — 11 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFENFSEMIG` | `GEBDFENFSEMIG()` | — |
| `GEBDFESERV` | `GEBDFESERV(o)` | Servico fiscal. |
| `GEBDFENFSEURL` | `GEBDFENFSEURL()` | Base das APIs: {cSefin, cAdn}. |
| `GEBDFEDPSID` | `GEBDFEDPSID(cMun, cDoc, nSerie, nNum)` | Id da DPS: "DPS" + municipio (7) + tipo de inscricao (1 CPF, 2 CNPJ) + inscricao (14) + serie (5) + numero (15). |
| `GEBDFEDPSXML` | `GEBDFEDPSXML(oD)` | XML da DPS (sem assinatura). |
| `GEBDFENFSE` | `GEBDFENFSE(oP)` | Emite a NFS-e. |
| `GEBDFENFSECANC` | `GEBDFENFSECANC(cChave, cMotivo, cTexto)` | Cancela a NFS-e (evento e101101). |
| `GEBDFEPEDCANC` | `GEBDFEPEDCANC(cChave, cTpAmb, cDh, cCNPJ, cMotivo, cTexto)` | Pedido de registro do evento de cancelamento (e101101), sem assinatura. |
| `GEBDFENFSERESOLVE` | `GEBDFENFSERESOLVE()` | DPS sem resposta (PENDENTE): consulta o Id da DPS na Sefin. |
| `GEBDFEDANFSE` | `GEBDFEDANFSE(cChave)` | DANFSe oficial (PDF) da NFS-e, baixado do ADN com o certificado. |
| `GEBFATSERV` | `GEBFATSERV(cCli, cServ, nValor, cDescricao, cCond, cData, lRetido, nDesc)` | Faturamento de servico: NFS-e (se DFE_NFSE = S), livro fiscal (GF3/GF4 tipo NFE, para o Simples e a apuracao), titulos a receber pela condicao e receita no contabil... |

**`src/GEBDFE_QR.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBQRMATRIZ` | `GEBQRMATRIZ(cTexto, nMascara)` | — |
| `GEBQRSVG` | `GEBQRSVG(cTexto, nModulo)` | QR Code em SVG (um retangulo por trecho escuro de cada linha). |

**`src/GEBDFE_WS.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEWSTAB` | `GEBDFEWSTAB()` | — |

**`src/GEBDFE_XML.prw`** — 31 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDFEUFS` | `GEBDFEUFS()` | {sigla, codigo IBGE, fuso} |
| `GEBDFECUF` | `GEBDFECUF(cUF)` | Codigo IBGE da UF ("" se nao existir). |
| `GEBDFEUFSIG` | `GEBDFEUFSIG(cCod)` | — |
| `GEBDFEFUSO` | `GEBDFEFUSO(cUF)` | — |
| `GEBDFEAGORA` | `GEBDFEAGORA(cUF, cUTC)` | Data e hora local da UF calculadas do UTC (DateTimeUTC), qualquer que seja o fuso do servidor. |
| `GEBDFEDV` | `GEBDFEDV(c43)` | DV modulo 11 da chave (pesos 2 a 9 da direita; resto 0 ou 1 => 0). |
| `GEBDFECHAVE` | `GEBDFECHAVE(cCUF, cAAMM, cCNPJ, cMod, nSerie, nNF, cTpEmis, cCNF)` | Chave de acesso: cUF AAMM CNPJ mod serie nNF tpEmis cNF DV (44 digitos). |
| `GEBDFECNF` | `GEBDFECNF(nNF)` | Codigo numerico aleatorio de 8 digitos, diferente do numero da nota. |
| `GEBDFEDIG` | `GEBDFEDIG(c)` | So os digitos. |
| `GEBDFETXT` | `GEBDFETXT(cTxt, nMax)` | Texto para o XML: troca letras acentuadas (UTF-8) pela letra sem acento, tira o que nao for ASCII imprimivel, junta espacos repetidos, apara, corta em nMax e escapa &, < e >... |
| `GEBDFEESC` | `GEBDFEESC(c)` | — |
| `GEBDFEN` | `GEBDFEN(nVal, nDec)` | Numero com ponto e nDec casas. |
| `GEBDFEMONTA` | `GEBDFEMONTA(oNF)` | Monta o <NFe> (sem infNFeSupl e sem assinatura). |
| `GEBDFESUPL` | `GEBDFESUPL(cXml, cQR, cUrlChave)` | Insere <infNFeSupl> (QR Code e URL de consulta da NFC-e) depois do infNFe. |
| `GEBDFEBLOCO` | `GEBDFEBLOCO(cXml, cTag)` | Trecho do elemento cTag (da abertura ate o fechamento). |
| `GEBDFEDIGEST` | `GEBDFEDIGEST(cXml, cTag)` | (NF-e: portalfiscal; NFS-e nacional: sped.fazenda.gov.br/nfse). |
| `GEBDFECERTB64` | `GEBDFECERTB64(cPem)` | Corpo do certificado (Base64 do DER) a partir do PEM. |
| `GEBDFEASSINA` | `GEBDFEASSINA(cXml, cTag, cRaiz, cKeyPem, cCertPem)` | Assinatura XMLDSig envelopada do elemento cTag (que tem o atributo Id), inserida antes do fechamento de cRaiz. |
| `GEBDFEQRCODE` | `GEBDFEQRCODE(oQ)` | Conteudo do QR Code da NFC-e. |
| `GEBDFELOTE` | `GEBDFELOTE(cNFe, cIdLote)` | Lote de autorizacao sincrono com uma nota. |
| `GEBDFESTATUS` | `GEBDFESTATUS(cTpAmb, cCUF)` | — |
| `GEBDFECONSULTA` | `GEBDFECONSULTA(cTpAmb, cChave)` | — |
| `GEBDFEEVCANC` | `GEBDFEEVCANC(cChave, cCNPJ, cTpAmb, cProt, cJust, cDh, nSeq)` | Evento de cancelamento (110111), sem assinatura. |
| `GEBDFEEVCCE` | `GEBDFEEVCCE(cChave, cCNPJ, cTpAmb, cTexto, cDh, nSeq)` | Carta de correcao (110110), sem assinatura. Texto da condicao de uso: o do schema (sem acento). |
| `GEBDFEDISTMSG` | `GEBDFEDISTMSG(cTpAmb, cCUF, cCNPJ, cUltNSU, cChave)` | Pedido de distribuicao de DF-e (1.01): por ultimo NSU ou por chave (cChave preenchida). |
| `GEBDFEEVMANIF` | `GEBDFEEVMANIF(cChave, cCNPJ, cTpAmb, cTpEvento, cDesc, cJust, cDh)` | Manifestacao do destinatario (2102xx), sem assinatura; cOrgao 91 (Ambiente Nacional). |
| `GEBDFELOTEEV` | `GEBDFELOTEEV(cEvento, cIdLote)` | — |
| `GEBDFEINUT` | `GEBDFEINUT(cTpAmb, cCUF, cAno, cCNPJ, cMod, nSerie, nIni, nFim, cJust)` | Inutilizacao de faixa de numeros, sem assinatura. |
| `GEBDFESOAP` | `GEBDFESOAP(cOperacao, cMsg)` | Envelope SOAP 1.2 do servico (cOperacao: NFeAutorizacao4, NFeStatusServico4...). |
| `GEBDFETAG` | `GEBDFETAG(cXml, cTag)` | Conteudo da primeira ocorrencia de cTag (com ou sem prefixo de namespace); "" se nao houver. |
| `GEBDFEPROC` | `GEBDFEPROC(cNFe, cProt)` | nfeProc (documento autorizado): NFe assinada + protNFe do retorno. |

### GEB_DERRAMA

**`src/GEBDER_BAI.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDBAI` | `GEBDBAI(cGuia, cConta, cData)` | — |

**`src/GEBDER_COB.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDJUR` | `GEBDJUR(cGuia, nDias)` | — |
| `GEBDPAR` | `GEBDPAR(cGuia, nParc)` | — |
| `GEBDPRO` | `GEBDPRO(cGuia)` | — |

**`src/GEBDER_GUI.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDGER` | `GEBDGER(cComp)` | — |

**`src/GEBDER_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDMIG` | `GEBDMIG()` | — |

### GEB_ESTOQ_VENDA

**`src/GEBV_EST.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVEST` | `GEBVEST(cProd, nQtd)` | — |
| `GEBVESTGV1` | `GEBVESTGV1(cProd, nQtd)` | Atualiza so' o saldo antigo GV1 (uso interno do GEBESTMOV, que mantem GES1/GES2 e chama esta funcao para as telas antigas). |

**`src/GEBV_FIA.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVFIA` | `GEBVFIA(cCli, nValor)` | — |
| `GEBVJUR` | `GEBVJUR(cCli, nDias)` | — |

**`src/GEBV_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVMIG` | `GEBVMIG()` | — |

**`src/GEBV_VEN.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVVEN` | `GEBVVEN(cVenda, cProd, nQtd, nPreco)` | — |

### GEB_CONTABIL

**`src/GEBCTB_BAL.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBBAL` | `GEBBAL(cComp)` | — |
| `GEBDRE` | `GEBDRE(cComp)` | — |

**`src/GEBCTB_DIR.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCDIR` | `GEBCDIR(cContaD, cContaC, nValor, cUser)` | — |

**`src/GEBCTB_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMIG` | `GEBCMIG()` | — |

### GEB_FIN

**`src/GEBFIN_BAI.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFNBAI` | `GEBFNBAI(cTipo, cDoc, nValor)` | — |

**`src/GEBFIN_CON.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFNREC` | `GEBFNREC(cDoc, cCli, nValor, dVenc)` | — |
| `GEBFNPAG` | `GEBFNPAG(cDoc, cForn, nValor, dVenc)` | — |

**`src/GEBFIN_FLX.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBNFLX` | `GEBNFLX()` | — |

**`src/GEBFIN_MIG.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFNMIG` | `GEBFNMIG()` | — |
| `GEBFNCON` | `GEBFNCON(cConta, cNome)` | — |

### GEB_COM

**`src/GEBCOM_ENT.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMENT` | `GEBCMENT(cNF, cPed)` | — |

**`src/GEBCOM_FOR.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMFOR` | `GEBCMFOR(cCod, cNome)` | — |
| `GEBCMCOT` | `GEBCMCOT(cForn, cProd, nPreco)` | — |
| `GEBCMMEL` | `GEBCMMEL(cProd)` | — |

**`src/GEBCOM_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMMIG` | `GEBCMMIG()` | — |

**`src/GEBCOM_PED.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMPED` | `GEBCMPED(cPed, cForn)` | — |
| `GEBCMIT` | `GEBCMIT(cPed, cProd, nQtd, nPreco)` | — |

### GEB_BACKOFFICE

**`src/GEBBCO.prw`** — 18 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBBCOMIG` | `GEBBCOMIG()` | — |
| `GEBBCOCFG` | `GEBBCOCFG(cConta, cBanco, cAgencia, cAgDv, cCC, cCCDv, cCarteira, cCodEmp, cBenef, cCnpj, cLayout, cModal)` | Dados de cobranca de uma conta financeira (GFN1). |
| `GEBBCOBOL` | `GEBBCOBOL(cDoc, cConta)` | Gera (ou devolve, se ja existe) o boleto de um titulo a receber aberto. |
| `GEBBCOLIVRE` | `GEBBCOLIVRE(cBanco, cAgencia, cConta, cCarteira, cCodEmp, cModal, cSeq)` | Campo livre (25 posicoes) e nosso numero do banco (calculo puro). |
| `GEBBCOBARRAS` | `GEBBCOBARRAS(cBanco, cFator, nValor, cLivre)` | Codigo de barras FEBRABAN: banco(3) + moeda 9 + DV + fator(4) + valor(10, centavos) + campo livre(25). |
| `GEBBCOLINHA` | `GEBBCOLINHA(cBar)` | Linha digitavel (formatada) a partir do codigo de barras. |
| `GEBBCOMOD10` | `GEBBCOMOD10(cNum)` | Modulo 10 (pesos 2,1 da direita; produto > 9 soma os digitos). |
| `GEBBCOMOD11` | `GEBBCOMOD11(cNum)` | Modulo 11 do codigo de barras (pesos 2 a 9 da direita; 0, 10 e 11 viram 1). |
| `GEBBCONNDV` | `GEBBCONNDV(cCarteira, cNN)` | DV do nosso numero Bradesco: modulo 11 base 7 sobre carteira(2) + nosso numero(11). |
| `GEBBCOFATOR` | `GEBBCOFATOR(cVenc)` | Fator de vencimento: dias desde 07/10/1997; a partir de 10.000 recomeca em 1.000 (ciclo de 9.000). |
| `GEBBCOHTML` | `GEBBCOHTML(cDoc)` | Pagina HTML do boleto (beneficiario, pagador, valores, linha digitavel e codigo de barras intercalado 2 de 5 desenhado em barras). |
| `GEBBCOREM` | `GEBBCOREM(cConta, cArquivo)` | Remessa CNAB dos boletos GERADO da conta, no leiaute da conta (400 Bradesco/Itau ou 240 FEBRABAN). |
| `GEBBCORET` | `GEBBCORET(cConta, cConteudo)` | Le o retorno CNAB da conta (400 Bradesco/Itau ou 240 FEBRABAN) e baixa os titulos liquidados: principal = valor pago - juros + desconto (limitado ao saldo), com juros e... |
| `GEBBCOOFX` | `GEBBCOOFX(cConta, cConteudo)` | Importa extrato OFX da conta (sem repetir FITID) e concilia sozinho. |
| `GEBBCOCONC` | `GEBBCOCONC(cConta)` | Conciliacao automatica: cada linha pendente do extrato com um movimento da conta (GFX4) ainda nao conciliado, de mesmo valor e sentido, com data ate GE4 BCO_DIAS_CONC dias de... |
| `GEBBCOCONCMAN` | `GEBBCOCONCMAN(cConta, cFitid, nMov)` | Concilia na mao uma linha do extrato (FITID) com um movimento (numero R_E_C_N_O_ da GFX4, mostrado no relatorio), ou desfaz (nMov = 0). |
| `GEBBCOLANCA` | `GEBBCOLANCA(cConta, cFitid, cCtaCtb, cCC)` | Lanca no sistema a linha do extrato que so' existe no banco (tarifa, rendimento) como movimento avulso (GEBFXMOV) e ja concilia. |
| `GEBBCOREL` | `GEBBCOREL(cConta, cIni, cFim)` | Relatorio: conciliacao da conta no periodo: linhas conciliadas, pendentes no banco (extrato sem movimento) e pendentes no sistema (movimento sem extrato), com o total de cada lado. |

**`src/GEBBO.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBBOROTAS` | `GEBBOROTAS()` | — |
| `GEBBOROTA` | `GEBBOROTA(cRota, cMetodo)` | Rota {metodo, rota, menu, item, descricao}; {} se nao existe. |
| `GEBBOEXEC` | `GEBBOEXEC(cMetodo, cRota, o, cUsu)` | Executa a rota do backoffice. |

**`src/GEBBOLIB.prw`** — 25 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `BOMIG` | `BOMIG()` | — |
| `BOTAB` | `BOTAB(cTab, cCols, cIdx)` | BOTAB("GXX1", "GXX1_A TEXT NOT NULL, ...", "GXX1_A") -> cria se faltar + indice (filial, cIdx). |
| `BOSTR` | `BOSTR(xVal)` | — |
| `BOCOL` | `BOCOL(xVal)` | Texto aparado (colunas de TCSqlQuery, campos da API). |
| `BOVAL` | `BOVAL(xVal)` | — |
| `BONUM` | `BONUM(nVal, nDec)` | — |
| `BOQ` | `BOQ(oReq, cCampo)` | — |
| `BOQN` | `BOQN(oReq, cCampo)` | — |
| `BOQITENS` | `BOQITENS(oReq, cCampo, aCampos, aNum)` | Itens de uma lista da API: array de JsonObject -> array de arrays com os campos pedidos (numericos pelo nome em aNum). |
| `BOHOJE` | `BOHOJE()` | — |
| `BODATAOK` | `BODATAOK(cData)` | Data AAAAMMDD valida? |
| `BODATA` | `BODATA(cData)` | Data vazia => hoje; invalida => "". |
| `BOJDN` | `BOJDN(cData)` | — |
| `BODEJDN` | `BODEJDN(nJ)` | — |
| `BODTADD` | `BODTADD(cData, nDias)` | — |
| `BODIAS` | `BODIAS(cData1, cData2)` | Dias de cData1 ate cData2 (positivo se cData2 for depois). |
| `BOPARM` | `BOPARM(cChave, cDefault)` | Parametro da empresa (GE4) com default. |
| `BOMOD` | `BOMOD(nA, nB)` | Resto inteiro (nA, nB positivos). |
| `BOSETPARM` | `BOSETPARM(cChave, cValor)` | Grava parametro da empresa (GE4). |
| `BOMESADD` | `BOMESADD(cComp, nDelta)` | BOMESADD("202601", -1) -> "202512" |
| `BOCOMPOK` | `BOCOMPOK(cComp)` | Competencia AAAAMM valida? |
| `BOFIMMES` | `BOFIMMES(cComp)` | Ultimo dia da competencia (AAAAMMDD). |
| `BOSEQ` | `BOSEQ(cChave, nTam)` | Proximo numero da chave (GBS1). |
| `BOSESSAO` | `BOSESSAO()` | Identificador da sessao (cada janela do navegador e' uma VM, com seus Static): "S" + AAAAMMDD + HHMMSS + aleatorio. |
| `BOREL` | `BOREL(aLinhas)` | Regrava a grade de relatorio da sessao (GBR1). |

**`src/GEBCPX.prw`** — 10 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCPXMIG` | `GEBCPXMIG()` | — |
| `GEBCPXSC` | `GEBCPXSC(cNum, aItens, cSolic)` | Solicitacao de compra. |
| `GEBCPXPED` | `GEBCPXPED(cPed, cForn, aItens, cCond, cLocal, cData)` | Pedido de compra com varios itens. |
| `GEBCPXGERA` | `GEBCPXGERA(cNumSC, cCond, cLocal, cData)` | Gera os pedidos de uma solicitacao pelo menor preco cotado (GCP2), um pedido por fornecedor. |
| `GEBCPXAPR` | `GEBCPXAPR(cPed, cUsuario, lAprova)` | Libera (lAprova .T.) ou rejeita um pedido PENDENTE de alcada. |
| `GEBCPXENT` | `GEBCPXENT(cNF, cPed, aItens, nFrete, cData, aRet, cChaveNF)` | Documento de entrada de um pedido. |
| `GEBCPXDEV` | `GEBCPXDEV(cNF, cForn, aItens, cData, cChaveForn)` | Devolucao de compra: itens de um documento de entrada voltam ao fornecedor pelo custo da entrada (com o frete rateado) e pelos mesmos lotes. |
| `GEBCPXABERTOS` | `GEBCPXABERTOS()` | Relatorio: pedidos abertos/parciais por item (pedido, fornecedor, produto, pedida, recebida, saldo, preco, valor pendente, liberacao). |
| `GEBCPXPORFORN` | `GEBCPXPORFORN(cIni, cFim)` | Relatorio: compras por fornecedor no periodo (entradas, mercadoria, frete, total). |
| `GEBCPXSCPEND` | `GEBCPXSCPEND()` | Relatorio: solicitacoes de compra abertas (por necessidade). |

**`src/GEBCTX.prw`** — 13 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCTXMIG` | `GEBCTXMIG()` | — |
| `GEBCTXLP` | `GEBCTXLP(cEvento, nValor, cDoc, cData, cDeb, cCred, cCC)` | Lancamento padrao do evento na data do fato. |
| `GEBCTXRATEIA` | `GEBCTXRATEIA(cCC, nValor)` | Divide um valor pelo centro de custo ou pelo rateio (o ultimo centro fica com o centavo). |
| `GEBCTXCC` | `GEBCTXCC(cCod, cDesc, cBloq)` | Cadastra/altera centro de custo (bloqueado S = nao recebe lancamento). |
| `GEBCTXRAT` | `GEBCTXRAT(cCod, aItens)` | Cadastra/altera um rateio: {{cCentro, nPercentual}...}, somando 100. |
| `GEBCTXCCRES` | `GEBCTXCCRES(cIni, cFim)` | Relatorio: resultado por centro de custo no periodo (receita bruta, deducoes, CMV, outras receitas, despesas, resultado); a ultima linha "(sem centro)" e' o que nao foi marcado. |
| `GEBCTXREV` | `GEBCTXREV(cEvento, nValor, cDoc, cData, cDeb, cCred, cCC)` | Estorno: mesmo evento com as contas trocadas. |
| `GEBCTXCONTAS` | `GEBCTXCONTAS(cEvento)` | {cDebito, cCredito} do evento ("" se nao existe). |
| `GEBCTXFIN` | `GEBCTXFIN(cConta)` | ponytail: CAIXA* = Caixa, o resto = Bancos; criar de-para por conta se a empresa quiser um razao por banco |
| `GEBCTXRAZAO` | `GEBCTXRAZAO(cConta, cIni, cFim)` | Relatorio: razao de uma conta no periodo (saldo anterior, lancamentos com saldo acumulado, saldo final). |
| `GEBCTXBALAN` | `GEBCTXBALAN(cIni, cFim, cCC)` | Relatorio: balancete do periodo. |
| `GEBCTXDRE` | `GEBCTXDRE(cIni, cFim, cCC)` | Relatorio: DRE estruturada do periodo. |
| `GEBCTXCORRIGE` | `GEBCTXCORRIGE()` | Corrige os lancamentos antigos que cairam no PADRAO (CTBLAN pelo numero do documento: D 1.01.001 Caixa / C 3.01.001 Receita, tipo AUTO). |

**`src/GEBDER_FIN.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDERFMIG` | `GEBDERFMIG()` | Garante as tabelas da Derrama, do financeiro e o complemento GD4. |
| `GEBDERGUIA` | `GEBDERGUIA(cGuia, cTipo, cComp, nValor, cVenc, cCtaCtb, cCredor)` | Cria ou atualiza a guia da Derrama e o titulo a pagar. |
| `GEBDERPAGA` | `GEBDERPAGA(cGuia, cConta, cData)` | Paga a guia pela Derrama: baixa no financeiro todos os titulos abertos da guia (o dinheiro sai da conta). |
| `GEBDERPODEPAR` | `GEBDERPODEPAR(cGuia)` | A guia pode ser parcelada? Nao se ja tem pagamento ou esta baixada. |
| `GEBDERPARTIT` | `GEBDERPARTIT(cGuia, nParc, nTot)` | Troca os titulos abertos da guia por um titulo por parcela (30 em 30 dias). |
| `GEBDERTITS` | `GEBDERTITS(cGuia)` | Titulos a pagar de uma guia (o da guia ou os das parcelas). |
| `GEBDERPROV` | `GEBDERPROV(cEvento, cDoc, nAlvo, cData, cDeb, cCred)` | Lanca a provisao de um tributo: deixa o saldo lancado do evento para o documento igual a nAlvo, lancando so' a diferenca (positiva no sentido do evento, negativa com as pernas... |

**`src/GEBEST.prw`** — 17 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBESTMIG` | `GEBESTMIG()` | — |
| `GEBESTMOV` | `GEBESTMOV(cProd, cLocal, cTipo, nQtd, nCusto, cOrigem, cDoc, cData, aDet, cDocRef, lCustoInf)` | Movimenta o estoque com custo. |
| `GEBESTSLD` | `GEBESTSLD(cProd, cLocal)` | Saldo do produto: {nQtd, nCM, nValor}. |
| `GEBESTAJU` | `GEBESTAJU(cProd, cLocal, nContado, nCusto, cDoc, cData, aDet)` | Inventario: informa a quantidade contada; a diferenca entra ou sai ao custo medio (sem CM, nCusto informado vale para a entrada) e e' contabilizada (EST_AJ_POS / EST_AJ_NEG). |
| `GEBESTTRF` | `GEBESTTRF(cProd, cOrig, cDest, nQtd, cDoc, cData, aDet, cEnderDest)` | Transferencia entre armazens ao custo medio da origem. |
| `GEBESTKARDEX` | `GEBESTKARDEX(cProd, cLocal, cIni, cFim)` | Relatorio: kardex do produto no periodo (saldo inicial, cada movimento com custo e saldo, saldo final). |
| `GEBESTPOS` | `GEBESTPOS(cLocal)` | Relatorio: posicao do estoque valorizada (por produto e armazem: quantidade, custo medio, valor; minimo da GV1 e alerta abaixo do minimo). |
| `GEBESTCTL` | `GEBESTCTL(cProd, cRastro, cEnder)` | Controle do produto: rastro N (nenhum), L (lote, com validade opcional) ou S (numero de serie: uma unidade por serie) e endereco S/N. |
| `GEBESTENDER` | `GEBESTENDER(cLocal, cEnder, cDesc)` | Cadastra endereco (armazem + endereco, ex.: 01 / A-01-03). |
| `GEBESTENDTRF` | `GEBESTENDTRF(cProd, cLocal, cLote, cOrig, cDest, nQtd, cData)` | Muda um lote de endereco dentro do armazem (nao mexe no custo). |
| `GEBESTLOTES` | `GEBESTLOTES(cProd, cLocal, cData)` | Relatorio: saldo por lote/serie e endereco (com validade e dias para vencer). |
| `GEBESTVENCER` | `GEBESTVENCER(nDias, cData)` | Relatorio: lotes vencidos ou vencendo em ate nDias a partir de cData. |
| `GEBESTFECHA` | `GEBESTFECHA(cComp)` | Fechamento mensal do estoque (como a virada de saldo SB9 do Protheus): grava o saldo de cada produto/armazem no fim da competencia (GES7, pelo kardex) e bloqueia movimentos com... |
| `GEBESTREABRE` | `GEBESTREABRE(cComp)` | Reabre a ultima competencia fechada. |
| `GEBESTFECHREL` | `GEBESTFECHREL(cComp)` | Relatorio: fechamento da competencia por produto/armazem (saldo do fechamento anterior, entradas, saidas e saldo final, em quantidade e valor) com a conferencia inicial +... |
| `GEBESTVALLOTE` | `GEBESTVALLOTE(cProd, cLocal, cTipo, nQtd, aDet, cDocRef, cData)` | Produto sem controle devolve .T. |
| `GEBESTDET` | `GEBESTDET(cLote, cValid, cEnder, nQtd)` | Lotes de um item da API/tela: lote (series separadas por ";"), validade, endereco, quantidade. |

**`src/GEBFAT.prw`** — 13 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFATMIG` | `GEBFATMIG()` | — |
| `GEBFATCLI` | `GEBFATCLI(cCod, cNome, cDoc, cUF, nLimite, cCond, cTab)` | Cadastra/altera cliente. |
| `GEBFATPRC` | `GEBFATPRC(cTab, cProd, nPreco)` | Preco do produto numa tabela (vazia = PADRAO). |
| `GEBFATPED` | `GEBFATPED(cNum, cCli, aItens, cCond, nDesc, cLocal, cData, cCC, cRegime)` | Pedido de venda. `cRegime` = `FISCAL` (padrao) ou `COMPROVANTE` (DIFAL extraoficial: teto de desconto por `LOJ_REG_DESCF`/`LOJ_REG_DESCC` e sem NF-e no faturamento). |
| `GEBFATLIB` | `GEBFATLIB(cNum, lForca)` | Liberacao do pedido (credito e estoque). |
| `GEBFATCAN` | `GEBFATCAN(cNum)` | Cancela pedido sem nenhum faturamento. |
| `GEBFATFAT` | `GEBFATFAT(cNum, aItens, cData, cNota)` | Documento de saida do pedido liberado. |
| `GEBFATNOTA` | `GEBFATNOTA(cChave, aItens, cData, cTipo)` | Nota fiscal com varios itens: GF3 (cabecalho) + GF4 (um por item). |
| `GEBFATDEV` | `GEBFATDEV(cNota, aItens, cData, cChaveCli)` | Devolucao de venda (itens de uma nota). |
| `GEBFATREL` | `GEBFATREL(cIni, cFim, cAgrupa)` | Relatorio: faturamento do periodo por CLIENTE ou PRODUTO: quantidade, valor liquido de devolucoes, custo, margem e margem %. |
| `GEBFATCARTEIRA` | `GEBFATCARTEIRA()` | Relatorio: carteira de pedidos (itens com saldo a faturar). |
| `GEBFATABC` | `GEBFATABC(cIni, cFim)` | Relatorio: curva ABC dos produtos pelo valor faturado no periodo (A ate 80% acumulado, B ate 95%, C o resto). |
| `GEBFATPRECO` | `GEBFATPRECO(cTab, cProd)` | Preco do produto na tabela (vazia = PADRAO, cai para PADRAO se faltar); 0 se nao tem. |

**`src/GEBFNX.prw`** — 13 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFXMIG` | `GEBFXMIG()` | — |
| `GEBFXCOND` | `GEBFXCOND(cCod, cDesc, cDias)` | Cadastra/altera condicao de pagamento (dias separados por virgula, em ordem crescente; "0" = a vista). |
| `GEBFXPARC` | `GEBFXPARC(cCond, nValor, cEmissao)` | Parcelas de um valor pela condicao (codigo GFX1 ou lista de dias; vazio = a vista). |
| `GEBFXTIT` | `GEBFXTIT(cTipo, cDoc, cParceiro, nValor, cCond, cEmissao, cOrigem, cCtaCtb)` | Gera os titulos (parcelas) a receber (R) ou a pagar (P). |
| `GEBFXCALC` | `GEBFXCALC(cTipo, cDoc, cData)` | Juros e multa por atraso de um titulo aberto na data. |
| `GEBFXBAI` | `GEBFXBAI(cTipo, cDoc, nPrinc, nJuros, nMulta, nDesc, cConta, cData)` | Baixa (parcial ou total) de titulo a receber (R) ou a pagar (P). |
| `GEBFXTRF` | `GEBFXTRF(cOrig, cDest, nValor, cData, cHist)` | Transferencia entre contas financeiras. |
| `GEBFXMOV` | `GEBFXMOV(cConta, cDC, nValor, cHist, cData, cCtaCtb, cCC)` | Movimento avulso na conta (C = entrada, D = saida), sem titulo. |
| `GEBFXDESP` | `GEBFXDESP(cDoc, cForn, nValor, cCond, cEmissao, cCtaDesp, cCC, cHist)` | Despesa a pagar: gera os titulos (GEBFXTIT P) e ja reconhece a despesa (FIN_DESPESA: debito cCtaDesp, padrao 4.02.006 Despesas gerais; credito Fornecedores), com centro de... |
| `GEBFXPOSICAO` | `GEBFXPOSICAO(cTipo, cData)` | Relatorio: titulos abertos (R ou P) na data, por faixa de atraso: a vencer, 1-30, 31-60, 61-90 e mais de 90 dias. |
| `GEBFXEXTRATO` | `GEBFXEXTRATO(cConta, cIni, cFim)` | Relatorio: extrato da conta no periodo (saldo anterior, movimentos com saldo acumulado, saldo final). |
| `GEBFXFLUXO` | `GEBFXFLUXO(cIni, nDias)` | Relatorio: fluxo de caixa projetado de cIni por nDias: saldo inicial (soma das contas GFN1), titulos vencidos ate cIni na primeira linha, depois receber/pagar por dia de... |
| `GEBFXMOVCONTA` | `GEBFXMOVCONTA(cConta, cDC, nValor, cHist, cDoc, cData)` | Movimento na conta sem lancamento contabil (quem chama contabiliza): {lOk, cMsg}. |

### GEB_LOJA (frente de loja e PDV)

**`src/GEBLOJ.prw`** — 12 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBLOJMIG` | `GEBLOJMIG()` | — |
| `GEBLOJCX` | `GEBLOJCX(cCod, cNome, cConta, cLocal, cCC)` | Cadastra/altera um caixa. |
| `GEBLOJABRE` | `GEBLOJABRE(cCaixa, cOper, nFundo, cData)` | Abre a sessao do caixa (uma aberta por caixa). |
| `GEBLOJVEN` | `GEBLOJVEN(cSessao, aItens, aPagtos, cCli, nDesc, cVend, cCPF, cSuperv, cSenhaSup, cOrc, cRegime)` | Venda no caixa (cupom). `cRegime` = `FISCAL` (padrao) ou `COMPROVANTE` (sem NFC-e; teto de desconto por regime quando `LOJ_REG_ATIVO=S`). Forma de pagamento `CRYPTO` recebe doc `"MOEDA|ENDERECO"` (BTC/ETH/XMR/USDC/USDT, cotacao CoinGecko, QR no PDV). |
| `GEBLOJCAN` | `GEBLOJCAN(cCupom, cMotivo)` | Cancela um cupom da sessao aberta. Estorna cada forma: `CRYPTO` devolve o valor a `CRY_CONTA` e estorna o evento contabil `LOJ_CRYPTO` (a transacao on-chain e' manual, como no PIX). |
| `GEBLOJSAN` | `GEBLOJSAN(cSessao, cTipo, nValor, cMotivo, cConta)` | Sangria (SANGRIA: caixa -> cofre) ou suprimento (SUPRIMENTO: cofre -> caixa). |
| `GEBLOJFECHA` | `GEBLOJFECHA(cSessao, nContado)` | Fecha a sessao com o dinheiro contado. |
| `GEBLOJRESUMO` | `GEBLOJRESUMO(cSessao)` | Relatorio: resumo da sessao (cupons, cancelados, total por forma de pagamento, sangrias, suprimentos, fundo, dinheiro esperado, contado e diferenca). |
| `GEBLOJVENDAS` | `GEBLOJVENDAS(cData, cCaixa)` | Relatorio: vendas do dia por produto (cupons nao cancelados; cCaixa vazio = todos). |
| `GEBLOJSES` | `GEBLOJSES(cSessao)` | Sessao do caixa: {cSessao, cCaixa, cStatus, cDataAbertura, nFundo, cOperador, nContado, nDiferenca}; {} se nao existe. |
| `GEBLOJCXA` | `GEBLOJCXA(cCaixa)` | Caixa: {cCod, cConta, cLocal, cCentroCusto}; {} se nao existe. |
| `GEBLOJESP` | `GEBLOJESP(cSessao)` | Dinheiro esperado na gaveta da sessao. |

**`src/GEBLOJ_CAD.prw`** — 10 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBLOJCADMIG` | `GEBLOJCADMIG()` | — |
| `GEBLOJBAR` | `GEBLOJBAR(cCodigo, cProd, nFator)` | Cadastra o codigo de barras (GTIN com digito valido) ou o PLU de balanca (5 digitos) do produto. |
| `GEBLOJEANOK` | `GEBLOJEANOK(cCodigo)` | GTIN-8/12/13/14 com digito verificador certo (modulo 10, pesos 3 e 1). |
| `GEBLOJRESOLVE` | `GEBLOJRESOLVE(cCodigo, nQtd, nPreco)` | Traduz o que foi lido no caixa em produto, quantidade e preco: codigo do produto, codigo de barras (quantidade x fator) ou etiqueta de balanca. |
| `GEBLOJPROMO` | `GEBLOJPROMO(cCod, cProd, cTipo, nQtdMin, nValor, cIni, cFim)` | Cadastra/altera a promocao (cCod). |
| `GEBLOJPRECO` | `GEBLOJPRECO(cProd, nQtd, cData)` | Preco unitario do item na data: o da tabela PADRAO ou o da promocao vigente que deixar o item mais barato. |
| `GEBLOJVEND` | `GEBLOJVEND(cCod, cNome, nComis)` | Cadastra/altera o vendedor e o percentual de comissao. |
| `GEBLOJVENDOK` | `GEBLOJVENDOK(cCod)` | Vendedor cadastrado? |
| `GEBLOJCPFOK` | `GEBLOJCPFOK(cDoc)` | CPF (11 digitos) ou CNPJ (14 digitos) com digitos verificadores certos. |
| `GEBLOJDIGITOS` | `GEBLOJDIGITOS(cTxt)` | So' os digitos do texto. |

**`src/GEBLOJ_OPE.prw`** — 10 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBLOJORC` | `GEBLOJORC(aItens, cCli, cVend, nDesc, cData)` | Grava o orcamento. |
| `GEBLOJORCFIN` | `GEBLOJORCFIN(cSessao, cOrc, aPagtos, cCPF, cSuperv, cSenhaSup, cRegime)` | Finaliza o orcamento no caixa: vira cupom (GEBLOJVEN) com os precos do orcamento. `cRegime` segue para `GEBLOJVEN` (`FISCAL`/`COMPROVANTE`). |
| `GEBLOJORCCAN` | `GEBLOJORCCAN(cOrc)` | Cancela o orcamento aberto. |
| `GEBLOJORCS` | `GEBLOJORCS(cStatus)` | Relatorio: orcamentos pelo status (vazio = ABERTO). |
| `GEBLOJDEV` | `GEBLOJDEV(cSessao, cCupom, aItens, cModo, cMotivo, oCons)` | Devolucao/troca no caixa (sessao aberta) de itens de um cupom vendido. |
| `GEBLOJVALE` | `GEBLOJVALE(cVale)` | Consulta o vale-troca. |
| `GEBLOJCUPOM` | `GEBLOJCUPOM(cCupom)` | Segunda via do cupom em texto (uma linha por elemento; tambem na grade). |
| `GEBLOJCONS` | `GEBLOJCONS(cCodigo, cCaixa)` | Consulta de preco: produto (ou codigo de barras), descricao, preco da tabela, promocao vigente e saldo no armazem do caixa (vazio = 01). |
| `GEBLOJGER` | `GEBLOJGER(cIni, cFim, cAgrupa)` | Relatorio gerencial da loja no periodo, agrupado por DIA (padrao), CAIXA, OPERADOR ou VENDEDOR. |
| `GEBLOJCOMIS` | `GEBLOJCOMIS(cIni, cFim)` | Relatorio: comissao por vendedor no periodo. |

**`src/GEBPDV_API.prw`** — 16 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBPDVCAIXALST` | `GEBPDVCAIXALST(cUsuario)` | Lista caixas cadastrados via API REST. |
| `GEBPDVCAIXAABR` | `GEBPDVCAIXAABR(cUsuario, aBody)` | Abre sessao de caixa via API REST. |
| `GEBPDVCAIXAFECH` | `GEBPDVCAIXAFECH(cUsuario, aBody)` | Fecha sessao de caixa via API REST. |
| `GEBPDVCUPOMNOV` | `GEBPDVCUPOMNOV(cUsuario, aBody)` | Cria novo cupom via API REST. |
| `GEBPDVCUPOMGET` | `GEBPDVCUPOMGET(cUsuario, cCupom)` | Busca cupom por ID (segunda via) via API REST. |
| `GEBPDVCUPCANC` | `GEBPDVCUPCANC(cUsuario, aBody)` | Cancela cupom via API REST. |
| `GEBPDVPRODUTBUSC` | `GEBPDVPRODUTBUSC(cUsuario, cCodigo)` | Busca produto por codigo ou codigo de barras via API REST. |
| `GEBPDVRELGER` | `GEBPDVRELGER(cUsuario, aBody)` | Relatorio gerencial da loja via API REST. |
| `GEBPDVRELCOM` | `GEBPDVRELCOM(cUsuario, aBody)` | Relatorio de comissao por vendedor via API REST. |
| `GEBPDVPERIFLIST` | `GEBPDVPERIFLIST(cUsuario, cTipo)` | Lista perifÃ©ricos configurados via API REST. |
| `GEBPDVPERIFREG` | `GEBPDVPERIFREG(cUsuario, aBody)` | Registra perifÃ©rico via API REST. |
| `GEBPDVPERIFDEL` | `GEBPDVPERIFDEL(cUsuario, nId)` | Remove perifÃ©rico via API REST. |
| `GEBPDVSANGRIA` | `GEBPDVSANGRIA(cUsuario, aBody)` | Sangria ou suprimento de caixa via API REST. |
| `GEBPDVRELGERCSV` | `GEBPDVRELGERCSV(cUsuario, aBody)` | Relatorio gerencial exportado como CSV. |
| `GEBPDVRELCOMCSV` | `GEBPDVRELCOMCSV(cUsuario, aBody)` | Relatorio de comissao exportado como CSV. |
| `GEBPDVCAIXARESUMO` | `GEBPDVCAIXARESUMO(cUsuario, cSessao)` | Resumo completo da sessao de caixa (para fechamento). |

**`src/GEBPDV_HTML.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBPDVHTML` | `GEBPDVHTML(oReq)` | Serve a interface PDV (pÃ¡gina HTML autocontida). |
| `GEBPDVWS` | `GEBPDVWS(oReq)` | Health check do serviÃ§o WebSocket de perifÃ©ricos. |

**`src/GEBPERIF_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBPERIFMIG` | `GEBPERIFMIG()` | — |

**`src/GEBTEF.prw`** — 10 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBTEFMIG` | `GEBTEFMIG()` | — |
| `GEBTEFCFG` | `GEBTEFCFG(cProv, cUrl, cMerchantId, cChave, cCartao, cBandeira)` | Configura o TEF da empresa (GE4): provedor SIMULADOR, HTTP ou CIELO e os dados do provedor. |
| `GEBTEFAUT` | `GEBTEFAUT(cForma, nValor, nParc, cRef)` | Autoriza um pagamento em cartao (DEBITO/CREDITO). |
| `GEBTEFCONF` | `GEBTEFCONF(cId)` | Confirma a transacao pendente (CONFIRMADA). |
| `GEBTEFDESF` | `GEBTEFDESF(cId)` | Desfaz a transacao pendente (DESFEITA). |
| `GEBTEFCANC` | `GEBTEFCANC(cId)` | Cancela/estorna a transacao confirmada (CANCELADA). |
| `GEBTEFRESOLVE` | `GEBTEFRESOLVE()` | Desfaz as transacoes que ficaram PENDENTE (venda interrompida). |
| `GEBTEFREL` | `GEBTEFREL(cData)` | Relatorio: transacoes TEF do dia (para conferir com a adquirente): cada transacao e os totais confirmados por forma e bandeira. |
| `GEBTEFRESP` | `GEBTEFRESP(cJson)` | Interpreta a resposta JSON do gateway HTTP. |
| `GEBTEFCIELO` | `GEBTEFCIELO(cOper, cJson, cExt)` | Interpreta a resposta da Cielo (API e-Commerce 3.0) para a operacao: autorizar = Payment.Status 1; confirmar = 2; desfazer/cancelar = 10 ou 11. |

### GEB_EXPANSAO

**`src/GEBEXP_CTX.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBEXPCONTEXTO` | `GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)` | — |
| `GEBEXPIST` | `GEBEXPIST()` | Verifica se ha sessao de contexto ativa (linha em GEX). |
| `GEBEXPCONTEXT_GET` | `GEBEXPCONTEXT_GET()` | — |
| `GEBEXPCLEAR` | `GEBEXPCLEAR()` | Encerra sessao: remove linha ativa de GEX. |
| `GEXBINIT` | `GEXBINIT()` | Inicializa tabelas auxiliares GEH (historico) e GEX (contexto) se nao existirem. |

**`src/GEBEXP_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBEXPCriaAuditoria` | `GEBEXPCriaAuditoria()` | — |

**`src/GEBEXP_REL_BIZ.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBRELFISCAL` | `GEBRELFISCAL(cEmpresa, cComp)` | — |
| `GEBRELDERRAMA` | `GEBRELDERRAMA(cEmpresa, cComp)` | — |
| `GEBRELFIN` | `GEBRELFIN(cEmpresa)` | — |
| `GEBRELSTOQUE` | `GEBRELSTOQUE(cEmpresa)` | — |
| `GEBRELCOMPRAS` | `GEBRELCOMPRAS(cEmpresa)` | — |
| `GEBRELCONTABIL` | `GEBRELCONTABIL(cEmpresa, cComp)` | — |
| `GEBRELGERAL` | `GEBRELGERAL(cEmpresa)` | — |

**`src/GEBEXP_REL_NUC.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBRELEMPRESAS` | `GEBRELEMPRESAS()` | — |
| `GEBRELUSUARIOS` | `GEBRELUSUARIOS(cEmpresa)` | — |
| `GEBRELAUDITORIA` | `GEBRELAUDITORIA(cEmpresa, cInicio, cFim)` | — |
| `GEBRELMENTOR` | `GEBRELMENTOR(cEmpresa)` | — |
| `GEBRELCADASTROS` | `GEBRELCADASTROS(cEmpresa)` | — |

**`src/GEBEXP_TRAK.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBTRAKCOMPRA` | `GEBTRAKCOMPRA(cPedido)` | — |
| `GEBTRAKVENDA` | `GEBTRAKVENDA(cVenda)` | — |
| `GEBTRAKNOTAFISCAL` | `GEBTRAKNOTAFISCAL(cChave)` | — |
| `GEBTRAKDERRAMA` | `GEBTRAKDERRAMA(cGuia)` | — |

### GEB_SEGURANCA

**`src/GEBSEC_CICLO.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECBLOQUEIA` | `GEBSECBLOQUEIA(cUsuLog, cAlvo, lBloq)` | GEBSECBLOQUEIA(cUsuLog, cAlvo, lBloq) -> {lOk, cMsg}. Bloqueia (.T.) ou desbloqueia (.F.). |
| `GEBSECVALIDADE` | `GEBSECVALIDADE(cUsuLog, cAlvo, cData)` | GEBSECVALIDADE(cUsuLog, cAlvo, cData) -> {lOk, cMsg}. cData AAAAMMDD; "" limpa a validade. |
| `GEBSECELIMINAACESSOS` | `GEBSECELIMINAACESSOS(cUsuLog, cAlvo)` | GEBSECELIMINAACESSOS(cUsuLog, cAlvo) -> {lOk, cMsg}. |
| `GEBSECEXCLUI` | `GEBSECEXCLUI(cUsuLog, cAlvo)` | GEBSECEXCLUI(cUsuLog, cAlvo) -> {lOk, cMsg}. So' usuario que nunca acessou; so' o super. |
| `GEBSECIGNORAEXP` | `GEBSECIGNORAEXP(cUsuLog, cAlvo, lIgnora)` | GEBSECIGNORAEXP(cUsuLog, cAlvo, lIgnora) -> {lOk, cMsg}. Conta de servico: nao expira por troca periodica. |
| `GEBSECFORCATROCA` | `GEBSECFORCATROCA(cUsuLog, cAlvo, lForca)` | GEBSECFORCATROCA(cUsuLog, cAlvo, lForca) -> {lOk, cMsg}. Troca obrigatoria no proximo logon. |

**`src/GEBSEC_LOGIN.prw`** — 8 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECLOGIN` | `GEBSECLOGIN(cUser, cPass, cIP)` | — |
| `HashSenha` | `HashSenha(cSenha, cSalt)` | para binario -- nao ha necessidade). |
| `HexEncode` | `HexEncode(cBin)` | — |
| `GEBSECSALT` | `GEBSECSALT()` | Gera um salt aleatorio por usuario para HashSenha(): 32 caracteres hexadecimais (16 bytes) derivados de UUIDRandom() -- UUID v4 gerado com crypto/rand pelo runtime AdvPP... |
| `GEBSECPODE` | `GEBSECPODE(cUsuario, cAlvo, lExigeVinc)` | Regra unica de autorizacao para agir sobre usuarios (criar, alterar, trocar senha, excluir, vincular), usada pela API e pela tela. |
| `GEBSECDERRUBA` | `GEBSECDERRUBA(cUsu)` | troca de senha por outra pessoa costuma responder a comprometimento. |
| `GEBSECISSUPER` | `GEBSECISSUPER(cUsu)` | Diz se o codigo e' a conta global super (case-insensitive). |
| `GEBSECCRIAUSU` | `GEBSECCRIAUSU(cUsu, cSenha, aEmpresas, cNome, cPerfil, lPermiteSuper, cFilial)` | — |

**`src/GEBSEC_MIG.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `TCSecMIG` | `TCSecMIG()` | — |
| `GEBSECBOOT` | `GEBSECBOOT()` | Conta "super" em instalacao nova. |

**`src/GEBSEC_POL.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECPOL_VERIFICA` | `GEBSECPOL_VERIFICA(cSenha)` | — |
| `GEBSECPOL_EXPIRACAO` | `GEBSECPOL_EXPIRACAO(cUsuario)` | — |
| `GEBSECPOL_FORCA` | `GEBSECPOL_FORCA(nForca)` | — |
| `GEBSECFORCAR` | `GEBSECFORCAR(cUsuario)` | — |

**`src/GEBSEC_RBA.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECRBAC` | `GEBSECRBAC(cUsuario, cMenu, cItem)` | — |
| `GEBSECRBACADD` | `GEBSECRBACADD(cPerfil, cMenu, cItem, lPermite)` | — |
| `GEBSECRBACADDEMP` | `GEBSECRBACADDEMP(cPerfil, cEmpresa, cMenu, cItem, lPermite)` | — |
| `GEBSECRBACLIST` | `GEBSECRBACLIST(cPerfil)` | — |
| `GEBSECRBACLISTEMP` | `GEBSECRBACLISTEMP(cPerfil, cEmpresa)` | cEmpresa "*" lista so' as globais. |

**`src/GEBSEC_TOKEN.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECTOKEN` | `GEBSECTOKEN(cUsuario, cEmpresa, cFilial, cIP)` | — |
| `GEBSECTOKENDEL` | `GEBSECTOKENDEL(cToken)` | Invalida token (soft-delete). |

### GEB_TUI (interface PO-UI)

**`src/GEBTUI.prw`** — 9 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBTUI` | `GEBTUI()` | Interface do GEBAN em componentes PO-UI (PoApp): login (com troca de senha obrigatoria/expirada), empresa e filial, menu lateral com os modulos permitidos e uma pagina por... |
| `GEBTUIBRWAPP` | `GEBTUIBRWAPP(bBloco)` | Desvia GEBTUIBRW para um bloco {/cAlias, cTitulo/ ...} (Nil = FWMBrowse). |
| `GEBTUIEMPRESAS` | `GEBTUIEMPRESAS(cUsu)` | Lista empresas do catalogo para o menu (pares {cod, nome}). |
| `GEBTUIFILIAL` | `GEBTUIFILIAL(cUsu, cEmp)` | Filiais do usuario na empresa, {{rotulo, codigo}} ("" = matriz). |
| `GEBTUIBRW` | `GEBTUIBRW(cAlias, cTitle)` | Abre browse FWMBrowse da tabela (padrao GesCon). |
| `GEBTUITROCASENHA` | `GEBTUITROCASENHA(cUsuLog, cAlvo, cSenha, cNome, cPerfil)` | Troca senha e/ou propriedades (nome, perfil) de um usuario. |
| `GEBTUIMODOK` | `GEBTUIMODOK(cUsu, cMenu, lAvisa)` | .T. |
| `GEBTUIPERMSETEMP` | `GEBTUIPERMSETEMP(cUsuLog, cEmpresa, cPerfil, cMenu, cItem, lPermite)` | Concede (lPermite .T.) ou revoga (.F.) uma area para um perfil, numa empresa. |
| `GEBTUIPERMSET` | `GEBTUIPERMSET(cUsuLog, cPerfil, cMenu, cItem, lPermite)` | Concede ou revoga uma area para um perfil em TODAS as empresas. |

### GEB_REST_WEB

**`src/GEBREST.prw`** — 55 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBREST` | `GEBREST(cMetodo, cPath, aParams, cUsuario, cIP)` | — |
| `GEBRESTHEALTH` | `GEBRESTHEALTH(cUsuario)` | Endpoint /health. |
| `GEBRESTUSRLST` | `GEBRESTUSRLST(cUsuario)` | Endpoint GET /usuarios. |
| `GEBRESTURGET` | `GEBRESTURGET(cUsuario, cCod)` | Endpoint GET /usuarios/{cod}. |
| `GEBRESTURLSC` | `GEBRESTURLSC(cUsuario, aBody)` | Endpoint POST /usuarios. |
| `GEBRESTUSRUPD` | `GEBRESTUSRUPD(cUsuario, cCod, aBody)` | Endpoint PUT /usuarios/{cod}. |
| `GEBRESTUSRRM` | `GEBRESTUSRRM(cUsuario, cCod)` | Endpoint DELETE /usuarios/{cod}. |
| `GEBRESTEMPLST` | `GEBRESTEMPLST(cUsuario)` | Endpoint GET /empresas. |
| `GEBRESTEMPLSC` | `GEBRESTEMPLSC(cUsuario, aBody)` | Endpoint POST /empresas. |
| `GEBRESTPRDLST` | `GEBRESTPRDLST(cUsuario)` | Endpoint GET /produtos. |
| `GEBRESTALISC` | `GEBRESTALISC(cUsuario, aBody)` | Cadastra aliquota IBS/CBS (percentual) de uma NCM com vigencia em GF2. |
| `GEBRESTPRDLSC` | `GEBRESTPRDLSC(cUsuario, aBody)` | Endpoint POST /produtos. |
| `GEBRESTNOTLST` | `GEBRESTNOTLST(cUsuario, aParams)` | Endpoint GET /notas. |
| `GEBRESTNOTPOST` | `GEBRESTNOTPOST(cUsuario, aBody)` | Endpoint POST /notas. |
| `GEBRESTFLXLST` | `GEBRESTFLXLST(cUsuario)` | Endpoint GET /financeiro/fluxo. |
| `GEBRESTCONLST` | `GEBRESTCONLST(cUsuario)` | Endpoint GET /financeiro/contas. |
| `GEBRESTRELFISSC` | `GEBRESTRELFISSC(cUsuario, cComp)` | Endpoint GET /fiscal/relatorio/{comp}. |
| `GEBRESTRELGER` | `GEBRESTRELGER(cUsuario)` | Endpoint GET /relatorios/gerencial. |
| `GEBRESTMONUSU` | `GEBRESTMONUSU(cUsuario)` | Endpoint GET /monitor/usuarios. |
| `GEBRESTMONDES` | `GEBRESTMONDES(cUsuario, cToken)` | Endpoint DELETE /monitor/sessao/{token}. |
| `GEBRESTDERLST` | `GEBRESTDERLST(cUsuario)` | Endpoint GET /derrama/guias. |
| `GEBRESTESTLST` | `GEBRESTESTLST(cUsuario)` | Endpoint GET /estoque. |
| `GEBRESTVENLST` | `GEBRESTVENLST(cUsuario)` | Endpoint GET /estoque/vendas. |
| `GEBRESTCTBLST` | `GEBRESTCTBLST(cUsuario)` | Endpoint GET /contabil/lancamentos. |
| `GEBRESTCTCLST` | `GEBRESTCTCLST(cUsuario)` | Endpoint GET /contabil/contas. |
| `GEBRESTCOMLST` | `GEBRESTCOMLST(cUsuario)` | Endpoint GET /compras/pedidos. |
| `GEBRESTFORLST` | `GEBRESTFORLST(cUsuario)` | Endpoint GET /compras/fornecedores. |
| `GEBRESTFILLST` | `GEBRESTFILLST(cUsuario)` | Endpoint GET /filiais. |
| `GEBRESTFILSC` | `GEBRESTFILSC(cUsuario, aBody)` | Endpoint POST /filiais. |
| `GEBRESTVINCSC` | `GEBRESTVINCSC(cUsuario, aBody)` | Endpoint POST /vinculos. |
| `GEBRESTPUBEMP` | `GEBRESTPUBEMP(cUsuario)` | Endpoint GET /public/empresas. |
| `GEBRESTDERGER` | `GEBRESTDERGER(cUsuario, aBody)` | Endpoint POST /derrama/gerar. |
| `GEBRESTDERBAI` | `GEBRESTDERBAI(cUsuario, aBody)` | Endpoint POST /derrama/baixar. |
| `GEBRESTDERPAR` | `GEBRESTDERPAR(cUsuario, aBody)` | Endpoint POST /derrama/parcelar. |
| `GEBRESTDERJUR` | `GEBRESTDERJUR(cUsuario, aBody)` | Endpoint POST /derrama/juros. |
| `GEBRESTDERPRO` | `GEBRESTDERPRO(cUsuario, aBody)` | Endpoint POST /derrama/protestar. |
| `GEBRESTESTVEN` | `GEBRESTESTVEN(cUsuario, aBody)` | Endpoint POST /estoque/vender. |
| `GEBRESTESTFIA` | `GEBRESTESTFIA(cUsuario, aBody)` | Endpoint POST /estoque/fiado. |
| `GEBRESTESTFIJ` | `GEBRESTESTFIJ(cUsuario, aBody)` | Endpoint POST /estoque/fiado/juros. |
| `GEBRESTCTBDIR` | `GEBRESTCTBDIR(cUsuario, aBody)` | Endpoint POST /contabil/lancar. |
| `GEBRESTCTBBAL` | `GEBRESTCTBBAL(cUsuario, cComp)` | Endpoint GET /contabil/balancete. |
| `GEBRESTCTBDRE` | `GEBRESTCTBDRE(cUsuario, cComp)` | Endpoint GET /contabil/dre. |
| `GEBRESTFINCON` | `GEBRESTFINCON(cUsuario, aBody)` | Endpoint POST /financeiro/contas. |
| `GEBRESTFINBAI` | `GEBRESTFINBAI(cUsuario, aBody)` | Endpoint POST /financeiro/baixar. |
| `GEBRESTCOMFOR` | `GEBRESTCOMFOR(cUsuario, aBody)` | Endpoint POST /compras/fornecedores. |
| `GEBRESTCOMPED` | `GEBRESTCOMPED(cUsuario, aBody)` | Endpoint POST /compras/pedidos. |
| `GEBRESTCOMIT` | `GEBRESTCOMIT(cUsuario, aBody)` | Endpoint POST /compras/itens. |
| `GEBRESTCOMENT` | `GEBRESTCOMENT(cUsuario, aBody)` | Endpoint POST /compras/entradas. |
| `GEBRESTFISAPU` | `GEBRESTFISAPU(cUsuario, aBody)` | Endpoint POST /fiscal/apurar. |
| `GEBRESTSNCFG` | `GEBRESTSNCFG(cUsuario, aBody)` | Endpoints POST /fiscal/simples/config {anexo, inicio AAAAMM}, /fiscal/simples/folha {competencia, folha, receita_externa, atividade}, /fiscal/simples/apurar {competencia},... |
| `GEBRESTSNFOL` | `GEBRESTSNFOL(cUsuario, aBody)` | — |
| `GEBRESTSNAPU` | `GEBRESTSNAPU(cUsuario, aBody)` | — |
| `GEBRESTFISCRE` | `GEBRESTFISCRE(cUsuario, aBody)` | Endpoint POST /fiscal/creditos. |
| `GEBRESTUNILST` | `GEBRESTUNILST(cUsuario)` | Endpoint GET /unidades. |
| `GEBRESTUNILSC` | `GEBRESTUNILSC(cUsuario, aBody)` | Endpoint POST /unidades. |

**`src/GEBWEB.prw`** — 18 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBWEB` | `GEBWEB(nPorta)` | Servidor HTTP real (WSRestServer, AdvPP nativo): API REST do ERP (integracoes). |
| `GEBWEB_LOGINAPI` | `GEBWEB_LOGINAPI(oReq)` | POST /api/login -- autentica de verdade. |
| `GEBWAPI_PDVCAIXALST` | `GEBWAPI_PDVCAIXALST(oReq)` | — |
| `GEBWAPI_PDVCAIXAABR` | `GEBWAPI_PDVCAIXAABR(oReq)` | — |
| `GEBWAPI_PDVCAIXAFECH` | `GEBWAPI_PDVCAIXAFECH(oReq)` | — |
| `GEBWAPI_PDVCAIXARESUMO` | `GEBWAPI_PDVCAIXARESUMO(oReq)` | — |
| `GEBWAPI_PDVSANGRIA` | `GEBWAPI_PDVSANGRIA(oReq)` | — |
| `GEBWAPI_PDVCUPOMNOV` | `GEBWAPI_PDVCUPOMNOV(oReq)` | — |
| `GEBWAPI_PDVCUPOMGET` | `GEBWAPI_PDVCUPOMGET(oReq)` | — |
| `GEBWAPI_PDVCUPCANC` | `GEBWAPI_PDVCUPCANC(oReq)` | — |
| `GEBWAPI_PDVPRODUTBUSC` | `GEBWAPI_PDVPRODUTBUSC(oReq)` | — |
| `GEBWAPI_PDVRELGER` | `GEBWAPI_PDVRELGER(oReq)` | — |
| `GEBWAPI_PDVRELGERCSV` | `GEBWAPI_PDVRELGERCSV(oReq)` | — |
| `GEBWAPI_PDVRELCOM` | `GEBWAPI_PDVRELCOM(oReq)` | — |
| `GEBWAPI_PDVRELCOMCSV` | `GEBWAPI_PDVRELCOMCSV(oReq)` | — |
| `GEBWAPI_PDVPERIFLIST` | `GEBWAPI_PDVPERIFLIST(oReq)` | — |
| `GEBWAPI_PDVPERIFREG` | `GEBWAPI_PDVPERIFREG(oReq)` | — |
| `GEBWAPI_PDVPERIFDEL` | `GEBWAPI_PDVPERIFDEL(oReq)` | — |

**`src/GEBWEB_API.prw`** — 64 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBWAPI_HEALTH` | `GEBWAPI_HEALTH(oReq)` | GET /api/health -- publico, sem token. |
| `GEBWAPI_USRLST` | `GEBWAPI_USRLST(oReq)` | GET /api/usuarios -- lista usuarios (auth). |
| `GEBWAPI_USRGET` | `GEBWAPI_USRGET(oReq)` | GET /api/usuarios/{cod} -- detalha usuario (auth). |
| `GEBWAPI_USRPOST` | `GEBWAPI_USRPOST(oReq)` | POST /api/usuarios -- cria usuario (auth, via GEBSECCRIAUSU). |
| `GEBWAPI_USRPUT` | `GEBWAPI_USRPUT(oReq)` | PUT /api/usuarios/{cod} -- atualiza nome/perfil/senha (auth). |
| `GEBWAPI_USRDEL` | `GEBWAPI_USRDEL(oReq)` | DELETE /api/usuarios/{cod} -- remove usuario (auth). |
| `GEBWAPI_EMPLST` | `GEBWAPI_EMPLST(oReq)` | GET /api/empresas -- lista empresas (auth). |
| `GEBWAPI_EMPLSC` | `GEBWAPI_EMPLSC(oReq)` | POST /api/empresas -- cria empresa em GE1 (auth). |
| `GEBWAPI_PRDLST` | `GEBWAPI_PRDLST(oReq)` | GET /api/produtos -- lista produtos GF1 (auth). |
| `GEBWAPI_PRDLSC` | `GEBWAPI_PRDLSC(oReq)` | POST /api/produtos -- cria produto GF1 (auth). |
| `GEBWAPI_NOTLST` | `GEBWAPI_NOTLST(oReq)` | GET /api/notas -- lista notas GF3 com filtros periodo/status (auth). |
| `GEBWAPI_NOTPOST` | `GEBWAPI_NOTPOST(oReq)` | POST /api/notas -- emite nota via GEBFEMI (auth). |
| `GEBWAPI_FLXLST` | `GEBWAPI_FLXLST(oReq)` | GET /api/financeiro/fluxo -- resumo fluxo de caixa (auth). |
| `GEBWAPI_CONLST` | `GEBWAPI_CONLST(oReq)` | GET /api/financeiro/contas -- lista contas GFN1 (auth). |
| `GEBWAPI_RELFISC` | `GEBWAPI_RELFISC(oReq)` | GET /api/fiscal/relatorio/{comp} -- relatorio fiscal (auth). |
| `GEBWAPI_RELGER` | `GEBWAPI_RELGER(oReq)` | GET /api/relatorios/gerencial -- relatorio gerencial (auth). |
| `GEBWAPI_MONUSU` | `GEBWAPI_MONUSU(oReq)` | GET /api/monitor/usuarios -- usuarios online (auth, ADMIN/monitor). |
| `GEBWAPI_MONDEL` | `GEBWAPI_MONDEL(oReq)` | DELETE /api/monitor/sessao/{sessao} -- invalida sessao (auth). |
| `GEBWAPI_DERLST` | `GEBWAPI_DERLST(oReq)` | GET /api/derrama/guias -- lista guias GD1 (auth). |
| `GEBWAPI_ESTLST` | `GEBWAPI_ESTLST(oReq)` | GET /api/estoque -- saldos GV1 (auth). |
| `GEBWAPI_VENLST` | `GEBWAPI_VENLST(oReq)` | GET /api/estoque/vendas -- vendas GV2 (auth). |
| `GEBWAPI_CTBLST` | `GEBWAPI_CTBLST(oReq)` | GET /api/contabil/lancamentos -- lancamentos GC2 (auth). |
| `GEBWAPI_CTCLST` | `GEBWAPI_CTCLST(oReq)` | GET /api/contabil/contas -- plano de contas GC1 (auth). |
| `GEBWAPI_COMLST` | `GEBWAPI_COMLST(oReq)` | GET /api/compras/pedidos -- pedidos GCP3 (auth). |
| `GEBWAPI_FORLST` | `GEBWAPI_FORLST(oReq)` | GET /api/compras/fornecedores -- fornecedores GCP1 (auth). |
| `GEBWAPI_FILLST` | `GEBWAPI_FILLST(oReq)` | GET /api/filiais -- filiais GEF1 do tenant (auth). |
| `GEBWAPI_FILSC` | `GEBWAPI_FILSC(oReq)` | POST /api/filiais -- cadastra filial EEUUFF (auth). |
| `GEBWAPI_VINCSC` | `GEBWAPI_VINCSC(oReq)` | POST /api/vinculos -- vincula usuario a empresa+filial (auth). |
| `GEBWAPI_PUBEMP` | `GEBWAPI_PUBEMP(oReq)` | GET /api/public/empresas -- empresas para o seletor de ambiente (publico, sem token). |
| `GEBWAPI_DERGER` | `GEBWAPI_DERGER(oReq)` | POST /api/derrama/gerar -- gera guia (auth). |
| `GEBWAPI_DERBAI` | `GEBWAPI_DERBAI(oReq)` | POST /api/derrama/baixar -- quita guia (auth). |
| `GEBWAPI_DERPAR` | `GEBWAPI_DERPAR(oReq)` | POST /api/derrama/parcelar -- parcela guia (auth). |
| `GEBWAPI_DERJUR` | `GEBWAPI_DERJUR(oReq)` | POST /api/derrama/juros -- calcula juros (auth). |
| `GEBWAPI_DERPRO` | `GEBWAPI_DERPRO(oReq)` | POST /api/derrama/protestar -- protesta guia (auth). |
| `GEBWAPI_ESTVEN` | `GEBWAPI_ESTVEN(oReq)` | POST /api/estoque/vender -- vende (auth). |
| `GEBWAPI_ESTFIA` | `GEBWAPI_ESTFIA(oReq)` | POST /api/estoque/fiado -- vende fiado (auth). |
| `GEBWAPI_ESTFIJ` | `GEBWAPI_ESTFIJ(oReq)` | POST /api/estoque/fiados/juros -- juros do fiado (auth). |
| `GEBWAPI_CTBDIR` | `GEBWAPI_CTBDIR(oReq)` | POST /api/contabil/lancar -- lancamento direto (auth). |
| `GEBWAPI_CTBBAL` | `GEBWAPI_CTBBAL(oReq)` | GET /api/contabil/balancete/{comp} -- balancete (auth, via dispatcher). |
| `GEBWAPI_CTBDRE` | `GEBWAPI_CTBDRE(oReq)` | GET /api/contabil/dre/{comp} -- DRE (auth, via dispatcher). |
| `GEBWAPI_FINCON` | `GEBWAPI_FINCON(oReq)` | POST /api/financeiro/contas -- cria conta (auth). |
| `GEBWAPI_FINBAI` | `GEBWAPI_FINBAI(oReq)` | POST /api/financeiro/baixar -- baixa titulo (auth). |
| `GEBWAPI_COMFOR` | `GEBWAPI_COMFOR(oReq)` | POST /api/compras/fornecedores -- cadastra (auth). |
| `GEBWAPI_COMPED` | `GEBWAPI_COMPED(oReq)` | POST /api/compras/pedidos -- abre pedido (auth). |
| `GEBWAPI_COMIT` | `GEBWAPI_COMIT(oReq)` | POST /api/compras/itens -- adiciona item (auth). |
| `GEBWAPI_COMENT` | `GEBWAPI_COMENT(oReq)` | POST /api/compras/entradas -- da entrada (auth). |
| `GEBWAPI_FISAPU` | `GEBWAPI_FISAPU(oReq)` | POST /api/fiscal/apurar -- apura competencia (auth). |
| `GEBWAPI_SNCFG` | `GEBWAPI_SNCFG(oReq)` | POST /api/fiscal/simples/config (anexo, inicio), /folha (competencia, folha, receita_externa) e /apurar (competencia) -- Simples Nacional (auth). |
| `GEBWAPI_SNFOL` | `GEBWAPI_SNFOL(oReq)` | — |
| `GEBWAPI_SNAPU` | `GEBWAPI_SNAPU(oReq)` | — |
| `GEBWAPI_SNATV` | `GEBWAPI_SNATV(oReq)` | — |
| `GEBWAPI_SNPRD` | `GEBWAPI_SNPRD(oReq)` | — |
| `GEBWAPI_SNEXP` | `GEBWAPI_SNEXP(oReq)` | — |
| `GEBWAPI_SNFER` | `GEBWAPI_SNFER(oReq)` | — |
| `GEBWAPI_BOPOST` | `GEBWAPI_BOPOST(oReq)` | POST/GET /api/bo/{modulo}/{acao} -- backoffice (auth). |
| `GEBWAPI_BOGET` | `GEBWAPI_BOGET(oReq)` | — |
| `GEBWAPI_SNEXT` | `GEBWAPI_SNEXT(oReq)` | GET /api/fiscal/simples/extrato/{comp} e /anual/{ano} -- relatorios do Simples (auth). |
| `GEBWAPI_SNANU` | `GEBWAPI_SNANU(oReq)` | — |
| `GEBWAPI_FISCRE` | `GEBWAPI_FISCRE(oReq)` | POST /api/fiscal/creditos -- lanca credito (auth). |
| `GEBWAPI_UNILST` | `GEBWAPI_UNILST(oReq)` | GET /api/unidades -- unidades GEU1 (auth). |
| `GEBWAPI_UNILSC` | `GEBWAPI_UNILSC(oReq)` | POST /api/unidades -- cadastra unidade UU (auth). |
| `GEBWAPI_DFEPAG` | `GEBWAPI_DFEPAG(oReq)` | GET /api/dfe/configurar -- pagina (publica) do assistente fiscal: entra com empresa/usuario/senha (POST /api/login) e, com o token, mostra o roteiro "o que falta para emitir",... |
| `GEBWAPI_DFEDANFE` | `GEBWAPI_DFEDANFE(oReq)` | GET /api/dfe/danfe?token=&empresa=&chave= (ou &cupom=) -- DANFE NFC-e em HTML para imprimir (permissao LOJA/CAIXA ou FISCAL/DFE). |
| `GEBWAPI_DFEEFD` | `GEBWAPI_DFEEFD(oReq)` | GET /api/dfe/efd?token=&empresa=&competencia= -- arquivo da EFD ICMS/IPI gerado (texto para o PVA). |

### OUTROS

**`src/_init.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `TEST_INIT` | `TEST_INIT()` | — |

## 9. Testes (72 suítes, 72/72 PASS em duas rodadas seguidas num `geban_test` vazio, 02/10/2026, advplc v4.4.0-geban)

Um comando: **`o runner de testes [T_NOME ...]`** — envia `src/`+`tests/` ao servidor de testes,
roda cada `tests/T_*.prw` contra o banco **`geban_test`** (nunca `geban`; o script
aborta se o alvo não for o de teste e compara a lista de schemas da produção antes e
depois), com tempo-limite por teste (`GEBAN_TEST_TIMEOUT`, padrão 300 s) e stdin
fechado; imprime `PASS/FAIL/ERRO/TIMEOUT` por teste e o placar; logs em
`tests/.out/logs/`. `--selftest` testa o classificador localmente. `GEBAN_ADVPLC`
troca o binário (ex.: testar um advplc novo antes de instalar).
Suítes novas desta revisão: `T_GEBISO` (isolamento entre empresas sob concorrência),
`T_GEBSEC_API` (token), `T_GEBSEC_ACESSO` (matriz de acesso, 21 casos),
`T_GEBTUI_FLUXOS` (as 25 ações da tela contra docs/02), `T_GEBDB_MOEDA` (NUMERIC).
Defeitos conhecidos e status: `documentacao interna`.

## 10. Deploy e operação

Serviços no servidor de testes (working dir `/opt/geban`): `geban.service` (`advplc serve
src/GEBTUI.prw --port 8081`, console), `gebansocat.service` (8080→8081),
`geban-nat.service`, `gebweb.service` (REST/HTML 8090), `cloudflared.service`
(túnel para `SEU-DOMINIO` — nunca reiniciar junto: `Wants`, não `Requires`).
Runtime: `advplc v4.4.0-geban` em `/usr/local/bin` (anterior em
`advplc.bak-v432`). **Deploy: `o script de publicacao`** (testes 100% → backup → envio →
conferência → rollback automático). **Backup: `geban-backup.timer`** (02:30, 7 dias,
restauração conferida a cada backup). Procedimentos: o runbook de operacao (interno). Segredos: `GEBAN_PG_*` via `o arquivo de variaveis do banco` (600, só root),
nunca em código/log/commit. Conta `super` provisionada via `GEBSECCRIAUSU` com
`lPermiteSuper` (senha inicial entregue uma vez ao operador e rotacionada por ele).

## 11. Mudanças recentes incorporadas

- **Revisão geral (02/10/2026, `documentacao interna`):**
  isolamento entre empresas no AdvPP 4.4.0-geban (conexão por sessão/requisição);
  injeção SQL na autenticação da `/api` e token previsível corrigidos; escape em 156
  pontos; regra única `GEBSECPODE`; monitor sem tokens; bloqueio temporário; grades do
  catálogo só leitura; dinheiro `NUMERIC`; DRE/balancete da tela corrigidos; cadastro
  de alíquota; operação com deploy/rollback e backup conferido.

- Conta global `super` por username no lugar de `ADMIN` por perfil (bypass, criar
  empresa, guardas REST/TUI, `GEBSECISSUPER`, escopo por empresa) + bootstrap da
  primeira empresa pelo super no TUI + ação Trocar senha (`GEBTUITROCASENHA`).
- `GEBDBSetTenant` estrito (rejeita schema inexistente); `GEBDB_TENANT` auto-suficiente
  em includes; R_E_C_N_O_ `BY DEFAULT` (deriva `ALWAYS` migrada).
- AdvPP v4.3.2: `FWMBrowse` usa `R_E_C_N_O_` em vez de `rowid` (funciona em SQLite e
  Postgres); includes `LOGIN` completados onde o RBAC passou a exigir.
- Higiene de testes: asserts da regra vigente, bootstraps por schema, cleanups
  completos (`m5`, `zzwrongfil`, `emp_03`).

*Divergência entre este texto e o fonte? O `.prw` vence — abra o arquivo indicado.*

## 12. Backoffice (18/10/2026)

**Fontes e serviços centrais**

| Fonte | Funções principais |
|---|---|
| `GEBBOLIB.prw` | `BOTAB`, `BOSEQ` (numerador GBS1), `BOREL` (grade GBR1), `BODTADD`/`BODIAS`/`BODATA` (datas), `BOQ`/`BOQN`/`BOQITENS` (campos da API), `BOPARM` (GE4 com padrão) |
| `GEBCTX.prw` | `GEBCTXMIG` (plano + eventos), `GEBCTXLP`, `GEBCTXREV`, `GEBCTXFIN`, relatórios `GEBCTXRAZAO`/`GEBCTXBALAN`/`GEBCTXDRE` |
| `GEBEST.prw` | `GEBESTMOV` (serviço central), `GEBESTSLD`, `GEBESTAJU`, `GEBESTTRF`, relatórios `GEBESTKARDEX`/`GEBESTPOS` |
| `GEBFNX.prw` | `GEBFXCOND`, `GEBFXPARC`, `GEBFXTIT`, `GEBFXCALC`, `GEBFXBAI`, `GEBFXTRF`, `GEBFXMOV`, `GEBFXMOVCONTA`, relatórios `GEBFXPOSICAO`/`GEBFXEXTRATO`/`GEBFXFLUXO` |
| `GEBCPX.prw` | `GEBCPXSC`, `GEBCPXGERA`, `GEBCPXPED`, `GEBCPXAPR`, `GEBCPXENT`, relatórios `GEBCPXABERTOS`/`GEBCPXPORFORN`/`GEBCPXSCPEND` |
| `GEBFAT.prw` | `GEBFATCLI`, `GEBFATPRC`, `GEBFATPRECO`, `GEBFATPED`, `GEBFATLIB`, `GEBFATCAN`, `GEBFATFAT`, `GEBFATNOTA` (nota com vários itens), `GEBFATDEV`, relatórios `GEBFATREL`/`GEBFATCARTEIRA`/`GEBFATABC` |
| `GEBLOJ.prw` | `GEBLOJCX`, `GEBLOJABRE`, `GEBLOJVEN` (código de barras, promoção, vendedor, CPF, limite de desconto, pagamento `VALE`/`CRYPTO`, regime `FISCAL`/`COMPROVANTE`), `GEBLOJCAN`, `GEBLOJSAN`, `GEBLOJFECHA`, relatórios `GEBLOJRESUMO`/`GEBLOJVENDAS`; `GEBLOJSES`/`GEBLOJCXA`/`GEBLOJESP` (sessão, caixa, dinheiro esperado) |
| `GEBLOJ_CAD.prw` | `GEBLOJCADMIG` (GLJ8–GLJH), `GEBLOJBAR` (código de barras/PLU), `GEBLOJEANOK`, `GEBLOJRESOLVE` (produto, GTIN ou etiqueta de balança), `GEBLOJPROMO`, `GEBLOJPRECO` (melhor promoção vigente), `GEBLOJVEND`/`GEBLOJVENDOK`, `GEBLOJCPFOK`, `GEBLOJDIGITOS` |
| `GEBLOJ_OPE.prw` | `GEBLOJORC`/`GEBLOJORCFIN`/`GEBLOJORCCAN` (orçamento), `GEBLOJDEV` (devolução no caixa), `GEBLOJVALE`, `GEBLOJCUPOM` (segunda via), `GEBLOJCONS` (consulta de preço), relatórios `GEBLOJORCS`/`GEBLOJGER`/`GEBLOJCOMIS` |
| `GEBBO.prw` | `GEBBOROTAS` (tabela de rotas e permissões), `GEBBOROTA`, `GEBBOEXEC` |
| `GEBBCO.prw` | `GEBBCOCFG`, `GEBBCOBOL`, `GEBBCOBARRAS`/`GEBBCOLINHA`/`GEBBCOMOD10`/`GEBBCOMOD11`/`GEBBCONNDV`/`GEBBCOFATOR`, `GEBBCOLIVRE` (campo livre e nosso número por banco: 001, 033, 104, 237, 341, 756), `GEBBCOHTML`, `GEBBCOREM`/`GEBBCORET` (CNAB 240 FEBRABAN v10.3 para todos; CNAB 400 do Itaú e do Bradesco), `GEBBCOOFX`, `GEBBCOCONC`/`GEBBCOCONCMAN`/`GEBBCOLANCA`, relatório `GEBBCOREL` |
| `GEBTEF.prw` | `GEBTEFCFG`, `GEBTEFAUT`, `GEBTEFCONF`, `GEBTEFDESF`, `GEBTEFCANC`, `GEBTEFRESOLVE`, `GEBTEFRESP`, `GEBTEFCIELO` (leitura da resposta da API Cielo e-Commerce 3.0), relatório `GEBTEFREL` |
| `GEBTUIBO.prw` | telas `GEBTUIFAT`, `GEBTUILOJ`, `GEBTUIBOEST`, `GEBTUIBOFIN`, `GEBTUIBOCTB`, `GEBTUIBOCOM` |
| `GEBDER_FIN.prw` | Derrama ↔ financeiro: `GEBDERGUIA` (guia + título a pagar de mesmo número; reapuração; guia complementar), `GEBDERPAGA` (paga a guia pelo financeiro), `GEBDERPODEPAR`/`GEBDERPARTIT` (parcelamento em títulos), `GEBDERTITS`, `GEBDERPROV` (provisão contábil pela diferença), `GEBDERFMIG` (GD4) |
| `GEBRET.prw` | Retenções: `GEBRETCAD` (regra), `GEBRETVAL`, `GEBRETAPL` (na entrada de compra), relatório `GEBRETREL`, `GEBRETMIG` |
| `GENUC_MIG.prw` | `GEBREGIME()` — regime único da empresa (parâmetro `REGIME`; senão a linha da empresa na GE1 com nome `SIMPLES`; senão `REGULAR`) |
| `GEBCRY.prw` | Pagamento crypto no PDV: `GEBCRYMIG` (GCK1 wallet, GCK2 auditoria do pagamento), `GEBCRYMOEDAS` (lista fechada BTC/ETH/XMR/USDC/USDT), `GEBCRYWAL`/`GEBCRYWALLST` (wallets), `GEBCRYCOT` (cotação BRL via CoinGecko), `GEBCRYQRCODE` (URI de pagamento BIP21/EIP-681), `GEBCRYPAGA`/`GEBCRYPAGOS` |
| `GESSAR.prw` | Gatilho Sarney (remarcação agendada de preços): `GESSARMIG` (GSK1 regra, GSK2 override por produto, GSK3 log), `GESSARCFG`/`GESSARLISTA`/`GESSARHIST`, `GESSARPROD` (override), `GESSARDEVE` (decisão pura: slot, vezes, slot único/dia), `GESSARAPLICA` (reajusta GFT2 PADRAO), `GESSARRUN` (executor 1x/min pelo agendador, trava por empresa) |

Todas as funções de negócio devolvem `{lOk, cMsg, xDados}`. Os relatórios devolvem as linhas, com a primeira linha de cabeçalho, mais os totais em pares `{chave, valor}`.

**Tabelas novas** (schema da empresa):
- GBS1 numeradores, GBR1 grade de relatório;
- GES1/GES2 estoque, GES3–GES6 lote/série/endereço, GES7 fechamento mensal;
- GFX1–GFX4 financeiro, GBC1–GBC3 banco (cobrança, boletos, extrato OFX);
- GCC1/GCC2 centros de custo e rateios, GCX1 centro do lote contábil;
- GCQ1–GCQ7 compras (GCQ6 devolução de compra, GCQ7 IBS/CBS da entrada = crédito da apuração);
- GD4 complemento da guia da Derrama (tipo, competência, vencimento, conta contábil, credor);
- GRT1/GRT2 retenções (regras e retenções por documento);
- GFT1–GFT7 faturamento;
- GLJ1–GLJ7 loja (GLJ7 transações TEF); GLJ8 códigos de barras, GLJ9 promoções, GLJA promoção aplicada por item, GLJB complemento do cupom (vendedor, CPF, orçamento, quem liberou o desconto, hora), GLJC vendedores, GLJD/GLJE orçamentos, GLJF vales-troca, GLJH devoluções no caixa; GLJ3_REGIME (FISCAL/COMPROVANTE, DIFAL extraoficial);
- GCK1/GCK2 crypto (wallet do proprietário por moeda e auditoria do pagamento do cupom: moeda, endereço, BRL, quantidade e cotação);
- GSK1/GSK2/GSK3 Gatilho Sarney (regra de reajuste, override por produto e log de aplicação).

**Parâmetros GE4:** `EST_NEGATIVO`, `EST_VENCIDO`, `EST_FECHADO` (gravado pelo fechamento), `FIN_JUROS_DIA`, `FIN_MULTA`, `COM_ALCADA`, `BCO_DIAS_CONC`, `LOJ_CONTA_PIX`, `LOJ_CONTA_COFRE`, `LOJ_TAXA_DEB`, `LOJ_TAXA_CRED`, `LOJ_FIADO_DIAS`, `LOJ_DESC_MAX` (desconto máximo sem liberação, % do bruto; vazio = sem limite), `LOJ_BALANCA` (PRECO ou PESO na etiqueta), `LOJ_ORC_DIAS` (validade do orçamento, padrão 7), `LOJ_TEF` (S/N), `LOJ_TEF_PROVEDOR` (SIMULADOR/HTTP/CIELO), `LOJ_TEF_URL`, `LOJ_TEF_TOKEN`, `LOJ_TEF_TIMEOUT`, `LOJ_CIELO_URL` (padrão: sandbox), `LOJ_CIELO_MERCHANTID`, `LOJ_CIELO_MERCHANTKEY`, `LOJ_CIELO_CARTAO` e `LOJ_CIELO_BANDEIRA` (cartão usado na venda — só serve para a sandbox ou o emulador; ver docs/02 §19), `REGIME` (SIMPLES/REGULAR; gravado por `GEBSNCFG`), `DER_CONTA` (conta que paga a guia, padrão CAIXA), `DER_DIA_IBSCBS`, `DER_DIA_ICMS`, `DER_DIA_ISS` e `RET_DIA_<tributo>` (dia do vencimento, padrão 20, ajustado para dia útil); `LOJ_REG_ATIVO` (S/N, DIFAL extraoficial), `LOJ_REG_DESCC` (teto de desconto % com COMPROVANTE + dinheiro, padrão 10) e `LOJ_REG_DESCF` (demais casos, padrão 3); `CRY_CONTA` (conta financeira que recebe o valor crypto, ex.: `CRYPTO`) e `CRY_TIMEOUT` (timeout da cotação CoinGecko, padrão 15s).

**Contas e eventos da integração** (inseridos se faltarem): 2.01.004 IBS/CBS a recolher, 2.01.005 tributos retidos a recolher, 2.01.006 ICMS/ISS a recolher (fora do DAS), 3.02.002 IBS/CBS sobre vendas, 4.02.007 ICMS/ISS fora do DAS; eventos `APU_IBSCBS`, `SN_FORA`, `RET_FORN`, `FIN_RECEITA` (o `SN_DAS` passou a ser usado). Ver docs/02 §20. Frente de loja: `LOJ_VALE` (D 2.01.003 / C 3.01.001, venda paga com vale-troca).

**Venda da loja (`loja/venda`):** além de `sessao`, `itens`, `pagamentos`, `cliente` e `desconto`, aceita `vendedor`, `cpf`, `supervisor`, `senha_supervisor` (desconto acima de `LOJ_DESC_MAX`) e `regime` (`FISCAL` padrão ou `COMPROVANTE`; `loja/orcamento-finalizar` aceita `regime` também). Em `itens`, `produto` pode ser o código de barras ou a etiqueta da balança. Em `pagamentos`, a forma `VALE` leva o número do vale em `documento`; a forma `CRYPTO` leva `"MOEDA|ENDERECO"` em `documento` (ex.: `BTC|bc1q...`), exige `CRY_CONTA` configurada e wallet ativa da moeda — a cotação BRL→crypto é buscada no CoinGecko uma única vez por pagamento e o QR code é montado no caixa (`/api/pdv/crypto/previa`). Com `regime=COMPROVANTE` a venda não emite NFC-e **nem grava GF3/GF4** (o comprovante interno não entra na apuração de DAS nem de IBS/CBS; o faturamento `GEBFATFAT` segue a mesma regra e zera `GFT5_IBS`/`GFT5_CBS`). Com `LOJ_REG_ATIVO=S`, o teto de desconto passa a depender do regime: `COMPROVANTE` pago em dinheiro usa `LOJ_REG_DESCC`, qualquer outro caso usa `LOJ_REG_DESCF`.

**Propagação da forma CRYPTO pelos módulos:** PDV web (`pdv.html` + `GEBPDV_API`) e PDV TUI (`GEBTUIPDV`, campo `MOEDA|ENDERECO`) → `GEBLOJVEN` valida conta `CRY_CONTA`, wallet e cotação; na liquidação credita `CRY_CONTA` (`GEBFXMOVCONTA`), grava auditoria `GCK2` (moeda, endereço, BRL, quantidade, cotação) e lançamento contábil `LOJ_CRYPTO` (evento padrão débito `1.01.002` / crédito `3.01.001`, conta financeira real no débito); NFC-e leva `tPag=99` com `xPag="Crypto <MOEDA>"`; cancelamento (`GEBLOJCAN`) estorna a conta e o evento; `GEBLOJRESUMO` consolida `forma CRYPTO` por sessão.

**Entrada de compra (`compras/entrada`):** além de `nota`, `pedido`, `itens`, `frete` e `data`, aceita `retencoes` (códigos da GRT1 separados por vírgula, ex.: `ISS5,IR15`).

**Cobrança (`banco/cobranca`):** `conta`, `banco` (001, 033, 104, 237, 341, 756), `agencia`, `agencia_dv`, `conta_corrente`, `conta_dv`, `carteira`, `codigo_empresa` (código do beneficiário/convênio: 7 dígitos em 033/001/756, 6 em 104), `beneficiario`, `cnpj`, `layout` (240 ou 400; 400 só em 237/341; padrão 400 em 237/341 e 240 nos demais) e `modalidade` (Sicoob, padrão 01).

**Emulador Cielo:** `tests/emuladores/cielo_emulador.py` (só biblioteca padrão do Python, escuta em 127.0.0.1:18765). O `o runner de testes` o sobe antes da suíte se houver `python3` e o derruba no fim. Resultado pelo último dígito do cartão, como na sandbox (0/1/4/9 aprova; 2 → 05; 3 → 57; 5 → 78; 6 → 99; 7 → 77; 8 → 70).

**API** — `POST|GET /api/bo/{modulo}/{acao}`. Token e empresa vão como nas demais rotas, e os campos vão pelo nome no corpo ou na query. As listas `itens`, `pagamentos` (com `parcelas` no crédito) e `lotes` (`lote`, `validade`, `endereco`, `quantidade`) são arrays de objetos; o conteúdo de arquivos (retorno CNAB, OFX) vai no campo `conteudo`. Respostas:
- 200 `{"dados": [mensagem, dados]}`;
- 400 (recusa, com o motivo em `erros`);
- 403 (sem permissão);
- 404 (rota inexistente).

| Rota | Permissão (menu/item) | O quê |
|---|---|---|
| `POST /api/bo/estoque/movimento` | ESTOQUE/ESTOQ | Entrada/saida com custo |
| `POST /api/bo/estoque/inventario` | ESTOQUE/ESTOQ | Ajuste de inventario |
| `POST /api/bo/estoque/transferencia` | ESTOQUE/ESTOQ | Transferencia entre armazens |
| `GET /api/bo/estoque/saldo` | ESTOQUE/ESTOQ | Saldo e custo medio |
| `GET /api/bo/estoque/kardex` | ESTOQUE/ESTOQ | Relatorio: kardex |
| `GET /api/bo/estoque/posicao` | ESTOQUE/ESTOQ | Relatorio: posicao valorizada |
| `POST /api/bo/estoque/controle` | ESTOQUE/ESTOQ | Controle de lote/serie/endereco do produto |
| `POST /api/bo/estoque/endereco` | ESTOQUE/ESTOQ | Cadastro de endereco |
| `POST /api/bo/estoque/mudar-endereco` | ESTOQUE/ESTOQ | Mudanca de endereco |
| `GET /api/bo/estoque/lotes` | ESTOQUE/ESTOQ | Relatorio: saldo por lote/endereco |
| `GET /api/bo/estoque/vencer` | ESTOQUE/ESTOQ | Relatorio: lotes a vencer |
| `POST /api/bo/estoque/fechar` | ESTOQUE/ESTOQ | Fechamento mensal |
| `POST /api/bo/estoque/reabrir` | ESTOQUE/ESTOQ | Reabertura do ultimo mes fechado |
| `GET /api/bo/estoque/fechamento` | ESTOQUE/ESTOQ | Relatorio: fechamento do mes |
| `POST /api/bo/financeiro/condicao` | FINANCEIRO/FLUXO | Condicao de pagamento |
| `POST /api/bo/financeiro/titulo` | FINANCEIRO/FLUXO | Titulos parcelados |
| `POST /api/bo/financeiro/baixa` | FINANCEIRO/FLUXO | Baixa com juros/multa/desconto |
| `GET /api/bo/financeiro/calculo` | FINANCEIRO/FLUXO | Juros e multa por atraso |
| `POST /api/bo/financeiro/transferencia` | FINANCEIRO/FLUXO | Transferencia entre contas |
| `POST /api/bo/financeiro/movimento` | FINANCEIRO/FLUXO | Movimento avulso |
| `GET /api/bo/financeiro/posicao` | FINANCEIRO/FLUXO | Relatorio: titulos por faixa de atraso |
| `GET /api/bo/financeiro/extrato` | FINANCEIRO/FLUXO | Relatorio: extrato da conta |
| `GET /api/bo/financeiro/fluxo` | FINANCEIRO/FLUXO | Relatorio: fluxo de caixa projetado |
| `POST /api/bo/financeiro/despesa` | FINANCEIRO/FLUXO | Despesa a pagar com centro de custo |
| `POST /api/bo/banco/cobranca` | FINANCEIRO/BANCO | Dados de cobranca da conta |
| `POST /api/bo/banco/boleto` | FINANCEIRO/BANCO | Boleto do titulo |
| `GET /api/bo/banco/boleto-html` | FINANCEIRO/BANCO | Boleto para imprimir (HTML) |
| `POST /api/bo/banco/remessa` | FINANCEIRO/BANCO | Remessa CNAB 240 ou 400 |
| `POST /api/bo/banco/retorno` | FINANCEIRO/BANCO | Retorno CNAB 240 ou 400 (baixa) |
| `POST /api/bo/banco/ofx` | FINANCEIRO/BANCO | Importacao de extrato OFX |
| `POST /api/bo/banco/conciliar` | FINANCEIRO/BANCO | Conciliacao automatica |
| `POST /api/bo/banco/conciliar-manual` | FINANCEIRO/BANCO | Conciliacao manual |
| `POST /api/bo/banco/lancar-extrato` | FINANCEIRO/BANCO | Lanca linha do extrato (tarifa) |
| `GET /api/bo/banco/conciliacao` | FINANCEIRO/BANCO | Relatorio: conciliacao |
| `GET /api/bo/contabil/razao` | CONTABIL/LANCTO | Relatorio: razao |
| `GET /api/bo/contabil/balancete` | CONTABIL/LANCTO | Relatorio: balancete |
| `GET /api/bo/contabil/dre` | CONTABIL/LANCTO | Relatorio: DRE |
| `POST /api/bo/contabil/centro` | CONTABIL/LANCTO | Centro de custo |
| `POST /api/bo/contabil/rateio` | CONTABIL/LANCTO | Rateio entre centros |
| `GET /api/bo/contabil/resultado-centro` | CONTABIL/LANCTO | Relatorio: resultado por centro |
| `POST /api/bo/compras/solicitacao` | COMPRAS/PEDID | Solicitacao de compra |
| `POST /api/bo/compras/gerar` | COMPRAS/PEDID | Pedidos da solicitacao (menor preco) |
| `POST /api/bo/compras/pedido` | COMPRAS/PEDID | Pedido de compra |
| `POST /api/bo/compras/aprovar` | COMPRAS/APROVA | Aprovacao de alcada |
| `POST /api/bo/compras/entrada` | COMPRAS/PEDID | Documento de entrada |
| `POST /api/bo/compras/devolucao` | COMPRAS/PEDID | Devolucao de compra |
| `POST /api/bo/fiscal/retencao` | FISCAL/APURA | Regra de retencao (tributo e aliquota) |
| `GET /api/bo/fiscal/retencoes` | FISCAL/APURA | Relatorio: retencoes da competencia |
| `POST /api/bo/derrama/pagar` | DERRAMA/GUIAS | Paga a guia pelo financeiro (conta e data) |
| `POST /api/bo/contabil/corrigir-legado` | CONTABIL/DIR | Corrige lancamentos antigos (estorno e lancamento certo) |
| `GET /api/bo/compras/abertos` | COMPRAS/PEDID | Relatorio: pedidos em aberto |
| `GET /api/bo/compras/por-fornecedor` | COMPRAS/PEDID | Relatorio: compras por fornecedor |
| `GET /api/bo/compras/solicitacoes` | COMPRAS/PEDID | Relatorio: solicitacoes pendentes |
| `POST /api/bo/faturamento/cliente` | FATURAMENTO/FATUR | Cliente |
| `POST /api/bo/faturamento/preco` | FATURAMENTO/FATUR | Tabela de preco |
| `POST /api/bo/faturamento/pedido` | FATURAMENTO/FATUR | Pedido de venda |
| `POST /api/bo/faturamento/liberar` | FATURAMENTO/FATUR | Liberacao (credito e estoque) |
| `POST /api/bo/faturamento/cancelar` | FATURAMENTO/FATUR | Cancelamento de pedido |
| `POST /api/bo/faturamento/faturar` | FATURAMENTO/FATUR | Documento de saida |
| `POST /api/bo/faturamento/devolucao` | FATURAMENTO/FATUR | Devolucao de venda |
| `GET /api/bo/faturamento/relatorio` | FATURAMENTO/FATUR | Relatorio: faturamento e margem |
| `GET /api/bo/faturamento/carteira` | FATURAMENTO/FATUR | Relatorio: carteira de pedidos |
| `GET /api/bo/faturamento/abc` | FATURAMENTO/FATUR | Relatorio: curva ABC |
| `POST /api/bo/loja/caixa` | LOJA/CAIXA | Cadastro de caixa |
| `POST /api/bo/loja/abrir` | LOJA/CAIXA | Abertura de caixa |
| `POST /api/bo/loja/venda` | LOJA/CAIXA | Venda (cupom) |
| `POST /api/bo/loja/cancelar` | LOJA/CAIXA | Cancelamento de cupom |
| `POST /api/bo/loja/sangria` | LOJA/CAIXA | Sangria/suprimento |
| `POST /api/bo/loja/fechar` | LOJA/CAIXA | Fechamento de caixa |
| `GET /api/bo/loja/resumo` | LOJA/CAIXA | Relatorio: resumo do caixa |
| `GET /api/bo/loja/vendas` | LOJA/CAIXA | Relatorio: vendas do dia |
| `GET /api/bo/loja/tef` | LOJA/CAIXA | Relatorio: transacoes TEF do dia |
| `POST /api/bo/loja/tef-pendentes` | LOJA/CAIXA | Desfaz transacoes TEF pendentes |
| `POST /api/bo/loja/tef-config` | CONFIG/EMPRES | Configuracao do TEF (provedor, Cielo) |
| `POST /api/bo/loja/codigo-barras` | LOJA/GEREN | Codigo de barras / PLU de balanca do produto |
| `POST /api/bo/loja/promocao` | LOJA/GEREN | Promocao (preco, leve N pague M, desconto por quantidade) |
| `POST /api/bo/loja/vendedor` | LOJA/GEREN | Vendedor e comissao |
| `POST /api/bo/loja/orcamento` | LOJA/ORCAM | Orcamento (pre-venda) |
| `POST /api/bo/loja/orcamento-cancelar` | LOJA/ORCAM | Cancelamento de orcamento |
| `GET /api/bo/loja/orcamentos` | LOJA/ORCAM | Relatorio: orcamentos por status |
| `POST /api/bo/loja/orcamento-finalizar` | LOJA/CAIXA | Finaliza o orcamento no caixa (cupom) |
| `POST /api/bo/loja/devolucao` | LOJA/CAIXA | Devolucao/troca no caixa (dinheiro ou vale-troca) |
| `GET /api/bo/loja/cupom` | LOJA/CAIXA | Segunda via do cupom |
| `GET /api/bo/loja/consulta` | LOJA/CAIXA | Consulta de preco e saldo |
| `GET /api/bo/loja/vale` | LOJA/CAIXA | Saldo do vale-troca |
| `GET /api/bo/loja/gerencial` | LOJA/GEREN | Relatorio: gerencial (dia, caixa, operador, vendedor) |
| `GET /api/bo/loja/comissao` | LOJA/GEREN | Relatorio: comissao dos vendedores |

Forçar a liberação (`faturamento/liberar` com `forcar=S`) exige também FATURAMENTO/LIBERA. Liberar desconto acima do limite na loja exige LOJA/DESCONTO do operador da sessão ou do supervisor informado.

**Testes:**
- `T_GEBINTEG` (integração: apuração com nota cancelada, devolução e crédito; guia com título, provisão, pagamento e complementar; parcelamento em títulos; retenções; caminhos antigos; correção do contábil) e `T_GEBINTEGSN` (Simples: DAS e ISS fora do DAS como guias, sem guia de IBS/CBS);
- `T_GEBEST` (estoque e contábil), `T_GEBLOTE` (lote/série/endereço, fechamento, devolução de compra), `T_GEBCC` (centro de custo), `T_GEBBCO` (boletos dos seis bancos conferidos com os exemplos dos manuais, CNAB 240 dos seis bancos e 400 Itaú/Bradesco, com remessa e retorno, OFX), `T_GEBTEF` (simulador, HTTP e Cielo contra o emulador);
- `T_GEBFNX`, `T_GEBCPX`, `T_GEBFAT`, `T_GEBLOJ`, `T_GEBLOJ_OPE` (código de barras e balança, promoções, desconto com supervisor, devolução e vale-troca, orçamento, segunda via, gerencial e comissão);
- `T_GEBTUIBO` (todas as rotas despacham; as telas abrem);
- `T_GEBWEB_OPS` (chamadas reais a `/api/bo`).


## 13. Documentos fiscais eletrônicos: NFC-e real (19/10/2026)

**Requisito de runtime:** advplc **v4.8.5** ou mais novo (`PrivSignRSA`, `ProcRun`, `HTTPSPost` com certificado de cliente, `DateTimeUTC`; `Nil`/`NULL` como texto vazio e passagem por referência `@var`). O servidor também precisa do `openssl` e da cadeia ICP-Brasil instalada (script interno de instalação da cadeia ICP-Brasil).

**Fontes**

| Fonte | Funções principais |
|---|---|
| `GEBDFE_XML.prw` | Funções puras, sem banco. `GEBDFEUFS`/`GEBDFECUF`/`GEBDFEFUSO`, `GEBDFEAGORA` (hora local da UF calculada do UTC), `GEBDFECHAVE`/`GEBDFEDV`/`GEBDFECNF`, `GEBDFETXT` (texto sem acento, escapado), `GEBDFEMONTA` (XML NF-e/NFC-e 4.00 já canônico), `GEBDFEASSINA` (XMLDSig RSA-SHA1), `GEBDFEQRCODE` (QR v3/v2), `GEBDFESUPL`, `GEBDFELOTE`, `GEBDFEEVCANC`, `GEBDFEINUT`, `GEBDFESTATUS`, `GEBDFECONSULTA`, `GEBDFESOAP`, `GEBDFETAG`/`GEBDFEBLOCO`, `GEBDFEPROC` |
| `GEBDFE_QR.prw` | `GEBQRMATRIZ` (QR Code ISO 18004: modo byte, nível M, versões 1–40) e `GEBQRSVG` |
| `GEBDFE_IE.prw` | `GEBDFEIEOK` (dígito da inscrição estadual das 27 UFs) |
| `GEBDFE_WS.prw` | `GEBDFEWSTAB`: tabela gerada por `script interno gera_dfe_ws.py` (webservices por UF/modelo/ambiente, autorizador, URL de consulta) |
| `GEBDFE_MUN.prw` | `GEBDFEMUNTAB`: 5.571 municípios IBGE, gerada por `script interno gera_dfe_mun.py` |
| `GEBDFE_CAD.prw` | `GEBDFECADMIG` (GDF1, GDF2, GDF4, GDF5, GDF6), `GEBDFEEMIT`/`GEBDFEEMITLE`, `GEBDFECERT`/`GEBDFECERTLE`/`GEBDFECERTDIR`, `GEBDFEPRODFIS`/`GEBDFEPRODITEM`, `GEBDFECONFIG`, `GEBDFEPROXNUM`/`GEBDFESETNUM`, `GEBDFEDOCOK`, `GEBDFEMUNNOME`/`GEBDFEMUNBUSCA` |
| `GEBDFE.prw` | `GEBDFEURL`, `GEBDFEENVIA`, `GEBDFENFCE`, `GEBDFETRANSMITE`, `GEBDFECONSULTAR`, `GEBDFECANCELA`, `GEBDFEINUTILIZA`/`GEBDFEPENDINUT`/`GEBDFEINUTPEND`, `GEBDFESTATSVC`, `GEBDFEROTEIRO`, `GEBDFEDOCS`, `GEBDFEDOC` |
| `GEBDFE_DANFE.prw` | `GEBDFEDANFE` (HTML de 80 mm com QR em SVG) e `GEBDFEDANFETXT` |

**Tabelas (schema da empresa):**

| Tabela | Conteúdo |
|---|---|
| GDF1 | Emitente da filial |
| GDF2 | Certificado instalado: titular, CNPJ, validade e caminhos dos PEM |
| GDF4 | Perfil fiscal do produto |
| GDF5 | Documentos: chave, modelo, série, número, tpEmis, ambiente, situação, cStat, motivo, protocolo, datas, origem/documento, vNF, XML (nfeProc quando autorizada), QR, URL de consulta, destinatário, chave e XML da tentativa online (`CHORIG`/`XMLORIG`) |
| GDF6 | Eventos: cancelamento e inutilização, com o XML de processamento |

Situações em GDF5: `AUTORIZADA`, `CONTINGENCIA`, `REJEITADA`, `REJEITADA_CONTINGENCIA`, `DENEGADA`, `CANCELADA`, `INUTILIZADA`, `SUBSTITUIDA` (contingência cuja tentativa online já estava autorizada).

**Parâmetros GE4:**

| Parâmetro | O quê |
|---|---|
| `DFE_AMBIENTE` | 1 produção, 2 homologação (padrão) |
| `DFE_NFCE` | `S` liga a NFC-e na frente de loja |
| `DFE_SERIE_65` | Série da NFC-e |
| `DFE_QR_VERSAO` | 3 (padrão, sem CSC) ou 2 (com `DFE_CSC_ID` e `DFE_CSC`) |
| `DFE_RT_CNPJ`, `DFE_RT_CONTATO`, `DFE_RT_EMAIL`, `DFE_RT_FONE` | Responsável técnico |
| `DFE_CFOP`, `DFE_CSOSN`, `DFE_CST`, `DFE_ALIQ_ICMS`, `DFE_UNIDADE`, `DFE_ORIGEM`, `DFE_PIS_CST`, `DFE_COFINS_CST` | Padrões do produto sem perfil |
| `DFE_CANC_MIN` | Prazo de cancelamento em minutos (padrão 30) |
| `DFE_TIMEOUT` | Segundos de espera da SEFAZ (padrão 15) |
| `DFE_INFCPL` | Mensagem do cupom em informações complementares |
| `DFE_CERT_DIR` | Pasta dos certificados (senão a variável de ambiente `GEBAN_CERT_DIR`, senão `cert` relativo ao serviço) |
| `DFE_URL_<SERVICO>` | Sobrepõe o endereço da SEFAZ, sem deploy |
| `GEBAN_URL` | Endereço público usado nos links impressos pela tela (padrão `https://SEU-DOMINIO`) |

**Frente de loja:** com `DFE_NFCE = S`, `GEBLOJVEN` emite a NFC-e depois do TEF e antes de gravar a venda:
- rejeitada: desfaz o TEF e devolve o motivo; a venda não é gravada;
- autorizada ou em contingência: a venda é gravada. `GLJ3_NOTA` e `GF3_CHAVE` ficam com a chave de acesso, e o livro GF3 só fica `AUTORIZADA` com o protocolo.

`GEBLOJVEN` devolve `{cupom, total, troco, chave, situação}`.

`GEBLOJCAN` cancela primeiro na SEFAZ (evento 110111). Com nota em contingência, recusa até ela ser transmitida. Se o estorno do cartão falhar depois do cancelamento fiscal, o cupom é cancelado e a mensagem avisa do estorno pendente.

**Rotas** (`/api/bo/...`, mesmo formato das demais):

| Rota | Permissão | O quê |
|---|---|---|
| `POST dfe/emitente` · `GET dfe/emitente` | FISCAL/DFE | Emitente (cnpj, ie, im, cnae, razao, fantasia, crt, logradouro, numero, complemento, bairro, municipio, uf, cep, fone, email) |
| `POST dfe/certificado` | FISCAL/DFE | `pfx` (Base64) e `senha` |
| `POST dfe/configuracao` | FISCAL/DFE | ambiente, nfce, serie_nfce, proximo_nfce, qr_versao, csc_id, csc, rt_*, cfop, csosn, cst, aliq_icms, unidade, origem, pis_cst, cofins_cst, canc_min, timeout, mensagem (a pasta dos certificados e os endereços da SEFAZ não vêm pela API) |
| `POST dfe/produto` | FISCAL/DFE | Perfil fiscal (produto, unidade, gtin, cfop, csosn, cst, aliq_icms, cest, origem, pis_cst, cofins_cst, aliq_pis, aliq_cofins) |
| `GET dfe/municipios` | FISCAL/DFE | `nome`, `uf` |
| `GET dfe/roteiro` | FISCAL/DFE | `testar=N` pula o teste de comunicação |
| `GET dfe/status` | FISCAL/DFE | Status do serviço (`modelo`, padrão 65) |
| `POST dfe/transmitir` | LOJA/CAIXA | Transmite as contingências |
| `POST dfe/cancelar` | FISCAL/DFE | `chave`, `justificativa` |
| `POST dfe/inutilizar` · `POST dfe/inutilizar-pendentes` | FISCAL/DFE | `modelo`, `serie`, `inicio`, `fim`, `justificativa` |
| `GET dfe/consultar` | FISCAL/DFE | `chave` (acerta a situação local) |
| `GET dfe/documentos` | FISCAL/DFE | `inicio`, `fim`, `status` |
| `GET dfe/danfe` · `GET loja/danfe` | FISCAL/DFE · LOJA/CAIXA | DANFE em HTML, dentro do JSON |

**Páginas HTML:**
- `GET /api/dfe/configurar` (pública): assistente fiscal. Faz login e mostra o roteiro, o emitente com busca de município, o envio do `.pfx`, a configuração e a impressão do DANFE.
- `GET /api/dfe/danfe?token=&empresa=&chave=` (ou `&cupom=`): DANFE para imprimir. Exige LOJA/CAIXA ou FISCAL/DFE.

**Telas:**
- Fiscal > Documentos eletrônicos (`GEBTUIDFE`, 12 opções).
- Frente de loja > "NFC-e: transmitir as emitidas em contingência" e "NFC-e: DANFE do cupom". A segunda mostra o texto e um link de impressão com token novo.

**Testes:**

| Teste | Onde roda | O que confere |
|---|---|---|
| `T_GEBDFE` | Suíte, servidor de testes | 51 verificações de ponta a ponta contra `tests/emuladores/sefaz_emulador.py` (HTTPS 127.0.0.1:18766; confere digest e RSA de cada documento e simula 100, 204, 297, 373, 539, 778, 108, resposta lenta, 135, 580, 102, 241, 101, 217). O runner de testes sobe o emulador e exporta `ADVPP_HTTP_INSECURE` só para os testes. |
| `tests/local/T_GEBDFE_XML.sh` | Local | XSD oficiais PL_010_V1.30 (`tests/xsd`) com `xmllint`; assinatura e QR conferidos com lxml/cryptography |
| `tests/local/T_GEBDFE_QR.sh` | Local | Matriz idêntica à da biblioteca Python `qrcode` |
| `tests/local/T_GEBDFE_IE.sh <ie.js>` | Local | 92.000 inscrições conferidas com a implementação de referência gammasoft/ie |

### 13.1 NF-e modelo 55 (bloco 3)

**Fontes:**

| Fonte | Funções |
|---|---|
| `GEBDFE_NFE.prw` | `GEBDFENFEMIG` (GDF7 participante fiscal, GDF8 vínculos de chave), `GEBDFEPART`/`GEBDFEPARTLE`, `GEBDFEVINC`/`GEBDFEVINCLE`, `GEBDFEALIQINTER`, `GEBDFENFE` (emissão), `GEBDFERESOLVE` (pendentes), `GEBDFECCE` (carta de correção) |
| `GEBDFE_DANFE55.prw` | `GEBC128`/`GEBC128SVG` (Code 128 C) e `GEBDFEDANFE55` (A4). `GEBDFEDANFE` encaminha o modelo 55 para cá. |

`GEBDFE_XML` ganhou a cobrança (`COBR`), o `INDPAG` e o `GEBDFEEVCCE`.

**Integração** (com `DFE_NFE = S`):

| Rotina | O que muda |
|---|---|
| `GEBFATFAT` | Emite a NF-e antes de gravar, com duplicatas pela condição. A chave vira o número da nota: GF3, títulos, GFT5/GFT6. |
| `GEBFATDEV(cNota, aItens, cData, cChaveCli)` | Nota eletrônica: cliente contribuinte exige `cChaveCli` (vínculo `DEVCLI`); os demais geram NF-e de entrada (finalidade 4, 1202/2202, CSOSN 900, PIS/COFINS 98, `refNFe`). |
| `GEBCPXENT(..., cChaveNF)` | Guarda a chave da NF-e do fornecedor (vínculo `ENT`). |
| `GEBCPXDEV(..., cChaveForn)` | Emite a NF-e de saída, finalidade 4, 5202/6202, referenciando a chave da entrada ou a informada. |

**Parâmetros:**

| Parâmetro | O quê |
|---|---|
| `DFE_NFE` | Liga a NF-e (`S`/`N`) |
| `DFE_SERIE_55` | Série da NF-e |
| `DFE_NFE_TPAG` | Forma de pagamento da NF-e de venda (padrão 15, boleto) |
| `DFE_NFE_INDPRES` | Indicador de presença (padrão 9) |
| `DFE_NFE_INFCPL` | Mensagem em informações complementares |

**Rotas:**

| Rota | Permissão | Campos |
|---|---|---|
| `POST dfe/participante` | FISCAL/DFE | tipo C/F, codigo, doc, contribuinte 1/2/9, ie, nome, logradouro, numero, complemento, bairro, municipio, uf, cep, fone, email |
| `POST dfe/carta-correcao` | FISCAL/DFE | chave, correcao |
| `POST dfe/resolver` | FISCAL/DFE | |
| `faturamento/devolucao` | | ganhou `chave_cliente` |
| `compras/entrada` e `compras/devolucao` | | ganharam `chave` |

**Telas:**
- Documentos eletrônicos ganhou: cadastro fiscal de cliente/fornecedor, carta de correção, resolver pendentes e link do DANFE.
- Os prompts de devolução e entrada pedem a chave.

**Testes:**
- `T_GEBDFE_NFE` (32 verificações, emulador);
- `tests/local/T_GEBDFE_C128.sh` (Code 128 igual ao reportlab);
- `T_GEBDFE_XML.sh` também valida a NF-e com duplicatas, a de devolução e a carta de correção no XSD.

### 13.2 Itens complementares (19/10/2026)

- **`GEBLOJDEV(..., oCons)`:**
  - Com cupom de NFC-e, emite NF-e de entrada `LOJDEV` e devolve a chave em `[3][5]`.
  - A rota `loja/devolucao` aceita `consumidor_doc`, `consumidor_nome`, `consumidor_logradouro`, `consumidor_numero`, `consumidor_complemento`, `consumidor_bairro`, `consumidor_municipio`, `consumidor_uf`, `consumidor_cep`, `consumidor_fone` e `consumidor_email`.
  - `GEBDFEPART` aceita o tipo `L`.
- **DIFAL:**
  - `GEBDFEALIQINT(UF)`, com tabela e `DFE_ALIQ_INT_<UF>`;
  - `GEBDFEFCPPAD`, `DFE_FCP_<UF>`, `DFE_DIFAL_BASE_DUPLA_<UF>`;
  - título `DIFAL-<UF>-<n>` e `SN_FORA`.
- **ST e CST 20:** perfil fiscal com `RED_BC`, `MVA`, `ALIQ_ST` e `RED_BC_ST` (tabela GDFA).
- **IBS/CBS:** `GEBDFETRIB`; parâmetros `DFE_IBSCBS`, `DFE_IBSCBS_CST`, `DFE_CCLASSTRIB`, `DFE_IBS_MUN_PCT`.
- **IBPT:**
  - tabela GDFB, importada por `GEBDFEIBPTIMP(conteudo, uf)`, `POST dfe/ibpt` (`uf`, `conteudo`) ou item 4 da página;
  - versão gravada em `DFE_IBPT_VERSAO_<UF>`.
- **`o script de publicacao`:** publica a cópia de `src/` tirada antes dos testes e para se `src/` mudar durante eles.

### 13.3 NFS-e nacional

- **`GEBDFE_NFSE.prw`:**
  - `GEBDFENFSEMIG` (GDFC serviço fiscal);
  - `GEBDFESERV`;
  - `GEBDFENFSEURL`, `GEBDFEDPSID`, `GEBDFEDPSXML`, `GEBDFEPEDCANC`;
  - `GEBDFENFSE` (emissão), `GEBDFENFSECANC`, `GEBDFENFSERESOLVE`;
  - `GEBDFEDANFSE` (PDF do ADN);
  - `GEBFATSERV` (faturamento de serviço).
- **Rotas:**

  | Rota | Permissão | Campos |
  |---|---|---|
  | `POST dfe/servico` | FISCAL/DFE | codigo, descricao, trib_nacional, trib_municipal, nbs, aliq_iss |
  | `POST faturamento/servico` | FATURAMENTO/FATUR | cliente, servico, valor, desconto, descricao, condicao, data, iss_retido S/N |
  | `POST dfe/nfse-cancelar` | FISCAL/DFE | chave, motivo, justificativa |

  `dfe/resolver` também resolve a NFS-e.
- **Parâmetros:** `DFE_NFSE`, `DFE_SERIE_NFSE`, `DFE_NFSE_REGAPSN`, `DFE_NFSE_PTOTTRIBSN`, `DFE_URL_SEFIN`, `DFE_URL_ADN`. Os documentos ficam em GDF5 com modelo `SE`.
- **Emulador:** o `sefaz_emulador.py` atende também a API REST da Sefin.
- **Testes:**
  - `T_GEBDFE_NFSE` (16 verificações);
  - local `tests/local/T_GEBDFE_NFSE.sh` (DPS e cancelamento contra `tests/xsd/nfse_v1.01`, schemas da nfelib);
  - `tests/local/T_NOMES_RESERVADOS.sh`: nenhuma variável com nome de palavra-chave (`aS`, `oR`, `oN`...).

### 13.4 Recebimento de NF-e (bloco 5)

- **`GEBDFE_DIST.prw`:**
  - `GEBDFEDISTMIG` (GDFE recebidas, GDFF de-para);
  - `GEBDFEDISTBUSCA`, `GEBDFEDISTCHAVE`, `GEBDFEMANIF`, `GEBDFEDEPARA`, `GEBDFEIMPORTA`, `GEBDFERECEBIDAS`.
- **`GEBDFE_XML`:** `GEBDFEDISTMSG` e `GEBDFEEVMANIF`.
- **`GEBDFEENVIA`:** usa o envelope `nfeDistDFeInteresse/nfeDadosMsg` na distribuição.
- **Rotas:**

  | Rota | Permissão | Campos |
  |---|---|---|
  | `POST compras/nfe-buscar` | COMPRAS/PEDID | |
  | `GET compras/nfe-recebidas` | COMPRAS/PEDID | situacao |
  | `POST compras/nfe-manifestar` | COMPRAS/PEDID | chave, tipo, justificativa |
  | `POST compras/de-para` | COMPRAS/PEDID | fornecedor, codigo_fornecedor, produto, fator |
  | `POST compras/nfe-importar` | COMPRAS/PEDID | chave, pedido, data |

- **Telas:** Compras avançado, opções 12 a 16.
- **Testes:**
  - `T_GEBDFE_DIST` (19 verificações);
  - o local `T_GEBDFE_XML.sh` valida `distDFeInt` e a manifestação no XSD.

### 13.5 EFD ICMS/IPI (bloco 6)

- **`GEBDFE_EFD.prw`:**
  - `GEBDFEEFDMIG` (GDFG: competência, finalidade, saldo credor, a recolher, linhas, data e arquivo);
  - `GEBDFEEFDVER(cComp)`: versão do leiaute pelo ano;
  - `GEBDFEEFD(cComp, cFin)`: coleta GDF5/GDF6/GDF8+GCQ4+GDFE+GDFF, valida e grava; devolve `{lOk, msg, arquivo, {débitos, créditos, recolher, saldo credor, docs, linhas}}`;
  - `GEBDFEEFDTXT(oE, oP, aDocs)`: montador puro (sem banco);
  - `GEBDFEEFDLE(cComp)`: arquivo guardado;
  - `GEBDFEEFDBLOCOS(cXml, cTag)`: blocos de uma tag em ordem.
- **Parâmetros (GE4), também pela `dfe/configuracao`:**

  | Campo da API | Parâmetro |
  |---|---|
  | efd_perfil, efd_atividade | `DFE_EFD_PERFIL`, `DFE_EFD_ATIV` |
  | efd_cod_rec, efd_cod_rec_st, efd_cod_rec_difal, efd_cod_rec_fcp | `DFE_EFD_COD_REC`, `_ST`, `_DIFAL`, `_FCP` |
  | efd_dia_venc, efd_saldo_credor_inicial | `DFE_EFD_DIA_VENC`, `DFE_EFD_SLD_CRED_INI` |
  | cont_nome, cont_cpf, cont_crc, cont_cnpj, cont_email, cont_fone, cont_cep, cont_end, cont_num, cont_compl, cont_bairro, cont_municipio | `DFE_EFD_CONT_*` |

  Só por parâmetro: `DFE_EFD_SIMPLES`, `DFE_EFD_CODVER`.
- **Rotas:**

  | Rota | Permissão | Campos |
  |---|---|---|
  | `POST /api/bo/dfe/efd` | FISCAL/DFE | competencia, finalidade |
  | `GET /api/dfe/efd` | FISCAL/DFE | token, empresa, competencia (texto do arquivo) |

- **Telas:** Fiscal > Documentos eletrônicos, opções 20 (gerar) e 21 (configuração da EFD).
- **Registros gerados:** 0000, 0001, 0005, 0100, 0150, 0190, 0200, 0220, 0990; B001/B990; C001, C100, C101, C170, C190, C990; D001/D990; E001, E100, E110, E116, E200, E210, E250, E300, E310, E316, E990; G, H, K sem movimento; 1001, 1010, 1990; 9001, 9900, 9990, 9999.
- **Testes:**
  - `T_GEBDFE_EFD` (com banco): recusas, coleta, apuração, arquivo guardado e saldo credor na competência seguinte;
  - local `T_GEBDFE_EFD.sh`: montador com notas do motor real e validador independente em Python (campos por registro, obrigatórios, formatos, ordem dos blocos, 9900/x990/9999, C190 × C100, fórmula do E110 e E116).
- **Pendente:** validação do arquivo no PVA da Receita (ainda não feita; fazer antes da primeira entrega real).
