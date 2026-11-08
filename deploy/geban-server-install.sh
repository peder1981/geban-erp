#!/usr/bin/env bash
# Instalador do GEBAN ERP — modelo "servidor central + acesso web".
#
# Uso (como root, numa máquina Debian/Ubuntu limpa com PostgreSQL):
#   sudo ./geban-server-install.sh --src /caminho/geban-erp \
#        --advplc /caminho/advplc --db-name geban \
#        --db-user geban_app --db-password 'senha-forte'
#
# O que faz:
#   1. cria o usuário de sistema `geban` e os diretórios /opt/geban e /etc/geban
#   2. instala fontes (src/, public/) e o binário advplc
#   3. grava /etc/geban/geban.env com GEBAN_PG_* (PostgreSQL local)
#   4. cria role/banco no Postgres (se --db-superuser for informado)
#   5. instala e habilita os units systemd (geban, geban-web,
#      geban-scheduler.timer)
#   6. confere: serviços ativos, 8081 = 200, 8090 /api/health = 200
#
# Idempotente: pode rodar de novo; não apaga dados existentes.
set -euo pipefail

SRC=""; ADVPLC=""; DB_NAME=geban; DB_USER=geban_app; DB_PASS=""; DB_HOST=127.0.0.1; DB_PORT=5432
SUPERUSER=""; SKIP_PERIFERICO=0

while [ $# -gt 0 ]; do
    case "$1" in
        --src) SRC="$2"; shift 2 ;;
        --advplc) ADVPLC="$2"; shift 2 ;;
        --db-name) DB_NAME="$2"; shift 2 ;;
        --db-user) DB_USER="$2"; shift 2 ;;
        --db-password) DB_PASS="$2"; shift 2 ;;
        --db-host) DB_HOST="$2"; shift 2 ;;
        --db-port) DB_PORT="$2"; shift 2 ;;
        --db-superuser) SUPERUSER="$2"; shift 2 ;;   # "user:pass" com CREATEDB/CREATEROLE
        --skip-periferico) SKIP_PERIFERICO=1; shift ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) echo "opção desconhecida: $1" >&2; exit 1 ;;
    esac
done

[ "$(id -u)" = "0" ] || { echo "rode como root (sudo)" >&2; exit 1; }
[ -n "$SRC" ] && [ -d "$SRC/src" ] || { echo "--src deve apontar para a raiz do geban-erp (com src/)" >&2; exit 1; }
[ -n "$DB_PASS" ] || { echo "--db-password é obrigatório" >&2; exit 1; }

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)

echo "== 1/6 usuário e diretórios"
id -u geban >/dev/null 2>&1 || useradd --system --home /opt/geban --shell /usr/sbin/nologin geban
install -d -o geban -g geban /opt/geban /var/lib/geban
install -d -m 750 /etc/geban

echo "== 2/6 fontes e binário"
rsync -a --delete "$SRC/src/" /opt/geban/src/
rsync -a --delete "$SRC/public/" /opt/geban/public/
if [ -n "$ADVPLC" ]; then
    install -m 755 "$ADVPLC" /usr/local/bin/advplc
elif ! command -v advplc >/dev/null; then
    echo "advplc não encontrado; informe --advplc /caminho/advplc" >&2; exit 1
fi
# fontes precisam ser legíveis pelo usuário geban
chown -R geban:geban /opt/geban

echo "== 3/6 ambiente (/etc/geban/geban.env)"
cat > /etc/geban/geban.env <<EOF
GEBAN_PG_HOST=$DB_HOST
GEBAN_PG_PORT=$DB_PORT
GEBAN_PG_DB=$DB_NAME
GEBAN_PG_USER=$DB_USER
GEBAN_PG_PASSWORD=$DB_PASS
EOF
chmod 640 /etc/geban/geban.env; chown root:geban /etc/geban/geban.env

echo "== 4/6 banco de dados"
if [ -n "$SUPERUSER" ]; then
    SU=${SUPERUSER%%:*}; SUPASS=${SUPERUSER#*:}
    export PGPASSWORD="$SUPASS"
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$SU" -d postgres -v ON_ERROR_STOP=1 <<SQL
DO \$\$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '$DB_USER') THEN
    CREATE ROLE "$DB_USER" LOGIN PASSWORD '$DB_PASS';
  ELSE
    ALTER ROLE "$DB_USER" LOGIN PASSWORD '$DB_PASS';
  END IF;
END \$\$;
SQL
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$SU" -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$DB_NAME'" | grep -q 1 \
        || psql -h "$DB_HOST" -p "$DB_PORT" -U "$SU" -d postgres -c "CREATE DATABASE \"$DB_NAME\" OWNER \"$DB_USER\""
    psql -h "$DB_HOST" -p "$DB_PORT" -U "$SU" -d "$DB_NAME" -c "GRANT ALL ON SCHEMA public TO \"$DB_USER\";"
    unset PGPASSWORD
else
    echo "  (sem --db-superuser: crie role '$DB_USER' e banco '$DB_NAME' manualmente)"
fi

echo "== 5/6 systemd"
install -m 644 "$SCRIPT_DIR/systemd/geban.service" /etc/systemd/system/geban.service
install -m 644 "$SCRIPT_DIR/systemd/geban-web.service" /etc/systemd/system/geban-web.service
install -m 644 "$SCRIPT_DIR/systemd/geban-scheduler.service" /etc/systemd/system/geban-scheduler.service
install -m 644 "$SCRIPT_DIR/systemd/geban-scheduler.timer" /etc/systemd/system/geban-scheduler.timer
systemctl daemon-reload
systemctl enable --now geban geban-web geban-scheduler.timer

if [ "$SKIP_PERIFERICO" = "0" ] && [ -f "$SRC/periferico/periferico_service.py" ]; then
    echo "== 5b/6 periférico PDV (opcional)"
    install -d -o geban -g geban /opt/geban/periferico
    rsync -a "$SRC/periferico/" /opt/geban/periferico/
    chown -R geban:geban /opt/geban/periferico
    command -v python3 >/dev/null && {
        pip3 install -q -r /opt/geban/periferico/requirements.txt || true
        install -m 644 "$SCRIPT_DIR/systemd/geban-periferico.service" /etc/systemd/system/geban-periferico.service 2>/dev/null || true
        systemctl daemon-reload
        systemctl enable --now geban-periferico 2>/dev/null || echo "  periférico instalado mas não iniciado (confira requirements/drivers)"
    } || echo "  python3 ausente — periférico não instalado"
fi

echo "== 6/6 verificação"
ok=1
for i in $(seq 1 12); do
    sleep 5
    if systemctl is-active --quiet geban geban-web \
       && [ "$(curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8081/)" = "200" ] \
       && curl -sf http://127.0.0.1:8090/api/health >/dev/null; then ok=0; break; fi
done
if [ "$ok" = "0" ]; then
    echo "INSTALADO: UI em http://$(hostname -I | awk '{print $1}'):8081  API :8090"
    echo "Logs: journalctl -u geban -u geban-web -f"
else
    echo "INSTALADO COM PENDÊNCIAS — serviços não responderam; veja journalctl -u geban -u geban-web" >&2
    exit 2
fi
