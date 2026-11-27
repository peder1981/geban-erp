# Design — Crypto no PDV, Gatilho Sarney e Regime de venda (comprovante x fiscal)

Data: 2026-11-26 · Autor: Devin · Status: aprovado pelo operador (decisões abaixo)

## Decisões do operador

| Ponto | Decisão |
|---|---|
| Cotação BRL→crypto | CoinGecko (`simple/price`, `vs_currencies=brl`), sem chave, via `HttpQuote` |
| Confirmação do pagamento crypto | Manual — o operador confere a carteira e confirma |
| Alvo do Sarney | Tabela de preços `GFT2_TAB = 'PADRAO'` |
| Regime de venda | PDV **e** faturamento |

## 1. Pagamento em crypto (módulo `GEBCRY`, tabelas `GCK*`)

### Tabelas (por filial, via `BOTAB`)

- `GCK1` wallet do estabelecimento: `GCK1_MOEDA` (BTC/ETH/XMR/USDC/USDT),
  `GCK1_ENDERECO` (chave pública ou, para ERC-20, a wallet de destino),
  `GCK1_ATIVO` ('S'/'N'). Uma linha por moeda.
- `GCK2` pagamento crypto do cupom: `GCK2_CUPOM`, `GCK2_MOEDA`,
  `GCK2_ENDERECO`, `GCK2_BRL` NUMERIC(18,2), `GCK2_QTD` NUMERIC(18,8),
  `GCK2_COT` NUMERIC(18,8) (taxa BRL por unidade usada).

### Funções (`src/GEBCRY.prw`)

- `GEBCRYMIG()` — cria GCK1/GCK2.
- `GEBCRYMOEDAS()` — lista fechada `{moeda, id CoinGecko}`:
  BTC=bitcoin, ETH=ethereum, XMR=monero, USDC=usd-coin, USDT=tether.
- `GEBCRYWAL(cMoeda, cEndereco, cAtivo)` — upsert da wallet (RBAC `CONFIG`).
- `GEBCRYWALLST()` — wallets ativas da filial.
- `GEBCRYCOT()` — cotação BRL de todas as moedas configuradas via
  CoinGecko; timeout `GE4 CRY_TIMEOUT` (padrão 15s). Retorna `{}` se a
  API falhar (a tela avisa; a venda em si decide o que fazer).
- `GEBCRYQRCODE(cMoeda, nBRL)` — resolve wallet + cotação e devolve
  `{lOk, cMsg, {cUri, cEndereco, nQtd, nCot}}`. URI por moeda:
  - BTC `bitcoin:<addr>?amount=<qtd>`
  - ETH `ethereum:<addr>?value=<qtd>` (valor em ETH)
  - XMR `monero:<addr>?tx_amount=<qtd>`
  - USDC/USDT (ERC-20): `ethereum:<contrato>/transfer?address=<addr>&uint256=<qtd*1e6>`
    (contratos USDC `0xA0b8…eB48`, USDT `0xdAC1…1ec7`, 6 decimais)
- `GEBCRYPAGA(cCupom, cMoeda, cEndereco, nBRL, nQtd, nCot)` — grava GCK2.

### Integração na venda (`GEBLOJVEN`)

- Forma de pagamento `"CRYPTO"` entra na lista fechada. Item de pagamento:
  `{"CRYPTO", nValorBRL, 1, "MOEDA|ENDERECO"}` (doc = moeda|endereço,
  reaproveita `LOJDocPg`).
- No fechamento, para cada CRYPTO: `GEBCRYQRCODE` confirma wallet ativa;
  a cotação é buscada **no servidor** (não confia no cliente); grava GCK2.
- Financeiro: credita a conta `GE4 CRY_CONTA` (conta GFN1 de recebimento
  crypto, ex.: "CRIPTO") via `GEBFXMOVCONTA` + `GEBCTXLP("LOJ_CRYPTO")`.
  Sem `CRY_CONTA` configurada → venda recusada com mensagem clara.
- `GEBLOJCUPOM` (segunda via) exibe linha crypto com moeda, qtd e endereço.

### API / UI

- `GET /api/pdv/crypto/cotacao` → moedas configuradas + cotação BRL.
- `GET /api/pdv/crypto/wallets` → wallets ativas.
- `POST /api/pdv/crypto/wallet` → upsert (RBAC `CONFIG`, como periféricos).
- `public/pdv.html`: botão CRYPTO, seleção da moeda, QR code (lib JS
  vendored `public/vendor/qrcode.min.js`), endereço/valor em texto e
  confirmação manual.

## 2. Gatilho Sarney (`src/GESSAR.prw`, tabelas `GSK*`)

Reajuste programado de preços da tabela `GFT2_TAB='PADRAO'`, sem
etiquetadora: o preço muda no sistema e vale para PDV, pedidos e notas.

### Tabelas

- `GSK1` regra: `GSK1_COD`, `GSK1_DESCR`, `GSK1_PCT` NUMERIC(8,4) (percentual
  geral), `GSK1_VEZES` INTEGER (total de aplicações), `GSK1_HORAS` TEXT
  (horários HHMM separados por espaço, ex.: `"0800 1200 1800 2100"`),
  `GSK1_FEITAS` INTEGER, `GSK1_ULTHORA` TEXT (`AAAAMMDDHHMM` do último slot
  aplicado), `GSK1_ATIVO` ('S'/'N').
- `GSK2` override por produto: `GSK2_CFG`, `GSK2_PROD`, `GSK2_PCT`.
- `GSK3` auditoria por produto aplicado: `GSK3_CFG`, `GSK3_DATA`,
  `GSK3_HORA`, `GSK3_PROD`, `GSK3_PCT`, `GSK3_ANT`, `GSK3_NOV`.

### Funções

- `GESSARMIG()`; `GESSARCFG(cCod,cDescr,nPct,nVezes,cHoras,cAtivo)` upsert;
  `GESSARPROD(cCfg,cProd,nPct)` (nPct 0 remove override);
  `GESSARLISTA()`; `GESSARHIST(cCod)` (últimos reajustes).
- `GESSARDEVE(cHoje,cHora,cCfg)` — função pura: ativo, `FEITAS < VEZES`,
  `cHora` está em `GSK1_HORAS` e `ULTHORA != cHoje+cHora`.
- `GESSARAPLICA(aCfg)` — aplica `pct` (override GSK2 ou geral) em todos os
  produtos de `GFT2_TAB='PADRAO'` com preço > 0:
  `GFT2_PRECO = ROUND(preco * (1 + pct/100), 4)`; grava GSK3 por produto;
  incrementa `FEITAS` e grava `ULTHORA`.
- `GESSARRUN()` — chamado pelo agendador a cada minuto (dentro da trava
  `pg_advisory_lock` de `GEBSCHRODA`): roda as regras devidas e devolve o
  total de aplicações.

### Gancho no agendador

`GEBSCH.prw` passa a `#include "GESSAR.prw"` e `GEBSCHRODA()` chama
`GESSARRUN()` antes de liberar a trava. Nenhuma rotina SCH_JOB é necessária:
as regras GSK1 têm agenda própria.

### TUI

Módulo "Sarney" (permissão `LOJA`): abas GSK1 (regras) e GSK2 (produtos com
percentual próprio) + formulário "Regra de reajuste" e "Produto do
reajuste".

## 3. Regime de venda — comprovante x fiscal ("DIFAL extraoficial")

> **Aviso de conformidade:** vender sem documento fiscal é operação
> irregular perante a legislação tributária. O recurso existe a pedido do
> operador e fica desligado por padrão; a documentação registra o risco.

### Parâmetros (GE4, por empresa)

| Chave | Padrão | Efeito |
|---|---|---|
| `LOJ_REG_ATIVO` | `N` | `S` habilita a escolha de regime na venda |
| `LOJ_REG_DESCC` | `10` | % máx. de desconto para pagamento em dinheiro **sem** documento fiscal |
| `LOJ_REG_DESCF` | `3` | % máx. de desconto para pagamento em dinheiro **com** documento fiscal |

### PDV (`GEBLOJVEN`, novo parâmetro `cRegime`)

- `cRegime`: `""`/`"FISCAL"` = comportamento atual; `"COMPROVANTE"` =
  venda só com comprovante interno (sem NFC-e mesmo com `DFE_NFCE=S`).
- Teto de desconto passa a depender do regime **e** de haver pagamento em
  dinheiro: `DESCC` quando `COMPROVANTE + dinheiro`, senão `DESCF`; se os
  parâmetros estiverem vazios, mantém `LOJ_DESC_MAX` (retrocompatível).
  Acima do teto continua exigindo supervisor `LOJA/DESCONTO`.
- `GLJ3_REGIME` (coluna nova, `ALTER TABLE … ADD COLUMN IF NOT EXISTS`)
  grava `COMPROVANTE`/`FISCAL`; segunda via mostra o regime.
- Pagamentos crypto/documento inalterados; `tPag` da NFC-e usa `99` para
  formas desconhecidas (crypto mapeia para `99` — documentado).

### Faturamento (`GEBFAT`)

- `GEBFATPED` ganha `cRegime` (parâmetro final, retrocompatível) e grava
  `GFT3_REGIME`.
- Teto do desconto % do pedido segue a mesma regra de parâmetros.
- `GEBFATFAT` lê o regime do pedido: `COMPROVANTE` **não** chama
  `GEBDFENFE` (não emite NF-e) mesmo com `DFE_NFE=S`; o documento interno
  (GF3/GFT5) continua sendo gerado.

### TUI

- Formulário "Pedido de venda" ganha campo "Regime" (`{"FISCAL","COMPROVANTE"}`).
- PDV (`pdv.html`): seletor de regime junto ao pagamento, exibindo o teto
  de desconto aplicável.

## Testes

- `tests/T_GESSAR.prw` — `GESSARDEVE` (pura) + `GESSARAPLICA` em produtos
  de teste (pct geral e override).
- `tests/T_GEBCRY.prw` — wallets, URI por moeda (função pura), validações;
  cotação CoinGecko só se houver rede (assert tolerante).
- `tests/T_GEBLOJREG.prw` — venda com regime COMPROVANTE (sem NFC-e),
  tetos de desconto por regime e registro em GLJ3_REGIME.
