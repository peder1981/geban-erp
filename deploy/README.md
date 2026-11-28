# Instalação do GEBAN — Servidor (modelo central + web)

Leva o GEBAN ERP para um servidor Linux (Debian/Ubuntu) com PostgreSQL.
O varejista final não instala nada: acessa pelo navegador.

## Pré-requisitos

- Debian/Ubuntu com `postgresql` instalado e rodando
- Binário `advplc` (>= 4.6.1) — compilado do repo AdvPP
- A raiz deste repositório (com `src/` e `public/`)

## Instalar

```bash
sudo ./geban-server-install.sh \
    --src /caminho/geban-erp \
    --advplc /caminho/advplc \
    --db-name geban --db-user geban_app --db-password 'senha-forte' \
    --db-superuser 'postgres:senha-do-postgres'
```

O script é idempotente. Ele:

1. Cria o usuário `geban` e `/opt/geban`, `/etc/geban`;
2. Copia `src/` e `public/` para `/opt/geban` e instala o `advplc`;
3. Grava `/etc/geban/geban.env` com `GEBAN_PG_*`;
4. Cria a role e o banco no Postgres (com `--db-superuser`);
5. Instala e sobe os serviços systemd:
   - `geban` — interface web em `http://<servidor>:8081`
   - `geban-web` — API REST em `:8090`
   - `geban-scheduler.timer` — rotinas agendadas a cada minuto
   - `geban-periferico` — agente de periféricos PDV (opcional,
     `--skip-periferico` desativa);
6. Verifica HTTP 200 em 8081 e `/api/health` em 8090.

## Depois de instalar

1. Abra `http://<servidor>:8081` — no primeiro boot o sistema cria a
   conta `super` com a senha `Geban#2026` (ou `GEBAN_SUPER_SENHA`, se
   definida antes do primeiro boot). O primeiro login exige a troca da
   senha e já cria a primeira empresa no bootstrap.
2. Cadastre filial, usuários e permissões em **Núcleo**.
3. Configure certificado digital A1 e parâmetros fiscais para emissão
   real de documentos (ver `docs/04-manual-utilizacao.md`).
4. Se houver Cloudflare Tunnel/reverse proxy na frente, aponte
   `/api/*` **e `/pdv`** para `:8090` e o resto para `:8081` — a mesma
   origem é o que permite ao menu **Frente de loja** do TUI abrir o PDV
   web via `FWOPENTAB` (token da sessão em `#tok=`, sem segundo login;
   requer AdvPP 4.11.0+). Sem proxy na frente, o PDV segue acessível em
   `http://<servidor>:8090/pdv` com login próprio.

## Operação

```bash
systemctl status geban geban-web geban-scheduler.timer
journalctl -u geban -u geban-web -f
systemctl restart geban geban-web        # após atualizar src/
```

Para atualizar o código: copie os novos `src/`/`public/` para
`/opt/geban` (ou rode o instalador de novo) e reinicie `geban` e
`geban-web`.
