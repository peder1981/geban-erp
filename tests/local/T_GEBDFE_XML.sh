#!/usr/bin/env bash
# Conformidade do motor de documentos fiscais (src/GEBDFE_XML.prw), local:
#  1. gera chave e certificado de teste (openssl);
#  2. roda T_GEBDFE_XML.prw (asserts + grava os XML em ../.out/local);
#  3. valida cada XML contra o XSD oficial (xmllint, tests/xsd/PL_010_V1.30);
#  4. confere digest e assinatura XMLDSig e o QR Code offline v3 / v2
#     (python com lxml e cryptography, independente do runtime).
set -uo pipefail
cd "$(dirname "$0")"
OUT=../.out/local; XSD=../xsd/PL_010_V1.30
PY=${GEBAN_PY:-python3}
rm -rf "$OUT"; mkdir -p "$OUT"
openssl req -x509 -newkey rsa:2048 -nodes -keyout "$OUT/key.pem" -out "$OUT/cert.pem" -days 2 \
    -subj "/C=BR/O=ICP-Brasil/CN=EMPRESA TESTE LTDA:12345678000195" 2>/dev/null || { echo "T_GEBDFE_XML FAIL (openssl)"; exit 1; }
falhas=0
advplc run T_GEBDFE_XML.prw > "$OUT/run.log" 2>&1
grep -E "^  (OK|FAIL)" "$OUT/run.log"
grep -q "^T_GEBDFE_XML PASS" "$OUT/run.log" || { tail -5 "$OUT/run.log"; falhas=$((falhas+1)); }
valida() { # arquivo xsd
    if xmllint --noout --schema "$XSD/$2" "$OUT/$1" > "$OUT/$1.xsd.log" 2>&1; then echo "  OK xsd $1"; else echo "  FAIL xsd $1"; cat "$OUT/$1.xsd.log" | head -5; falhas=$((falhas+1)); fi
}
valida nfce.xml nfe_v4.00.xsd
valida nfce_off.xml nfe_v4.00.xsd
valida nfe55.xml nfe_v4.00.xsd
valida nfe55cobr.xml nfe_v4.00.xsd
valida nfe55dev.xml nfe_v4.00.xsd
valida cce.xml envCCe_v1.00.xsd
valida nfe55st.xml nfe_v4.00.xsd
valida nfe55sn.xml nfe_v4.00.xsd
valida nfe55ibs.xml nfe_v4.00.xsd
valida dist_nsu.xml distDFeInt_v1.01.xsd
valida dist_ch.xml distDFeInt_v1.01.xsd
valida manif.xml envConfRecebto_v1.00.xsd
valida lote.xml enviNFe_v4.00.xsd
valida evento.xml envEventoCancNFe_v1.00.xsd
valida inut.xml inutNFe_v4.00.xsd
valida status.xml consStatServ_v4.00.xsd
valida consulta.xml consSitNFe_v4.00.xsd
xmllint --noout "$OUT/soap.xml" && echo "  OK soap bem formado" || falhas=$((falhas+1))
$PY -I - "$OUT" <<'PYEOF' || falhas=$((falhas+1))
import base64, hashlib, sys
from lxml import etree
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
out = sys.argv[1]
cert = x509.load_pem_x509_certificate(open(out + "/cert.pem", "rb").read())
pub = cert.public_key()
DS = "{http://www.w3.org/2000/09/xmldsig#}"
falhas = 0
def c14n(el):
    # libxml2 2.12.x poe xmlns="" nos netos ao canonicalizar uma subarvore:
    # copia o elemento (com o namespace herdado) para um documento proprio.
    return etree.tostring(etree.fromstring(etree.tostring(el)), method="c14n")
for arq in ["nfce.xml", "nfce_off.xml", "nfe55.xml", "nfe55cobr.xml", "nfe55dev.xml", "nfe55st.xml", "nfe55sn.xml", "nfe55ibs.xml", "manif.xml", "evento.xml", "cce.xml", "inut.xml"]:
    doc = etree.parse(out + "/" + arq)
    for sig in doc.iter(DS + "Signature"):
        ref = sig.find(".//" + DS + "Reference").get("URI")[1:]
        alvo = doc.xpath("//*[@Id=$i]", i=ref)[0]
        dig = base64.b64encode(hashlib.sha1(c14n(alvo)).digest()).decode()
        dv = sig.find(".//" + DS + "DigestValue").text
        si = c14n(sig.find(DS + "SignedInfo"))
        sv = base64.b64decode(sig.find(DS + "SignatureValue").text)
        try:
            pub.verify(sv, si, padding.PKCS1v15(), hashes.SHA1()); ok_sig = True
        except Exception:
            ok_sig = False
        x5 = sig.find(".//" + DS + "X509Certificate").text
        ok_cert = base64.b64decode(x5) == cert.public_bytes(__import__("cryptography.hazmat.primitives.serialization", fromlist=["Encoding"]).Encoding.DER)
        if dig == dv and ok_sig and ok_cert:
            print("  OK assinatura", arq, ref[:14] + "...")
        else:
            print("  FAIL assinatura", arq, "digest", dig == dv, "rsa", ok_sig, "cert", ok_cert); falhas += 1
# QR v3 offline: assinatura RSA-SHA1 da cadeia sem o ultimo campo.
qr = open(out + "/qr3off.txt").read().strip()
p = qr.split("?p=", 1)[1].split("|")
seq = "|".join(p[:-1]).encode()
try:
    pub.verify(base64.b64decode(p[-1]), seq, padding.PKCS1v15(), hashes.SHA1())
    nf = etree.parse(out + "/nfce_off.xml").getroot()
    N = "{http://www.portalfiscal.inf.br/nfe}"
    ch = nf.find(N + "infNFe").get("Id")[3:]
    vnf = nf.find(".//" + N + "vNF").text
    ok = p[0] == ch and p[1] == "3" and p[2] == "2" and p[3] == "19" and p[4] == vnf and p[5] == "2" and p[6] == "11144477735"
    ok = ok and nf.find(".//" + N + "qrCode").text == qr
    print("  OK qr v3 offline" if ok else "  FAIL qr v3 offline campos " + str(p[:7]))
    falhas += 0 if ok else 1
except Exception as e:
    print("  FAIL qr v3 offline assinatura", e); falhas += 1
# QR v2 online: SHA-1 (maiusculo) de chave|2|tpAmb|idCSC + CSC.
ch, qr2 = open(out + "/qr2.txt").read().split("\n")
seq = ch + "|2|2|1"
esp = "https://www.homologacao.nfce.fazenda.sp.gov.br/qrcode?p=" + seq + "|" + hashlib.sha1((seq + "CSCTESTE123").encode()).hexdigest().upper()
print("  OK qr v2" if qr2.strip() == esp else "  FAIL qr v2 " + qr2); falhas += 0 if qr2.strip() == esp else 1
sys.exit(1 if falhas else 0)
PYEOF
if [ "$falhas" -eq 0 ]; then echo "T_GEBDFE_XML PASS"; else echo "T_GEBDFE_XML FAIL ($falhas)"; exit 1; fi
