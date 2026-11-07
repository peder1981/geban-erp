#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBFIN_MIG.prw"

/*/{Protheus.doc} GEBFNX
    Financeiro do backoffice (inspirado em SE4/SE1/SE2/SE5/FINA070/FINA080/
    FINR130/FINR150 do Protheus).
    - GFX1 condicao de pagamento: dias de cada parcela ("30,60,90"; "0" =
      a vista). Uma lista de dias tambem pode ser usada direto no lugar
      do codigo.
    - Titulos continuam em GFN2 (receber) / GFN3 (pagar), uma linha por
      parcela (DOC/01, DOC/02...; parcela unica = DOC). GFX2 guarda o
      complemento: emissao, origem, parceiro, valor original e a conta
      contabil do titulo (receber 1.01.003, pagar 2.01.001 se vazia).
      A ultima parcela fica com o centavo do arredondamento.
    - GEBFXBAI: baixa parcial/total com juros, multa e desconto (GFX3),
      movimento na conta (GFX4 + saldo GFN1) e contabilizacao (FIN_REC /
      FIN_PAG pelo principal liquido, FIN_DESC_CONC / FIN_DESC_OBT pelo
      desconto, FIN_JUROS_REC / FIN_JUROS_PAG por juros + multa).
    - GEBFXCALC: juros (GE4 FIN_JUROS_DIA, % ao dia, padrao 0,033) e multa
      (GE4 FIN_MULTA, %, padrao 2) por atraso.
    - GEBFXTRF transferencia entre contas; GEBFXMOV movimento avulso.
    - Relatorios: GEBFXPOSICAO (titulos abertos por faixa de atraso),
      GEBFXEXTRATO (extrato da conta) e GEBFXFLUXO (fluxo projetado).
    O extrato junta GFX4 com os movimentos antigos de GFN4 (GEBFNBAI).
    @type Modulo financeiro
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBFXMIG()
    Local lOk := GEBFNMIG() .And. GEBCTXMIG()
    lOk := lOk .And. BOTAB("GFX1", "GFX1_COD TEXT NOT NULL, GFX1_DESC TEXT NOT NULL, GFX1_DIAS TEXT NOT NULL", "GFX1_COD")
    lOk := lOk .And. BOTAB("GFX2", "GFX2_TIPO TEXT NOT NULL, GFX2_DOC TEXT NOT NULL, GFX2_ORIGDOC TEXT NOT NULL, GFX2_PARC TEXT NOT NULL, " + ;
        "GFX2_PARCEIRO TEXT NOT NULL, GFX2_EMISSAO TEXT NOT NULL, GFX2_ORIGEM TEXT NOT NULL, GFX2_VLORIG NUMERIC(18,2) NOT NULL, " + ;
        "GFX2_CTACTB TEXT NOT NULL", "GFX2_DOC")
    lOk := lOk .And. BOTAB("GFX3", "GFX3_TIPO TEXT NOT NULL, GFX3_DOC TEXT NOT NULL, GFX3_DATA TEXT NOT NULL, GFX3_PRINC NUMERIC(18,2) NOT NULL, " + ;
        "GFX3_JUROS NUMERIC(18,2) NOT NULL, GFX3_MULTA NUMERIC(18,2) NOT NULL, GFX3_DESC NUMERIC(18,2) NOT NULL, " + ;
        "GFX3_TOTAL NUMERIC(18,2) NOT NULL, GFX3_CONTA TEXT NOT NULL", "GFX3_DOC")
    lOk := lOk .And. BOTAB("GFX4", "GFX4_CONTA TEXT NOT NULL, GFX4_DATA TEXT NOT NULL, GFX4_DC TEXT NOT NULL, " + ;
        "GFX4_VALOR NUMERIC(18,2) NOT NULL, GFX4_HIST TEXT NOT NULL, GFX4_DOC TEXT NOT NULL", "GFX4_CONTA")
Return lOk

/*/{Protheus.doc} GEBFXCOND
    Cadastra/altera condicao de pagamento (dias separados por virgula, em
    ordem crescente; "0" = a vista).
    @type Cadastro financeiro
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBFXCOND(cCod, cDesc, cDias)
    Local cFil := FWxFilial("GFX1")
    cCod := Upper(BOCOL(cCod))
    cDias := StrTran(BOCOL(cDias), " ", "")
    If cCod == "" .Or. Len(cCod) > 10
        Return {.F., "codigo_invalido: 1 a 10 caracteres"}
    EndIf
    If Len(FNXDias(cDias)) == 0
        Return {.F., "dias_invalidos: use 0 ou 30,60,90 (crescente)"}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GFX1 SET D_E_L_E_T_ = '*' WHERE GFX1_FILIAL = " + GEBDBQuote(cFil) + " AND GFX1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    If !TCSqlExec("INSERT INTO GFX1 (D_E_L_E_T_, GFX1_FILIAL, GFX1_COD, GFX1_DESC, GFX1_DIAS) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
            GEBDBQuote(cCod) + ", " + GEBDBQuote(BOCOL(cDesc)) + ", " + GEBDBQuote(cDias) + ")")
        Return {.F., "falha_gravacao"}
    EndIf
Return {.T., "condicao " + cCod + " gravada"}

/*/{Protheus.doc} GEBFXPARC
    Parcelas de um valor pela condicao (codigo GFX1 ou lista de dias;
    vazio = a vista).
    @type Calculo financeiro
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {{cVenc, nValor}...}}
/*/
User Function GEBFXPARC(cCond, nValor, cEmissao)
    Local aDias := {}
    Local aP := {}
    Local aHit := {}
    Local nParc := 0
    Local nAcum := 0
    Local nI := 0

    cCond := Upper(BOCOL(cCond))
    nValor := Round(BOVAL(nValor), 2)
    cEmissao := BODATA(cEmissao)
    If cEmissao == ""
        Return {.F., "emissao_invalida", {}}
    EndIf
    If nValor <= 0
        Return {.F., "valor_invalido", {}}
    EndIf
    If cCond == ""
        aDias := {0}
    Else
        If GEBDBTableExistsHere("GFX1")
            aHit := TCSqlQuery("SELECT GFX1_DIAS AS D FROM GFX1 WHERE GFX1_FILIAL = " + GEBDBQuote(FWxFilial("GFX1")) + ;
                " AND GFX1_COD = " + GEBDBQuote(cCond) + " AND D_E_L_E_T_ = ' '")
        EndIf
        If Len(aHit) > 0
            aDias := FNXDias(BOCOL(aHit[1]:D))
        Else
            aDias := FNXDias(cCond)
        EndIf
    EndIf
    If Len(aDias) == 0
        Return {.F., "condicao_inexistente: " + cCond, {}}
    EndIf
    nParc := Round(nValor / Len(aDias), 2)
    For nI := 1 To Len(aDias)
        If nI == Len(aDias)
            nParc := Round(nValor - nAcum, 2)
        EndIf
        aAdd(aP, {BODTADD(cEmissao, aDias[nI]), nParc})
        nAcum := nAcum + nParc
    Next nI
Return {.T., "parcelas", aP}

/*/{Protheus.doc} GEBFXTIT
    Gera os titulos (parcelas) a receber (R) ou a pagar (P).
    @type Servico financeiro
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {{cDocParcela, cVenc, nValor}...}}
/*/
User Function GEBFXTIT(cTipo, cDoc, cParceiro, nValor, cCond, cEmissao, cOrigem, cCtaCtb)
    Local aR := {}
    Local aTit := {}
    Local cTab := ""
    Local cDocP := ""
    Local cParc := ""
    Local nI := 0

    cTipo := Upper(BOCOL(cTipo))
    cDoc := BOCOL(cDoc)
    cParceiro := BOCOL(cParceiro)
    cEmissao := BODATA(cEmissao)
    cCtaCtb := BOCOL(cCtaCtb)
    If !(cTipo == "R") .And. !(cTipo == "P")
        Return {.F., "tipo_invalido: R ou P", {}}
    EndIf
    If cDoc == ""
        Return {.F., "documento_vazio", {}}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aR := GEBFXPARC(cCond, nValor, cEmissao)
    If !aR[1]
        Return aR
    EndIf
    cTab := FNXTab(cTipo)
    If cCtaCtb == ""
        cCtaCtb := FNXCtaPad(cTipo)
    EndIf
    For nI := 1 To Len(aR[3])
        cDocP := FNXDocParc(cDoc, nI, Len(aR[3]))
        If Len(TCSqlQuery("SELECT " + cTab + "_DOC FROM " + cTab + " WHERE " + cTab + "_FILIAL = " + GEBDBQuote(FWxFilial(cTab)) + ;
                " AND " + cTab + "_DOC = " + GEBDBQuote(cDocP) + " AND D_E_L_E_T_ = ' '")) > 0
            Return {.F., "titulo_duplicado: " + cDocP, {}}
        EndIf
    Next nI
    For nI := 1 To Len(aR[3])
        cDocP := FNXDocParc(cDoc, nI, Len(aR[3]))
        cParc := StrZero(nI, 2) + "/" + StrZero(Len(aR[3]), 2)
        TCSqlExec("INSERT INTO " + cTab + " (D_E_L_E_T_, " + cTab + "_FILIAL, " + cTab + "_DOC, " + cTab + FNXColParc(cTipo) + ", " + ;
            cTab + "_VALOR, " + cTab + "_SALDO, " + cTab + "_VENC, " + cTab + "_STATUS) VALUES (' ', " + GEBDBQuote(FWxFilial(cTab)) + ", " + ;
            GEBDBQuote(cDocP) + ", " + GEBDBQuote(cParceiro) + ", " + BONUM(aR[3][nI][2], 2) + ", " + BONUM(aR[3][nI][2], 2) + ", " + ;
            GEBDBQuote(aR[3][nI][1]) + ", 'ABERTO')")
        TCSqlExec("INSERT INTO GFX2 (D_E_L_E_T_, GFX2_FILIAL, GFX2_TIPO, GFX2_DOC, GFX2_ORIGDOC, GFX2_PARC, GFX2_PARCEIRO, GFX2_EMISSAO, " + ;
            "GFX2_ORIGEM, GFX2_VLORIG, GFX2_CTACTB) VALUES (' ', " + GEBDBQuote(FWxFilial("GFX2")) + ", " + GEBDBQuote(cTipo) + ", " + ;
            GEBDBQuote(cDocP) + ", " + GEBDBQuote(cDoc) + ", " + GEBDBQuote(cParc) + ", " + GEBDBQuote(cParceiro) + ", " + GEBDBQuote(cEmissao) + ", " + ;
            GEBDBQuote(BOCOL(cOrigem)) + ", " + BONUM(aR[3][nI][2], 2) + ", " + GEBDBQuote(cCtaCtb) + ")")
        aAdd(aTit, {cDocP, aR[3][nI][1], aR[3][nI][2]})
    Next nI
Return {.T., "titulos gerados", aTit}

/*/{Protheus.doc} GEBFXCALC
    Juros e multa por atraso de um titulo aberto na data.
    @type Calculo financeiro
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {nSaldo, nDiasAtraso, nJuros, nMulta, cVenc}}
/*/
User Function GEBFXCALC(cTipo, cDoc, cData)
    Local aT := {}
    Local nDias := 0
    Local nJuros := 0
    Local nMulta := 0
    cData := BODATA(cData)
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    aT := FNXTitulo(Upper(BOCOL(cTipo)), BOCOL(cDoc))
    If Len(aT) == 0
        Return {.F., "titulo_inexistente: " + BOCOL(cDoc), {}}
    EndIf
    nDias := BODIAS(aT[3], cData)
    If nDias > 0 .And. aT[2] > 0 .And. Left(FNXOrigem(Upper(BOCOL(cTipo)), BOCOL(cDoc))[1], 7) == "DERRAMA"
        // Titulo de guia: regra da Derrama (0,33% ao dia, teto de 20%, multa de 2%).
        nJuros := Min(Round(aT[2] * 0.0033 * nDias, 2), Round(aT[2] * 0.20, 2))
        nMulta := Round(aT[2] * 0.02, 2)
    ElseIf nDias > 0 .And. aT[2] > 0
        nJuros := Round(aT[2] * BOVAL(BOPARM("FIN_JUROS_DIA", "0.033")) / 100 * nDias, 2)
        nMulta := Round(aT[2] * BOVAL(BOPARM("FIN_MULTA", "2")) / 100, 2)
    Else
        nDias := 0
    EndIf
Return {.T., "calculado", {aT[2], nDias, nJuros, nMulta, aT[3]}}

/*/{Protheus.doc} GEBFXBAI
    Baixa (parcial ou total) de titulo a receber (R) ou a pagar (P).
    nJuros/nMulta Nil = calculados por atraso (GEBFXCALC).
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {nSaldoRestante, nTotalMovimentado}}
/*/
User Function GEBFXBAI(cTipo, cDoc, nPrinc, nJuros, nMulta, nDesc, cConta, cData)
    Local aT := {}
    Local aC := {}
    Local cTab := ""
    Local cCtb := ""
    Local cBco := ""
    Local cStatus := "ABERTO"
    Local nSaldo := 0
    Local nTotal := 0

    cTipo := Upper(BOCOL(cTipo))
    cDoc := BOCOL(cDoc)
    cConta := BOCOL(cConta)
    cData := BODATA(cData)
    nPrinc := Round(BOVAL(nPrinc), 2)
    nDesc := Round(BOVAL(nDesc), 2)
    If !(cTipo == "R") .And. !(cTipo == "P")
        Return {.F., "tipo_invalido: R ou P", {}}
    EndIf
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aT := FNXTitulo(cTipo, cDoc)
    If Len(aT) == 0
        Return {.F., "titulo_inexistente: " + cDoc, {}}
    EndIf
    If !(aT[4] == "ABERTO")
        Return {.F., "titulo_nao_esta_aberto: " + cDoc, {}}
    EndIf
    If nPrinc <= 0 .Or. nPrinc > aT[2]
        Return {.F., "principal_invalido: entre 0,01 e o saldo " + BONUM(aT[2], 2), {}}
    EndIf
    If nJuros == Nil .Or. nMulta == Nil
        aC := GEBFXCALC(cTipo, cDoc, cData)
        If nJuros == Nil
            nJuros := Round(aC[3][3] * nPrinc / aT[2], 2)
        EndIf
        If nMulta == Nil
            nMulta := Round(aC[3][4] * nPrinc / aT[2], 2)
        EndIf
    EndIf
    nJuros := Round(BOVAL(nJuros), 2)
    nMulta := Round(BOVAL(nMulta), 2)
    If nJuros < 0 .Or. nMulta < 0 .Or. nDesc < 0 .Or. nDesc > nPrinc
        Return {.F., "valores_invalidos: juros, multa e desconto >= 0; desconto <= principal", {}}
    EndIf
    If cConta == ""
        cConta := "CAIXA"
    EndIf
    If Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + ;
            " AND GFN1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "conta_inexistente: " + cConta, {}}
    EndIf

    nTotal := Round(nPrinc + nJuros + nMulta - nDesc, 2)
    nSaldo := Round(aT[2] - nPrinc, 2)
    If nSaldo == 0
        cStatus := FNXQuitado(cTipo)
    EndIf
    cTab := FNXTab(cTipo)
    TCSqlExec("UPDATE " + cTab + " SET " + cTab + "_SALDO = " + BONUM(nSaldo, 2) + ", " + cTab + "_STATUS = " + GEBDBQuote(cStatus) + ;
        " WHERE " + cTab + "_FILIAL = " + GEBDBQuote(FWxFilial(cTab)) + " AND " + cTab + "_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GFX3 (D_E_L_E_T_, GFX3_FILIAL, GFX3_TIPO, GFX3_DOC, GFX3_DATA, GFX3_PRINC, GFX3_JUROS, GFX3_MULTA, GFX3_DESC, " + ;
        "GFX3_TOTAL, GFX3_CONTA) VALUES (' ', " + GEBDBQuote(FWxFilial("GFX3")) + ", " + GEBDBQuote(cTipo) + ", " + GEBDBQuote(cDoc) + ", " + ;
        GEBDBQuote(cData) + ", " + BONUM(nPrinc, 2) + ", " + BONUM(nJuros, 2) + ", " + BONUM(nMulta, 2) + ", " + BONUM(nDesc, 2) + ", " + ;
        BONUM(nTotal, 2) + ", " + GEBDBQuote(cConta) + ")")
    If cTipo == "R"
        FNXMovConta(cConta, "C", nTotal, "Recebimento " + cDoc, cDoc, cData)
    Else
        FNXMovConta(cConta, "D", nTotal, "Pagamento " + cDoc, cDoc, cData)
    EndIf

    // Contabilizacao: principal liquido, desconto e juros + multa.
    cCtb := FNXCtaTit(cTipo, cDoc)
    cBco := GEBCTXFIN(cConta)
    If cTipo == "R"
        GEBCTXLP("FIN_REC", nPrinc - nDesc, cDoc, cData, cBco, cCtb)
        GEBCTXLP("FIN_DESC_CONC", nDesc, cDoc, cData, "", cCtb)
        GEBCTXLP("FIN_JUROS_REC", nJuros + nMulta, cDoc, cData, cBco, "")
    Else
        GEBCTXLP("FIN_PAG", nPrinc - nDesc, cDoc, cData, cCtb, cBco)
        GEBCTXLP("FIN_DESC_OBT", nDesc, cDoc, cData, cCtb, "")
        GEBCTXLP("FIN_JUROS_PAG", nJuros + nMulta, cDoc, cData, "", cBco)
    EndIf
    If nSaldo == 0
        FNXSinc(cTipo, cDoc)
    EndIf
Return {.T., "baixado", {nSaldo, nTotal}}

// Origem do titulo (GFX2): {cOrigem, cDocOrigem}; titulo sem complemento = {"", ""}.
Static Function FNXOrigem(cTipo, cDoc)
    Local aHit := {}
    If !GEBDBTableExistsHere("GFX2")
        Return {"", ""}
    EndIf
    aHit := TCSqlQuery("SELECT GFX2_ORIGEM AS O, GFX2_ORIGDOC AS D FROM GFX2 WHERE GFX2_FILIAL = " + GEBDBQuote(FWxFilial("GFX2")) + ;
        " AND GFX2_TIPO = " + GEBDBQuote(cTipo) + " AND GFX2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {"", ""}
    EndIf
Return {BOCOL(aHit[1]:O), BOCOL(aHit[1]:D)}

// Titulo quitado: baixa a parcela e, sem titulos abertos, a guia da Derrama;
// quita a linha do fiado do balcao (GV3).
Static Function FNXSinc(cTipo, cDoc)
    Local aO := FNXOrigem(cTipo, cDoc)
    Local cFil := ""
    If Left(aO[1], 7) == "DERRAMA" .And. GEBDBTableExistsHere("GD1")
        If "/" $ cDoc .And. GEBDBTableExistsHere("GD2")
            TCSqlExec("UPDATE GD2 SET GD2_STATUS = 'BAIXADA' WHERE GD2_FILIAL = " + GEBDBQuote(FWxFilial("GD2")) + " AND GD2_GUIA = " + ;
                GEBDBQuote(aO[2]) + " AND GD2_PARC = " + GEBDBQuote(StrZero(Val(SubStr(cDoc, At("/", cDoc) + 1)), 3)) + " AND D_E_L_E_T_ = ' '")
        EndIf
        cFil := FWxFilial("GFN3")
        If Len(TCSqlQuery("SELECT GFN3_DOC FROM GFN3 JOIN GFX2 ON GFX2_FILIAL = GFN3_FILIAL AND GFX2_DOC = GFN3_DOC AND GFX2_TIPO = 'P' " + ;
                "AND GFX2.D_E_L_E_T_ = ' ' WHERE GFN3.D_E_L_E_T_ = ' ' AND GFN3_FILIAL = " + GEBDBQuote(cFil) + " AND GFX2_ORIGDOC = " + ;
                GEBDBQuote(aO[2]) + " AND GFX2_ORIGEM LIKE 'DERRAMA%' AND GFN3_STATUS = 'ABERTO'")) == 0
            TCSqlExec("UPDATE GD1 SET GD1_STATUS = 'BAIXADA' WHERE GD1_FILIAL = " + GEBDBQuote(FWxFilial("GD1")) + " AND GD1_GUIA = " + ;
                GEBDBQuote(aO[2]) + " AND D_E_L_E_T_ = ' '")
        EndIf
    ElseIf Left(aO[1], 10) == "FIADO GV3:" .And. GEBDBTableExistsHere("GV3")
        TCSqlExec("UPDATE GV3 SET GV3_STATUS = 'QUITADA' WHERE GV3_FILIAL = " + GEBDBQuote(FWxFilial("GV3")) + " AND R_E_C_N_O_ = " + ;
            cValToChar(Val(SubStr(aO[1], 11))) + " AND D_E_L_E_T_ = ' '")
    EndIf
Return .T.

/*/{Protheus.doc} GEBFXTRF
    Transferencia entre contas financeiras.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBFXTRF(cOrig, cDest, nValor, cData, cHist)
    cOrig := BOCOL(cOrig)
    cDest := BOCOL(cDest)
    nValor := Round(BOVAL(nValor), 2)
    cData := BODATA(cData)
    If cOrig == "" .Or. cDest == "" .Or. cOrig == cDest .Or. nValor <= 0 .Or. cData == ""
        Return {.F., "parametros_invalidos"}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If !FNXContaOk(cOrig) .Or. !FNXContaOk(cDest)
        Return {.F., "conta_inexistente"}
    EndIf
    If BOCOL(cHist) == ""
        cHist := "Transferencia " + cOrig + " -> " + cDest
    EndIf
    FNXMovConta(cOrig, "D", nValor, cHist, "TRF", cData)
    FNXMovConta(cDest, "C", nValor, cHist, "TRF", cData)
    GEBCTXLP("FIN_TRANSF", nValor, cOrig + "->" + cDest, cData, GEBCTXFIN(cDest), GEBCTXFIN(cOrig))
Return {.T., "transferido"}

/*/{Protheus.doc} GEBFXMOV
    Movimento avulso na conta (C = entrada, D = saida), sem titulo.
    Contabiliza FIN_MOV_REC / FIN_MOV_PAG (cCtaCtb substitui a conta de
    receita/despesa do evento).
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBFXMOV(cConta, cDC, nValor, cHist, cData, cCtaCtb, cCC)
    Local aR := {}
    cConta := BOCOL(cConta)
    cDC := Upper(BOCOL(cDC))
    nValor := Round(BOVAL(nValor), 2)
    cData := BODATA(cData)
    If cConta == "" .Or. !(cDC == "C" .Or. cDC == "D") .Or. nValor <= 0 .Or. cData == ""
        Return {.F., "parametros_invalidos: conta, C/D, valor > 0, data"}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If !FNXContaOk(cConta)
        Return {.F., "conta_inexistente: " + cConta}
    EndIf
    aR := GEBCTXRATEIA(cCC, nValor)
    If !aR[1]
        Return {.F., aR[2]}
    EndIf
    FNXMovConta(cConta, cDC, nValor, BOCOL(cHist), "MOV", cData)
    If cDC == "C"
        GEBCTXLP("FIN_MOV_REC", nValor, BOCOL(cHist), cData, GEBCTXFIN(cConta), BOCOL(cCtaCtb), cCC)
    Else
        GEBCTXLP("FIN_MOV_PAG", nValor, BOCOL(cHist), cData, BOCOL(cCtaCtb), GEBCTXFIN(cConta), cCC)
    EndIf
Return {.T., "movimentado"}

/*/{Protheus.doc} GEBFXDESP
    Despesa a pagar: gera os titulos (GEBFXTIT P) e ja reconhece a despesa
    (FIN_DESPESA: debito cCtaDesp, padrao 4.02.006 Despesas gerais; credito
    Fornecedores), com centro de custo ou rateio.
    @type Operacao financeira
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aTitulos}
/*/
User Function GEBFXDESP(cDoc, cForn, nValor, cCond, cEmissao, cCtaDesp, cCC, cHist)
    Local aR := {}
    Local aT := {}
    cEmissao := BODATA(cEmissao)
    If !GEBFXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aR := GEBCTXRATEIA(cCC, nValor)
    If !aR[1]
        Return {.F., aR[2], {}}
    EndIf
    If !(BOCOL(cCtaDesp) == "") .And. Len(TCSqlQuery("SELECT GC1_CONTA FROM GC1 WHERE GC1_CONTA = " + GEBDBQuote(BOCOL(cCtaDesp)) + " AND D_E_L_E_T_ = ' '")) == 0
        Return {.F., "conta_contabil_inexistente: " + BOCOL(cCtaDesp), {}}
    EndIf
    aT := GEBFXTIT("P", cDoc, cForn, nValor, cCond, cEmissao, "DESPESA " + BOCOL(cHist), "")
    If !aT[1]
        Return aT
    EndIf
    aR := GEBCTXLP("FIN_DESPESA", nValor, BOCOL(cDoc) + " " + BOCOL(cHist), cEmissao, BOCOL(cCtaDesp), "", cCC)
    If !aR[1]
        Return {.F., aR[2], aT[3]}
    EndIf
Return {.T., "despesa lancada", aT[3]}

/*/{Protheus.doc} GEBFXPOSICAO
    Relatorio: titulos abertos (R ou P) na data, por faixa de atraso: a
    vencer, 1-30, 31-60, 61-90 e mais de 90 dias.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aFaixas {faixa, valor}}}
/*/
User Function GEBFXPOSICAO(cTipo, cData)
    Local aHit := {}
    Local aLin := {{"documento", "parceiro", "vencimento", "saldo", "dias_atraso", "faixa"}}
    Local aFx := {{"a vencer", 0}, {"1-30", 0}, {"31-60", 0}, {"61-90", 0}, {"mais de 90", 0}}
    Local aRel := {}
    Local cTab := ""
    Local nDias := 0
    Local nF := 0
    Local nTot := 0
    Local nI := 0

    cTipo := Upper(BOCOL(cTipo))
    cData := BODATA(cData)
    If !(cTipo == "R") .And. !(cTipo == "P")
        Return {.F., "tipo_invalido: R ou P", {}}
    EndIf
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cTab := FNXTab(cTipo)
    aHit := TCSqlQuery("SELECT " + cTab + "_DOC AS DOC, " + cTab + FNXColParc(cTipo) + " AS PAR, " + cTab + "_VENC AS VEN, " + ;
        cTab + "_SALDO AS SAL FROM " + cTab + " WHERE " + cTab + "_FILIAL = " + GEBDBQuote(FWxFilial(cTab)) + ;
        " AND D_E_L_E_T_ = ' ' AND " + cTab + "_STATUS = 'ABERTO' AND " + cTab + "_SALDO > 0 ORDER BY " + cTab + "_VENC, " + cTab + "_DOC")
    For nI := 1 To Len(aHit)
        nDias := 0
        If BODATAOK(BOCOL(aHit[nI]:VEN))
            nDias := BODIAS(BOCOL(aHit[nI]:VEN), cData)
        EndIf
        If nDias <= 0
            nF := 1
            nDias := 0
        ElseIf nDias <= 30
            nF := 2
        ElseIf nDias <= 60
            nF := 3
        ElseIf nDias <= 90
            nF := 4
        Else
            nF := 5
        EndIf
        aFx[nF][2] := Round(aFx[nF][2] + BOVAL(aHit[nI]:SAL), 2)
        nTot := nTot + BOVAL(aHit[nI]:SAL)
        aAdd(aLin, {BOCOL(aHit[nI]:DOC), BOCOL(aHit[nI]:PAR), BOCOL(aHit[nI]:VEN), BOVAL(aHit[nI]:SAL), nDias, aFx[nF][1]})
    Next nI
    aAdd(aFx, {"total", Round(nTot, 2)})
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    For nI := 1 To Len(aFx)
        aAdd(aRel, {"", "", "faixa " + aFx[nI][1], aFx[nI][2]})
    Next nI
    BOREL(aRel)
Return {.T., "posicao", {aLin, aFx}}

/*/{Protheus.doc} GEBFXEXTRATO
    Relatorio: extrato da conta no periodo (saldo anterior, movimentos com
    saldo acumulado, saldo final). Saldo de hoje = GFN1_SALDO.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aResumo, aLinhas (1a = cabecalho)}}
/*/
User Function GEBFXEXTRATO(cConta, cIni, cFim)
    Local aHit := {}
    Local aLin := {{"data", "historico", "documento", "entrada", "saida", "saldo"}}
    Local aRel := {}
    Local cMovs := ""
    Local nAtual := 0
    Local nDepois := 0
    Local nPer := 0
    Local nAnt := 0
    Local nSaldo := 0
    Local nE := 0
    Local nS := 0
    Local nTE := 0
    Local nTS := 0
    Local nI := 0

    cConta := BOCOL(cConta)
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cConta == "" .Or. cIni == "" .Or. cFim == "" .Or. cIni > cFim
        Return {.F., "parametros_invalidos: conta, inicio e fim AAAAMMDD", {}}
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GFN1_SALDO AS S FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + ;
        " AND GFN1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {.F., "conta_inexistente: " + cConta, {}}
    EndIf
    nAtual := BOVAL(aHit[1]:S)
    // Movimentos novos (GFX4) + antigos (GFN4 de GEBFNBAI), com sinal.
    cMovs := "(SELECT GFX4_DATA AS DT, GFX4_HIST AS HI, GFX4_DOC AS DOC, CASE WHEN GFX4_DC = 'C' THEN GFX4_VALOR ELSE -GFX4_VALOR END AS V, R_E_C_N_O_ AS RN " + ;
        "FROM GFX4 WHERE GFX4_FILIAL = " + GEBDBQuote(FWxFilial("GFX4")) + " AND GFX4_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' ' " + ;
        "UNION ALL SELECT GFN4_DATA, 'baixa ' || GFN4_TIPO, '', CASE WHEN GFN4_TIPO = 'REC' THEN GFN4_VALOR ELSE -GFN4_VALOR END, R_E_C_N_O_ " + ;
        "FROM GFN4 WHERE GFN4_FILIAL = " + GEBDBQuote(FWxFilial("GFN4")) + " AND GFN4_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' ') M"
    aHit := TCSqlQuery("SELECT COALESCE(SUM(V), 0) AS S FROM " + cMovs + " WHERE DT > " + GEBDBQuote(cFim))
    nDepois := BOVAL(aHit[1]:S)
    aHit := TCSqlQuery("SELECT DT, HI, DOC, V FROM " + cMovs + " WHERE DT BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " ORDER BY DT, RN")
    For nI := 1 To Len(aHit)
        nPer := nPer + BOVAL(aHit[nI]:V)
    Next nI
    nAnt := Round(nAtual - nDepois - nPer, 2)
    nSaldo := nAnt
    For nI := 1 To Len(aHit)
        nE := 0
        nS := 0
        If BOVAL(aHit[nI]:V) >= 0
            nE := BOVAL(aHit[nI]:V)
        Else
            nS := -BOVAL(aHit[nI]:V)
        EndIf
        nTE := nTE + nE
        nTS := nTS + nS
        nSaldo := Round(nSaldo + nE - nS, 2)
        aAdd(aLin, {BOCOL(aHit[nI]:DT), BOCOL(aHit[nI]:HI), BOCOL(aHit[nI]:DOC), nE, nS, nSaldo})
    Next nI
    aRel := {{"conta " + cConta, "saldo anterior", "", "", "", nAnt}}
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"", "totais / saldo final", "", Round(nTE, 2), Round(nTS, 2), nSaldo})
    BOREL(aRel)
Return {.T., "extrato", {{{"conta", cConta}, {"saldo_anterior", nAnt}, {"entradas", Round(nTE, 2)}, {"saidas", Round(nTS, 2)}, ;
    {"saldo_final", nSaldo}}, aLin}}

/*/{Protheus.doc} GEBFXFLUXO
    Relatorio: fluxo de caixa projetado de cIni por nDias: saldo inicial
    (soma das contas GFN1), titulos vencidos ate cIni na primeira linha,
    depois receber/pagar por dia de vencimento e saldo acumulado.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aResumo}}
/*/
User Function GEBFXFLUXO(cIni, nDias)
    Local aHit := {}
    Local aLin := {{"data", "receber", "pagar", "saldo_do_dia", "saldo_acumulado"}}
    Local cFim := ""
    Local cDia := ""
    Local nSaldo := 0
    Local nIni := 0
    Local nR := 0
    Local nP := 0
    Local nTR := 0
    Local nTP := 0
    Local nI := 0

    cIni := BODATA(cIni)
    nDias := Int(BOVAL(nDias))
    If cIni == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If nDias <= 0
        nDias := 30
    EndIf
    If !GEBFXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cFim := BODTADD(cIni, nDias - 1)
    aHit := TCSqlQuery("SELECT COALESCE(SUM(GFN1_SALDO), 0) AS S FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + " AND D_E_L_E_T_ = ' '")
    nIni := BOVAL(aHit[1]:S)
    nSaldo := nIni
    // Vencidos (antes de cIni) entram no primeiro dia.
    aHit := TCSqlQuery("SELECT CASE WHEN V < " + GEBDBQuote(cIni) + " THEN " + GEBDBQuote(cIni) + " ELSE V END AS DT, SUM(R) AS R, SUM(P) AS P FROM (" + ;
        "SELECT GFN2_VENC AS V, GFN2_SALDO AS R, 0 AS P FROM GFN2 WHERE GFN2_FILIAL = " + GEBDBQuote(FWxFilial("GFN2")) + " AND D_E_L_E_T_ = ' ' AND GFN2_STATUS = 'ABERTO' " + ;
        "UNION ALL SELECT GFN3_VENC, 0, GFN3_SALDO FROM GFN3 WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND D_E_L_E_T_ = ' ' AND GFN3_STATUS = 'ABERTO') T " + ;
        "WHERE V <= " + GEBDBQuote(cFim) + " GROUP BY 1 ORDER BY 1")
    For nI := 1 To Len(aHit)
        cDia := BOCOL(aHit[nI]:DT)
        nR := Round(BOVAL(aHit[nI]:R), 2)
        nP := Round(BOVAL(aHit[nI]:P), 2)
        nTR := nTR + nR
        nTP := nTP + nP
        nSaldo := Round(nSaldo + nR - nP, 2)
        aAdd(aLin, {cDia, nR, nP, Round(nR - nP, 2), nSaldo})
    Next nI
    BOREL(aLin)
Return {.T., "fluxo", {aLin, {{"saldo_inicial", nIni}, {"receber", Round(nTR, 2)}, {"pagar", Round(nTP, 2)}, {"saldo_final", nSaldo}, ;
    {"periodo", cIni + "-" + cFim}}}}

// Movimento na conta sem lancamento contabil (quem chama contabiliza): {lOk, cMsg}.
User Function GEBFXMOVCONTA(cConta, cDC, nValor, cHist, cDoc, cData)
    cConta := BOCOL(cConta)
    cDC := Upper(BOCOL(cDC))
    nValor := Round(BOVAL(nValor), 2)
    cData := BODATA(cData)
    If !(cDC == "C" .Or. cDC == "D") .Or. nValor <= 0 .Or. cData == ""
        Return {.F., "parametros_invalidos"}
    EndIf
    If !GEBFXMIG() .Or. !FNXContaOk(cConta)
        Return {.F., "conta_inexistente: " + cConta}
    EndIf
    FNXMovConta(cConta, cDC, nValor, BOCOL(cHist), BOCOL(cDoc), cData)
Return {.T., "movimentado"}

// Dias "30,60,90" -> {30, 60, 90}; {} se invalido.
Static Function FNXDias(cDias)
    Local aRet := {}
    Local aTok := StrTokArr(StrTran(cDias, " ", ""), ",")
    Local nI := 0
    Local nD := 0
    If Len(aTok) == 0
        Return {}
    EndIf
    For nI := 1 To Len(aTok)
        If !(StrZero(Val(aTok[nI]), Len(aTok[nI])) == aTok[nI]) .Or. Len(aTok[nI]) > 4
            Return {}
        EndIf
        nD := Val(aTok[nI])
        If Len(aRet) > 0 .And. nD <= aRet[Len(aRet)]
            Return {}
        EndIf
        aAdd(aRet, nD)
    Next nI
Return aRet

Static Function FNXTab(cTipo)
    If cTipo == "R"
        Return "GFN2"
    EndIf
Return "GFN3"

Static Function FNXColParc(cTipo)
    If cTipo == "R"
        Return "_CLI"
    EndIf
Return "_FORN"

Static Function FNXQuitado(cTipo)
    If cTipo == "R"
        Return "RECEBIDA"
    EndIf
Return "PAGA"

Static Function FNXCtaPad(cTipo)
    If cTipo == "R"
        Return "1.01.003"
    EndIf
Return "2.01.001"

Static Function FNXDocParc(cDoc, nI, nTot)
    If nTot == 1
        Return cDoc
    EndIf
Return cDoc + "/" + StrZero(nI, 2)

// Titulo: {cDoc, nSaldo, cVenc, cStatus, cParceiro}; {} se nao existe.
Static Function FNXTitulo(cTipo, cDoc)
    Local cTab := FNXTab(cTipo)
    Local aHit := {}
    If !(cTipo == "R") .And. !(cTipo == "P")
        Return {}
    EndIf
    If !GEBDBTableExistsHere(cTab)
        Return {}
    EndIf
    aHit := TCSqlQuery("SELECT " + cTab + "_SALDO AS SAL, " + cTab + "_VENC AS VEN, " + cTab + "_STATUS AS ST, " + cTab + FNXColParc(cTipo) + ;
        " AS PAR FROM " + cTab + " WHERE " + cTab + "_FILIAL = " + GEBDBQuote(FWxFilial(cTab)) + " AND " + cTab + "_DOC = " + GEBDBQuote(cDoc) + ;
        " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {cDoc, Round(BOVAL(aHit[1]:SAL), 2), BOCOL(aHit[1]:VEN), BOCOL(aHit[1]:ST), BOCOL(aHit[1]:PAR)}

// Conta contabil do titulo (GFX2) ou a padrao do tipo.
Static Function FNXCtaTit(cTipo, cDoc)
    Local aHit := TCSqlQuery("SELECT GFX2_CTACTB AS C FROM GFX2 WHERE GFX2_FILIAL = " + GEBDBQuote(FWxFilial("GFX2")) + ;
        " AND GFX2_TIPO = " + GEBDBQuote(cTipo) + " AND GFX2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0 .Or. BOCOL(aHit[1]:C) == ""
        Return FNXCtaPad(cTipo)
    EndIf
Return BOCOL(aHit[1]:C)

Static Function FNXContaOk(cConta)
Return Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_FILIAL = " + GEBDBQuote(FWxFilial("GFN1")) + ;
    " AND GFN1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")) > 0

// Movimento da conta: GFX4 + saldo em GFN1 (C soma, D subtrai).
Static Function FNXMovConta(cConta, cDC, nValor, cHist, cDoc, cData)
    Local cSinal := "+"
    If cDC == "D"
        cSinal := "-"
    EndIf
    TCSqlExec("INSERT INTO GFX4 (D_E_L_E_T_, GFX4_FILIAL, GFX4_CONTA, GFX4_DATA, GFX4_DC, GFX4_VALOR, GFX4_HIST, GFX4_DOC) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GFX4")) + ", " + GEBDBQuote(cConta) + ", " + GEBDBQuote(cData) + ", " + GEBDBQuote(cDC) + ", " + ;
        BONUM(nValor, 2) + ", " + GEBDBQuote(Left(cHist, 120)) + ", " + GEBDBQuote(cDoc) + ")")
    TCSqlExec("UPDATE GFN1 SET GFN1_SALDO = GFN1_SALDO " + cSinal + " " + BONUM(nValor, 2) + " WHERE GFN1_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GFN1")) + " AND GFN1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")
Return .T.
