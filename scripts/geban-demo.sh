#!/usr/bin/env bash
# Entrada única do ambiente local de demonstração (nunca usar em produção).
#
# Wrapper fino sobre units systemd --user. Dois modos:
#   sob-demanda (default, "opcao B"): so' geban-demo-watchdog.service fica
#     enabled/always-on; ele escuta em 127.0.0.1:18768 e sobe as units de
#     emulador via `systemctl --user start` quando o login na empresa 99
#     (hook em GEBWEB.prw/GEBTUI.prw) ou o `seed` chamam GET /ensure.
#     As 4 units de emulador ficam instaladas mas DESABILITADAS.
#   sempre-online (`up --all`): comportamento antigo — enable --now nas
#     4 units de emulador, que voltam sozinhas no boot/login.
#
#   geban-demo-watchdog.service  watchdog :18768 (GET /health /ensure)
#   geban-emu-sefaz.service    emulador SEFAZ HTTPS :18766 (SEFAZ_SEED_NOTAS=9)
#   geban-emu-cielo.service    emulador Cielo       :18765
#   geban-emu-banco.service    emulador CNAB        :18767
#   geban-periferico.service   periferico WS        :9100
#
# Uso: scripts/geban-demo.sh {up [--all]|down|reset|status|seed} [reset: -y|--yes]
#   up     instala/atualiza as units em ~/.config/systemd/user.
#          Default: enable --now SOMENTE o watchdog; as units de emulador
#          ficam instaladas e desabilitadas (sob-demanda). Com --all:
#          enable --now nas 4 de emulador tambem (sempre-online).
#   down   systemctl --user stop nas 4 units de emulador — o WATCHDOG
#          continua rodando (e' a peca always-on): o proximo acesso a
#          empresa 99 chama /ensure e os emuladores sobem de novo.
#          Não toca em processos estranhos que ocupem as portas; o status
#          reporta o conflito honestamente (a unit falha ao dar bind).
#   reset  para TUDO (inclui o watchdog) + DROP SCHEMA emp_99 CASCADE +
#          rm periferico/saidas/cupom-*. Pede confirmação ("SIM") salvo
#          -y/--yes. Depois rode `up` + `seed`.
#   status tabela de saúde: estado das units + portas.
#   seed   chama GET :18768/ensure, espera as portas e roda
#          tests/local/seed_full.prw uma vez (idempotente).
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
WATCHDOG=geban-demo-watchdog
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
    for u in "${UNITS[@]}" "$WATCHDOG"; do
        sed -e "s|__GEBAN_ROOT__|$ROOT|g" -e "s|__GEBAN_PYTHON__|$PYTHON|g" \
            "$UNIT_SRC/$u.service" > "$UNIT_DST/$u.service"
    done
    systemctl --user daemon-reload
}

up() {
    local all=0
    [[ ${1:-} == --all ]] && all=1
    need "$PYTHON"; need curl
    "$PYTHON" -c 'import websockets' 2>/dev/null ||
        die "websockets ausente em $PYTHON. Prepare um venv com periferico/requirements.txt e use GEBAN_DEMO_PYTHON=/caminho/venv/bin/python."
    install_units
    if (( all )); then
        # Sempre-online: enable --now nas 4 de emulador + watchdog.
        for u in "${UNITS[@]}" "$WATCHDOG"; do
            systemctl --user enable --now "$u.service" >/dev/null 2>&1 ||
                systemctl --user enable --now "$u.service"
        done
        say "Modo sempre-online: emuladores enabled (voltam no boot/login)."
    else
        # Sob-demanda: so' o watchdog e' always-on; emuladores instalados
        # mas desabilitados — sobem via GET :18768/ensure no login emp_99.
        systemctl --user enable --now "$WATCHDOG.service" >/dev/null 2>&1 ||
            systemctl --user enable --now "$WATCHDOG.service"
        local u
        for u in "${UNITS[@]}"; do
            systemctl --user disable "$u.service" >/dev/null 2>&1 || true
        done
        say "Modo sob-demanda: watchdog enabled; emuladores desabilitados (subem no primeiro acesso a empresa 99)."
        say "Para sempre-online: scripts/geban-demo.sh up --all"
    fi
    sleep 2
    status || true
    say "Demo: http://127.0.0.1:8081 (suba 'advplc serve src/GEBTUI.prw' fora deste script se precisar da TUI)."
    say "Login empresa 99: DEM_ADMIN / Demo#2026 (criado no primeiro 'geban-demo seed'). Conta super: Geban#2026 (troca obrigatória no 1º login)."
    say "Primeiro uso: rode 'scripts/geban-demo.sh seed'. Logs: journalctl --user -u geban-demo-watchdog -u geban-emu-sefaz -u geban-emu-cielo -u geban-emu-banco -u geban-periferico"
}

down() {
    need systemctl
    # So' os emuladores: o watchdog e' always-on e deve continuar para
    # subir tudo de novo no proximo acesso a empresa 99 (/ensure).
    systemctl --user stop "${UNITS[@]/%/.service}" 2>/dev/null || true
    say "Emuladores parados; o watchdog ($WATCHDOG) continua — próximo acesso à emp_99 os sobe de novo."
    say "Units continuam enabled conforme o modo (sob-demanda: desabilitadas; --all: habilitadas)."
}

status() {
    local name port unit state bad=0
    printf '%-20s %-10s %-8s %s\n' UNIT ACTIVE PORTA SAUDE
    # Watchdog: unica peca always-on no modo sob-demanda.
    state=$(unit_state "$WATCHDOG")
    if tcp 18768; then
        printf '%-20s %-10s %-8s OK\n' "$WATCHDOG.service" "$state" 18768
    else
        printf '%-20s %-10s %-8s DOWN\n' "$WATCHDOG.service" "$state" 18768; bad=1
    fi
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
    need advplc; need timeout; need curl; need "$PYTHON"
    # Sob-demanda: pede ao watchdog para subir os emuladores e espera as
    # portas (cold start de cada servico leva ~1-3s).
    if curl -fsS --max-time 5 http://127.0.0.1:18768/ensure >/dev/null 2>&1; then
        say "Watchdog :18768/ensure ok — aguardando portas dos emuladores..."
    else
        say "AVISO: watchdog :18768 nao respondeu ao /ensure (suba 'geban-demo.sh up'); seguindo mesmo assim."
    fi
    local i
    for i in $(seq 1 60); do
        if tcp 18766 && tcp 18765 && tcp 18767 && tcp 9100; then break; fi
        sleep 0.5
    done
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
    # reset e' parada total: inclui o watchdog (down o preserva de proposito).
    systemctl --user stop "$WATCHDOG.service" 2>/dev/null || true
    PGPASSWORD=$GEBAN_PG_PASSWORD PGCONNECT_TIMEOUT=5 psql -X -v ON_ERROR_STOP=1 \
        -h "$GEBAN_PG_HOST" -p "$GEBAN_PG_PORT" -U "$GEBAN_PG_USER" -d "$GEBAN_PG_DB" \
        -c 'DROP SCHEMA IF EXISTS emp_99 CASCADE;'
    rm -f -- periferico/saidas/cupom-*
    say "Reset concluído. Rode 'scripts/geban-demo.sh up' e depois 'scripts/geban-demo.sh seed' para recriar a carga demo."
}

case ${1:---help} in
    up)    shift; up "${1:-}" ;;
    down)  down ;;
    status) status ;;
    seed)  seed ;;
    reset)
        [[ $# -eq 1 || ( $# -eq 2 && ( ${2:-} == -y || ${2:-} == --yes ) ) ]] ||
            die 'Uso: geban-demo.sh reset [-y|--yes]'
        reset "${2:-}" ;;
    -h|--help) say 'Uso: scripts/geban-demo.sh {up [--all]|down|status|seed|reset [-y|--yes]}' ;;
    *) die 'Comando inválido; use --help.' ;;
esac
