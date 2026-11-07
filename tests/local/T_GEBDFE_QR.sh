#!/usr/bin/env bash
# Confere o QR Code do GEBAN (src/GEBDFE_QR.prw) contra a biblioteca Python qrcode:
# mesma versao, nivel M e mascara => mesma matriz. Roda local (python3 com qrcode).
set -uo pipefail
cd "$(dirname "$0")"
OUT=$(advplc run T_GEBDFE_QR.prw 2>&1) || { echo "$OUT" | tail -5; echo "T_GEBDFE_QR FAIL"; exit 1; }
echo "$OUT" | python3 -I -c '
import sys, qrcode
txt = ["A", "https://www.homologacao.nfce.fazenda.sp.gov.br/qrcode?p=35261012345678000195650010000000011123456789|3|2",
       "0123456789ABCDEF" * 30, "x" * 800]
linhas = sys.stdin.read().splitlines()
falhas = 0; casos = 0; i = 0
while i < len(linhas):
    l = linhas[i]
    if l.startswith("QR "):
        _, t, k, v = l.split(); t = int(t); k = int(k); v = int(v)
        n = v * 4 + 17
        mat = linhas[i + 1:i + 1 + n]; i += 1 + n
        casos += 1
        if k < 0:
            q = qrcode.QRCode(error_correction=qrcode.constants.ERROR_CORRECT_M, border=0)
            q.add_data(qrcode.util.QRData(txt[t - 1].encode(), mode=qrcode.util.MODE_8BIT_BYTE)); q.make(fit=True)
            ok = q.version == v
            if not ok: print("  FALHA versao texto", t, "esperada", q.version, "obtida", v)
            falhas += 0 if ok else 1
            continue
        q = qrcode.QRCode(version=v, error_correction=qrcode.constants.ERROR_CORRECT_M, border=0, mask_pattern=k)
        q.add_data(qrcode.util.QRData(txt[t - 1].encode(), mode=qrcode.util.MODE_8BIT_BYTE)); q.make(fit=False)
        esp = ["".join("1" if c else "0" for c in row) for row in q.get_matrix()]
        if esp != mat:
            falhas += 1
            dif = sum(1 for a, b in zip(esp, mat) for x, y in zip(a, b) if x != y)
            print("  FALHA texto", t, "mascara", k, "versao", v, "modulos diferentes:", dif)
        else:
            print("  OK texto", t, "mascara", k, "versao", v)
    else:
        i += 1
print("casos", casos)
sys.exit(1 if falhas or casos == 0 else 0)
' && echo "T_GEBDFE_QR PASS" || { echo "T_GEBDFE_QR FAIL"; exit 1; }
