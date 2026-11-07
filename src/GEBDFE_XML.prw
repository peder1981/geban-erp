#include "totvs.ch"
#include "GEBBOLIB.prw"

/*/{Protheus.doc} GEBDFE_XML
    Funcoes puras (sem banco) dos documentos fiscais eletronicos 4.00
    (NF-e modelo 55 e NFC-e modelo 65), conferidas contra os XSD oficiais
    (PL_010_V1.30) em tests/local/T_GEBDFE_XML.sh:
    - UF (codigo IBGE e fuso), hora local da UF a partir do UTC (o servidor
      de producao roda em UTC), chave de acesso e DV (modulo 11).
    - GEBDFEMONTA(oNF): XML <NFe> sem assinatura, ja na forma canonica
      (sem espacos entre tags, atributos em ordem, so &, < e > escapados no
      texto), entao o digest e' o SHA-1 do proprio trecho <infNFe> com o
      namespace herdado.
    - GEBDFEASSINA: XMLDSig envelopada (RSA-SHA1, C14N 20010315), igual a
      exigida pela SEFAZ para infNFe, infEvento e infInut.
    - GEBDFEQRCODE: QR Code da NFC-e, versao 3 (NT 2025.001: online sem
      CSC; offline com assinatura RSA-SHA1 dos campos) e versao 2 (CSC).
    - Mensagens: evento de cancelamento, inutilizacao, status, consulta,
      lote de autorizacao, envelope SOAP 1.2 e leitura de tags do retorno.
    oNF e' um JsonObject com chaves em maiusculas (ver GEBDFEMONTA).
    @type Biblioteca
    @author Peder Munksgaard
    @since 19/10/2026
/*/

#define DFE_NS "http://www.portalfiscal.inf.br/nfe"
#define DFE_DS "http://www.w3.org/2000/09/xmldsig#"
#define DFE_C14N "http://www.w3.org/TR/2001/REC-xml-c14n-20010315"

// {sigla, codigo IBGE, fuso}
User Function GEBDFEUFS()
Return {{"RO", "11", "-04:00"}, {"AC", "12", "-05:00"}, {"AM", "13", "-04:00"}, {"RR", "14", "-04:00"}, {"PA", "15", "-03:00"}, ;
    {"AP", "16", "-03:00"}, {"TO", "17", "-03:00"}, {"MA", "21", "-03:00"}, {"PI", "22", "-03:00"}, {"CE", "23", "-03:00"}, ;
    {"RN", "24", "-03:00"}, {"PB", "25", "-03:00"}, {"PE", "26", "-03:00"}, {"AL", "27", "-03:00"}, {"SE", "28", "-03:00"}, ;
    {"BA", "29", "-03:00"}, {"MG", "31", "-03:00"}, {"ES", "32", "-03:00"}, {"RJ", "33", "-03:00"}, {"SP", "35", "-03:00"}, ;
    {"PR", "41", "-03:00"}, {"SC", "42", "-03:00"}, {"RS", "43", "-03:00"}, {"MS", "50", "-04:00"}, {"MT", "51", "-04:00"}, ;
    {"GO", "52", "-03:00"}, {"DF", "53", "-03:00"}}

// Codigo IBGE da UF ("" se nao existir).
User Function GEBDFECUF(cUF)
    Local aU := GEBDFEUFS()
    Local nP := AScan(aU, {|x| x[1] == Upper(AllTrim(cUF))})
    If nP == 0
        Return ""
    EndIf
Return aU[nP][2]

User Function GEBDFEUFSIG(cCod)
    Local aU := GEBDFEUFS()
    Local nP := AScan(aU, {|x| x[2] == AllTrim(cCod)})
    If nP == 0
        Return ""
    EndIf
Return aU[nP][1]

User Function GEBDFEFUSO(cUF)
    Local aU := GEBDFEUFS()
    Local nP := AScan(aU, {|x| x[1] == Upper(AllTrim(cUF))})
    If nP == 0
        Return "-03:00"
    EndIf
Return aU[nP][3]

/*/{Protheus.doc} GEBDFEAGORA
    Data e hora local da UF calculadas do UTC (DateTimeUTC), qualquer que
    seja o fuso do servidor. cUTC (opcional, "AAAA-MM-DDTHH:MM:SSZ") fixa o
    instante (testes).
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
    @return {cData AAAAMMDD, cHora HH:MM:SS, cDh AAAA-MM-DDTHH:MM:SS-03:00}
/*/
User Function GEBDFEAGORA(cUF, cUTC)
    Local cFuso := GEBDFEFUSO(cUF)
    Local cData := ""
    Local nSeg := 0
    Local nOff := 0
    Local nJ := 0
    If cUTC == Nil .Or. Empty(cUTC)
        cUTC := DateTimeUTC()
    EndIf
    cData := StrTran(Left(cUTC, 10), "-", "")
    nSeg := Val(SubStr(cUTC, 12, 2)) * 3600 + Val(SubStr(cUTC, 15, 2)) * 60 + Val(SubStr(cUTC, 18, 2))
    nOff := (Val(SubStr(cFuso, 2, 2)) * 3600 + Val(SubStr(cFuso, 5, 2)) * 60)
    If Left(cFuso, 1) == "-"
        nOff := -nOff
    EndIf
    nSeg := nSeg + nOff
    nJ := BOJDN(cData)
    Do While nSeg < 0
        nSeg += 86400
        nJ--
    EndDo
    Do While nSeg >= 86400
        nSeg -= 86400
        nJ++
    EndDo
    cData := BODEJDN(nJ)
Return {cData, StrZero(Int(nSeg / 3600), 2) + ":" + StrZero(Int((nSeg % 3600) / 60), 2) + ":" + StrZero(nSeg % 60, 2), ;
    Left(cData, 4) + "-" + SubStr(cData, 5, 2) + "-" + Right(cData, 2) + "T" + StrZero(Int(nSeg / 3600), 2) + ":" + ;
    StrZero(Int((nSeg % 3600) / 60), 2) + ":" + StrZero(nSeg % 60, 2) + cFuso}

// DV modulo 11 da chave (pesos 2 a 9 da direita; resto 0 ou 1 => 0).
User Function GEBDFEDV(c43)
    Local nSoma := 0
    Local nPeso := 2
    Local nI := 0
    Local nR := 0
    For nI := Len(c43) To 1 Step -1
        nSoma += Val(SubStr(c43, nI, 1)) * nPeso
        nPeso++
        If nPeso > 9
            nPeso := 2
        EndIf
    Next nI
    nR := nSoma % 11
    If nR < 2
        Return "0"
    EndIf
Return cValToChar(11 - nR)

// Chave de acesso: cUF AAMM CNPJ mod serie nNF tpEmis cNF DV (44 digitos).
User Function GEBDFECHAVE(cCUF, cAAMM, cCNPJ, cMod, nSerie, nNF, cTpEmis, cCNF)
    Local c43 := cCUF + cAAMM + PadL(GEBDFEDIG(cCNPJ), 14, "0") + cMod + StrZero(nSerie, 3) + StrZero(nNF, 9) + cTpEmis + cCNF
Return c43 + GEBDFEDV(c43)

// Codigo numerico aleatorio de 8 digitos, diferente do numero da nota.
User Function GEBDFECNF(nNF)
    Local cC := ""
    Do While .T.
        cC := StrZero(Randomize(10000000, 99999999), 8)
        If !(cC == StrZero(nNF, 8))
            Exit
        EndIf
    EndDo
Return cC

// So os digitos.
User Function GEBDFEDIG(c)
    Local cR := ""
    Local nI := 0
    c := BOSTR(c)
    For nI := 1 To Len(c)
        If SubStr(c, nI, 1) $ "0123456789"
            cR += SubStr(c, nI, 1)
        EndIf
    Next nI
Return cR

/*/{Protheus.doc} GEBDFETXT
    Texto para o XML: troca letras acentuadas (UTF-8) pela letra sem
    acento, tira o que nao for ASCII imprimivel, junta espacos repetidos,
    apara, corta em nMax e escapa &, < e > (forma canonica).
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFETXT(cTxt, nMax)
    Local aMap := {{192, 197, "A"}, {199, 199, "C"}, {200, 203, "E"}, {204, 207, "I"}, {209, 209, "N"}, {210, 214, "O"}, {216, 216, "O"}, ;
        {217, 220, "U"}, {221, 221, "Y"}, {224, 229, "a"}, {231, 231, "c"}, {232, 235, "e"}, {236, 239, "i"}, {241, 241, "n"}, ;
        {242, 246, "o"}, {248, 248, "o"}, {249, 252, "u"}, {253, 253, "y"}, {255, 255, "y"}, {186, 186, "o"}, {170, 170, "a"}, {176, 176, "o"}}
    Local cR := ""
    Local cC := ""
    Local nI := 0
    Local nJ := 0
    Local nA := 0
    cTxt := BOSTR(cTxt)
    For nI := 1 To Len(aMap)
        For nJ := aMap[nI][1] To aMap[nI][2]
            cTxt := StrTran(cTxt, Chr(nJ), aMap[nI][3])
        Next nJ
    Next nI
    For nI := 1 To Len(cTxt)
        cC := SubStr(cTxt, nI, 1)
        nA := Asc(cC)
        If nA < 32 .Or. nA > 126
            cC := " "
        EndIf
        If !(cC == " " .And. Right(cR, 1) == " ")
            cR += cC
        EndIf
    Next nI
    cR := AllTrim(cR)
    If nMax != Nil .And. Len(cR) > nMax
        cR := AllTrim(Left(cR, nMax))
    EndIf
Return GEBDFEESC(cR)

User Function GEBDFEESC(c)
    c := StrTran(c, "&", "&amp;")
    c := StrTran(c, "<", "&lt;")
Return StrTran(c, ">", "&gt;")

// Numero com ponto e nDec casas.
User Function GEBDFEN(nVal, nDec)
Return AllTrim(Str(Round(BOVAL(nVal), nDec), 20, nDec))

Static Function DFETag(cTag, cVal)
Return "<" + cTag + ">" + cVal + "</" + cTag + ">"

// Tag so se houver valor.
Static Function DFETagOpc(cTag, cVal)
    If BOCOL(cVal) == ""
        Return ""
    EndIf
Return "<" + cTag + ">" + cVal + "</" + cTag + ">"

Static Function DFEJ(oJ, cCampo)
    If oJ == Nil
        Return ""
    EndIf
Return BOCOL(oJ[cCampo])

Static Function DFEJN(oJ, cCampo)
    If oJ == Nil
        Return 0
    EndIf
Return BOVAL(oJ[cCampo])

/*/{Protheus.doc} GEBDFEMONTA
    Monta o <NFe> (sem infNFeSupl e sem assinatura). oNF (JsonObject):
    MOD (55|65), SERIE, NNF, CNF (vazio = aleatorio), TPEMIS (1|9), DHEMI,
    DHCONT/XJUST (contingencia), TPAMB (1|2), NATOP, CMUNFG, FINNFE (1|4),
    INDFINAL, INDPRES, IDDEST, TPNF (1 saida|0 entrada), VERPROC, NFREF
    (array de chaves), INFCPL,
    EMIT {CNPJ, XNOME, XFANT, XLGR, NRO, XCPL, XBAIRRO, CMUN, XMUN, UF, CEP,
    FONE, IE, IM, CNAE, CRT},
    DEST (opcional) {CNPJ|CPF, XNOME, XLGR, NRO, XBAIRRO, CMUN, XMUN, UF,
    CEP, INDIEDEST, IE, EMAIL},
    ITENS [{CPROD, CEAN, XPROD, NCM, CEST, CFOP, UCOM, QCOM, VUNCOM, VDESC,
    ORIG, CSOSN|CST, PICMS, PCREDSN, PREDBC, MVA, PICMSST, PREDBCST, PISCST,
    COFINSCST, PPIS, PCOFINS, VTOTTRIB, IBSCST, CCLASSTRIB, PIBSUF, PIBSMUN,
    PCBS}], DIFAL (opcional) {pInternaDestino, pFCP, lBaseDupla}, IBSCBS (.T.
    emite o grupo IBS/CBS por item e o total IBSCBSTot),
    PAG [{INDPAG, TPAG, VPAG, XPAG, TPINTEGRA, CNPJCRED, TBAND, CAUT}],
    COBR (NF-e, opcional) {nFat, vOrig, vDesc, vLiq, {{nDup, dVenc, vDup}...}},
    RESPTEC (opcional) {CNPJ, XCONTATO, EMAIL, FONE}.
    vProd = Round(qCom * vUnCom, 2); vNF = soma(vProd) - soma(vDesc).
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cXml, cChave, nVNF, nTroco}}
/*/
User Function GEBDFEMONTA(oNF)
    Local oE := oNF["EMIT"]
    Local oD := oNF["DEST"]
    Local aIt := oNF["ITENS"]
    Local aPg := oNF["PAG"]
    Local aRef := oNF["NFREF"]
    Local aDif := oNF["DIFAL"]
    Local aPC := {}
    Local aSt := {}
    Local aD := {}
    Local nVBCST := 0
    Local nVST := 0
    Local nTBCST := 0
    Local nTST := 0
    Local nTDif := 0
    Local nTFcpD := 0
    Local nTTrib := 0
    Local aTIbs := {0, 0, 0, 0}
    Local cMod := DFEJ(oNF, "MOD")
    Local cTpEmis := DFEJ(oNF, "TPEMIS")
    Local cTpAmb := DFEJ(oNF, "TPAMB")
    Local cCUF := GEBDFECUF(DFEJ(oE, "UF"))
    Local cCNF := DFEJ(oNF, "CNF")
    Local cChave := ""
    Local cX := ""
    Local cDet := ""
    Local cImp := ""
    Local cIcms := ""
    Local cCst := ""
    Local cOrig := ""
    Local cHom := "NOTA FISCAL EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL"
    Local cXProd := ""
    Local cGtin := ""
    Local cPag := ""
    Local nSerie := DFEJN(oNF, "SERIE")
    Local nNF := DFEJN(oNF, "NNF")
    Local nVProd := 0
    Local nVDesc := 0
    Local nVBC := 0
    Local nVICMS := 0
    Local nVPIS := 0
    Local nVCOF := 0
    Local nTProd := 0
    Local nTDesc := 0
    Local nTBC := 0
    Local nTICMS := 0
    Local nTPIS := 0
    Local nTCOF := 0
    Local nVNF := 0
    Local nTPag := 0
    Local nTroco := 0
    Local nQ := 0
    Local nI := 0

    If !(cMod == "55" .Or. cMod == "65")
        Return {.F., "modelo_invalido: " + cMod, {}}
    EndIf
    If cCUF == ""
        Return {.F., "uf_do_emitente_invalida", {}}
    EndIf
    If aIt == Nil .Or. Len(aIt) == 0
        Return {.F., "sem_itens", {}}
    EndIf
    If Len(aIt) > 990
        Return {.F., "mais_de_990_itens", {}}
    EndIf
    If cTpEmis == ""
        cTpEmis := "1"
    EndIf
    If cCNF == ""
        cCNF := GEBDFECNF(nNF)
    EndIf
    cChave := GEBDFECHAVE(cCUF, SubStr(DFEJ(oNF, "DHEMI"), 3, 2) + SubStr(DFEJ(oNF, "DHEMI"), 6, 2), DFEJ(oE, "CNPJ"), cMod, nSerie, nNF, cTpEmis, cCNF)

    // Itens e totais.
    For nI := 1 To Len(aIt)
        nQ := DFEJN(aIt[nI], "QCOM")
        If nQ <= 0 .Or. DFEJN(aIt[nI], "VUNCOM") <= 0
            Return {.F., "item_" + cValToChar(nI) + "_quantidade_ou_preco_invalidos", {}}
        EndIf
        nVProd := Round(nQ * DFEJN(aIt[nI], "VUNCOM"), 2)
        nVDesc := Round(DFEJN(aIt[nI], "VDESC"), 2)
        If nVDesc < 0 .Or. nVDesc >= nVProd
            Return {.F., "item_" + cValToChar(nI) + "_desconto_invalido", {}}
        EndIf
        cXProd := GEBDFETXT(DFEJ(aIt[nI], "XPROD"), 120)
        If nI == 1 .And. cTpAmb == "2"
            cXProd := cHom
        EndIf
        If cXProd == ""
            Return {.F., "item_" + cValToChar(nI) + "_sem_descricao", {}}
        EndIf
        If !(Len(GEBDFEDIG(DFEJ(aIt[nI], "NCM"))) == 8 .Or. DFEJ(aIt[nI], "NCM") == "00")
            Return {.F., "item_" + cValToChar(nI) + "_ncm_invalida: " + DFEJ(aIt[nI], "NCM"), {}}
        EndIf
        If !(Len(GEBDFEDIG(DFEJ(aIt[nI], "CFOP"))) == 4)
            Return {.F., "item_" + cValToChar(nI) + "_cfop_invalido", {}}
        EndIf
        cGtin := GEBDFEDIG(DFEJ(aIt[nI], "CEAN"))
        If !(Len(cGtin) == 8 .Or. Len(cGtin) == 12 .Or. Len(cGtin) == 13 .Or. Len(cGtin) == 14)
            cGtin := "SEM GTIN"
        EndIf
        cOrig := DFEJ(aIt[nI], "ORIG")
        If cOrig == ""
            cOrig := "0"
        EndIf

        // ICMS pelo CSOSN (Simples) ou pelo CST (regime normal).
        nVBC := 0
        nVICMS := 0
        nVBCST := 0
        nVST := 0
        cCst := DFEJ(aIt[nI], "CSOSN")
        If !(cCst == "")
            If cCst == "101"
                cIcms := "<ICMSSN101>" + DFETag("orig", cOrig) + DFETag("CSOSN", cCst) + DFETag("pCredSN", GEBDFEN(DFEJN(aIt[nI], "PCREDSN"), 2)) + ;
                    DFETag("vCredICMSSN", GEBDFEN((nVProd - nVDesc) * DFEJN(aIt[nI], "PCREDSN") / 100, 2)) + "</ICMSSN101>"
            ElseIf cCst $ "102|103|300|400"
                cIcms := "<ICMSSN102>" + DFETag("orig", cOrig) + DFETag("CSOSN", cCst) + "</ICMSSN102>"
            ElseIf cCst == "500"
                cIcms := "<ICMSSN500>" + DFETag("orig", cOrig) + DFETag("CSOSN", cCst) + "</ICMSSN500>"
            ElseIf cCst == "900"
                cIcms := "<ICMSSN900>" + DFETag("orig", cOrig) + DFETag("CSOSN", cCst) + "</ICMSSN900>"
            ElseIf cCst $ "201|202|203" .And. Len(cCst) == 3
                aSt := DFEST(aIt[nI], nVProd - nVDesc)
                cIcms := "<ICMSSN" + DFEPadrao2(cCst == "201", "201", "202") + ">" + DFETag("orig", cOrig) + DFETag("CSOSN", cCst) + aSt[1]
                If cCst == "201"
                    cIcms += DFETag("pCredSN", GEBDFEN(DFEJN(aIt[nI], "PCREDSN"), 2)) + ;
                        DFETag("vCredICMSSN", GEBDFEN((nVProd - nVDesc) * DFEJN(aIt[nI], "PCREDSN") / 100, 2))
                EndIf
                cIcms += "</ICMSSN" + DFEPadrao2(cCst == "201", "201", "202") + ">"
                nVBCST := aSt[2]
                nVST := aSt[3]
            Else
                Return {.F., "item_" + cValToChar(nI) + "_csosn_nao_suportado: " + cCst, {}}
            EndIf
        Else
            cCst := DFEJ(aIt[nI], "CST")
            If cCst == "00"
                nVBC := nVProd - nVDesc
                nVICMS := Round(nVBC * DFEJN(aIt[nI], "PICMS") / 100, 2)
                cIcms := "<ICMS00>" + DFETag("orig", cOrig) + DFETag("CST", cCst) + DFETag("modBC", "3") + DFETag("vBC", GEBDFEN(nVBC, 2)) + ;
                    DFETag("pICMS", GEBDFEN(DFEJN(aIt[nI], "PICMS"), 2)) + DFETag("vICMS", GEBDFEN(nVICMS, 2)) + "</ICMS00>"
            ElseIf cCst == "20"
                nVBC := Round((nVProd - nVDesc) * (1 - DFEJN(aIt[nI], "PREDBC") / 100), 2)
                nVICMS := Round(nVBC * DFEJN(aIt[nI], "PICMS") / 100, 2)
                cIcms := "<ICMS20>" + DFETag("orig", cOrig) + DFETag("CST", cCst) + DFETag("modBC", "3") + DFETag("pRedBC", GEBDFEN(DFEJN(aIt[nI], "PREDBC"), 2)) + ;
                    DFETag("vBC", GEBDFEN(nVBC, 2)) + DFETag("pICMS", GEBDFEN(DFEJN(aIt[nI], "PICMS"), 2)) + DFETag("vICMS", GEBDFEN(nVICMS, 2)) + "</ICMS20>"
            ElseIf cCst == "10"
                nVBC := nVProd - nVDesc
                nVICMS := Round(nVBC * DFEJN(aIt[nI], "PICMS") / 100, 2)
                aSt := DFEST(aIt[nI], nVBC)
                cIcms := "<ICMS10>" + DFETag("orig", cOrig) + DFETag("CST", cCst) + DFETag("modBC", "3") + DFETag("vBC", GEBDFEN(nVBC, 2)) + ;
                    DFETag("pICMS", GEBDFEN(DFEJN(aIt[nI], "PICMS"), 2)) + DFETag("vICMS", GEBDFEN(nVICMS, 2)) + aSt[1] + "</ICMS10>"
                nVBCST := aSt[2]
                nVST := aSt[3]
            ElseIf cCst == "40" .Or. cCst == "41" .Or. cCst == "50"
                cIcms := "<ICMS40>" + DFETag("orig", cOrig) + DFETag("CST", cCst) + "</ICMS40>"
            ElseIf cCst == "60"
                cIcms := "<ICMS60>" + DFETag("orig", cOrig) + DFETag("CST", cCst) + "</ICMS60>"
            Else
                Return {.F., "item_" + cValToChar(nI) + "_cst_icms_nao_suportado: " + cCst, {}}
            EndIf
        EndIf
        cImp := "<ICMS>" + cIcms + "</ICMS>"
        If DFEJN(aIt[nI], "VTOTTRIB") > 0
            cImp := DFETag("vTotTrib", GEBDFEN(DFEJN(aIt[nI], "VTOTTRIB"), 2)) + cImp
            nTTrib += Round(DFEJN(aIt[nI], "VTOTTRIB"), 2)
        EndIf
        aPC := DFEPisCof("PIS", DFEJ(aIt[nI], "PISCST"), nVProd - nVDesc, DFEJN(aIt[nI], "PPIS"))
        cImp += "<PIS>" + aPC[1] + "</PIS>"
        nVPIS := aPC[2]
        aPC := DFEPisCof("COFINS", DFEJ(aIt[nI], "COFINSCST"), nVProd - nVDesc, DFEJN(aIt[nI], "PCOFINS"))
        cImp += "<COFINS>" + aPC[1] + "</COFINS>"
        nVCOF := aPC[2]
        If aDif != Nil
            aD := DFEDifal(aDif, nVProd - nVDesc, DFEJN(aIt[nI], "PICMS"))
            cImp += aD[1]
            nTDif += aD[2]
            nTFcpD += aD[3]
        EndIf
        If oNF["IBSCBS"] == .T.
            aD := DFEIbsCbs(aIt[nI], nVProd - nVDesc)
            cImp += aD[1]
            aTIbs[1] += nVProd - nVDesc
            aTIbs[2] += aD[2]
            aTIbs[3] += aD[3]
            aTIbs[4] += aD[4]
        EndIf

        cDet += '<det nItem="' + cValToChar(nI) + '"><prod>' + DFETag("cProd", GEBDFETXT(DFEJ(aIt[nI], "CPROD"), 60)) + DFETag("cEAN", cGtin) + ;
            DFETag("xProd", cXProd) + DFETag("NCM", DFEJ(aIt[nI], "NCM")) + DFETagOpc("CEST", GEBDFEDIG(DFEJ(aIt[nI], "CEST"))) + ;
            DFETag("CFOP", GEBDFEDIG(DFEJ(aIt[nI], "CFOP"))) + DFETag("uCom", GEBDFETXT(DFEJ(aIt[nI], "UCOM"), 6)) + DFETag("qCom", GEBDFEN(nQ, 4)) + ;
            DFETag("vUnCom", GEBDFEN(DFEJN(aIt[nI], "VUNCOM"), 6)) + DFETag("vProd", GEBDFEN(nVProd, 2)) + DFETag("cEANTrib", cGtin) + ;
            DFETag("uTrib", GEBDFETXT(DFEJ(aIt[nI], "UCOM"), 6)) + DFETag("qTrib", GEBDFEN(nQ, 4)) + DFETag("vUnTrib", GEBDFEN(DFEJN(aIt[nI], "VUNCOM"), 6))
        If nVDesc > 0
            cDet += DFETag("vDesc", GEBDFEN(nVDesc, 2))
        EndIf
        cDet += DFETag("indTot", "1") + "</prod><imposto>" + cImp + "</imposto></det>"
        nTProd += nVProd
        nTDesc += nVDesc
        nTBC += nVBC
        nTICMS += nVICMS
        nTPIS += nVPIS
        nTCOF += nVCOF
        nTBCST += nVBCST
        nTST += nVST
    Next nI
    nVNF := Round(nTProd - nTDesc + nTST, 2)

    // Pagamento: o que passar do total e' troco (NFC-e); sem pagamento => tPag 90.
    If aPg == Nil .Or. Len(aPg) == 0
        cPag := "<detPag>" + DFETag("tPag", "90") + DFETag("vPag", "0.00") + "</detPag>"
    Else
        For nI := 1 To Len(aPg)
            cPag += "<detPag>" + DFETagOpc("indPag", DFEJ(aPg[nI], "INDPAG")) + DFETag("tPag", DFEJ(aPg[nI], "TPAG"))
            If DFEJ(aPg[nI], "TPAG") == "99"
                cPag += DFETag("xPag", GEBDFETXT(DFEJ(aPg[nI], "XPAG"), 60))
            EndIf
            cPag += DFETag("vPag", GEBDFEN(DFEJN(aPg[nI], "VPAG"), 2))
            If DFEJ(aPg[nI], "TPAG") $ "03|04|17|18"
                cPag += "<card>" + DFETag("tpIntegra", DFEJ(aPg[nI], "TPINTEGRA"))
                If DFEJ(aPg[nI], "TPINTEGRA") == "1"
                    cPag += DFETagOpc("CNPJ", GEBDFEDIG(DFEJ(aPg[nI], "CNPJCRED"))) + DFETagOpc("tBand", DFEJ(aPg[nI], "TBAND")) + ;
                        DFETagOpc("cAut", GEBDFETXT(DFEJ(aPg[nI], "CAUT"), 128))
                EndIf
                cPag += "</card>"
            EndIf
            cPag += "</detPag>"
            nTPag += Round(DFEJN(aPg[nI], "VPAG"), 2)
        Next nI
        If Round(nTPag, 2) < nVNF
            Return {.F., "pagamento_menor_que_o_total", {}}
        EndIf
        nTroco := Round(nTPag - nVNF, 2)
        If nTroco > 0
            cPag += DFETag("vTroco", GEBDFEN(nTroco, 2))
        EndIf
    EndIf

    cX := '<NFe xmlns="' + DFE_NS + '"><infNFe Id="NFe' + cChave + '" versao="4.00"><ide>' + DFETag("cUF", cCUF) + DFETag("cNF", cCNF) + ;
        DFETag("natOp", GEBDFETXT(DFEJ(oNF, "NATOP"), 60)) + DFETag("mod", cMod) + DFETag("serie", cValToChar(nSerie)) + DFETag("nNF", cValToChar(nNF)) + ;
        DFETag("dhEmi", DFEJ(oNF, "DHEMI"))
    If cMod == "55" .And. !(DFEJ(oNF, "DHSAIENT") == "")
        cX += DFETag("dhSaiEnt", DFEJ(oNF, "DHSAIENT"))
    EndIf
    cX += DFETag("tpNF", DFEPadrao(DFEJ(oNF, "TPNF"), "1")) + DFETag("idDest", DFEPadrao(DFEJ(oNF, "IDDEST"), "1")) + ;
        DFETag("cMunFG", DFEJ(oNF, "CMUNFG"))
    If cMod == "65"
        cX += DFETag("tpImp", "4")
    Else
        cX += DFETag("tpImp", "1")
    EndIf
    cX += DFETag("tpEmis", cTpEmis) + DFETag("cDV", Right(cChave, 1)) + DFETag("tpAmb", cTpAmb) + DFETag("finNFe", DFEPadrao(DFEJ(oNF, "FINNFE"), "1")) + ;
        DFETag("indFinal", DFEPadrao(DFEJ(oNF, "INDFINAL"), "1")) + DFETag("indPres", DFEPadrao(DFEJ(oNF, "INDPRES"), "1")) + ;
        DFETag("procEmi", "0") + DFETag("verProc", GEBDFETXT(DFEPadrao(DFEJ(oNF, "VERPROC"), "GEBAN"), 20))
    If !(cTpEmis == "1")
        cX += DFETag("dhCont", DFEJ(oNF, "DHCONT")) + DFETag("xJust", GEBDFETXT(DFEJ(oNF, "XJUST"), 256))
    EndIf
    If aRef != Nil
        For nI := 1 To Len(aRef)
            cX += "<NFref>" + DFETag("refNFe", aRef[nI]) + "</NFref>"
        Next nI
    EndIf
    cX += "</ide><emit>" + DFETag("CNPJ", GEBDFEDIG(DFEJ(oE, "CNPJ"))) + DFETag("xNome", GEBDFETXT(DFEJ(oE, "XNOME"), 60)) + ;
        DFETagOpc("xFant", GEBDFETXT(DFEJ(oE, "XFANT"), 60)) + "<enderEmit>" + DFEEnder(oE, .T.) + "</enderEmit>" + ;
        DFETag("IE", GEBDFEDIG(DFEJ(oE, "IE")))
    If !(DFEJ(oE, "IM") == "")
        cX += DFETag("IM", GEBDFETXT(DFEJ(oE, "IM"), 15)) + DFETagOpc("CNAE", GEBDFEDIG(DFEJ(oE, "CNAE")))
    EndIf
    cX += DFETag("CRT", DFEJ(oE, "CRT")) + "</emit>"
    If oD != Nil .And. !(GEBDFEDIG(DFEJ(oD, "CNPJ")) + GEBDFEDIG(DFEJ(oD, "CPF")) == "")
        cX += "<dest>"
        If !(GEBDFEDIG(DFEJ(oD, "CNPJ")) == "")
            cX += DFETag("CNPJ", GEBDFEDIG(DFEJ(oD, "CNPJ")))
        Else
            cX += DFETag("CPF", GEBDFEDIG(DFEJ(oD, "CPF")))
        EndIf
        If cTpAmb == "2" .And. cMod == "55"
            cX += DFETag("xNome", "NF-E EMITIDA EM AMBIENTE DE HOMOLOGACAO - SEM VALOR FISCAL")
        Else
            cX += DFETagOpc("xNome", GEBDFETXT(DFEJ(oD, "XNOME"), 60))
        EndIf
        If !(DFEJ(oD, "XLGR") == "")
            cX += "<enderDest>" + DFEEnder(oD, .F.) + "</enderDest>"
        EndIf
        cX += DFETag("indIEDest", DFEPadrao(DFEJ(oD, "INDIEDEST"), "9"))
        If DFEJ(oD, "INDIEDEST") == "1"
            cX += DFETag("IE", GEBDFEDIG(DFEJ(oD, "IE")))
        EndIf
        cX += DFETagOpc("email", GEBDFETXT(DFEJ(oD, "EMAIL"), 60)) + "</dest>"
    EndIf
    cX += cDet + "<total><ICMSTot>" + DFETag("vBC", GEBDFEN(nTBC, 2)) + DFETag("vICMS", GEBDFEN(nTICMS, 2)) + DFETag("vICMSDeson", "0.00") + ;
        DFETotDifal(aDif, nTFcpD, nTDif) + DFETag("vFCP", "0.00") + DFETag("vBCST", GEBDFEN(nTBCST, 2)) + DFETag("vST", GEBDFEN(nTST, 2)) + DFETag("vFCPST", "0.00") + DFETag("vFCPSTRet", "0.00") + ;
        DFETag("vProd", GEBDFEN(nTProd, 2)) + DFETag("vFrete", "0.00") + DFETag("vSeg", "0.00") + DFETag("vDesc", GEBDFEN(nTDesc, 2)) + ;
        DFETag("vII", "0.00") + DFETag("vIPI", "0.00") + DFETag("vIPIDevol", "0.00") + DFETag("vPIS", GEBDFEN(nTPIS, 2)) + ;
        DFETag("vCOFINS", GEBDFEN(nTCOF, 2)) + DFETag("vOutro", "0.00") + DFETag("vNF", GEBDFEN(nVNF, 2)) + DFETotTrib(nTTrib) + "</ICMSTot>" + ;
        DFETotIbs(oNF["IBSCBS"] == .T., aTIbs) + "</total>" + ;
        "<transp>" + DFETag("modFrete", "9") + "</transp>" + DFECobr(oNF["COBR"]) + "<pag>" + cPag + "</pag>"
    If !(DFEJ(oNF, "INFCPL") == "")
        cX += "<infAdic>" + DFETag("infCpl", GEBDFETXT(DFEJ(oNF, "INFCPL"), 5000)) + "</infAdic>"
    EndIf
    If oNF["RESPTEC"] != Nil .And. !(DFEJ(oNF["RESPTEC"], "CNPJ") == "")
        cX += "<infRespTec>" + DFETag("CNPJ", GEBDFEDIG(DFEJ(oNF["RESPTEC"], "CNPJ"))) + DFETag("xContato", GEBDFETXT(DFEJ(oNF["RESPTEC"], "XCONTATO"), 60)) + ;
            DFETag("email", GEBDFETXT(DFEJ(oNF["RESPTEC"], "EMAIL"), 60)) + DFETag("fone", GEBDFEDIG(DFEJ(oNF["RESPTEC"], "FONE"))) + "</infRespTec>"
    EndIf
    cX += "</infNFe></NFe>"
Return {.T., "ok", {cX, cChave, nVNF, nTroco, Round(nTST, 2), Round(nTDif + nTFcpD, 2)}}

// Cobranca (NF-e): fatura e duplicatas {nFat, vOrig, vDesc, vLiq, {{nDup, dVenc AAAAMMDD, vDup}...}}.
Static Function DFECobr(aC)
    Local cX := ""
    Local nI := 0
    If aC == Nil .Or. Len(aC) < 5 .Or. Len(aC[5]) == 0
        Return ""
    EndIf
    cX := "<cobr><fat>" + DFETag("nFat", GEBDFETXT(aC[1], 60)) + DFETag("vOrig", GEBDFEN(aC[2], 2)) + DFETag("vDesc", GEBDFEN(aC[3], 2)) + ;
        DFETag("vLiq", GEBDFEN(aC[4], 2)) + "</fat>"
    For nI := 1 To Len(aC[5])
        cX += "<dup>" + DFETag("nDup", aC[5][nI][1]) + DFETag("dVenc", Left(aC[5][nI][2], 4) + "-" + SubStr(aC[5][nI][2], 5, 2) + "-" + Right(aC[5][nI][2], 2)) + ;
            DFETag("vDup", GEBDFEN(aC[5][nI][3], 2)) + "</dup>"
    Next nI
Return cX + "</cobr>"

// ICMS ST por MVA: {cXmlDoGrupo, nVBCST, nVICMSST}. Deduz o ICMS proprio pela PICMS do item.
Static Function DFEST(oI, nBase)
    Local nBCST := Round(nBase * (1 + DFEJN(oI, "MVA") / 100) * (1 - DFEJN(oI, "PREDBCST") / 100), 2)
    Local nST := Round(nBCST * DFEJN(oI, "PICMSST") / 100 - Round(nBase * DFEJN(oI, "PICMS") / 100, 2), 2)
    Local cX := ""
    If nST < 0
        nST := 0
    EndIf
    cX := DFETag("modBCST", "4") + DFETag("pMVAST", GEBDFEN(DFEJN(oI, "MVA"), 2))
    If DFEJN(oI, "PREDBCST") > 0
        cX += DFETag("pRedBCST", GEBDFEN(DFEJN(oI, "PREDBCST"), 2))
    EndIf
    cX += DFETag("vBCST", GEBDFEN(nBCST, 2)) + DFETag("pICMSST", GEBDFEN(DFEJN(oI, "PICMSST"), 2)) + DFETag("vICMSST", GEBDFEN(nST, 2))
Return {cX, nBCST, nST}

// DIFAL (EC 87/2015, LC 190/2022) do item: aDif {pInternaDestino, pFCPDestino, lBaseDupla}.
// Devolve {cXml ICMSUFDest, nVICMSUFDest, nVFCPUFDest}.
Static Function DFEDifal(aDif, nV, pInter)
    Local nBC := nV
    Local nDif := 0
    Local nFcp := 0
    If aDif[3]
        nBC := Round((nV - nV * pInter / 100) / (1 - aDif[1] / 100), 2)
        nDif := Round(nBC * aDif[1] / 100 - nV * pInter / 100, 2)
    Else
        nDif := Round(nBC * (aDif[1] - pInter) / 100, 2)
    EndIf
    If nDif < 0
        nDif := 0
    EndIf
    nFcp := Round(nBC * aDif[2] / 100, 2)
Return {"<ICMSUFDest>" + DFETag("vBCUFDest", GEBDFEN(nBC, 2)) + DFETag("vBCFCPUFDest", GEBDFEN(nBC, 2)) + DFETag("pFCPUFDest", GEBDFEN(aDif[2], 2)) + ;
    DFETag("pICMSUFDest", GEBDFEN(aDif[1], 2)) + DFETag("pICMSInter", GEBDFEN(pInter, 2)) + DFETag("pICMSInterPart", "100.00") + ;
    DFETag("vFCPUFDest", GEBDFEN(nFcp, 2)) + DFETag("vICMSUFDest", GEBDFEN(nDif, 2)) + DFETag("vICMSUFRemet", "0.00") + "</ICMSUFDest>", nDif, nFcp}

// Grupo IBS/CBS do item (NT 2025.002): {cXml, vIBSUF, vIBSMun, vCBS}. Campos do item:
// IBSCST (padrao 000), CCLASSTRIB (padrao 000001), PIBSUF, PIBSMUN, PCBS.
Static Function DFEIbsCbs(oI, nBase)
    Local nUF := Round(nBase * DFEJN(oI, "PIBSUF") / 100, 2)
    Local nMun := Round(nBase * DFEJN(oI, "PIBSMUN") / 100, 2)
    Local nCBS := Round(nBase * DFEJN(oI, "PCBS") / 100, 2)
    Local cX := "<IBSCBS>" + DFETag("CST", DFEPadrao(DFEJ(oI, "IBSCST"), "000")) + DFETag("cClassTrib", DFEPadrao(DFEJ(oI, "CCLASSTRIB"), "000001")) + ;
        "<gIBSCBS>" + DFETag("vBC", GEBDFEN(nBase, 2)) + "<gIBSUF>" + DFETag("pIBSUF", GEBDFEN(DFEJN(oI, "PIBSUF"), 4)) + DFETag("vIBSUF", GEBDFEN(nUF, 2)) + ;
        "</gIBSUF><gIBSMun>" + DFETag("pIBSMun", GEBDFEN(DFEJN(oI, "PIBSMUN"), 4)) + DFETag("vIBSMun", GEBDFEN(nMun, 2)) + "</gIBSMun>" + ;
        DFETag("vIBS", GEBDFEN(nUF + nMun, 2)) + "<gCBS>" + DFETag("pCBS", GEBDFEN(DFEJN(oI, "PCBS"), 4)) + DFETag("vCBS", GEBDFEN(nCBS, 2)) + ;
        "</gCBS></gIBSCBS></IBSCBS>"
Return {cX, nUF, nMun, nCBS}

Static Function DFETotIbs(lIbs, aT)
    If !lIbs
        Return ""
    EndIf
Return "<IBSCBSTot>" + DFETag("vBCIBSCBS", GEBDFEN(aT[1], 2)) + "<gIBS><gIBSUF>" + DFETag("vDif", "0.00") + DFETag("vDevTrib", "0.00") + ;
    DFETag("vIBSUF", GEBDFEN(aT[2], 2)) + "</gIBSUF><gIBSMun>" + DFETag("vDif", "0.00") + DFETag("vDevTrib", "0.00") + DFETag("vIBSMun", GEBDFEN(aT[3], 2)) + ;
    "</gIBSMun>" + DFETag("vIBS", GEBDFEN(aT[2] + aT[3], 2)) + DFETag("vCredPres", "0.00") + DFETag("vCredPresCondSus", "0.00") + "</gIBS><gCBS>" + ;
    DFETag("vDif", "0.00") + DFETag("vDevTrib", "0.00") + DFETag("vCBS", GEBDFEN(aT[4], 2)) + DFETag("vCredPres", "0.00") + DFETag("vCredPresCondSus", "0.00") + ;
    "</gCBS></IBSCBSTot>"

Static Function DFETotTrib(nT)
    If nT <= 0
        Return ""
    EndIf
Return DFETag("vTotTrib", GEBDFEN(nT, 2))

Static Function DFETotDifal(aDif, nFcp, nDif)
    If aDif == Nil
        Return ""
    EndIf
Return DFETag("vFCPUFDest", GEBDFEN(nFcp, 2)) + DFETag("vICMSUFDest", GEBDFEN(nDif, 2)) + DFETag("vICMSUFRemet", "0.00")

Static Function DFEPadrao2(lCond, cSim, cNao)
    If lCond
        Return cSim
    EndIf
Return cNao

Static Function DFEPadrao(cVal, cPadrao)
    If cVal == ""
        Return cPadrao
    EndIf
Return cVal

// Endereco (emitente: CEP obrigatorio, pais Brasil).
Static Function DFEEnder(oJ, lEmit)
    Local cX := DFETag("xLgr", GEBDFETXT(DFEJ(oJ, "XLGR"), 60)) + DFETag("nro", GEBDFETXT(DFEPadrao(DFEJ(oJ, "NRO"), "SN"), 60)) + ;
        DFETagOpc("xCpl", GEBDFETXT(DFEJ(oJ, "XCPL"), 60)) + DFETag("xBairro", GEBDFETXT(DFEJ(oJ, "XBAIRRO"), 60)) + ;
        DFETag("cMun", DFEJ(oJ, "CMUN")) + DFETag("xMun", GEBDFETXT(DFEJ(oJ, "XMUN"), 60)) + DFETag("UF", Upper(DFEJ(oJ, "UF")))
    If lEmit .Or. !(GEBDFEDIG(DFEJ(oJ, "CEP")) == "")
        cX += DFETag("CEP", GEBDFEDIG(DFEJ(oJ, "CEP")))
    EndIf
    cX += DFETag("cPais", "1058") + DFETag("xPais", "Brasil")
    If Len(GEBDFEDIG(DFEJ(oJ, "FONE"))) >= 6
        cX += DFETag("fone", GEBDFEDIG(DFEJ(oJ, "FONE")))
    EndIf
Return cX

// Grupo PIS/COFINS pelo CST: 01/02 aliquota; 04-09 nao tributado; demais "outras"
// (no Simples, aliquota 0). Devolve {cXml, nValor}.
Static Function DFEPisCof(cTrib, cCst, nBase, nAliq)
    Local nValor := 0
    If cCst == ""
        cCst := "49"
    EndIf
    If cCst == "01" .Or. cCst == "02"
        nValor := Round(nBase * nAliq / 100, 2)
        Return {"<" + cTrib + "Aliq>" + DFETag("CST", cCst) + DFETag("vBC", GEBDFEN(nBase, 2)) + DFETag("p" + cTrib, GEBDFEN(nAliq, 2)) + ;
            DFETag("v" + cTrib, GEBDFEN(nValor, 2)) + "</" + cTrib + "Aliq>", nValor}
    EndIf
    If cCst $ "04|05|06|07|08|09"
        Return {"<" + cTrib + "NT>" + DFETag("CST", cCst) + "</" + cTrib + "NT>", 0}
    EndIf
    If nAliq <= 0
        nBase := 0
    EndIf
    nValor := Round(nBase * nAliq / 100, 2)
Return {"<" + cTrib + "Outr>" + DFETag("CST", cCst) + DFETag("vBC", GEBDFEN(nBase, 2)) + DFETag("p" + cTrib, GEBDFEN(nAliq, 2)) + ;
    DFETag("v" + cTrib, GEBDFEN(nValor, 2)) + "</" + cTrib + "Outr>", nValor}

/*/{Protheus.doc} GEBDFESUPL
    Insere <infNFeSupl> (QR Code e URL de consulta da NFC-e) depois do infNFe.
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFESUPL(cXml, cQR, cUrlChave)
Return StrTran(cXml, "</infNFe>", "</infNFe><infNFeSupl>" + DFETag("qrCode", GEBDFEESC(cQR)) + DFETag("urlChave", GEBDFEESC(cUrlChave)) + "</infNFeSupl>")

// Trecho do elemento cTag (da abertura ate o fechamento).
User Function GEBDFEBLOCO(cXml, cTag)
    Local nIni := At("<" + cTag + " ", cXml)
    Local nFim := 0
    If nIni == 0
        nIni := At("<" + cTag + ">", cXml)
    EndIf
    If nIni == 0
        Return ""
    EndIf
    nFim := At("</" + cTag + ">", SubStr(cXml, nIni))
    If nFim == 0
        Return ""
    EndIf
Return SubStr(cXml, nIni, nFim + Len(cTag) + 2)

// Digest (Base64 do SHA-1) do elemento cTag com o namespace herdado da raiz
// (NF-e: portalfiscal; NFS-e nacional: sped.fazenda.gov.br/nfse).
User Function GEBDFEDIGEST(cXml, cTag)
    Local cEl := GEBDFEBLOCO(cXml, cTag)
    Local cNS := DFE_NS
    Local nP := At('xmlns="', cXml)
    If nP > 0 .And. nP < At(">", cXml)
        cNS := SubStr(cXml, nP + 7, At('"', SubStr(cXml, nP + 7)) - 1)
    EndIf
    If !("xmlns=" $ Left(cEl, At(">", cEl)))
        cEl := "<" + cTag + ' xmlns="' + cNS + '"' + SubStr(cEl, Len(cTag) + 2)
    EndIf
Return Encode64(SHA1(cEl, 1))

// Corpo do certificado (Base64 do DER) a partir do PEM.
User Function GEBDFECERTB64(cPem)
    Local nIni := At("-----BEGIN CERTIFICATE-----", cPem)
    Local nFim := At("-----END CERTIFICATE-----", cPem)
    If nIni == 0 .Or. nFim == 0
        Return ""
    EndIf
    cPem := SubStr(cPem, nIni + 27, nFim - nIni - 27)
    cPem := StrTran(cPem, Chr(13), "")
    cPem := StrTran(cPem, Chr(10), "")
Return AllTrim(cPem)

/*/{Protheus.doc} GEBDFEASSINA
    Assinatura XMLDSig envelopada do elemento cTag (que tem o atributo Id),
    inserida antes do fechamento de cRaiz.
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
    @param cKeyPem Chave privada (PEM, conteudo ou caminho)
    @param cCertPem Certificado (PEM, conteudo)
    @return {lOk, cMsg, cXmlAssinado}
/*/
User Function GEBDFEASSINA(cXml, cTag, cRaiz, cKeyPem, cCertPem)
    Local cEl := GEBDFEBLOCO(cXml, cTag)
    Local cId := ""
    Local cSI := ""
    Local cErr := ""
    Local cCert := GEBDFECERTB64(cCertPem)
    Local xSig := Nil
    Local nP := 0
    If cEl == ""
        Return {.F., "elemento_a_assinar_nao_encontrado: " + cTag, ""}
    EndIf
    If cCert == ""
        Return {.F., "certificado_invalido", ""}
    EndIf
    nP := At('Id="', cEl)
    cId := SubStr(cEl, nP + 4, At('"', SubStr(cEl, nP + 4)) - 1)
    cSI := '<CanonicalizationMethod Algorithm="' + DFE_C14N + '"></CanonicalizationMethod><SignatureMethod Algorithm="' + DFE_DS + ;
        'rsa-sha1"></SignatureMethod><Reference URI="#' + cId + '"><Transforms><Transform Algorithm="' + DFE_DS + ;
        'enveloped-signature"></Transform><Transform Algorithm="' + DFE_C14N + '"></Transform></Transforms><DigestMethod Algorithm="' + ;
        DFE_DS + 'sha1"></DigestMethod><DigestValue>' + GEBDFEDIGEST(cXml, cTag) + "</DigestValue></Reference>"
    xSig := PrivSignRSA(cKeyPem, '<SignedInfo xmlns="' + DFE_DS + '">' + cSI + "</SignedInfo>", 2, "", @cErr)
    If xSig == Nil .Or. Empty(xSig)
        Return {.F., "falha_ao_assinar: chave privada invalida", ""}
    EndIf
    nP := RAt("</" + cRaiz + ">", cXml)
    If nP == 0
        Return {.F., "raiz_nao_encontrada: " + cRaiz, ""}
    EndIf
Return {.T., "ok", Left(cXml, nP - 1) + '<Signature xmlns="' + DFE_DS + '"><SignedInfo>' + cSI + "</SignedInfo><SignatureValue>" + ;
    Encode64(xSig) + "</SignatureValue><KeyInfo><X509Data><X509Certificate>" + cCert + "</X509Certificate></X509Data></KeyInfo></Signature>" + ;
    SubStr(cXml, nP)}

/*/{Protheus.doc} GEBDFEQRCODE
    Conteudo do QR Code da NFC-e. oQ: URL, VERSAO (3|2), CHAVE, TPAMB,
    TPEMIS, DHEMI, VNF, TPIDDEST (1 CNPJ, 2 CPF, 3 estrangeiro, vazio sem
    destinatario), IDDEST, KEYPEM (v3 offline), IDCSC/CSC (v2), DIGVAL (v2
    offline).
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cQR}
/*/
User Function GEBDFEQRCODE(oQ)
    Local cUrl := DFEJ(oQ, "URL")
    Local cVer := DFEPadrao(DFEJ(oQ, "VERSAO"), "3")
    Local cOff := ""
    Local cSeq := ""
    Local cDig := ""
    Local cErr := ""
    Local cDest := DFEJ(oQ, "IDDEST")
    Local xSig := Nil
    Local nI := 0
    If !("?p=" $ cUrl)
        cUrl += "?p="
    EndIf
    cOff := SubStr(DFEJ(oQ, "DHEMI"), 9, 2) + "|" + GEBDFEN(DFEJN(oQ, "VNF"), 2)
    If cVer == "3"
        cSeq := DFEJ(oQ, "CHAVE") + "|3|" + DFEJ(oQ, "TPAMB")
        If DFEJ(oQ, "TPEMIS") == "1"
            Return {.T., "ok", cUrl + cSeq}
        EndIf
        If DFEJ(oQ, "TPIDDEST") == "3"
            cDest := ""
        EndIf
        cSeq += "|" + cOff + "|" + DFEJ(oQ, "TPIDDEST") + "|" + cDest
        xSig := PrivSignRSA(DFEJ(oQ, "KEYPEM"), cSeq, 2, "", @cErr)
        If xSig == Nil .Or. Empty(xSig)
            Return {.F., "falha_ao_assinar_qrcode", ""}
        EndIf
        Return {.T., "ok", cUrl + cSeq + "|" + Encode64(xSig)}
    EndIf
    If DFEJ(oQ, "CSC") == "" .Or. DFEJ(oQ, "IDCSC") == ""
        Return {.F., "csc_nao_configurado (QR Code versao 2)", ""}
    EndIf
    If DFEJ(oQ, "TPEMIS") == "1"
        cSeq := DFEJ(oQ, "CHAVE") + "|2|" + DFEJ(oQ, "TPAMB") + "|" + cValToChar(Val(DFEJ(oQ, "IDCSC")))
    Else
        For nI := 1 To Len(DFEJ(oQ, "DIGVAL"))
            cDig += Lower(DFEHex2(Asc(SubStr(DFEJ(oQ, "DIGVAL"), nI, 1))))
        Next nI
        cSeq := DFEJ(oQ, "CHAVE") + "|2|" + DFEJ(oQ, "TPAMB") + "|" + cOff + "|" + cDig + "|" + cValToChar(Val(DFEJ(oQ, "IDCSC")))
    EndIf
Return {.T., "ok", cUrl + cSeq + "|" + Upper(SHA1(cSeq + DFEJ(oQ, "CSC")))}

Static Function DFEHex2(nB)
    Local cH := "0123456789ABCDEF"
Return SubStr(cH, Int(nB / 16) + 1, 1) + SubStr(cH, nB % 16 + 1, 1)

// Lote de autorizacao sincrono com uma nota.
User Function GEBDFELOTE(cNFe, cIdLote)
Return '<enviNFe xmlns="' + DFE_NS + '" versao="4.00">' + DFETag("idLote", cIdLote) + DFETag("indSinc", "1") + cNFe + "</enviNFe>"

User Function GEBDFESTATUS(cTpAmb, cCUF)
Return '<consStatServ xmlns="' + DFE_NS + '" versao="4.00">' + DFETag("tpAmb", cTpAmb) + DFETag("cUF", cCUF) + DFETag("xServ", "STATUS") + "</consStatServ>"

User Function GEBDFECONSULTA(cTpAmb, cChave)
Return '<consSitNFe xmlns="' + DFE_NS + '" versao="4.00">' + DFETag("tpAmb", cTpAmb) + DFETag("xServ", "CONSULTAR") + DFETag("chNFe", cChave) + "</consSitNFe>"

// Evento de cancelamento (110111), sem assinatura.
User Function GEBDFEEVCANC(cChave, cCNPJ, cTpAmb, cProt, cJust, cDh, nSeq)
    Local cSeq := StrZero(nSeq, 2)
Return '<evento xmlns="' + DFE_NS + '" versao="1.00"><infEvento Id="ID110111' + cChave + cSeq + '">' + DFETag("cOrgao", Left(cChave, 2)) + ;
    DFETag("tpAmb", cTpAmb) + DFETag("CNPJ", GEBDFEDIG(cCNPJ)) + DFETag("chNFe", cChave) + DFETag("dhEvento", cDh) + DFETag("tpEvento", "110111") + ;
    DFETag("nSeqEvento", cValToChar(nSeq)) + DFETag("verEvento", "1.00") + '<detEvento versao="1.00">' + DFETag("descEvento", "Cancelamento") + ;
    DFETag("nProt", cProt) + DFETag("xJust", GEBDFETXT(cJust, 255)) + "</detEvento></infEvento></evento>"

// Carta de correcao (110110), sem assinatura. Texto da condicao de uso: o do schema (sem acento).
User Function GEBDFEEVCCE(cChave, cCNPJ, cTpAmb, cTexto, cDh, nSeq)
    Local cCond := "A Carta de Correcao e disciplinada pelo paragrafo 1o-A do art. 7o do Convenio S/N, de 15 de dezembro de 1970 e pode ser " + ;
        "utilizada para regularizacao de erro ocorrido na emissao de documento fiscal, desde que o erro nao esteja relacionado com: I - as " + ;
        "variaveis que determinam o valor do imposto tais como: base de calculo, aliquota, diferenca de preco, quantidade, valor da operacao ou " + ;
        "da prestacao; II - a correcao de dados cadastrais que implique mudanca do remetente ou do destinatario; III - a data de emissao ou de saida."
Return '<evento xmlns="' + DFE_NS + '" versao="1.00"><infEvento Id="ID110110' + cChave + StrZero(nSeq, 2) + '">' + DFETag("cOrgao", Left(cChave, 2)) + ;
    DFETag("tpAmb", cTpAmb) + DFETag("CNPJ", GEBDFEDIG(cCNPJ)) + DFETag("chNFe", cChave) + DFETag("dhEvento", cDh) + DFETag("tpEvento", "110110") + ;
    DFETag("nSeqEvento", cValToChar(nSeq)) + DFETag("verEvento", "1.00") + '<detEvento versao="1.00">' + DFETag("descEvento", "Carta de Correcao") + ;
    DFETag("xCorrecao", GEBDFETXT(cTexto, 1000)) + DFETag("xCondUso", cCond) + "</detEvento></infEvento></evento>"

// Pedido de distribuicao de DF-e (1.01): por ultimo NSU ou por chave (cChave preenchida).
User Function GEBDFEDISTMSG(cTpAmb, cCUF, cCNPJ, cUltNSU, cChave)
    Local cX := '<distDFeInt xmlns="' + DFE_NS + '" versao="1.01">' + DFETag("tpAmb", cTpAmb) + DFETag("cUFAutor", cCUF) + DFETag("CNPJ", GEBDFEDIG(cCNPJ))
    If BOCOL(cChave) == ""
        cX += "<distNSU>" + DFETag("ultNSU", StrZero(Val(BOSTR(cUltNSU)), 15)) + "</distNSU>"
    Else
        cX += "<consChNFe>" + DFETag("chNFe", cChave) + "</consChNFe>"
    EndIf
Return cX + "</distDFeInt>"

// Manifestacao do destinatario (2102xx), sem assinatura; cOrgao 91 (Ambiente Nacional).
User Function GEBDFEEVMANIF(cChave, cCNPJ, cTpAmb, cTpEvento, cDesc, cJust, cDh)
    Local cX := '<evento xmlns="' + DFE_NS + '" versao="1.00"><infEvento Id="ID' + cTpEvento + cChave + '01">' + DFETag("cOrgao", "91") + ;
        DFETag("tpAmb", cTpAmb) + DFETag("CNPJ", GEBDFEDIG(cCNPJ)) + DFETag("chNFe", cChave) + DFETag("dhEvento", cDh) + DFETag("tpEvento", cTpEvento) + ;
        DFETag("nSeqEvento", "1") + DFETag("verEvento", "1.00") + '<detEvento versao="1.00">' + DFETag("descEvento", cDesc)
    If cTpEvento == "210240"
        cX += DFETag("xJust", GEBDFETXT(cJust, 255))
    EndIf
Return cX + "</detEvento></infEvento></evento>"

User Function GEBDFELOTEEV(cEvento, cIdLote)
Return '<envEvento xmlns="' + DFE_NS + '" versao="1.00">' + DFETag("idLote", cIdLote) + cEvento + "</envEvento>"

// Inutilizacao de faixa de numeros, sem assinatura.
User Function GEBDFEINUT(cTpAmb, cCUF, cAno, cCNPJ, cMod, nSerie, nIni, nFim, cJust)
    Local cId := "ID" + cCUF + cAno + PadL(GEBDFEDIG(cCNPJ), 14, "0") + cMod + StrZero(nSerie, 3) + StrZero(nIni, 9) + StrZero(nFim, 9)
Return '<inutNFe xmlns="' + DFE_NS + '" versao="4.00"><infInut Id="' + cId + '">' + DFETag("tpAmb", cTpAmb) + DFETag("xServ", "INUTILIZAR") + ;
    DFETag("cUF", cCUF) + DFETag("ano", cAno) + DFETag("CNPJ", GEBDFEDIG(cCNPJ)) + DFETag("mod", cMod) + DFETag("serie", cValToChar(nSerie)) + ;
    DFETag("nNFIni", cValToChar(nIni)) + DFETag("nNFFin", cValToChar(nFim)) + DFETag("xJust", GEBDFETXT(cJust, 255)) + "</infInut></inutNFe>"

// Envelope SOAP 1.2 do servico (cOperacao: NFeAutorizacao4, NFeStatusServico4...).
User Function GEBDFESOAP(cOperacao, cMsg)
Return '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' + ;
    'xmlns:soap="http://www.w3.org/2003/05/soap-envelope"><soap:Body><nfeDadosMsg xmlns="' + DFE_NS + "/wsdl/" + cOperacao + '">' + cMsg + ;
    "</nfeDadosMsg></soap:Body></soap:Envelope>"

/*/{Protheus.doc} GEBDFETAG
    Conteudo da primeira ocorrencia de cTag (com ou sem prefixo de
    namespace); "" se nao houver.
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFETAG(cXml, cTag)
    Local nIni := 0
    Local nFim := 0
    Local nP := 0
    Local cResto := ""
    nP := At("<" + cTag + ">", cXml)
    If nP > 0
        nIni := nP + Len(cTag) + 2
    Else
        nP := At(":" + cTag + ">", cXml)
        If nP == 0
            Return ""
        EndIf
        nIni := nP + Len(cTag) + 2
    EndIf
    cResto := SubStr(cXml, nIni)
    nFim := At("</", cResto)
    If nFim == 0
        Return ""
    EndIf
Return SubStr(cResto, 1, nFim - 1)

// nfeProc (documento autorizado): NFe assinada + protNFe do retorno.
User Function GEBDFEPROC(cNFe, cProt)
Return '<nfeProc xmlns="' + DFE_NS + '" versao="4.00">' + cNFe + cProt + "</nfeProc>"
