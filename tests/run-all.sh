#!/usr/bin/env bash
# Roda a suite tests/T_*.prw contra o Postgres de teste e consolida
# o veredito real de cada teste.
#
# Uso:
#   GEBAN_PG_HOST=localhost GEBAN_PG_PORT=5432 GEBAN_PG_DB=geban_test \
#   GEBAN_PG_USER=postgres GEBAN_PG_PASSWORD=senha ./tests/run-all.sh [padrao]
#
#   padrao (opcional): roda so' testes cujo nome contenha o texto
#   (ex.: ./tests/run-all.sh GEBSEC).
#
# Veredito: procura "T_NOME PASS"/"PASS" na saida; FAIL explicito ou
# ausencia de veredito positivo conta como falha. Testes que precisam
# dos emuladores (SEFAZ :18766, Cielo :18765, Banco :18767) falham sem eles — suba
# tests/emuladores/ antes se for o caso. O watchdog :18768 NAO e'
# necessario: os emuladores podem vir das units systemd ou de qualquer
# outro meio; T_GEBAN_DEMO apenas dispara /ensure como cortesia e
# tolera o watchdog fora do ar. T_GEBAN_DEMO exige o ambiente demo
# semeado (emp_99 via scripts/geban-demo.sh seed) e e' read-only.
#
# Rode SEMPRE num banco de teste dedicado, nunca em producao.
set -uo pipefail
cd "$(dirname "$0")/.."

PADRAO=${1:-}
PASS=0; FAIL=0; ERRO=0
declare -a FALHAS=()

for f in tests/T_*.prw; do
    nome=$(basename "$f" .prw)
    [ -n "$PADRAO" ] && [[ "$nome" != *"$PADRAO"* ]] && continue

    out=$(timeout 300 advplc run "$f" 2>&1)
    rc=$?

    # Veredito = ultima ocorrencia de "T_ALGO PASS|FAIL" (formatos vistos:
    # "T_X PASS", "T_X: PASS", "T_X PASS algo"). FAIL no fim vence PASS.
    verdict=$(printf '%s' "$out" | grep -oE "T_[A-Za-z0-9_]+:? (PASS|FAIL)" | tail -1 | awk '{print $NF}')

    if [ "$verdict" = "PASS" ]; then
        PASS=$((PASS+1))
    elif [ "$verdict" = "FAIL" ]; then
        FAIL=$((FAIL+1)); FALHAS+=("$nome")
    elif [ $rc -ne 0 ]; then
        ERRO=$((ERRO+1)); FALHAS+=("$nome (rc=$rc, sem veredito)")
    else
        FAIL=$((FAIL+1)); FALHAS+=("$nome (sem veredito)")
    fi
done

echo "=============================================="
echo "RESULTADO: $PASS PASS, $FAIL FAIL, $ERRO erro(s)"
if [ ${#FALHAS[@]} -gt 0 ]; then
    printf '  - %s\n' "${FALHAS[@]}"
fi
[ $FAIL -eq 0 ] && [ $ERRO -eq 0 ]
