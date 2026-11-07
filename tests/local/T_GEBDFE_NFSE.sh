#!/usr/bin/env bash
# NFS-e nacional local: DPS e pedido de cancelamento contra os XSD oficiais (v1.01)
# e assinatura conferida com lxml/cryptography. Usa a chave/certificado gerados
# por T_GEBDFE_XML.sh (rode-o antes) ou gera novos.
set -uo pipefail
cd "$(dirname "$0")"
OUT=../.out/local; XSD=../xsd/nfse_v1.01; PY=${GEBAN_PY:-python3}
mkdir -p "$OUT"
[ -f "$OUT/key.pem" ] || openssl req -x509 -newkey rsa:2048 -nodes -keyout "$OUT/key.pem" -out "$OUT/cert.pem" -days 2 -subj "/CN=EMPRESA TESTE LTDA:12345678000195" 2>/dev/null
falhas=0
advplc run T_GEBDFE_NFSE.prw > "$OUT/nfse.log" 2>&1; grep -E "^  (OK|FAIL)" "$OUT/nfse.log"; grep -q "^T_GEBDFE_NFSE PASS" "$OUT/nfse.log" || falhas=$((falhas+1))
for a in "dps_sn.xml DPS_v1.01.xsd" "dps_rn.xml DPS_v1.01.xsd" "nfse_canc.xml pedRegEvento_v1.01.xsd"; do set -- $a
    if xmllint --noout --schema "$XSD/$2" "$OUT/$1" > "$OUT/$1.log" 2>&1; then echo "  OK xsd $1"; else echo "  FAIL xsd $1"; head -4 "$OUT/$1.log"; falhas=$((falhas+1)); fi
done
$PY -I - "$OUT" <<'PYEOF' || falhas=$((falhas+1))
import base64, hashlib, sys
from lxml import etree
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
out = sys.argv[1]; pub = x509.load_pem_x509_certificate(open(out + "/cert.pem", "rb").read()).public_key()
DS = "{http://www.w3.org/2000/09/xmldsig#}"; f = 0
c14n = lambda el: etree.tostring(etree.fromstring(etree.tostring(el)), method="c14n")
for arq in ["dps_sn.xml", "dps_rn.xml", "nfse_canc.xml"]:
    doc = etree.parse(out + "/" + arq); sig = next(doc.iter(DS + "Signature"))
    alvo = doc.xpath("//*[@Id=$i]", i=sig.find(".//" + DS + "Reference").get("URI")[1:])[0]
    ok = base64.b64encode(hashlib.sha1(c14n(alvo)).digest()).decode() == sig.find(".//" + DS + "DigestValue").text
    try: pub.verify(base64.b64decode(sig.find(DS + "SignatureValue").text), c14n(sig.find(DS + "SignedInfo")), padding.PKCS1v15(), hashes.SHA1())
    except Exception: ok = False
    print(("  OK" if ok else "  FAIL") + " assinatura " + arq); f += 0 if ok else 1
sys.exit(1 if f else 0)
PYEOF
if [ "$falhas" -eq 0 ]; then echo "T_GEBDFE_NFSE PASS"; else echo "T_GEBDFE_NFSE FAIL ($falhas)"; exit 1; fi
