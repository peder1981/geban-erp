#!/usr/bin/env bash
# Entrada única do ambiente local de demonstração (nunca usar em produção).
#
# Wrapper fino sobre units systemd --user (sempre online, Restart=always):
#   geban-emu-sefaz.service    emulador SEFAZ HTTPS :18766 (SEFAZ_SEED_NOTAS=9)
#   geban-emu-cielo.service    emulador Cielo       :18765
#   geban-emu-banco.service    emulador CNAB        :18767
#   geban-periferico.service   periferico WS        :9100
#
# Uso: scripts/geban-demo.sh {up|down|reset|status|seed} [reset: -y|--yes]
#   up     instala/atualiza as units em ~/.config/systemd/user e dá
#          enable --now (idempotente). As units ficam enabled: voltam
#          sozinhas no próximo login/boot (Linger=yes mantém sem login).
#   down   systemctl --user stop — para os serviços mas MANTÉM enabled.
#          Não toca em processos estranhos que ocupem as portas; o status
#          reporta o conflito honestamente (a unit falha ao dar bind).
#   reset  down + DROP SCHEMA emp_99 CASCADE + rm periferico/saidas/cupom-*.
#          Pede confirmação ("SIM") salvo -y/--yes. Depois rode `up` + `seed`.
#   status tabela de saúde: estado das units + portas.
#   seed   roda tests/local/seed_full.prw uma vez (idempotente) — manual,
#          para ambiente novo ou após `reset`.
#
# A interface web (advplc serve GEBTUI :8081) NÃO é gerenciada aqui: o serve
# principal do ERP já roda em dev; suba a TUI por conta própria se precisar.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/geban-demo
UNIT_SRC=$ROOT/deploy/systemd-user
UNIT_DST=${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user
PYTHON=${GEBAN_DEMO_PYTHON:-python3}
UNITS=(geban-emu-sefaz geban-emu-cielo geban-emu-banco geban-periferico)
export GEBAN_PG_HOST=${GEBAN_PG_HOST:-localhost}
export GEBAN_PG_PORT=${GEBAN_PG_PORT:-5432}
export GEBAN_PG_DB=${GEBAN_PG_DB:-geban_test}
export GEBAN_PG_USER=${GEBAN_PG_USER:-postgres}
export GEBAN_PG_PASSWORD=${GEBAN_PG_PASSWORD:-postgres}
export ADVPP_HTTP_INSECURE=1
cd "$ROOT"

say() { printf '%s\n' "$*"; }
die() { say "ERRO: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "Comando necessário: $1"; }
tcp() { "$PYTHON" -c 'import socket,sys; s=socket.create_connection(("127.0.0.1",int(sys.argv[1])),1); s.close()' "$1" 2>/dev/null; }
healthy() {
    case "$1" in
        sefaz) [[ $(curl -ksS --max-time 2 -o /dev/null -w '%{http_code}' https://127.0.0.1:18766/ 2>/dev/null) == 404 ]] ;;
        banco) curl -fsS --max-time 2 http://127.0.0.1:18767/health >/dev/null 2>&1 ;;
        *) tcp "$2" ;;
    esac
}
unit_state() { systemctl --user is-active "$1.service" 2>/dev/null || true; }

install_units() {
    need systemctl
    systemctl --user >/dev/null 2>&1 ||
        die 'systemd --user indisponível (sem sessão/lingering?). Rode num terminal de login.'
    mkdir -p "$UNIT_DST"
    local u
    for u in "${UNITS[@]}"; do
        sed -e "s|__GEBAN_ROOT__|$ROOT|g" -e "s|__GEBAN_PYTHON__|$PYTHON|g" \
            "$UNIT_SRC/$u.service" > "$UNIT_DST/$u.service"
    done
    systemctl --user daemon-reload
    for u in "${UNITS[@]}"; do
        systemctl --user enable --now "$u.service" >/dev/null 2>&1 ||
            systemctl --user enable --now "$u.service"
    done
}

up() {
    need "$PYTHON"; need curl
    "$PYTHON" -c 'import websockets' 2>/dev/null ||
        die "websockets ausente em $PYTHON. Prepare um venv com periferico/requirements.txt e use GEBAN_DEMO_PYTHON=/caminho/venv/bin/python."
    install_units
    sleep 2
    status || true
    say "Demo: http://127.0.0.1:8081 (suba 'advplc serve src/GEBTUI.prw' fora deste script se precisar da TUI)."
    say "Login empresa 99: DEM_ADMIN / Demo#2026 (criado no primeiro 'geban-demo seed'). Conta super: Geban#2026 (troca obrigatória no 1º login)."
    say "Primeiro uso: rode 'scripts/geban-demo.sh seed'. Logs: journalctl --user -u geban-emu-sefaz -u geban-emu-cielo -u geban-emu-banco -u geban-periferico"
}

down() {
    need systemctl
    systemctl --user stop "${UNITS[@]/%/.service}" 2>/dev/null || true
    say "Units paradas (continuam enabled — voltam no próximo login). Para desabilitar de vez: systemctl --user disable ${UNITS[*]}"
}

status() {
    local name port unit state bad=0
    printf '%-20s %-10s %-8s %s\n' UNIT ACTIVE PORTA SAUDE
    for name in sefaz cielo banco periferico; do
        case $name in
            sefaz)      port=18766 ;;
            cielo)      port=18765 ;;
            banco)      port=18767 ;;
            periferico) port=9100 ;;
        esac
        case $name in
            sefaz)      unit=geban-emu-sefaz ;;
            cielo)      unit=geban-emu-cielo ;;
            banco)      unit=geban-emu-banco ;;
            periferico) unit=geban-periferico ;;
        esac
        state=$(unit_state "$unit")
        if healthy "$name" "$port"; then
            printf '%-20s %-10s %-8s OK\n' "$unit" "$state" "$port"
        else
            printf '%-20s %-10s %-8s DOWN\n' "$unit" "$state" "$port"; bad=1
        fi
    done
    return "$bad"
}

seed() {
    need advplc; need timeout
    say "Executando tests/local/seed_full.prw (limite 300s)..."
    local log=$STATE/seed.log pid i
    mkdir -p "$STATE"
    timeout --kill-after=5s 300s advplc run tests/local/seed_full.prw > "$log" 2>&1 &
    pid=$!
    if ! wait "$pid"; then die "seed_full falhou; consulte $log"; fi
    if grep -Eq '(^|[[:space:]])FAIL([[:space:]]|$)' "$log" ||
        ! grep -Eq "^SEED_FULL:? PASS([[:space:]]|$)" "$log"; then
        die "seed_full sem veredito 'SEED_FULL PASS' limpo; consulte $log"
    fi
    say "OK SEED_FULL PASS"
}

reset() {
    need psql
    say "ATENÇÃO: apagará emp_99 CASCADE em $GEBAN_PG_HOST:$GEBAN_PG_PORT/$GEBAN_PG_DB e periferico/saidas/cupom-*; recriará os dados demo."
    if [[ ${1:-} != -y && ${1:-} != --yes ]]; then
        local answer
        read -r -p 'Digite SIM para confirmar: ' answer || return 1
        [[ $answer == SIM ]] || { say 'Cancelado.'; return 0; }
    fi
    down
    PGPASSWORD=$GEBAN_PG_PASSWORD PGCONNECT_TIMEOUT=5 psql -X -v ON_ERROR_STOP=1 \
        -h "$GEBAN_PG_HOST" -p "$GEBAN_PG_PORT" -U "$GEBAN_PG_USER" -d "$GEBAN_PG_DB" \
        -c 'DROP SCHEMA IF EXISTS emp_99 CASCADE;'
    rm -f -- periferico/saidas/cupom-*
    say "Reset concluído. Rode 'scripts/geban-demo.sh up' e depois 'scripts/geban-demo.sh seed' para recriar a carga demo."
}

case ${1:---help} in
    up)    up ;;
    down)  down ;;
    status) status ;;
    seed)  seed ;;
    reset)
        [[ $# -eq 1 || ( $# -eq 2 && ( ${2:-} == -y || ${2:-} == --yes ) ) ]] ||
            die 'Uso: geban-demo.sh reset [-y|--yes]'
        reset "${2:-}" ;;
    -h|--help) say 'Uso: scripts/geban-demo.sh {up|down|status|seed|reset [-y|--yes]}' ;;
    *) die 'Comando inválido; use --help.' ;;
esac
