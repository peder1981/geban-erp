# Roteiro de apresentação — ambiente demo GEBAN

Massa real semeada por `tests/local/seed_full.prw` na empresa **99**
("Empresa Demo Completa", schema `emp_99` do `geban_test`). Todos os
registros de demonstração usam o prefixo **`DEM-`** — basta filtrar por ele
em qualquer grade/consulta para achar o cenário.

## Subir o ambiente

```bash
scripts/geban-demo.sh up     # watchdog :18768 always-on; emuladores sob demanda
scripts/geban-demo.sh seed   # /ensure + espera as portas + roda seed_full.prw (idempotente)
scripts/geban-demo.sh status # saúde: units + portas
```

Interface: **http://127.0.0.1:8081** (TUI `GEBTUI`; suba com
`advplc serve src/GEBTUI.prw` se ainda não estiver no ar).
PDV web (totem/tablet): **http://127.0.0.1:8090/pdv** — login próprio (servido pelo GEBWEB; o :8081 é só a TUI).

**Login:** usuário `DEM_ADMIN`, senha `Demo#2026`, empresa **99**.
Outros perfis demo (mesma senha): `DEM_GESTOR`, `DEM_CAIXA1`, `DEM_CAIXA2`,
`DEM_FISCAL`, `DEM_FIN`, `DEM_COMPRAS`, `DEM_CTB` — cada um vê só o seu
módulo, útil para demonstrar RBAC. Conta super: `super` / `Geban#2026`.

**Emuladores (sobem sozinhos):** o login na empresa 99 chama
`GET :18768/ensure` no watchdog, que sobe SEFAZ `:18766`, Cielo `:18765`,
CNAB `:18767` e periférico `:9100` na primeira necessidade. O watchdog é
opcional para quem já subiu as units (`up --all`); o health-check
`tests/T_GEBAN_DEMO.prw` funciona nos dois modos.

Health-check ponta a ponta (read-only, não altera `emp_99`):

```bash
GEBAN_PG_HOST=localhost GEBAN_PG_PORT=5432 GEBAN_PG_DB=geban_test \
GEBAN_PG_USER=postgres GEBAN_PG_PASSWORD=postgres ADVPP_HTTP_INSECURE=1 \
advplc run tests/T_GEBAN_DEMO.prw   # → T_GEBAN_DEMO PASS
```

## Ordem sugerida das telas

### 1. Fiscal — documentos eletrônicos (o carro-chefe)

Menu **Fiscal → aba Documentos eletronicos** (ou `/api/dfe/*`):

- **40 NF-e modelo 55** autorizadas na SEFAZ emulada: `DEM-55-001` a
  `DEM-55-040` (série 99). Abra qualquer uma e gere o **DANFE**
  (`/api/dfe/danfe`) — QR code e protocolo reais do emulador.
- **3 canceladas**: `DEM-55-001`, `DEM-55-002`, `DEM-55-003` (status
  CANCELADA, evento de cancelamento na SEFAZ).
- **1 carta de correção**: `DEM-55-004` (evento CCE 135/136).
- **15 NFC-e modelo 65**: `DEM-65-001` a `DEM-65-015` — DANFE NFC-e com QR.
- **8 NF-e recebidas** do fornecedor `11444777000161` (distribuição DFe,
  manifestadas com ciência + importação) — base das entradas de compras.
- **EFD ICMS/IPI gerada**: competência **202611**, 63 documentos,
  ~17,8 KB (menu Fiscal → SPED Fiscal, ou `GET /api/dfe/efd?comp=202611`).
  O balancete confere: 210 linhas no `GDFG`.
- Emitente demo: "Mercado Demo Completo Ltda", CNPJ `11.222.333/0001-81`;
  certificado A1 autoassinado em `/tmp/geban-seed-full/cert` (só vale com
  `ADVPP_HTTP_INSECURE=1`).

### 2. Financeiro — títulos e CNAB ponta a ponta

Menu **Financeiro** (títulos) e formulários **Banco: \***:

- **120 títulos** `DEM-REC-001` a `DEM-REC-120` (R$ 120–570):
  - `DEM-REC-001`–`030`: baixados manualmente com juros/multa/desconto;
  - `DEM-REC-031`–`050`: vencidos em aberto;
  - `DEM-REC-051`–`120`: em aberto.
- **CNAB 240 ponta a ponta**: os 5 boletos `DEM-REC-031`–`035` foram
  remetidos ao banco emulado (`:18767`) e **liquidados pelo retorno**
  (status `LIQUIDADO` em `GBC2`) — mostre a remessa/retorno e a baixa
  automática nos títulos.
- Contas: `CAIXA`, `BANCO`, `CRYPTO`.

### 3. Compras — solicitações, cotações, pedidos e NF-e de fornecedor

Menu **Compras**:

- **5 solicitações** `DEM-SC-01`–`DEM-SC-05` atendidas pela menor cotação
  (geraram pedido `PC*`).
- **30 pedidos** `DEM-PED-001`–`030`: 18 `RECEBIDO` (com NF `DEM-NF-001`–
  `018`), 3 aprovados por alçada (`DEM-PED-019`–`021`), 3 pendentes de
  alçada (`022`–`024`), 6 liberados em aberto (`025`–`030`).
- De-para fiscal: fornecedor `F77000161` → produtos `DEM-P01`/`DEM-P02`.
- 15 fornecedores `DEM-F001`–`DEM-F015`, 60 produtos `DEM-P01`–`DEM-P60`,
  40 clientes `DEM-C001`–`DEM-C040`.

### 4. Contábil — balancete e DRE fechados

Menu **Contabil** (competência **202611**):

- Plano de contas `DEM-1`–`DEM-4` (14 contas) + 6 centros de custo
  `DEM-CC01`–`DEM-CC06`.
- 3 lançamentos manuais `DEM-CTB-001`–`003`; o restante veio dos módulos
  (vendas, compras, baixas, DAS).
- **Balancete**: débitos = créditos = **R$ 30.711,74** (fechado = S).
- **DRE**: receita bruta > 0 e **resultado = +R$ 1.658,50**.

### 5. Simples Nacional — apuração e DAS

Menu **Fiscal → aba Simples Nacional** (e tabelas `GSN1`–`GSN3`):

- Anexo **I**, atividade `COM` (comércio), Fator R.
- **13 competências** de folha/receita externa (GSN1); 60 produtos na
  atividade `COM` (GSN7).
- Apuração **202611**: RBT12 R$ 549.600,00, folha R$ 189.000,00,
  **fator_r = 0,343886**, alíquota efetiva 6,978166%.
- **DAS = R$ 211,59** (venc. 2026-12-21): guia `DAS-202611` na `GD1`
  (BAIXADA — pague demo via Derrama) + título `DAS-202611` na `GFN3`.
- Alerta didático: devoluções de R$ 17,80 sem receita do mesmo tipo no
  mês (não deduzidas) — ótimo para explicar o Fator R.

### 6. Loja / Frente de loja — PDV com todas as formas

Menu **Frente de loja** (PDV embutido) ou **/pdv**:

- Caixa **01** ("DEM Caixa Loja Centro"), última sessão fechada
  **`S0000011`**: **19 cupons** (18 vendidos + 1 cancelado
  "desistência no balcão").
- **Venda com NFC-e real**: o regime **FISCAL** do PDV emite NFC-e
  modelo 65 de verdade contra o emulador SEFAZ (:18766) — já provado
  com cupom `CP00000063` (venda por **código de barras** EAN-13,
  DINHEIRO, troco) e `CP00000064` (pagamento **CRYPTO/BTC** com QR
  `bitcoin:`). `DFE_NFCE=S`, série 65 = 99, CSC demo configurado e
  certificado A1 autoassinado estável em `~/.geban-demo/cert`.
- **7 formas de pagamento** em `GLJ5`: DINHEIRO, PIX, DEBITO, CREDITO
  (TEF **Cielo** no emulador `:18765`), FIADO, VALE (vale-troca) e
  **CRYPTO** (BTC/USDT — wallets `GCK1` ativas; a cotação vem do
  CoinGecko ao vivo, sem internet a forma é pulada na sessão).
- Devolução no caixa de cupom **com NFC-e** exige o consumidor
  (CPF/CNPJ + endereço) — a NF-e de devolução (finalidade 4) referencia
  a NFC-e; sem isso o caixa recusa com `devolucao_de_nfce`. O PDV web
  pede os dados na aba Devolução.
- Periféricos 100% virtuais (:9100, drivers `*_virtual` que nunca
  falham): `escpos_virtual` grava o cupom em
  `periferico/saidas/cupom-*.png`, `barcode_virtual` lê EANs demo,
  `peso_virtual` devolve peso plausível, `gaveta_virtual` registra o
  pulso e `tef_virtual` aprova transação — os 5 já vêm cadastrados em
  `GEP_PERIFERICOS` e em `periferico/config/perifericos.json`.
- Sangria R$ 400 e suprimento R$ 150 (`GLJ6`), fechamento **sem
  diferença**.
- **50 pedidos** `DEM-PV-001`–`050` liberados e faturados (notas `NS*`)
  no menu Faturamento; **7 devoluções** `GFT7` (5 de venda faturada +
  2 do caixa: dinheiro e vale-troca).
- 60 produtos com estoque de reposição `DEM-ESL-*` (500 un. cada).

### 7. Derrama — retenções e guias

Menu **Derrama** (guias `GD1`):

- 6 regras `DEM-*`: ISS 5%, IRRF 1,5%, INSS 11%, PIS 0,65%, COFINS 3%,
  CSLL 1%.
- Retenções aplicadas em 3 notas de entrada `DEM-NF-*` (`GRT2`, 7 linhas
  `LEFT(DOC,6)='DEM-NF'`) gerando guias `RET-ISS/IRRF/INSS/PIS/COFINS/
  CSLL-202611` (ABERTAS).
- Guia extra `DEM-GD-ICMS` (R$ 1.450,00, vencida) paga com juros — mostre
  `GEBDJUR`/`GEBDERPAGA`.
- Pagamentos demo: `GEBDERPAGA("DEM-GD-ICMS","BANCO")` e
  `GEBDERPAGA("DAS-202611","BANCO")` já baixaram as duas guias.

### 8. Periférico virtual — cupom impresso em PNG

- Serviço `geban-periferico` (`periferico_service.py`, WebSocket `:9100`)
  com **5 periféricos virtuais** (`escpos_virtual`, `barcode_virtual`,
  `peso_virtual`, `gaveta_virtual`, `tef_virtual`) — impressora grava
  cada cupom como imagem em **`periferico/saidas/cupom-<timestamp>.png`**.
- No **PDV web** (`/pdv`): aba **Periféricos** — liste/consulte os 5
  periféricos (`GET /api/pdv/perifericos`); ao finalizar uma venda, o
  navegador fala WS com `:9100` (`print_receipt`, `read_barcode`,
  `read_weight`, `open_cash_drawer`, `authorize_transaction`) e o PNG
  aparece em `saidas/`.
- O TUI não fala WS: a geração do PNG é **cobertura manual** (não assertada
  pelo `T_GEBAN_DEMO`, que valida o schema `GEP_PERIFERICOS`).

## Reset

```bash
scripts/geban-demo.sh reset -y   # para tudo + DROP SCHEMA emp_99 + limpa saidas/
scripts/geban-demo.sh up && scripts/geban-demo.sh seed
```

## Referência rápida — identificadores DEM

| Área | Identificador | Onde ver |
|---|---|---|
| NF-e 55 | `DEM-55-001`–`040` (37 autoriz., 3 canc.) | Fiscal → DF-e |
| NFC-e 65 | `DEM-65-001`–`015` | Fiscal → DF-e |
| CC-e | chave de `DEM-55-004` | Fiscal → DF-e (eventos) |
| Recebidas | CNPJ `11444777000161` | Fiscal → DF-e (distribuição) |
| EFD | competência `202611`, `GDFG` | Fiscal → SPED |
| Títulos | `DEM-REC-001`–`120` | Financeiro |
| Boletos CNAB | `DEM-REC-031`–`035` LIQUIDADO | Financeiro → Banco |
| SC / pedidos | `DEM-SC-01`–`05`, `DEM-PED-001`–`030` | Compras |
| Entradas | `DEM-NF-001`–`018` | Compras → NF-e fornecedor |
| Contábil | `DEM-CTB-001`–`003`, balancete `202611` | Contabil |
| Simples | `GSN2` comp `202611`, DAS R$ 211,59, fator_r 0,343886 | Fiscal → Simples |
| Loja | sessão `S0000011` (19 cupons), `DEM-PV-001`–`050` | Frente de loja / Faturamento |
| Derrama | `DEM-*-202611`, `DEM-GD-ICMS` | Derrama |
| Periférico | `cupom-*.png` em `periferico/saidas/` | PDV web → Periféricos |
