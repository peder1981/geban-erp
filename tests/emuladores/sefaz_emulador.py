#!/usr/bin/env python3
"""Emulador local dos webservices da SEFAZ (NF-e/NFC-e 4.00) para os testes.

HTTPS (certificado proprio, gerado com o openssl na partida) em 127.0.0.1.
Um so endereco atende todos os servicos: o servico sai do elemento dentro de
<nfeDadosMsg> (enviNFe, consStatServ, consSitNFe, envEvento, inutNFe), como
a SEFAZ faz por URL. Confere a assinatura XMLDSig de cada documento
(digest SHA-1 da forma canonica + RSA-SHA1 pelo certificado embutido, com o
openssl) e responde como a SEFAZ:
  enviNFe   104 + protNFe 100 (nProt sequencial). Regras simuladas:
            assinatura errada 297; homologacao sem o texto no 1o item 373;
            NCM 99999999 778; mesma chave ja autorizada 204; mesmo
            serie/numero com outra chave 539 [chNFe:...]; infCpl com
            PARALISADO => lote 108; infCpl com DEMORA => autoriza e so'
            responde depois de 4 s (o teste usa timeout menor).
  consStatServ 107.  consSitNFe 100/101/217.
  envEvento cancelamento: 128 + 135 (nProt confere), 580 se ja cancelada,
            217 se a nota nao existe, 222 protocolo divergente.
  inutNFe   102; 241 se um numero da faixa ja foi autorizado.
  distDFeInt (AN): semeia SEFAZ_SEED_NOTAS notas (padrao 2; demo: 9) do
            fornecedor 11444777000161 para o CNPJ consultado (a 2a cancelada
            por evento, demais importaveis); ciencia/confirmacao (2102xx)
            liberam a nota completa (procNFe); 137 sem novidade, 656 na 2a vazia.
NFS-e nacional (REST/JSON, mesmo endereco): POST .../nfse (DPS gzip+Base64;
  assinatura conferida; cTribNac 999999 => 400 E0310; xDescServ com DEMORA
  => gera e responde depois de 4 s; DPS repetida => 400 E0014), GET
  .../dps/{id}, POST .../nfse/{chave}/eventos (cancelamento), GET
  .../danfse/{chave} (PDF).

Uso: python3 sefaz_emulador.py [porta]   (padrao 18766)
"""
import base64
import hashlib
import json
import os
import re
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

NS = "http://www.portalfiscal.inf.br/nfe"
DS = "http://www.w3.org/2000/09/xmldsig#"
N = "{%s}" % NS
D = "{%s}" % DS
HOMOLOG = "NOTA FISCAL EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL"
HOMOLOG_NFE = "NF-E EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL"

TRAVA = threading.RLock()
NOTAS = {}      # chave -> {"prot", "dh", "status", "serie", "nnf", "mod", "digval"}
NUMEROS = {}    # (mod, serie, nnf) -> chave autorizada
SEQ = [0]
TMP = tempfile.mkdtemp(prefix="sefaz-emu-")


def agora():
    return datetime.now(timezone(timedelta(hours=-3))).strftime("%Y-%m-%dT%H:%M:%S-03:00")


def proximo_prot(cuf):
    with TRAVA:
        SEQ[0] += 1
        return cuf + "2" + "%012d" % SEQ[0]


def bloco(texto, tag):
    """Trecho bruto do elemento tag (com atributos) no texto."""
    m = re.search(r"<%s[ >]" % tag, texto)
    if not m:
        return ""
    fim = texto.find("</%s>" % tag, m.start())
    return texto[m.start():fim + len(tag) + 3] if fim >= 0 else ""


def canonico(trecho, ns):
    """C14N do elemento extraido, com o namespace herdado declarado nele."""
    tag = re.match(r"<([A-Za-z]+)", trecho).group(1)
    if 'xmlns="' not in trecho[:trecho.find(">")]:
        trecho = '<%s xmlns="%s"%s' % (tag, ns, trecho[len(tag) + 1:])
    return ET.canonicalize(xml_data=trecho).encode()


def assinatura_ok(doc_txt, tag, ns=NS):
    """Confere digest e RSA-SHA1 da assinatura que segue o elemento tag."""
    try:
        alvo = bloco(doc_txt, tag)
        sig = bloco(doc_txt[doc_txt.find(alvo):], "Signature")
        if not alvo or not sig:
            return False
        dig = base64.b64encode(hashlib.sha1(canonico(alvo, ns)).digest()).decode()
        if dig != re.search(r"<DigestValue>([^<]+)</DigestValue>", sig).group(1):
            return False
        si = canonico(bloco(sig, "SignedInfo"), DS)
        sv = base64.b64decode(re.search(r"<SignatureValue>([^<]+)</SignatureValue>", sig).group(1))
        x5 = re.search(r"<X509Certificate>([^<]+)</X509Certificate>", sig).group(1)
        d = tempfile.mkdtemp(dir=TMP)
        pem = "-----BEGIN CERTIFICATE-----\n" + "\n".join(x5[i:i + 64] for i in range(0, len(x5), 64)) + "\n-----END CERTIFICATE-----\n"
        open(d + "/c.pem", "w").write(pem)
        open(d + "/si", "wb").write(si)
        open(d + "/sv", "wb").write(sv)
        subprocess.run(["openssl", "x509", "-in", d + "/c.pem", "-pubkey", "-noout", "-out", d + "/pub.pem"], check=True, capture_output=True)
        r = subprocess.run(["openssl", "dgst", "-sha1", "-verify", d + "/pub.pem", "-signature", d + "/sv", d + "/si"], capture_output=True)
        return r.returncode == 0
    except Exception:
        return False


def envelope(op, corpo):
    return ('<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope"><soap:Body>'
            '<nfeResultMsg xmlns="%s/wsdl/%s">%s</nfeResultMsg></soap:Body></soap:Envelope>' % (NS, op, corpo))


def txt(el, caminho):
    x = el.find(caminho)
    return x.text if x is not None and x.text else ""


def autoriza(msg):
    nfe_txt = bloco(msg, "NFe")
    nfe = ET.fromstring(nfe_txt)
    inf = nfe.find(N + "infNFe")
    chave = inf.get("Id")[3:]
    ide = inf.find(N + "ide")
    tpamb, cuf = txt(ide, N + "tpAmb"), txt(ide, N + "cUF")
    mod, serie, nnf = txt(ide, N + "mod"), txt(ide, N + "serie"), txt(ide, N + "nNF")
    infcpl = txt(inf, N + "infAdic/" + N + "infCpl")
    cab = ('<retEnviNFe xmlns="%s" versao="4.00"><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic>' % (NS, tpamb))
    if "PARALISADO" in infcpl:
        return cab + "<cStat>108</cStat><xMotivo>Servico Paralisado Momentaneamente (curto prazo)</xMotivo><cUF>%s</cUF><dhRecbto>%s</dhRecbto></retEnviNFe>" % (cuf, agora()), 0

    def prot(cstat, motivo, nprot=""):
        dig = re.search(r"<DigestValue>([^<]+)</DigestValue>", nfe_txt)
        p = ('<protNFe versao="4.00"><infProt><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic><chNFe>%s</chNFe><dhRecbto>%s</dhRecbto>'
             % (tpamb, chave, agora()))
        if nprot:
            p += "<nProt>%s</nProt>" % nprot
        if dig:
            p += "<digVal>%s</digVal>" % dig.group(1)
        p += "<cStat>%s</cStat><xMotivo>%s</xMotivo></infProt></protNFe>" % (cstat, motivo)
        return (cab + "<cStat>104</cStat><xMotivo>Lote processado</xMotivo><cUF>%s</cUF><dhRecbto>%s</dhRecbto>%s</retEnviNFe>"
                % (cuf, agora(), p))

    if not assinatura_ok(nfe_txt, "infNFe"):
        return prot("297", "Rejeicao: Assinatura difere do calculado"), 0
    itens = inf.findall(N + "det")
    if tpamb == "2" and mod == "65" and txt(itens[0], N + "prod/" + N + "xProd") != HOMOLOG:
        return prot("373", "Rejeicao: Descricao do primeiro item diferente de " + HOMOLOG), 0
    if tpamb == "2" and mod == "55" and inf.find(N + "dest") is not None and txt(inf, N + "dest/" + N + "xNome") != HOMOLOG_NFE:
        return prot("598", "Rejeicao: NF-e emitida em ambiente de homologacao com Razao Social do destinatario diferente de " + HOMOLOG_NFE), 0
    for ref in inf.findall(N + "ide/" + N + "NFref/" + N + "refNFe"):
        if mod == "55" and txt(ide, N + "finNFe") == "4" and ref.text not in NOTAS and ref.text[20:22] == "55" and ref.text[6:20] == txt(inf, N + "emit/" + N + "CNPJ"):
            return prot("267", "Rejeicao: NF Complementar referencia uma NF-e inexistente"), 0
    for det in itens:
        if txt(det, N + "prod/" + N + "NCM") == "99999999":
            return prot("778", "Rejeicao: Informado NCM inexistente [nItem:%s]" % det.get("nItem")), 0
    with TRAVA:
        if chave in NOTAS:
            return prot("204", "Rejeicao: Duplicidade de NF-e [nProt:%s]" % NOTAS[chave]["prot"]), 0
        outra = NUMEROS.get((mod, serie, nnf))
        if outra:
            return prot("539", "Rejeicao: Duplicidade de NF-e com diferenca na Chave de Acesso [chNFe:%s][nProt:%s]" % (outra, NOTAS[outra]["prot"])), 0
        nprot = proximo_prot(cuf)
        NOTAS[chave] = {"prot": nprot, "dh": agora(), "status": "100", "mod": mod, "serie": serie, "nnf": nnf}
        NUMEROS[(mod, serie, nnf)] = chave
    demora = 4 if "DEMORA" in infcpl else 0
    return prot("100", "Autorizado o uso da NF-e", nprot), demora


def consulta(msg):
    r = ET.fromstring(bloco(msg, "consSitNFe"))
    tpamb, chave = txt(r, N + "tpAmb"), txt(r, N + "chNFe")
    cab = '<retConsSitNFe xmlns="%s" versao="4.00"><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic>' % (NS, tpamb)
    n = NOTAS.get(chave)
    if not n:
        return cab + "<cStat>217</cStat><xMotivo>Rejeicao: NF-e nao consta na base de dados da SEFAZ</xMotivo><cUF>%s</cUF><dhRecbto>%s</dhRecbto><chNFe>%s</chNFe></retConsSitNFe>" % (chave[:2], agora(), chave)
    cstat, motivo = ("101", "Cancelamento de NF-e homologado") if n["status"] == "101" else ("100", "Autorizado o uso da NF-e")
    return (cab + "<cStat>%s</cStat><xMotivo>%s</xMotivo><cUF>%s</cUF><dhRecbto>%s</dhRecbto><chNFe>%s</chNFe>"
            '<protNFe versao="4.00"><infProt><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic><chNFe>%s</chNFe><dhRecbto>%s</dhRecbto>'
            "<nProt>%s</nProt><cStat>100</cStat><xMotivo>Autorizado o uso da NF-e</xMotivo></infProt></protNFe></retConsSitNFe>"
            % (cstat, motivo, chave[:2], agora(), chave, tpamb, chave, n["dh"], n["prot"]))


def evento(msg):
    ev_txt = bloco(msg, "evento")
    ev = ET.fromstring(ev_txt)
    inf = ev.find(N + "infEvento")
    tpamb, chave, nprot = txt(inf, N + "tpAmb"), txt(inf, N + "chNFe"), txt(inf, N + "detEvento/" + N + "nProt")
    tpevento = txt(inf, N + "tpEvento")

    def ret(cstat, motivo, prot=""):
        r = ('<retEnvEvento xmlns="%s" versao="1.00"><idLote>1</idLote><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic><cOrgao>%s</cOrgao>'
             "<cStat>128</cStat><xMotivo>Lote de Evento Processado</xMotivo>"
             '<retEvento versao="1.00"><infEvento><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic><cOrgao>%s</cOrgao><cStat>%s</cStat>'
             "<xMotivo>%s</xMotivo><chNFe>%s</chNFe><tpEvento>%s</tpEvento><xEvento>%s</xEvento>"
             "<nSeqEvento>%s</nSeqEvento><dhRegEvento>%s</dhRegEvento>" % (NS, tpamb, chave[:2], tpamb, chave[:2], cstat, motivo, chave, tpevento,
                                                                         "Carta de Correcao registrada" if tpevento == "110110" else "Cancelamento registrado",
                                                                         txt(inf, N + "nSeqEvento"), agora()))
        if prot:
            r += "<nProt>%s</nProt>" % prot
        return r + "</infEvento></retEvento></retEnvEvento>"

    if not assinatura_ok(ev_txt, "infEvento"):
        return ret("297", "Rejeicao: Assinatura difere do calculado")
    if tpevento.startswith("2102"):
        cst, mot = manifesta(chave, tpevento, txt(inf, N + "CNPJ"))
        return ret(cst, mot, proximo_prot("91") if cst == "135" else "")
    with TRAVA:
        n = NOTAS.get(chave)
        if not n:
            return ret("217", "Rejeicao: NF-e nao consta na base de dados da SEFAZ")
        if n["status"] == "101":
            return ret("580", "Rejeicao: O evento exige uma NF-e autorizada")
        if tpevento == "110110":
            if n["mod"] != "55":
                return ret("490", "Rejeicao: Evento nao permitido para o modelo")
            if len(txt(inf, N + "detEvento/" + N + "xCorrecao")) < 15:
                return ret("225", "Rejeicao: Falha no Schema XML (xCorrecao)")
            return ret("135", "Evento registrado e vinculado a NF-e", proximo_prot(chave[:2]))
        if n["prot"] != nprot:
            return ret("222", "Rejeicao: Protocolo de Autorizacao de Uso difere do cadastrado")
        n["status"] = "101"
        return ret("135", "Evento registrado e vinculado a NF-e", proximo_prot(chave[:2]))


def inutiliza(msg):
    inut_txt = bloco(msg, "inutNFe")
    inf = ET.fromstring(inut_txt).find(N + "infInut")
    tpamb, cuf, mod, serie = txt(inf, N + "tpAmb"), txt(inf, N + "cUF"), txt(inf, N + "mod"), txt(inf, N + "serie")
    ini, fim = int(txt(inf, N + "nNFIni")), int(txt(inf, N + "nNFFin"))

    def ret(cstat, motivo, prot=""):
        r = ('<retInutNFe xmlns="%s" versao="4.00"><infInut><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic><cStat>%s</cStat><xMotivo>%s</xMotivo>'
             "<cUF>%s</cUF><ano>%s</ano><CNPJ>%s</CNPJ><mod>%s</mod><serie>%s</serie><nNFIni>%d</nNFIni><nNFFin>%d</nNFFin><dhRecbto>%s</dhRecbto>"
             % (NS, tpamb, cstat, motivo, cuf, txt(inf, N + "ano"), txt(inf, N + "CNPJ"), mod, serie, ini, fim, agora()))
        if prot:
            r += "<nProt>%s</nProt>" % prot
        return r + "</infInut></retInutNFe>"

    if not assinatura_ok(inut_txt, "infInut"):
        return ret("297", "Rejeicao: Assinatura difere do calculado")
    with TRAVA:
        for n in range(ini, fim + 1):
            if (mod, serie, str(n)) in NUMEROS:
                return ret("241", "Rejeicao: Um numero da faixa ja foi utilizado")
    return ret("102", "Inutilizacao de numero homologado", proximo_prot(cuf))


# ---------- Distribuicao de DF-e (Ambiente Nacional) ----------
DIST = {}  # CNPJ destinatario -> {"docs": [(nsu, schema, xml)], "chaves": {...}, "vazias": n}
FORN = "11444777000161"


def chave_forn(nnf):
    base = "35" + datetime.now().strftime("%y%m") + FORN + "55" + "001" + "%09d" % nnf + "1" + "%08d" % (nnf * 3)
    return base + dv11(base)


def res_nfe(ch, vnf, sit="1"):
    return ('<resNFe xmlns="%s" versao="1.01"><chNFe>%s</chNFe><CNPJ>%s</CNPJ><xNome>Fornecedor de Bananas Ltda</xNome><IE>110042490114</IE>'
            "<dhEmi>%s</dhEmi><tpNF>1</tpNF><vNF>%s</vNF><dhRecbto>%s</dhRecbto><nProt>135260000000999</nProt><cSitNFe>%s</cSitNFe></resNFe>"
            % (NS, ch, FORN, agora(), vnf, agora(), sit))


def proc_nfe(ch, dest):
    nnf = int(ch[25:34])
    return ('<nfeProc xmlns="%s" versao="4.00"><NFe><infNFe Id="NFe%s" versao="4.00"><ide><cUF>35</cUF><natOp>VENDA</natOp><mod>55</mod><serie>1</serie>'
            "<nNF>%d</nNF><dhEmi>%s</dhEmi><tpNF>1</tpNF></ide><emit><CNPJ>%s</CNPJ><xNome>Fornecedor de Bananas Ltda</xNome><IE>110042490114</IE></emit>"
            "<dest><CNPJ>%s</CNPJ></dest>"
            '<det nItem="1"><prod><cProd>FORN-BAN</cProd><xProd>Banana caixa com 12</xProd><NCM>08039000</NCM><CFOP>5102</CFOP><uCom>CX</uCom>'
            "<qCom>10.0000</qCom><vUnCom>24.00</vUnCom><vProd>240.00</vProd></prod></det>"
            '<det nItem="2"><prod><cProd>FORN-MAC</cProd><xProd>Maca fuji kg</xProd><NCM>08081000</NCM><CFOP>5102</CFOP><uCom>KG</uCom>'
            "<qCom>5.0000</qCom><vUnCom>8.00</vUnCom><vProd>40.00</vProd><vDesc>2.00</vDesc></prod></det>"
            "<total><ICMSTot><vProd>280.00</vProd><vFrete>10.00</vFrete><vDesc>2.00</vDesc><vNF>288.00</vNF></ICMSTot></total></infNFe></NFe>"
            '<protNFe versao="4.00"><infProt><chNFe>%s</chNFe><nProt>135260000000999</nProt><cStat>100</cStat></infProt></protNFe></nfeProc>'
            % (NS, ch, nnf, agora(), FORN, dest, ch))


def dist(msg):
    r = ET.fromstring(bloco(msg, "distDFeInt"))
    tpamb, cnpj = txt(r, N + "tpAmb"), txt(r, N + "CNPJ")
    with TRAVA:
        d = DIST.get(cnpj)
        if d is None:
            a, b = chave_forn(456), chave_forn(457)
            d = DIST[cnpj] = {"docs": [], "chaves": {a: False, b: False}, "vazias": 0, "a": a}
            d["docs"].append(("resNFe_v1.01.xsd", res_nfe(a, "288.00")))
            d["docs"].append(("resNFe_v1.01.xsd", res_nfe(b, "50.00")))
            d["docs"].append(("procEventoNFe_v1.00.xsd", '<procEventoNFe xmlns="%s" versao="1.00"><evento versao="1.00"><infEvento><chNFe>%s</chNFe>'
                              "<tpEvento>110111</tpEvento></infEvento></evento></procEventoNFe>" % (NS, b)))
            for nnf in range(458, 456 + max(2, int(os.environ.get("SEFAZ_SEED_NOTAS", "2")))):
                ch = chave_forn(nnf)
                d["chaves"][ch] = False
                d["docs"].append(("resNFe_v1.01.xsd", res_nfe(ch, "288.00")))
        cab = '<retDistDFeInt xmlns="%s" versao="1.01"><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic>' % (NS, tpamb)
        chc = txt(r, N + "consChNFe/" + N + "chNFe")
        if chc:
            if chc not in d["chaves"]:
                return cab + "<cStat>640</cStat><xMotivo>Rejeicao: CNPJ/CPF do interessado nao possui permissao para consultar esta NF-e</xMotivo><dhResp>%s</dhResp></retDistDFeInt>" % agora()
            xml = proc_nfe(chc, cnpj) if d["chaves"][chc] else res_nfe(chc, "288.00")
            esq = "procNFe_v4.00.xsd" if d["chaves"][chc] else "resNFe_v1.01.xsd"
            return (cab + "<cStat>138</cStat><xMotivo>Documento localizado</xMotivo><dhResp>%s</dhResp><ultNSU>%015d</ultNSU><maxNSU>%015d</maxNSU>"
                    '<loteDistDFeInt><docZip NSU="%015d" schema="%s">%s</docZip></loteDistDFeInt></retDistDFeInt>'
                    % (agora(), len(d["docs"]), len(d["docs"]), len(d["docs"]), esq, gz64(xml)))
        ult = int(txt(r, N + "distNSU/" + N + "ultNSU") or "0")
        novos = [(i + 1, sch, x) for i, (sch, x) in enumerate(d["docs"]) if i + 1 > ult][:50]
        if not novos:
            d["vazias"] += 1
            if d["vazias"] > 1:
                return cab + "<cStat>656</cStat><xMotivo>Rejeicao: Consumo Indevido</xMotivo><dhResp>%s</dhResp></retDistDFeInt>" % agora()
            return (cab + "<cStat>137</cStat><xMotivo>Nenhum documento localizado</xMotivo><dhResp>%s</dhResp><ultNSU>%015d</ultNSU><maxNSU>%015d</maxNSU>"
                    "</retDistDFeInt>" % (agora(), ult, len(d["docs"])))
        d["vazias"] = 0
        lote = "".join('<docZip NSU="%015d" schema="%s">%s</docZip>' % (n, sch, gz64(x)) for n, sch, x in novos)
        return (cab + "<cStat>138</cStat><xMotivo>Documento(s) localizado(s)</xMotivo><dhResp>%s</dhResp><ultNSU>%015d</ultNSU><maxNSU>%015d</maxNSU>"
                "<loteDistDFeInt>%s</loteDistDFeInt></retDistDFeInt>" % (agora(), novos[-1][0], len(d["docs"]), lote))


def manifesta(chave, tpevento, cnpj):
    """Manifestacao (2102xx): {cStat, motivo}. Ciencia/confirmacao liberam a nota completa."""
    with TRAVA:
        d = DIST.get(cnpj)
        if d is None or chave not in d["chaves"]:
            return "217", "Rejeicao: NF-e nao consta na base de dados da SEFAZ"
        if tpevento in ("210210", "210200") and not d["chaves"][chave]:
            d["chaves"][chave] = True
            d["docs"].append(("procNFe_v4.00.xsd", proc_nfe(chave, cnpj)))
    return "135", "Evento registrado e vinculado a NF-e"


# ---------- NFS-e nacional (REST/JSON da Sefin Nacional) ----------
NFSE_NS = "http://www.sped.fazenda.gov.br/nfse"
NFSES = {}   # chave -> {"id", "cancelada"}
DPS_IDS = {}  # idDps -> chave


def gz64(txt):
    import gzip
    return base64.b64encode(gzip.compress(txt.encode())).decode()


def ungz64(b64):
    import gzip
    return gzip.decompress(base64.b64decode(b64)).decode("utf-8")


def dv11(c):
    soma, peso = 0, 2
    for d in reversed(c):
        soma += int(d) * peso
        peso = 2 if peso == 9 else peso + 1
    r = soma % 11
    return "0" if r < 2 else str(11 - r)


def nfse_post(corpo):
    """POST /nfse: (status, dict json, demora)."""
    dps = ungz64(json.loads(corpo)["dpsXmlGZipB64"])
    agora_ = agora()
    erro = lambda cod, desc: (400, {"tipoAmbiente": 2, "versaoAplicativo": "EMU-1.0", "dataHoraProcessamento": agora_,
                                    "erros": [{"codigo": cod, "descricao": desc, "complemento": ""}]}, 0)
    if not assinatura_ok(dps, "infDPS", NFSE_NS):
        return erro("E0714", "Assinatura invalida")
    m = re.search(r'Id="(DPS\d{42})"', dps)
    if not m:
        return erro("E0001", "Id da DPS invalido")
    idd = m.group(1)
    if re.search(r"<cTribNac>999999</cTribNac>", dps):
        return erro("E0310", "Codigo de tributacao nacional inexistente")
    with TRAVA:
        if idd in DPS_IDS:
            return erro("E0014", "DPS ja processada [chave:%s]" % DPS_IDS[idd])
        SEQ[0] += 1
        base = idd[3:10] + "1" + idd[10:25] + "%013d" % SEQ[0] + datetime.now().strftime("%y%m") + "%09d" % (SEQ[0] * 7)
        chave = base + dv11(base)
        DPS_IDS[idd] = chave
        NFSES[chave] = {"id": idd, "cancelada": False}
    nfse = ('<NFSe xmlns="%s" versao="1.01"><infNFSe Id="NFS%s"><nNFSe>%d</nNFSe><dhProc>%s</dhProc>%s</infNFSe></NFSe>'
            % (NFSE_NS, chave, SEQ[0], agora_, dps[dps.find("<DPS"):]))
    demora = 4 if "DEMORA" in dps else 0
    return 201, {"tipoAmbiente": 2, "versaoAplicativo": "EMU-1.0", "dataHoraProcessamento": agora_, "idDps": idd, "chaveAcesso": chave,
                 "nfseXmlGZipB64": gz64(nfse), "alertas": []}, demora


def nfse_evento(chave, corpo):
    ped = ungz64(json.loads(corpo)["pedidoRegistroEventoXmlGZipB64"])
    erro = lambda st, cod, desc: (st, {"erro": [{"codigo": cod, "descricao": desc}]})
    if not assinatura_ok(ped, "infPedReg", NFSE_NS):
        return erro(400, "E0714", "Assinatura invalida")
    if not re.search(r'Id="PRE%s101101"' % chave, ped):
        return erro(400, "E1235", "Id do pedido de evento invalido")
    with TRAVA:
        n = NFSES.get(chave)
        if not n:
            return erro(404, "E0404", "NFS-e nao encontrada")
        if n["cancelada"]:
            return erro(400, "E1220", "NFS-e ja cancelada")
        n["cancelada"] = True
    ev = '<evento xmlns="%s" versao="1.01"><infEvento Id="EVT%s101101001"><dhProc>%s</dhProc>%s</infEvento></evento>' % (NFSE_NS, chave, agora(), ped)
    return 201, {"tipoAmbiente": 2, "versaoAplicativo": "EMU-1.0", "dataHoraProcessamento": agora(), "eventoXmlGZipB64": gz64(ev)}


class Handler(BaseHTTPRequestHandler):
    def _json(self, st, obj, demora=0, tipo="application/json"):
        if demora:
            time.sleep(demora)
        dados = obj if isinstance(obj, bytes) else json.dumps(obj).encode()
        try:
            self.send_response(st)
            self.send_header("Content-Type", tipo)
            self.send_header("Content-Length", str(len(dados)))
            self.end_headers()
            self.wfile.write(dados)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        p = self.path.split("?")[0]
        m = re.search(r"/dps/(DPS\d{42})$", p)
        if m:
            ch = DPS_IDS.get(m.group(1))
            return self._json(200, {"idDps": m.group(1), "chaveAcesso": ch}) if ch else self._json(404, {"erro": [{"codigo": "E0404", "descricao": "DPS nao encontrada"}]})
        m = re.search(r"/danfse/(\d{50})$", p)
        if m:
            if m.group(1) not in NFSES:
                return self._json(404, {"erro": [{"codigo": "E0404"}]})
            return self._json(200, b"%PDF-1.4\n% DANFSe emulador " + m.group(1).encode() + b"\n%%EOF\n", tipo="application/pdf")
        m = re.search(r"/nfse/(\d{50})$", p)
        if m and m.group(1) in NFSES:
            return self._json(200, {"chaveAcesso": m.group(1)})
        return self._json(404, {"erro": [{"codigo": "E0404", "descricao": "nao encontrado"}]})

    def do_POST(self):
        corpo = self.rfile.read(int(self.headers.get("Content-Length", 0))).decode("utf-8", "replace")
        if corpo.lstrip().startswith("{"):
            try:
                m = re.search(r"/nfse/(\d{50})/eventos$", self.path)
                if m:
                    st, obj = nfse_evento(m.group(1), corpo)
                    return self._json(st, obj)
                if self.path.rstrip("/").endswith("/nfse"):
                    st, obj, demora = nfse_post(corpo)
                    return self._json(st, obj, demora)
            except Exception as e:
                return self._json(400, {"erros": [{"codigo": "E0000", "descricao": "Requisicao invalida: %s" % type(e).__name__}]})
            return self._json(404, {"erro": [{"codigo": "E0404"}]})
        demora = 0
        try:
            if "<enviNFe" in corpo:
                resp, demora = autoriza(corpo)
                op = "NFeAutorizacao4"
            elif "<consStatServ" in corpo:
                tpamb = re.search(r"<tpAmb>(\d)</tpAmb>", corpo).group(1)
                cuf = re.search(r"<cUF>(\d+)</cUF>", corpo).group(1)
                resp = ('<retConsStatServ xmlns="%s" versao="4.00"><tpAmb>%s</tpAmb><verAplic>EMU-1.0</verAplic><cStat>107</cStat>'
                        "<xMotivo>Servico em Operacao</xMotivo><cUF>%s</cUF><dhRecbto>%s</dhRecbto><tMed>1</tMed></retConsStatServ>" % (NS, tpamb, cuf, agora()))
                op = "NFeStatusServico4"
            elif "<consSitNFe" in corpo:
                resp, op = consulta(corpo), "NFeConsultaProtocolo4"
            elif "<envEvento" in corpo:
                resp, op = evento(corpo), "NFeRecepcaoEvento4"
            elif "<distDFeInt" in corpo:
                resp, op = dist(corpo), "NFeDistribuicaoDFe"
            elif "<inutNFe" in corpo:
                resp, op = inutiliza(corpo), "NFeInutilizacao4"
            else:
                self.send_response(400)
                self.end_headers()
                return
        except Exception as e:  # mensagem mal formada: a SEFAZ responde 2xx com rejeicao de schema
            resp, op = ('<retEnviNFe xmlns="%s" versao="4.00"><cStat>225</cStat><xMotivo>Rejeicao: Falha no Schema XML (%s)</xMotivo></retEnviNFe>'
                        % (NS, type(e).__name__)), "NFeAutorizacao4"
        if demora:
            time.sleep(demora)
        dados = envelope(op, resp).encode()
        try:
            self.send_response(200)
            self.send_header("Content-Type", "application/soap+xml; charset=utf-8")
            self.send_header("Content-Length", str(len(dados)))
            self.end_headers()
            self.wfile.write(dados)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def log_message(self, *a):
        pass


def main():
    porta = int(sys.argv[1]) if len(sys.argv) > 1 else 18766
    subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", TMP + "/srv.key", "-out", TMP + "/srv.pem",
                    "-days", "2", "-subj", "/CN=127.0.0.1"], check=True, capture_output=True)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(TMP + "/srv.pem", TMP + "/srv.key")
    srv = ThreadingHTTPServer(("127.0.0.1", porta), Handler)
    srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
    srv.serve_forever()


if __name__ == "__main__":
    main()
