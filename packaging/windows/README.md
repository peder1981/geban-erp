# GEBAN ERP — Pacote Windows all-in-one

Instalador único para Windows 10/11 que leva **tudo** para a máquina
do estabelecimento: runtime AdvPP, interface web, API REST, PostgreSQL
embarcado e agendador de rotinas. Não exige administrador nem
conhecimento técnico — depois de instalar, o GEBAN abre no navegador.

## O que o instalador faz

`geban-setup.exe` instala em `%LOCALAPPDATA%\GEBAN` (por usuário):

| Componente | Origem |
|---|---|
| `advplc.exe` | build Windows do repo AdvPP (`cmd/advplc`) |
| `geban-launcher.exe` | `launcher/` — bootstrap em Go (stdlib) |
| `src/`, `public/` | fontes AdvPL do ERP |
| `pg/` | binários PostgreSQL 16 Windows (EDB, só `bin/lib/share`) |
| `periferico/` | fontes do agente PDV (ver abaixo) |

Na primeira execução, `geban-launcher.exe`:

1. roda `initdb` no PostgreSQL embarcado (senha gerada aleatoriamente);
2. cria a role/banco da aplicação;
3. sobe `advplc serve src/GEBTUI.prw` (:8081) e `advplc run
   src/GEBWEB.prw` (:8090);
4. registra a tarefa agendada "GEBAN Scheduler" (`GEBSCHJOB`, 1/min);
5. abre `http://127.0.0.1:8081` no navegador.

O primeiro boot cria a conta `super` com a senha `Geban#2026` — o
primeiro login exige a troca da senha e já cria a primeira empresa
(não há wizard separado). Para outra senha inicial, defina
`GEBAN_SUPER_SENHA` em `geban.env` antes do primeiro boot. Credenciais
do banco ficam em `geban.env` na pasta de instalação (visível só ao
usuário do Windows).

## Gerar o instalador

```bash
./build-package.sh           # monta payload e roda makensis
# saída: dist/geban-setup.exe (~38 MB)
```

Variáveis úteis: `ADVPP_SRC` (checkout do AdvPP), `PG_ZIP`/`PG_URL`
(binários PostgreSQL), `ADVPLC_WIN` (advplc.exe pronto).

## Agente de periféricos PDV (bônus, opcional)

Balança, TEF e impressora serial/USB precisam do serviço Python
`periferico/periferico_service.py`. Para ter `geban-periferico.exe`
autocontido (sem Python instalado):

```bash
# no Windows, numa pasta com Python 3.10+
cd packaging/windows/pdv && ./build-pdv-agent.sh
# gera dist/geban-periferico.exe — copie para junto do launcher
```

## Limitações conhecidas

- Emissão fiscal real exige certificado digital A1 e homologação na
  SEFAZ — configurar depois da instalação (ver manual de utilização).
- O launcher mostra uma janela de console de supervisão; logs em
  `data/*.log`.
- Antivírus podem questionar o PostgreSQL embarcado na primeira
  execução — autorizar a pasta `%LOCALAPPDATA%\GEBAN`.
