#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBCTB_MIG.prw"

/*/{Protheus.doc} GEBCTX
    Contabilidade do backoffice (inspirada em CT1/CT5/CT2/CTBR400/CTBR040 do
    Protheus).
    - GEBCTXMIG: amplia o plano de contas (GC1) e o lancamento padrao por
      evento (GC4), inserindo so' o que falta (nao muda contas ja
      configuradas pela empresa).
    - GEBCTXLP(cEvento, nValor, cDoc, cData[, cDeb, cCred]): grava o lote
      (GC2 + duas pernas em GC3) na data do fato, com GC2_ORIGEM =
      EVENTO:DOC e GC2_TIPO = LP. cDeb/cCred substituem a conta do evento
      (ex.: banco da baixa, conta do titulo). Valor zero nao grava (ok).
    - GEBCTXREV: estorno (mesmo evento com debito e credito trocados).
    - GEBCTXFIN(cConta): conta contabil de uma conta financeira (GFN1):
      CAIXA* = 1.01.001 (Caixa), demais = 1.01.002 (Bancos).
    - Relatorios: GEBCTXRAZAO (razao da conta), GEBCTXBALAN (balancete do
      periodo com totais por grupo) e GEBCTXDRE (DRE estruturada).
    Grupos: 1 ativo, 2 passivo, 3 receitas (3.02 = deducoes, natureza
    devedora), 4 custos e despesas -- os mesmos de GEBBAL/GEBDRE.
    @type Modulo contabil
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBCTXMIG()
    Local aPlano := CTXPlano()
    Local aEv := CTXEventos()
    Local cFil := FWxFilial("GC1")
    Local nI := 0
    If !GEBCMIG() .Or. !BOMIG()
        Return .F.
    EndIf
    If !BOTAB("GCC1", "GCC1_COD TEXT NOT NULL, GCC1_DESC TEXT NOT NULL, GCC1_BLOQ TEXT NOT NULL", "GCC1_COD") .Or. ;
            !BOTAB("GCC2", "GCC2_COD TEXT NOT NULL, GCC2_CC TEXT NOT NULL, GCC2_PCT NUMERIC(8,4) NOT NULL", "GCC2_COD") .Or. ;
            !BOTAB("GCX1", "GCX1_LOTE TEXT NOT NULL, GCX1_CC TEXT NOT NULL", "GCX1_LOTE")
        Return .F.
    EndIf
    For nI := 1 To Len(aPlano)
        If Len(TCSqlQuery("SELECT GC1_CONTA FROM GC1 WHERE GC1_CONTA = " + GEBDBQuote(aPlano[nI][1]) + " AND D_E_L_E_T_ = ' '")) == 0
            TCSqlExec("INSERT INTO GC1 (D_E_L_E_T_, GC1_FILIAL, GC1_CONTA, GC1_NOME, GC1_TIPO) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
                GEBDBQuote(aPlano[nI][1]) + ", " + GEBDBQuote(aPlano[nI][2]) + ", 'A')")
        EndIf
    Next nI
    For nI := 1 To Len(aEv)
        If Len(TCSqlQuery("SELECT GC4_EVENTO FROM GC4 WHERE GC4_EVENTO = " + GEBDBQuote(aEv[nI][1]) + " AND D_E_L_E_T_ = ' '")) == 0
            TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
                GEBDBQuote(aEv[nI][1]) + ", " + GEBDBQuote(aEv[nI][2]) + ", " + GEBDBQuote(aEv[nI][3]) + ", 'S')")
        EndIf
    Next nI
Return .T.

/*/{Protheus.doc} GEBCTXLP
    Lancamento padrao do evento na data do fato.
    @type Funcao contabil
    @author Peder Munksgaard
    @since 18/10/2026
    @param cCC Centro de custo (GCC1) ou codigo de rateio (GCC2): o lote e'
           marcado com o centro (GCX1); no rateio, um lote por centro.
    @return {lOk, cMsg, cLote}
/*/
User Function GEBCTXLP(cEvento, nValor, cDoc, cData, cDeb, cCred, cCC)
    Local cFil := FWxFilial("GC4")
    Local aHit := {}
    Local aRat := {}
    Local cLote := ""
    Local cPrim := ""
    Local nI := 0

    nValor := Round(BOVAL(nValor), 2)
    cDoc := BOCOL(cDoc)
    cDeb := BOCOL(cDeb)
    cCred := BOCOL(cCred)
    cData := BODATA(cData)
    If nValor <= 0
        Return {.T., "sem_valor", ""}
    EndIf
    If cData == ""
        Return {.F., "data_invalida", ""}
    EndIf
    If !GEBCTXMIG()
        Return {.F., "falha_tabelas", ""}
    EndIf
    If cDeb == "" .Or. cCred == ""
        aHit := TCSqlQuery("SELECT GC4_CTADEB AS D, GC4_CTACRED AS C FROM GC4 WHERE GC4_FILIAL = " + GEBDBQuote(cFil) + ;
            " AND GC4_EVENTO = " + GEBDBQuote(cEvento) + " AND D_E_L_E_T_ = ' '")
        If Len(aHit) == 0
            Return {.F., "evento_sem_lancamento_padrao: " + cEvento, ""}
        EndIf
        If cDeb == ""
            cDeb := BOCOL(aHit[1]:D)
        EndIf
        If cCred == ""
            cCred := BOCOL(aHit[1]:C)
        EndIf
    EndIf
    If cDeb == cCred
        Return {.T., "mesma_conta", ""}
    EndIf
    aRat := GEBCTXRATEIA(cCC, nValor)
    If !aRat[1]
        Return {.F., aRat[2], ""}
    EndIf
    For nI := 1 To Len(aRat[3])
        cLote := "LP" + BOSEQ("CTB_LOTE", 8)
        If !TCSqlExec("INSERT INTO GC2 (D_E_L_E_T_, GC2_FILIAL, GC2_LOTE, GC2_ORIGEM, GC2_VALOR, GC2_DATA, GC2_COMP, GC2_TIPO) VALUES (' ', " + ;
                GEBDBQuote(FWxFilial("GC2")) + ", " + GEBDBQuote(cLote) + ", " + GEBDBQuote(Left(cEvento + ":" + cDoc, 120)) + ", " + ;
                BONUM(aRat[3][nI][2], 2) + ", " + GEBDBQuote(cData) + ", " + GEBDBQuote(Left(cData, 6)) + ", 'LP')")
            Return {.F., "falha_gravacao", ""}
        EndIf
        TCSqlExec("INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES " + ;
            "(' ', " + GEBDBQuote(FWxFilial("GC3")) + ", " + GEBDBQuote(cLote) + ", 'D', " + GEBDBQuote(cDeb) + ", " + BONUM(aRat[3][nI][2], 2) + "), " + ;
            "(' ', " + GEBDBQuote(FWxFilial("GC3")) + ", " + GEBDBQuote(cLote) + ", 'C', " + GEBDBQuote(cCred) + ", " + BONUM(aRat[3][nI][2], 2) + ")")
        If !(aRat[3][nI][1] == "")
            TCSqlExec("INSERT INTO GCX1 (D_E_L_E_T_, GCX1_FILIAL, GCX1_LOTE, GCX1_CC) VALUES (' ', " + GEBDBQuote(FWxFilial("GCX1")) + ", " + ;
                GEBDBQuote(cLote) + ", " + GEBDBQuote(aRat[3][nI][1]) + ")")
        EndIf
        If cPrim == ""
            cPrim := cLote
        EndIf
    Next nI
Return {.T., "lancado", cPrim}

/*/{Protheus.doc} GEBCTXRATEIA
    Divide um valor pelo centro de custo ou pelo rateio (o ultimo centro
    fica com o centavo). Vazio = sem centro.
    @type Funcao contabil
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {{cCC, nValor}...}}
/*/
User Function GEBCTXRATEIA(cCC, nValor)
    Local aHit := {}
    Local aRet := {}
    Local nAc := 0
    Local nV := 0
    Local nI := 0
    cCC := Upper(BOCOL(cCC))
    nValor := Round(BOVAL(nValor), 2)
    If cCC == ""
        Return {.T., "", {{"", nValor}}}
    EndIf
    aHit := TCSqlQuery("SELECT GCC1_BLOQ AS B FROM GCC1 WHERE GCC1_FILIAL = " + GEBDBQuote(FWxFilial("GCC1")) + " AND GCC1_COD = " + ;
        GEBDBQuote(cCC) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) > 0
        If BOCOL(aHit[1]:B) == "S"
            Return {.F., "centro_de_custo_bloqueado: " + cCC, {}}
        EndIf
        Return {.T., "", {{cCC, nValor}}}
    EndIf
    aHit := TCSqlQuery("SELECT GCC2_CC AS C, GCC2_PCT AS P FROM GCC2 WHERE GCC2_FILIAL = " + GEBDBQuote(FWxFilial("GCC2")) + " AND GCC2_COD = " + ;
        GEBDBQuote(cCC) + " AND D_E_L_E_T_ = ' ' ORDER BY R_E_C_N_O_")
    If Len(aHit) == 0
        Return {.F., "centro_de_custo_ou_rateio_inexistente: " + cCC, {}}
    EndIf
    For nI := 1 To Len(aHit)
        nV := Round(nValor * BOVAL(aHit[nI]:P) / 100, 2)
        If nI == Len(aHit)
            nV := Round(nValor - nAc, 2)
        EndIf
        nAc := nAc + nV
        If nV > 0
            aAdd(aRet, {BOCOL(aHit[nI]:C), nV})
        EndIf
    Next nI
Return {.T., "", aRet}

/*/{Protheus.doc} GEBCTXCC
    Cadastra/altera centro de custo (bloqueado S = nao recebe lancamento).
    @type Cadastro contabil
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBCTXCC(cCod, cDesc, cBloq)
    Local cFil := FWxFilial("GCC1")
    cCod := Upper(BOCOL(cCod))
    cBloq := Upper(BOCOL(cBloq))
    If cCod == "" .Or. Len(cCod) > 10
        Return {.F., "codigo_invalido: 1 a 10 caracteres"}
    EndIf
    If !(cBloq == "S")
        cBloq := "N"
    EndIf
    If !GEBCTXMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If Len(TCSqlQuery("SELECT GCC2_COD FROM GCC2 WHERE GCC2_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "codigo_ja_usado_por_rateio: " + cCod}
    EndIf
    TCSqlExec("UPDATE GCC1 SET D_E_L_E_T_ = '*' WHERE GCC1_FILIAL = " + GEBDBQuote(cFil) + " AND GCC1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GCC1 (D_E_L_E_T_, GCC1_FILIAL, GCC1_COD, GCC1_DESC, GCC1_BLOQ) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cCod) + ", " + GEBDBQuote(BOCOL(cDesc)) + ", " + GEBDBQuote(cBloq) + ")")
Return {.T., "centro de custo " + cCod + " gravado"}

/*/{Protheus.doc} GEBCTXRAT
    Cadastra/altera um rateio: {{cCentro, nPercentual}...}, somando 100.
    @type Cadastro contabil
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg}
/*/
User Function GEBCTXRAT(cCod, aItens)
    Local cFil := FWxFilial("GCC2")
    Local aHitCC := {}
    Local nSoma := 0
    Local nI := 0
    cCod := Upper(BOCOL(cCod))
    If cCod == "" .Or. aItens == Nil .Or. Len(aItens) == 0
        Return {.F., "codigo_e_itens_obrigatorios"}
    EndIf
    If !GEBCTXMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    If Len(TCSqlQuery("SELECT GCC1_COD FROM GCC1 WHERE GCC1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")) > 0
        Return {.F., "codigo_ja_usado_por_centro: " + cCod}
    EndIf
    For nI := 1 To Len(aItens)
        If BOVAL(aItens[nI][2]) <= 0
            Return {.F., "percentual_invalido: " + BOCOL(aItens[nI][1])}
        EndIf
        aHitCC := TCSqlQuery("SELECT GCC1_BLOQ AS B FROM GCC1 WHERE GCC1_FILIAL = " + GEBDBQuote(FWxFilial("GCC1")) + " AND GCC1_COD = " + ;
            GEBDBQuote(Upper(BOCOL(aItens[nI][1]))) + " AND D_E_L_E_T_ = ' '")
        If Len(aHitCC) == 0
            Return {.F., "centro_de_custo_inexistente: " + BOCOL(aItens[nI][1])}
        EndIf
        nSoma := nSoma + BOVAL(aItens[nI][2])
    Next nI
    If !(Round(nSoma, 4) == 100)
        Return {.F., "percentuais_somam_" + BONUM(nSoma, 4) + ": precisa ser 100"}
    EndIf
    TCSqlExec("UPDATE GCC2 SET D_E_L_E_T_ = '*' WHERE GCC2_FILIAL = " + GEBDBQuote(cFil) + " AND GCC2_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    For nI := 1 To Len(aItens)
        TCSqlExec("INSERT INTO GCC2 (D_E_L_E_T_, GCC2_FILIAL, GCC2_COD, GCC2_CC, GCC2_PCT) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
            GEBDBQuote(cCod) + ", " + GEBDBQuote(Upper(BOCOL(aItens[nI][1]))) + ", " + BONUM(aItens[nI][2], 4) + ")")
    Next nI
Return {.T., "rateio " + cCod + " gravado"}

/*/{Protheus.doc} GEBCTXCCRES
    Relatorio: resultado por centro de custo no periodo (receita bruta,
    deducoes, CMV, outras receitas, despesas, resultado); a ultima linha
    "(sem centro)" e' o que nao foi marcado.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBCTXCCRES(cIni, cFim)
    Local aHit := {}
    Local aLin := {{"centro", "descricao", "receita_bruta", "deducoes", "cmv", "outras_receitas", "despesas", "resultado"}}
    Local aD := {}
    Local aTot := {}
    Local aSoma := {0, 0, 0, 0, 0, 0}
    Local nI := 0
    Local nJ := 0
    aTot := GEBCTXDRE(cIni, cFim)
    If !aTot[1]
        Return aTot
    EndIf
    aHit := TCSqlQuery("SELECT GCC1_COD AS C, GCC1_DESC AS D FROM GCC1 WHERE GCC1_FILIAL = " + GEBDBQuote(FWxFilial("GCC1")) + " AND D_E_L_E_T_ = ' ' ORDER BY 1")
    For nI := 1 To Len(aHit)
        aD := GEBCTXDRE(cIni, cFim, BOCOL(aHit[nI]:C))
        aAdd(aLin, {BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:D), CTXChave(aD[3], "receita_bruta"), CTXChave(aD[3], "deducoes"), CTXChave(aD[3], "cmv"), ;
            CTXChave(aD[3], "outras_receitas"), CTXChave(aD[3], "despesas"), CTXChave(aD[3], "resultado")})
        For nJ := 1 To 6
            aSoma[nJ] := aSoma[nJ] + aLin[Len(aLin)][nJ + 2]
        Next nJ
    Next nI
    aAdd(aLin, {"(sem centro)", "", Round(CTXChave(aTot[3], "receita_bruta") - aSoma[1], 2), Round(CTXChave(aTot[3], "deducoes") - aSoma[2], 2), ;
        Round(CTXChave(aTot[3], "cmv") - aSoma[3], 2), Round(CTXChave(aTot[3], "outras_receitas") - aSoma[4], 2), ;
        Round(CTXChave(aTot[3], "despesas") - aSoma[5], 2), Round(CTXChave(aTot[3], "resultado") - aSoma[6], 2)})
    BOREL(aLin)
Return {.T., "resultado_por_centro", aLin}

// Estorno: mesmo evento com as contas trocadas.
User Function GEBCTXREV(cEvento, nValor, cDoc, cData, cDeb, cCred, cCC)
    Local aCt := GEBCTXCONTAS(cEvento)
    If !(BOCOL(cDeb) == "")
        aCt[1] := BOCOL(cDeb)
    EndIf
    If !(BOCOL(cCred) == "")
        aCt[2] := BOCOL(cCred)
    EndIf
    If aCt[1] == "" .Or. aCt[2] == ""
        Return {.F., "evento_sem_lancamento_padrao: " + cEvento, ""}
    EndIf
Return GEBCTXLP(cEvento, nValor, "ESTORNO " + BOCOL(cDoc), cData, aCt[2], aCt[1], cCC)

// {cDebito, cCredito} do evento ("" se nao existe).
User Function GEBCTXCONTAS(cEvento)
    Local aHit := {}
    GEBCTXMIG()
    aHit := TCSqlQuery("SELECT GC4_CTADEB AS D, GC4_CTACRED AS C FROM GC4 WHERE GC4_FILIAL = " + GEBDBQuote(FWxFilial("GC4")) + ;
        " AND GC4_EVENTO = " + GEBDBQuote(cEvento) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return {"", ""}
    EndIf
Return {BOCOL(aHit[1]:D), BOCOL(aHit[1]:C)}

// Conta contabil de uma conta financeira (GFN1).
// ponytail: CAIXA* = Caixa, o resto = Bancos; criar de-para por conta se a empresa quiser um razao por banco
User Function GEBCTXFIN(cConta)
    If Upper(Left(BOCOL(cConta), 5)) == "CAIXA"
        Return "1.01.001"
    EndIf
Return "1.01.002"

/*/{Protheus.doc} GEBCTXRAZAO
    Relatorio: razao de uma conta no periodo (saldo anterior, lancamentos com
    saldo acumulado, saldo final). Saldo = debito - credito.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aResumo, aLinhas (1a = cabecalho)}}
/*/
User Function GEBCTXRAZAO(cConta, cIni, cFim)
    Local aHit := {}
    Local aLin := {{"data", "lote", "historico", "debito", "credito", "saldo"}}
    Local aRel := {}
    Local nAnt := 0
    Local nSaldo := 0
    Local nDeb := 0
    Local nCred := 0
    Local nD := 0
    Local nC := 0
    Local nI := 0

    cConta := BOCOL(cConta)
    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cConta == "" .Or. cIni == "" .Or. cFim == "" .Or. cIni > cFim
        Return {.F., "parametros_invalidos: conta, inicio e fim AAAAMMDD", {}}
    EndIf
    If !GEBCTXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT COALESCE(SUM(CASE WHEN GC3_DC = 'D' THEN GC3_VALOR ELSE -GC3_VALOR END), 0) AS S FROM GC3 " + ;
        "JOIN GC2 ON GC2_FILIAL = GC3_FILIAL AND GC2_LOTE = GC3_LOTE AND GC2.D_E_L_E_T_ = ' ' WHERE GC3.D_E_L_E_T_ = ' ' " + ;
        "AND GC3_FILIAL = " + GEBDBQuote(FWxFilial("GC3")) + " AND GC3_CONTA = " + GEBDBQuote(cConta) + " AND GC2_DATA < " + GEBDBQuote(cIni))
    nAnt := BOVAL(aHit[1]:S)
    nSaldo := nAnt
    aHit := TCSqlQuery("SELECT GC2_DATA AS DT, GC2_LOTE AS LT, GC2_ORIGEM AS ORI, GC3_DC AS DC, GC3_VALOR AS VAL FROM GC3 " + ;
        "JOIN GC2 ON GC2_FILIAL = GC3_FILIAL AND GC2_LOTE = GC3_LOTE AND GC2.D_E_L_E_T_ = ' ' WHERE GC3.D_E_L_E_T_ = ' ' " + ;
        "AND GC3_FILIAL = " + GEBDBQuote(FWxFilial("GC3")) + " AND GC3_CONTA = " + GEBDBQuote(cConta) + ;
        " AND GC2_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " ORDER BY GC2_DATA, GC2.R_E_C_N_O_")
    For nI := 1 To Len(aHit)
        nD := 0
        nC := 0
        If BOCOL(aHit[nI]:DC) == "D"
            nD := BOVAL(aHit[nI]:VAL)
        Else
            nC := BOVAL(aHit[nI]:VAL)
        EndIf
        nDeb := nDeb + nD
        nCred := nCred + nC
        nSaldo := Round(nSaldo + nD - nC, 2)
        aAdd(aLin, {BOCOL(aHit[nI]:DT), BOCOL(aHit[nI]:LT), BOCOL(aHit[nI]:ORI), nD, nC, nSaldo})
    Next nI
    aRel := {{"conta " + cConta + " " + CTXNome(cConta), "saldo anterior", BONUM(nAnt, 2), "", "", ""}}
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    aAdd(aRel, {"", "", "totais / saldo final", nDeb, nCred, nSaldo})
    BOREL(aRel)
Return {.T., "razao", {{{"conta", cConta}, {"nome", CTXNome(cConta)}, {"saldo_anterior", nAnt}, {"debitos", Round(nDeb, 2)}, ;
    {"creditos", Round(nCred, 2)}, {"saldo_final", nSaldo}}, aLin}}

/*/{Protheus.doc} GEBCTXBALAN
    Relatorio: balancete do periodo. Por conta: saldo anterior, debitos,
    creditos e saldo atual (debito - credito); subtotais por grupo (1o
    digito) e total geral (debitos = creditos em partidas dobradas).
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, {aLinhas (1a = cabecalho), aTotais}}
/*/
User Function GEBCTXBALAN(cIni, cFim, cCC)
    Local aHit := {}
    Local aLin := {{"conta", "nome", "saldo_anterior", "debitos", "creditos", "saldo_atual"}}
    Local aRel := {}
    Local aGrp := {}
    Local cGrp := ""
    Local cConta := ""
    Local nAnt := 0
    Local nD := 0
    Local nC := 0
    Local nTD := 0
    Local nTC := 0
    Local nI := 0
    Local nG := 0
    Local nT := 0
    Local cWCC := ""

    cIni := BODATA(cIni)
    cFim := BODATA(cFim)
    If cIni == "" .Or. cFim == "" .Or. cIni > cFim
        Return {.F., "periodo_invalido: inicio e fim AAAAMMDD", {}}
    EndIf
    If !GEBCTXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    // Centro de custo: so' os lotes marcados com ele.
    If !(BOCOL(cCC) == "")
        cWCC := " AND EXISTS (SELECT 1 FROM GCX1 WHERE GCX1_FILIAL = GC3_FILIAL AND GCX1_LOTE = GC3_LOTE AND GCX1_CC = " + ;
            GEBDBQuote(Upper(BOCOL(cCC))) + " AND GCX1.D_E_L_E_T_ = ' ')"
    EndIf
    aHit := TCSqlQuery("SELECT GC3_CONTA AS CT, " + ;
        "SUM(CASE WHEN GC2_DATA < " + GEBDBQuote(cIni) + " AND GC3_DC = 'D' THEN GC3_VALOR WHEN GC2_DATA < " + GEBDBQuote(cIni) + " THEN -GC3_VALOR ELSE 0 END) AS ANT, " + ;
        "SUM(CASE WHEN GC2_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " AND GC3_DC = 'D' THEN GC3_VALOR ELSE 0 END) AS DEB, " + ;
        "SUM(CASE WHEN GC2_DATA BETWEEN " + GEBDBQuote(cIni) + " AND " + GEBDBQuote(cFim) + " AND GC3_DC = 'C' THEN GC3_VALOR ELSE 0 END) AS CRE " + ;
        "FROM GC3 JOIN GC2 ON GC2_FILIAL = GC3_FILIAL AND GC2_LOTE = GC3_LOTE AND GC2.D_E_L_E_T_ = ' ' " + ;
        "WHERE GC3.D_E_L_E_T_ = ' ' AND GC3_FILIAL = " + GEBDBQuote(FWxFilial("GC3")) + " AND GC2_DATA <= " + GEBDBQuote(cFim) + cWCC + ;
        " GROUP BY GC3_CONTA ORDER BY GC3_CONTA")
    For nI := 1 To Len(aHit)
        cConta := BOCOL(aHit[nI]:CT)
        nAnt := Round(BOVAL(aHit[nI]:ANT), 2)
        nD := Round(BOVAL(aHit[nI]:DEB), 2)
        nC := Round(BOVAL(aHit[nI]:CRE), 2)
        aAdd(aLin, {cConta, CTXNome(cConta), nAnt, nD, nC, Round(nAnt + nD - nC, 2)})
        nTD := nTD + nD
        nTC := nTC + nC
        cGrp := Left(cConta, 1)
        nG := 0
        For nT := 1 To Len(aGrp)
            If aGrp[nT][1] == cGrp
                nG := nT
            EndIf
        Next nT
        If nG == 0
            aAdd(aGrp, {cGrp, 0, 0, 0})
            nG := Len(aGrp)
        EndIf
        aGrp[nG][2] := aGrp[nG][2] + nAnt
        aGrp[nG][3] := aGrp[nG][3] + nD
        aGrp[nG][4] := aGrp[nG][4] + nC
    Next nI
    For nI := 1 To Len(aLin)
        aAdd(aRel, aLin[nI])
    Next nI
    For nG := 1 To Len(aGrp)
        aAdd(aRel, {"grupo " + aGrp[nG][1], CTXGrupo(aGrp[nG][1]), Round(aGrp[nG][2], 2), Round(aGrp[nG][3], 2), Round(aGrp[nG][4], 2), ;
            Round(aGrp[nG][2] + aGrp[nG][3] - aGrp[nG][4], 2)})
    Next nG
    aAdd(aRel, {"total", "", "", Round(nTD, 2), Round(nTC, 2), ""})
    BOREL(aRel)
Return {.T., "balancete", {aLin, {{"periodo", cIni + "-" + cFim}, {"debitos", Round(nTD, 2)}, {"creditos", Round(nTC, 2)}, ;
    {"fechado", CTXSimNao(Round(nTD, 2) == Round(nTC, 2))}}}}

/*/{Protheus.doc} GEBCTXDRE
    Relatorio: DRE estruturada do periodo.
    Receita bruta (3.01.001) - deducoes (3.02) = receita liquida; - CMV
    (4.01) = lucro bruto; + outras receitas (demais 3.01) - despesas (4.02 e
    demais 4) = resultado do periodo.
    @type Relatorio
    @author Peder Munksgaard
    @since 18/10/2026
    @return {lOk, cMsg, aLinhas {descricao, valor}}
/*/
User Function GEBCTXDRE(cIni, cFim, cCC)
    Local aR := GEBCTXBALAN(cIni, cFim, cCC)
    Local aLin := {}
    Local aDre := {}
    Local cCt := ""
    Local nMov := 0
    Local nRB := 0
    Local nDed := 0
    Local nCmv := 0
    Local nOut := 0
    Local nDesp := 0
    Local nI := 0

    If !aR[1]
        Return aR
    EndIf
    aLin := aR[3][1]
    For nI := 2 To Len(aLin)
        cCt := aLin[nI][1]
        nMov := aLin[nI][4] - aLin[nI][5]
        If cCt == "3.01.001"
            nRB := nRB - nMov
        ElseIf Left(cCt, 4) == "3.02"
            nDed := nDed + nMov
        ElseIf Left(cCt, 1) == "3"
            nOut := nOut - nMov
        ElseIf Left(cCt, 4) == "4.01"
            nCmv := nCmv + nMov
        ElseIf Left(cCt, 1) == "4"
            nDesp := nDesp + nMov
        EndIf
    Next nI
    aDre := {{"receita_bruta", Round(nRB, 2)}, {"deducoes", Round(nDed, 2)}, {"receita_liquida", Round(nRB - nDed, 2)}, ;
        {"cmv", Round(nCmv, 2)}, {"lucro_bruto", Round(nRB - nDed - nCmv, 2)}, {"outras_receitas", Round(nOut, 2)}, ;
        {"despesas", Round(nDesp, 2)}, {"resultado", Round(nRB - nDed - nCmv + nOut - nDesp, 2)}}
    aLin := {{"linha", "valor"}}
    For nI := 1 To Len(aDre)
        aAdd(aLin, {aDre[nI][1], aDre[nI][2]})
    Next nI
    BOREL(aLin)
Return {.T., "dre", aDre}

// Plano de contas padrao do backoffice {conta, nome}.
/*/{Protheus.doc} GEBCTXCORRIGE
    Corrige os lancamentos antigos que cairam no PADRAO (CTBLAN pelo numero
    do documento: D 1.01.001 Caixa / C 3.01.001 Receita, tipo AUTO). Cada
    lote reconhecido recebe um estorno (ESTORNO:<lote>, pernas invertidas,
    mesma data) e o lancamento certo:
    - guia da Derrama paga: D 3.02.002 / C caixa;
    - nota de entrada de compra: 1o lote = entrada (COMPRA_ESTOQUE),
      demais = pagamento (D fornecedores / C caixa);
    - titulo a pagar: pagamento a vista como despesa (D 4.02.006 / C caixa);
    - titulo a receber dos modulos novos (com GFX2): D caixa / C clientes.
    Vendas a vista, notas e receber antigo ficam (receita no caixa esta
    certa). Lote ja estornado e' ignorado: pode rodar de novo.
    @type Manutencao contabil
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, aLinhas (1a = cabecalho)}
/*/
User Function GEBCTXCORRIGE()
    Local aLin := {{"lote", "documento", "valor", "correcao"}}
    Local aLot := {}
    Local aR := {}
    Local cLote := ""
    Local cDoc := ""
    Local cData := ""
    Local cTipo := ""
    Local nVal := 0
    Local nI := 0

    If !GEBCTXMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aLot := TCSqlQuery("SELECT GC2_LOTE AS L, GC2_ORIGEM AS O, GC2_VALOR AS V, GC2_DATA AS D, GC2.R_E_C_N_O_ AS RN FROM GC2 WHERE GC2.D_E_L_E_T_ = ' ' AND GC2_TIPO = 'AUTO' " + ;
        "AND EXISTS (SELECT 1 FROM GC3 WHERE GC3_LOTE = GC2_LOTE AND GC3_DC = 'D' AND GC3_CONTA = '1.01.001' AND GC3.D_E_L_E_T_ = ' ') " + ;
        "AND EXISTS (SELECT 1 FROM GC3 WHERE GC3_LOTE = GC2_LOTE AND GC3_DC = 'C' AND GC3_CONTA = '3.01.001' AND GC3.D_E_L_E_T_ = ' ') " + ;
        "AND NOT EXISTS (SELECT 1 FROM GC2 E WHERE E.GC2_ORIGEM = 'ESTORNO:' || GC2.GC2_LOTE AND E.D_E_L_E_T_ = ' ') ORDER BY GC2.R_E_C_N_O_")
    For nI := 1 To Len(aLot)
        cLote := BOCOL(aLot[nI]:L)
        cDoc := BOCOL(aLot[nI]:O)
        nVal := Round(BOVAL(aLot[nI]:V), 2)
        cData := BOCOL(aLot[nI]:D)
        cTipo := CTXTipoLegado(cDoc, BOVAL(aLot[nI]:RN))
        If !(cTipo == "")
            CTXEstorna(cLote, nVal, cData)
            If cTipo == "GUIA"
                aR := GEBCTXLP("FIN_PAG", nVal, cDoc, cData, "3.02.002", "1.01.001")
            ElseIf cTipo == "ENTRADA"
                aR := GEBCTXLP("COMPRA_ESTOQUE", nVal, cDoc, cData)
            ElseIf cTipo == "PAG_ENTRADA"
                aR := GEBCTXLP("FIN_PAG", nVal, cDoc, cData, "2.01.001", "1.01.001")
            ElseIf cTipo == "PAGAR"
                aR := GEBCTXLP("FIN_PAG", nVal, cDoc, cData, "4.02.006", "1.01.001")
            Else
                aR := GEBCTXLP("FIN_REC", nVal, cDoc, cData, "1.01.001", "1.01.003")
            EndIf
            aAdd(aLin, {cLote, cDoc, nVal, cTipo})
        EndIf
    Next nI
Return {.T., cValToChar(Len(aLin) - 1) + " lancamento(s) corrigido(s)", aLin}

// Natureza do lote antigo pelo documento: GUIA, ENTRADA, PAG_ENTRADA, PAGAR,
// RECEBER (titulo dos modulos novos) ou "" (fica como esta).
Static Function CTXTipoLegado(cDoc, nRecno)
    If GEBDBTableExistsHere("GD1") .And. Len(TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_GUIA = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")) > 0
        Return "GUIA"
    EndIf
    If GEBDBTableExistsHere("GCP5") .And. Len(TCSqlQuery("SELECT GCP5_NF FROM GCP5 WHERE GCP5_NF = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")) > 0
        // O primeiro lote do documento e' a entrada; os seguintes, pagamentos.
        If Len(TCSqlQuery("SELECT GC2_LOTE FROM GC2 WHERE GC2_ORIGEM = " + GEBDBQuote(cDoc) + " AND GC2_TIPO = 'AUTO' AND R_E_C_N_O_ < " + ;
                cValToChar(nRecno) + " AND D_E_L_E_T_ = ' '")) == 0
            Return "ENTRADA"
        EndIf
        Return "PAG_ENTRADA"
    EndIf
    If GEBDBTableExistsHere("GFN3") .And. Len(TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' '")) > 0
        Return "PAGAR"
    EndIf
    If GEBDBTableExistsHere("GFX2") .And. Len(TCSqlQuery("SELECT GFX2_DOC FROM GFX2 WHERE GFX2_TIPO = 'R' AND GFX2_DOC = " + GEBDBQuote(cDoc) + ;
            " AND D_E_L_E_T_ = ' '")) > 0
        Return "RECEBER"
    EndIf
Return ""

// Lote de estorno: mesmas contas com D e C trocados, na data do original.
Static Function CTXEstorna(cLote, nVal, cData)
    Local cNovo := "ES" + BOSEQ("CTB_LOTE", 8)
    TCSqlExec("INSERT INTO GC2 (D_E_L_E_T_, GC2_FILIAL, GC2_LOTE, GC2_ORIGEM, GC2_VALOR, GC2_DATA, GC2_COMP, GC2_TIPO) VALUES (' ', " + ;
        GEBDBQuote(FWxFilial("GC2")) + ", " + GEBDBQuote(cNovo) + ", " + GEBDBQuote("ESTORNO:" + cLote) + ", " + BONUM(nVal, 2) + ", " + ;
        GEBDBQuote(cData) + ", " + GEBDBQuote(Left(cData, 6)) + ", 'ESTORNO')")
Return TCSqlExec("INSERT INTO GC3 (D_E_L_E_T_, GC3_FILIAL, GC3_LOTE, GC3_DC, GC3_CONTA, GC3_VALOR) VALUES " + ;
    "(' ', " + GEBDBQuote(FWxFilial("GC3")) + ", " + GEBDBQuote(cNovo) + ", 'D', '3.01.001', " + BONUM(nVal, 2) + "), " + ;
    "(' ', " + GEBDBQuote(FWxFilial("GC3")) + ", " + GEBDBQuote(cNovo) + ", 'C', '1.01.001', " + BONUM(nVal, 2) + ")")

Static Function CTXPlano()
Return {{"1.01.001", "CAIXA"}, {"1.01.002", "BANCOS"}, {"1.01.003", "CLIENTES"}, {"1.01.004", "ESTOQUE DE MERCADORIAS"}, ;
    {"1.01.005", "CARTOES A RECEBER"}, {"1.01.006", "CREDITOS COM FORNECEDORES"}, {"2.01.001", "FORNECEDORES"}, {"2.01.002", "SIMPLES NACIONAL A RECOLHER"}, ;
    {"2.01.003", "CREDITOS DE CLIENTES"}, {"3.01.001", "RECEITA VENDAS"}, {"3.01.002", "RECEITAS FINANCEIRAS"}, ;
    {"3.01.003", "DESCONTOS OBTIDOS"}, {"3.01.004", "OUTRAS RECEITAS"}, {"3.02.001", "DEVOLUCOES DE VENDAS"}, ;
    {"4.01.001", "CUSTO MERCADORIAS"}, {"4.02.001", "DESCONTOS CONCEDIDOS"}, {"4.02.002", "JUROS PAGOS"}, ;
    {"4.02.003", "PERDAS DE ESTOQUE"}, {"4.02.004", "TAXAS DE CARTAO"}, {"4.02.005", "SIMPLES NACIONAL (DAS)"}, ;
    {"4.02.006", "DESPESAS GERAIS"}, {"2.01.004", "IBS/CBS A RECOLHER"}, {"2.01.005", "TRIBUTOS RETIDOS A RECOLHER"}, ;
    {"2.01.006", "ICMS/ISS A RECOLHER (FORA DO DAS)"}, {"3.02.002", "IBS/CBS SOBRE VENDAS"}, {"4.02.007", "ICMS/ISS FORA DO DAS"}}

// Lancamento padrao {evento, debito, credito}.
Static Function CTXEventos()
Return {{"VENDA_RECEITA", "1.01.003", "3.01.001"}, {"VENDA_CMV", "4.01.001", "1.01.004"}, ;
    {"COMPRA_ESTOQUE", "1.01.004", "2.01.001"}, {"FIN_REC", "1.01.002", "1.01.003"}, {"FIN_PAG", "2.01.001", "1.01.002"}, ;
    {"FIN_JUROS_REC", "1.01.002", "3.01.002"}, {"FIN_DESC_CONC", "4.02.001", "1.01.003"}, ;
    {"FIN_JUROS_PAG", "4.02.002", "1.01.002"}, {"FIN_DESC_OBT", "2.01.001", "3.01.003"}, ;
    {"FIN_MOV_REC", "1.01.002", "3.01.004"}, {"FIN_MOV_PAG", "4.02.006", "1.01.002"}, {"FIN_TRANSF", "1.01.002", "1.01.002"}, ;
    {"EST_AJ_POS", "1.01.004", "3.01.004"}, {"EST_AJ_NEG", "4.02.003", "1.01.004"}, ;
    {"DEVOL_VENDA", "3.02.001", "1.01.003"}, {"DEVOL_CMV", "1.01.004", "4.01.001"}, {"DEVOL_COMPRA", "2.01.001", "1.01.004"}, ;
    {"LOJ_DINHEIRO", "1.01.001", "3.01.001"}, {"LOJ_PIX", "1.01.002", "3.01.001"}, {"LOJ_CARTAO", "1.01.005", "3.01.001"}, ;
    {"LOJ_FIADO", "1.01.003", "3.01.001"}, {"LOJ_TAXA", "4.02.004", "1.01.005"}, {"LOJ_SANGRIA", "1.01.002", "1.01.001"}, ;
    {"SN_DAS", "4.02.005", "2.01.002"}, {"FIN_DESPESA", "4.02.006", "2.01.001"}, {"APU_IBSCBS", "3.02.002", "2.01.004"}, ;
    {"SN_FORA", "4.02.007", "2.01.006"}, {"RET_FORN", "2.01.001", "2.01.005"}, {"FIN_RECEITA", "1.01.003", "3.01.004"}, {"LOJ_VALE", "2.01.003", "3.01.001"}, ;
    {"LOJ_CRYPTO", "1.01.002", "3.01.001"}}

Static Function CTXChave(aP, cK)
    Local nI := 0
    For nI := 1 To Len(aP)
        If aP[nI][1] == cK
            Return aP[nI][2]
        EndIf
    Next nI
Return 0

Static Function CTXNome(cConta)
    Local aHit := TCSqlQuery("SELECT GC1_NOME AS N FROM GC1 WHERE GC1_CONTA = " + GEBDBQuote(cConta) + " AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        Return ""
    EndIf
Return BOCOL(aHit[1]:N)

Static Function CTXGrupo(cGrp)
    Local aNom := {"ATIVO", "PASSIVO", "RECEITAS", "CUSTOS E DESPESAS"}
    Local nPos := AScan({"1", "2", "3", "4"}, cGrp)
    If nPos == 0
        Return ""
    EndIf
Return aNom[nPos]

Static Function CTXSimNao(lVal)
    If lVal
        Return "S"
    EndIf
Return "N"
