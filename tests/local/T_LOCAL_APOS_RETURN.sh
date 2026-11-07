#!/usr/bin/env bash
# Declaracao "Local" depois de "Return" dentro da mesma funcao. O AdvPP compila o
# fonte mas a declaracao fica fora do fluxo: em 2026-11-07 uma "Local aR := ..."
# colocada depois do Return de U_GEBPDVCAIXAABR fazia o gebweb falhar no boot
# (incidente em docs/incidentes/2026-11-07-gebweb-boot.md). Reprova o fonte se achar.
cd "$(dirname "$0")/../.."
achou=$(awk '
  /^[[:space:]]*(User|Static) Function/ { after = 0 }
  /^[[:space:]]*Return([[:space:](]|$)/ { after = 1; next }
  /^[[:space:]]*(\/\/|\*|\/\*)/ || /^[[:space:]]*$/ { next }
  after && /^[[:space:]]*Local[[:space:]]/ { printf "%s:%d: %s\n", FILENAME, FNR, $0 }
  { if (!/^[[:space:]]*Return/) after = 0 }
' src/*.prw tests/*.prw 2>/dev/null)
if [ -n "$achou" ]; then echo "$achou"; echo "T_LOCAL_APOS_RETURN FAIL"; exit 1; fi
echo "T_LOCAL_APOS_RETURN PASS"
