#include "totvs.ch"
#include "../../src/GEBDB_CORE.prw"
#include "../../src/GENUC_MIG.prw"
#include "../../src/GEBBOLIB.prw"
#include "../../src/GEBDFE_XML.prw"

/*/{Protheus.doc} T_GEBDFE_XML
    Teste local (sem banco) do motor de documentos fiscais: confere chave,
    DV, hora local da UF e limpeza de texto, e grava em ../.out/local os
    documentos assinados com o certificado de teste (gerado por
    T_GEBDFE_XML.sh) para o script validar contra os XSD oficiais e
    conferir digest, assinatura e QR Code offline com lxml/cryptography.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function T_GEBDFE_XML()
    Local cDir := "../.out/local/"
    Local cKey := MemoRead(cDir + "key.pem")
    Local cCert := MemoRead(cDir + "cert.pem")
    Local lOk := .T.
    Local aR := {}
    Local aA := {}
    Local aQ := {}
    Local oNF := Nil
    Local oQ := Nil
    Local oX := Nil
    Local cXml := ""
    Local cEv := ""
    Local nI := 0

    lOk := Chk(lOk, "dv chave exemplo NT", GEBDFEDV("4315010828769300015765101000000097100000125") == "1")
    lOk := Chk(lOk, "dv resto 0/1 vira 0", GEBDFEDV(Replicate("0", 43)) == "0" .And. GEBDFEDV(Replicate("0", 41) + "11") == "6")
    lOk := Chk(lOk, "cuf SP", GEBDFECUF("sp") == "35" .And. GEBDFEUFSIG("43") == "RS" .And. GEBDFECUF("XX") == "")
    aA := GEBDFEAGORA("SP", "2026-10-19T02:30:00Z")
    lOk := Chk(lOk, "agora SP volta um dia", aA[1] == "20261018" .And. aA[2] == "23:30:00" .And. aA[3] == "2026-10-18T23:30:00-03:00")
    aA := GEBDFEAGORA("AC", "2026-12-31T23:59:59Z")
    lOk := Chk(lOk, "agora AC", aA[3] == "2026-12-31T18:59:59-05:00")
    aA := GEBDFEAGORA("SP", "2026-02-28T23:00:00Z")
    lOk := Chk(lOk, "agora SP mesmo dia", aA[3] == "2026-02-28T20:00:00-03:00")
    lOk := Chk(lOk, "txt acento", GEBDFETXT("  P" + Chr(227) + "o  de queijo & caf" + Chr(233) + " <esp> " + Chr(10) + "x", 60) == ;
        "Pao de queijo &amp; cafe &lt;esp&gt; x")
    lOk := Chk(lOk, "txt corta", GEBDFETXT("abcdef", 3) == "abc")
    lOk := Chk(lOk, "num", GEBDFEN(1234.5, 2) == "1234.50" .And. GEBDFEN(2, 4) == "2.0000")
    lOk := Chk(lOk, "chave 44", Len(GEBDFECHAVE("35", "2610", "12345678000195", "65", 1, 123, "1", "12345678")) == 44)
    lOk := Chk(lOk, "certificado lido", !(GEBDFECERTB64(cCert) == ""))

    // NFC-e online em homologacao (Simples, CSOSN 102, dinheiro com troco + debito).
    oNF := NFCe("1")
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta nfce", aR[1])
    If aR[1]
        lOk := Chk(lOk, "vNF e troco", aR[3][3] == 25.60 .And. aR[3][4] == 4.40)
        oQ := JsonObject():New()
        oQ["URL"] := "https://www.homologacao.nfce.fazenda.sp.gov.br/qrcode"
        oQ["VERSAO"] := "3"
        oQ["CHAVE"] := aR[3][2]
        oQ["TPAMB"] := "2"
        oQ["TPEMIS"] := "1"
        aQ := GEBDFEQRCODE(oQ)
        lOk := Chk(lOk, "qr v3 online", aQ[1] .And. aQ[3] == oQ["URL"] + "?p=" + aR[3][2] + "|3|2")
        cXml := GEBDFESUPL(aR[3][1], aQ[3], "www.homologacao.nfce.fazenda.sp.gov.br/consulta")
        aA := GEBDFEASSINA(cXml, "infNFe", "NFe", cKey, cCert)
        lOk := Chk(lOk, "assina nfce", aA[1])
        MemoWrite(cDir + "nfce.xml", aA[3])
        MemoWrite(cDir + "lote.xml", GEBDFELOTE(aA[3], "000000000000001"))
        MemoWrite(cDir + "soap.xml", GEBDFESOAP("NFeAutorizacao4", GEBDFELOTE(aA[3], "000000000000001")))

        // QR v2 (CSC) online.
        oQ["VERSAO"] := "2"
        oQ["IDCSC"] := "000001"
        oQ["CSC"] := "CSCTESTE123"
        aQ := GEBDFEQRCODE(oQ)
        MemoWrite(cDir + "qr2.txt", aR[3][2] + Chr(10) + aQ[3])

        // Cancelamento do documento.
        cEv := GEBDFEEVCANC(aR[3][2], "12345678000195", "2", "135260000000001", "Cliente desistiu da compra", "2026-10-19T10:00:00-03:00", 1)
        aA := GEBDFEASSINA(cEv, "infEvento", "evento", cKey, cCert)
        lOk := Chk(lOk, "assina evento", aA[1])
        MemoWrite(cDir + "evento.xml", GEBDFELOTEEV(aA[3], "000000000000002"))
    EndIf

    // NFC-e offline (tpEmis 9) com CPF: QR v3 assinado.
    oNF := NFCe("9")
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta nfce offline", aR[1])
    If aR[1]
        oQ := JsonObject():New()
        oQ["URL"] := "https://www.homologacao.nfce.fazenda.sp.gov.br/qrcode"
        oQ["VERSAO"] := "3"
        oQ["CHAVE"] := aR[3][2]
        oQ["TPAMB"] := "2"
        oQ["TPEMIS"] := "9"
        oQ["DHEMI"] := oNF["DHEMI"]
        oQ["VNF"] := aR[3][3]
        oQ["TPIDDEST"] := "2"
        oQ["IDDEST"] := "11144477735"
        oQ["KEYPEM"] := cKey
        aQ := GEBDFEQRCODE(oQ)
        lOk := Chk(lOk, "qr v3 offline", aQ[1] .And. Len(aQ[3]) < 1000)
        MemoWrite(cDir + "qr3off.txt", aQ[3])
        aA := GEBDFEASSINA(GEBDFESUPL(aR[3][1], aQ[3], "www.homologacao.nfce.fazenda.sp.gov.br/consulta"), "infNFe", "NFe", cKey, cCert)
        lOk := Chk(lOk, "assina nfce offline", aA[1])
        MemoWrite(cDir + "nfce_off.xml", aA[3])
    EndIf

    // NF-e modelo 55, regime normal (CST 00, PIS/COFINS 01), destinatario PJ.
    oNF := NFe55()
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta nfe 55", aR[1])
    If aR[1]
        aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", cKey, cCert)
        MemoWrite(cDir + "nfe55.xml", aA[3])
    EndIf

    // NF-e de venda a prazo: duplicatas e indPag 1 (boleto).
    oNF := NFe55()
    oX := JsonObject():New()
    oX["INDPAG"] := "1"
    oX["TPAG"] := "15"
    oX["VPAG"] := 800
    oNF["PAG"] := {oX}
    oNF["COBR"] := {"PV000123", 800, 0, 800, {{"001", "20261118", 400}, {"002", "20261218", 400}}}
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta nfe com duplicatas", aR[1] .And. "<dup><nDup>001</nDup><dVenc>2026-11-18</dVenc><vDup>400.00</vDup></dup>" $ aR[3][1])
    If aR[1]
        aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", cKey, cCert)
        MemoWrite(cDir + "nfe55cobr.xml", aA[3])
    EndIf

    // NF-e de entrada de devolucao de venda (finalidade 4, NF-e referenciada, CSOSN 900, PIS/COFINS 98).
    oNF := NFe55()
    oNF["EMIT"] := Emit("1")
    oNF["TPNF"] := "0"
    oNF["FINNFE"] := "4"
    oNF["NATOP"] := "Devolucao de venda"
    oNF["NFREF"] := {"35261012345678000195550010000000011123456787"}
    oNF["PAG"] := {}
    oX := oNF["ITENS"][1]
    oX["CST"] := ""
    oX["CSOSN"] := "900"
    oX["CFOP"] := "2202"
    oX["PISCST"] := "98"
    oX["COFINSCST"] := "98"
    oX["PPIS"] := 0
    oX["PCOFINS"] := 0
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta nfe de devolucao", aR[1] .And. "<finNFe>4</finNFe>" $ aR[3][1] .And. "<NFref><refNFe>" $ aR[3][1] .And. ;
        "<tPag>90</tPag>" $ aR[3][1])
    If aR[1]
        aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", cKey, cCert)
        MemoWrite(cDir + "nfe55dev.xml", aA[3])
    EndIf

    // Regime normal para consumidor de outra UF: CST 10 (ST por MVA), CST 20 (reducao) e DIFAL.
    oNF := NFe55()
    oX := oNF["DEST"]
    oX["CNPJ"] := ""
    oX["CPF"] := "11144477735"
    oX["INDIEDEST"] := "9"
    oX["IE"] := ""
    oNF["INDFINAL"] := "1"
    oNF["DIFAL"] := {20, 2, .F.}
    oX := oNF["ITENS"][1]
    oX["CST"] := "10"
    oX["PICMS"] := 12
    oX["MVA"] := 40
    oX["PICMSST"] := 20
    oX := Item("PQ01", "Queijo", "", 2, 100, 0)
    oX["CSOSN"] := ""
    oX["CST"] := "20"
    oX["PICMS"] := 12
    oX["PREDBC"] := 33.33
    aAdd(oNF["ITENS"], oX)
    oX := JsonObject():New()
    oX["TPAG"] := "15"
    oX["VPAG"] := 2000
    oNF["PAG"] := {oX}
    aR := GEBDFEMONTA(oNF)
    // Item 1: 800; BCST 1120; ST 1120*20% - 96 = 128. Item 2: 200; BC 133.34; ICMS 16.00.
    // DIFAL base unica: (800 + 200) x (20 - 12)% = 80.00; FCP 2% = 20.00. vNF = 1000 + 128 = 1128.
    lOk := Chk(lOk, "monta nfe st/difal", aR[1] .And. "<vBCST>1120.00</vBCST>" $ aR[3][1] .And. "<vICMSST>128.00</vICMSST>" $ aR[3][1] .And. ;
        "<vBC>133.34</vBC>" $ aR[3][1] .And. "<vICMSUFDest>80.00</vICMSUFDest>" $ aR[3][1] .And. "<vFCPUFDest>20.00</vFCPUFDest>" $ aR[3][1] .And. ;
        "<vNF>1128.00</vNF>" $ aR[3][1] .And. aR[3][6] == 100)
    If aR[1]
        aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", cKey, cCert)
        MemoWrite(cDir + "nfe55st.xml", aA[3])
    EndIf
    // IBS/CBS (NT 2025.002, aliquotas de teste de 2026) e tributos aproximados (Lei 12.741).
    oNF["IBSCBS"] := .T.
    For nI := 1 To Len(oNF["ITENS"])
        oX := oNF["ITENS"][nI]
        oX["PIBSUF"] := 0.1
        oX["PIBSMUN"] := 0
        oX["PCBS"] := 0.9
        oX["VTOTTRIB"] := 10 * nI
    Next nI
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta ibs/cbs e vTotTrib", aR[1] .And. "<IBSCBS><CST>000</CST><cClassTrib>000001</cClassTrib>" $ aR[3][1] .And. ;
        "<vBCIBSCBS>1000.00</vBCIBSCBS>" $ aR[3][1] .And. "<vIBSUF>1.00</vIBSUF>" $ aR[3][1] .And. "<vCBS>9.00</vCBS>" $ aR[3][1] .And. ;
        "<vTotTrib>30.00</vTotTrib>" $ aR[3][1])
    If aR[1]
        aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", cKey, cCert)
        MemoWrite(cDir + "nfe55ibs.xml", aA[3])
    EndIf
    oNF["IBSCBS"] := Nil

    // Base dupla (LC 190): BC = (V - V x 12%) / (1 - 20%); DIFAL = BC x 20% - V x 12%.
    oNF["DIFAL"] := {20, 0, .T.}
    aR := GEBDFEMONTA(oNF)
    // Item 1: (800 - 96) / 0,8 = 880; 880 x 20% - 96 = 80. Item 2: (200 - 24) / 0,8 = 220; 44 - 24 = 20.
    lOk := Chk(lOk, "difal base dupla", aR[1] .And. "<vBCUFDest>880.00</vBCUFDest>" $ aR[3][1] .And. "<vICMSUFDest>80.00</vICMSUFDest>" $ aR[3][1] .And. ;
        "<vBCUFDest>220.00</vBCUFDest>" $ aR[3][1] .And. "<vICMSUFDest>20.00</vICMSUFDest>" $ aR[3][1] .And. aR[3][6] == 100)

    // Simples com ST: CSOSN 201 (credito) e 202.
    oNF := NFe55()
    oNF["EMIT"] := Emit("1")
    oX := oNF["ITENS"][1]
    oX["CST"] := ""
    oX["CSOSN"] := "201"
    oX["PCREDSN"] := 2.5
    oX["PICMS"] := 18
    oX["MVA"] := 30
    oX["PICMSST"] := 18
    oX := Item("PQ01", "Queijo", "", 1, 100, 0)
    oX["CSOSN"] := "202"
    oX["PICMS"] := 18
    oX["MVA"] := 30
    oX["PICMSST"] := 18
    aAdd(oNF["ITENS"], oX)
    oX := JsonObject():New()
    oX["TPAG"] := "15"
    oX["VPAG"] := 2000
    oNF["PAG"] := {oX}
    aR := GEBDFEMONTA(oNF)
    lOk := Chk(lOk, "monta simples st", aR[1] .And. "<ICMSSN201>" $ aR[3][1] .And. "<ICMSSN202>" $ aR[3][1] .And. "<vICMSST>43.20</vICMSST>" $ aR[3][1])
    If aR[1]
        aA := GEBDFEASSINA(aR[3][1], "infNFe", "NFe", cKey, cCert)
        MemoWrite(cDir + "nfe55sn.xml", aA[3])
    EndIf

    // Distribuicao de DF-e e manifestacao do destinatario.
    MemoWrite(cDir + "dist_nsu.xml", GEBDFEDISTMSG("2", "35", "12345678000195", "42", ""))
    MemoWrite(cDir + "dist_ch.xml", GEBDFEDISTMSG("2", "35", "12345678000195", "", "35261011444777000161550010000004561000004562"))
    aA := GEBDFEASSINA(GEBDFEEVMANIF("35261011444777000161550010000004561000004562", "12345678000195", "2", "210240", "Operacao nao Realizada", ;
        "Mercadoria devolvida na portaria", "2026-10-19T11:00:00-03:00"), "infEvento", "evento", cKey, cCert)
    lOk := Chk(lOk, "manifestacao", aA[1] .And. "<cOrgao>91</cOrgao>" $ aA[3] .And. "<xJust>Mercadoria devolvida na portaria</xJust>" $ aA[3])
    MemoWrite(cDir + "manif.xml", GEBDFELOTEEV(aA[3], "000000000000009"))

    // Carta de correcao.
    aA := GEBDFEASSINA(GEBDFEEVCCE("35261012345678000195550010000000011123456787", "12345678000195", "2", "Corrige o endereco de entrega & complemento", ;
        "2026-10-19T11:00:00-03:00", 1), "infEvento", "evento", cKey, cCert)
    lOk := Chk(lOk, "assina carta de correcao", aA[1] .And. "&amp; complemento" $ aA[3])
    MemoWrite(cDir + "cce.xml", GEBDFELOTEEV(aA[3], "000000000000003"))

    // Inutilizacao, status e consulta.
    aA := GEBDFEASSINA(GEBDFEINUT("2", "35", "26", "12345678000195", "65", 1, 10, 12, "Falha de sistema na emissao"), "infInut", "inutNFe", cKey, cCert)
    lOk := Chk(lOk, "assina inutilizacao", aA[1])
    MemoWrite(cDir + "inut.xml", aA[3])
    MemoWrite(cDir + "status.xml", GEBDFESTATUS("2", "35"))
    MemoWrite(cDir + "consulta.xml", GEBDFECONSULTA("2", "35261012345678000195650010000000011123456780"))

    // Recusas.
    oNF := NFCe("1")
    oX := oNF["ITENS"][1]
    oX["NCM"] := "123"
    lOk := Chk(lOk, "recusa ncm", !GEBDFEMONTA(oNF)[1])
    oNF := NFCe("1")
    oX := oNF["PAG"][1]
    oX["VPAG"] := 1
    oX := oNF["PAG"][2]
    oX["VPAG"] := 1
    lOk := Chk(lOk, "recusa pagamento menor", !GEBDFEMONTA(oNF)[1])
    oNF := NFCe("1")
    oX := oNF["ITENS"][1]
    oX["CSOSN"] := "999"
    lOk := Chk(lOk, "recusa csosn inexistente", !GEBDFEMONTA(oNF)[1])
    lOk := Chk(lOk, "tag do retorno", GEBDFETAG("<a><ns2:cStat>100</ns2:cStat><xMotivo>Autorizado</xMotivo></a>", "cStat") == "100" .And. ;
        GEBDFETAG("<b><xMotivo>Ok</xMotivo></b>", "xMotivo") == "Ok")

    If lOk
        ConOut("T_GEBDFE_XML PASS")
    Else
        ConOut("T_GEBDFE_XML FAIL")
    EndIf
Return lOk

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.

Static Function Emit(cCRT)
    Local oE := JsonObject():New()
    oE["CNPJ"] := "12.345.678/0001-95"
    oE["XNOME"] := "Empresa Teste Ltda"
    oE["XFANT"] := "Loja Teste"
    oE["XLGR"] := "Rua das Bananeiras"
    oE["NRO"] := "100"
    oE["XBAIRRO"] := "Centro"
    oE["CMUN"] := "3550308"
    oE["XMUN"] := "SAO PAULO"
    oE["UF"] := "SP"
    oE["CEP"] := "01001-000"
    oE["FONE"] := "(11) 3333-4444"
    oE["IE"] := "123456789012"
    oE["CRT"] := cCRT
Return oE

Static Function Item(cProd, cDesc, cEan, nQtd, nPreco, nDesc)
    Local oI := JsonObject():New()
    oI["CPROD"] := cProd
    oI["CEAN"] := cEan
    oI["XPROD"] := cDesc
    oI["NCM"] := "08039000"
    oI["CFOP"] := "5102"
    oI["UCOM"] := "UN"
    oI["QCOM"] := nQtd
    oI["VUNCOM"] := nPreco
    oI["VDESC"] := nDesc
    oI["ORIG"] := "0"
    oI["CSOSN"] := "102"
Return oI

Static Function Pag(cTp, nVal)
    Local oP := JsonObject():New()
    oP["TPAG"] := cTp
    oP["VPAG"] := nVal
    oP["TPINTEGRA"] := "2"
Return oP

Static Function NFCe(cTpEmis)
    Local oNF := JsonObject():New()
    Local oD := Nil
    oNF["MOD"] := "65"
    oNF["SERIE"] := 1
    oNF["NNF"] := 123
    oNF["CNF"] := "12345678"
    oNF["TPEMIS"] := cTpEmis
    oNF["DHEMI"] := "2026-10-19T10:15:30-03:00"
    oNF["TPAMB"] := "2"
    oNF["NATOP"] := "Venda ao consumidor"
    oNF["CMUNFG"] := "3550308"
    oNF["VERPROC"] := "GEBAN 1.0"
    oNF["EMIT"] := Emit("1")
    oNF["ITENS"] := {Item("BAN01", "Banana prata kg", "7891234567895", 1.5, 6.40, 0), ;
        Item("PQ01", "P" + Chr(227) + "o de queijo & caf" + Chr(233) + " <especial>", "", 3, 5.50, 0.50)}
    oNF["PAG"] := {Pag("01", 20), Pag("04", 10)}
    oNF["INFCPL"] := "Volte sempre"
    If cTpEmis == "9"
        oNF["DHCONT"] := "2026-10-19T10:10:00-03:00"
        oNF["XJUST"] := "Sem comunicacao com a SEFAZ autorizadora"
        oD := JsonObject():New()
        oD["CPF"] := "111.444.777-35"
        oD["INDIEDEST"] := "9"
        oNF["DEST"] := oD
        oNF["PAG"] := {Pag("01", 30)}
    EndIf
Return oNF

Static Function NFe55()
    Local oNF := JsonObject():New()
    Local oD := JsonObject():New()
    Local oI := Item("BAN01", "Banana prata caixa 20kg", "", 10, 80, 0)
    Local oRT := JsonObject():New()
    oI["CSOSN"] := ""
    oI["CST"] := "00"
    oI["PICMS"] := 18
    oI["PISCST"] := "01"
    oI["PPIS"] := 1.65
    oI["COFINSCST"] := "01"
    oI["PCOFINS"] := 7.6
    oD["CNPJ"] := "11222333000181"
    oD["XNOME"] := "Cliente Atacado SA"
    oD["XLGR"] := "Av Brasil"
    oD["NRO"] := "1"
    oD["XBAIRRO"] := "Jardim"
    oD["CMUN"] := "3304557"
    oD["XMUN"] := "RIO DE JANEIRO"
    oD["UF"] := "RJ"
    oD["CEP"] := "20000000"
    oD["INDIEDEST"] := "1"
    oD["IE"] := "12345678"
    oRT["CNPJ"] := "12345678000195"
    oRT["XCONTATO"] := "Suporte GEBAN"
    oRT["EMAIL"] := "suporte@exemplo.com.br"
    oRT["FONE"] := "1133334444"
    oNF["MOD"] := "55"
    oNF["SERIE"] := 1
    oNF["NNF"] := 1
    oNF["TPEMIS"] := "1"
    oNF["DHEMI"] := "2026-10-19T10:15:30-03:00"
    oNF["TPAMB"] := "2"
    oNF["NATOP"] := "Venda de mercadoria"
    oNF["CMUNFG"] := "3550308"
    oNF["IDDEST"] := "2"
    oNF["INDFINAL"] := "0"
    oNF["INDPRES"] := "9"
    oNF["EMIT"] := Emit("3")
    oNF["DEST"] := oD
    oNF["ITENS"] := {oI}
    oNF["PAG"] := {Pag("15", 800)}
    oNF["RESPTEC"] := oRT
Return oNF
