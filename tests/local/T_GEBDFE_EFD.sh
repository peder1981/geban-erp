#!/usr/bin/env bash
# EFD ICMS/IPI local: gera o arquivo (T_GEBDFE_EFD.prw) e confere de forma
# independente: campos por registro (leiaute do Guia Pratico), obrigatorios,
# numeros com virgula, datas, hierarquia dos blocos, 9900/x990/9999, C190 x C100
# e a apuracao do E110/E116.
set -uo pipefail
cd "$(dirname "$0")"
OUT=../.out/local; PY=${GEBAN_PY:-python3}
mkdir -p "$OUT"
falhas=0
advplc run T_GEBDFE_EFD.prw > "$OUT/efd.log" 2>&1; grep -E "^  (OK|FAIL)" "$OUT/efd.log"; grep -q "^T_GEBDFE_EFD PASS" "$OUT/efd.log" || falhas=$((falhas+1))
$PY -I - "$OUT/efd.txt" <<'PYEOF' || falhas=$((falhas+1))
import re, sys
from decimal import Decimal as D
L = {  # campos depois do REG; * = obrigatorio
 "0000": "COD_VER* COD_FIN* DT_INI* DT_FIN* NOME* CNPJ CPF UF* IE* COD_MUN* IM SUFRAMA IND_PERFIL* IND_ATIV*",
 "0001": "IND_MOV*", "0005": "FANTASIA CEP END NUM COMPL BAIRRO FONE FAX EMAIL",
 "0100": "NOME* CPF* CRC* CNPJ CEP END NUM COMPL BAIRRO FONE FAX EMAIL* COD_MUN*",
 "0150": "COD_PART* NOME* COD_PAIS* CNPJ CPF IE COD_MUN SUFRAMA END* NUM COMPL BAIRRO",
 "0190": "UNID* DESCR*", "0200": "COD_ITEM* DESCR_ITEM* COD_BARRA COD_ANT_ITEM UNID_INV* TIPO_ITEM* COD_NCM EX_IPI COD_GEN COD_LST ALIQ_ICMS CEST",
 "0220": "UNID_CONV* FAT_CONV* COD_BARRA", "0990": "QTD_LIN*",
 "C100": "IND_OPER* IND_EMIT* COD_PART COD_MOD* COD_SIT* SER NUM_DOC* CHV_NFE DT_DOC DT_E_S VL_DOC IND_PGTO VL_DESC VL_ABAT_NT VL_MERC IND_FRT "
         "VL_FRT VL_SEG VL_OUT_DA VL_BC_ICMS VL_ICMS VL_BC_ICMS_ST VL_ICMS_ST VL_IPI VL_PIS VL_COFINS VL_PIS_ST VL_COFINS_ST",
 "C101": "VL_FCP_UF_DEST* VL_ICMS_UF_DEST* VL_ICMS_UF_REM*",
 "C170": "NUM_ITEM* COD_ITEM* DESCR_COMPL QTD* UNID* VL_ITEM* VL_DESC IND_MOV* CST_ICMS* CFOP* COD_NAT VL_BC_ICMS ALIQ_ICMS VL_ICMS VL_BC_ICMS_ST "
         "ALIQ_ST VL_ICMS_ST IND_APUR CST_IPI COD_ENQ VL_BC_IPI ALIQ_IPI VL_IPI CST_PIS VL_BC_PIS ALIQ_PIS QUANT_BC_PIS ALIQ_PIS_R VL_PIS CST_COFINS "
         "VL_BC_COFINS ALIQ_COFINS QUANT_BC_COFINS ALIQ_COFINS_R VL_COFINS COD_CTA VL_ABAT_NT",
 "C190": "CST_ICMS* CFOP* ALIQ_ICMS VL_OPR* VL_BC_ICMS* VL_ICMS* VL_BC_ICMS_ST* VL_ICMS_ST* VL_RED_BC* VL_IPI* COD_OBS",
 "E100": "DT_INI* DT_FIN*",
 "E110": "VL_TOT_DEBITOS* VL_AJ_DEBITOS* VL_TOT_AJ_DEBITOS* VL_ESTORNOS_CRED* VL_TOT_CREDITOS* VL_AJ_CREDITOS* VL_TOT_AJ_CREDITOS* VL_ESTORNOS_DEB* "
         "VL_SLD_CREDOR_ANT* VL_SLD_APURADO* VL_TOT_DED* VL_ICMS_RECOLHER* VL_SLD_CREDOR_TRANSPORTAR* DEB_ESP*",
 "E116": "COD_OR* VL_OR* DT_VCTO* COD_REC* NUM_PROC IND_PROC PROC TXT_COMPL MES_REF*",
 "E200": "UF* DT_INI* DT_FIN*",
 "E210": "IND_MOV_ST* VL_SLD_CRED_ANT_ST* VL_DEVOL_ST* VL_RESSARC_ST* VL_OUT_CRED_ST* VL_AJ_CREDITOS_ST* VL_RETENCAO_ST* VL_OUT_DEB_ST* "
         "VL_AJ_DEBITOS_ST* VL_SLD_DEV_ANT_ST* VL_DEDUCOES_ST* VL_ICMS_RECOL_ST* VL_SLD_CRED_ST_TRANSPORTAR* DEB_ESP_ST*",
 "E250": "COD_OR* VL_OR* DT_VCTO* COD_REC* NUM_PROC IND_PROC PROC TXT_COMPL MES_REF*",
 "E300": "UF* DT_INI* DT_FIN*",
 "E310": "IND_MOV_FCP_DIFAL* VL_SLD_CRED_ANT_DIFAL* VL_TOT_DEBITOS_DIFAL* VL_OUT_DEB_DIFAL* VL_TOT_CREDITOS_DIFAL* VL_OUT_CRED_DIFAL* "
         "VL_SLD_DEV_ANT_DIFAL* VL_DEDUCOES_DIFAL* VL_RECOL_DIFAL* VL_SLD_CRED_TRANSPORTAR_DIFAL* DEB_ESP_DIFAL* VL_SLD_CRED_ANT_FCP* VL_TOT_DEB_FCP* "
         "VL_OUT_DEB_FCP* VL_TOT_CRED_FCP* VL_OUT_CRED_FCP* VL_SLD_DEV_ANT_FCP* VL_DEDUCOES_FCP* VL_RECOL_FCP* VL_SLD_CRED_TRANSPORTAR_FCP* DEB_ESP_FCP*",
 "E316": "COD_OR* VL_OR* DT_VCTO* COD_REC* NUM_PROC IND_PROC PROC TXT_COMPL MES_REF*",
 "1010": " ".join(c + "*" for c in "IND_EXP IND_CCRF IND_COMB IND_USINA IND_VA IND_EE IND_CART IND_FORM IND_AER IND_GIAF1 IND_GIAF3 IND_GIAF4 "
                                   "IND_REST_RESSARC_COMPL_ICMS".split()),
 "9900": "REG_BLC* QTD_REG_BLC*", "9990": "QTD_LIN_9*", "9999": "QTD_LIN*",
}
for b in "0BCDEGHK19":
    L.setdefault(b + "001", "IND_MOV*"); L.setdefault(b + "990", "QTD_LIN*")
erros = []
def err(m): erros.append(m)
raw = open(sys.argv[1], "rb").read()
if not raw.endswith(b"\r\n") or b"\n" in raw.replace(b"\r\n", b""): err("linhas sem CRLF")
if any(c > 126 for c in raw): err("bytes fora de ASCII")
lin = raw.decode("ascii", "replace").split("\r\n")[:-1]
regs = []
for i, l in enumerate(lin, 1):
    if not (l.startswith("|") and l.endswith("|")): err(f"linha {i} sem pipes"); continue
    f = l[1:-1].split("|"); r = f[0]
    if r not in L: err(f"linha {i}: registro {r} desconhecido"); continue
    nomes = L[r].split()
    if len(f) - 1 != len(nomes): err(f"linha {i} {r}: {len(f)-1} campos, esperado {len(nomes)}"); continue
    cod_sit = f[5] if r == "C100" else ""
    for n, v in zip(nomes, f[1:]):
        obr = n.endswith("*"); n = n.rstrip("*")
        if obr and v == "": err(f"linha {i} {r}.{n} obrigatorio vazio")
        if v and (n.startswith("VL_") or n.startswith("ALIQ") or n in ("QTD", "FAT_CONV", "DEB_ESP")) and not re.fullmatch(r"\d+(,\d+)?", v):
            err(f"linha {i} {r}.{n} numero invalido: {v}")
        if v and (n.startswith("DT_")) and not re.fullmatch(r"(0[1-9]|[12]\d|3[01])(0[1-9]|1[0-2])20\d\d", v): err(f"linha {i} {r}.{n} data: {v}")
    if r == "C100" and cod_sit in ("02", "03", "04", "05") and any(f[j] for j in [3] + list(range(9, 29))):
        err(f"linha {i}: C100 {cod_sit} com campos alem da identificacao")
    regs.append((r, [x for x in f[1:]]))
ordem = "0BCDEGHK19"
blocos = [r[0] for r, _ in regs]
if blocos != sorted(blocos, key=ordem.index): err("blocos fora de ordem")
if regs[0][0] != "0000" or regs[-1][0] != "9999": err("abertura/encerramento")
cont = {}
for r, _ in regs: cont[r] = cont.get(r, 0) + 1
for r, f in regs:
    if r.endswith("990"):
        n = sum(1 for x, _ in regs if x[0] == r[0])
        if int(f[0]) != n: err(f"{r}: {f[0]} != {n}")
    if r == "9900" and int(f[1]) != cont.get(f[0], 0): err(f"9900 {f[0]}: {f[1]} != {cont.get(f[0], 0)}")
if set(f[0] for r, f in regs if r == "9900") != set(cont): err("9900 nao cobre todos os registros")
if int(regs[-1][1][0]) != len(regs): err("9999 errado")
v = lambda s: D(s.replace(",", ".")) if s else D(0)
# C190 x C100 e apuracao.
deb = cred = D(0); doc = None
def fecha():
    if doc and doc["sit"] == "00":
        if sum(doc["opr"]) != v(doc["f"][10]) and doc["f"][2] == "0": err(f"C100 {doc['f'][7]}: soma VL_OPR {sum(doc['opr'])} != VL_DOC {doc['f'][10]}")
        if sum(doc["icms"]) != v(doc["f"][20]): err(f"C100 {doc['f'][7]}: soma C190 VL_ICMS {sum(doc['icms'])} != {doc['f'][20]}")
for r, f in regs + [("FIM", [])]:
    if r in ("C100", "C990", "FIM"):
        fecha(); doc = {"f": f, "sit": f[4], "opr": [], "icms": []} if r == "C100" else None
    if r == "C190":
        doc["opr"].append(v(f[3])); doc["icms"].append(v(f[5]))
        if f[1][0] in "567": deb += v(f[5])
        else: cred += v(f[5])
e110 = next(f for r, f in regs if r == "E110")
if v(e110[0]) != deb or v(e110[4]) != cred: err(f"E110 debitos/creditos {e110[0]}/{e110[4]} != {deb}/{cred}")
sld = v(e110[0]) - v(e110[4]) - v(e110[8])
if v(e110[9]) != max(sld, D(0)) or v(e110[12]) != max(-sld, D(0)) or v(e110[11]) != v(e110[9]) - v(e110[10]): err("E110 formula do saldo")
if sum(v(f[1]) for r, f in regs if r == "E116") != v(e110[11]) + v(e110[13]): err("E116 != VL_ICMS_RECOLHER + DEB_ESP")
for e in erros: print("  FAIL: " + e)
print("  OK leiaute, contagens e somas (%d linhas)" % len(regs) if not erros else "  FAIL: %d erro(s) de leiaute" % len(erros))
sys.exit(1 if erros else 0)
PYEOF
if [ "$falhas" -eq 0 ]; then echo "T_GEBDFE_EFD PASS"; else echo "T_GEBDFE_EFD FAIL ($falhas)"; exit 1; fi
