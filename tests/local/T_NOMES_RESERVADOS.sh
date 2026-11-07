#!/usr/bin/env bash
# Variaveis com nome de palavra-chave do AdvPP (aS = AS, oR = OR, oN = ON...) compilam
# mas viram outra coisa (ex.: aS[2] devolve o vetor inteiro). Procura nos fontes.
cd "$(dirname "$0")/../.."
achou=$(grep -nwE "(Local|Private|Static)\s+(aS|oR|oN|aT_|dO|iF|oF|tO|aND|nOT)\b" src/*.prw tests/*.prw tests/local/*.prw 2>/dev/null)
if [ -n "$achou" ]; then echo "$achou"; echo "T_NOMES_RESERVADOS FAIL"; exit 1; fi
echo "T_NOMES_RESERVADOS PASS"
