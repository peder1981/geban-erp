#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_CAD.prw"
#include "GEBDFE.prw"
#include "GEBDFE_NFE.prw"
#include "GEBFNX.prw"
#include "GEBCTX.prw"
#include "GEBFAT.prw"

/*/{Protheus.doc} GEBDFE_NFSE
    NFS-e no padrao nacional (Sefin Nacional / ADN, obrigatorio para os
    municipios desde 2026): DPS em XML (leiaute 1.01, namespace
    http://www.sped.fazenda.gov.br/nfse), assinada como a NF-e (RSA-SHA1,
    C14N), compactada em gzip + Base64 dentro de JSON e enviada por REST com
    o certificado A1 (TLS mutuo):
    - POST {sefin}/nfse {"dpsXmlGZipB64"} => 201 {chaveAcesso, idDps,
      nfseXmlGZipB64} ou 400 {erros[{codigo, descricao, complemento}]}.
    - GET {sefin}/dps/{idDps} => chave (resolve envio sem resposta).
    - POST {sefin}/nfse/{chave}/eventos {"pedidoRegistroEventoXmlGZipB64"}
      (cancelamento e101101).
    - GET {adn}/danfse/{chave} => DANFSe oficial em PDF.
    Enderecos: DFE_URL_SEFIN / DFE_URL_ADN, senao os oficiais do ambiente.
    GDFC: servico fiscal (codigo de tributacao nacional, municipal, NBS).
    GEBFATSERV: faturamento de servico (NFS-e + titulos + contabil + livro).
    @type Modulo fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
#define NFSE_NS "http://www.sped.fazenda.gov.br/nfse"

User Function GEBDFENFSEMIG()
    Local lOk := GEBDFENFEMIG() .And. GEBFATMIG()
    lOk := lOk .And. BOTAB("GDFC", "GDFC_COD TEXT NOT NULL, GDFC_DESC TEXT NOT NULL, GDFC_CTRIBNAC TEXT NOT NULL, GDFC_CTRIBMUN TEXT NOT NULL, " + ;
        "GDFC_CNBS TEXT NOT NULL, GDFC_PALIQ NUMERIC(8,4) NOT NULL", "GDFC_COD")
Return lOk

/*/{Protheus.doc} GEBDFESERV
    Servico fiscal. o: CODIGO, DESCRICAO, TRIB_NACIONAL (6 digitos: item,
    subitem e desdobro da LC 116), TRIB_MUNICIPAL (3, opcional), NBS (9,
    opcional), ALIQ_ISS (opcional, so' informativa).
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFESERV(o)
    Local cFil := FWxFilial("GDFC")
    Local cCod := Upper(BOQ(o, "CODIGO"))
    Local cNac := GEBDFEDIG(BOQ(o, "TRIB_NACIONAL"))
    Local cMun := GEBDFEDIG(BOQ(o, "TRIB_MUNICIPAL"))
    Local cNbs := GEBDFEDIG(BOQ(o, "NBS"))
    If cCod == "" .Or. BOQ(o, "DESCRICAO") == ""
        Return {.F., "codigo_e_descricao_obrigatorios"}
    EndIf
    If !(Len(cNac) == 6)
        Return {.F., "codigo_de_tributacao_nacional_com_6_digitos (item, subitem e desdobro da LC 116)"}
    EndIf
    If !(cMun == "") .And. !(Len(cMun) == 3)
        Return {.F., "codigo_de_tributacao_municipal_com_3_digitos"}
    EndIf
    If !(cNbs == "") .And. !(Len(cNbs) == 9)
        Return {.F., "nbs_com_9_digitos"}
    EndIf
    If !GEBDFENFSEMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GDFC SET D_E_L_E_T_ = '*' WHERE GDFC_FILIAL = " + GEBDBQuote(cFil) + " AND GDFC_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDFC (D_E_L_E_T_, GDFC_FILIAL, GDFC_COD, GDFC_DESC, GDFC_CTRIBNAC, GDFC_CTRIBMUN, GDFC_CNBS, GDFC_PALIQ) VALUES (' ', " + ;
        GEBDBQuote(cFil) + ", " + GEBDBQuote(cCod) + ", " + GEBDBQuote(BOQ(o, "DESCRICAO")) + ", " + GEBDBQuote(cNac) + ", " + GEBDBQuote(cMun) + ", " + ;
        GEBDBQuote(cNbs) + ", " + BONUM(BOQN(o, "ALIQ_ISS"), 4) + ")")
Return {.T., "servico " + cCod + " gravado"}

Static Function NFSServico(cCod)
    Local aH := TCSqlQuery("SELECT GDFC_DESC AS D, GDFC_CTRIBNAC AS N, GDFC_CTRIBMUN AS M, GDFC_CNBS AS B, GDFC_PALIQ AS A FROM GDFC WHERE GDFC_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GDFC")) + " AND GDFC_COD = " + GEBDBQuote(Upper(BOCOL(cCod))) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return {}
    EndIf
Return {BOCOL(aH[1]:D), BOCOL(aH[1]:N), BOCOL(aH[1]:M), BOCOL(aH[1]:B), BOVAL(aH[1]:A)}

// Base das APIs: {cSefin, cAdn}.
User Function GEBDFENFSEURL()
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    Local cSefin := "https://sefin.producaorestrita.nfse.gov.br/SefinNacional"
    Local cAdn := "https://adn.producaorestrita.nfse.gov.br"
    If cAmb == "1"
        cSefin := "https://sefin.nfse.gov.br/SefinNacional"
        cAdn := "https://adn.nfse.gov.br"
    EndIf
Return {BOPARM("DFE_URL_SEFIN", cSefin), BOPARM("DFE_URL_ADN", cAdn)}

// Id da DPS: "DPS" + municipio (7) + tipo de inscricao (1 CPF, 2 CNPJ) + inscricao (14) + serie (5) + numero (15).
User Function GEBDFEDPSID(cMun, cDoc, nSerie, nNum)
    Local cTp := "2"
    If Len(GEBDFEDIG(cDoc)) == 11
        cTp := "1"
    EndIf
Return "DPS" + cMun + cTp + PadL(GEBDFEDIG(cDoc), 14, "0") + StrZero(nSerie, 5) + StrZero(nNum, 15)

/*/{Protheus.doc} GEBDFEDPSXML
    XML da DPS (sem assinatura). oD: ID, TPAMB, DHEMI, SERIE, NDPS, DCOMPET
    (AAAAMMDD), CLOCEMI, EMIT (do GEBDFEEMITLE), CRT, REGAPSN, TOMA (DEST de
    GEBDFEPARTLE, opcional), CLOCPREST, CTRIBNAC, CTRIBMUN, CNBS, XDESC,
    VSERV, VDESCINC, RETIDO (.T./.F.), PALIQ, PTOTTRIBSN.
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFEDPSXML(oD)
    Local oE := oD["EMIT"]
    Local oT := oD["TOMA"]
    Local cOp := "1"
    Local cX := ""
    If oD["CRT"] == "1"
        cOp := "3"
    ElseIf oD["CRT"] == "4"
        cOp := "2"
    EndIf
    cX := '<DPS xmlns="' + NFSE_NS + '" versao="1.01"><infDPS Id="' + oD["ID"] + '">' + NTag("tpAmb", oD["TPAMB"]) + NTag("dhEmi", oD["DHEMI"]) + ;
        NTag("verAplic", "GEBAN_1.0") + NTag("serie", cValToChar(oD["SERIE"])) + NTag("nDPS", cValToChar(oD["NDPS"])) + ;
        NTag("dCompet", Left(oD["DCOMPET"], 4) + "-" + SubStr(oD["DCOMPET"], 5, 2) + "-" + Right(oD["DCOMPET"], 2)) + NTag("tpEmit", "1") + ;
        NTag("cLocEmi", oD["CLOCEMI"]) + "<prest>" + NTag("CNPJ", GEBDFEDIG(oE["CNPJ"]))
    If !(BOCOL(oE["IM"]) == "")
        cX += NTag("IM", GEBDFETXT(oE["IM"], 15))
    EndIf
    cX += "<regTrib>" + NTag("opSimpNac", cOp)
    If cOp == "3"
        cX += NTag("regApTribSN", oD["REGAPSN"])
    EndIf
    cX += NTag("regEspTrib", "0") + "</regTrib></prest>"
    If oT != Nil
        cX += "<toma>"
        If !(BOCOL(oT["CNPJ"]) == "")
            cX += NTag("CNPJ", oT["CNPJ"])
        Else
            cX += NTag("CPF", oT["CPF"])
        EndIf
        cX += NTag("xNome", GEBDFETXT(oT["XNOME"], 300)) + "<end><endNac>" + NTag("cMun", oT["CMUN"]) + NTag("CEP", GEBDFEDIG(oT["CEP"])) + ;
            "</endNac>" + NTag("xLgr", GEBDFETXT(oT["XLGR"], 255)) + NTag("nro", GEBDFETXT(DFEPad(oT["NRO"], "SN"), 60))
        If !(BOCOL(oT["XCPL"]) == "")
            cX += NTag("xCpl", GEBDFETXT(oT["XCPL"], 156))
        EndIf
        cX += NTag("xBairro", GEBDFETXT(oT["XBAIRRO"], 60)) + "</end>"
        If Len(GEBDFEDIG(oT["FONE"])) >= 6
            cX += NTag("fone", GEBDFEDIG(oT["FONE"]))
        EndIf
        If !(BOCOL(oT["EMAIL"]) == "")
            cX += NTag("email", GEBDFETXT(oT["EMAIL"], 80))
        EndIf
        cX += "</toma>"
    EndIf
    cX += "<serv><locPrest>" + NTag("cLocPrestacao", oD["CLOCPREST"]) + "</locPrest><cServ>" + NTag("cTribNac", oD["CTRIBNAC"])
    If !(BOCOL(oD["CTRIBMUN"]) == "")
        cX += NTag("cTribMun", oD["CTRIBMUN"])
    EndIf
    cX += NTag("xDescServ", GEBDFETXT(oD["XDESC"], 2000))
    If !(BOCOL(oD["CNBS"]) == "")
        cX += NTag("cNBS", oD["CNBS"])
    EndIf
    cX += "</cServ></serv><valores><vServPrest>" + NTag("vServ", GEBDFEN(oD["VSERV"], 2)) + "</vServPrest>"
    If BOVAL(oD["VDESCINC"]) > 0
        cX += "<vDescCondIncond>" + NTag("vDescIncond", GEBDFEN(oD["VDESCINC"], 2)) + "</vDescCondIncond>"
    EndIf
    cX += "<trib><tribMun>" + NTag("tribISSQN", "1")
    If oD["RETIDO"] == .T.
        cX += NTag("tpRetISSQN", "2")
        If BOVAL(oD["PALIQ"]) > 0
            cX += NTag("pAliq", GEBDFEN(oD["PALIQ"], 2))
        EndIf
    Else
        cX += NTag("tpRetISSQN", "1")
    EndIf
    cX += "</tribMun><totTrib>"
    If cOp == "3" .And. BOVAL(oD["PTOTTRIBSN"]) > 0
        cX += NTag("pTotTribSN", GEBDFEN(oD["PTOTTRIBSN"], 2))
    Else
        cX += NTag("indTotTrib", "0")
    EndIf
Return cX + "</totTrib></trib></valores></infDPS></DPS>"

Static Function NTag(cTag, cVal)
Return "<" + cTag + ">" + BOSTR(cVal) + "</" + cTag + ">"

Static Function DFEPad(cV, cPad)
    If BOCOL(cV) == ""
        Return cPad
    EndIf
Return BOCOL(cV)

// Envio REST com o certificado: {nStatusHttp, oJsonResposta|Nil, cCorpo}.
Static Function NFSRest(cMetodo, cUrl, cCorpo, aC)
    Local aHead := {"Content-Type: application/json", "Accept: application/json"}
    Local nTimeout := BOVAL(BOPARM("DFE_TIMEOUT", "15"))
    Local xR := Nil
    Local oJ := Nil
    If cMetodo == "POST"
        xR := HTTPSPost(cUrl, aC[4], aC[5], "", "", cCorpo, nTimeout, aHead)
    Else
        xR := HTTPSGet(cUrl, aC[4], aC[5], "", "", nTimeout, aHead)
    EndIf
    // Falha de conexao: o HTTPGetStatus guarda o status da chamada anterior, entao 0 aqui.
    If xR == Nil
        Return {0, Nil, ""}
    EndIf
    If Left(AllTrim(xR), 1) == "{"
        oJ := JsonObject():New()
        oJ:FromJson(xR)
    EndIf
Return {HTTPGetStatus(), oJ, xR}

Static Function NFSGz(cXml)
Return Encode64(GzStrComp(cXml))

Static Function NFSUnGz(cB64)
    Local cZ := Decode64(BOSTR(cB64))
    If cZ == ""
        Return ""
    EndIf
Return BOSTR(GzStrDecomp(cZ, Len(cZ)))

// Mensagens de erro da Sefin em texto.
Static Function NFSErros(oJ)
    Local aE := Nil
    Local cR := ""
    Local nI := 0
    If oJ == Nil
        Return "resposta_sem_json"
    EndIf
    aE := oJ["erros"]
    If aE == Nil
        aE := oJ["erro"]
    EndIf
    If ValType(aE) == "A"
        For nI := 1 To Len(aE)
            cR += IIFS(nI > 1, "; ", "") + BOCOL(aE[nI]["codigo"]) + " - " + BOCOL(aE[nI]["descricao"]) + " " + BOCOL(aE[nI]["complemento"])
        Next nI
    ElseIf ValType(aE) == "O"
        cR := BOCOL(aE["codigo"]) + " - " + BOCOL(aE["descricao"])
    EndIf
    If cR == ""
        cR := "erro_sem_descricao"
    EndIf
Return AllTrim(cR)

Static Function IIFS(lC, cS, cN)
    If lC
        Return cS
    EndIf
Return cN

/*/{Protheus.doc} GEBDFENFSE
    Emite a NFS-e. oP: ORIGEM, DOC, PART (cliente, cadastro fiscal C;
    vazio = tomador nao identificado), SERV (GDFC), VALOR, DESCRICAO
    (complementa a do servico), VDESC (desconto incondicionado), COMPET
    (AAAAMMDD; vazio = hoje), RETIDO (.T. = ISS retido pelo tomador),
    LOCAL (municipio IBGE da prestacao; vazio = do emitente).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cChave, cStatus, nNDPS, cIdDps}}
/*/
User Function GEBDFENFSE(oP)
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local aSv := {}
    Local aU := GEBDFENFSEURL()
    Local aNow := {}
    Local aA := {}
    Local aR := {}
    Local oD := Nil
    Local oT := Nil
    Local cId := ""
    Local cXml := ""
    Local cNfse := ""
    Local cCh := ""
    Local nSerie := BOVAL(BOPARM("DFE_SERIE_NFSE", "1"))
    Local nNum := 0
    If oE == Nil .Or. Len(aC) == 0 .Or. aC[3] < BOHOJE()
        Return {.F., "emitente_ou_certificado_nao_configurado", {}}
    EndIf
    If BOCOL(oE["IM"]) == ""
        Return {.F., "inscricao_municipal_do_emitente_obrigatoria_para_nfse", {}}
    EndIf
    GEBDFENFSEMIG()
    aSv := NFSServico(oP["SERV"])
    If Len(aSv) == 0
        Return {.F., "servico_fiscal_inexistente: " + BOCOL(oP["SERV"]), {}}
    EndIf
    If BOVAL(oP["VALOR"]) <= 0 .Or. BOVAL(oP["VDESC"]) < 0 .Or. BOVAL(oP["VDESC"]) >= BOVAL(oP["VALOR"])
        Return {.F., "valor_ou_desconto_invalidos", {}}
    EndIf
    If !(BOCOL(oP["PART"]) == "")
        oT := GEBDFEPARTLE("C", oP["PART"])
        If oT == Nil
            Return {.F., "cadastro_fiscal_do_tomador_incompleto: " + BOCOL(oP["PART"]), {}}
        EndIf
    EndIf
    aNow := GEBDFEAGORA(oE["UF"])
    nNum := Val(BOSEQ("DFESE" + StrZero(nSerie, 5), 15))
    cId := GEBDFEDPSID(oE["CMUN"], oE["CNPJ"], nSerie, nNum)
    oD := JsonObject():New()
    oD["ID"] := cId
    oD["TPAMB"] := BOPARM("DFE_AMBIENTE", "2")
    oD["DHEMI"] := aNow[3]
    oD["SERIE"] := nSerie
    oD["NDPS"] := nNum
    oD["DCOMPET"] := DFEPad(oP["COMPET"], aNow[1])
    oD["CLOCEMI"] := oE["CMUN"]
    oD["EMIT"] := oE
    oD["CRT"] := oE["CRT"]
    oD["REGAPSN"] := BOPARM("DFE_NFSE_REGAPSN", "1")
    oD["TOMA"] := oT
    oD["CLOCPREST"] := DFEPad(oP["LOCAL"], oE["CMUN"])
    oD["CTRIBNAC"] := aSv[2]
    oD["CTRIBMUN"] := aSv[3]
    oD["CNBS"] := aSv[4]
    oD["XDESC"] := AllTrim(aSv[1] + " " + BOCOL(oP["DESCRICAO"]))
    oD["VSERV"] := BOVAL(oP["VALOR"])
    oD["VDESCINC"] := BOVAL(oP["VDESC"])
    oD["RETIDO"] := oP["RETIDO"] == .T.
    oD["PALIQ"] := aSv[5]
    oD["PTOTTRIBSN"] := BOVAL(BOPARM("DFE_NFSE_PTOTTRIBSN", "0"))
    aA := GEBDFEASSINA(GEBDFEDPSXML(oD), "infDPS", "DPS", MemoRead(aC[5]), MemoRead(aC[4]))
    If !aA[1]
        Return {.F., aA[2], {}}
    EndIf
    cXml := aA[3]
    aR := NFSRest("POST", aU[1] + "/nfse", '{"dpsXmlGZipB64":"' + NFSGz(cXml) + '"}', aC)
    If aR[1] == 201 .And. aR[2] != Nil .And. !(BOCOL(aR[2]["chaveAcesso"]) == "")
        cCh := BOCOL(aR[2]["chaveAcesso"])
        cNfse := NFSUnGz(aR[2]["nfseXmlGZipB64"])
        NFSGrava(cCh, nSerie, nNum, "AUTORIZADA", "201", "NFS-e gerada", aNow[3], oP, BOVAL(oP["VALOR"]) - BOVAL(oP["VDESC"]), cNfse, cId, oT)
        Return {.T., "NFS-e gerada: chave " + cCh, {cCh, "AUTORIZADA", nNum, cId}}
    EndIf
    If aR[1] < 100 .Or. aR[1] >= 500 .Or. aR[2] == Nil
        // Sem resposta valida: a Sefin pode ter gerado. Fica PENDENTE (GEBDFENFSERESOLVE consulta pelo Id da DPS).
        NFSGrava(cId, nSerie, nNum, "PENDENTE", cValToChar(aR[1]), "sem resposta da Sefin", aNow[3], oP, BOVAL(oP["VALOR"]), cXml, cId, oT)
        Return {.F., "sem_resposta_da_sefin_nacional: a DPS " + cValToChar(nNum) + " ficou pendente; resolva em Documentos eletronicos > " + ;
            "Resolver pendentes antes de repetir", {}}
    EndIf
    NFSGrava(cId, nSerie, nNum, "REJEITADA", cValToChar(aR[1]), NFSErros(aR[2]), aNow[3], oP, BOVAL(oP["VALOR"]), cXml, cId, oT)
Return {.F., "nfse_rejeitada: " + NFSErros(aR[2]), {}}

Static Function NFSGrava(cChave, nSerie, nNum, cStatus, cCStat, cMotivo, cDh, oP, nVal, cXml, cId, oT)
    Local cFil := FWxFilial("GDF5")
    Local cDest := ""
    If oT != Nil
        cDest := BOCOL(oT["CNPJ"]) + BOCOL(oT["CPF"])
    EndIf
    TCSqlExec("UPDATE GDF5 SET D_E_L_E_T_ = '*' WHERE GDF5_FILIAL = " + GEBDBQuote(cFil) + " AND GDF5_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
Return TCSqlExec("INSERT INTO GDF5 (D_E_L_E_T_, GDF5_FILIAL, GDF5_CHAVE, GDF5_MOD, GDF5_SERIE, GDF5_NNF, GDF5_TPEMIS, GDF5_TPAMB, GDF5_STATUS, " + ;
    "GDF5_CSTAT, GDF5_MOTIVO, GDF5_PROT, GDF5_DHEMI, GDF5_DHAUT, GDF5_ORIGEM, GDF5_DOC, GDF5_VNF, GDF5_XML, GDF5_QR, GDF5_URLCH, GDF5_DEST, " + ;
    "GDF5_CHORIG, GDF5_DATA, GDF5_XMLORIG) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cChave) + ", 'SE', " + BONUM(nSerie, 0) + ", " + ;
    BONUM(nNum, 0) + ", '1', " + GEBDBQuote(BOPARM("DFE_AMBIENTE", "2")) + ", " + GEBDBQuote(cStatus) + ", " + GEBDBQuote(cCStat) + ", " + ;
    GEBDBQuote(Left(cMotivo, 250)) + ", '', " + GEBDBQuote(cDh) + ", " + GEBDBQuote(cDh) + ", " + GEBDBQuote(BOCOL(oP["ORIGEM"])) + ", " + ;
    GEBDBQuote(BOCOL(oP["DOC"])) + ", " + BONUM(nVal, 2) + ", " + GEBDBQuote(cXml) + ", '', '', " + GEBDBQuote(cDest) + ", " + GEBDBQuote(cId) + ", " + ;
    GEBDBQuote(StrTran(Left(cDh, 10), "-", "")) + ", '')")

/*/{Protheus.doc} GEBDFENFSECANC
    Cancela a NFS-e (evento e101101). cMotivo: 1 erro na emissao, 2 servico
    nao prestado, 9 outros; texto de 15 a 255 letras.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFENFSECANC(cChave, cMotivo, cTexto)
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local aD := GEBDFEDOC(cChave)
    Local aU := GEBDFENFSEURL()
    Local aNow := {}
    Local aA := {}
    Local aR := {}
    Local cEv := ""
    If oE == Nil .Or. Len(aC) == 0
        Return {.F., "emitente_ou_certificado_nao_configurado"}
    EndIf
    If Len(aD) == 0 .Or. !(aD[5] == "SE") .Or. !(aD[1] == "AUTORIZADA")
        Return {.F., "so_nfse_gerada_pode_ser_cancelada"}
    EndIf
    If !(cMotivo $ "1|2|9") .Or. Len(BOCOL(cMotivo)) != 1
        Return {.F., "motivo_deve_ser_1_erro_2_nao_prestado_ou_9_outros"}
    EndIf
    If Len(GEBDFETXT(cTexto, 255)) < 15
        Return {.F., "justificativa_com_pelo_menos_15_letras"}
    EndIf
    aNow := GEBDFEAGORA(oE["UF"])
    cEv := GEBDFEPEDCANC(cChave, aD[8], aNow[3], oE["CNPJ"], cMotivo, cTexto)
    aA := GEBDFEASSINA(cEv, "infPedReg", "pedRegEvento", MemoRead(aC[5]), MemoRead(aC[4]))
    If !aA[1]
        Return {.F., aA[2]}
    EndIf
    aR := NFSRest("POST", aU[1] + "/nfse/" + cChave + "/eventos", '{"pedidoRegistroEventoXmlGZipB64":"' + NFSGz(aA[3]) + '"}', aC)
    If !(aR[1] == 201 .Or. aR[1] == 200) .Or. aR[2] == Nil .Or. BOCOL(aR[2]["eventoXmlGZipB64"]) == ""
        If aR[2] == Nil
            Return {.F., "sem_resposta_da_sefin_nacional (status " + cValToChar(aR[1]) + "): tente de novo"}
        EndIf
        Return {.F., "cancelamento_rejeitado: " + NFSErros(aR[2])}
    EndIf
    TCSqlExec("INSERT INTO GDF6 (D_E_L_E_T_, GDF6_FILIAL, GDF6_CHAVE, GDF6_TIPO, GDF6_SEQ, GDF6_CSTAT, GDF6_MOTIVO, GDF6_PROT, GDF6_DH, GDF6_JUST, GDF6_XML, " + ;
        "GDF6_MOD, GDF6_SERIE, GDF6_NINI, GDF6_NFIM) VALUES (' ', " + GEBDBQuote(FWxFilial("GDF6")) + ", " + GEBDBQuote(cChave) + ", 'CANC', 1, '201', " + ;
        "'Evento registrado', '', " + GEBDBQuote(aNow[3]) + ", " + GEBDBQuote(cTexto) + ", " + GEBDBQuote(NFSUnGz(aR[2]["eventoXmlGZipB64"])) + ;
        ", 'SE', " + BONUM(aD[6], 0) + ", " + BONUM(aD[7], 0) + ", " + BONUM(aD[7], 0) + ")")
    TCSqlExec("UPDATE GDF5 SET GDF5_STATUS = 'CANCELADA' WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + ;
        GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("UPDATE GF3 SET GF3_STATUS = 'CANCELADA' WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + ;
        GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
Return {.T., "NFS-e cancelada"}

// Pedido de registro do evento de cancelamento (e101101), sem assinatura.
User Function GEBDFEPEDCANC(cChave, cTpAmb, cDh, cCNPJ, cMotivo, cTexto)
Return '<pedRegEvento xmlns="' + NFSE_NS + '" versao="1.01"><infPedReg Id="PRE' + cChave + '101101">' + NTag("tpAmb", cTpAmb) + ;
    NTag("verAplic", "GEBAN_1.0") + NTag("dhEvento", cDh) + NTag("CNPJAutor", GEBDFEDIG(cCNPJ)) + NTag("chNFSe", cChave) + "<e101101>" + ;
    NTag("xDesc", "Cancelamento de NFS-e") + NTag("cMotivo", cMotivo) + NTag("xMotivo", GEBDFETXT(cTexto, 255)) + "</e101101></infPedReg></pedRegEvento>"

/*/{Protheus.doc} GEBDFENFSERESOLVE
    DPS sem resposta (PENDENTE): consulta o Id da DPS na Sefin. Gerada =>
    como a operacao nao foi gravada, cancela (motivo 1). Nao gerada (404)
    => REJEITADA. Sem comunicacao => continua pendente.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {nCanceladas, nLiberadas, nPendentes}}
/*/
User Function GEBDFENFSERESOLVE()
    Local aC := GEBDFECERTLE()
    Local aU := GEBDFENFSEURL()
    Local aH := {}
    Local aR := {}
    Local aX := {}
    Local cId := ""
    Local cCh := ""
    Local nCanc := 0
    Local nLib := 0
    Local nPend := 0
    Local nI := 0
    If Len(aC) == 0
        Return {.F., "certificado_nao_instalado", {0, 0, 0}}
    EndIf
    GEBDFENFSEMIG()
    aH := TCSqlQuery("SELECT GDF5_CHAVE AS C FROM GDF5 WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_MOD = 'SE' AND " + ;
        "GDF5_STATUS = 'PENDENTE' AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aH)
        cId := BOCOL(aH[nI]:C)
        aR := NFSRest("GET", aU[1] + "/dps/" + cId, "", aC)
        If aR[1] == 200 .And. aR[2] != Nil .And. !(BOCOL(aR[2]["chaveAcesso"]) == "")
            cCh := BOCOL(aR[2]["chaveAcesso"])
            TCSqlExec("UPDATE GDF5 SET GDF5_CHAVE = " + GEBDBQuote(cCh) + ", GDF5_STATUS = 'AUTORIZADA', GDF5_CSTAT = '200' WHERE GDF5_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + GEBDBQuote(cId) + " AND D_E_L_E_T_ = ' '")
            aX := GEBDFENFSECANC(cCh, "1", "DPS gerada sem resposta da Sefin; operacao nao gravada")
            If aX[1]
                nCanc++
            Else
                nPend++
            EndIf
        ElseIf aR[1] == 404
            TCSqlExec("UPDATE GDF5 SET GDF5_STATUS = 'REJEITADA', GDF5_CSTAT = '404', GDF5_MOTIVO = 'DPS nao consta na Sefin' WHERE GDF5_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + GEBDBQuote(cId) + " AND D_E_L_E_T_ = ' '")
            nLib++
        Else
            nPend++
        EndIf
    Next nI
Return {nPend == 0, cValToChar(nCanc) + " cancelada(s), " + cValToChar(nLib) + " nao gerada(s), " + cValToChar(nPend) + " ainda pendente(s)", ;
    {nCanc, nLib, nPend}}

/*/{Protheus.doc} GEBDFEDANFSE
    DANFSe oficial (PDF) da NFS-e, baixado do ADN com o certificado.
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cPdf}
/*/
User Function GEBDFEDANFSE(cChave)
    Local aC := GEBDFECERTLE()
    Local aU := GEBDFENFSEURL()
    Local aD := GEBDFEDOC(BOCOL(cChave))
    Local xR := Nil
    If Len(aD) == 0 .Or. !(aD[5] == "SE")
        Return {.F., "nfse_inexistente", ""}
    EndIf
    If Len(aC) == 0
        Return {.F., "certificado_nao_instalado", ""}
    EndIf
    xR := HTTPSGet(aU[2] + "/danfse/" + BOCOL(cChave), aC[4], aC[5], "", "", BOVAL(BOPARM("DFE_TIMEOUT", "15")), {"Accept: application/pdf"})
    If xR == Nil .Or. !(Left(xR, 4) == "%PDF")
        Return {.F., "danfse_indisponivel (status " + cValToChar(HTTPGetStatus()) + ")", ""}
    EndIf
Return {.T., "ok", xR}

/*/{Protheus.doc} GEBFATSERV
    Faturamento de servico: NFS-e (se DFE_NFSE = S), livro fiscal (GF3/GF4
    tipo NFE, para o Simples e a apuracao), titulos a receber pela condicao
    e receita no contabil (VENDA_RECEITA).
    @type Operacao faturamento
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cDocumento, nValor, aTitulos}}
/*/
User Function GEBFATSERV(cCli, cServ, nValor, cDescricao, cCond, cData, lRetido, nDesc)
    Local oP := Nil
    Local aR := {}
    Local aSv := {}
    Local aTit := {}
    Local cDoc := ""
    Local nLiq := 0
    cCli := Upper(BOCOL(cCli))
    cData := BODATA(cData)
    nValor := Round(BOVAL(nValor), 2)
    nDesc := Round(BOVAL(nDesc), 2)
    If cData == "" .Or. nValor <= 0 .Or. nDesc < 0 .Or. nDesc >= nValor
        Return {.F., "data_valor_ou_desconto_invalidos", {}}
    EndIf
    If !GEBDFENFSEMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aSv := NFSServico(cServ)
    If Len(aSv) == 0
        Return {.F., "servico_fiscal_inexistente: " + BOCOL(cServ), {}}
    EndIf
    If Len(TCSqlQuery("SELECT GFT1_COD FROM GFT1 WHERE GFT1_FILIAL = " + GEBDBQuote(FWxFilial("GFT1")) + " AND GFT1_COD = " + GEBDBQuote(cCli) + ;
            " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "cliente_inexistente: " + cCli, {}}
    EndIf
    If !(BOCOL(cCond) == "") .And. !GEBFXPARC(cCond, 1, cData)[1]
        Return {.F., "condicao_inexistente: " + BOCOL(cCond), {}}
    EndIf
    nLiq := Round(nValor - nDesc, 2)
    If BOPARM("DFE_NFSE", "N") == "S"
        oP := JsonObject():New()
        oP["ORIGEM"] := "SERV"
        oP["DOC"] := cCli
        oP["PART"] := cCli
        oP["SERV"] := cServ
        oP["VALOR"] := nValor
        oP["VDESC"] := nDesc
        oP["DESCRICAO"] := cDescricao
        oP["COMPET"] := cData
        oP["RETIDO"] := lRetido == .T.
        aR := GEBDFENFSE(oP)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        cDoc := aR[3][1]
    Else
        cDoc := "NS" + BOSEQ("FAT_NFS", 6)
    EndIf
    GEBFATNOTA(cDoc, {{Upper(BOCOL(cServ)), 1, nLiq}}, cData)
    aR := GEBFXTIT("R", cDoc, cCli, nLiq, cCond, cData, "SERVICO " + Upper(BOCOL(cServ)), "")
    If aR[1]
        aTit := aR[3]
    EndIf
    GEBCTXLP("VENDA_RECEITA", nLiq, cDoc, cData)
Return {.T., "servico faturado: " + cDoc, {cDoc, nLiq, aTit}}
