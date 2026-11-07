#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBEST.prw"
#include "GEBFNX.prw"
#include "GEBCOM_MIG.prw"
#include "GEBFAT.prw"
#include "GEBDFE_NFE.prw"

/*/{Protheus.doc} GEBCPX
    Compras do backoffice (inspirado em MATA110/MATA150/MATA120/MATA097/
    MATA103 do Protheus).
    - GCQ1 solicitacao de compra (itens: produto, quantidade, necessidade).
    - GEBCPXGERA: pedidos a partir da solicitacao pelo menor preco cotado
      (GCP2), um pedido por fornecedor.
    - Pedido em GCP3/GCP4 (como antes) + GCQ2: condicao, armazem de
      entrega, total e liberacao. Total acima de GE4 COM_ALCADA (0 = sem
      alcada) fica PENDENTE ate GEBCPXAPR (permissao COMPRAS/APROVA na
      API e na tela).
    - GEBCPXENT: documento de entrada. Recebe todo o pendente ou so' os
      itens informados (parcial), com preco do pedido ou informado; frete
      rateado pelo valor de cada item (o ultimo fica com o centavo) entra no
      custo; estoque a custo de entrada (GEBESTMOV), titulos a pagar pela
      condicao (GEBFXTIT), lancamento COMPRA_ESTOQUE. GCQ3 acumula o
      recebido por item; o pedido fica PARCIAL ou RECEBIDO. GCQ4/GCQ5 guardam
      o documento; GCP5 continua registrando a NF.
    - Relatorios: GEBCPXABERTOS (pedido x recebido), GEBCPXPORFORN (compras
      por fornecedor no periodo) e GEBCPXSCPEND (solicitacoes pendentes).
    @type Modulo compras
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBCPXMIG()
    Local lOk := GEBCMMIG() .And. GEBESTMIG() .And. GEBFXMIG()
    // GCQ7: IBS/CBS de cada item da entrada (credito da apuracao).
    lOk := lOk .And. BOTAB("GCQ7", "GCQ7_NF TEXT NOT NULL, GCQ7_FORN TEXT NOT NULL, GCQ7_PROD TEXT NOT NULL, GCQ7_DATA TEXT NOT NULL, " + ;
        "GCQ7_BASE NUMERIC(18,2) NOT NULL, GCQ7_IBS NUMERIC(18,2) NOT NULL, GCQ7_CBS NUMERIC(18,2) NOT NULL", "GCQ7_NF")
    lOk := lOk .And. BOTAB("GCQ1", "GCQ1_NUM TEXT NOT NULL, GCQ1_PROD TEXT NOT NULL, GCQ1_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GCQ1_NECESS TEXT NOT NULL, GCQ1_SOLIC TEXT NOT NULL, GCQ1_STATUS TEXT NOT NULL, GCQ1_PED TEXT NOT NULL", "GCQ1_NUM")
    lOk := lOk .And. BOTAB("GCQ2", "GCQ2_PED TEXT NOT NULL, GCQ2_COND TEXT NOT NULL, GCQ2_LOCAL TEXT NOT NULL, GCQ2_EMISSAO TEXT NOT NULL, " + ;
        "GCQ2_TOTAL NUMERIC(18,2) NOT NULL, GCQ2_LIB TEXT NOT NULL, GCQ2_APROV TEXT NOT NULL", "GCQ2_PED")
    lOk := lOk .And. BOTAB("GCQ3", "GCQ3_PED TEXT NOT NULL, GCQ3_PROD TEXT NOT NULL, GCQ3_QTDREC NUMERIC(18,4) NOT NULL", "GCQ3_PED")
    lOk := lOk .And. BOTAB("GCQ4", "GCQ4_NF TEXT NOT NULL, GCQ4_FORN TEXT NOT NULL, GCQ4_PED TEXT NOT NULL, GCQ4_DATA TEXT NOT NULL, " + ;
        "GCQ4_VALMERC NUMERIC(18,2) NOT NULL, GCQ4_FRETE NUMERIC(18,2) NOT NULL, GCQ4_TOTAL NUMERIC(18,2) NOT NULL", "GCQ4_NF")
    lOk := lOk .And. BOTAB("GCQ6", "GCQ6_DEV TEXT NOT NULL, GCQ6_NF TEXT NOT NULL, GCQ6_FORN TEXT NOT NULL, GCQ6_PROD TEXT NOT NULL, " + ;
        "GCQ6_QTD NUMERIC(18,4) NOT NULL, GCQ6_VALOR NUMERIC(18,2) NOT NULL, GCQ6_DATA TEXT NOT NULL", "GCQ6_NF")
    lOk := lOk .And. BOTAB("GCQ5", "GCQ5_NF TEXT NOT NULL, GCQ5_PROD TEXT NOT NULL, GCQ5_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GCQ5_PRECO NUMERIC(18,6) NOT NULL, GCQ5_FRETE NUMERIC(18,2) NOT NULL, GCQ5_CUSTO NUMERIC(18,6) NOT NULL, GCQ5_VALOR NUMERIC(18,2) NOT NULL", "GCQ5_NF")
Return lOk

/*/{Protheus.doc} GEBCPXSC
    Solicitacao de compra. cNum vazio = numerada (SC000001...).
    @type Operacao compras
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd, cNecessidade AAAAMMDD}...}
    @return {lOk, cMsg, cNum}
/*/
User Function GEBCPXSC(cNum, aItens, cSolic)
    Local cFil := FWxFilial("GCQ1")
    Local cNec := ""
    Local nI := 0
    cNum := Upper(BOCOL(cNum))
    If aItens == Nil .Or. Len(aItens) == 0
        Return {.F., "sem_itens", ""}
    EndIf
    For nI := 1 To Len(aItens)
        If BOCOL(aItens[nI][1]) == "" .Or. BOVAL(aItens[nI][2]) <= 0
            Return {.F., "item_invalido: " + BONUM(nI, 0), ""}
        EndIf
        If Len(aItens[nI]) >= 3 .And. !(BOCOL(aItens[nI][3]) == "") .And. !BODATAOK(aItens[nI][3])
            Return {.F., "necessidade_invalida: item " + BONUM(nI, 0), ""}
        EndIf
    Next nI
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", ""}
    EndIf
    If cNum == ""
        cNum := "SC" + BOSEQ("CPX_SC", 6)
    ElseIf Len(TCSqlQuery("SELECT GCQ1_NUM FROM GCQ1 WHERE GCQ1_FILIAL = " + GEBDBQuote(cFil) + " AND GCQ1_NUM = " + GEBDBQuote(cNum) + " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "solicitacao_duplicada: " + cNum, ""}
    EndIf
    For nI := 1 To Len(aItens)
        cNec := BOHOJE()
        If Len(aItens[nI]) >= 3 .And. !(BOCOL(aItens[nI][3]) == "")
            cNec := BOCOL(aItens[nI][3])
        EndIf
        TCSqlExec("INSERT INTO GCQ1 (D_E_L_E_T_, GCQ1_FILIAL, GCQ1_NUM, GCQ1_PROD, GCQ1_QTD, GCQ1_NECESS, GCQ1_SOLIC, GCQ1_STATUS, GCQ1_PED) VALUES (' ', " + ;
            GEBDBQuote(cFil) + ", " + GEBDBQuote(cNum) + ", " + GEBDBQuote(BOCOL(aItens[nI][1])) + ", " + BONUM(aItens[nI][2], 4) + ", " + ;
            GEBDBQuote(cNec) + ", " + GEBDBQuote(BOCOL(cSolic)) + ", 'ABERTA', '')")
    Next nI
Return {.T., "solicitacao " + cNum + " gravada", cNum}

/*/{Protheus.doc} GEBCPXPED
    Pedido de compra com varios itens. cPed vazio = numerado (PC000001...).
    @type Operacao compras
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd, nPreco}...}
    @return {lOk, cMsg, {cPed, nTotal, cLiberacao}}
/*/
User Function GEBCPXPED(cPed, cForn, aItens, cCond, cLocal, cData)
    Local cFil := FWxFilial("GCP3")
    Local cLib := "LIBERADO"
    Local nTot := 0
    Local nAlc := 0
    Local nI := 0
    Local aR := {}

    cPed := Upper(BOCOL(cPed))
    cForn := BOCOL(cForn)
    cLocal := BOCOL(cLocal)
    cData := BODATA(cData)
    If cForn == "" .Or. cData == ""
        Return {.F., "fornecedor_ou_data_invalidos", {}}
    EndIf
    If aItens == Nil .Or. Len(aItens) == 0
        Return {.F., "sem_itens", {}}
    EndIf
    For nI := 1 To Len(aItens)
        If BOCOL(aItens[nI][1]) == "" .Or. BOVAL(aItens[nI][2]) <= 0 .Or. BOVAL(aItens[nI][3]) <= 0
            Return {.F., "item_invalido: " + BONUM(nI, 0), {}}
        EndIf
        If CPXPosItem(aItens, BOCOL(aItens[nI][1])) < nI
            Return {.F., "produto_repetido: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        nTot := nTot + Round(BOVAL(aItens[nI][2]) * BOVAL(aItens[nI][3]), 2)
    Next nI
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    If Len(TCSqlQuery("SELECT GCP1_COD FROM GCP1 WHERE GCP1_FILIAL = " + GEBDBQuote(FWxFilial("GCP1")) + " AND GCP1_COD = " + GEBDBQuote(cForn) + " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "fornecedor_inexistente: " + cForn, {}}
    EndIf
    aR := GEBFXPARC(cCond, 1, cData)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    If cPed == ""
        cPed := "PC" + BOSEQ("CPX_PC", 6)
    ElseIf Len(TCSqlQuery("SELECT GCP3_NUM FROM GCP3 WHERE GCP3_FILIAL = " + GEBDBQuote(cFil) + " AND GCP3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "pedido_duplicado: " + cPed, {}}
    EndIf
    nAlc := BOVAL(BOPARM("COM_ALCADA", "0"))
    If nAlc > 0 .And. nTot > nAlc
        cLib := "PENDENTE"
    EndIf
    TCSqlExec("INSERT INTO GCP3 (D_E_L_E_T_, GCP3_FILIAL, GCP3_NUM, GCP3_FORN, GCP3_STATUS) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cPed) + ", " + GEBDBQuote(cForn) + ", 'ABERTO')")
    For nI := 1 To Len(aItens)
        TCSqlExec("INSERT INTO GCP4 (D_E_L_E_T_, GCP4_FILIAL, GCP4_PED, GCP4_PROD, GCP4_QTD, GCP4_PRECO) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GCP4")) + ", " + GEBDBQuote(cPed) + ", " + GEBDBQuote(BOCOL(aItens[nI][1])) + ", " + ;
            BONUM(aItens[nI][2], 4) + ", " + BONUM(aItens[nI][3], 2) + ")")
    Next nI
    TCSqlExec("INSERT INTO GCQ2 (D_E_L_E_T_, GCQ2_FILIAL, GCQ2_PED, GCQ2_COND, GCQ2_LOCAL, GCQ2_EMISSAO, GCQ2_TOTAL, GCQ2_LIB, GCQ2_APROV) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GCQ2")) + ", " + GEBDBQuote(cPed) + ", " + GEBDBQuote(Upper(BOCOL(cCond))) + ", " + GEBDBQuote(cLocal) + ", " + ;
        GEBDBQuote(cData) + ", " + BONUM(nTot, 2) + ", " + GEBDBQuote(cLib) + ", '')")
Return {.T., "pedido " + cPed + " " + cLib, {cPed, nTot, cLib}}

/*/{Protheus.doc} GEBCPXGERA
    Gera os pedidos de uma solicitacao pelo menor preco cotado (GCP2), um
    pedido por fornecedor. Item sem cotacao recusa tudo.
    @type Operacao compras
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {cPed...}}
/*/
User Function GEBCPXGERA(cNumSC, cCond, cLocal, cData)
    Local cFil := FWxFilial("GCQ1")
    Local aHit := {}
    Local aCot := {}
    Local aForn := {}
    Local aPeds := {}
    Local aR := {}
    Local nF := 0
    Local nI := 0
    Local nJ := 0

    cNumSC := Upper(BOCOL(cNumSC))
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GCQ1_PROD AS P, GCQ1_QTD AS Q FROM GCQ1 WHERE GCQ1_FILIAL = " + GEBDBQuote(cFil) + " AND GCQ1_NUM = " + ;
        GEBDBQuote(cNumSC) + " AND GCQ1_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    If Len(aHit) == 0
        Return {.F., "solicitacao_sem_itens_abertos: " + cNumSC, {}}
    EndIf
    For nI := 1 To Len(aHit)
        aCot := TCSqlQuery("SELECT GCP2_FORN AS F, GCP2_PRECO AS PR FROM GCP2 WHERE GCP2_FILIAL = " + GEBDBQuote(FWxFilial("GCP2")) + ;
            " AND GCP2_PROD = " + GEBDBQuote(BOCOL(aHit[nI]:P)) + " AND D_E_L_E_T_ = ' ' ORDER BY GCP2_PRECO, R_E_C_N_O_")
        If Len(aCot) == 0
            Return {.F., "produto_sem_cotacao: " + BOCOL(aHit[nI]:P), {}}
        EndIf
        nF := 0
        For nJ := 1 To Len(aForn)
            If aForn[nJ][1] == BOCOL(aCot[1]:F)
                nF := nJ
            EndIf
        Next nJ
        If nF == 0
            aAdd(aForn, {BOCOL(aCot[1]:F), {}})
            nF := Len(aForn)
        EndIf
        aAdd(aForn[nF][2], {BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q), BOVAL(aCot[1]:PR)})
    Next nI
    For nF := 1 To Len(aForn)
        aR := GEBCPXPED("", aForn[nF][1], aForn[nF][2], cCond, cLocal, cData)
        If !aR[1]
            Return {.F., aR[2], aPeds}
        EndIf
        aAdd(aPeds, aR[3][1])
        For nI := 1 To Len(aForn[nF][2])
            TCSqlExec("UPDATE GCQ1 SET GCQ1_STATUS = 'ATENDIDA', GCQ1_PED = " + GEBDBQuote(aR[3][1]) + " WHERE GCQ1_FILIAL = " + GEBDBQuote(cFil) + ;
                " AND GCQ1_NUM = " + GEBDBQuote(cNumSC) + " AND GCQ1_PROD = " + GEBDBQuote(aForn[nF][2][nI][1]) + " AND GCQ1_STATUS = 'ABERTA' AND D_E_L_E_T_ = ' '")
        Next nI
    Next nF
Return {.T., BONUM(Len(aPeds), 0) + " pedido(s) gerado(s)", aPeds}

/*/{Protheus.doc} GEBCPXAPR
    Libera (lAprova .T.) ou rejeita um pedido PENDENTE de alcada.
    @type Operacao compras
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBCPXAPR(cPed, cUsuario, lAprova)
    Local aP := {}
    Local cLib := "LIBERADO"
    cPed := Upper(BOCOL(cPed))
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aP := CPXPedido(cPed)
    If Len(aP) == 0
        Return {.F., "pedido_inexistente: " + cPed}
    EndIf
    If !(aP[4] == "PENDENTE")
        Return {.F., "pedido_nao_esta_pendente: " + aP[4]}
    EndIf
    If lAprova == Nil .Or. !lAprova
        cLib := "REJEITADO"
    EndIf
    TCSqlExec("UPDATE GCQ2 SET GCQ2_LIB = " + GEBDBQuote(cLib) + ", GCQ2_APROV = " + GEBDBQuote(BOCOL(cUsuario)) + ;
        " WHERE GCQ2_FILIAL = " + GEBDBQuote(FWxFilial("GCQ2")) + " AND GCQ2_PED = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
Return {.T., "pedido " + cPed + " " + cLib}

/*/{Protheus.doc} GEBCPXENT
    Documento de entrada de um pedido.
    @type Operacao compras
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd[, nPreco, cLote, cValidade, cEndereco]}...};
           vazio = todo o pendente. Produto com lote/serie/endereco exige os
           campos (series separadas por ";").
    @param aRet Codigos de retencao (GRT1; lista ou texto com virgulas):
           o valor retido sai do titulo do fornecedor e vai para a Derrama.
    @return {lOk, cMsg, {nTotal, cStatusPedido, aTitulos, nRetido}}
/*/
User Function GEBCPXENT(cNF, cPed, aItens, nFrete, cData, aRet, cChaveNF)
    Local aP := {}
    Local aPend := {}
    Local aRec := {}
    Local aR := {}
    Local aTit := {}
    Local cFil := ""
    Local cStatus := "RECEBIDO"
    Local aReg := {}
    Local aTx := {}
    Local cNCM := ""
    Local nRet := 0
    Local nMerc := 0
    Local nFrAc := 0
    Local nFr := 0
    Local nVal := 0
    Local nPos := 0
    Local nQtd := 0
    Local nPreco := 0
    Local nI := 0

    cNF := Upper(BOCOL(cNF))
    cPed := Upper(BOCOL(cPed))
    nFrete := Round(BOVAL(nFrete), 2)
    cData := BODATA(cData)
    If aItens == Nil
        aItens := {}
    EndIf
    If cNF == "" .Or. cData == "" .Or. nFrete < 0
        Return {.F., "parametros_invalidos: nota, data, frete >= 0", {}}
    EndIf
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aR := GEBRETVAL(aRet)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    aReg := aR[3]
    aP := CPXPedido(cPed)
    If Len(aP) == 0
        Return {.F., "pedido_inexistente: " + cPed, {}}
    EndIf
    cChaveNF := GEBDFEDIG(cChaveNF)
    If !(cChaveNF == "") .And. !(Len(cChaveNF) == 44 .And. GEBDFEDV(Left(cChaveNF, 43)) == Right(cChaveNF, 1))
        Return {.F., "chave_da_nfe_do_fornecedor_invalida", {}}
    EndIf
    If !(aP[3] == "ABERTO") .And. !(aP[3] == "PARCIAL")
        Return {.F., "pedido_nao_esta_aberto: " + aP[3], {}}
    EndIf
    If !(aP[4] == "LIBERADO")
        Return {.F., "pedido_nao_liberado: " + aP[4], {}}
    EndIf
    If Len(TCSqlQuery("SELECT GCQ4_NF FROM GCQ4 WHERE GCQ4_FILIAL = " + GEBDBQuote(FWxFilial("GCQ4")) + " AND GCQ4_NF = " + GEBDBQuote(cNF) + ;
            " AND GCQ4_FORN = " + GEBDBQuote(aP[2]) + " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "nota_duplicada: " + cNF, {}}
    EndIf
    If Len(TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND (GFN3_DOC = " + GEBDBQuote(cNF) + ;
            " OR GFN3_DOC LIKE " + GEBDBQuote(cNF + "/%") + ") AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "titulo_ja_existe: " + cNF, {}}
    EndIf

    // Pendente por item {prod, qtd pendente, preco do pedido}.
    aPend := CPXPendente(cPed)
    If Len(aItens) == 0
        For nI := 1 To Len(aPend)
            If aPend[nI][2] > 0
                aAdd(aRec, {aPend[nI][1], aPend[nI][2], aPend[nI][3], {}})
            EndIf
        Next nI
    Else
        For nI := 1 To Len(aItens)
            nPos := CPXPosItem(aPend, BOCOL(aItens[nI][1]))
            nQtd := BOVAL(aItens[nI][2])
            If nPos == 0
                Return {.F., "produto_fora_do_pedido: " + BOCOL(aItens[nI][1]), {}}
            EndIf
            If nQtd <= 0 .Or. nQtd > aPend[nPos][2]
                Return {.F., "quantidade_acima_do_pendente: " + aPend[nPos][1] + " pendente " + BONUM(aPend[nPos][2], 4), {}}
            EndIf
            nPreco := aPend[nPos][3]
            If Len(aItens[nI]) >= 3 .And. BOVAL(aItens[nI][3]) > 0
                nPreco := BOVAL(aItens[nI][3])
            EndIf
            aAdd(aRec, {aPend[nPos][1], nQtd, nPreco, CPXDetItem(aItens[nI], nQtd)})
        Next nI
    EndIf
    If Len(aRec) == 0
        Return {.F., "nada_a_receber", {}}
    EndIf
    For nI := 1 To Len(aRec)
        nMerc := nMerc + Round(aRec[nI][2] * aRec[nI][3], 2)
        aR := GEBESTVALLOTE(aRec[nI][1], aP[6], "E", aRec[nI][2], aRec[nI][4], "", cData)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
    Next nI

    // Titulos primeiro (valida a condicao antes de mexer no estoque).
    aR := GEBFXTIT("P", cNF, aP[2], nMerc + nFrete, aP[5], cData, "COMPRA " + cPed, "")
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    aTit := aR[3]
    cFil := FWxFilial("GCQ5")
    For nI := 1 To Len(aRec)
        nVal := Round(aRec[nI][2] * aRec[nI][3], 2)
        If nI == Len(aRec)
            nFr := Round(nFrete - nFrAc, 2)
        ElseIf nMerc > 0
            nFr := Round(nFrete * nVal / nMerc, 2)
        EndIf
        nFrAc := nFrAc + nFr
        GEBESTMOV(aRec[nI][1], aP[6], "E", aRec[nI][2], Round((nVal + nFr) / aRec[nI][2], 6), "COMPRA", cNF, cData, aRec[nI][4])
        TCSqlExec("INSERT INTO GCQ5 (D_E_L_E_T_, GCQ5_FILIAL, GCQ5_NF, GCQ5_PROD, GCQ5_QTD, GCQ5_PRECO, GCQ5_FRETE, GCQ5_CUSTO, GCQ5_VALOR) VALUES (' ', " + ;
            GEBDBQuote(cFil) + ", " + GEBDBQuote(cNF) + ", " + GEBDBQuote(aRec[nI][1]) + ", " + BONUM(aRec[nI][2], 4) + ", " + BONUM(aRec[nI][3], 6) + ", " + ;
            BONUM(nFr, 2) + ", " + BONUM(Round((nVal + nFr) / aRec[nI][2], 6), 6) + ", " + BONUM(nVal + nFr, 2) + ")")
        CPXSomaRec(cPed, aRec[nI][1], aRec[nI][2])
        // Credito de IBS/CBS pela aliquota vigente da NCM do produto.
        If GEBDBTableExistsHere("GF1") .And. GEBDBTableExistsHere("GF2")
            cNCM := ""
            aTx := TCSqlQuery("SELECT GF1_NCM AS N FROM GF1 WHERE GF1_FILIAL = " + GEBDBQuote(FWxFilial("GF1")) + " AND GF1_COD = " + ;
                GEBDBQuote(aRec[nI][1]) + " AND D_E_L_E_T_ = ' '")
            If Len(aTx) > 0
                cNCM := BOCOL(aTx[1]:N)
            EndIf
            aTx := ALIQF(cNCM, cData)
            If aTx[1] + aTx[2] > 0
                TCSqlExec("INSERT INTO GCQ7 (D_E_L_E_T_, GCQ7_FILIAL, GCQ7_NF, GCQ7_FORN, GCQ7_PROD, GCQ7_DATA, GCQ7_BASE, GCQ7_IBS, GCQ7_CBS) VALUES (' ', " + ;
                    GEBDBQuote(FWxFilial("GCQ7")) + ", " + GEBDBQuote(cNF) + ", " + GEBDBQuote(aP[2]) + ", " + GEBDBQuote(aRec[nI][1]) + ", " + ;
                    GEBDBQuote(cData) + ", " + BONUM(nVal + nFr, 2) + ", " + BONUM(Round((nVal + nFr) * aTx[1] / 100, 2), 2) + ", " + ;
                    BONUM(Round((nVal + nFr) * aTx[2] / 100, 2), 2) + ")")
            EndIf
        EndIf
    Next nI
    TCSqlExec("INSERT INTO GCQ4 (D_E_L_E_T_, GCQ4_FILIAL, GCQ4_NF, GCQ4_FORN, GCQ4_PED, GCQ4_DATA, GCQ4_VALMERC, GCQ4_FRETE, GCQ4_TOTAL) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GCQ4")) + ", " + GEBDBQuote(cNF) + ", " + GEBDBQuote(aP[2]) + ", " + GEBDBQuote(cPed) + ", " + GEBDBQuote(cData) + ", " + ;
        BONUM(nMerc, 2) + ", " + BONUM(nFrete, 2) + ", " + BONUM(nMerc + nFrete, 2) + ")")
    TCSqlExec("INSERT INTO GCP5 (D_E_L_E_T_, GCP5_FILIAL, GCP5_NF, GCP5_PED, GCP5_STATUS) VALUES (' ', " + GEBDBQuote(FWxFilial("GCP5")) + ", " + ;
        GEBDBQuote(cNF) + ", " + GEBDBQuote(cPed) + ", 'RECEBIDA')")
    GEBCTXLP("COMPRA_ESTOQUE", nMerc + nFrete, cNF, cData)
    If Len(aReg) > 0
        aR := GEBRETAPL(cNF, aP[2], nMerc + nFrete, aReg, cData, aTit)
        nRet := aR[3]
    EndIf

    aPend := CPXPendente(cPed)
    For nI := 1 To Len(aPend)
        If aPend[nI][2] > 0
            cStatus := "PARCIAL"
        EndIf
    Next nI
    TCSqlExec("UPDATE GCP3 SET GCP3_STATUS = " + GEBDBQuote(cStatus) + " WHERE GCP3_FILIAL = " + GEBDBQuote(FWxFilial("GCP3")) + ;
        " AND GCP3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
    // Chave da NF-e do fornecedor: a devolucao de compra referencia a nota dele.
    If !(cChaveNF == "")
        GEBDFEVINC("ENT", cNF, aP[2], cChaveNF)
    EndIf
Return {.T., "entrada " + cNF + " registrada; pedido " + cStatus, {Round(nMerc + nFrete, 2), cStatus, aTit, nRet}}

/*/{Protheus.doc} GEBCPXDEV
    Devolucao de compra: itens de um documento de entrada voltam ao
    fornecedor pelo custo da entrada (com o frete rateado) e pelos mesmos
    lotes. Emite nota de devolucao (GF3 tipo DEVC, que nao e' receita),
    abate os titulos a pagar abertos da nota (da ultima parcela para a
    primeira) e o que ja foi pago vira credito com o fornecedor (GFN2
    DEVF-..., conta 1.01.006). Lancamento DEVOL_COMPRA.
    @type Operacao compras
    @author Peder Munksgaard
    @since 18/10/2026
    @param aItens {{cProd, nQtd}...}
    @return {lOk, cMsg, {cDev, nValor, nAbatido, nCredito}}
/*/
User Function GEBCPXDEV(cNF, cForn, aItens, cData, cChaveForn)
    Local oDfe := Nil
    Local cNota := ""
    Local aDoc := {}
    Local aIt := {}
    Local aHit := {}
    Local aR := {}
    Local aNF := {}
    Local cDev := ""
    Local cLocal := "01"
    Local nQtd := 0
    Local nCU := 0
    Local nVal := 0
    Local nTot := 0
    Local nResto := 0
    Local nTira := 0
    Local nAbat := 0
    Local nI := 0
    Local nJ := 0
    Local nPos := 0

    cNF := Upper(BOCOL(cNF))
    cForn := BOCOL(cForn)
    cData := BODATA(cData)
    If aItens == Nil .Or. Len(aItens) == 0 .Or. cData == ""
        Return {.F., "itens_e_data_obrigatorios", {}}
    EndIf
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aDoc := TCSqlQuery("SELECT GCQ4_PED AS P FROM GCQ4 WHERE GCQ4_FILIAL = " + GEBDBQuote(FWxFilial("GCQ4")) + " AND GCQ4_NF = " + GEBDBQuote(cNF) + ;
        " AND GCQ4_FORN = " + GEBDBQuote(cForn) + " AND D_E_L_E_T_ = ' '")
    If Len(aDoc) == 0
        Return {.F., "entrada_inexistente: " + cNF + " do fornecedor " + cForn, {}}
    EndIf
    cLocal := CPXPedido(BOCOL(aDoc[1]:P))[6]
    aHit := TCSqlQuery("SELECT GCQ5_PROD AS P, GCQ5_QTD AS Q, GCQ5_CUSTO AS CU, COALESCE((SELECT SUM(GCQ6_QTD) FROM GCQ6 WHERE GCQ6_FILIAL = GCQ5_FILIAL " + ;
        "AND GCQ6_NF = GCQ5_NF AND GCQ6_FORN = " + GEBDBQuote(cForn) + " AND GCQ6_PROD = GCQ5_PROD AND GCQ6.D_E_L_E_T_ = ' '), 0) AS QD FROM GCQ5 " + ;
        "WHERE GCQ5_FILIAL = " + GEBDBQuote(FWxFilial("GCQ5")) + " AND GCQ5_NF = " + GEBDBQuote(cNF) + " AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aItens)
        nQtd := BOVAL(aItens[nI][2])
        nPos := 0
        For nJ := 1 To Len(aHit)
            If BOCOL(aHit[nJ]:P) == BOCOL(aItens[nI][1])
                nPos := nJ
            EndIf
        Next nJ
        If nPos == 0
            Return {.F., "produto_fora_da_entrada: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        If nQtd <= 0 .Or. nQtd > BOVAL(aHit[nPos]:Q) - BOVAL(aHit[nPos]:QD)
            Return {.F., "quantidade_acima_do_devolvivel: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        If GEBESTSLD(BOCOL(aItens[nI][1]), cLocal)[1] < nQtd
            Return {.F., "saldo_insuficiente_para_devolver: " + BOCOL(aItens[nI][1]), {}}
        EndIf
        aR := GEBESTVALLOTE(BOCOL(aItens[nI][1]), cLocal, "S", nQtd, {}, cNF, cData)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        nCU := BOVAL(aHit[nPos]:CU)
        aAdd(aIt, {BOCOL(aItens[nI][1]), nQtd, nCU, Round(nQtd * nCU, 2)})
    Next nI
    // NF-e real: devolucao de compra e' uma NF-e de saida (finalidade 4) que referencia a nota do fornecedor.
    cNota := ""
    If BOPARM("DFE_NFE", "N") == "S"
        cChaveForn := GEBDFEDIG(cChaveForn)
        If cChaveForn == ""
            cChaveForn := GEBDFEVINCLE("ENT", cNF, cForn)
        EndIf
        If !(Len(cChaveForn) == 44)
            Return {.F., "informe_a_chave_da_nfe_do_fornecedor (na entrada ou na devolucao)", {}}
        EndIf
        oDfe := JsonObject():New()
        oDfe["ORIGEM"] := "CPXDEV"
        oDfe["DOC"] := cNF
        oDfe["TIPO_PART"] := "F"
        oDfe["PART"] := cForn
        oDfe["TPNF"] := "1"
        oDfe["FINNFE"] := "4"
        oDfe["NATOP"] := "DEVOLUCAO DE COMPRA"
        oDfe["REFS"] := {cChaveForn}
        oDfe["ITENS"] := {}
        For nI := 1 To Len(aIt)
            aAdd(oDfe["ITENS"], {aIt[nI][1], aIt[nI][2], aIt[nI][3], 0})
        Next nI
        aR := GEBDFENFE(oDfe)
        If !aR[1]
            Return {.F., aR[2], {}}
        EndIf
        cNota := aR[3][1]
    EndIf
    cDev := "DC" + BOSEQ("CPX_DEV", 6)
    If cNota == ""
        cNota := cDev
    EndIf
    aR := {}
    For nI := 1 To Len(aIt)
        aAdd(aR, {aIt[nI][1], aIt[nI][2], aIt[nI][3]})
    Next nI
    aNF := GEBFATNOTA(cNota, aR, cData, "DEVC")
    For nI := 1 To Len(aIt)
        GEBESTMOV(aIt[nI][1], cLocal, "S", aIt[nI][2], aIt[nI][3], "DEVCOMPRA", cDev, cData, {}, cNF, .T.)
        TCSqlExec("INSERT INTO GCQ6 (D_E_L_E_T_, GCQ6_FILIAL, GCQ6_DEV, GCQ6_NF, GCQ6_FORN, GCQ6_PROD, GCQ6_QTD, GCQ6_VALOR, GCQ6_DATA) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GCQ6")) + ", " + GEBDBQuote(cDev) + ", " + GEBDBQuote(cNF) + ", " + GEBDBQuote(cForn) + ", " + GEBDBQuote(aIt[nI][1]) + ", " + ;
            BONUM(aIt[nI][2], 4) + ", " + BONUM(aIt[nI][4], 2) + ", " + GEBDBQuote(cData) + ")")
        nTot := nTot + aIt[nI][4]
    Next nI
    nResto := Round(nTot, 2)
    aHit := TCSqlQuery("SELECT GFN3_DOC AS D, GFN3_SALDO AS S FROM GFN3 WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND (GFN3_DOC = " + ;
        GEBDBQuote(cNF) + " OR GFN3_DOC LIKE " + GEBDBQuote(cNF + "/%") + ") AND GFN3_FORN = " + GEBDBQuote(cForn) + " AND GFN3_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' ' ORDER BY GFN3_DOC DESC")
    For nI := 1 To Len(aHit)
        If nResto <= 0
            Exit
        EndIf
        nTira := BOVAL(aHit[nI]:S)
        If nResto < nTira
            nTira := nResto
        EndIf
        TCSqlExec("UPDATE GFN3 SET GFN3_SALDO = GFN3_SALDO - " + BONUM(nTira, 2) + ", GFN3_STATUS = CASE WHEN GFN3_SALDO - " + BONUM(nTira, 2) + ;
            " <= 0 THEN 'ABATIDO' ELSE 'ABERTO' END WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND GFN3_DOC = " + GEBDBQuote(BOCOL(aHit[nI]:D)) + ;
            " AND D_E_L_E_T_ = ' '")
        nAbat := nAbat + nTira
        nResto := Round(nResto - nTira, 2)
    Next nI
    GEBCTXLP("DEVOL_COMPRA", nAbat, cDev + " " + cNF, cData)
    If nResto > 0
        GEBFXTIT("R", "DEVF-" + cDev, cForn, nResto, "0", cData, "DEVOLUCAO COMPRA " + cNF, "1.01.006")
        GEBCTXLP("DEVOL_COMPRA", nResto, cDev + " " + cNF, cData, "1.01.006", "")
    EndIf
Return {.T., "devolucao " + cDev + " registrada (nota " + aNF[1] + ")", {cDev, Round(nTot, 2), Round(nAbat, 2), nResto}}

/*/{Protheus.doc} GEBCPXABERTOS
    Relatorio: pedidos abertos/parciais por item (pedido, fornecedor,
    produto, pedida, recebida, saldo, preco, valor pendente, liberacao).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBCPXABERTOS()
    Local aHit := {}
    Local aLin := {{"pedido", "fornecedor", "produto", "pedida", "recebida", "saldo", "preco", "valor_pendente"}}
    Local aRel := {}
    Local nTot := 0
    Local nSaldo := 0
    Local nI := 0
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GCP3_NUM AS PED, GCP3_FORN AS F, GCP4_PROD AS P, GCP4_QTD AS Q, GCP4_PRECO AS PR, " + ;
        "COALESCE((SELECT SUM(GCQ3_QTDREC) FROM GCQ3 WHERE GCQ3_FILIAL = GCP4_FILIAL AND GCQ3_PED = GCP4_PED AND GCQ3_PROD = GCP4_PROD AND GCQ3.D_E_L_E_T_ = ' '), 0) AS R, " + ;
        "COALESCE((SELECT MAX(GCQ2_LIB) FROM GCQ2 WHERE GCQ2_FILIAL = GCP3_FILIAL AND GCQ2_PED = GCP3_NUM AND GCQ2.D_E_L_E_T_ = ' '), 'LIBERADO') AS LIB " + ;
        "FROM GCP3 JOIN GCP4 ON GCP4_FILIAL = GCP3_FILIAL AND GCP4_PED = GCP3_NUM AND GCP4.D_E_L_E_T_ = ' ' " + ;
        "WHERE GCP3_FILIAL = " + GEBDBQuote(FWxFilial("GCP3")) + " AND GCP3.D_E_L_E_T_ = ' ' AND GCP3_STATUS IN ('ABERTO', 'PARCIAL') ORDER BY GCP3_NUM, GCP4_PROD")
    For nI := 1 To Len(aHit)
        nSaldo := BOVAL(aHit[nI]:Q) - BOVAL(aHit[nI]:R)
        If nSaldo > 0
            nTot := nTot + Round(nSaldo * BOVAL(aHit[nI]:PR), 2)
            aAdd(aLin, {BOCOL(aHit[nI]:PED) + " " + BOCOL(aHit[nI]:LIB), BOCOL(aHit[nI]:F), BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q), ;
                BOVAL(aHit[nI]:R), nSaldo, BOVAL(aHit[nI]:PR), Round(nSaldo * BOVAL(aHit[nI]:PR), 2)})
        EndIf
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", "", "", "", "", "", Round(nTot, 2)})
    BOREL(aRel)
Return {.T., "pedidos_em_aberto", {aLin, {{"valor_pendente", Round(nTot, 2)}, {"itens", Len(aLin) - 1}}}}

/*/{Protheus.doc} GEBCPXPORFORN
    Relatorio: compras por fornecedor no periodo (entradas, mercadoria,
    frete, total).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBCPXPORFORN(cIni, cFim)
    Local aHit := {}
    Local aLin := {{"fornecedor", "nome", "entradas", "mercadoria", "frete", "total"}}
    Local aRel := {}
    Local nTot := 0
    Local nI := 0
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cIni == "" .Or. cFim == "" .Or. cIni > cFim
        Return {.F., "periodo_invalido", {}}
    EndIf
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GCQ4_FORN AS F, COALESCE((SELECT MAX(GCP1_NOME) FROM GCP1 WHERE GCP1_COD = GCQ4_FORN AND GCP1.D_E_L_E_T_ = ' '), '') AS N, " + ;
        "COUNT(*) AS QT, SUM(GCQ4_VALMERC) AS M, SUM(GCQ4_FRETE) AS FR, SUM(GCQ4_TOTAL) AS T FROM GCQ4 WHERE GCQ4_FILIAL = " + GEBDBQuote(FWxFilial("GCQ4")) + ;
        " AND D_E_L_E_T_ = ' ' AND GCQ4_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " GROUP BY GCQ4_FORN ORDER BY 6 DESC")
    For nI := 1 To Len(aHit)
        nTot := nTot + BOVAL(aHit[nI]:T)
        aAdd(aLin, {BOCOL(aHit[nI]:F), BOCOL(aHit[nI]:N), BOVAL(aHit[nI]:QT), BOVAL(aHit[nI]:M), BOVAL(aHit[nI]:FR), BOVAL(aHit[nI]:T)})
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", "", "", "", Round(nTot, 2)})
    BOREL(aRel)
Return {.T., "compras_por_fornecedor", {aLin, {{"total", Round(nTot, 2)}}}}

/*/{Protheus.doc} GEBCPXSCPEND
    Relatorio: solicitacoes de compra abertas (por necessidade).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBCPXSCPEND()
    Local aHit := {}
    Local aLin := {{"solicitacao", "produto", "quantidade", "necessidade", "solicitante", "menor_preco"}}
    Local nI := 0
    If !GEBCPXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GCQ1_NUM AS N, GCQ1_PROD AS P, GCQ1_QTD AS Q, GCQ1_NECESS AS NE, GCQ1_SOLIC AS S, " + ;
        "COALESCE((SELECT MIN(GCP2_PRECO) FROM GCP2 WHERE GCP2_PROD = GCQ1_PROD AND GCP2.D_E_L_E_T_ = ' '), 0) AS MP FROM GCQ1 " + ;
        "WHERE GCQ1_FILIAL = " + GEBDBQuote(FWxFilial("GCQ1")) + " AND D_E_L_E_T_ = ' ' AND GCQ1_STATUS = 'ABERTA' ORDER BY GCQ1_NECESS, GCQ1_NUM")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:N), BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q), BOCOL(aHit[nI]:NE), BOCOL(aHit[nI]:S), BOVAL(aHit[nI]:MP)})
    Next nI
    BOREL(aLin)
Return {.T., "solicitacoes_pendentes", aLin}

// Pedido: {cPed, cForn, cStatus GCP3, cLiberacao, cCond, cLocal}; {} se nao existe.
// Pedido antigo (sem GCQ2) vale como LIBERADO, a vista, armazem 01.
Static Function CPXPedido(cPed)
    Local aHit := TCSqlQuery("SELECT GCP3_FORN AS F, GCP3_STATUS AS ST FROM GCP3 WHERE GCP3_FILIAL = " + GEBDBQuote(FWxFilial("GCP3")) + ;
        " AND GCP3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
    Local aC := {}
    Local cLocal := "01"
    If Len(aHit) == 0
        Return {}
    EndIf
    aC := TCSqlQuery("SELECT GCQ2_LIB AS L, GCQ2_COND AS C, GCQ2_LOCAL AS LC FROM GCQ2 WHERE GCQ2_FILIAL = " + GEBDBQuote(FWxFilial("GCQ2")) + ;
        " AND GCQ2_PED = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' '")
    If Len(aC) == 0
        Return {cPed, BOCOL(aHit[1]:F), BOCOL(aHit[1]:ST), "LIBERADO", "", cLocal}
    EndIf
    If !(BOCOL(aC[1]:LC) == "")
        cLocal := BOCOL(aC[1]:LC)
    EndIf
Return {cPed, BOCOL(aHit[1]:F), BOCOL(aHit[1]:ST), BOCOL(aC[1]:L), BOCOL(aC[1]:C), cLocal}

// Itens do pedido com quantidade pendente: {{cProd, nPendente, nPreco}...}.
Static Function CPXPendente(cPed)
    Local aRet := {}
    Local aHit := TCSqlQuery("SELECT GCP4_PROD AS P, SUM(GCP4_QTD) AS Q, MAX(GCP4_PRECO) AS PR, " + ;
        "COALESCE((SELECT SUM(GCQ3_QTDREC) FROM GCQ3 WHERE GCQ3_FILIAL = GCP4_FILIAL AND GCQ3_PED = GCP4_PED AND GCQ3_PROD = GCP4_PROD AND GCQ3.D_E_L_E_T_ = ' '), 0) AS R " + ;
        "FROM GCP4 WHERE GCP4_FILIAL = " + GEBDBQuote(FWxFilial("GCP4")) + " AND GCP4_PED = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' ' " + ;
        "GROUP BY GCP4_FILIAL, GCP4_PED, GCP4_PROD ORDER BY GCP4_PROD")
    Local nI := 0
    For nI := 1 To Len(aHit)
        aAdd(aRet, {BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:Q) - BOVAL(aHit[nI]:R), BOVAL(aHit[nI]:PR)})
    Next nI
Return aRet

Static Function CPXSomaRec(cPed, cProd, nQtd)
    TCSqlExec("INSERT INTO GCQ3 (D_E_L_E_T_, GCQ3_FILIAL, GCQ3_PED, GCQ3_PROD, GCQ3_QTDREC) VALUES (' ', " + GEBDBQuote(FWxFilial("GCQ3")) + ", " + ;
        GEBDBQuote(cPed) + ", " + GEBDBQuote(cProd) + ", " + BONUM(nQtd, 4) + ")")
Return .T.

// Lotes de um item da entrada: posicoes 4 (lote/series), 5 (validade), 6 (endereco).
Static Function CPXDetItem(aItem, nQtd)
    Local cLote := ""
    Local cValid := ""
    Local cEnder := ""
    If Len(aItem) >= 4
        cLote := BOCOL(aItem[4])
    EndIf
    If Len(aItem) >= 5
        cValid := BOCOL(aItem[5])
    EndIf
    If Len(aItem) >= 6
        cEnder := BOCOL(aItem[6])
    EndIf
Return GEBESTDET(cLote, cValid, cEnder, nQtd)

// Posicao do produto na lista (1a coluna); 0 se nao esta.
Static Function CPXPosItem(aLst, cProd)
    Local nI := 0
    For nI := 1 To Len(aLst)
        If BOCOL(aLst[nI][1]) == cProd
            Return nI
        EndIf
    Next nI
Return 0
