# GEBAN — Empacotamento e instalação (design)

**Data:** 2026-11-08 · **Status:** implementado (verificação de campo Windows pendente)

## Contexto

O GEBAN já roda em produção no modelo "servidor central + web"
(`advplc serve src/GEBTUI.prw` na 8081 para a UI PO-UI, `advplc run
src/GEBWEB.prw` na 8090 para a API REST, PostgreSQL multi-tenant,
`periferico_service.py` na 9100 para hardware de PDV). O pedido do
operador é oferecer **dois produtos de instalação**:

- **A — Servidor central + acesso web:** o varejista não instala nada;
  usa o navegador. O que empacotamos é o lado do servidor e o agente
  de periféricos do PDV.
- **B — Windows all-in-one:** instalador único que leva tudo para a
  máquina do varejista (runtime + Postgres embarcado + agente PDV +
  wizard de primeira execução), para quem exige operação offline.

## Fatos verificados no código/runtime

1. `advplc check` passa em **94/94** fontes de `src/`.
2. A conexão com Postgres é feita pela aplicação via classe nativa
   `DbConnection` (`GEBDBConecta()` lê `GEBAN_PG_*`), não pelo engine
   padrão da VM — logo **funciona igual em `serve`, `run` e `build`**.
3. `advplc build` gera executável standalone, mas o stub fixa
   `SQLiteEngine` como DB padrão e importa Fyne incondicionalmente:
   cross-compile Windows a partir do Linux não é trivial (Fyne exige
   cgo). **Decisão:** o pacote B usa `advplc.exe serve/run` com os
   fontes `.prw` (não `build`), que é exatamente o modelo de produção
   e ainda permite atualização de fontes sem recompilar.
4. `advplc.exe` (Windows amd64) pode ser gerado por
   `make`/`GOOS=windows` no repo AdvPP (Go puro, CGO_ENABLED=0).
5. PostgreSQL para Windows: usar os binários "binaries-only" do
   EDB/PostgreSQL (zip sem instalador), `initdb` + `pg_ctl` gerenciados
   pelo launcher. Licença permissiva, redistribuível.
6. Periféricos: `periferico_service.py` (pyserial, pyusb, websockets)
   precisa de Python no PDV. Empacotar com PyInstaller **no Windows**
   (não cross-compila do Linux); preparar spec + script e gerar o
   `.exe` em runner Windows/GitHub Actions ou máquina do operador.

## Produto A — "GEBAN Cloud/Servidor"

Componentes:

| Componente | Formato | Observação |
|---|---|---|
| Servidor | `deploy/geban-server-install.sh` (bash) | Instala advplc, src/, public/, units systemd (geban, gebweb, geban-schedule, periférico opcional), Postgres do sistema, firewall, backup timer |
| Agente PDV | `periferico/` → `geban-periferico.exe` (PyInstaller) + `install-geban-periferico.iss` | Tray app Windows; aponta para `wss://<servidor>/...` ou WS local |
| Onboarding | `docs/07-implantacao-empresa.md` + wizard web existente (GEBTUILOGIN já cria 1ª empresa no bootstrap) | Checklist: certificado A1, parâmetros fiscais, usuários |

O varejista do modelo A recebe: **um link** + opcionalmente o instalador
do agente PDV se tiver balança/TEF/impressora própria.

## Produto B — "GEBAN Caixa/Loja" (Windows all-in-one)

Instalador Inno Setup (`packaging/windows/geban.iss`) que instala em
`%ProgramFiles%\GEBAN` (ou `%LocalAppData%\GEBAN` para não exigir admin):

```
GEBAN/
  advplc.exe              # runtime Windows (build do repo AdvPP)
  src/*.prw, public/      # fontes servidos por `advplc serve`
  pg/bin, pg/lib          # PostgreSQL binaries-only (EDB zip)
  pg/data                 # initdb na 1ª execução
  periferico/geban-periferico.exe
  geban-launcher.exe      # bootstrap: sobe Postgres, advplc serve, advplc run, abre browser
  unins000.exe
```

Sequência de primeira execução (tudo automático, sem terminal):

1. `geban-launcher` verifica `pg/data`; se vazio, roda `initdb` com
   usuário/senha gerados e grava em `%ProgramData%\GEBAN\pg.env`.
2. Sobe `pg_ctl start` (ou postgres como processo filho supervisionado).
3. Exporta `GEBAN_PG_*` apontando para 127.0.0.1 e sobe:
   - `advplc.exe serve src/GEBTUI.prw --port 8081` (UI web local)
   - `advplc.exe run src/GEBWEB.prw` (API :8090)
   - `advplc.exe run src/GEBSCHJOB.prw` se o scheduler for invocável
     standalone (verificar; senão, task agendada a cada minuto).
4. Abre `http://127.0.0.1:8081` no navegador padrão.
5. O login GEBTUI já faz bootstrap da primeira empresa (verificado em
   `GEBTUILOGIN`) — wizard de empresa/filial fica a cargo da própria UI.

Serviços: registrar `geban-launcher` como tarefa do Windows
(`schtasks`, execução no logon do usuário) — sem serviço Windows para
não exigir admin na instalação por-usuário.

## Riscos e pendências

- **Certificado digital A1 / SEFAZ:** emissão fiscal real exige
  certificado por estabelecimento e homologação — fora do instalador;
  documentar no manual de implantação.
- **WSRestServer dentro de `advplc run`:** já é o modelo de produção;
  sem risco novo.
- **Scheduler:** confirmar como `GEBSCHJOB` é disparado em produção
  (timer systemd `geban-schedule.timer` → provavelmente
  `advplc run src/GEBSCHJOB.prw`). No Windows vira tarefa agendada.
- **Antivírus:** PostgreSQL embarcado + exe Go podem gerar falsos
  positivos; documentar e assinar binários quando houver certificado.
- **Tamanho:** Postgres binaries ~300MB + advplc ~70MB + fontes —
  instalador ~400-500MB, aceitável.
- **Concorrência:** `advplc serve` abre uma VM por aba — em máquina
  única de loja, OK (documentar limite de abas).

## Verificação

- A: instalar o script em VM/container Linux limpo, subir stack,
  login bootstrap, smoke test.
- B: gerar `advplc.exe` (GOOS=windows), montar pasta de staging,
  rodar Inno Setup em runner Windows (ou máquina do operador),
  instalar em Windows 10/11 limpo e percorrer o wizard.

## Resultado da implementação (2026-11-08)

- `deploy/geban-server-install.sh` + `deploy/systemd/*.service|timer`:
  instalador idempotente do servidor Linux.
- `packaging/windows/launcher/` (Go, stdlib): `geban-launcher.exe`
  gerado por cross-compile — initdb, provisionamento, subida de
  UI/API, tarefa agendada e abertura do navegador.
- `packaging/windows/geban.nsi` + `build-package.sh`: instalador
  NSIS gerado **nesta máquina** → `dist/geban-setup.exe` (~38 MB),
  instalação por usuário em `%LOCALAPPDATA%\GEBAN`.
- `src/GEBPDV_HTML.prw`: caminho do `pdv.html` portátil
  (`GEBAN_PUBLIC_DIR` → `/opt/geban/public` → `public/` → `.`).
- `packaging/windows/pdv/build-pdv-agent.sh`: build do agente PDV
  (PyInstaller) — **só roda no Windows**; `.exe` ainda não gerado.
- PostgreSQL embarcado: binários EDB 16.10 (só `bin/lib/share`, ~125 MB
  no payload).

### Pendente de validação em campo

- Instalar `geban-setup.exe` num Windows 10/11 real e percorrer o
  primeiro boot (initdb → serviços → login bootstrap).
- Gerar `geban-periferico.exe` no Windows e testar com hardware.
- Assinatura de código dos binários (falsos positivos de antivírus).
- Launcher hoje é console; se quiser janela nativa, migrar stub para
  `advplc build --gui` (exige build no Windows por causa do Fyne/cgo).
