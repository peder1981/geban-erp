#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDFE_XML.prw"
#include "GEBDFE_CAD.prw"
#include "GEBDFE.prw"
#include "GEBDFE_NFE.prw"
#include "GEBCPX.prw"
#include "GEBCOM_FOR.prw"

/*/{Protheus.doc} GEBDFE_DIST
    Recebimento das NF-e emitidas contra o CNPJ da empresa (Ambiente
    Nacional):
    - GEBDFEDISTBUSCA: distribuicao de DF-e por NSU (distDFeInt 1.01): cada
      docZip (gzip + Base64) vira resumo (resNFe), nota completa (procNFe) ou
      evento (cancelamento pelo emitente marca a nota como cancelada). O
      ultimo NSU fica em DFE_ULTNSU. 137 (nada novo) e 656 (consumo
      indevido) param a busca: a SEFAZ pede uma hora entre consultas vazias.
    - GEBDFEMANIF: manifestacao do destinatario (210210 ciencia, 210200
      confirmacao, 210220 desconhecimento, 210240 operacao nao realizada);
      depois da ciencia a nota completa e' baixada (consChNFe).
    - GEBDFEDEPARA: codigo do produto no fornecedor -> produto do GEBAN e
      fator (ex.: caixa com 12 => fator 12).
    - GEBDFEIMPORTA: nota completa -> fornecedor (pelo CNPJ; cria se faltar),
      pedido (o informado ou um gerado da propria nota) e entrada de compra
      (GEBCPXENT, com a chave vinculada para a devolucao).
    GDFE: notas recebidas. GDFF: de-para de produtos por fornecedor.
    @type Modulo fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFEDISTMIG()
    Local lOk := GEBDFENFEMIG() .And. GEBCPXMIG()
    lOk := lOk .And. BOTAB("GDFE", "GDFE_CHAVE TEXT NOT NULL, GDFE_NSU TEXT NOT NULL, GDFE_CNPJ TEXT NOT NULL, GDFE_NOME TEXT NOT NULL, " + ;
        "GDFE_IE TEXT NOT NULL, GDFE_DHEMI TEXT NOT NULL, GDFE_VNF NUMERIC(18,2) NOT NULL, GDFE_SIT TEXT NOT NULL, GDFE_MANIF TEXT NOT NULL, " + ;
        "GDFE_XML TEXT NOT NULL, GDFE_IMPORT TEXT NOT NULL", "GDFE_CHAVE")
    lOk := lOk .And. BOTAB("GDFF", "GDFF_FORN TEXT NOT NULL, GDFF_CPROD TEXT NOT NULL, GDFF_PROD TEXT NOT NULL, GDFF_FATOR NUMERIC(18,6) NOT NULL", ;
        "GDFF_FORN, GDFF_CPROD")
Return lOk

// Atributo cAttr da abertura do elemento (texto entre aspas).
Static Function DSTAttr(cAbre, cAttr)
    Local nP := At(cAttr + '="', cAbre)
    If nP == 0
        Return ""
    EndIf
Return SubStr(cAbre, nP + Len(cAttr) + 2, At('"', SubStr(cAbre, nP + Len(cAttr) + 2)) - 1)

// docZip do retorno: {{cNSU, cSchema, cXml}...}.
Static Function DSTDocs(cResp)
    Local aR := {}
    Local cAbre := ""
    Local cZ := ""
    Local nP := 0
    Local nF := 0
    Do While .T.
        nP := At("<docZip ", cResp)
        If nP == 0
            Exit
        EndIf
        cResp := SubStr(cResp, nP)
        nF := At(">", cResp)
        cAbre := Left(cResp, nF)
        cZ := Decode64(SubStr(cResp, nF + 1, At("</docZip>", cResp) - nF - 1))
        aAdd(aR, {DSTAttr(cAbre, "NSU"), DSTAttr(cAbre, "schema"), BOSTR(GzStrDecomp(cZ, Len(cZ)))})
        cResp := SubStr(cResp, At("</docZip>", cResp) + 9)
    EndDo
Return aR

Static Function DSTGrava(cCh, cNSU, cCNPJ, cNome, cIE, cDh, nV, cSit, cXml)
    Local cFil := FWxFilial("GDFE")
    Local aH := TCSqlQuery("SELECT GDFE_MANIF AS M, GDFE_XML AS X, GDFE_IMPORT AS I FROM GDFE WHERE GDFE_FILIAL = " + GEBDBQuote(cFil) + " AND GDFE_CHAVE = " + ;
        GEBDBQuote(cCh) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) > 0
        If cXml == ""
            cXml := BOSTR(aH[1]:X)
        EndIf
        TCSqlExec("UPDATE GDFE SET GDFE_NSU = " + GEBDBQuote(cNSU) + ", GDFE_SIT = " + GEBDBQuote(cSit) + ", GDFE_XML = " + GEBDBQuote(cXml) + ;
            ", GDFE_VNF = " + BONUM(nV, 2) + " WHERE GDFE_FILIAL = " + GEBDBQuote(cFil) + " AND GDFE_CHAVE = " + GEBDBQuote(cCh) + " AND D_E_L_E_T_ = ' '")
        Return .T.
    EndIf
Return TCSqlExec("INSERT INTO GDFE (D_E_L_E_T_, GDFE_FILIAL, GDFE_CHAVE, GDFE_NSU, GDFE_CNPJ, GDFE_NOME, GDFE_IE, GDFE_DHEMI, GDFE_VNF, GDFE_SIT, " + ;
    "GDFE_MANIF, GDFE_XML, GDFE_IMPORT) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cCh) + ", " + GEBDBQuote(cNSU) + ", " + GEBDBQuote(cCNPJ) + ", " + ;
    GEBDBQuote(Left(cNome, 120)) + ", " + GEBDBQuote(cIE) + ", " + GEBDBQuote(cDh) + ", " + BONUM(nV, 2) + ", " + GEBDBQuote(cSit) + ", 'NENHUMA', " + ;
    GEBDBQuote(cXml) + ", '')")

// Trata um documento distribuido.
Static Function DSTDoc(aDoc)
    Local cX := aDoc[3]
    Local cCh := ""
    Local cE := ""
    If "resNFe" $ aDoc[2]
        cCh := GEBDFETAG(cX, "chNFe")
        DSTGrava(cCh, aDoc[1], GEBDFETAG(cX, "CNPJ") + GEBDFETAG(cX, "CPF"), GEBDFETAG(cX, "xNome"), GEBDFETAG(cX, "IE"), GEBDFETAG(cX, "dhEmi"), ;
            BOVAL(GEBDFETAG(cX, "vNF")), DSTSit(GEBDFETAG(cX, "cSitNFe")), "")
        Return .T.
    EndIf
    If "procNFe" $ aDoc[2]
        cE := GEBDFEBLOCO(cX, "emit")
        cCh := SubStr(GEBDFEBLOCO(cX, "infNFe"), At('Id="NFe', GEBDFEBLOCO(cX, "infNFe")) + 7, 44)
        DSTGrava(cCh, aDoc[1], GEBDFETAG(cE, "CNPJ") + GEBDFETAG(cE, "CPF"), GEBDFETAG(cE, "xNome"), GEBDFETAG(cE, "IE"), GEBDFETAG(cX, "dhEmi"), ;
            BOVAL(GEBDFETAG(GEBDFEBLOCO(cX, "ICMSTot"), "vNF")), "AUTORIZADA", cX)
        Return .T.
    EndIf
    // Eventos: o cancelamento pelo emitente marca a nota recebida.
    If GEBDFETAG(cX, "tpEvento") == "110111"
        cCh := GEBDFETAG(cX, "chNFe")
        TCSqlExec("UPDATE GDFE SET GDFE_SIT = 'CANCELADA' WHERE GDFE_FILIAL = " + GEBDBQuote(FWxFilial("GDFE")) + " AND GDFE_CHAVE = " + ;
            GEBDBQuote(cCh) + " AND D_E_L_E_T_ = ' '")
    EndIf
Return .T.

Static Function DSTSit(cS)
    If cS == "3"
        Return "CANCELADA"
    EndIf
    If cS == "2"
        Return "DENEGADA"
    EndIf
Return "AUTORIZADA"

/*/{Protheus.doc} GEBDFEDISTBUSCA
    Busca as notas novas do CNPJ (a partir do ultimo NSU).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, nDocumentos}
/*/
User Function GEBDFEDISTBUSCA()
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local aEnv := {}
    Local aD := {}
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    Local cUlt := ""
    Local cMax := ""
    Local cCStat := ""
    Local nDocs := 0
    Local nVolta := 0
    Local nI := 0
    If oE == Nil .Or. Len(aC) == 0
        Return {.F., "emitente_ou_certificado_nao_configurado", 0}
    EndIf
    If !GEBDFEDISTMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    cUlt := StrZero(Val(BOPARM("DFE_ULTNSU", "0")), 15)
    Do While nVolta < 20
        nVolta++
        aEnv := GEBDFEENVIA("55", "AN", cAmb, "NfeDistribuicaoDFe", GEBDFEDISTMSG(cAmb, GEBDFECUF(oE["UF"]), oE["CNPJ"], cUlt, ""))
        If !aEnv[1]
            Return {nDocs > 0, aEnv[3] + " (" + cValToChar(nDocs) + " documento(s) recebido(s) antes)", nDocs}
        EndIf
        cCStat := GEBDFETAG(aEnv[2], "cStat")
        If cCStat == "656"
            Return {nDocs > 0, "656 - consumo indevido: a SEFAZ pede uma hora entre consultas sem novidade", nDocs}
        EndIf
        If !(cCStat == "137" .Or. cCStat == "138")
            Return {.F., cCStat + " - " + GEBDFETAG(aEnv[2], "xMotivo"), nDocs}
        EndIf
        aD := DSTDocs(aEnv[2])
        For nI := 1 To Len(aD)
            DSTDoc(aD[nI])
            nDocs++
        Next nI
        cUlt := GEBDFETAG(aEnv[2], "ultNSU")
        cMax := GEBDFETAG(aEnv[2], "maxNSU")
        BOSETPARM("DFE_ULTNSU", cUlt)
        If cCStat == "137" .Or. Val(cUlt) >= Val(cMax)
            Exit
        EndIf
    EndDo
Return {.T., cValToChar(nDocs) + " documento(s) recebido(s); ultimo NSU " + cUlt, nDocs}

// Nota completa de uma chave (consChNFe), depois da ciencia.
User Function GEBDFEDISTCHAVE(cChave)
    Local oE := GEBDFEEMITLE()
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    Local aEnv := {}
    Local aD := {}
    Local nI := 0
    If oE == Nil
        Return {.F., "emitente_nao_cadastrado"}
    EndIf
    GEBDFEDISTMIG()
    aEnv := GEBDFEENVIA("55", "AN", cAmb, "NfeDistribuicaoDFe", GEBDFEDISTMSG(cAmb, GEBDFECUF(oE["UF"]), oE["CNPJ"], "", cChave))
    If !aEnv[1]
        Return {.F., aEnv[3]}
    EndIf
    aD := DSTDocs(aEnv[2])
    For nI := 1 To Len(aD)
        DSTDoc(aD[nI])
    Next nI
Return {Len(aD) > 0, GEBDFETAG(aEnv[2], "cStat") + " - " + GEBDFETAG(aEnv[2], "xMotivo")}

/*/{Protheus.doc} GEBDFEMANIF
    Manifestacao do destinatario. cTipo: CIENCIA (210210), CONFIRMACAO
    (210200), DESCONHECIMENTO (210220) ou NAO_REALIZADA (210240, exige
    justificativa de 15 a 255 letras).
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBDFEMANIF(cChave, cTipo, cJust)
    Local oE := GEBDFEEMITLE()
    Local aC := GEBDFECERTLE()
    Local aT := {{"CIENCIA", "210210", "Ciencia da Operacao"}, {"CONFIRMACAO", "210200", "Confirmacao da Operacao"}, ;
        {"DESCONHECIMENTO", "210220", "Desconhecimento da Operacao"}, {"NAO_REALIZADA", "210240", "Operacao nao Realizada"}}
    Local aNow := {}
    Local aA := {}
    Local aEnv := {}
    Local cAmb := BOPARM("DFE_AMBIENTE", "2")
    Local cEv := ""
    Local cRet := ""
    Local cCStat := ""
    Local nP := AScan(aT, {|x| x[1] == Upper(BOCOL(cTipo))})
    If oE == Nil .Or. Len(aC) == 0
        Return {.F., "emitente_ou_certificado_nao_configurado"}
    EndIf
    If nP == 0
        Return {.F., "tipo_deve_ser_CIENCIA_CONFIRMACAO_DESCONHECIMENTO_ou_NAO_REALIZADA"}
    EndIf
    If aT[nP][2] == "210240" .And. Len(GEBDFETXT(cJust, 255)) < 15
        Return {.F., "justificativa_com_pelo_menos_15_letras"}
    EndIf
    GEBDFEDISTMIG()
    aNow := GEBDFEAGORA(oE["UF"])
    cEv := GEBDFEEVMANIF(cChave, oE["CNPJ"], cAmb, aT[nP][2], aT[nP][3], cJust, aNow[3])
    aA := GEBDFEASSINA(cEv, "infEvento", "evento", MemoRead(aC[5]), MemoRead(aC[4]))
    If !aA[1]
        Return {.F., aA[2]}
    EndIf
    aEnv := GEBDFEENVIA("55", "AN", cAmb, "RecepcaoEvento", GEBDFELOTEEV(aA[3], StrZero(Val(BOSEQ("DFE_LOTE", 9)), 15)))
    If !aEnv[1]
        Return {.F., aEnv[3] + ": tente de novo"}
    EndIf
    cRet := GEBDFEBLOCO(aEnv[2], "retEvento")
    cCStat := GEBDFETAG(cRet, "cStat")
    If !(cCStat == "135" .Or. cCStat == "136" .Or. cCStat == "573")
        Return {.F., "manifestacao_rejeitada: " + cCStat + " - " + GEBDFETAG(cRet, "xMotivo")}
    EndIf
    TCSqlExec("UPDATE GDFE SET GDFE_MANIF = " + GEBDBQuote(aT[nP][1]) + " WHERE GDFE_FILIAL = " + GEBDBQuote(FWxFilial("GDFE")) + " AND GDFE_CHAVE = " + ;
        GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
    If aT[nP][2] == "210210" .Or. aT[nP][2] == "210200"
        GEBDFEDISTCHAVE(cChave)
    EndIf
Return {.T., aT[nP][3] + " registrada"}

// De-para do produto do fornecedor.
User Function GEBDFEDEPARA(cForn, cProdForn, cProd, nFator)
    Local cFil := FWxFilial("GDFF")
    cForn := Upper(BOCOL(cForn))
    cProd := Upper(BOCOL(cProd))
    nFator := BOVAL(nFator)
    If nFator <= 0
        nFator := 1
    EndIf
    If cForn == "" .Or. BOCOL(cProdForn) == "" .Or. cProd == ""
        Return {.F., "fornecedor_codigo_do_fornecedor_e_produto_obrigatorios"}
    EndIf
    If !GEBDFEDISTMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GDFF SET D_E_L_E_T_ = '*' WHERE GDFF_FILIAL = " + GEBDBQuote(cFil) + " AND GDFF_FORN = " + GEBDBQuote(cForn) + " AND GDFF_CPROD = " + ;
        GEBDBQuote(BOCOL(cProdForn)) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GDFF (D_E_L_E_T_, GDFF_FILIAL, GDFF_FORN, GDFF_CPROD, GDFF_PROD, GDFF_FATOR) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cForn) + ", " + GEBDBQuote(BOCOL(cProdForn)) + ", " + GEBDBQuote(cProd) + ", " + BONUM(nFator, 6) + ")")
Return {.T., "de-para gravado: " + BOCOL(cProdForn) + " -> " + cProd + " x" + cValToChar(nFator)}

/*/{Protheus.doc} GEBDFEIMPORTA
    Importa a nota recebida (completa) como entrada de compra. cPed vazio =
    gera o pedido da propria nota. Produto sem de-para => recusa listando
    os codigos do fornecedor que faltam.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {cFornecedor, cPedido, cNota}}
/*/
User Function GEBDFEIMPORTA(cChave, cPed, cData)
    Local aH := {}
    Local aDet := {}
    Local aIt := {}
    Local aF := {}
    Local aR := {}
    Local cX := ""
    Local cE := ""
    Local cCNPJ := ""
    Local cForn := ""
    Local cNF := ""
    Local cFalta := ""
    Local cP := ""
    Local nFator := 0
    Local nQ := 0
    Local nV := 0
    Local nI := 0
    cData := BODATA(cData)
    If !GEBDFEDISTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aH := TCSqlQuery("SELECT GDFE_XML AS X, GDFE_SIT AS S, GDFE_IMPORT AS I FROM GDFE WHERE GDFE_FILIAL = " + GEBDBQuote(FWxFilial("GDFE")) + ;
        " AND GDFE_CHAVE = " + GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
    If Len(aH) == 0
        Return {.F., "nota_nao_recebida: busque as notas antes", {}}
    EndIf
    If !(BOCOL(aH[1]:I) == "")
        Return {.F., "nota_ja_importada: entrada " + BOCOL(aH[1]:I), {}}
    EndIf
    If !(BOCOL(aH[1]:S) == "AUTORIZADA")
        Return {.F., "nota_" + Lower(BOCOL(aH[1]:S)) + ": nao importa", {}}
    EndIf
    cX := BOSTR(aH[1]:X)
    If !("<det " $ cX)
        Return {.F., "so_o_resumo_da_nota: faca a ciencia da operacao para baixar a nota completa", {}}
    EndIf
    cE := GEBDFEBLOCO(cX, "emit")
    cCNPJ := GEBDFETAG(cE, "CNPJ")
    cNF := GEBDFETAG(GEBDFEBLOCO(cX, "ide"), "nNF")
    // Fornecedor pelo CNPJ (cria com o nome da nota se faltar).
    aF := TCSqlQuery("SELECT GCP1_COD AS C FROM GCP1 WHERE GCP1_FILIAL = " + GEBDBQuote(FWxFilial("GCP1")) + " AND GCP1_CNPJ = " + GEBDBQuote(cCNPJ) + ;
        " AND D_E_L_E_T_ = ' '")
    If Len(aF) > 0
        cForn := BOCOL(aF[1]:C)
    Else
        cForn := "F" + Right(cCNPJ, 8)
        GEBCMFOR(cForn, GEBDFETAG(cE, "xNome"))
        TCSqlExec("UPDATE GCP1 SET GCP1_CNPJ = " + GEBDBQuote(cCNPJ) + " WHERE GCP1_FILIAL = " + GEBDBQuote(FWxFilial("GCP1")) + " AND GCP1_COD = " + ;
            GEBDBQuote(cForn) + " AND D_E_L_E_T_ = ' '")
    EndIf
    // Itens pelo de-para.
    aDet := DSTBlocos(cX, "det")
    For nI := 1 To Len(aDet)
        cP := GEBDFETAG(aDet[nI], "cProd")
        aF := TCSqlQuery("SELECT GDFF_PROD AS P, GDFF_FATOR AS F FROM GDFF WHERE GDFF_FILIAL = " + GEBDBQuote(FWxFilial("GDFF")) + " AND GDFF_FORN = " + ;
            GEBDBQuote(cForn) + " AND GDFF_CPROD = " + GEBDBQuote(cP) + " AND D_E_L_E_T_ = ' '")
        If Len(aF) == 0
            cFalta += IIFD(cFalta == "", "", ", ") + cP + " (" + GEBDFETAG(aDet[nI], "xProd") + ")"
            Loop
        EndIf
        nFator := BOVAL(aF[1]:F)
        nQ := Round(BOVAL(GEBDFETAG(aDet[nI], "qCom")) * nFator, 4)
        nV := BOVAL(GEBDFETAG(aDet[nI], "vProd")) - BOVAL(GEBDFETAG(aDet[nI], "vDesc"))
        aAdd(aIt, {BOCOL(aF[1]:P), nQ, Round(nV / nQ, 6)})
    Next nI
    If !(cFalta == "")
        Return {.F., "produtos_sem_de_para do fornecedor " + cForn + ": " + cFalta, {}}
    EndIf
    If BOCOL(cPed) == ""
        cPed := "PN" + Right(cChave, 10)
        aR := GEBCPXPED(cPed, cForn, aIt, "0", "", cData)
        If !aR[1]
            Return {.F., "pedido_da_nota: " + aR[2], {}}
        EndIf
    EndIf
    aR := GEBCPXENT(cNF, cPed, AItensEnt(aIt), BOVAL(GEBDFETAG(GEBDFEBLOCO(cX, "ICMSTot"), "vFrete")), cData, "", cChave)
    If !aR[1]
        Return {.F., "entrada: " + aR[2], {}}
    EndIf
    TCSqlExec("UPDATE GDFE SET GDFE_IMPORT = " + GEBDBQuote(cNF) + " WHERE GDFE_FILIAL = " + GEBDBQuote(FWxFilial("GDFE")) + " AND GDFE_CHAVE = " + ;
        GEBDBQuote(cChave) + " AND D_E_L_E_T_ = ' '")
Return {.T., "nota " + cNF + " de " + cForn + " importada no pedido " + cPed, {cForn, cPed, cNF}}

// Itens da entrada: {{cProd, nQtd, nPreco}...}.
Static Function AItensEnt(aIt)
    Local aR := {}
    Local nI := 0
    For nI := 1 To Len(aIt)
        aAdd(aR, {aIt[nI][1], aIt[nI][2], aIt[nI][3]})
    Next nI
Return aR

Static Function IIFD(lC, cS, cN)
    If lC
        Return cS
    EndIf
Return cN

Static Function DSTBlocos(cXml, cTag)
    Local aR := {}
    Local cB := ""
    Do While .T.
        cB := GEBDFEBLOCO(cXml, cTag)
        If cB == ""
            Exit
        EndIf
        aAdd(aR, cB)
        cXml := SubStr(cXml, At(cB, cXml) + Len(cB))
    EndDo
Return aR

/*/{Protheus.doc} GEBDFERECEBIDAS
    Relatorio das notas recebidas (grade BOREL).
    @type Relatorio fiscal
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBDFERECEBIDAS(cSituacao)
    Local aRel := {{"Chave", "Emitente", "CNPJ", "Emissao", "Valor", "Situacao", "Manifestacao", "Entrada"}}
    Local aH := {}
    Local cW := ""
    Local nI := 0
    GEBDFEDISTMIG()
    If !(BOCOL(cSituacao) == "")
        cW := " AND GDFE_SIT = " + GEBDBQuote(Upper(BOCOL(cSituacao)))
    EndIf
    aH := TCSqlQuery("SELECT GDFE_CHAVE AS C, GDFE_NOME AS N, GDFE_CNPJ AS J, GDFE_DHEMI AS E, GDFE_VNF AS V, GDFE_SIT AS S, GDFE_MANIF AS M, " + ;
        "GDFE_IMPORT AS I FROM GDFE WHERE GDFE_FILIAL = " + GEBDBQuote(FWxFilial("GDFE")) + " AND D_E_L_E_T_ = ' '" + cW + " ORDER BY GDFE_DHEMI DESC")
    For nI := 1 To Len(aH)
        aAdd(aRel, {BOCOL(aH[nI]:C), BOCOL(aH[nI]:N), BOCOL(aH[nI]:J), Left(BOCOL(aH[nI]:E), 10), BOVAL(aH[nI]:V), BOCOL(aH[nI]:S), BOCOL(aH[nI]:M), ;
            BOCOL(aH[nI]:I)})
    Next nI
    BOREL(aRel)
Return {.T., cValToChar(Len(aH)) + " nota(s) recebida(s)", Len(aH)}
