#!/usr/bin/env bash
# Confere o Code 128 (C) do DANFE (src/GEBDFE_DANFE55.prw) com o reportlab.
set -uo pipefail
cd "$(dirname "$0")"
PY=${GEBAN_PY:-python3}
advplc run T_GEBDFE_C128.prw 2>&1 | $PY -I -c '
import sys
from reportlab.graphics.barcode.code128 import Code128
falhas = 0; n = 0
for l in sys.stdin.read().splitlines():
    if l.startswith("C128 "):
        _, dig, larg = l.split(); n += 1
        b = Code128(dig); b.validate(); b.encode()
        esp = "".join(str(ord(c.lower()) - 96) for c in b.decompose())
        if esp == larg: print("  OK", dig)
        else: print("  FAIL", dig); falhas += 1
    elif l.startswith("IMPAR"):
        ok = l.strip() == "IMPAR []"; print("  OK impar recusado" if ok else "  FAIL impar"); falhas += 0 if ok else 1
sys.exit(1 if falhas or n == 0 else 0)
' && echo "T_GEBDFE_C128 PASS" || { echo "T_GEBDFE_C128 FAIL"; exit 1; }
