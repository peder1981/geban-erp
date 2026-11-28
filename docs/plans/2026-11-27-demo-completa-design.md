# GEBAN — Ambiente de demonstração completo na empresa 99 (design)

**Data:** 2026-11-27 · **Status:** design validado, implementação pendente

## Contexto

Apresentação de todos os módulos do GEBAN na empresa 99 (TESTE, `emp_99`),
com ciclo fiscal completo e volume realista, legislação nacional e
obrigações acessórias (EFD ICMS/IPI, apuração ICMS, DAS do Simples,
balancete e DRE), conectividade de periféricos emulada (impressora
fiscal/térmica para NFC-e, TEF) — tudo subindo com um comando só.

Decisões tomadas na sessão de brainstorming (operador):

- Emuladores: banco/CNAB e impressora fiscal emulada são **novos**;
  SEFAZ e Cielo já existem e bastam. NFS-e municipal fora do escopo.
- Massa de dados: **ciclo completo + volume** — EFD/DRE/DAS gerados a
  partir dos dados reais do seed, e telas com volume de demo.
- Orquestração: **entry point único** `geban-demo` (up/down/reset/status),
  tudo-ou-nada com health-check por etapa.

## O que já existe (verificado)

- `tests/emuladores/sefaz_emulador.py` :18766 — HTTPS, NF-e/NFC-e/NFS-e
  nacional completos (enviNFe, consStatServ, eventos, inutilização,
  distDFeInt, NFS-e REST).
- `tests/emuladores/cielo_emulador.py` :18765 — TEF e-Commerce Cielo.
- `periferico/periferico_service.py` :9100 — WebSocket + drivers plug-and-play
  (ESC/POS USB/rede, TEF TCP/REST, leitor código de barras, balança serial,
  gaveta USB). PDV web (`public/pdv.html`) já usa `/perifericos` e
  `print_receipt`.
- `tests/local/seed_demo.prw` — seed mínimo da `emp_99` (produtos, preços,
  caixa, crypto, parâmetros), idempotente via `WHERE NOT EXISTS`.
- `tests/T_*_MASSA.prw` — geram massa por módulo mas **limpam ao final**;
  servem de referência das rotinas públicas, não são reaproveitáveis
  diretamente.
- `deploy/systemd/` e `scripts/geban-periferico.service` — base para units,
  caso o ambiente vire persistente.

## Arquitetura

```
geban-demo up        (scripts/geban-demo.sh — entry point único)
 ├─ emuladores (tests/emuladores/)
 │   ├─ sefaz_emulador.py     :18766  HTTPS  [existe]
 │   ├─ cielo_emulador.py     :18765  HTTP   [existe]
 │   └─ banco_emulador.py     :18767  HTTP   [novo]
 ├─ periferico_service.py     :9100   WebSocket
 │   └─ + driver EscPosVirtual (ESC/POS → cupom PNG/texto em disco)
 ├─ seed: advplc run tests/local/seed_full.prw   (emp_99, idempotente)
 └─ advplc serve src/GEBTUI.prw                  (TUI + PDV web)
```

Ordem do `up`: emuladores → periféricos → seed (autoriza notas na SEFAZ
emulada) → `advplc serve`. Cada etapa tem health-check com timeout; falha
em qualquer peça derruba o `up` inteiro. Logs em
`~/.local/state/geban-demo/`. `reset` dropa e recria `emp_99`, para
processos e limpa `saidas/` — confirmação interativa obrigatória.

## Banco emulador (`tests/emuladores/banco_emulador.py`, stdlib puro)

- `POST /cnab/remessa` — recebe CNAB240, valida header/trailer e nosso
  número, registra boletos.
- `GET /cnab/retorno` — devolve retorno CNAB240 com liquidações (T+1
  simulado: liquida vencidos, rejeita instrução inválida, ocorrência `02`).
- `GET /boleto/{nn}` — JSON do boleto (linha digitável, código de barras
  falso bem-formado).
- ERP aponta para `http://127.0.0.1:18767` via parâmetro `FIN_BANCO_URL`
  semeado pelo seed.

## Impressora emulada (`EscPosVirtual` em `periferico_service.py`)

Recebe o byte-stream ESC/POS pelo mesmo WebSocket :9100 do `EscPosNetwork`,
decodifica comandos (init, alinhamento, negrito, corte, QR) e renderiza o
cupom NFC-e em PNG (Pillow) + texto plano em
`periferico/saidas/cupom-<ts>.png`. Registrado no `DriverRegistry`;
`periferico/config/perifericos.json` da demo aponta a impressora padrão
para ele. Drivers físicos continuam disponíveis, mas não são pré-requisito.

Simplificação intencional: ignora comandos exóticos (bitmap download, code
page). Upgrade path: biblioteca de emulação ESC/POS dedicada.

## Massa de dados (`tests/local/seed_full.prw`, idempotente, prefixo `DEM`)

| Módulo | Volume | Ciclo completo |
|---|---|---|
| Núcleo | 3 filiais, 8 usuários, perfis variados | agendamento com histórico |
| Fiscal | ~60 produtos, 20 NCMs com IBS/CBS | 40 NF-e emitidas + 3 canceladas + 1 CC-e, 15 NFC-e, 8 NF-e fornecedor → EFD C100/C190/H010 real + apuração ICMS |
| Simples | — | receitas mensais → apuração + DAS, Fator R |
| Financeiro | 120 títulos (30 pagos c/ juros/desconto, 20 vencidos, 70 abertos) | remessa CNAB240 → retorno emulado baixa títulos |
| Contábil | plano completo, centros de custo | lançamentos integrados a vendas/compras → balancete e DRE |
| Estoque/Compras | 15 fornecedores, 30 pedidos | cotação → pedido → recebimento c/ NF-e → kardex e custo médio consistentes |
| Faturamento/Loja | 40 clientes, 50 pedidos, 5 devoluções | caixa c/ sangria/reforço; dinheiro, TEF, PIX, fiado, crypto |
| Derrama | — | tributos gerando títulos com retenções |

Consistência cruzada: as notas do fiscal alimentam estoque, contábil e
financeiro — a EFD é calculada dos mesmos registros que movem kardex e
razão. Seed é retomável: se a SEFAZ emulada cair no meio, reporta quantas
notas faltaram e reroda sem duplicar.

## Roteiro de demo

`geban-demo up` termina imprimindo o roteiro (também em
`docs/demo-roteiro.md`): login → dashboards → fiscal → NFC-e ao vivo no
PDV com cupom PNG aparecendo → TEF → CNAB → EFD/DRE/DAS gerados — com os
identificadores-chave (`DEM*`) para localizar cada registro.

## Arquivos

Novos:
- `scripts/geban-demo.sh`
- `tests/emuladores/banco_emulador.py`
- `tests/local/seed_full.prw`
- `periferico/config/perifericos.json`
- `periferico/saidas/` (gitignored, `.gitkeep`)
- `docs/demo-roteiro.md`

Alterados:
- `periferico/periferico_service.py` — driver `EscPosVirtual`
- `README.md` — seção "Ambiente de demonstração"
- `tests/run-all.sh` — nota sobre o emulador de banco

## Verificação

Novo `tests/T_GEBAN_DEMO.prw`: health-check ponta a ponta — SEFAZ emulada
autoriza NF-e de teste, banco emulado liquida um título, periférico
virtual gera cupom PNG. O `geban-demo up` roda esse teste antes de
declarar o ambiente pronto.

## Riscos

- Seed depende da SEFAZ emulada para autorizar ~55 documentos: mitigado
  pela idempotência e reporte de faltantes.
- Volume escolhido mantém o seed em minutos, não horas.
