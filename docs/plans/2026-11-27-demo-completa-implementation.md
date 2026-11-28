# Ambiente de demonstração completo (empresa 99) — Plano de implementação

> **For the executor:** implementar task por task, commits atômicos ao final de cada task. Design aprovado: `docs/plans/2026-11-27-demo-completa-design.md`.

**Goal:** um comando `geban-demo up` que sobe emuladores (SEFAZ, Cielo, banco/CNAB), serviço de periféricos com impressora fiscal emulada, seed idempotente completo da `emp_99` e o `advplc serve`, pronto para apresentação de todos os módulos.

**Architecture:** três emuladores Python stdlib + `periferico_service.py` com novo driver `EscPosVirtual` + seed AdvPL que chama as rotinas públicas já existentes com dados persistentes prefixados `DEM` + script bash de orquestração com health-checks.

**Tech Stack:** AdvPL (`advplc run`/`serve`), Python 3 stdlib (asyncio, websockets, pyserial, pyusb, Pillow), PostgreSQL multi-tenant (`emp_99`), bash.

**Restrição do operador:** NADA que exija modificar o repo AdvPP — PR #44 lá está pendente de merge. Todo o trabalho fica em geban-erp.

**Convenções do repo (verificadas):**
- Emuladores: `tests/emuladores/*.py`, stdlib puro, docstring de uso no topo, porta padrão como argv[1].
- Seed: `tests/local/seed_demo.prw` — `User Function SEED_DEMO()`, `GEBDBConecta()`, `TCSqlExec("SET search_path TO emp_99, public")`, idempotente via `WHERE NOT EXISTS`, veredito final `ConOut("SEED_DEMO PASS|FAIL")`.
- Rotinas públicas mapeadas em `src/GEBBO.prw` (route table → `aRes := GEBXXX(...)`). Testes de massa por módulo: `tests/T_*_MASSA.prw` (fazem cleanup — usar como referência de chamadas, NÃO executá-los do seed).
- Compilação/execução de testes: `advplc run tests/xxx.prw`; suite: `tests/run-all.sh`.

---

## Task 1: Emulador de banco (CNAB240 + boletos)

**Files:**
- Create: `tests/emuladores/banco_emulador.py`

**Contexto:** o ERP gera a remessa via `GEBBCOREM(conta, "")` (rota `banco/remessa`) e baixa o retorno via `GEBBCORET(conta, conteudo)` (rota `banco/retorno`, conteúdo do arquivo no body). O emulador recebe a remessa, guarda os boletos e devolve retorno com liquidações.

**Step 1 — criar o emulador.** Um arquivo, `http.server` + threading, padrão dos irmãos:

```
POST /cnab/remessa   body: arquivo CNAB240 → valida header (0)/trailer (9),
                     extrai registros segmento P (nosso número + valor),
                     registra boletos; responde {"ok":true,"boletos":N}
GET  /cnab/retorno   gera arquivo CNAB240 de retorno: liquida todos os
                     boletos com vencimento <= hoje (ocorrência 06),
                     rejeita instruções inválidas (ocorrência 02)
GET  /boleto/{nn}    {"linha_digitavel":"...","codigo_barras":"44...",
                     "valor":..., "vencimento":"AAAAMMDD","status":...}
GET  /health         {"ok":true,"boletos":N}
```

Regras de parse CNAB240 mínimas: header de lote = tipo registro `1`; segmento P posições: nosso número cols 38–57, vencimento cols 78–85 (DDMMAAAA), valor cols 86–100 (13 int + 2 dec). Na geração do retorno, reutilizar o layout do arquivo de remessa recebido trocando tipo de serviço/ocorrência. Docstring no topo documentando os endpoints e o simplification ceiling (layout simplificado: só segmento P; upgrade path = segmento Q/T/U completos).

**Step 2 — self-check ao final do arquivo** (`if __name__ == "__main__" and "--selfcheck" in argv` via arg simples): sobe em thread na porta efêmera, POSTa uma remessa sintética de 240-col com 2 boletos, GET retorno, asserta 2 liquidações. Menor verificação que quebra se o parse quebrar.

**Step 3 — rodar:** `python3 tests/emuladores/banco_emulador.py --selfcheck` → PASS.

**Step 4 — commit:** `emuladores: banco_emulador CNAB240 (remessa, retorno, boleto)`.

---

## Task 2: Driver `EscPosVirtual` no serviço de periféricos

**Files:**
- Modify: `periferico/periferico_service.py` (nova classe + registro em `_register_builtins`)
- Create: `periferico/config/perifericos.json`
- Create: `periferico/saidas/.gitkeep` (+ entrada no `.gitignore`)

**Step 1 — classe `EscPosVirtual(PerifericoDriver)`** após `EscPosNetwork` (por volta da linha 212–255):

```python
class EscPosVirtual(PerifericoDriver):
    """Impressora térmica emulada: renderiza ESC/POS em PNG + texto.

    Config: {"out_dir": "periferico/saidas", "colunas": 48}
    ponytail: parser ESC/POS simplificado — texto, alinhamento, negrito,
    QR (renderizado como caixa + payload), corte. Ignora bitmaps/codepage.
    Upgrade: biblioteca de emulação ESC/POS dedicada.
    """
    name = "escpos_virtual"
    tipo = "IMPRESSORA"
```

- `connect()`: cria `out_dir`, `self.connected = True`, retorna True (nunca falha — é virtual).
- `print_receipt(data: bytes)`: decodifica o stream:
  - `ESC @` reset; `ESC a n` alinhamento; `ESC E n` negrito; `GS V` / `ESC i` corte (fecha cupom atual); `GS ( k` QR → grava marcador `[QR: payload]`; `LF`/`CR` quebras; resto = texto (decode cp850 com fallback latin-1).
  - Salva `cupom-<timestamp>.txt` sempre; se Pillow disponível (`try import PIL`), renderiza PNG 48 col × altura proporcional com fonte monoespaçada; sem Pillow, só o .txt (degradado, não falha).
  - Responde True.
- `open_cash_drawer()` também retorna True (gaveta virtual é no-op).
- Registrar `"escpos_virtual"` na lista `builtins` de `_register_builtins`.

**Step 2 — `periferico/config/perifericos.json`:** config demo carregada no `--config`, registrando a impressora virtual como padrão (ver seção de carregamento de config no `main()`, linhas ~800+): `{"perifericos": [{"tipo": "IMPRESSORA", "driver": "escpos_virtual", "nome": "Cupom Demo", "config": {"out_dir": "saidas"}}]}` — ajustar à estrutura exata que `main()` espera (ler o código de load antes).

**Step 3 — self-check:** script de verificação mínimo `tests/local/T_PERIF_VIRTUAL.py`? Não — ponytail: um bloco `python3 -c` que importa o módulo, instancia `EscPosVirtual({...})`, `await print_receipt(ESC/POS bytes)`, asserta arquivo .txt gerado em tmp dir. Rodar inline, não persistir arquivo de teste.

**Step 4 — commit:** `periferico: driver EscPosVirtual — cupom NFC-e em PNG/texto sem hardware`.

---

## Task 3: `seed_full.prw` — esqueleto + núcleo + cadastros

**Files:**
- Create: `tests/local/seed_full.prw`

**Estrutura** (includes = a união dos includes de `seed_demo.prw` + os `_MIG` de cada módulo):

```advpl
User Function SEED_FULL()
    Local lOk := .T.
    If !GEBDBConecta()
        ConOut("SEED_FULL FAIL (GEBDBConecta)")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO emp_99, public")
    // migrações (todas, na ordem do seed_demo + GEBDER/GEBCOM/GEBPERIF)
    // parâmetros: FIN_BANCO_URL, DFE_* apontando 127.0.0.1:18766,
    //             TEF apontando 127.0.0.1:18765
    // filiais, usuários, produtos, clientes, fornecedores
    ConOut("SEED_FULL " + IIf(lOk, "PASS", "FAIL"))
Return lOk
```

Sub-rotinas `Static Function` por módulo (mesmo arquivo, estilo do repo). Prefixo `DEM` em chaves (`DEM-C001`, pedido `DEM00001`). Verificar em `seed_demo.prw` + `T_GeExp_MASSA.prw`/`T_GENUC_MNT.prw` as assinaturas exatas de criação de filial/usuário antes de escrever.

**Escopo desta task:** 3 filiais, 8 usuários com vínculos/perfis variados (`GEBSECCRIAUSU` + `GEBSECRBAC`), 60 produtos (`GF1`/`GF2` + `GEBFATPRC`), 40 clientes (`GEBFATCLI`), 15 fornecedores (assinatura em `T_GEBCOM_MASSA.prw`), plano de contas + centros de custo (`GEBCTXCC` + cadastro de contas — ver `T_GEBCTB_MASSA.prw`).

**Step:** `advplc run tests/local/seed_full.prw` → `SEED_FULL PASS`; rodar 2× seguidas → PASS nas duas (idempotência).

**Commit:** `seed: seed_full base — nucleo, cadastros, plano de contas`.

---

## Task 4: seed — fiscal ciclo completo

No `seed_full.prw`: ~40 NF-e (`GEBDFEEMIT` → `GEBDFETRANSMITE` contra SEFAZ :18766 — assinaturas em `T_GEBDFE_NFE.prw`/`T_GEBFIS_MASSA.prw`), 3 canceladas (`GEBDFECANCELA`), 1 CC-e (`GEBDFECCE`), 15 NFC-e, 8 NF-e de fornecedor (`GEBDFEDISTBUSCA`/`GEBDFEMANIF`/`GEBDFEIMPORTA` — o emulador já semeia notas do CNPJ 11444777000161), depois `GEBDFEEFD` para provar que gera. Reportar no log quantas notas autorizadas vs. esperadas.

**Step:** `advplc run` → PASS; conferir no log "NF-e: 40 autorizadas". **Commit:** `seed: ciclo fiscal — NF-e/NFC-e, cancelamentos, EFD`.

---

## Task 5: seed — financeiro + CNAB + estoque/compras

- 120 títulos (`GEBFXTIT`): 30 baixados c/ juros/desconto (`GEBFXBAI`), 20 vencidos (emissão retroativa), 70 abertos.
- `GEBBCOCFG` carteira demo → `GEBBCOBOL` boletos → `GEBBCOREM` remessa → POST no `banco_emulador` :18767 → `GEBBCORET` com o retorno recebido → baixa automática.
- Compras: `GEBCPXSC` → `GEBCPXPED` → `GEBCPXENT`/`GEBCPXGERA` com NF-e do fiscal → `GEBESTMOV`/kardex consistente. Assinaturas em `T_GEBCOM_MASSA.prw`.

**Step:** run → PASS. **Commit:** `seed: financeiro CNAB ponta a ponta + compras/estoque`.

---

## Task 6: seed — contábil, Simples, loja, Derrama

- Lançamentos contábeis integrados (ver `T_GEBCTB_MASSA.prw`/`T_GEBCTB_CTB.prw` para a rotina de lançamento padrão) → `GEBCTXBALAN`/`GEBCTXDRE` prováveis.
- Simples: receitas mensais → apuração + DAS (`T_GEBSN.prw` tem as rotinas).
- Loja: caixa `GEBLOJCX`/`GEBLOJABRE` + sangria/reforço (`GEBLOJSAN`), 50 pedidos `GEBFATPED` → `GEBFATFAT`, 5 devoluções `GEBFATDEV`, vendas multi-forma (`GEBLOJVEN` — dinheiro/TEF/PIX/fiado/crypto), TEF via `GEBTEFCFG`→Cielo :18765.
- Derrama: `GEBDER*` — tributos gerando títulos (`T_GEBDER_MASSA.prw`).

**Step:** run → PASS. **Commit:** `seed: contabil, simples, loja, derrama — seed_full completo`.

---

## Task 7: `scripts/geban-demo.sh`

**Files:** Create `scripts/geban-demo.sh`, Modify `README.md`, `tests/run-all.sh` (nota no cabeçalho sobre :18767).

```bash
geban-demo up      # sobe :18766 :18765 :18767 → periferico :9100
                   #   (--config periferico/config/perifericos.json)
                   #   → advplc run tests/local/seed_full.prw
                   #   → advplc run tests/T_GEBAN_DEMO.prw (health)
                   #   → advplc serve src/GEBTUI.prw (foreground)
geban-demo down    # mata por pidfile em ~/.local/state/geban-demo/
geban-demo reset   # down + recria emp_99 (DROP SCHEMA CASCADE +
                   #   re-run das migrações via seed) + limpa saidas/;
                   #   confirmação interativa
geban-demo status  # health-check das portas
```

Health-check por etapa: `curl -fsS http://127.0.0.1:PORT/health` (adicionar `/health` nos emuladores se ausente — checar) e `timeout` no bind; qualquer falha → `down` + exit 1. Logs `~/.local/state/geban-demo/*.log`. Termina imprimindo o roteiro (Task 8).

**Step:** `geban-demo up` de verdade → `status` verde → vender no PDV → cupom PNG em `periferico/saidas/` → `down` limpo.

**Commit:** `demo: geban-demo up/down/reset — ambiente completo num comando`.

---

## Task 8: Roteiro + health-check de demo

**Files:** Create `docs/demo-roteiro.md`, `tests/T_GEBAN_DEMO.prw`; Modify `README.md`.

- `T_GEBAN_DEMO.prw` (padrão `T_*`: `ConOut("T_GEBAN_DEMO PASS|FAIL")`): autoriza 1 NF-e na SEFAZ emulada, baixa 1 título via retorno do banco emulado, asserta cupom gerado. Roda no `up` como gate final e fica na suite `run-all.sh`.
- `demo-roteiro.md`: sequência de telas com identificadores `DEM*` para achar cada registro (login `super`, pedidos `DEM00001`+, nota autorizada, EFD/DRE/DAS gerados).
- README: seção "Ambiente de demonstração" — `scripts/geban-demo.sh up`.

**Commit:** `docs: roteiro de apresentacao + health-check T_GEBAN_DEMO`.

---

## Verificação final

`tests/run-all.sh` completo no `geban_test`; `geban-demo up` → demo roteada de ponta a ponta; `reset` → `up` de novo → idempotente.

## Riscos conhecidos

- CNAB240: `GEBBCOREM`/`GEBBCORET` podem ter layout próprio — **ler `src/GEBBO*.prw`/`GEBBOLIB.prw` antes de escrever o parse do emulador**; o emulador deve casar com o formato real que o ERP emite/espera, não com o CNAB240 genérico.
- Seed fiscal depende de `advplc` conseguir alcançar 127.0.0.1:18766 — mesmo pré-requisito dos testes `T_GEBDFE*` existentes.
