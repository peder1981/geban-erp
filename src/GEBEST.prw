#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTX.prw"
#include "GEBV_EST.prw"
#include "GEBV_MIG.prw"

/*/{Protheus.doc} GEBEST
    Estoque e custos (inspirado em SB2/MATA240/MATA241/MATA330/MATR900).
    - GES1: saldo por produto + armazem (quantidade, custo medio, valor).
      A GV1 (saldo total do produto, usada pelas telas antigas) e'
      atualizada junto via GEBVESTGV1.
    - GES2: kardex (um movimento por linha, com saldo e custo medio depois).
    - Custo medio ponderado movel: entrada soma qtd x custo ao valor e
      recalcula o CM; saida sai ao CM atual; saldo zerado zera o valor.
      Saida maior que o saldo e' recusada (GE4 EST_NEGATIVO = S libera).
    - GEBESTMOV: servico central de movimento (usado por compras,
      faturamento e frente de loja). GEBESTAJU: inventario (contagem ->
      diferenca ao CM, com lancamento EST_AJ_POS/EST_AJ_NEG). GEBESTTRF:
      transferencia entre armazens ao CM.
    - Relatorios: GEBESTKARDEX (produto/periodo) e GEBESTPOS (posicao
      valorizada, abaixo do minimo).
    @type Modulo estoque
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBESTMIG()
    Local lOk := BOMIG()
    lOk := lOk .And. BOTAB("GES1", "GES1_PROD TEXT NOT NULL, GES1_LOCAL TEXT NOT NULL, GES1_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GES1_CM NUMERIC(18,6) NOT NULL, GES1_VALOR NUMERIC(18,2) NOT NULL", "GES1_PROD")
    lOk := lOk .And. BOTAB("GES2", "GES2_DATA TEXT NOT NULL, GES2_PROD TEXT NOT NULL, GES2_LOCAL TEXT NOT NULL, " + ;
        "GES2_TIPO TEXT NOT NULL, GES2_ORIGEM TEXT NOT NULL, GES2_DOC TEXT NOT NULL, GES2_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GES2_CUSTO NUMERIC(18,6) NOT NULL, GES2_VALOR NUMERIC(18,2) NOT NULL, GES2_SLDQTD NUMERIC(18,4) NOT NULL, " + ;
        "GES2_SLDVAL NUMERIC(18,2) NOT NULL, GES2_CM NUMERIC(18,6) NOT NULL", "GES2_PROD")
    lOk := lOk .And. BOTAB("GES3", "GES3_PROD TEXT NOT NULL, GES3_RASTRO TEXT NOT NULL, GES3_ENDER TEXT NOT NULL", "GES3_PROD")
    lOk := lOk .And. BOTAB("GES4", "GES4_PROD TEXT NOT NULL, GES4_LOCAL TEXT NOT NULL, GES4_LOTE TEXT NOT NULL, GES4_VALID TEXT NOT NULL, " + ;
        "GES4_ENDER TEXT NOT NULL, GES4_QTD NUMERIC(18,4) NOT NULL", "GES4_PROD")
    lOk := lOk .And. BOTAB("GES5", "GES5_LOCAL TEXT NOT NULL, GES5_ENDER TEXT NOT NULL, GES5_DESC TEXT NOT NULL", "GES5_ENDER")
    lOk := lOk .And. BOTAB("GES6", "GES6_DATA TEXT NOT NULL, GES6_DOC TEXT NOT NULL, GES6_REF TEXT NOT NULL, GES6_PROD TEXT NOT NULL, " + ;
        "GES6_LOCAL TEXT NOT NULL, GES6_TIPO TEXT NOT NULL, GES6_LOTE TEXT NOT NULL, GES6_VALID TEXT NOT NULL, GES6_ENDER TEXT NOT NULL, " + ;
        "GES6_QTD NUMERIC(18,4) NOT NULL", "GES6_DOC")
    lOk := lOk .And. BOTAB("GES7", "GES7_COMP TEXT NOT NULL, GES7_PROD TEXT NOT NULL, GES7_LOCAL TEXT NOT NULL, GES7_QTD NUMERIC(18,4) NOT NULL, " + ;
        "GES7_VALOR NUMERIC(18,2) NOT NULL, GES7_CM NUMERIC(18,6) NOT NULL", "GES7_COMP")
    lOk := lOk .And. GEBVMIG()
Return lOk

/*/{Protheus.doc} GEBESTMOV
    Movimenta o estoque com custo.
    @type Servico de estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @param cTipo E (entrada) ou S (saida)
    @param nCusto Custo unitario da entrada (na saida so' vale com lCustoInf)
    @param aDet Lotes/series/enderecos {{cLote, cValidade, cEndereco, nQtd}...}
           (produto controlado; vazio = FEFO na saida, lotes de cDocRef na
           devolucao)
    @param cDocRef Documento de origem de uma devolucao/estorno: os lotes
           voltam/saem pelos lotes daquele documento
    @param lCustoInf Saida ao custo nCusto (devolucao de compra) em vez do CM
    @return {lOk, cMsg, {nCustoUnit, nValor, nCMDepois, nSaldoDepois, aLotesUsados}}
/*/
User Function GEBESTMOV(cProd, cLocal, cTipo, nQtd, nCusto, cOrigem, cDoc, cData, aDet, cDocRef, lCustoInf)
    Local cFil := FWxFilial("GES1")
    Local aSld := {}
    Local nQ := 0
    Local nV := 0
    Local nCM := 0
    Local nCU := 0
    Local nValMov := 0
    Local aCtl := {}
    Local aL := {}
    Local aUse := {}

    cProd := BOCOL(cProd)
    cLocal := ESTLocal(cLocal)
    If aDet == Nil
        aDet := {}
    EndIf
    If lCustoInf == Nil
        lCustoInf := .F.
    EndIf
    cTipo := Upper(BOCOL(cTipo))
    nQtd := BOVAL(nQtd)
    nCusto := BOVAL(nCusto)
    cData := BODATA(cData)
    If cProd == ""
        Return {.F., "produto_vazio", {}}
    EndIf
    If !(cTipo == "E") .And. !(cTipo == "S")
        Return {.F., "tipo_invalido: E ou S", {}}
    EndIf
    If nQtd <= 0
        Return {.F., "quantidade_invalida", {}}
    EndIf
    If nCusto < 0
        Return {.F., "custo_negativo", {}}
    EndIf
    If cData == ""
        Return {.F., "data_invalida", {}}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    If ESTFechado(cData)
        Return {.F., "periodo_fechado: estoque fechado ate " + BOPARM("EST_FECHADO", ""), {}}
    EndIf

    aSld := GEBESTSLD(cProd, cLocal)
    nQ := aSld[1]
    nCM := aSld[2]
    nV := aSld[3]
    If cTipo == "E"
        nCU := nCusto
        nValMov := Round(nQtd * nCusto, 2)
        nQ := nQ + nQtd
        nV := Round(nV + nValMov, 2)
        If nQ > 0
            nCM := Round(nV / nQ, 6)
        EndIf
    Else
        If nQtd > nQ .And. !(BOPARM("EST_NEGATIVO", "N") == "S")
            Return {.F., "saldo_insuficiente: " + cProd + " armazem " + cLocal + " tem " + BONUM(nQ, 4), {}}
        EndIf
        nCU := nCM
        If lCustoInf
            nCU := nCusto
        EndIf
        nValMov := Round(nQtd * nCU, 2)
        nQ := nQ - nQtd
        If nQ == 0
            // Saldo zerado leva o resto do valor (centavos do arredondamento).
            nValMov := Round(nV, 2)
        EndIf
        nV := Round(nV - nValMov, 2)
        If lCustoInf .And. nQ > 0
            nCM := Round(nV / nQ, 6)
        EndIf
    EndIf

    // Lote/serie/endereco (produto controlado em GES3).
    aCtl := ESTCtl(cProd)
    If !(aCtl[1] == "N") .Or. aCtl[2] == "S"
        aL := ESTLotes(cProd, cLocal, cTipo, nQtd, aDet, BOCOL(cDocRef), cData, aCtl)
        If !aL[1]
            Return {.F., aL[2], {}}
        EndIf
        aUse := aL[3]
    EndIf

    TCSqlExec("UPDATE GES1 SET D_E_L_E_T_ = '*' WHERE GES1_FILIAL = " + GEBDBQuote(cFil) + " AND GES1_PROD = " + GEBDBQuote(cProd) + ;
        " AND GES1_LOCAL = " + GEBDBQuote(cLocal) + " AND D_E_L_E_T_ = ' '")
    If !TCSqlExec("INSERT INTO GES1 (D_E_L_E_T_, GES1_FILIAL, GES1_PROD, GES1_LOCAL, GES1_QTD, GES1_CM, GES1_VALOR) VALUES (' ', " + ;
            GEBDBQuote(cFil) + ", " + GEBDBQuote(cProd) + ", " + GEBDBQuote(cLocal) + ", " + BONUM(nQ, 4) + ", " + BONUM(nCM, 6) + ", " + BONUM(nV, 2) + ")")
        Return {.F., "falha_gravacao", {}}
    EndIf
    TCSqlExec("INSERT INTO GES2 (D_E_L_E_T_, GES2_FILIAL, GES2_DATA, GES2_PROD, GES2_LOCAL, GES2_TIPO, GES2_ORIGEM, GES2_DOC, GES2_QTD, " + ;
        "GES2_CUSTO, GES2_VALOR, GES2_SLDQTD, GES2_SLDVAL, GES2_CM) VALUES (' ', " + GEBDBQuote(FWxFilial("GES2")) + ", " + GEBDBQuote(cData) + ", " + ;
        GEBDBQuote(cProd) + ", " + GEBDBQuote(cLocal) + ", " + GEBDBQuote(cTipo) + ", " + GEBDBQuote(BOCOL(cOrigem)) + ", " + GEBDBQuote(BOCOL(cDoc)) + ", " + ;
        BONUM(nQtd, 4) + ", " + BONUM(nCU, 6) + ", " + BONUM(nValMov, 2) + ", " + BONUM(nQ, 4) + ", " + BONUM(nV, 2) + ", " + BONUM(nCM, 6) + ")")
    ESTGrvLotes(cProd, cLocal, cTipo, aUse, BOCOL(cDoc), cData, BOCOL(cDocRef))
    // Saldo total do produto nas telas antigas (GV1).
    If cTipo == "E"
        GEBVESTGV1(cProd, nQtd)
    Else
        GEBVESTGV1(cProd, -nQtd)
    EndIf
Return {.T., "movimentado", {nCU, nValMov, nCM, nQ, aUse}}

/*/{Protheus.doc} GEBESTSLD
    Saldo do produto: {nQtd, nCM, nValor}. cLocal vazio = todos os armazens
    (CM = valor / quantidade).
    @type Servico de estoque
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBESTSLD(cProd, cLocal)
    Local aHit := {}
    Local cW := ""
    Local nQ := 0
    Local nV := 0
    cProd := BOCOL(cProd)
    cLocal := BOCOL(cLocal)
    If !GEBDBTableExistsHere("GES1")
        Return {0, 0, 0}
    EndIf
    cW := " WHERE GES1_FILIAL = " + GEBDBQuote(FWxFilial("GES1")) + " AND GES1_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '"
    If !(cLocal == "")
        cW := cW + " AND GES1_LOCAL = " + GEBDBQuote(cLocal)
        aHit := TCSqlQuery("SELECT GES1_QTD AS Q, GES1_CM AS CM, GES1_VALOR AS V FROM GES1" + cW)
        If Len(aHit) == 0
            Return {0, 0, 0}
        EndIf
        Return {BOVAL(aHit[1]:Q), BOVAL(aHit[1]:CM), BOVAL(aHit[1]:V)}
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(GES1_QTD), 0) AS Q, COALESCE(SUM(GES1_VALOR), 0) AS V FROM GES1" + cW)
    nQ := BOVAL(aHit[1]:Q)
    nV := BOVAL(aHit[1]:V)
    If nQ > 0
        Return {nQ, Round(nV / nQ, 6), nV}
    EndIf
Return {nQ, 0, nV}

/*/{Protheus.doc} GEBESTAJU
    Inventario: informa a quantidade contada; a diferenca entra ou sai ao
    custo medio (sem CM, nCusto informado vale para a entrada) e e'
    contabilizada (EST_AJ_POS / EST_AJ_NEG).
    @type Operacao de estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {nDiferenca, nValor}}
/*/
User Function GEBESTAJU(cProd, cLocal, nContado, nCusto, cDoc, cData, aDet)
    Local aSld := {}
    Local aR := {}
    Local nDif := 0
    Local nCU := 0
    nContado := BOVAL(nContado)
    cLocal := ESTLocal(cLocal)
    cData := BODATA(cData)
    If BOCOL(cProd) == "" .Or. nContado < 0 .Or. cData == ""
        Return {.F., "parametros_invalidos", {}}
    EndIf
    If BOCOL(cDoc) == ""
        cDoc := "INV-" + cData
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aSld := GEBESTSLD(cProd, cLocal)
    nDif := Round(nContado - aSld[1], 4)
    If nDif == 0
        Return {.T., "sem_diferenca", {0, 0}}
    EndIf
    If nDif > 0
        nCU := aSld[2]
        If nCU <= 0
            nCU := BOVAL(nCusto)
        EndIf
        aR := GEBESTMOV(cProd, cLocal, "E", nDif, nCU, "INVENTARIO", cDoc, cData, aDet)
        If aR[1]
            GEBCTXLP("EST_AJ_POS", aR[3][2], cDoc, cData)
        EndIf
    Else
        aR := GEBESTMOV(cProd, cLocal, "S", -nDif, 0, "INVENTARIO", cDoc, cData, aDet)
        If aR[1]
            GEBCTXLP("EST_AJ_NEG", aR[3][2], cDoc, cData)
        EndIf
    EndIf
    If !aR[1]
        Return aR
    EndIf
Return {.T., "ajustado", {nDif, aR[3][2]}}

/*/{Protheus.doc} GEBESTTRF
    Transferencia entre armazens ao custo medio da origem.
    @type Operacao de estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {nValor}}
/*/
User Function GEBESTTRF(cProd, cOrig, cDest, nQtd, cDoc, cData, aDet, cEnderDest)
    Local aR := {}
    Local aEnt := {}
    Local nI := 0
    cOrig := ESTLocal(cOrig)
    cDest := ESTLocal(cDest)
    If cOrig == cDest
        Return {.F., "armazens_iguais", {}}
    EndIf
    If BOCOL(cDoc) == ""
        cDoc := "TRF-" + BOHOJE()
    EndIf
    aR := GEBESTMOV(cProd, cOrig, "S", nQtd, 0, "TRANSFERENCIA", cDoc, cData, aDet)
    If !aR[1]
        Return aR
    EndIf
    // Os mesmos lotes entram no destino (no endereco de destino, se houver).
    For nI := 1 To Len(aR[3][5])
        aAdd(aEnt, {aR[3][5][nI][1], aR[3][5][nI][2], BOCOL(cEnderDest), aR[3][5][nI][4]})
        If BOCOL(cEnderDest) == ""
            aEnt[nI][3] := aR[3][5][nI][3]
        EndIf
    Next nI
    aR := GEBESTMOV(cProd, cDest, "E", nQtd, aR[3][1], "TRANSFERENCIA", cDoc, cData, aEnt)
    If !aR[1]
        Return aR
    EndIf
Return {.T., "transferido", {aR[3][2]}}

/*/{Protheus.doc} GEBESTKARDEX
    Relatorio: kardex do produto no periodo (saldo inicial, cada movimento
    com custo e saldo, saldo final). cLocal vazio = todos os armazens.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aResumo, aLinhas (1a = cabecalho)}}
/*/
User Function GEBESTKARDEX(cProd, cLocal, cIni, cFim)
    Local aHit := {}
    Local aLin := {{"data", "armazem", "tipo", "origem", "documento", "quantidade", "custo_unit", "valor"}}
    Local aRel := {}
    Local cW := ""
    Local nQIni := 0
    Local nVIni := 0
    Local nQ := 0
    Local nV := 0
    Local nEnt := 0
    Local nSai := 0
    Local nSinal := 0
    Local nI := 0

    cProd := BOCOL(cProd)
    cLocal := BOCOL(cLocal)
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cProd == "" .Or. cIni == "" .Or. cFim == "" .Or. cIni > cFim
        Return {.F., "parametros_invalidos: produto, inicio e fim AAAAMMDD", {}}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cW := " WHERE GES2_FILIAL = " + GEBDBQuote(FWxFilial("GES2")) + " AND GES2_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '"
    If !(cLocal == "")
        cW := cW + " AND GES2_LOCAL = " + GEBDBQuote(cLocal)
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_QTD ELSE -GES2_QTD END), 0) AS Q, " + ;
        "COALESCE(SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_VALOR ELSE -GES2_VALOR END), 0) AS V FROM GES2" + cW + " AND GES2_DATA < " + GEBDBQuote(cIni))
    nQIni := BOVAL(aHit[1]:Q)
    nVIni := Round(BOVAL(aHit[1]:V), 2)
    nQ := nQIni
    nV := nVIni
    aHit := TCSqlQuery("SELECT GES2_DATA AS DT, GES2_LOCAL AS LC, GES2_TIPO AS TP, GES2_ORIGEM AS ORI, GES2_DOC AS DOC, GES2_QTD AS Q, " + ;
        "GES2_CUSTO AS CU, GES2_VALOR AS V FROM GES2" + cW + " AND GES2_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + ;
        " ORDER BY GES2_DATA, R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        nSinal := 1
        If BOCOL(aHit[nI]:TP) == "S"
            nSinal := -1
            nSai := nSai + BOVAL(aHit[nI]:Q)
        Else
            nEnt := nEnt + BOVAL(aHit[nI]:Q)
        EndIf
        nQ := nQ + nSinal * BOVAL(aHit[nI]:Q)
        nV := Round(nV + nSinal * BOVAL(aHit[nI]:V), 2)
        aAdd(aLin, {BOCOL(aHit[nI]:DT), BOCOL(aHit[nI]:LC), BOCOL(aHit[nI]:TP), BOCOL(aHit[nI]:ORI), BOCOL(aHit[nI]:DOC), ;
            BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:CU), BOVAL(aHit[nI]:V)})
    Next nI
    aRel := {{"produto " + cProd, "saldo inicial", BONUM(nQIni, 4), BONUM(nVIni, 2)}}
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"", "", "", "saldo final", "", BONUM(nQ, 4), "", nV})
    BOREL(aRel)
Return {.T., "kardex", {{{"produto", cProd}, {"saldo_inicial_qtd", nQIni}, {"saldo_inicial_valor", nVIni}, ;
    {"entradas", nEnt}, {"saidas", nSai}, {"saldo_final_qtd", nQ}, {"saldo_final_valor", nV}}, aLin}}

/*/{Protheus.doc} GEBESTPOS
    Relatorio: posicao do estoque valorizada (por produto e armazem:
    quantidade, custo medio, valor; minimo da GV1 e alerta abaixo do minimo).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBESTPOS(cLocal)
    Local aHit := {}
    Local aLin := {{"produto", "descricao", "armazem", "quantidade", "custo_medio", "valor", "minimo", "situacao"}}
    Local aRel := {}
    Local cW := ""
    Local cSit := ""
    Local nTot := 0
    Local nAbaixo := 0
    Local nI := 0

    cLocal := BOCOL(cLocal)
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cW := " WHERE GES1_FILIAL = " + GEBDBQuote(FWxFilial("GES1")) + " AND GES1.D_E_L_E_T_ = ' '"
    If !(cLocal == "")
        cW := cW + " AND GES1_LOCAL = " + GEBDBQuote(cLocal)
    EndIf
    aHit := TCSqlQuery("SELECT GES1_PROD AS P, COALESCE((SELECT MAX(GF1_DESC) FROM GF1 WHERE GF1_COD = GES1_PROD AND GF1.D_E_L_E_T_ = ' '), '') AS DS, " + ;
        "GES1_LOCAL AS LC, GES1_QTD AS Q, GES1_CM AS CM, GES1_VALOR AS V, " + ;
        "COALESCE((SELECT MAX(GV1_MIN) FROM GV1 WHERE GV1_PROD = GES1_PROD AND GV1.D_E_L_E_T_ = ' '), 0) AS MN FROM GES1" + cW + ;
        " ORDER BY GES1_PROD, GES1_LOCAL")
    For nI := 1 To Len(aHit)
        cSit := "ok"
        If BOVAL(aHit[nI]:Q) < BOVAL(aHit[nI]:MN)
            cSit := "abaixo do minimo"
            nAbaixo := nAbaixo + 1
        EndIf
        nTot := nTot + BOVAL(aHit[nI]:V)
        aAdd(aLin, {BOCOL(aHit[nI]:P), BOCOL(aHit[nI]:DS), BOCOL(aHit[nI]:LC), BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:CM), ;
            BOVAL(aHit[nI]:V), BOVAL(aHit[nI]:MN), cSit})
    Next nI
    aRel := {}
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", "", "", "", Round(nTot, 2), "", BONUM(nAbaixo, 0) + " abaixo do minimo"})
    BOREL(aRel)
Return {.T., "posicao", {aLin, {{"valor_total", Round(nTot, 2)}, {"itens_abaixo_minimo", nAbaixo}}}}

/*/{Protheus.doc} GEBESTCTL
    Controle do produto: rastro N (nenhum), L (lote, com validade opcional)
    ou S (numero de serie: uma unidade por serie) e endereco S/N. So' muda
    com o produto sem saldo (como no Protheus).
    @type Cadastro estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBESTCTL(cProd, cRastro, cEnder)
    Local cFil := FWxFilial("GES3")
    cProd := BOCOL(cProd)
    cRastro := Upper(BOCOL(cRastro))
    cEnder := Upper(BOCOL(cEnder))
    If cProd == "" .Or. AScan({"N", "L", "S"}, cRastro) == 0 .Or. AScan({"N", "S"}, cEnder) == 0
        Return {.F., "parametros_invalidos: rastro N/L/S e endereco S/N"}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If !(GEBESTSLD(cProd, "")[1] == 0)
        Return {.F., "produto_com_saldo: zere o estoque antes de mudar o controle"}
    EndIf
    TCSqlExec("UPDATE GES3 SET D_E_L_E_T_ = '*' WHERE GES3_FILIAL = " + GEBDBQuote(cFil) + " AND GES3_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GES3 (D_E_L_E_T_, GES3_FILIAL, GES3_PROD, GES3_RASTRO, GES3_ENDER) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cProd) + ", " + GEBDBQuote(cRastro) + ", " + GEBDBQuote(cEnder) + ")")
Return {.T., "controle do produto " + cProd + " gravado"}

/*/{Protheus.doc} GEBESTENDER
    Cadastra endereco (armazem + endereco, ex.: 01 / A-01-03).
    @type Cadastro estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBESTENDER(cLocal, cEnder, cDesc)
    Local cFil := FWxFilial("GES5")
    cLocal := ESTLocal(cLocal)
    cEnder := Upper(BOCOL(cEnder))
    If cEnder == ""
        Return {.F., "endereco_vazio"}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If ESTEnderOk(cLocal, cEnder)
        Return {.T., "endereco ja existe"}
    EndIf
    TCSqlExec("INSERT INTO GES5 (D_E_L_E_T_, GES5_FILIAL, GES5_LOCAL, GES5_ENDER, GES5_DESC) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cLocal) + ", " + GEBDBQuote(cEnder) + ", " + GEBDBQuote(BOCOL(cDesc)) + ")")
Return {.T., "endereco " + cLocal + "/" + cEnder + " gravado"}

/*/{Protheus.doc} GEBESTENDTRF
    Muda um lote de endereco dentro do armazem (nao mexe no custo).
    @type Operacao estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBESTENDTRF(cProd, cLocal, cLote, cOrig, cDest, nQtd, cData)
    Local aCtl := {}
    Local aHit := {}
    Local cDoc := ""
    cProd := BOCOL(cProd)
    cLocal := ESTLocal(cLocal)
    cLote := Upper(BOCOL(cLote))
    cOrig := Upper(BOCOL(cOrig))
    cDest := Upper(BOCOL(cDest))
    nQtd := BOVAL(nQtd)
    cData := BODATA(cData)
    If cData == "" .Or. nQtd <= 0 .Or. cOrig == cDest
        Return {.F., "parametros_invalidos"}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If ESTFechado(cData)
        Return {.F., "periodo_fechado"}
    EndIf
    aCtl := ESTCtl(cProd)
    If !(aCtl[2] == "S")
        Return {.F., "produto_sem_controle_de_endereco"}
    EndIf
    If !ESTEnderOk(cLocal, cDest)
        Return {.F., "endereco_inexistente: " + cDest}
    EndIf
    aHit := ESTSaldoLote(cProd, cLocal, cLote, cOrig)
    If Len(aHit) == 0 .Or. aHit[1] < nQtd
        Return {.F., "saldo_insuficiente_no_endereco: " + cOrig}
    EndIf
    cDoc := "END" + BOSEQ("EST_END", 6)
    ESTGrvLotes(cProd, cLocal, "S", {{cLote, aHit[2], cOrig, nQtd}}, cDoc, cData, "")
    ESTGrvLotes(cProd, cLocal, "E", {{cLote, aHit[2], cDest, nQtd}}, cDoc, cData, "")
Return {.T., "lote movido de " + cOrig + " para " + cDest}

/*/{Protheus.doc} GEBESTLOTES
    Relatorio: saldo por lote/serie e endereco (com validade e dias para
    vencer). cProd/cLocal vazios = todos.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBESTLOTES(cProd, cLocal, cData)
    Local aHit := {}
    Local aLin := {{"produto", "armazem", "lote_serie", "validade", "endereco", "quantidade", "dias_para_vencer"}}
    Local cW := ""
    Local nDias := 0
    Local nI := 0
    cData := BODATA(cData)
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    cW := " WHERE GES4_FILIAL = " + GEBDBQuote(FWxFilial("GES4")) + " AND D_E_L_E_T_ = ' ' AND GES4_QTD > 0"
    If !(BOCOL(cProd) == "")
        cW := cW + " AND GES4_PROD = " + GEBDBQuote(BOCOL(cProd))
    EndIf
    If !(BOCOL(cLocal) == "")
        cW := cW + " AND GES4_LOCAL = " + GEBDBQuote(BOCOL(cLocal))
    EndIf
    aHit := TCSqlQuery("SELECT GES4_PROD AS P, GES4_LOCAL AS L, GES4_LOTE AS LT, GES4_VALID AS V, GES4_ENDER AS E, GES4_QTD AS Q FROM GES4" + cW + ;
        " ORDER BY GES4_PROD, GES4_LOCAL, GES4_VALID, GES4_LOTE, GES4_ENDER")
    For nI := 1 To Len(aHit)
        nDias := 0
        If BODATAOK(BOCOL(aHit[nI]:V))
            nDias := BODIAS(cData, BOCOL(aHit[nI]:V))
        EndIf
        aAdd(aLin, {BOCOL(aHit[nI]:P), BOCOL(aHit[nI]:L), BOCOL(aHit[nI]:LT), BOCOL(aHit[nI]:V), BOCOL(aHit[nI]:E), BOVAL(aHit[nI]:Q), nDias})
    Next nI
    BOREL(aLin)
Return {.T., "saldo_por_lote", aLin}

/*/{Protheus.doc} GEBESTVENCER
    Relatorio: lotes vencidos ou vencendo em ate nDias a partir de cData.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBESTVENCER(nDias, cData)
    Local aR := {}
    Local aLin := {{"produto", "armazem", "lote_serie", "validade", "endereco", "quantidade", "situacao"}}
    Local nI := 0
    nDias := Int(BOVAL(nDias))
    If nDias <= 0
        nDias := 30
    EndIf
    aR := GEBESTLOTES("", "", cData)
    If !aR[1]
        Return aR
    EndIf
    For nI := 2 To Len(aR[3])
        If !(aR[3][nI][4] == "") .And. aR[3][nI][7] <= nDias
            If aR[3][nI][7] < 0
                aAdd(aLin, {aR[3][nI][1], aR[3][nI][2], aR[3][nI][3], aR[3][nI][4], aR[3][nI][5], aR[3][nI][6], "vencido"})
            Else
                aAdd(aLin, {aR[3][nI][1], aR[3][nI][2], aR[3][nI][3], aR[3][nI][4], aR[3][nI][5], aR[3][nI][6], "vence em " + BONUM(aR[3][nI][7], 0) + " dias"})
            EndIf
        EndIf
    Next nI
    BOREL(aLin)
Return {.T., "lotes_a_vencer", aLin}

/*/{Protheus.doc} GEBESTFECHA
    Fechamento mensal do estoque (como a virada de saldo SB9 do Protheus):
    grava o saldo de cada produto/armazem no fim da competencia (GES7, pelo
    kardex) e bloqueia movimentos com data ate ela (GE4 EST_FECHADO). Fecha
    em ordem: a proxima depois da ultima fechada; o mes corrente nao fecha.
    @type Operacao estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, nItens}
/*/
User Function GEBESTFECHA(cComp)
    Local cUlt := ""
    Local cFim := ""
    Local aHit := {}
    Local nQ := 0
    Local nV := 0
    Local nCM := 0
    Local nI := 0
    cComp := BOCOL(cComp)
    If !BOCOMPOK(cComp)
        Return {.F., "competencia_invalida: use AAAAMM", 0}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    cUlt := BOPARM("EST_FECHADO", "")
    If !(cUlt == "") .And. !(cComp == BOMESADD(cUlt, 1))
        Return {.F., "feche_em_ordem: proxima competencia e' " + BOMESADD(cUlt, 1), 0}
    EndIf
    If cComp >= Left(BOHOJE(), 6)
        Return {.F., "competencia_ainda_aberta: so' fecha mes encerrado", 0}
    EndIf
    cFim := BOFIMMES(cComp)
    TCSqlExec("DELETE FROM GES7 WHERE GES7_FILIAL = " + GEBDBQuote(FWxFilial("GES7")) + " AND GES7_COMP = " + GEBDBQuote(cComp))
    aHit := TCSqlQuery("SELECT GES2_PROD AS P, GES2_LOCAL AS L, SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_QTD ELSE -GES2_QTD END) AS Q, " + ;
        "SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_VALOR ELSE -GES2_VALOR END) AS V FROM GES2 WHERE GES2_FILIAL = " + GEBDBQuote(FWxFilial("GES2")) + ;
        " AND D_E_L_E_T_ = ' ' AND GES2_DATA <= " + GEBDBQuote(cFim) + " GROUP BY GES2_PROD, GES2_LOCAL ORDER BY 1, 2")
    For nI := 1 To Len(aHit)
        nQ := BOVAL(aHit[nI]:Q)
        nV := Round(BOVAL(aHit[nI]:V), 2)
        nCM := 0
        If nQ > 0
            nCM := Round(nV / nQ, 6)
        EndIf
        TCSqlExec("INSERT INTO GES7 (D_E_L_E_T_, GES7_FILIAL, GES7_COMP, GES7_PROD, GES7_LOCAL, GES7_QTD, GES7_VALOR, GES7_CM) VALUES (' ', " + ;
            GEBDBQuote(FWxFilial("GES7")) + ", " + GEBDBQuote(cComp) + ", " + GEBDBQuote(BOCOL(aHit[nI]:P)) + ", " + GEBDBQuote(BOCOL(aHit[nI]:L)) + ", " + ;
            BONUM(nQ, 4) + ", " + BONUM(nV, 2) + ", " + BONUM(nCM, 6) + ")")
    Next nI
    BOSETPARM("EST_FECHADO", cComp)
Return {.T., "estoque fechado em " + cComp + " (" + BONUM(Len(aHit), 0) + " saldos)", Len(aHit)}

/*/{Protheus.doc} GEBESTREABRE
    Reabre a ultima competencia fechada.
    @type Operacao estoque
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBESTREABRE(cComp)
    Local aHit := {}
    Local cAnt := ""
    cComp := BOCOL(cComp)
    If !GEBESTMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If !(cComp == BOPARM("EST_FECHADO", "")) .Or. cComp == ""
        Return {.F., "so_reabre_a_ultima_fechada: " + BOPARM("EST_FECHADO", "(nenhuma)")}
    EndIf
    TCSqlExec("DELETE FROM GES7 WHERE GES7_FILIAL = " + GEBDBQuote(FWxFilial("GES7")) + " AND GES7_COMP = " + GEBDBQuote(cComp))
    aHit := TCSqlQuery("SELECT MAX(GES7_COMP) AS C FROM GES7 WHERE GES7_FILIAL = " + GEBDBQuote(FWxFilial("GES7")) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) > 0
        cAnt := BOCOL(aHit[1]:C)
    EndIf
    BOSETPARM("EST_FECHADO", cAnt)
Return {.T., "competencia " + cComp + " reaberta"}

/*/{Protheus.doc} GEBESTFECHREL
    Relatorio: fechamento da competencia por produto/armazem (saldo do
    fechamento anterior, entradas, saidas e saldo final, em quantidade e
    valor) com a conferencia inicial + entradas - saidas = final.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBESTFECHREL(cComp)
    Local aHit := {}
    Local aAnt := {}
    Local aMov := {}
    Local aLin := {{"produto", "armazem", "qtd_inicial", "valor_inicial", "entradas_valor", "saidas_valor", "qtd_final", "valor_final"}}
    Local aRel := {}
    Local cAnt := ""
    Local cIni := ""
    Local cFim := ""
    Local nQI := 0
    Local nVI := 0
    Local nE := 0
    Local nS := 0
    Local nQE := 0
    Local nQS := 0
    Local nTot := 0
    Local nDif := 0
    Local nI := 0
    cComp := BOCOL(cComp)
    If !BOCOMPOK(cComp)
        Return {.F., "competencia_invalida", {}}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GES7_PROD AS P, GES7_LOCAL AS L, GES7_QTD AS Q, GES7_VALOR AS V FROM GES7 WHERE GES7_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GES7")) + " AND GES7_COMP = " + GEBDBQuote(cComp) + " AND D_E_L_E_T_ = ' ' ORDER BY 1, 2")
    If Len(aHit) == 0
        Return {.F., "competencia_nao_fechada: " + cComp, {}}
    EndIf
    cAnt := BOMESADD(cComp, -1)
    cIni := cComp + "01"
    cFim := BOFIMMES(cComp)
    For nI := 1 To Len(aHit)
        aAnt := TCSqlQuery("SELECT GES7_QTD AS Q, GES7_VALOR AS V FROM GES7 WHERE GES7_FILIAL = " + GEBDBQuote(FWxFilial("GES7")) + ;
            " AND GES7_COMP = " + GEBDBQuote(cAnt) + " AND GES7_PROD = " + GEBDBQuote(BOCOL(aHit[nI]:P)) + " AND GES7_LOCAL = " + GEBDBQuote(BOCOL(aHit[nI]:L)) + ;
            " AND D_E_L_E_T_ = ' '")
        nQI := 0
        nVI := 0
        If Len(aAnt) > 0
            nQI := BOVAL(aAnt[1]:Q)
            nVI := BOVAL(aAnt[1]:V)
        Else
            // Sem fechamento anterior: saldo do kardex antes do mes.
            aAnt := TCSqlQuery("SELECT COALESCE(SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_QTD ELSE -GES2_QTD END), 0) AS Q, " + ;
                "COALESCE(SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_VALOR ELSE -GES2_VALOR END), 0) AS V FROM GES2 WHERE GES2_FILIAL = " + ;
                GEBDBQuote(FWxFilial("GES2")) + " AND D_E_L_E_T_ = ' ' AND GES2_PROD = " + GEBDBQuote(BOCOL(aHit[nI]:P)) + ;
                " AND GES2_LOCAL = " + GEBDBQuote(BOCOL(aHit[nI]:L)) + " AND GES2_DATA < " + GEBDBQuote(cIni))
            nQI := BOVAL(aAnt[1]:Q)
            nVI := BOVAL(aAnt[1]:V)
        EndIf
        aMov := TCSqlQuery("SELECT COALESCE(SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_QTD ELSE 0 END), 0) AS QE, " + ;
            "COALESCE(SUM(CASE WHEN GES2_TIPO = 'S' THEN GES2_QTD ELSE 0 END), 0) AS QS, " + ;
            "COALESCE(SUM(CASE WHEN GES2_TIPO = 'E' THEN GES2_VALOR ELSE 0 END), 0) AS E, " + ;
            "COALESCE(SUM(CASE WHEN GES2_TIPO = 'S' THEN GES2_VALOR ELSE 0 END), 0) AS S FROM GES2 WHERE GES2_FILIAL = " + GEBDBQuote(FWxFilial("GES2")) + ;
            " AND D_E_L_E_T_ = ' ' AND GES2_PROD = " + GEBDBQuote(BOCOL(aHit[nI]:P)) + " AND GES2_LOCAL = " + GEBDBQuote(BOCOL(aHit[nI]:L)) + ;
            " AND GES2_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim))
        nQE := BOVAL(aMov[1]:QE)
        nQS := BOVAL(aMov[1]:QS)
        nE := Round(BOVAL(aMov[1]:E), 2)
        nS := Round(BOVAL(aMov[1]:S), 2)
        If !(Round(nQI + nQE - nQS, 4) == Round(BOVAL(aHit[nI]:Q), 4)) .Or. !(Round(nVI + nE - nS, 2) == Round(BOVAL(aHit[nI]:V), 2))
            nDif := nDif + 1
        EndIf
        nTot := nTot + BOVAL(aHit[nI]:V)
        aAdd(aLin, {BOCOL(aHit[nI]:P), BOCOL(aHit[nI]:L), nQI, Round(nVI, 2), nE, nS, BOVAL(aHit[nI]:Q), BOVAL(aHit[nI]:V)})
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"total", "", "", "", "", "", "", Round(nTot, 2)})
    BOREL(aRel)
Return {.T., "fechamento", {aLin, {{"competencia", cComp}, {"valor_final", Round(nTot, 2)}, {"divergencias", nDif}}}}

// Confere (sem gravar) se o movimento acha os lotes/enderecos: {lOk, cMsg}.
// Produto sem controle devolve .T.
User Function GEBESTVALLOTE(cProd, cLocal, cTipo, nQtd, aDet, cDocRef, cData)
    Local aCtl := {}
    Local aL := {}
    If aDet == Nil
        aDet := {}
    EndIf
    If !GEBESTMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    aCtl := ESTCtl(BOCOL(cProd))
    If aCtl[1] == "N" .And. !(aCtl[2] == "S")
        Return {.T., ""}
    EndIf
    aL := ESTLotes(BOCOL(cProd), ESTLocal(cLocal), Upper(BOCOL(cTipo)), BOVAL(nQtd), aDet, BOCOL(cDocRef), BODATA(cData), aCtl)
Return {aL[1], aL[2]}

// Lotes de um item da API/tela: lote (series separadas por ";"), validade, endereco, quantidade.
User Function GEBESTDET(cLote, cValid, cEnder, nQtd)
    Local aRet := {}
    Local aSer := {}
    Local nI := 0
    cLote := BOCOL(cLote)
    If cLote == "" .And. BOCOL(cEnder) == ""
        Return {}
    EndIf
    If ";" $ cLote
        aSer := StrTokArr(cLote, ";")
        For nI := 1 To Len(aSer)
            If !(AllTrim(aSer[nI]) == "")
                aAdd(aRet, {AllTrim(aSer[nI]), BOCOL(cValid), BOCOL(cEnder), 1})
            EndIf
        Next nI
        Return aRet
    EndIf
Return {{cLote, BOCOL(cValid), BOCOL(cEnder), BOVAL(nQtd)}}

// Controle do produto: {cRastro N/L/S, cEndereco S/N}.
Static Function ESTCtl(cProd)
    Local aHit := {}
    If !GEBDBTableExistsHere("GES3")
        Return {"N", "N"}
    EndIf
    aHit := TCSqlQuery("SELECT GES3_RASTRO AS R, GES3_ENDER AS E FROM GES3 WHERE GES3_FILIAL = " + GEBDBQuote(FWxFilial("GES3")) + ;
        " AND GES3_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {"N", "N"}
    EndIf
Return {BOCOL(aHit[1]:R), BOCOL(aHit[1]:E)}

Static Function ESTEnderOk(cLocal, cEnder)
Return Len(TCSqlQuery("SELECT GES5_ENDER FROM GES5 WHERE GES5_FILIAL = " + GEBDBQuote(FWxFilial("GES5")) + " AND GES5_LOCAL = " + ;
    GEBDBQuote(cLocal) + " AND GES5_ENDER = " + GEBDBQuote(cEnder) + " AND D_E_L_E_T_ = ' '")) > 0

// Data dentro de uma competencia fechada?
Static Function ESTFechado(cData)
    Local cF := BOPARM("EST_FECHADO", "")
Return !(cF == "") .And. Left(cData, 6) <= cF

// {nQtd, cValidade} do lote no endereco; {} se nao ha linha.
Static Function ESTSaldoLote(cProd, cLocal, cLote, cEnder)
    Local aHit := TCSqlQuery("SELECT GES4_QTD AS Q, GES4_VALID AS V FROM GES4 WHERE GES4_FILIAL = " + GEBDBQuote(FWxFilial("GES4")) + ;
        " AND GES4_PROD = " + GEBDBQuote(cProd) + " AND GES4_LOCAL = " + GEBDBQuote(cLocal) + " AND GES4_LOTE = " + GEBDBQuote(cLote) + ;
        " AND GES4_ENDER = " + GEBDBQuote(cEnder) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {}
    EndIf
Return {BOVAL(aHit[1]:Q), BOCOL(aHit[1]:V)}

// Resolve os lotes/enderecos do movimento: {lOk, cMsg, {{cLote, cValid, cEnder, nQtd}...}}.
Static Function ESTLotes(cProd, cLocal, cTipo, nQtd, aDet, cDocRef, cData, aCtl)
    Local aUse := {}
    Local aHit := {}
    Local aSl := {}
    Local cRast := aCtl[1]
    Local lEnd := aCtl[2] == "S"
    Local lVenc := BOPARM("EST_VENCIDO", "N") == "S"
    Local cLote := ""
    Local cValid := ""
    Local cEnder := ""
    Local cTpRef := "S"
    Local nQ := 0
    Local nSoma := 0
    Local nResto := 0
    Local nI := 0
    Local nJ := 0

    If Len(aDet) > 0
        For nI := 1 To Len(aDet)
            cLote := Upper(BOCOL(aDet[nI][1]))
            cValid := BOCOL(aDet[nI][2])
            cEnder := Upper(BOCOL(aDet[nI][3]))
            nQ := BOVAL(aDet[nI][4])
            If nQ <= 0
                Return {.F., "quantidade_do_lote_invalida", {}}
            EndIf
            If cRast == "N"
                cLote := ""
                cValid := ""
            ElseIf cLote == ""
                Return {.F., "lote_obrigatorio: " + cProd, {}}
            EndIf
            If cRast == "S" .And. !(nQ == 1)
                Return {.F., "serie_tem_quantidade_1: " + cLote, {}}
            EndIf
            If !lEnd
                cEnder := ""
            ElseIf cEnder == ""
                Return {.F., "endereco_obrigatorio: " + cProd, {}}
            EndIf
            If !(cValid == "") .And. !BODATAOK(cValid)
                Return {.F., "validade_invalida: " + cValid, {}}
            EndIf
            For nJ := 1 To Len(aUse)
                If aUse[nJ][1] == cLote .And. aUse[nJ][3] == cEnder .And. cRast == "S"
                    Return {.F., "serie_repetida: " + cLote, {}}
                EndIf
            Next nJ
            If cTipo == "E"
                If lEnd .And. !ESTEnderOk(cLocal, cEnder)
                    Return {.F., "endereco_inexistente: " + cLocal + "/" + cEnder, {}}
                EndIf
                If cRast == "S" .And. Len(TCSqlQuery("SELECT GES4_LOTE FROM GES4 WHERE GES4_FILIAL = " + GEBDBQuote(FWxFilial("GES4")) + ;
                        " AND GES4_PROD = " + GEBDBQuote(cProd) + " AND GES4_LOTE = " + GEBDBQuote(cLote) + " AND GES4_QTD > 0 AND D_E_L_E_T_ = ' '")) > 0
                    Return {.F., "serie_ja_em_estoque: " + cLote, {}}
                EndIf
            Else
                aSl := ESTSaldoLote(cProd, cLocal, cLote, cEnder)
                If Len(aSl) == 0 .Or. aSl[1] < nQ
                    Return {.F., "saldo_do_lote_insuficiente: " + cLote + " " + cEnder, {}}
                EndIf
                cValid := aSl[2]
                If !lVenc .And. !(cValid == "") .And. cValid < cData
                    Return {.F., "lote_vencido: " + cLote + " em " + cValid, {}}
                EndIf
            EndIf
            nSoma := nSoma + nQ
            aAdd(aUse, {cLote, cValid, cEnder, nQ})
        Next nI
        If !(Round(nSoma, 4) == Round(nQtd, 4))
            Return {.F., "lotes_somam_" + BONUM(nSoma, 4) + "_e_o_movimento_e_" + BONUM(nQtd, 4), {}}
        EndIf
        Return {.T., "", aUse}
    EndIf

    nResto := nQtd
    If !(cDocRef == "")
        // Devolucao/estorno: os lotes do documento de origem (menos o que ja voltou).
        If cTipo == "S"
            cTpRef := "E"
        EndIf
        aHit := TCSqlQuery("SELECT GES6_LOTE AS LT, MAX(GES6_VALID) AS V, GES6_ENDER AS E, SUM(GES6_QTD) - COALESCE((SELECT SUM(R.GES6_QTD) FROM GES6 R " + ;
            "WHERE R.GES6_FILIAL = G.GES6_FILIAL AND R.GES6_REF = " + GEBDBQuote(cDocRef) + " AND R.GES6_PROD = G.GES6_PROD AND R.GES6_TIPO = " + GEBDBQuote(cTipo) + ;
            " AND R.GES6_LOTE = G.GES6_LOTE AND R.GES6_ENDER = G.GES6_ENDER AND R.D_E_L_E_T_ = ' '), 0) AS Q FROM GES6 G WHERE G.GES6_FILIAL = " + ;
            GEBDBQuote(FWxFilial("GES6")) + " AND G.GES6_DOC = " + GEBDBQuote(cDocRef) + " AND G.GES6_PROD = " + GEBDBQuote(cProd) + ;
            " AND G.GES6_TIPO = " + GEBDBQuote(cTpRef) + " AND G.D_E_L_E_T_ = ' ' GROUP BY G.GES6_FILIAL, G.GES6_PROD, G.GES6_LOTE, G.GES6_ENDER ORDER BY 1, 3")
        For nI := 1 To Len(aHit)
            If nResto <= 0
                Exit
            EndIf
            nQ := BOVAL(aHit[nI]:Q)
            If nQ > nResto
                nQ := nResto
            EndIf
            If cTipo == "S" .And. nQ > 0
                aSl := ESTSaldoLote(cProd, cLocal, BOCOL(aHit[nI]:LT), BOCOL(aHit[nI]:E))
                If Len(aSl) == 0 .Or. aSl[1] < nQ
                    Return {.F., "lote_do_documento_sem_saldo: " + BOCOL(aHit[nI]:LT), {}}
                EndIf
            EndIf
            If nQ > 0
                aAdd(aUse, {BOCOL(aHit[nI]:LT), BOCOL(aHit[nI]:V), BOCOL(aHit[nI]:E), nQ})
                nResto := Round(nResto - nQ, 4)
            EndIf
        Next nI
        If nResto > 0
            Return {.F., "lotes_do_documento_insuficientes: " + cDocRef, {}}
        EndIf
        Return {.T., "", aUse}
    EndIf

    If cTipo == "E"
        If !(cRast == "N")
            Return {.F., "lote_obrigatorio: " + cProd, {}}
        EndIf
        Return {.F., "endereco_obrigatorio: " + cProd, {}}
    EndIf
    // Saida sem lote informado: FEFO (vence primeiro, sai primeiro), sem vencidos.
    aHit := TCSqlQuery("SELECT GES4_LOTE AS LT, GES4_VALID AS V, GES4_ENDER AS E, GES4_QTD AS Q FROM GES4 WHERE GES4_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GES4")) + " AND GES4_PROD = " + GEBDBQuote(cProd) + " AND GES4_LOCAL = " + GEBDBQuote(cLocal) + ;
        " AND GES4_QTD > 0 AND D_E_L_E_T_ = ' ' ORDER BY CASE WHEN GES4_VALID = '' THEN '99999999' ELSE GES4_VALID END, GES4_LOTE, GES4_ENDER")
    For nI := 1 To Len(aHit)
        If nResto <= 0
            Exit
        EndIf
        If lVenc .Or. BOCOL(aHit[nI]:V) == "" .Or. BOCOL(aHit[nI]:V) >= cData
            nQ := BOVAL(aHit[nI]:Q)
            If nQ > nResto
                nQ := nResto
            EndIf
            aAdd(aUse, {BOCOL(aHit[nI]:LT), BOCOL(aHit[nI]:V), BOCOL(aHit[nI]:E), nQ})
            nResto := Round(nResto - nQ, 4)
        EndIf
    Next nI
    If nResto > 0
        Return {.F., "saldo_por_lote_insuficiente (sem vencidos): " + cProd, {}}
    EndIf
Return {.T., "", aUse}

// Grava saldo por lote/endereco (GES4) e o detalhe do movimento (GES6).
Static Function ESTGrvLotes(cProd, cLocal, cTipo, aUse, cDoc, cData, cDocRef)
    Local cFil := FWxFilial("GES4")
    Local cW := ""
    Local nI := 0
    For nI := 1 To Len(aUse)
        cW := " WHERE GES4_FILIAL = " + GEBDBQuote(cFil) + " AND GES4_PROD = " + GEBDBQuote(cProd) + " AND GES4_LOCAL = " + GEBDBQuote(cLocal) + ;
            " AND GES4_LOTE = " + GEBDBQuote(aUse[nI][1]) + " AND GES4_ENDER = " + GEBDBQuote(aUse[nI][3]) + " AND D_E_L_E_T_ = ' '"
        If cTipo == "E"
            If Len(TCSqlQuery("SELECT GES4_LOTE FROM GES4" + cW)) > 0
                TCSqlExec("UPDATE GES4 SET GES4_QTD = GES4_QTD + " + BONUM(aUse[nI][4], 4) + cW)
            Else
                TCSqlExec("INSERT INTO GES4 (D_E_L_E_T_, GES4_FILIAL, GES4_PROD, GES4_LOCAL, GES4_LOTE, GES4_VALID, GES4_ENDER, GES4_QTD) VALUES (' ', " + ;
                    GEBDBQuote(cFil) + ", " + GEBDBQuote(cProd) + ", " + GEBDBQuote(cLocal) + ", " + GEBDBQuote(aUse[nI][1]) + ", " + ;
                    GEBDBQuote(aUse[nI][2]) + ", " + GEBDBQuote(aUse[nI][3]) + ", " + BONUM(aUse[nI][4], 4) + ")")
            EndIf
        Else
            TCSqlExec("UPDATE GES4 SET GES4_QTD = GES4_QTD - " + BONUM(aUse[nI][4], 4) + cW)
        EndIf
        TCSqlExec("INSERT INTO GES6 (D_E_L_E_T_, GES6_FILIAL, GES6_DATA, GES6_DOC, GES6_REF, GES6_PROD, GES6_LOCAL, GES6_TIPO, GES6_LOTE, GES6_VALID, " + ;
            "GES6_ENDER, GES6_QTD) VALUES (' ', " + GEBDBQuote(FWxFilial("GES6")) + ", " + GEBDBQuote(cData) + ", " + GEBDBQuote(cDoc) + ", " + ;
            GEBDBQuote(cDocRef) + ", " + GEBDBQuote(cProd) + ", " + GEBDBQuote(cLocal) + ", " + GEBDBQuote(cTipo) + ", " + GEBDBQuote(aUse[nI][1]) + ", " + ;
            GEBDBQuote(aUse[nI][2]) + ", " + GEBDBQuote(aUse[nI][3]) + ", " + BONUM(aUse[nI][4], 4) + ")")
    Next nI
Return .T.

Static Function ESTLocal(cLocal)
    cLocal := BOCOL(cLocal)
    If cLocal == ""
        Return "01"
    EndIf
Return cLocal
