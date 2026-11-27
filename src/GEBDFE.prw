#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_WS.prw"
#include "GEBDFE_CAD.prw"

/*/{Protheus.doc} GEBDFE
    Emissao e eventos dos documentos fiscais eletronicos junto a SEFAZ.
    - GEBDFEURL: endereco do servico pela UF, modelo e ambiente (quem
      autoriza a UF: propria SEFAZ, SVRS...); DFE_URL_<SERVICO> sobrepoe.
    - GEBDFEENVIA: SOAP 1.2 com o certificado A1 (TLS mutuo).
    - GEBDFENFCE: NFC-e de uma venda. Autorizada => {.T.}. Sem comunicacao
      ou SEFAZ fora (108/109) => contingencia offline (tpEmis 9, mesmo
      numero, QR assinado): a venda segue e a nota fica para transmitir em
      ate 24 h. Rejeitada => {.F., motivo} e o numero fica "a inutilizar".
    - GEBDFETRANSMITE: envia as contingencias; 539 (a SEFAZ ja tinha a
      tentativa online) => consulta a chave original e adota o protocolo.
    - GEBDFECANCELA (evento 110111, prazo DFE_CANC_MIN), GEBDFEINUTILIZA,
      GEBDFEINUTPEND (numeros rejeitados), GEBDFECONSULTAR, GEBDFESTATSVC.
    - GEBDFEROTEIRO: o que falta para emitir (emitente, certificado,
      ambiente, produtos sem perfil, comunicacao, pendencias).
    Toda tentativa fica em GDF5 (documentos) e GDF6 (eventos).
    @type Modulo fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/

// Linha da tabela de webservices.
Static Function DFEWSLinha(cMod, cUF, cAmb, cServ)
    Local aT := GEBDFEWSTAB()
    Local nP := AScan(aT, {|x| x[1] == cMod .And. x[2] == cUF .And. x[3] == cAmb .And. x[4] == cServ})
    If nP == 0
        Return {}
    EndIf
Return aT[nP]

/*/{Protheus.doc} GEBDFEURL
    Endereco do servico. cServ: NfeAutorizacao, NfeStatusServico,
    NfeConsultaProtocolo, RecepcaoEvento, NfeInutilizacao, NfeConsultaQR,
    URLCHAVE.
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
    @return {cUrl, cOperacao, cMetodo, cVersao} ou {} se nao houver
/*/
User Function GEBDFEURL(cMod, cUF, cAmb, cServ)
    Local aL := {}
    Local aAut := {}
    Local cAut := cUF
    Local cOver := BOPARM("DFE_URL_" + Upper(cServ), "")
    If !(cServ == "NfeConsultaQR" .Or. cServ == "URLCHAVE")
        aAut := DFEWSLinha(cMod, cUF, "", "AUTORIZADOR")
        If Len(aAut) > 0
            cAut := aAut[5]
        EndIf
    EndIf
    aL := DFEWSLinha(cMod, cAut, cAmb, cServ)
    If !(cOver == "")
        If Len(aL) == 0
            aL := DFEWSLinha("65", "SVRS", "2", cServ)
        EndIf
        If Len(aL) == 0
            Return {cOver, "", "", "300"}
        EndIf
        Return {cOver, aL[7], aL[6], aL[8]}
    EndIf
    If Len(aL) == 0
        Return {}
    EndIf
Return {aL[5], aL[7], aL[6], aL[8]}

/*/{Protheus.doc} GEBDFEENVIA
    Envia a mensagem ao servico (SOAP 1.2, certificado da filial).
    @type Funcao
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lComunicou, cResposta, cErro}
/*/
User Function GEBDFEENVIA(cMod, cUF, cAmb, cServ, cMsg)
    Local aU := GEBDFEURL(cMod, cUF, cAmb, cServ)
    Local aC := GEBDFECERTLE()
    Local aHead := {}
    Local cEnv := ""
    Local xResp := Nil
    Local nTimeout := BOVAL(BOPARM("DFE_TIMEOUT", "15"))
    If Len(aU) == 0
        Return {.F., "", "servico_" + cServ + "_nao_disponivel_para_" + cUF}
    EndIf
    If Len(aC) == 0
        Return {.F., "", "certificado_nao_instalado"}
    EndIf
    cEnv := GEBDFESOAP(aU[2], cMsg)
    If cServ == "NfeDistribuicaoDFe"
        // Distribuicao (AN): a mensagem vai dentro de nfeDistDFeInteresse/nfeDadosMsg.
        cEnv := '<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" ' + ;
            'xmlns:soap="http://www.w3.org/2003/05/soap-envelope"><soap:Body><nfeDistDFeInteresse xmlns="http://www.portalfiscal.inf.br/nfe/wsdl/' + ;
            'NFeDistribuicaoDFe"><nfeDadosMsg>' + cMsg + "</nfeDadosMsg></nfeDistDFeInteresse></soap:Body></soap:Envelope>"
    EndIf
    aHead := {'Content-Type: application/soap+xml; charset=utf-8; action="http://www.portalfiscal.inf.br/nfe/wsdl/' + aU[2] + "/" + aU[3] + '"'}
    xResp := HTTPSPost(aU[1], aC[4], aC[5], "", "", cEnv, nTimeout, aHead)
    If xResp == Nil .Or. Empty(xResp)
        Return {.F., "", "sem_comunicacao_com_a_sefaz (status " + cValToChar(HTTPGetStatus()) + ")"}
    EndIf
    If !("cStat" $ xResp)
        Return {.F., "", "resposta_invalida_da_sefaz (status " + cValToChar(HTTPGetStatus()) + ")"}
    EndIf
Return {.T., xResp, ""}

// Ambiente e configuracao basica: {lOk, cMsg, oEmit, cAmb, aCert}.
Static Function DFEPrepara()
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    If oE == Nil
        Return {.F., "emitente_nao_cadastrado", Nil, cAmb, aC}
    EndIf
    If Len(aC) == 0
        Return {.F., "certificado_nao_instalado", oE, cAmb, aC}
    EndIf
    If aC[3] < BOHOJE()
        Return {.F., "certificado_vencido_em_" + aC[3], oE, cAmb, aC}
    EndIf
Return {.T., "ok", oE, cAmb, aC}

// Responsavel tecnico (opcional; algumas UFs exigem).
User Function GEBDFERESPTEC()
    Local oRT := Nil
    If BOPARM("DFE_RT_CNPJ", "") == ""
        Return Nil
    EndIf
    oRT := JsonObject():New()
    oRT["CNPJ"] := BOPARM("DFE_RT_CNPJ", "")
    oRT["XCONTATO"] := BOPARM("DFE_RT_CONTATO", "")
    oRT["EMAIL"] := BOPARM("DFE_RT_EMAIL", "")
    oRT["FONE"] := BOPARM("DFE_RT_FONE", "")
Return oRT

/*/{Protheus.doc} GEBDFENFCE
    NFC-e da venda. aItens {{cProd, nQtd, nVUnit, nVDesc}...}; aPag
    {{cTPag, nValor, cTpIntegra, cCNPJCred, cTBand, cCAut}...}; cCPF
    (CPF ou CNPJ do consumidor, opcional); cDoc (cupom).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cChave, cStatus, cProt, cQR, cUrlChave, nNNF, nSerie, cDhEmi, nVNF}}
/*/
User Function GEBDFENFCE(cDoc, aItens, aPag, cCPF)
    Local aPrep := DFEPrepara()
    Local oE := Nil
    Local oNF := Nil
    Local oI := Nil
    Local oD := Nil
    Local oP := Nil
    Local aIt := {}
    Local aPg := {}
    Local aNow := {}
    Local aR := {}
    Local aEnv := {}
    Local aSn := {}
    Local aTrib := {}
    Local cAmb := ""
    Local cChave := ""
    Local cXml := ""
    Local cQR := ""
    Local cUrlCh := ""
    Local cProt := ""
    Local cBloco := ""
    Local cCStat := ""
    Local cMotivo := ""
    Local cDhAut := ""
    Local cChOrig := ""
    Local cXmlOrig := ""
    Local lSimples := .F.
    Local nSerie := BOVAL(BOPARM("DFE_SERIE_65", "1"))
    Local nNNF := 0
    Local nI := 0

    If !aPrep[1]
        Return {.F., aPrep[2], {}}
    EndIf
    oE := aPrep[3]
    cAmb := aPrep[4]
    lSimples := oE["CRT"] == "1" .Or. oE["CRT"] == "4"
    For nI := 1 To Len(aItens)
        oI := GEBDFEPRODITEM(aItens[nI][1], lSimples)
        If oI == Nil
            Return {.F., "produto_inexistente: " + aItens[nI][1], {}}
        EndIf
        If (BOCOL(oI["CSOSN"]) $ "201|202|203" .And. !(BOCOL(oI["CSOSN"]) == "")) .Or. BOCOL(oI["CST"]) == "10"
            Return {.F., "icms_st_nao_permitido_na_nfce: " + aItens[nI][1] + " (na venda a consumidor use CSOSN 500 ou CST 60)", {}}
        EndIf
        oI["QCOM"] := aItens[nI][2]
        oI["VUNCOM"] := aItens[nI][3]
        oI["VDESC"] := aItens[nI][4]
        aAdd(aIt, oI)
    Next nI
    For nI := 1 To Len(aPag)
        oP := JsonObject():New()
        oP["TPAG"] := aPag[nI][1]
        oP["VPAG"] := aPag[nI][2]
        oP["TPINTEGRA"] := DFEPadrao2(aPag[nI], 3, "2")
        oP["CNPJCRED"] := DFEPadrao2(aPag[nI], 4, "")
        oP["TBAND"] := DFEPadrao2(aPag[nI], 5, "")
        oP["CAUT"] := DFEPadrao2(aPag[nI], 6, "")
        If aPag[nI][1] == "99"
            oP["XPAG"] := DFEPadrao2(aPag[nI], 7, "Outros")
        EndIf
        aAdd(aPg, oP)
    Next nI
    If !(GEBDFEDIG(cCPF) == "")
        If !GEBDFEDOCOK(cCPF)
            Return {.F., "cpf_cnpj_do_consumidor_invalido", {}}
        EndIf
        oD := JsonObject():New()
        If Len(GEBDFEDIG(cCPF)) == 14
            oD["CNPJ"] := GEBDFEDIG(cCPF)
        Else
            oD["CPF"] := GEBDFEDIG(cCPF)
        EndIf
        oD["INDIEDEST"] := "9"
    EndIf

    aNow := GEBDFEAGORA(oE["UF"])
    oNF := JsonObject():New()
    oNF["MOD"] := "65"
    oNF["SERIE"] := nSerie
    oNF["TPEMIS"] := "1"
    oNF["DHEMI"] := aNow[3]
    oNF["TPAMB"] := cAmb
    oNF["NATOP"] := "VENDA"
    oNF["CMUNFG"] := oE["CMUN"]
    oNF["VERPROC"] := "GEBAN 1.0"
    oNF["EMIT"] := oE
    oNF["DEST"] := oD
    oNF["ITENS"] := aIt
    oNF["PAG"] := aPg
    oNF["INFCPL"] := AllTrim("Documento " + cDoc + " " + BOPARM("DFE_INFCPL", ""))
    oNF["RESPTEC"] := GEBDFERESPTEC()
    aTrib := GEBDFETRIB(aIt, oE["UF"], oE["CRT"], aNow[1])
    oNF["IBSCBS"] := aTrib[1]
    If !(aTrib[2] == "")
        oNF["INFCPL"] := oNF["INFCPL"] + ". " + aTrib[2]
    EndIf

    // Valida antes de consumir o numero: recusa local nao deixa buraco na numeracao.
    oNF["NNF"] := 1
    aR := GEBDFEMONTA(oNF)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    nNNF := GEBDFEPROXNUM("65", nSerie)
    oNF["NNF"] := nNNF

    aR := DFEMontaNFCe(oNF, aPrep[5], cAmb, oE["UF"])
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    cChave := aR[3][1]
    cXml := aR[3][2]
    cQR := aR[3][3]
    cUrlCh := aR[3][4]

    aEnv := GEBDFEENVIA("65", oE["UF"], cAmb, "NfeAutorizacao", GEBDFELOTE(cXml, DFELote()))
    If !aEnv[1] .And. Left(aEnv[3], 8) == "servico_"
        // Configuracao (UF sem servico), nao queda da SEFAZ: contingencia nao resolveria.
        DFEGrava(cChave, "65", nSerie, nNNF, "1", cAmb, "REJEITADA", "", aEnv[3], "", aNow[3], "", "LOJA", cDoc, aR[3][5], cXml, cQR, cUrlCh, cCPF, "", "")
        Return {.F., aEnv[3], {}}
    EndIf
    If aEnv[1]
        cCStat := GEBDFETAG(aEnv[2], "cStat")
        cBloco := GEBDFEBLOCO(aEnv[2], "protNFe")
        If !(cBloco == "")
            cCStat := GEBDFETAG(cBloco, "cStat")
            cMotivo := GEBDFETAG(cBloco, "xMotivo")
        Else
            cMotivo := GEBDFETAG(aEnv[2], "xMotivo")
        EndIf
        If cCStat == "100" .Or. cCStat == "150"
            cProt := GEBDFETAG(cBloco, "nProt")
            cDhAut := GEBDFETAG(cBloco, "dhRecbto")
            DFEGrava(cChave, "65", nSerie, nNNF, "1", cAmb, "AUTORIZADA", cCStat, cMotivo, cProt, aNow[3], cDhAut, "LOJA", cDoc, aR[3][5], ;
                GEBDFEPROC(cXml, cBloco), cQR, cUrlCh, cCPF, "", "")
            Return {.T., "NFC-e autorizada: protocolo " + cProt, {cChave, "AUTORIZADA", cProt, cQR, cUrlCh, nNNF, nSerie, aNow[3], aR[3][5]}}
        EndIf
        If !(cCStat == "108" .Or. cCStat == "109")
            If cCStat $ "110|301|302|303" .And. Len(cCStat) == 3
                DFEGrava(cChave, "65", nSerie, nNNF, "1", cAmb, "DENEGADA", cCStat, cMotivo, GEBDFETAG(cBloco, "nProt"), aNow[3], "", "LOJA", cDoc, ;
                    aR[3][5], cXml, cQR, cUrlCh, cCPF, "", "")
                Return {.F., "nfce_denegada: " + cCStat + " - " + cMotivo, {}}
            EndIf
            DFEGrava(cChave, "65", nSerie, nNNF, "1", cAmb, "REJEITADA", cCStat, cMotivo, "", aNow[3], "", "LOJA", cDoc, aR[3][5], cXml, cQR, ;
                cUrlCh, cCPF, "", "")
            Return {.F., "nfce_rejeitada: " + cCStat + " - " + cMotivo, {}}
        EndIf
    EndIf

    // Contingencia offline: mesmo numero, tpEmis 9 (a tentativa online fica guardada para o 539).
    cChOrig := cChave
    cXmlOrig := cXml
    aSn := GEBDFEAGORA(oE["UF"])
    oNF["TPEMIS"] := "9"
    oNF["DHCONT"] := aSn[3]
    If aEnv[1]
        oNF["XJUST"] := "SEFAZ indisponivel: " + cCStat + " " + cMotivo
    Else
        oNF["XJUST"] := "Sem comunicacao com a SEFAZ autorizadora"
    EndIf
    aR := DFEMontaNFCe(oNF, aPrep[5], cAmb, oE["UF"])
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    DFEGrava(aR[3][1], "65", nSerie, nNNF, "9", cAmb, "CONTINGENCIA", "", oNF["XJUST"], "", aNow[3], "", "LOJA", cDoc, aR[3][5], aR[3][2], ;
        aR[3][3], aR[3][4], cCPF, cChOrig, cXmlOrig)
Return {.T., "NFC-e em contingencia offline (transmitir em ate 24 h): " + oNF["XJUST"], ;
    {aR[3][1], "CONTINGENCIA", "", aR[3][3], aR[3][4], nNNF, nSerie, aNow[3], aR[3][5]}}

Static Function DFEPadrao2(aA, nPos, cPadrao)
    If Len(aA) < nPos .Or. BOCOL(aA[nPos]) == ""
        Return cPadrao
    EndIf
Return BOCOL(aA[nPos])

Static Function DFELote()
Return StrZero(Val(BOSEQ("DFE_LOTE", 9)), 15)

// Monta, poe o QR e assina: {lOk, cMsg, {cChave, cXmlAssinado, cQR, cUrlChave, nVNF}}.
Static Function DFEMontaNFCe(oNF, aCert, cAmb, cUF)
    Local aR := GEBDFEMONTA(oNF)
    Local aU := {}
    Local aQ := {}
    Local aA := {}
    Local oQ := Nil
    Local cKey := ""
    Local cCert := ""
    Local cUrlCh := ""
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    cKey := MemoRead(aCert[5])
    cCert := MemoRead(aCert[4])
    aU := GEBDFEURL("65", cUF, cAmb, "NfeConsultaQR")
    If Len(aU) == 0
        Return {.F., "url_do_qrcode_nao_encontrada_para_" + cUF, {}}
    EndIf
    oQ := JsonObject():New()
    oQ["URL"] := aU[1]
    // QR v3 (NT 2025.001: todas as UFs; sem CSC). DFE_QR_VERSAO = 2 volta ao CSC se a UF exigir.
    oQ["VERSAO"] := BOPARM("DFE_QR_VERSAO", "3")
    oQ["CHAVE"] := aR[3][2]
    oQ["TPAMB"] := cAmb
    oQ["TPEMIS"] := oNF["TPEMIS"]
    oQ["DHEMI"] := oNF["DHEMI"]
    oQ["VNF"] := aR[3][3]
    oQ["KEYPEM"] := cKey
    oQ["IDCSC"] := BOPARM("DFE_CSC_ID", "")
    oQ["CSC"] := BOPARM("DFE_CSC", "")
    oQ["DIGVAL"] := GEBDFEDIGEST(aR[3][1], "infNFe")
    If oNF["DEST"] != Nil
        If !(BOCOL(oNF["DEST"]["CNPJ"]) == "")
            oQ["TPIDDEST"] := "1"
            oQ["IDDEST"] := oNF["DEST"]["CNPJ"]
        Else
            oQ["TPIDDEST"] := "2"
            oQ["IDDEST"] := oNF["DEST"]["CPF"]
        EndIf
    EndIf
    aQ := GEBDFEQRCODE(oQ)
    If !aQ[1]
        Return {.F., aQ[2], {}}
    EndIf
    aU := GEBDFEURL("65", cUF, cAmb, "URLCHAVE")
    If Len(aU) > 0
        cUrlCh := aU[1]
    EndIf
    aA := GEBDFEASSINA(GEBDFESUPL(aR[3][1], aQ[3], cUrlCh), "infNFe", "NFe", cKey, cCert)
    If !aA[1]
        Return {.F., aA[2], {}}
    EndIf
Return {.T., "ok", {aR[3][2], aA[3], aQ[3], cUrlCh, aR[3][3]}}

Static Function DFEGrava(cChave, cMod, nSerie, nNNF, cTpEmis, cAmb, cStatus, cCStat, cMotivo, cProt, cDhEmi, cDhAut, cOrigem, cDoc, nVNF, cXml, ;
        cQR, cUrlCh, cDest, cChOrig, cXmlOrig)
    Local cFil := FWxFilial("GDF5")
    TCSqlExec("UPDATE GDF5 SET D_E_L_E_T_ = '*' WHERE GDF5_FILIAL = " + GEBDBQuote(cFil) + " AND GDF5_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
Return TCSqlExec("INSERT INTO GDF5 (D_E_L_E_T_, GDF5_FILIAL, GDF5_CHAVE, GDF5_MOD, GDF5_SERIE, GDF5_NNF, GDF5_TPEMIS, GDF5_TPAMB, GDF5_STATUS, " + ;
    "GDF5_CSTAT, GDF5_MOTIVO, GDF5_PROT, GDF5_DHEMI, GDF5_DHAUT, GDF5_ORIGEM, GDF5_DOC, GDF5_VNF, GDF5_XML, GDF5_QR, GDF5_URLCH, GDF5_DEST, " + ;
    "GDF5_CHORIG, GDF5_DATA, GDF5_XMLORIG) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cChave) + ", " + GEBDBQuote(cMod) + ", " + ;
    BONUM(nSerie, 0) + ", " + BONUM(nNNF, 0) + ", " + GEBDBQuote(cTpEmis) + ", " + GEBDBQuote(cAmb) + ", " + GEBDBQuote(cStatus) + ", " + ;
    GEBDBQuote(cCStat) + ", " + GEBDBQuote(Left(cMotivo, 250)) + ", " + GEBDBQuote(cProt) + ", " + GEBDBQuote(cDhEmi) + ", " + GEBDBQuote(cDhAut) + ", " + ;
    GEBDBQuote(cOrigem) + ", " + GEBDBQuote(cDoc) + ", " + BONUM(nVNF, 2) + ", " + GEBDBQuote(cXml) + ", " + GEBDBQuote(cQR) + ", " + ;
    GEBDBQuote(cUrlCh) + ", " + GEBDBQuote(GEBDFEDIG(cDest)) + ", " + GEBDBQuote(cChOrig) + ", " + GEBDBQuote(StrTran(Left(cDhEmi, 10), "-", "")) + ", " + ;
    GEBDBQuote(cXmlOrig) + ")")

// Documento (GDF5) pela chave: {status, prot, xml, dhaut, mod, serie, nnf, tpamb, doc, chorig, xmlorig, qr, urlch, vnf, dhemi, dest} ou {}.
User Function GEBDFEDOC(cChave)
    Local aH := {}
    GEBDFECADMIG()
    aH := TCSqlQuery("SELECT GDF5_STATUS AS S, GDF5_PROT AS P, GDF5_XML AS X, GDF5_DHAUT AS A, GDF5_MOD AS M, GDF5_SERIE AS SE, GDF5_NNF AS N, " + ;
        "GDF5_TPAMB AS T, GDF5_DOC AS D, GDF5_CHORIG AS CO, GDF5_XMLORIG AS XO, GDF5_QR AS Q, GDF5_URLCH AS U, GDF5_VNF AS V, GDF5_DHEMI AS E, " + ;
        "GDF5_DEST AS DE FROM GDF5 WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return {}
    EndIf
Return {BOCOL(aH[1]:S), BOCOL(aH[1]:P), BOSTR(aH[1]:X), BOCOL(aH[1]:A), BOCOL(aH[1]:M), BOVAL(aH[1]:SE), BOVAL(aH[1]:N), BOCOL(aH[1]:T), ;
    BOCOL(aH[1]:D), BOCOL(aH[1]:CO), BOSTR(aH[1]:XO), BOSTR(aH[1]:Q), BOCOL(aH[1]:U), BOVAL(aH[1]:V), BOCOL(aH[1]:E), BOCOL(aH[1]:DE)}

Static Function DFEStatus(cChave, cStatus, cCStat, cMotivo, cProt, cDhAut, cXml)
    Local cSet := "GDF5_STATUS = " + GEBDBQuote(cStatus) + ", GDF5_CSTAT = " + GEBDBQuote(cCStat) + ", GDF5_MOTIVO = " + GEBDBQuote(Left(cMotivo, 250))
    If !(cProt == "")
        cSet += ", GDF5_PROT = " + GEBDBQuote(cProt) + ", GDF5_DHAUT = " + GEBDBQuote(cDhAut)
    EndIf
    If !(cXml == "")
        cSet += ", GDF5_XML = " + GEBDBQuote(cXml)
    EndIf
Return TCSqlExec("UPDATE GDF5 SET " + cSet + " WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_CHAVE = " + GEBDBQuote(cChave) + ;
    " AND D_E_L_E_T_ = ' '")

/*/{Protheus.doc} GEBDFETRANSMITE
    Transmite as NFC-e em contingencia. Para cada uma: autorizada =>
    AUTORIZADA (e o livro GF3 tambem); 539 => consulta a chave da tentativa
    online e, se autorizada, adota chave e protocolo dela; outra rejeicao
    => REJEITADA_CONTINGENCIA (corrigir e reemitir).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {nAutorizadas, nPendentes, nRejeitadas}}
/*/
User Function GEBDFETRANSMITE()
    Local aPrep := DFEPrepara()
    Local aH := {}
    Local aD := {}
    Local aEnv := {}
    Local aC := {}
    Local cCh := ""
    Local cBloco := ""
    Local cCStat := ""
    Local cMot := ""
    Local nAut := 0
    Local nPend := 0
    Local nRej := 0
    Local nI := 0
    If !aPrep[1]
        Return {.F., aPrep[2], {0, 0, 0}}
    EndIf
    aH := TCSqlQuery("SELECT GDF5_CHAVE AS C FROM GDF5 WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_STATUS = 'CONTINGENCIA' " + ;
        "AND D_E_L_E_T_ = ' ' ORDER BY GDF5_NNF")
    For nI := 1 To Len(aH)
        cCh := BOCOL(aH[nI]:C)
        aD := GEBDFEDOC(cCh)
        aEnv := GEBDFEENVIA(aD[5], aPrep[3]["UF"], aD[8], "NfeAutorizacao", GEBDFELOTE(aD[3], DFELote()))
        If !aEnv[1]
            nPend++
            Loop
        EndIf
        cBloco := GEBDFEBLOCO(aEnv[2], "protNFe")
        cCStat := GEBDFETAG(cBloco, "cStat")
        cMot := GEBDFETAG(cBloco, "xMotivo")
        If cBloco == ""
            cCStat := GEBDFETAG(aEnv[2], "cStat")
            cMot := GEBDFETAG(aEnv[2], "xMotivo")
        EndIf
        If cCStat == "100" .Or. cCStat == "150"
            DFEStatus(cCh, "AUTORIZADA", cCStat, cMot, GEBDFETAG(cBloco, "nProt"), GEBDFETAG(cBloco, "dhRecbto"), GEBDFEPROC(aD[3], cBloco))
            DFELivro(cCh, cCh, "AUTORIZADA")
            nAut++
        ElseIf cCStat == "539" .And. !(aD[10] == "")
            aC := GEBDFECONSULTAR(aD[10], .F.)
            If aC[1] .And. aC[3][1] == "100"
                DFEAdota(cCh, aD, aC[3])
                nAut++
            Else
                DFEStatus(cCh, "REJEITADA_CONTINGENCIA", cCStat, cMot, "", "", "")
                nRej++
            EndIf
        ElseIf cCStat == "108" .Or. cCStat == "109"
            nPend++
        Else
            DFEStatus(cCh, "REJEITADA_CONTINGENCIA", cCStat, cMot, "", "", "")
            nRej++
        EndIf
    Next nI
Return {nRej == 0, cValToChar(nAut) + " autorizada(s), " + cValToChar(nPend) + " pendente(s), " + cValToChar(nRej) + " rejeitada(s)", {nAut, nPend, nRej}}

// A tentativa online estava autorizada: o documento passa a ser ela.
Static Function DFEAdota(cChCont, aD, aCons)
    Local cFil := FWxFilial("GDF5")
    TCSqlExec("UPDATE GDF5 SET GDF5_STATUS = 'SUBSTITUIDA', GDF5_MOTIVO = " + GEBDBQuote("Autorizada a tentativa online " + aD[10]) + ;
        " WHERE GDF5_FILIAL = " + GEBDBQuote(cFil) + " AND GDF5_CHAVE = " + GEBDBQuote(cChCont) + " AND D_E_L_E_T_ = ' '")
    DFEGrava(aD[10], aD[5], aD[6], aD[7], "1", aD[8], "AUTORIZADA", "100", "Autorizado o uso da NF-e (tentativa online)", aCons[3], aD[15], aCons[4], ;
        "LOJA", aD[9], aD[14], GEBDFEPROC(aD[11], aCons[5]), "", "", aD[16], "", "")
Return DFELivro(cChCont, aD[10], "AUTORIZADA")

// Livro fiscal interno (GF3/GF4) acompanha a chave e o status do documento.
Static Function DFELivro(cChave, cNova, cStatus)
    Local cW := " WHERE GF3_FILIAL = " + GEBDBQuote(FWxFilial("GF3")) + " AND GF3_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '"
    If !(cNova == cChave)
        TCSqlExec("UPDATE GF4 SET GF4_CHAVE = " + GEBDBQuote(cNova) + " WHERE GF4_FILIAL = " + GEBDBQuote(FWxFilial("GF4")) + " AND GF4_CHAVE = " + ;
            GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
        If GEBDBTableExistsHere("GLJ3")
            TCSqlExec("UPDATE GLJ3 SET GLJ3_NOTA = " + GEBDBQuote(cNova) + " WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_NOTA = " + ;
                GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
        EndIf
    EndIf
Return TCSqlExec("UPDATE GF3 SET GF3_STATUS = " + GEBDBQuote(cStatus) + ", GF3_CHAVE = " + GEBDBQuote(cNova) + cW)

/*/{Protheus.doc} GEBDFECONSULTAR
    Situacao do documento na SEFAZ (consSitNFe). lAtualiza: acerta o
    status local (autorizada/cancelada) com o que a SEFAZ disser.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cCStat, cMotivo, cProt, cDhAut, cProtNFe}}
/*/
User Function GEBDFECONSULTAR(cChave, lAtualiza)
    Local aPrep := DFEPrepara()
    Local aEnv := {}
    Local aD := {}
    Local cB := ""
    Local cCStat := ""
    Local cMot := ""
    If !aPrep[1]
        Return {.F., aPrep[2], {}}
    EndIf
    aEnv := GEBDFEENVIA(SubStr(cChave, 21, 2), aPrep[3]["UF"], aPrep[4], "NfeConsultaProtocolo", GEBDFECONSULTA(aPrep[4], cChave))
    If !aEnv[1]
        Return {.F., aEnv[3], {}}
    EndIf
    cCStat := GEBDFETAG(aEnv[2], "cStat")
    cMot := GEBDFETAG(aEnv[2], "xMotivo")
    cB := GEBDFEBLOCO(aEnv[2], "protNFe")
    If lAtualiza == .T.
        aD := GEBDFEDOC(cChave)
        If Len(aD) > 0
            If cCStat == "100" .And. !(aD[1] == "AUTORIZADA")
                DFEStatus(cChave, "AUTORIZADA", cCStat, cMot, GEBDFETAG(cB, "nProt"), GEBDFETAG(cB, "dhRecbto"), GEBDFEPROC(aD[3], cB))
                DFELivro(cChave, cChave, "AUTORIZADA")
            ElseIf cCStat == "101" .And. !(aD[1] == "CANCELADA")
                DFEStatus(cChave, "CANCELADA", cCStat, cMot, "", "", "")
                DFELivro(cChave, cChave, "CANCELADA")
            EndIf
        EndIf
    EndIf
Return {.T., cCStat + " - " + cMot, {cCStat, cMot, GEBDFETAG(cB, "nProt"), GEBDFETAG(cB, "dhRecbto"), cB}}

/*/{Protheus.doc} GEBDFECANCELA
    Cancela a NF-e/NFC-e autorizada (evento 110111) dentro de DFE_CANC_MIN
    minutos (padrao 30) da autorizacao. Justificativa de 15 a 255 letras.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cProtEvento}
/*/
User Function GEBDFECANCELA(cChave, cJust)
    Local aPrep := DFEPrepara()
    Local aD := GEBDFEDOC(cChave)
    Local aNow := {}
    Local aA := {}
    Local aEnv := {}
    Local cRet := ""
    Local cCStat := ""
    Local cMot := ""
    Local cProt := ""
    Local nMin := BOVAL(BOPARM("DFE_CANC_MIN", "30"))
    If !aPrep[1]
        Return {.F., aPrep[2], ""}
    EndIf
    If Len(aD) == 0
        Return {.F., "documento_inexistente", ""}
    EndIf
    If !(aD[1] == "AUTORIZADA")
        Return {.F., "so_documento_autorizado_pode_ser_cancelado (situacao: " + aD[1] + ")", ""}
    EndIf
    cJust := AllTrim(BOSTR(cJust))
    If Len(cJust) < 15
        Return {.F., "justificativa_com_pelo_menos_15_letras", ""}
    EndIf
    aNow := GEBDFEAGORA(aPrep[3]["UF"])
    If DFEMinutos(aD[4], aNow[3]) > nMin
        Return {.F., "prazo_de_cancelamento_expirado (" + cValToChar(nMin) + " min): faca a devolucao", ""}
    EndIf
    aA := GEBDFEASSINA(GEBDFEEVCANC(cChave, aPrep[3]["CNPJ"], aD[8], aD[2], cJust, aNow[3], 1), "infEvento", "evento", ;
        MemoRead(aPrep[5][5]), MemoRead(aPrep[5][4]))
    If !aA[1]
        Return {.F., aA[2], ""}
    EndIf
    aEnv := GEBDFEENVIA(aD[5], aPrep[3]["UF"], aD[8], "RecepcaoEvento", GEBDFELOTEEV(aA[3], DFELote()))
    If !aEnv[1]
        Return {.F., aEnv[3] + ": tente de novo", ""}
    EndIf
    cRet := GEBDFEBLOCO(aEnv[2], "retEvento")
    cCStat := GEBDFETAG(cRet, "cStat")
    cMot := GEBDFETAG(cRet, "xMotivo")
    cProt := GEBDFETAG(cRet, "nProt")
    DFEEvento(cChave, "CANC", 1, cCStat, cMot, cProt, aNow[3], cJust, '<procEventoNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="1.00">' + ;
        aA[3] + cRet + "</procEventoNFe>", aD[5], aD[6], aD[7], aD[7])
    If !(cCStat == "135" .Or. cCStat == "136" .Or. cCStat == "155")
        Return {.F., "cancelamento_rejeitado: " + cCStat + " - " + cMot, ""}
    EndIf
    DFEStatus(cChave, "CANCELADA", cCStat, cMot, "", "", "")
    DFELivro(cChave, cChave, "CANCELADA")
Return {.T., "documento cancelado: protocolo " + cProt, cProt}

// Minutos entre dois AAAA-MM-DDTHH:MM:SS (fuso ignorado: mesma UF).
Static Function DFEMinutos(cDe, cAte)
    Local nDe := BOJDN(StrTran(Left(cDe, 10), "-", "")) * 1440 + Val(SubStr(cDe, 12, 2)) * 60 + Val(SubStr(cDe, 15, 2))
    Local nAte := BOJDN(StrTran(Left(cAte, 10), "-", "")) * 1440 + Val(SubStr(cAte, 12, 2)) * 60 + Val(SubStr(cAte, 15, 2))
Return nAte - nDe

Static Function DFEEvento(cChave, cTipo, nSeq, cCStat, cMot, cProt, cDh, cJust, cXml, cMod, nSerie, nIni, nFim)
Return TCSqlExec("INSERT INTO GDF6 (D_E_L_E_T_, GDF6_FILIAL, GDF6_CHAVE, GDF6_TIPO, GDF6_SEQ, GDF6_CSTAT, GDF6_MOTIVO, GDF6_PROT, GDF6_DH, GDF6_JUST, " + ;
    "GDF6_XML, GDF6_MOD, GDF6_SERIE, GDF6_NINI, GDF6_NFIM) VALUES (' ', " + GEBDBQuote(FWxFilial("GDF6")) + ", " + GEBDBQuote(cChave) + ", " + ;
    GEBDBQuote(cTipo) + ", " + BONUM(nSeq, 0) + ", " + GEBDBQuote(cCStat) + ", " + GEBDBQuote(Left(cMot, 250)) + ", " + GEBDBQuote(cProt) + ", " + ;
    GEBDBQuote(cDh) + ", " + GEBDBQuote(cJust) + ", " + GEBDBQuote(cXml) + ", " + GEBDBQuote(cMod) + ", " + BONUM(nSerie, 0) + ", " + ;
    BONUM(nIni, 0) + ", " + BONUM(nFim, 0) + ")")

/*/{Protheus.doc} GEBDFEINUTILIZA
    Inutiliza a faixa de numeros (nIni a nFim) do modelo/serie.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, cProt}
/*/
User Function GEBDFEINUTILIZA(cMod, nSerie, nIni, nFim, cJust)
    Local aPrep := DFEPrepara()
    Local aNow := {}
    Local aA := {}
    Local aEnv := {}
    Local cRet := ""
    Local cCStat := ""
    Local cMot := ""
    Local cProt := ""
    Local cCUF := ""
    If !aPrep[1]
        Return {.F., aPrep[2], ""}
    EndIf
    cJust := AllTrim(BOSTR(cJust))
    If Len(cJust) < 15
        Return {.F., "justificativa_com_pelo_menos_15_letras", ""}
    EndIf
    If nIni < 1 .Or. nFim < nIni .Or. !(cMod == "55" .Or. cMod == "65")
        Return {.F., "faixa_ou_modelo_invalidos", ""}
    EndIf
    cCUF := GEBDFECUF(aPrep[3]["UF"])
    aNow := GEBDFEAGORA(aPrep[3]["UF"])
    aA := GEBDFEASSINA(GEBDFEINUT(aPrep[4], cCUF, SubStr(aNow[1], 3, 2), aPrep[3]["CNPJ"], cMod, nSerie, nIni, nFim, cJust), "infInut", "inutNFe", ;
        MemoRead(aPrep[5][5]), MemoRead(aPrep[5][4]))
    If !aA[1]
        Return {.F., aA[2], ""}
    EndIf
    aEnv := GEBDFEENVIA(cMod, aPrep[3]["UF"], aPrep[4], "NfeInutilizacao", aA[3])
    If !aEnv[1]
        Return {.F., aEnv[3] + ": tente de novo", ""}
    EndIf
    cRet := GEBDFEBLOCO(aEnv[2], "retInutNFe")
    cCStat := GEBDFETAG(cRet, "cStat")
    cMot := GEBDFETAG(cRet, "xMotivo")
    cProt := GEBDFETAG(cRet, "nProt")
    DFEEvento("", "INUT", 1, cCStat, cMot, cProt, aNow[3], cJust, '<procInutNFe xmlns="http://www.portalfiscal.inf.br/nfe" versao="4.00">' + ;
        aA[3] + cRet + "</procInutNFe>", cMod, nSerie, nIni, nFim)
    If !(cCStat == "102")
        Return {.F., "inutilizacao_rejeitada: " + cCStat + " - " + cMot, ""}
    EndIf
    TCSqlExec("UPDATE GDF5 SET GDF5_STATUS = 'INUTILIZADA' WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_MOD = " + ;
        GEBDBQuote(cMod) + " AND GDF5_SERIE = " + BONUM(nSerie, 0) + " AND GDF5_NNF BETWEEN " + BONUM(nIni, 0) + " AND " + BONUM(nFim, 0) + ;
        " AND GDF5_STATUS = 'REJEITADA' AND D_E_L_E_T_ = ' '")
Return {.T., "numeros " + cValToChar(nIni) + " a " + cValToChar(nFim) + " inutilizados: protocolo " + cProt, cProt}

// Numeros rejeitados ainda nao inutilizados: {{cMod, nSerie, nNNF}...}.
User Function GEBDFEPENDINUT()
    Local aH := {}
    Local aR := {}
    Local nI := 0
    GEBDFECADMIG()
    aH := TCSqlQuery("SELECT GDF5_MOD AS M, GDF5_SERIE AS S, GDF5_NNF AS N FROM GDF5 R WHERE R.GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + ;
        " AND R.GDF5_STATUS = 'REJEITADA' AND R.D_E_L_E_T_ = ' ' AND NOT EXISTS (SELECT 1 FROM GDF5 O WHERE O.GDF5_FILIAL = R.GDF5_FILIAL " + ;
        "AND O.GDF5_MOD = R.GDF5_MOD AND O.GDF5_SERIE = R.GDF5_SERIE AND O.GDF5_NNF = R.GDF5_NNF AND O.D_E_L_E_T_ = ' ' " + ;
        "AND O.GDF5_STATUS IN ('AUTORIZADA', 'CONTINGENCIA', 'CANCELADA', 'DENEGADA', 'SUBSTITUIDA')) ORDER BY 1, 2, 3")
    For nI := 1 To Len(aH)
        If Len(aR) == 0 .Or. !(aR[Len(aR)][3] == BOVAL(aH[nI]:N) .And. aR[Len(aR)][1] == BOCOL(aH[nI]:M))
            aAdd(aR, {BOCOL(aH[nI]:M), BOVAL(aH[nI]:S), BOVAL(aH[nI]:N)})
        EndIf
    Next nI
Return aR

// Inutiliza todos os numeros pendentes (um pedido por numero).
User Function GEBDFEINUTPEND(cJust)
    Local aP := GEBDFEPENDINUT()
    Local aR := {}
    Local nOk := 0
    Local nI := 0
    Local cErro := ""
    For nI := 1 To Len(aP)
        aR := GEBDFEINUTILIZA(aP[nI][1], aP[nI][2], aP[nI][3], aP[nI][3], cJust)
        If aR[1]
            nOk++
        Else
            cErro := aR[2]
        EndIf
    Next nI
    If !(cErro == "")
        Return {.F., cValToChar(nOk) + " de " + cValToChar(Len(aP)) + " inutilizado(s); ultimo erro: " + cErro, nOk}
    EndIf
Return {.T., cValToChar(nOk) + " numero(s) inutilizado(s)", nOk}

/*/{Protheus.doc} GEBDFESTATSVC
    Status do servico de autorizacao (consStatServ) do modelo.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk (107 em operacao), cMsg}
/*/
User Function GEBDFESTATSVC(cMod)
    Local aPrep := DFEPrepara()
    Local aEnv := {}
    Local cCStat := ""
    If !aPrep[1]
        Return {.F., aPrep[2]}
    EndIf
    aEnv := GEBDFEENVIA(cMod, aPrep[3]["UF"], aPrep[4], "NfeStatusServico", GEBDFESTATUS(aPrep[4], GEBDFECUF(aPrep[3]["UF"])))
    If !aEnv[1]
        Return {.F., aEnv[3]}
    EndIf
    cCStat := GEBDFETAG(aEnv[2], "cStat")
Return {cCStat == "107", cCStat + " - " + GEBDFETAG(aEnv[2], "xMotivo")}

/*/{Protheus.doc} GEBDFEROTEIRO
    O que falta para emitir NFC-e (e o que precisa de atencao), na ordem
    em que o lojista deve resolver. lTestar: faz o teste de comunicacao.
    Tambem grava a grade de relatorio (BOREL).
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lPronto, {{cItem, cSituacao (OK|FALTA|ATENCAO), cDetalhe}...}}
/*/
User Function GEBDFEROTEIRO(lTestar)
    Local aL := {}
    Local aRel := {{"Item", "Situacao", "O que fazer"}}
    Local oE := Nil
    Local aC := {}
    Local aH := {}
    Local aU := {}
    Local aSt := {}
    Local aOut := {}
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    Local lPronto := .T.
    Local nI := 0
    Local nDias := 0

    GEBDFECADMIG()
    oE := GEBDFEEMITLE()
    If oE == Nil
        aAdd(aL, {"1. Emitente", "FALTA", "Cadastre CNPJ, IE, regime e endereco (Fiscal > Documentos eletronicos > Emitente)"})
    Else
        aAdd(aL, {"1. Emitente", "OK", oE["XNOME"] + " - CNPJ " + oE["CNPJ"] + " - " + oE["XMUN"] + "/" + oE["UF"] + " - regime " + oE["CRT"]})
    EndIf
    aC := GEBDFECERTLE()
    If Len(aC) == 0
        aAdd(aL, {"2. Certificado A1", "FALTA", "Envie o arquivo .pfx e a senha pela pagina /api/dfe/configurar"})
    Else
        nDias := BODIAS(BOHOJE(), aC[3])
        If nDias < 0
            aAdd(aL, {"2. Certificado A1", "FALTA", "Vencido em " + DFEDataBr(aC[3]) + ": envie o certificado renovado"})
        ElseIf !File(aC[4]) .Or. !File(aC[5])
            aAdd(aL, {"2. Certificado A1", "FALTA", "Arquivos do certificado nao encontrados no servidor: envie de novo"})
        ElseIf nDias <= 30
            aAdd(aL, {"2. Certificado A1", "ATENCAO", aC[1] + " vence em " + cValToChar(nDias) + " dia(s) (" + DFEDataBr(aC[3]) + "): renove"})
        Else
            aAdd(aL, {"2. Certificado A1", "OK", aC[1] + " - valido ate " + DFEDataBr(aC[3])})
        EndIf
    EndIf
    If ProcRun("openssl", {"version"}, {|c| aAdd(aOut, c)}) != 0
        aAdd(aL, {"3. Ferramenta openssl", "FALTA", "O servidor precisa do openssl para instalar o certificado"})
    EndIf
    If cAmb == "1"
        aAdd(aL, {"4. Ambiente", "OK", "Producao (notas com valor fiscal)"})
    Else
        aAdd(aL, {"4. Ambiente", "ATENCAO", "Homologacao (notas de teste, sem valor fiscal): mude para producao quando os testes passarem"})
    EndIf
    If oE != Nil
        aU := GEBDFEURL("65", oE["UF"], cAmb, "NfeConsultaQR")
        If Len(aU) == 0
            aAdd(aL, {"5. QR Code", "FALTA", "Sem endereco de consulta do QR Code para " + oE["UF"]})
        ElseIf BOPARM("DFE_QR_VERSAO", "3") == "2" .And. (BOPARM("DFE_CSC", "") == "" .Or. BOPARM("DFE_CSC_ID", "") == "")
            aAdd(aL, {"5. CSC (QR Code)", "FALTA", "QR Code versao 2 escolhido: informe o ID e o codigo CSC gerados no portal da SEFAZ"})
        Else
            aAdd(aL, {"5. QR Code", "OK", "Versao " + BOPARM("DFE_QR_VERSAO", "3") + " (" + aU[1] + ")"})
        EndIf
    EndIf
    If BOPARM("DFE_RT_CNPJ", "") == ""
        aAdd(aL, {"6. Responsavel tecnico", "ATENCAO", "Algumas UFs exigem o grupo do responsavel tecnico (CNPJ, contato, e-mail, fone)"})
    EndIf
    aH := TCSqlQuery("SELECT COUNT(*) AS N FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND D_E_L_E_T_ = ' ' AND " + ;
        "(LENGTH(TRIM(GF1_NCM)) <> 8 OR TRIM(GF1_NCM) !~ '^[0-9]+$')")
    If Len(aH) > 0 .And. BOVAL(aH[1]:N) > 0
        aAdd(aL, {"7. Produtos", "FALTA", cValToChar(BOVAL(aH[1]:N)) + " produto(s) sem NCM de 8 digitos (a SEFAZ rejeita)"})
    Else
        aAdd(aL, {"7. Produtos", "OK", "Todos com NCM; sem perfil proprio usam o padrao (CFOP " + BOPARM("DFE_CFOP", "5102") + ", CSOSN " + ;
            BOPARM("DFE_CSOSN", "102") + ", unidade " + BOPARM("DFE_UNIDADE", "UN") + ")"})
    EndIf
    If oE != Nil .And. BOPARM("DFE_IBPT_VERSAO_" + oE["UF"], "") == ""
        aAdd(aL, {"7a. Tributos aproximados (Lei 12.741)", "ATENCAO", "Importe a tabela do IBPT da UF " + oE["UF"] + " (pagina de configuracao, item 4)"})
    EndIf
    If BOPARM("DFE_NFSE", "N") == "S" .And. oE != Nil .And. BOCOL(oE["IM"]) == ""
        aAdd(aL, {"7b. NFS-e", "FALTA", "A NFS-e exige a inscricao municipal do emitente"})
    EndIf
    If !(BOPARM("DFE_NFCE", "N") == "S")
        aAdd(aL, {"8. NFC-e na frente de loja", "FALTA", "Ligue a emissao (configuracao NFCE = S) depois do teste de comunicacao"})
    Else
        aAdd(aL, {"8. NFC-e na frente de loja", "OK", "Ligada: serie " + BOPARM("DFE_SERIE_65", "1")})
    EndIf
    aH := TCSqlQuery("SELECT COUNT(*) AS N, MIN(GDF5_DHEMI) AS D FROM GDF5 WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + ;
        " AND GDF5_STATUS = 'CONTINGENCIA' AND D_E_L_E_T_ = ' '")
    If Len(aH) > 0 .And. BOVAL(aH[1]:N) > 0
        aAdd(aL, {"9. Contingencia", "ATENCAO", cValToChar(BOVAL(aH[1]:N)) + " NFC-e a transmitir (prazo de 24 h; a mais antiga e' de " + BOCOL(aH[1]:D) + ")"})
    EndIf
    aH := TCSqlQuery("SELECT COUNT(*) AS N FROM GDF5 WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + ;
        " AND GDF5_STATUS = 'REJEITADA_CONTINGENCIA' AND D_E_L_E_T_ = ' '")
    If Len(aH) > 0 .And. BOVAL(aH[1]:N) > 0
        aAdd(aL, {"10. Contingencia rejeitada", "FALTA", cValToChar(BOVAL(aH[1]:N)) + " NFC-e emitida(s) offline foi(ram) rejeitada(s): corrija o cadastro e reemita"})
    EndIf
    aSt := GEBDFEPENDINUT()
    If Len(aSt) > 0
        aAdd(aL, {"11. Numeros a inutilizar", "ATENCAO", cValToChar(Len(aSt)) + " numero(s) de notas rejeitadas: inutilize (Documentos eletronicos > Inutilizar pendentes)"})
    EndIf
    If lTestar == .T. .And. oE != Nil .And. Len(aC) > 0
        aSt := GEBDFESTATSVC("65")
        If aSt[1]
            aAdd(aL, {"12. Comunicacao com a SEFAZ", "OK", aSt[2]})
        Else
            aAdd(aL, {"12. Comunicacao com a SEFAZ", "FALTA", aSt[2] + DFEDicaRede(aSt[2])})
        EndIf
    EndIf
    For nI := 1 To Len(aL)
        If aL[nI][2] == "FALTA"
            lPronto := .F.
        EndIf
        aAdd(aRel, aL[nI])
    Next nI
    BOREL(aRel)
Return {lPronto, aL}

Static Function DFEDicaRede(cMsg)
    If "status 0" $ cMsg .Or. "sem_comunicacao" $ cMsg
        Return " (confira a internet do servidor e a cadeia de certificados ICP-Brasil; ver docs/07-runbook.md)"
    EndIf
Return ""

Static Function DFEDataBr(cData)
Return Right(cData, 2) + "/" + SubStr(cData, 5, 2) + "/" + Left(cData, 4)

/*/{Protheus.doc} GEBDFEDOCS
    Relatorio dos documentos do periodo (grade BOREL): numero, chave,
    situacao, valor, protocolo, motivo.
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFEDOCS(cIni, cFim, cStatus)
    Local aRel := {{"Modelo/serie/numero", "Chave", "Situacao", "Valor", "Emissao", "Protocolo", "Documento", "Motivo"}}
    Local aH := {}
    Local cW := ""
    Local nI := 0
    GEBDFECADMIG()
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    cW := " WHERE GDF5_FILIAL = " + GEBDBQuote(FWxFilial("GDF5")) + " AND GDF5_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + ;
        " AND D_E_L_E_T_ = ' '"
    If !(BOCOL(cStatus) == "")
        cW += " AND GDF5_STATUS = " + GEBDBQuote(Upper(BOCOL(cStatus)))
    EndIf
    aH := TCSqlQuery("SELECT GDF5_MOD AS M, GDF5_SERIE AS S, GDF5_NNF AS N, GDF5_CHAVE AS C, GDF5_STATUS AS ST, GDF5_VNF AS V, GDF5_DHEMI AS E, " + ;
        "GDF5_PROT AS P, GDF5_DOC AS D, GDF5_CSTAT AS CS, GDF5_MOTIVO AS MO FROM GDF5" + cW + " ORDER BY GDF5_MOD, GDF5_SERIE, GDF5_NNF")
    For nI := 1 To Len(aH)
        aAdd(aRel, {BOCOL(aH[nI]:M) + "/" + cValToChar(BOVAL(aH[nI]:S)) + "/" + cValToChar(BOVAL(aH[nI]:N)), BOCOL(aH[nI]:C), BOCOL(aH[nI]:ST), ;
            BOVAL(aH[nI]:V), BOCOL(aH[nI]:E), BOCOL(aH[nI]:P), BOCOL(aH[nI]:D), BOCOL(aH[nI]:CS) + " " + BOCOL(aH[nI]:MO)})
    Next nI
    BOREL(aRel)
Return {.T., cValToChar(Len(aH)) + " documento(s)", Len(aH)}
