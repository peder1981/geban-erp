# 05 — Referência Técnica Completa do ERP GEBAN

> **Autor:** Peder Munksgaard · **Data:** 26/09/2026 · **Idioma:** PT-BR
> **Fontes primárias:** `src/*.prw` (57 arquivos, 386 funções — todas catalogadas na seção 8),
> `docs/02-regras-negocio.md`, planos e ledgers em `documentacao interna` e `registro interno`.
> **Estado verificado:** suíte completa **67/67 PASS** contra Postgres sob o
> runtime **AdvPP advplc v4.3.2** (que inclui a correção `rowid` → `R_E_C_N_O_` do `FWMBrowse`,
> sem a qual nenhum browse abre em banco remoto). Commits: `cfcf004` (conta super) e `e72582b`
> (higiene de testes). Sem mocks: todo comportamento abaixo foi lido dos fontes e executado.
> PDFs gerados com o template `jmpm` (`md2pdf.py --template jmpm --cover`).

---

## 1. Visão geral

O GEBAN é o ERP da fictícia República das Bananias: monolito modular em **AdvPL** (`.prw`,
encoding CP-1252, `#include "totvs.ch"`, só `User`/`Static Function`, notação húngara) sobre
**Postgres multi-tenant**, compilado e executado pelo runtime próprio **AdvPP** (`advplc
check/run/serve/build`). Entrada única: `User Function GEBAN()` em `src/GEBAN.prw`.
Ordem de construção dos 9 subprojetos:

```
GEB_NUCLEO → GEB_FISCAL → GEB_DERRAMA → GEB_ESTOQ_VENDA → GEB_CONTABIL
    → GEB_FIN → GEB_COM → GEB_EXPANSAO → GEB_GUI (+ GEB_SEGURANCA e GEB_REST transversais)
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

## 4. Inventário de tabelas

| Tabela(s) | Módulo | Conteúdo (colunas-chave) |
|---|---|---|
| `GE1` | Núcleo (catálogo) | Empresas: `GE1_FILIAL`, `GE1_COD`, `GE1_NOME` |
| `GE2` | Núcleo (catálogo) | Usuários: `GE2_FILIAL`, `GE2_COD`, `GE2_NOME`, `GE2_PERFIL` |
| `GE2_SEC` | Segurança (catálogo) | Credenciais: `SEC_FILIAL`, `SEC_USUARIO`, `SEC_SALT`, `SEC_HASH`, `SEC_FAILCNT`, `SEC_LOCKED`, `SEC_LASTLOGIN`, `SEC_PWDLAST` |
| `GE2_TOK` | Segurança (catálogo) | Sessões: `TOK_TOKEN`, `TOK_USUARIO`, `TOK_EMPRESA`, `TOK_FILIAL` |
| `GE2_EMP` | Segurança (catálogo) | Vínculos: `GE2_EMP_FILIAL`, `GE2_EMP_USUARIO`, `GE2_EMP_EMPRESA` |
| `GE3` | Núcleo | Trilha de auditoria (B.O.): usuário, evento, motivo |
| `GE4` | Núcleo | Parâmetros/config: evento → modo do Mentor, flags (`PERMITE_DIRETA`, `EMISSAO`, `APURACAO`) |
| `GE5` | Núcleo | Fila offline (`PENDENTE`) |
| `GEH` / `GEI` / `GEI_AUDIT` | Expansão | Histórico de acesso / audit log processual |
| `GEX` | Expansão | Sessão ativa (linha temporária) |
| `GF1` | Fiscal | Produtos/serviços: `GF1_COD`, `GF1_NCM`, `GF1_DESC` |
| `GF2` | Fiscal | Alíquotas com vigência por NCM |
| `GF3` / `GF4` | Fiscal | Header da nota (`CHAVE`, `TIPO`, `STATUS`, `EMIS`, `BASE`, `IBS`, `CBS`) / itens |
| `GF5` | Fiscal | Apuração por competência: `DEB`, `CRED`, `SALDO`, `REGIME` |
| `GF6` | Fiscal | Créditos (`TRANSF`/`RESSARC`) |
| `GD1` | Derrama | Guias: `VALOR`, `JUROS`, `MULTA`, `TOTAL`, `STATUS` (`ABERTA/PARCELADA/PROTESTADA`) |
| `GD2` | Derrama | Parcelas (`PARC` 001–999) |
| `GD3` | Derrama | Cobrança/protesto (`ACAO`, `DATA`, `STATUS`) |
| `GV1` | Estoque | Saldos: `PROD`, `SALDO`, `MINIMO` (padrão 10) |
| `GV2` | Venda | Vendas (`VENDIDA/BLOQUEADA/SEM_ESTOQUE`) |
| `GV3` | Fiado | Caderninho: cliente, `VALOR`, `JUROS`, `MULTA`, `TOTAL`, `ABERTA` |
| `GC1` | Contábil | Plano de contas |
| `GC2` / `GC3` | Contábil | Lotes (`LOTE`, `ORIGEM`, `VALOR`, `COMP`, `TIPO AUTO/DIRETO`) / pernas `D` e `C` |
| `GC4` | Contábil | Parâmetros evento → conta débito/crédito (+ `LANC_DIRETO`) |
| `GFN1` | Financeiro | Contas (`CONTA`, `NOME`, `SALDO`) |
| `GFN2` / `GFN3` | Financeiro | Receber / pagar (`DOC`, `VALOR`, `SALDO`, `VENC`, `ABERTO/RECEBIDA/PAGA`) |
| `GFN4` | Financeiro | Movimentos de caixa |
| `GCP1` | Compras | Fornecedores (`COD`, `NOME`, `CNPJ`) |
| `GCP2` | Compras | Cotações (`FORN`, `PROD`, `PRECO`) |
| `GCP3` / `GCP4` | Compras | Pedidos (`NUM`, `FORN`, `ABERTO/BLOQUEADO/RECEBIDO`) / itens |
| `GCP5` | Compras | Entradas (`NF`, `PED`, `RECEBIDA`) |
| `GEF1` | Filiais | Cadastro de filiais do tenant (`GEF1_COD`, `GEF1_NOME`) |
| `GEU1` | Unidades | Unidades (`UU`) |
| `SEC_PERM` | Segurança | RBAC (`PERFIL`, `MENU`, `ITEM`, `PERMITE`) |
| `SEC_MON` / `SEC_ADMIN_SESSION` | Segurança | Monitor / sessões admin |
| `GEBGUICONFIG_SC/LC` | GUI | Storage complementar de configuração |

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
  `GEBMON*` (monitor), `GEBINIC`, `CTBLAN`/`CTBGRV` (partida dobrada + stub compatível).

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

## 8. Referência completa de funções por arquivo (386 funções)

Assinaturas exatas extraídas dos fontes; propósitos do bloco `Protheus.doc` ou da regra
de negócio verificada. `Retorna:` indica o `@return` documentado quando existe.

### GEB_NUCLEO

**`src/GENUC_MIG.prw`** — 9 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GENMIGCatalogo` | `GENMIGCatalogo()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `GENMIGEmpresa` | `GENMIGEmpresa()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `GENMIG` | `GENMIG()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `GEBCFG` | `GEBCFG(cChave)` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGE1` | `CriaGE1()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGE2` | `CriaGE2()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGE3` | `CriaGE3()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGE4` | `CriaGE4()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGE5` | `CriaGE5()` | GENUC_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GENUC_CAD.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBAUD` | `GEBAUD(cUsuario, cEvento, cMotivo)` | GENUC_CAD Retorna: .T. se gravou/autorizado, .F. caso contrario |
| `GEBUSR` | `GEBUSR(cCodUser)` | GENUC_CAD Retorna: .T. se gravou/autorizado, .F. caso contrario |
| `GEBCAD` | `GEBCAD()` | Dispatcher de cadastros do Nucleo. |
| `CADMenu` | `CADMenu()` | Menu de cadastros (stub). |
| `GEBCADemp` | `GEBCADemp()` | Stub cadastro de empresa. |
| `GEBCADusu` | `GEBCADusu()` | Stub cadastro de usuario. |
| `GEBCADaud` | `GEBCADaud()` | Stub consulta auditoria. |

**`src/GENUC_MNT.prw`** — 5 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBMNT` | `GEBMNT(cEvento)` | GENUC_MNT Retorna: .T. liberado/enfileirado/balanceado, .F. travado ou erro |
| `GEBFILA` | `GEBFILA(cChave, cPayload)` | GENUC_MNT Retorna: .T. liberado/enfileirado/balanceado, .F. travado ou erro |
| `CTBLAN` | `CTBLAN(cOrigem, nValor)` | Partida dobrada via GC4 (debito == credito) ou stub. |
| `CTBGRV` | `CTBGRV(cOrigem, cDeb, cCred, nValor, cTipo)` | Grava lote GC2 + 2 pernas GC3. |
| `NovoLote` | `NovoLote()` | Gera numero de lote contabil. |

**`src/GEBAUD.prw`** — 9 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GBAUDINIC` | `GBAUDINIC()` | GEBAUD Retorna: string formatada (GBAUDExport) |
| `GBAUDLOG` | `GBAUDLOG(cTabela, cAcao, cRegistro, cUsuario, cEmpresa, cFilial)` | Grava trilha de auditoria em GE3 (usuario, evento, motivo). |
| `GBAUDLISTAR` | `GBAUDLISTAR(cEmpresa, cInicio, cFim, nMax)` | Lista trilhas GE3 por empresa e periodo (limite nMax). |
| `GBAUDRESUMO` | `GBAUDRESUMO(cEmpresa)` | Conta trilhas GE3 por evento (resumo). |
| `GBAUDExport` | `GBAUDExport(cEmpresa, cFormato)` | Exporta trilhas GE3 em CSV ou JSON. |
| `IifObj` | `IifObj(xVal, xPadrao)` | Coalescencia Nil (xVal Nil retorna xPadrao). |
| `StrRep` | `StrRep(cStr, cOld, cNew)` | Substitui ocorrencias (wrapper de StrTran). |
| `EscCSV` | `EscCSV(cVal)` | Escapa valor para CSV. |
| `EscJSON` | `EscJSON(cVal)` | Escapa valor para JSON. |

**`src/GEBMON.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBMONINIC` | `GEBMONINIC()` | GEBMONINIC Retorna: .T. se sucesso, .F. se erro |
| `GEBMONATUALIZA` | `GEBMONATUALIZA(cToken, cRotina)` | GEBMONATUALIZA Retorna: void |
| `GEBMONLISTAR` | `GEBMONLISTAR()` | GEBMONLISTAR Retorna: Array {token, usuario, empresa, filial, ip, loginem, tempoconectado, min, ultimaacao, rotina} |
| `GEBMONDESLIGAR` | `GEBMONDESLIGAR(cToken)` | GEBMONDESLIGAR Retorna: .T. se sucesso, .F. se token invalido |
| `GEBMONMETRICAS` | `GEBMONMETRICAS()` | GEBMONMETRICAS Retorna: Object {nUsuariosOnline, nEmpresasAtivas, nReqPorSeg, gargalos} |
| `GEBMONUNICO` | `GEBMONUNICO(aArr)` | GEBMONUNICO Retorna: Array unico |
| `GEBMONROTINA` | `GEBMONROTINA(cToken)` | GEBMONROTINA Retorna: cRotina Nome da rotina ("" se nao encontrado) |

**`src/GEBINIC.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBINIC` | `GEBINIC()` | GEBINIC Retorna: .T. se o catalogo foi provisionado com sucesso, .F. caso |

**`src/GEBDB_CORE.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDBTableExists` | `GEBDBTableExists(cTabela)` | GEBDB_CORE |
| `GEBDBTableExistsHere` | `GEBDBTableExistsHere(cTabela)` | GEBDB_CORE |
| `GEBDBColumnExists` | `GEBDBColumnExists(cTabela, cColuna)` | GEBDB_CORE |
| `GEBDBTableEnsure` | `GEBDBTableEnsure(cTabela, cDDL, aColsObrigatorias)` | GEBDB_CORE |

**`src/GEBDB_TENANT.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDBConecta` | `GEBDBConecta()` | GEBDB_TENANT |
| `GEBDBSchemaValido` | `GEBDBSchemaValido(cCod)` | GEBDB_TENANT |
| `IsAlphaNumUnder` | `IsAlphaNumUnder(cTxt)` | GEBDB_TENANT |
| `GEBDBSchemaExists` | `GEBDBSchemaExists(cCod)` | GEBDB_TENANT |
| `GEBDBSetTenant` | `GEBDBSetTenant(cCod)` | GEBDB_TENANT |
| `GEBDBProvisionaCatalogo` | `GEBDBProvisionaCatalogo()` | GEBDB_TENANT |
| `GEBDBProvisionaEmpresa` | `GEBDBProvisionaEmpresa(cCod, cNome)` | GEBDB_TENANT |

**`src/_init.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `TEST_INIT` | `TEST_INIT()` | Bootstrap de tabelas para testes (helper _init). |

### GEB_FISCAL

**`src/GEBFIS_MIG.prw`** — 9 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFMIG` | `GEBFMIG()` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `CALCIBS` | `CALCIBS(nBase, nAliqIBS, nAliqCBS)` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `ALIQF` | `ALIQF(cNCM, dData)` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `CriaGF1` | `CriaGF1()` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `CriaGF2` | `CriaGF2()` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `CriaGF3` | `CriaGF3()` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `CriaGF4` | `CriaGF4()` | GEBFIS_MIG Retorna: .T. se migracao OK, .F. se falhar (GEBFMIG); array {nIBS, nCBS} (CALCIBS/ALIQF) |
| `CriaGF5` | `CriaGF5()` | DDL idempotente da tabela GF5 (apuracao). |
| `CriaGF6` | `CriaGF6()` | DDL idempotente da tabela GF6 (creditos). |

**`src/GEBFIS_CAD.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFPRO` | `GEBFPRO(cCod)` | GEBFIS_CAD Retorna: Array {COD, NCM, DESC} ou {} (GEBFPRO); array {IBS, CBS} (GEBFALI) |
| `GEBFALI` | `GEBFALI(cNCM, dData)` | GEBFIS_CAD Retorna: Array {COD, NCM, DESC} ou {} (GEBFPRO); array {IBS, CBS} (GEBFALI) |

**`src/GEBFIS_EMI.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFEMI` | `GEBFEMI(cChave, cCod, nQtd, nPreco)` | GEBFIS_EMI Retorna: Status AUTORIZADA ou EM_FILA (GEBFEMI); array de parcelas (GEBFSPL) |
| `GEBFSPL` | `GEBFSPL(nTotal, nPartes)` | Divide total em N parcelas (ultima ajusta residuo). |
| `GrvGF3` | `GrvGF3(cChave, nBase, nIBS, nCBS, cStatus)` | Grava header GF3 da nota. |
| `GrvGF4` | `GrvGF4(cChave, cCod, nQtd, nPreco, nBase, nIBS, nCBS)` | Grava item GF4 da nota. |

**`src/GEBFIS_APU.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFAPU` | `GEBFAPU(cComp)` | GEBFIS_APU Retorna: .T. se apurou/gravou, .F. se tabelas ausentes (ambas) |
| `GEBFCRE` | `GEBFCRE(cComp, cOrig, nValor, cTipo)` | Credito GF6 TRANSF ou RESSARC (sem lastro nega). |
| `RegimeGE1` | `RegimeGE1()` | Deduz SIMPLES ou REGULAR pelo nome da empresa. |
| `ChavesComp` | `ChavesComp(cComp)` | Chaves GF3 da competencia AAAAMM. |
| `SomaGF4` | `SomaGF4(aChaves)` | Soma IBS+CBS dos itens das chaves. |
| `BaixaGF5` | `BaixaGF5(cComp)` | Baixa logica das apuracoes ativas da competencia. |
| `GrvGF5` | `GrvGF5(cComp, nDeb, nCred, nSaldo, cRegime)` | Grava linha GF5 (debito, credito, saldo, regime). |

### GEB_DERRAMA

**`src/GEBDER_MIG.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDMIG` | `GEBDMIG()` | GEBDER_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGD1` | `CriaGD1()` | GEBDER_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGD2` | `CriaGD2()` | GEBDER_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGD3` | `CriaGD3()` | GEBDER_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GEBDER_GUI.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDGER` | `GEBDGER(cComp)` | GEBDER_GUI: guia do IBS/CBS (GD mais cComp) com titulo no financeiro (`GEBDERGUIA`); regime Simples nao gera. Retorna o codigo da guia gravada ou vazio |

**`src/GEBDER_COB.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDJUR` | `GEBDJUR(cGuia, nDias)` | GEBDER_COB Retorna: .T.-.F. para GEBDPAR e GEBDPRO |
| `GEBDPAR` | `GEBDPAR(cGuia, nParc)` | GEBDER_COB Retorna: .T.-.F. para GEBDPAR e GEBDPRO |
| `GEBDPRO` | `GEBDPRO(cGuia)` | Protesto: grava GD3 PROTESTO/ABERTA e marca guia PROTESTADA. |

**`src/GEBDER_BAI.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBDBAI` | `GEBDBAI(cGuia[, cConta, cData])` | GEBDER_BAI: paga a guia pelo financeiro (`GEBDERPAGA`, conta padrao `DER_CONTA`/CAIXA). Retorna .T. se pagou (ou ja estava baixada) |

### GEB_ESTOQ_VENDA

**`src/GEBV_MIG.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVMIG` | `GEBVMIG()` | GEBV_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGV1` | `CriaGV1()` | GEBV_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGV2` | `CriaGV2()` | GEBV_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGV3` | `CriaGV3()` | GEBV_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GEBV_EST.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVEST` | `GEBVEST(cProd, nQtd)` | GEBV_EST Retorna: Novo saldo em GV1, 0 se bloqueado por guarda |

**`src/GEBV_VEN.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVVEN` | `GEBVVEN(cVenda, cProd, nQtd, nPreco)` | GEBV_VEN: venda a vista (estoque com custo + CMV, nota, titulo recebido no CAIXA). Retorna: VENDIDA ou BLOQUEADA ou SEM_ESTOQUE |
| `TemFiscal` | `TemFiscal()` | Diz se ha contexto fiscal (GF1/GF3) para integrar venda. |

**`src/GEBV_FIA.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBVFIA` | `GEBVFIA(cCli, nValor)` | GEBV_FIA: fiado com limite + titulo a receber FIA-<registro> e receita. Retorna: .T. se abriu, .F. se bloqueado |
| `GEBVJUR` | `GEBVJUR(cCli, nDias)` | GEBV_FIA Retorna: .T. se abriu, .F. se bloqueado (GEBVFIA); soma dos totais (GEBVJUR) |
| `SomaAberto` | `SomaAberto(cCli, cFil)` | Soma em aberto do cliente em GV3. |

### GEB_CONTABIL

**`src/GEBCTB_MIG.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMIG` | `GEBCMIG()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGC1` | `CriaGC1()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGC2` | `CriaGC2()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGC3` | `CriaGC3()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGC4` | `CriaGC4()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `SeedGC1` | `SeedGC1()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `SeedGC4` | `SeedGC4()` | GEBCTB_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GEBCTB_DIR.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCDIR` | `GEBCDIR(cContaD, cContaC, nValor, cUser)` | GEBCTB_DIR Retorna: .T. se gravou direto, .F. se alguma trava negou |

**`src/GEBCTB_BAL.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBBAL` | `GEBBAL(cComp)` | GEBCTB_BAL Retorna: Array do balancete (GEBBAL) ou resultado (GEBDRE) |
| `GEBDRE` | `GEBDRE(cComp)` | GEBCTB_BAL Retorna: Array do balancete (GEBBAL) ou resultado (GEBDRE) |
| `PosConta` | `PosConta(aBal, cConta)` | Indice da conta no array do balancete. |

### GEB_FIN

**`src/GEBFIN_MIG.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFNMIG` | `GEBFNMIG()` | GEBFIN_MIG Retorna: .T. se migracao/conta OK, .F. se falhar |
| `GEBFNCON` | `GEBFNCON(cConta, cNome)` | GEBFIN_MIG Retorna: .T. se migracao/conta OK, .F. se falhar |
| `CriaGFN1` | `CriaGFN1()` | GEBFIN_MIG Retorna: .T. se migracao/conta OK, .F. se falhar |
| `CriaGFN2` | `CriaGFN2()` | GEBFIN_MIG Retorna: .T. se migracao/conta OK, .F. se falhar |
| `CriaGFN3` | `CriaGFN3()` | GEBFIN_MIG Retorna: .T. se migracao/conta OK, .F. se falhar |
| `CriaGFN4` | `CriaGFN4()` | GEBFIN_MIG Retorna: .T. se migracao/conta OK, .F. se falhar |

**`src/GEBFIN_CON.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFNREC` | `GEBFNREC(cDoc, cCli, nValor, dVenc)` | GEBFIN_CON Retorna: .T. se lancou, .F. se recusou |
| `GEBFNPAG` | `GEBFNPAG(cDoc, cForn, nValor, dVenc)` | GEBFIN_CON Retorna: .T. se lancou, .F. se recusou |

**`src/GEBFIN_BAI.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBFNBAI` | `GEBFNBAI(cTipo, cDoc, nValor)` | GEBFIN_BAI: mentor + limite ao saldo e baixa pelo financeiro (`GEBFXBAI`) na conta CAIXA. Retorna: .T. se baixou, .F. se recusou |

**`src/GEBFIN_FLX.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBNFLX` | `GEBNFLX()` | GEBFIN_FLX Retorna: Array {nReceber, nPagar, nSaldo} |

### GEB_COM

**`src/GEBCOM_MIG.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMMIG` | `GEBCMMIG()` | GEBCOM_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGCP1` | `CriaGCP1()` | GEBCOM_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGCP2` | `CriaGCP2()` | GEBCOM_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGCP3` | `CriaGCP3()` | GEBCOM_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGCP4` | `CriaGCP4()` | GEBCOM_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGCP5` | `CriaGCP5()` | GEBCOM_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GEBCOM_FOR.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMFOR` | `GEBCMFOR(cCod, cNome)` | Cria fornecedor GCP1 (idempotente; vazio nega). |
| `GEBCMCOT` | `GEBCMCOT(cForn, cProd, nPreco)` | Grava cotacao GCP2 (fornecedor, produto, preco). |
| `GEBCMMEL` | `GEBCMMEL(cProd)` | Menor preco cotado do produto (0 se sem cotacao). |

**`src/GEBCOM_PED.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMPED` | `GEBCMPED(cPed, cForn)` | Cria pedido GCP3 ABERTO apos guia COMPRA_IMPULSIVA (travado vira BLOQUEADO). |
| `GEBCMIT` | `GEBCMIT(cPed, cProd, nQtd, nPreco)` | Grava item GCP4 (exige pedido existente). |

**`src/GEBCOM_ENT.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBCMENT` | `GEBCMENT(cNF, cPed)` | Entrada de NF pelo documento de entrada do backoffice (`GEBCPXENT`): estoque com custo, titulo pela condicao, COMPRA_ESTOQUE, credito de IBS/CBS, RECEBIDO/RECEBIDA. |
| `SomaItens` | `SomaItens(cPed, cFil4)` | Soma QTD x PRECO dos itens GCP4 do pedido. |
| `EntraEstoque` | `EntraEstoque(cPed, cFil4)` | Apropria itens do pedido no estoque via GEBVEST. |

### GEB_EXPANSAO

**`src/GEBEXP_MIG.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBEXPCriaAuditoria` | `GEBEXPCriaAuditoria()` | GEBEXP_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGEH` | `CriaGEH()` | GEBEXP_MIG Retorna: .T. se migracao OK, .F. se falhar |
| `CriaGEI` | `CriaGEI()` | GEBEXP_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GEBEXP_CTX.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBEXPCONTEXTO` | `GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)` | GEBEXP_CTX Retorna: .T. se sessao iniciada, .F. se usuario nao existe na empresa |
| `GEBEXPIST` | `GEBEXPIST()` | GEBEXPIST Retorna: .T. se sessao ativa, .F. caso contrario |
| `GEBEXPCONTEXT_GET` | `GEBEXPCONTEXT_GET()` | GEBEXPCONTEXT Retorna: Array 3 posicoes: [1]=empresa, [2]=filial, [3]=usuario |
| `GEBEXPCLEAR` | `GEBEXPCLEAR()` | GEBEXPCLEAR Retorna: void |
| `GEXBINIT` | `GEXBINIT()` | GEXBINIT Retorna: .T. sempre |
| `GEXPCREATE` | `GEXPCREATE()` | GEXPCREATE Retorna: .T. sempre |

**`src/GEBEXP_TRAK.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBTRAKCOMPRA` | `GEBTRAKCOMPRA(cPedido)` | GEBEXP_TRAK |
| `GEBTRAKVENDA` | `GEBTRAKVENDA(cVenda)` | Rastreio venda: header, itens, estoque, receber, lancamentos. |
| `GEBTRAKNOTAFISCAL` | `GEBTRAKNOTAFISCAL(cChave)` | Rastreio NF: header, itens, IBS/CBS, receber, apuracao, guia. |
| `GEBTRAKDERRAMA` | `GEBTRAKDERRAMA(cGuia)` | Rastreio guia: apuracao, guia, parcelas, protesto, pagar, baixa, lancamentos. |

**`src/GEBEXP_WEB.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBEXP_WEB` | `GEBEXP_WEB(cEmpresa, cUsuario)` | GEBEXP_WEB Retorna: .T. se dashboard exibido com sucesso |

**`src/GEBEXP_REL_NUC.prw`** — 9 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBRELEMPRESAS` | `GEBRELEMPRESAS()` | GEBEXP_REL_NUC |
| `GEBRELUSUARIOS` | `GEBRELUSUARIOS(cEmpresa)` | GEBEXP_REL_NUC |
| `GEBRELAUDITORIA` | `GEBRELAUDITORIA(cEmpresa, cInicio, cFim)` | Historico de acesso GEH por periodo. |
| `GEBRELMENTOR` | `GEBRELMENTOR(cEmpresa)` | Modos do Mentor por empresa. |
| `GEBRELCADASTROS` | `GEBRELCADASTROS(cEmpresa)` | Contagem de cadastros ativos. |
| `RNEmpAlvo` | `RNEmpAlvo(cEmpresa)` | Normaliza codigo de empresa para relatorios Nucleo. |
| `RNTabNoSchema` | `RNTabNoSchema(cEmp, cTabela)` | Verifica tabela no schema do tenant. |
| `RNContaTenant` | `RNContaTenant(cCod, cTabela)` | Conta registros de tabela do tenant. |
| `RNDataValida` | `RNDataValida(cData)` | Valida data AAAAMMDD para filtros. |

**`src/GEBEXP_REL_BIZ.prw`** — 7 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBRELFISCAL` | `GEBRELFISCAL(cEmpresa, cComp)` | GEBEXP_REL_BIZ |
| `GEBRELDERRAMA` | `GEBRELDERRAMA(cEmpresa, cComp)` | GEBEXP_REL_BIZ |
| `GEBRELFIN` | `GEBRELFIN(cEmpresa)` | Posicao financeira {contas, receber, pagar, valores, saldo, movs}. |
| `GEBRELSTOQUE` | `GEBRELSTOQUE(cEmpresa)` | Estoque {produtos, abaixo-minimo, valor, movs}. |
| `GEBRELCOMPRAS` | `GEBRELCOMPRAS(cEmpresa)` | Compras {fornecedores, pedidos, recebidos, valor, cotacoes}. |
| `GEBRELCONTABIL` | `GEBRELCONTABIL(cEmpresa, cComp)` | Lancamentos por competencia {qtd, debitos, creditos, valores, saldo}. |
| `GEBRELGERAL` | `GEBRELGERAL(cEmpresa)` | Consolidado fiscal+derrama+fin+estoque+compras+contabil. |

**`src/GEBFIL_MIG.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEFFILMIG` | `GEFFILMIG()` | GEBFIL_MIG |
| `GEFFILVALIDA` | `GEFFILVALIDA(cEmp, cFil)` | GEFFILVALIDA Retorna: .T. se formato OK |
| `GEFFILUNI` | `GEFFILUNI(cFil)` | GEFFILUNI Retorna: 2 chars da unidade ("" se invalido) |
| `CriaGEF1` | `CriaGEF1()` | GEFFILUNI Retorna: 2 chars da unidade ("" se invalido) |

**`src/GEBUNI_MIG.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEUNIMIG` | `GEUNIMIG()` | GEBUNI_MIG |
| `GEUVALIDA` | `GEUVALIDA(cUni)` | GEUVALIDA Retorna: .T. se formato OK |
| `CriaGEU1` | `CriaGEU1()` | GEUVALIDA Retorna: .T. se formato OK |

### GEB_SEGURANCA

**`src/GEBSEC_MIG.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `TCSecMIG` | `TCSecMIG()` | GEBSEC_MIG Retorna: .T. se migracao OK, .F. se falhar |

**`src/GEBSEC_POL.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECPOL_VERIFICA` | `GEBSECPOL_VERIFICA(cSenha)` | GEBSEC_POL Retorna: {lOk,cMsg} (GEBSECPOL_VERIFICA), dData (GEBSECPOL_EXPIRACAO), .T./.F. (GEBSECPOL_FORCA), void (GEBSE |
| `GEBSECPOL_EXPIRACAO` | `GEBSECPOL_EXPIRACAO(cUsuario)` | Calcula vencimento da senha. |
| `GEBSECPOL_FORCA` | `GEBSECPOL_FORCA(nForca)` | Flag de forca de senha (GE4). |
| `GEBSECFORCAR` | `GEBSECFORCAR(cUsuario)` | Marca redefinicao obrigatoria. |

**`src/GEBSEC_RBA.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECRBAC` | `GEBSECRBAC(cUsuario, cMenu, cItem)` | GEBSEC_RBA Retorna: .T./.F. (GEBSECRBAC/GEBSECRBACADD) ou array {menu,item,permite} (GEBSECRBACLIST) |
| `GEBSECRBACADD` | `GEBSECRBACADD(cPerfil, cMenu, cItem, lPermite)` | GEBSEC_RBA Retorna: .T./.F. (GEBSECRBAC/GEBSECRBACADD) ou array {menu,item,permite} (GEBSECRBACLIST) |
| `GEBSECRBACLIST` | `GEBSECRBACLIST(cPerfil)` | Lista permissoes do perfil. |

**`src/GEBSEC_RAC.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECRBAC` | `GEBSECRBAC(cUsuario, cMenu, cItem)` | GEBSEC_RAC Retorna: .T. se permitido, .F. caso contrario |

**`src/GEBSEC_LOGIN.prw`** — 6 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECLOGIN` | `GEBSECLOGIN(cUser, cPass, cIP)` | GEBSEC_LOGIN Retorna: cStatus  Codigo de status ("OK" ou erro) |
| `HashSenha` | `HashSenha(cSenha, cSalt)` | Hash da senha com salt. |
| `HexEncode` | `HexEncode(cBin)` | Codifica binario em hexadecimal. |
| `GEBSECSALT` | `GEBSECSALT()` | GEBSECSALT Retorna: cSalt  Salt hexadecimal de 32 chars, ou "" em falha |
| `GEBSECISSUPER` | `GEBSECISSUPER(cUsu)` | GEBSECISSUPER Retorna: .T. se for super |
| `GEBSECCRIAUSU` | `GEBSECCRIAUSU(cUsu, cSenha, aEmpresas, cNome, cPerfil, lPermiteSuper, cFilial)` | GEBSECISSUPER Retorna: .T. se for super |

**`src/GEBSEC_TOKEN.prw`** — 4 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBSECTOKEN` | `GEBSECTOKEN(cUsuario, cEmpresa, cFilial, cIP)` | GEBSEC_TOKEN Retorna: cToken    Token gerado ("") se falhar |
| `GBSTokDiaSeguinte` | `GBSTokDiaSeguinte(cData)` | Calcula expiracao do token (dia seguinte). |
| `GEBSECTOKENDEL` | `GEBSECTOKENDEL(cToken)` | Invalida token (logout). |
| `HashStr` | `HashStr(cTexto)` | Hash generico de texto (tokens). |

### GEB_GUI_TUI

**`src/GEBGUI_MAIN.prw`** — 9 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBGUIMAIN` | `GEBGUIMAIN(cModo)` | GEBGUI_MAIN Retorna: .T. se menu executado sem erro |
| `GEBGUINUC` | `GEBGUINUC()` | GEBGUI_MAIN Retorna: .T. se menu executado sem erro |
| `GEBGUIFIS` | `GEBGUIFIS()` | GEBGUI_MAIN Retorna: .T. se menu executado sem erro |
| `GEBGUIDER` | `GEBGUIDER()` | GEBGUI_MAIN Retorna: .T. se menu executado sem erro |
| `GEBGUIEST` | `GEBGUIEST()` | GEBGUI_MAIN Retorna: .T. se menu executado sem erro |
| `GEBGUIC` | `GEBGUIC` | GEBGUI_MAIN Retorna: .T. se menu executado sem erro |
| `GEBGUIFIN` | `GEBGUIFIN()` | Submenu Financeiro da GUI. |
| `GEBGUICOM` | `GEBGUICOM()` | Submenu Compras da GUI. |
| `GEBGUICFG` | `GEBGUICFG()` | Submenu Configuracao da GUI. |

**`src/GEBGUI_MNU.prw`** — 10 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBGUIMENU` | `GEBGUIMENU()` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `MenuDef` | `MenuDef()` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |
| `GEBGUI` | `GEBGUI` | GEBGUI_MNU Retorna: .T. se menu inicializado sem erro |

**`src/GEBGUI_BRW.prw`** — 17 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `BRW_EMPRESAS` | `BRW_EMPRESAS(cTitle)` | GEBGUI_BRW |
| `BRW_USUARIOS` | `BRW_USUARIOS(cTitle)` | GEBGUI_BRW |
| `BRW_PRODUTOS` | `BRW_PRODUTOS(cTitle)` | GEBGUI_BRW |
| `BRW_ALIQ` | `BRW_ALIQ(cTitle)` | GEBGUI_BRW |
| `BRW_NOTAS` | `BRW_NOTAS(cTitle)` | Browse de notas GF3. |
| `BRW_APU` | `BRW_APU(cTitle)` | Browse de apuracao GF5. |
| `BRW_GUIAS` | `BRW_GUIAS(cTitle)` | Browse de guias GD1. |
| `BRW_ESTOQUE` | `BRW_ESTOQUE(cTitle)` | Browse de estoque GV1. |
| `BRW_VENDAS` | `BRW_VENDAS(cTitle)` | Browse de vendas GV2. |
| `BRW_CONTA` | `BRW_CONTA(cTitle)` | Browse de contas GFN1. |
| `BRW_RECEBER` | `BRW_RECEBER(cTitle)` | Browse de receber GFN2. |
| `BRW_PAGAR` | `BRW_PAGAR(cTitle)` | Browse de pagar GFN3. |
| `BRW_FLUXO` | `BRW_FLUXO(cTitle)` | Browse de fluxo GFN4. |
| `BRW_FORNECEDORES` | `BRW_FORNECEDORES(cTitle)` | Browse de fornecedores GCP1. |
| `BRW_PEDIDOS` | `BRW_PEDIDOS(cTitle)` | Browse de pedidos GCP3. |
| `BRW_PLANCON` | `BRW_PLANCON(cTitle)` | Browse de plano de contas GC1. |
| `BRW_LANCAMENTOS` | `BRW_LANCAMENTOS(cTitle)` | Browse de lancamentos GC3. |

**`src/GEBGUI_CFG.prw`** — 12 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBGUICONF_SHOW` | `GEBGUICONF_SHOW()` | GEBGUI_CFG Retorna: void (todas) |
| `GEBGUICONF_PARAM` | `GEBGUICONF_PARAM(cSeccao)` | GEBGUI_CFG Retorna: void (todas) |
| `GEBGUICONF_ALIQ` | `GEBGUICONF_ALIQ(cNCM)` | Exibe aliquota vigente do NCM + exemplo CALCIBS(1000). |
| `GEBGUICONF_CAD_EMPRESA` | `GEBGUICONF_CAD_EMPRESA()` | Stub de cadastro rapido de empresa. |
| `GEBGUICONF_CAD_USUARIO` | `GEBGUICONF_CAD_USUARIO()` | Stub de cadastro rapido de usuario. |
| `GEBGUICONF_CAD_PRODUTO` | `GEBGUICONF_CAD_PRODUTO()` | Stub de cadastro rapido de produto. |
| `GEBGUICONF_CAD_FORN` | `GEBGUICONF_CAD_FORN()` | Stub de cadastro rapido de fornecedor. |
| `GEBGUICONF_CAD_CONTA` | `GEBGUICONF_CAD_CONTA()` | Stub de cadastro rapido de conta. |
| `GEBGUICONF_RESUMO` | `GEBGUICONF_RESUMO()` | Dashboard numerico (fluxo + balancete + DRE). |
| `GEBGUIMIG` | `GEBGUIMIG()` | Cria tabelas de config da GUI. |
| `CriaGEBGUICONFIG_SC` | `CriaGEBGUICONFIG_SC()` | DDL da tabela de config string. |
| `CriaGEBGUICONFIG_LC` | `CriaGEBGUICONFIG_LC()` | DDL da tabela de config logica. |

**`src/GEBGUI_LOGIN.prw`** — 3 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBGUI_LOGIN` | `GEBGUI_LOGIN(cUser, cPass, cEmp, cIP, lSkipDash)` | GEBGUI_LOGIN Retorna: .T. se autenticacao com sucesso, .F. se cancelado ou falha critica |
| `GEBGUIVINC` | `GEBGUIVINC(cUsu, cEmp, cFilial)` | GEBGUIVINC Retorna: .T. se formato valido e vinculo GE2_EMP existir |
| `GEBGUI_DASHBOARD` | `GEBGUI_DASHBOARD(cEmpresa, cUsuario, cFilial)` | GEBGUIVINC Retorna: .T. se formato valido e vinculo GE2_EMP existir |

**`src/GEBGUI_VLD.prw`** — 14 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBGUIPROD_CK` | `GEBGUIPROD_CK(cCod)` | GEBGUI_VLD |
| `GEBGUIFORN_CK` | `GEBGUIFORN_CK(cCod)` | GEBGUI_VLD |
| `GEBGUICLI_CK` | `GEBGUICLI_CK(cCod)` | GEBGUI_VLD |
| `GEBGUIPROD_EST` | `GEBGUIPROD_EST(cProd, nQtd)` | GEBGUI_VLD |
| `GEBGUIFIADO_LIM` | `GEBGUIFIADO_LIM(cCli, nValor)` | Valida limite 1000 do fiado. |
| `GEBGUIFIN_BAI` | `GEBGUIFIN_BAI(cTipo, cDoc, nValor)` | Valida tipo/documento/saldo para baixa. |
| `GEBGUIFIN_FLX` | `GEBGUIFIN_FLX()` | Valida e retorna fluxo {rec, pag, saldo}. |
| `GEBGUIFIS_EMI` | `GEBGUIFIS_EMI(cChave, cCod, nQtd, nPreco)` | Valida params de emissao (chave, produto, qtd, preco). |
| `GEBGUIFIS_APU` | `GEBGUIFIS_APU(cComp)` | Valida competencia para apuracao. |
| `GEBGUIFIS_GER` | `GEBGUIFIS_GER(cComp)` | Valida competencia e retorna guia. |
| `GEBGUICTB_DIR` | `GEBGUICTB_DIR(cCli, cContaD, cContaC, nValor)` | Valida flag PERMITE_DIRETA e delega a GEBCDIR. |
| `GEBGUICONFIG_LC` | `GEBGUICONFIG_LC(cChave)` | Le configuracao logica (GEBCFG). |
| `GEBGUICONFIG_SC` | `GEBGUICONFIG_SC(cChave, cValor)` | Le/escreve configuracao string. |
| `SomaAbertoGV3` | `SomaAbertoGV3(cCli, cFil)` | Soma TOTAL em aberto do cliente (fiado). |

**`src/GEBTUI.prw`** — 14 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBTUI` | `GEBTUI()` | GEBTUI |
| `GEBTUILOGIN` | `GEBTUILOGIN()` | GEBTUILOGIN Retorna: {cEmp, cFil, cUsu} ou {} se desistir/falhar |
| `GEBTUIEMPRESAS` | `GEBTUIEMPRESAS()` | GEBTUIEMPRESAS |
| `GEBTUIFILIAL` | `GEBTUIFILIAL(cUsu, cEmp)` | GEBTUIFILIAL Retorna: Codigo da filial, "" matriz, Nil se desistir |
| `GEBTUIBRW` | `GEBTUIBRW(cAlias, cTitle)` | GEBTUIBRW |
| `GEBTUIMENU` | `GEBTUIMENU(cEmp, cFil, cUsu)` | GEBTUIMENU |
| `GEBTUIFISCAL` | `GEBTUIFISCAL(cEmp, cFil, cUsu)` | GEBTUIFISCAL |
| `GEBTUIFIN` | `GEBTUIFIN(cEmp, cFil, cUsu)` | GEBTUIFIN |
| `GEBTUIDER` | `GEBTUIDER(cEmp, cFil, cUsu)` | GEBTUIDER |
| `GEBTUIEST` | `GEBTUIEST(cEmp, cFil, cUsu)` | GEBTUIEST |
| `GEBTUICTB` | `GEBTUICTB(cEmp, cFil, cUsu)` | GEBTUICTB |
| `GEBTUICOM` | `GEBTUICOM(cEmp, cFil, cUsu)` | GEBTUICOM |
| `GEBTUINUC` | `GEBTUINUC(cEmp, cFil, cUsu)` | GEBTUINUC |
| `GEBTUITROCASENHA` | `GEBTUITROCASENHA(cUsuLog, cAlvo, cSenha, cNome, cPerfil)` | GEBTUITROCASENHA Retorna: {lOk, cMsg} (cMsg: usuario_atualizado, nada_a_alterar, |

**`src/GEBAN.prw`** — 1 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBAN` | `GEBAN(cEmpresa, cUsuario, cSenha, cModo)` | GEBAN |

### GEB_REST_WEB

**`src/GEBREST.prw`** — 61 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBREST` | `GEBREST(cMetodo, cPath, aParams, cUsuario, cIP)` | GEBREST Retorna: Array {cStatus, cBody} onde cStatus e codigo HTTP e cBody e JSON |
| `GEBRESTRBAC` | `GEBRESTRBAC(cUsuario, cPath, cMetodo)` | GEBRESTRBAC Retorna: .T. se permitido, .F. caso contrario |
| `GEBRESTJSONRESP` | `GEBRESTJSONRESP(lOk, xDados, aErros)` | GEBRESTJSONRESP Retorna: String JSON |
| `GEBRESTJSONENC` | `GEBRESTJSONENC(xVal)` | GEBRESTJSONENC Retorna: String JSON |
| `GEBRESTJSONESCAPE` | `GEBRESTJSONESCAPE(cStr)` | GEBRESTJSONESCAPE Retorna: String escapada |
| `GEBRESTJSONDEC` | `GEBRESTJSONDEC(cJson)` | GEBRESTJSONDEC Retorna: Array de tokens |
| `GEBRESTJSONTOOBJ` | `GEBRESTJSONTOOBJ(aTok)` | GEBRESTJSONTOOBJ Retorna: Array/valor AdvPL |
| `GEBRESTJSONPARSE` | `GEBRESTJSONPARSE(aTok, ByRef nPos)` | GEBRESTJSONPARSE |
| `GEBRESTJSONTOARR` | `GEBRESTJSONTOARR(cJson)` | GEBRESTJSONTOARR Retorna: Array AdvPL |
| `GEBRESTRLIMIT` | `GEBRESTRLIMIT(cIP, nLim)` | GEBRESTRLIMIT Retorna: .T. se dentro do limite, .F. caso contrario |
| `GEBRESTHEALTH` | `GEBRESTHEALTH(cUsuario)` | GEBRESTHEALTH Retorna: Array {nHttp, cJson} |
| `GEBRESTUSRLST` | `GEBRESTUSRLST(cUsuario)` | GEBRESTUSRLST Retorna: Array {nHttp, cJson} |
| `GEBRESTURGET` | `GEBRESTURGET(cUsuario, cCod)` | GEBRESTURGET Retorna: Array {nHttp, cJson} |
| `GEBRESTURLSC` | `GEBRESTURLSC(cUsuario, aBody)` | GEBRESTURLSC Retorna: Array {nHttp, cJson} |
| `GEBRESTUSRUPD` | `GEBRESTUSRUPD(cUsuario, cCod, aBody)` | GEBRESTUSRUPD Retorna: Array {nHttp, cJson} |
| `GEBRESTUSRRM` | `GEBRESTUSRRM(cUsuario, cCod)` | GEBRESTUSRRM Retorna: Array {nHttp, cJson} |
| `GEBRESTEMPLST` | `GEBRESTEMPLST(cUsuario)` | GEBRESTEMPLST Retorna: Array {nHttp, cJson} |
| `GEBRESTEMPLSC` | `GEBRESTEMPLSC(cUsuario, aBody)` | GEBRESTEMPLSC Retorna: Array {nHttp, cJson} |
| `GEBRESTPRDLST` | `GEBRESTPRDLST(cUsuario)` | GEBRESTPRDLST Retorna: Array {nHttp, cJson} |
| `GEBRESTPRDLSC` | `GEBRESTPRDLSC(cUsuario, aBody)` | GEBRESTPRDLSC Retorna: Array {nHttp, cJson} |
| `GEBRESTNOTLST` | `GEBRESTNOTLST(cUsuario, aParams)` | GEBRESTNOTLST Retorna: Array {nHttp, cJson} |
| `GEBRESTNOTPOST` | `GEBRESTNOTPOST(cUsuario, aBody)` | GEBRESTNOTPOST Retorna: Array {nHttp, cJson} |
| `GEBRESTFLXLST` | `GEBRESTFLXLST(cUsuario)` | GEBRESTFLXLST Retorna: Array {nHttp, cJson} |
| `GEBRESTCONLST` | `GEBRESTCONLST(cUsuario)` | GEBRESTCONLST Retorna: Array {nHttp, cJson} |
| `GEBRESTRELFISSC` | `GEBRESTRELFISSC(cUsuario, cComp)` | GEBRESTRELFISSC Retorna: Array {nHttp, cJson} |
| `GEBRESTRELGER` | `GEBRESTRELGER(cUsuario)` | GEBRESTRELGER Retorna: Array {nHttp, cJson} |
| `GEBRESTMONUSU` | `GEBRESTMONUSU(cUsuario)` | GEBRESTMONUSU Retorna: Array {nHttp, cJson} |
| `GEBRESTMONDES` | `GEBRESTMONDES(cUsuario, cToken)` | GEBRESTMONDES Retorna: Array {nHttp, cJson} |
| `GEBRESTDERLST` | `GEBRESTDERLST(cUsuario)` | GEBRESTDERLST Retorna: Array {nHttp, cJson} |
| `GEBRESTESTLST` | `GEBRESTESTLST(cUsuario)` | GEBRESTESTLST Retorna: Array {nHttp, cJson} |
| `GEBRESTVENLST` | `GEBRESTVENLST(cUsuario)` | GEBRESTVENLST Retorna: Array {nHttp, cJson} |
| `GEBRESTCTBLST` | `GEBRESTCTBLST(cUsuario)` | GEBRESTCTBLST Retorna: Array {nHttp, cJson} |
| `GEBRESTCTCLST` | `GEBRESTCTCLST(cUsuario)` | GEBRESTCTCLST Retorna: Array {nHttp, cJson} |
| `GEBRESTCOMLST` | `GEBRESTCOMLST(cUsuario)` | GEBRESTCOMLST Retorna: Array {nHttp, cJson} |
| `GEBRESTFORLST` | `GEBRESTFORLST(cUsuario)` | GEBRESTFORLST Retorna: Array {nHttp, cJson} |
| `GEBRESTTENANT` | `GEBRESTTENANT()` | GEBRESTTENANT Retorna: Codigo ("" se fora de tenant) |
| `GEBRESTFILLST` | `GEBRESTFILLST(cUsuario)` | GEBRESTFILLST Retorna: Array {nHttp, cJson} |
| `GEBRESTFILSC` | `GEBRESTFILSC(cUsuario, aBody)` | GEBRESTFILSC Retorna: Array {nHttp, cJson} |
| `GEBRESTVINCSC` | `GEBRESTVINCSC(cUsuario, aBody)` | GEBRESTVINCSC Retorna: Array {nHttp, cJson} |
| `GEBRESTPUBEMP` | `GEBRESTPUBEMP(cUsuario)` | GEBRESTPUBEMP Retorna: Array {nHttp, cJson} |
| `GEBRESTDERGER` | `GEBRESTDERGER(cUsuario, aBody)` | GEBRESTDERGER Retorna: Array {nHttp, cJson} 201 {guia} / 400 |
| `GEBRESTDERBAI` | `GEBRESTDERBAI(cUsuario, aBody)` | GEBRESTDERBAI Retorna: Array {nHttp, cJson} 200 / 404 |
| `GEBRESTDERPAR` | `GEBRESTDERPAR(cUsuario, aBody)` | GEBRESTDERPAR Retorna: Array {nHttp, cJson} 200 / 400 |
| `GEBRESTDERJUR` | `GEBRESTDERJUR(cUsuario, aBody)` | GEBRESTDERJUR Retorna: Array {nHttp, cJson} 200 {total} |
| `GEBRESTDERPRO` | `GEBRESTDERPRO(cUsuario, aBody)` | GEBRESTDERPRO Retorna: Array {nHttp, cJson} 200 / 404 |
| `GEBRESTESTVEN` | `GEBRESTESTVEN(cUsuario, aBody)` | GEBRESTESTVEN Retorna: Array 201 VENDIDA / 409 SEM_ESTOQUE / 403 BLOQUEADA / 400 |
| `GEBRESTESTFIA` | `GEBRESTESTFIA(cUsuario, aBody)` | GEBRESTESTFIA Retorna: Array 201 / 400 |
| `GEBRESTESTFIJ` | `GEBRESTESTFIJ(cUsuario, aBody)` | GEBRESTESTFIJ Retorna: Array 200 {total} |
| `GEBRESTCTBDIR` | `GEBRESTCTBDIR(cUsuario, aBody)` | GEBRESTCTBDIR Retorna: Array 201 / 400 |
| `GEBRESTCTBBAL` | `GEBRESTCTBBAL(cUsuario, aComp)` | GEBRESTCTBBAL Retorna: Array 200 |
| `GEBRESTCTBDRE` | `GEBRESTCTBDRE(cUsuario, aComp)` | GEBRESTCTBDRE Retorna: Array 200 {resultado} |
| `GEBRESTFINCON` | `GEBRESTFINCON(cUsuario, aBody)` | GEBRESTFINCON Retorna: Array 201 / 400 |
| `GEBRESTFINBAI` | `GEBRESTFINBAI(cUsuario, aBody)` | GEBRESTFINBAI Retorna: Array 200 / 400 |
| `GEBRESTCOMFOR` | `GEBRESTCOMFOR(cUsuario, aBody)` | GEBRESTCOMFOR Retorna: Array 201 / 400 |
| `GEBRESTCOMPED` | `GEBRESTCOMPED(cUsuario, aBody)` | GEBRESTCOMPED Retorna: Array 201 ABERTO / 403 BLOQUEADO / 400 |
| `GEBRESTCOMIT` | `GEBRESTCOMIT(cUsuario, aBody)` | GEBRESTCOMIT Retorna: Array 201 / 400 |
| `GEBRESTCOMENT` | `GEBRESTCOMENT(cUsuario, aBody)` | GEBRESTCOMENT Retorna: Array 201 / 400 |
| `GEBRESTFISAPU` | `GEBRESTFISAPU(cUsuario, aBody)` | GEBRESTFISAPU Retorna: Array 200 / 400 |
| `GEBRESTFISCRE` | `GEBRESTFISCRE(cUsuario, aBody)` | GEBRESTFISCRE Retorna: Array 201 {registro} / 400 |
| `GEBRESTUNILST` | `GEBRESTUNILST(cUsuario)` | GEBRESTUNILST Retorna: Array {nHttp, cJson} |
| `GEBRESTUNILSC` | `GEBRESTUNILSC(cUsuario, aBody)` | GEBRESTUNILSC Retorna: Array {nHttp, cJson} 201 / 400 / 409 |

**`src/GEBWEB.prw`** — 2 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBWEB` | `GEBWEB(nPorta)` | GEBWEB |
| `GEBWEB_LOGINAPI` | `GEBWEB_LOGINAPI(oReq)` | GEBWEB_LOGINAPI |

**`src/GEBWEB_API.prw`** — 58 funções

| Função | Assinatura | Propósito |
|---|---|---|
| `GEBWAPIFIELD` | `GEBWAPIFIELD(oReq, cNome)` | GEBWAPIFIELD Retorna: Valor em string ("" se ausente) |
| `GEBWAPIAUTH` | `GEBWAPIAUTH(cTok, cEmp)` | GEBWAPIAUTH Retorna: Array {lOk, cUsuario} |
| `GEBWAPIRESP` | `GEBWAPIRESP(aRes)` | GEBWAPIRESP Retorna: Array sentinela RAW_HTTP |
| `GEBWAPIDENY` | `GEBWAPIDENY()` | GEBWAPIDENY Retorna: Array sentinela RAW_HTTP 401 |
| `GEBWAPIW_HEALTH` | `GEBWAPIW_HEALTH()` | GEBWAPIW_HEALTH Retorna: Array sentinela RAW_HTTP |
| `GEBWAPIW_GET` | `GEBWAPIW_GET(cTok, cEmp, cMetodo, cPath, aParams)` | GEBWAPIW_GET Retorna: Array sentinela RAW_HTTP |
| `GEBWAPIW_POST` | `GEBWAPIW_POST(cTok, cEmp, cPath, aBody)` | GEBWAPIW_POST Retorna: Array sentinela RAW_HTTP |
| `GEBWAPIW_PUTDEL` | `GEBWAPIW_PUTDEL(cTok, cEmp, cMetodo, cPath, aBody)` | GEBWAPIW_PUTDEL Retorna: Array sentinela RAW_HTTP |
| `GEBWAPI_HEALTH` | `GEBWAPI_HEALTH(oReq)` | GEBWAPI_HEALTH |
| `GEBWAPI_USRLST` | `GEBWAPI_USRLST(oReq)` | GEBWAPI_USRLST |
| `GEBWAPI_USRGET` | `GEBWAPI_USRGET(oReq)` | GEBWAPI_USRGET |
| `GEBWAPI_USRPOST` | `GEBWAPI_USRPOST(oReq)` | GEBWAPI_USRPOST |
| `GEBWAPI_USRPUT` | `GEBWAPI_USRPUT(oReq)` | GEBWAPI_USRPUT |
| `GEBWAPI_USRDEL` | `GEBWAPI_USRDEL(oReq)` | GEBWAPI_USRDEL |
| `GEBWAPI_EMPLST` | `GEBWAPI_EMPLST(oReq)` | GEBWAPI_EMPLST |
| `GEBWAPI_EMPLSC` | `GEBWAPI_EMPLSC(oReq)` | GEBWAPI_EMPLSC |
| `GEBWAPI_PRDLST` | `GEBWAPI_PRDLST(oReq)` | GEBWAPI_PRDLST |
| `GEBWAPI_PRDLSC` | `GEBWAPI_PRDLSC(oReq)` | GEBWAPI_PRDLSC |
| `GEBWAPI_NOTLST` | `GEBWAPI_NOTLST(oReq)` | GEBWAPI_NOTLST |
| `GEBWAPI_NOTPOST` | `GEBWAPI_NOTPOST(oReq)` | GEBWAPI_NOTPOST |
| `GEBWAPI_FLXLST` | `GEBWAPI_FLXLST(oReq)` | GEBWAPI_FLXLST |
| `GEBWAPI_CONLST` | `GEBWAPI_CONLST(oReq)` | GEBWAPI_CONLST |
| `GEBWAPI_RELFISC` | `GEBWAPI_RELFISC(oReq)` | GEBWAPI_RELFISC |
| `GEBWAPI_RELGER` | `GEBWAPI_RELGER(oReq)` | GEBWAPI_RELGER |
| `GEBWAPI_MONUSU` | `GEBWAPI_MONUSU(oReq)` | GEBWAPI_MONUSU |
| `GEBWAPI_MONDEL` | `GEBWAPI_MONDEL(oReq)` | GEBWAPI_MONDEL |
| `GEBWAPI_DERLST` | `GEBWAPI_DERLST(oReq)` | GEBWAPI_DERLST |
| `GEBWAPI_ESTLST` | `GEBWAPI_ESTLST(oReq)` | GEBWAPI_ESTLST |
| `GEBWAPI_VENLST` | `GEBWAPI_VENLST(oReq)` | GEBWAPI_VENLST |
| `GEBWAPI_CTBLST` | `GEBWAPI_CTBLST(oReq)` | GEBWAPI_CTBLST |
| `GEBWAPI_CTCLST` | `GEBWAPI_CTCLST(oReq)` | GEBWAPI_CTCLST |
| `GEBWAPI_COMLST` | `GEBWAPI_COMLST(oReq)` | GEBWAPI_COMLST |
| `GEBWAPI_FORLST` | `GEBWAPI_FORLST(oReq)` | GEBWAPI_FORLST |
| `GEBWAPI_FILLST` | `GEBWAPI_FILLST(oReq)` | GEBWAPI_FILLST |
| `GEBWAPI_FILSC` | `GEBWAPI_FILSC(oReq)` | GEBWAPI_FILSC |
| `GEBWAPI_VINCSC` | `GEBWAPI_VINCSC(oReq)` | GEBWAPI_VINCSC |
| `GEBWAPI_PUBEMP` | `GEBWAPI_PUBEMP(oReq)` | GEBWAPI_PUBEMP |
| `GEBWAPI_DERGER` | `GEBWAPI_DERGER(oReq)` | GEBWAPI_DERGER |
| `GEBWAPI_DERBAI` | `GEBWAPI_DERBAI(oReq)` | GEBWAPI_DERBAI |
| `GEBWAPI_DERPAR` | `GEBWAPI_DERPAR(oReq)` | GEBWAPI_DERPAR |
| `GEBWAPI_DERJUR` | `GEBWAPI_DERJUR(oReq)` | GEBWAPI_DERJUR |
| `GEBWAPI_DERPRO` | `GEBWAPI_DERPRO(oReq)` | GEBWAPI_DERPRO |
| `GEBWAPI_ESTVEN` | `GEBWAPI_ESTVEN(oReq)` | GEBWAPI_ESTVEN |
| `GEBWAPI_ESTFIA` | `GEBWAPI_ESTFIA(oReq)` | GEBWAPI_ESTFIA |
| `GEBWAPI_ESTFIJ` | `GEBWAPI_ESTFIJ(oReq)` | GEBWAPI_ESTFIJ |
| `GEBWAPI_CTBDIR` | `GEBWAPI_CTBDIR(oReq)` | GEBWAPI_CTBDIR |
| `GEBWAPI_CTBBAL` | `GEBWAPI_CTBBAL(oReq)` | GEBWAPI_CTBBAL |
| `GEBWAPI_CTBDRE` | `GEBWAPI_CTBDRE(oReq)` | GEBWAPI_CTBDRE |
| `GEBWAPI_FINCON` | `GEBWAPI_FINCON(oReq)` | GEBWAPI_FINCON |
| `GEBWAPI_FINBAI` | `GEBWAPI_FINBAI(oReq)` | GEBWAPI_FINBAI |
| `GEBWAPI_COMFOR` | `GEBWAPI_COMFOR(oReq)` | GEBWAPI_COMFOR |
| `GEBWAPI_COMPED` | `GEBWAPI_COMPED(oReq)` | GEBWAPI_COMPED |
| `GEBWAPI_COMIT` | `GEBWAPI_COMIT(oReq)` | GEBWAPI_COMIT |
| `GEBWAPI_COMENT` | `GEBWAPI_COMENT(oReq)` | GEBWAPI_COMENT |
| `GEBWAPI_FISAPU` | `GEBWAPI_FISAPU(oReq)` | GEBWAPI_FISAPU |
| `GEBWAPI_FISCRE` | `GEBWAPI_FISCRE(oReq)` | GEBWAPI_FISCRE |
| `GEBWAPI_UNILST` | `GEBWAPI_UNILST(oReq)` | GEBWAPI_UNILST |
| `GEBWAPI_UNILSC` | `GEBWAPI_UNILSC(oReq)` | GEBWAPI_UNILSC |

<!-- arquivos fora dos modulos: [] -->
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
| `GEBLOJ.prw` | `GEBLOJCX`, `GEBLOJABRE`, `GEBLOJVEN` (código de barras, promoção, vendedor, CPF, limite de desconto, pagamento `VALE`), `GEBLOJCAN`, `GEBLOJSAN`, `GEBLOJFECHA`, relatórios `GEBLOJRESUMO`/`GEBLOJVENDAS`; `GEBLOJSES`/`GEBLOJCXA`/`GEBLOJESP` (sessão, caixa, dinheiro esperado) |
| `GEBLOJ_CAD.prw` | `GEBLOJCADMIG` (GLJ8–GLJH), `GEBLOJBAR` (código de barras/PLU), `GEBLOJEANOK`, `GEBLOJRESOLVE` (produto, GTIN ou etiqueta de balança), `GEBLOJPROMO`, `GEBLOJPRECO` (melhor promoção vigente), `GEBLOJVEND`/`GEBLOJVENDOK`, `GEBLOJCPFOK`, `GEBLOJDIGITOS` |
| `GEBLOJ_OPE.prw` | `GEBLOJORC`/`GEBLOJORCFIN`/`GEBLOJORCCAN` (orçamento), `GEBLOJDEV` (devolução no caixa), `GEBLOJVALE`, `GEBLOJCUPOM` (segunda via), `GEBLOJCONS` (consulta de preço), relatórios `GEBLOJORCS`/`GEBLOJGER`/`GEBLOJCOMIS` |
| `GEBBO.prw` | `GEBBOROTAS` (tabela de rotas e permissões), `GEBBOROTA`, `GEBBOEXEC` |
| `GEBBCO.prw` | `GEBBCOCFG`, `GEBBCOBOL`, `GEBBCOBARRAS`/`GEBBCOLINHA`/`GEBBCOMOD10`/`GEBBCOMOD11`/`GEBBCONNDV`/`GEBBCOFATOR`, `GEBBCOLIVRE` (campo livre e nosso número por banco: 001, 033, 104, 237, 341, 756), `GEBBCOHTML`, `GEBBCOREM`/`GEBBCORET` (CNAB 240 FEBRABAN v10.3 para todos; CNAB 400 do Itaú e do Bradesco), `GEBBCOOFX`, `GEBBCOCONC`/`GEBBCOCONCMAN`/`GEBBCOLANCA`, relatório `GEBBCOREL` |
| `GEBTEF.prw` | `GEBTEFCFG`, `GEBTEFAUT`, `GEBTEFCONF`, `GEBTEFDESF`, `GEBTEFCANC`, `GEBTEFRESOLVE`, `GEBTEFRESP`, `GEBTEFCIELO` (leitura da resposta da API Cielo e-Commerce 3.0), relatório `GEBTEFREL` |
| `GEBTUIBO.prw` | telas `GEBTUIFAT`, `GEBTUILOJ`, `GEBTUIBOEST`, `GEBTUIBOFIN`, `GEBTUIBOCTB`, `GEBTUIBOCOM` |
| `GEBDER_FIN.prw` | Derrama ↔ financeiro: `GEBDERGUIA` (guia + título a pagar de mesmo número; reapuração; guia complementar), `GEBDERPAGA` (paga a guia pelo financeiro), `GEBDERPODEPAR`/`GEBDERPARTIT` (parcelamento em títulos), `GEBDERTITS`, `GEBDERPROV` (provisão contábil pela diferença), `GEBDERFMIG` (GD4) |
| `GEBRET.prw` | Retenções: `GEBRETCAD` (regra), `GEBRETVAL`, `GEBRETAPL` (na entrada de compra), relatório `GEBRETREL`, `GEBRETMIG` |
| `GENUC_MIG.prw` | `GEBREGIME()` — regime único da empresa (parâmetro `REGIME`; senão a linha da empresa na GE1 com nome `SIMPLES`; senão `REGULAR`) |

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
- GLJ1–GLJ7 loja (GLJ7 transações TEF); GLJ8 códigos de barras, GLJ9 promoções, GLJA promoção aplicada por item, GLJB complemento do cupom (vendedor, CPF, orçamento, quem liberou o desconto, hora), GLJC vendedores, GLJD/GLJE orçamentos, GLJF vales-troca, GLJH devoluções no caixa.

**Parâmetros GE4:** `EST_NEGATIVO`, `EST_VENCIDO`, `EST_FECHADO` (gravado pelo fechamento), `FIN_JUROS_DIA`, `FIN_MULTA`, `COM_ALCADA`, `BCO_DIAS_CONC`, `LOJ_CONTA_PIX`, `LOJ_CONTA_COFRE`, `LOJ_TAXA_DEB`, `LOJ_TAXA_CRED`, `LOJ_FIADO_DIAS`, `LOJ_DESC_MAX` (desconto máximo sem liberação, % do bruto; vazio = sem limite), `LOJ_BALANCA` (PRECO ou PESO na etiqueta), `LOJ_ORC_DIAS` (validade do orçamento, padrão 7), `LOJ_TEF` (S/N), `LOJ_TEF_PROVEDOR` (SIMULADOR/HTTP/CIELO), `LOJ_TEF_URL`, `LOJ_TEF_TOKEN`, `LOJ_TEF_TIMEOUT`, `LOJ_CIELO_URL` (padrão: sandbox), `LOJ_CIELO_MERCHANTID`, `LOJ_CIELO_MERCHANTKEY`, `LOJ_CIELO_CARTAO` e `LOJ_CIELO_BANDEIRA` (cartão usado na venda — só serve para a sandbox ou o emulador; ver docs/02 §19), `REGIME` (SIMPLES/REGULAR; gravado por `GEBSNCFG`), `DER_CONTA` (conta que paga a guia, padrão CAIXA), `DER_DIA_IBSCBS`, `DER_DIA_ICMS`, `DER_DIA_ISS` e `RET_DIA_<tributo>` (dia do vencimento, padrão 20, ajustado para dia útil).

**Contas e eventos da integração** (inseridos se faltarem): 2.01.004 IBS/CBS a recolher, 2.01.005 tributos retidos a recolher, 2.01.006 ICMS/ISS a recolher (fora do DAS), 3.02.002 IBS/CBS sobre vendas, 4.02.007 ICMS/ISS fora do DAS; eventos `APU_IBSCBS`, `SN_FORA`, `RET_FORN`, `FIN_RECEITA` (o `SN_DAS` passou a ser usado). Ver docs/02 §20. Frente de loja: `LOJ_VALE` (D 2.01.003 / C 3.01.001, venda paga com vale-troca).

**Venda da loja (`loja/venda`):** além de `sessao`, `itens`, `pagamentos`, `cliente` e `desconto`, aceita `vendedor`, `cpf`, `supervisor` e `senha_supervisor` (desconto acima de `LOJ_DESC_MAX`). Em `itens`, `produto` pode ser o código de barras ou a etiqueta da balança. Em `pagamentos`, a forma `VALE` leva o número do vale em `documento`.

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

**Requisito de runtime:** advplc **v4.6.0** ou mais novo (`PrivSignRSA`, `ProcRun`, `HTTPSPost` com certificado de cliente, `DateTimeUTC`). A produção roda a 4.4.5: o deploy desta etapa vai com `o script de publicacao --advplc <binário 4.6.0>`. O servidor também precisa do `openssl` (já existe na servidor de testes) e da cadeia ICP-Brasil instalada (o script de instalacao da cadeia ICP-Brasil, ver docs/07).

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
| `T_GEBDFE` | Suíte, banco de teste | 51 verificações de ponta a ponta contra `tests/emuladores/sefaz_emulador.py` (HTTPS 127.0.0.1:18766; confere digest e RSA de cada documento e simula 100, 204, 297, 373, 539, 778, 108, resposta lenta, 135, 580, 102, 241, 101, 217). O runner de testes sobe o emulador e exporta `ADVPP_HTTP_INSECURE` só para os testes. |
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
