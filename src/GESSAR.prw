#include "totvs.ch"
#include "GEBBOLIB.prw"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GESSAR
    Gatilho Sarney: reajuste programado de precos da tabela PADRAO (GFT2),
    sem etiquetadora. O operador cadastra uma regra (percentual geral ou por
    produto, total de aplicacoes e horarios do dia); o executor roda a cada
    minuto pelo agendador (GEBSCHRODA -> GESSARRUN) e aplica o percentual
    nos precos, com auditoria por produto em GSK3.
    - GSK1 regra: codigo, descricao, pct geral, vezes (total), horas (HHMM
      separados por espaco), feitas, ulthora (AAAAMMDDHHMM do ultimo slot),
      ativo.
    - GSK2 override: produto com percentual proprio dentro da regra.
    - GSK3 log: uma linha por produto reajustado (data, hora, pct, antes,
      depois).
    - Preco novo = ROUND(preco * (1 + pct/100), 4) sobre GFT2_TAB='PADRAO'
      com preco > 0. Vale para PDV, pedidos e notas seguintes.
    @type Modulo precos
    @author Peder Munksgaard
    @since 26/11/2026
/*/

// Cria as tabelas do Sarney no tenant corrente (idempotente).
User Function GESSARMIG()
    Local lOk := BOTAB("GSK1", "GSK1_COD TEXT NOT NULL, GSK1_DESCR TEXT NOT NULL, GSK1_PCT NUMERIC(8,4) NOT NULL, " + ;
        "GSK1_VEZES INTEGER NOT NULL, GSK1_HORAS TEXT NOT NULL, GSK1_FEITAS INTEGER NOT NULL, " + ;
        "GSK1_ULTHORA TEXT NOT NULL, GSK1_ATIVO TEXT NOT NULL", "GSK1_COD")
    lOk := lOk .And. BOTAB("GSK2", "GSK2_CFG TEXT NOT NULL, GSK2_PROD TEXT NOT NULL, GSK2_PCT NUMERIC(8,4) NOT NULL", "GSK2_CFG")
    lOk := lOk .And. BOTAB("GSK3", "GSK3_CFG TEXT NOT NULL, GSK3_DATA TEXT NOT NULL, GSK3_HORA TEXT NOT NULL, " + ;
        "GSK3_PROD TEXT NOT NULL, GSK3_PCT NUMERIC(8,4) NOT NULL, GSK3_ANT NUMERIC(18,6) NOT NULL, " + ;
        "GSK3_NOV NUMERIC(18,6) NOT NULL", "GSK3_CFG")
Return lOk

/*/{Protheus.doc} GESSARCFG
    Cadastra/alterada a regra de reajuste. nVezes = total de aplicacoes;
    cHoras = horarios HHMM separados por espaco (ex.: "0800 1200 1800").
    cAtivo "N" desliga sem apagar. cCod existente e' substituido.
    @type Cadastro precos
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg}
/*/
User Function GESSARCFG(cCod, cDescr, nPct, nVezes, cHoras, cAtivo)
    Local cFil := FWxFilial("GSK1")
    Local cAt  := "S"
    cCod := Upper(BOCOL(cCod))
    nPct := BOVAL(nPct)
    nVezes := Int(BOVAL(nVezes))
    cHoras := GESSARHORASOK(cHoras)
    If cCod == "" .Or. Len(cCod) > 10
        Return {.F., "codigo_invalido: 1 a 10 caracteres"}
    EndIf
    If BOCOL(cDescr) == ""
        Return {.F., "descricao_obrigatoria"}
    EndIf
    If nPct <= 0 .Or. nPct > 100
        Return {.F., "percentual_invalido: 0 a 100"}
    EndIf
    If nVezes < 1 .Or. nVezes > 365
        Return {.F., "vezes_invalida: 1 a 365 aplicacoes"}
    EndIf
    If cHoras == ""
        Return {.F., "horarios_invalidos: informe HHMM separados por espaco"}
    EndIf
    If cAtivo == "N"
        cAt := "N"
    EndIf
    If !GESSARMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GSK1 SET D_E_L_E_T_ = '*' WHERE GSK1_FILIAL = " + GEBDBQuote(cFil) + " AND GSK1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GSK1 (D_E_L_E_T_, GSK1_FILIAL, GSK1_COD, GSK1_DESCR, GSK1_PCT, GSK1_VEZES, GSK1_HORAS, GSK1_FEITAS, GSK1_ULTHORA, GSK1_ATIVO) VALUES (' ', " + ;
        GEBDBQuote(cFil) + ", " + GEBDBQuote(cCod) + ", " + GEBDBQuote(BOCOL(cDescr)) + ", " + BONUM(nPct, 4) + ", " + BONUM(nVezes, 0) + ", " + ;
        GEBDBQuote(cHoras) + ", 0, '', " + GEBDBQuote(cAt) + ")")
Return {.T., "regra " + cCod + " gravada"}

/*/{Protheus.doc} GESSARPROD
    Define o percentual proprio de um produto dentro da regra (override do
    GSK1_PCT). nPct 0 remove o override.
    @type Cadastro precos
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg}
/*/
User Function GESSARPROD(cCfg, cProd, nPct)
    Local cFil := FWxFilial("GSK2")
    cCfg := Upper(BOCOL(cCfg))
    cProd := BOCOL(cProd)
    nPct := BOVAL(nPct)
    If cCfg == "" .Or. cProd == ""
        Return {.F., "regra_e_produto_obrigatorios"}
    EndIf
    If nPct < 0 .Or. nPct > 100
        Return {.F., "percentual_invalido: 0 a 100"}
    EndIf
    If !GESSARMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GSK2 SET D_E_L_E_T_ = '*' WHERE GSK2_FILIAL = " + GEBDBQuote(cFil) + " AND GSK2_CFG = " + GEBDBQuote(cCfg) + ;
        " AND GSK2_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
    If nPct > 0
        TCSqlExec("INSERT INTO GSK2 (D_E_L_E_T_, GSK2_FILIAL, GSK2_CFG, GSK2_PROD, GSK2_PCT) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
            GEBDBQuote(cCfg) + ", " + GEBDBQuote(cProd) + ", " + BONUM(nPct, 4) + ")")
    EndIf
Return {.T., "produto " + cProd + " na regra " + cCfg}

/*/{Protheus.doc} GESSARLISTA
    Lista as regras de reajuste (para tela e testes).
    @type Consulta precos
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg, aLinhas}
/*/
User Function GESSARLISTA()
    Local aHit := {}
    Local aLin := {{"codigo", "descricao", "pct", "vezes", "feitas", "horas", "ativo"}}
    Local nI := 0
    If !GESSARMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GSK1_COD AS C, GSK1_DESCR AS D, GSK1_PCT AS P, GSK1_VEZES AS V, GSK1_FEITAS AS F, " + ;
        "GSK1_HORAS AS H, GSK1_ATIVO AS A FROM GSK1 WHERE GSK1_FILIAL = " + GEBDBQuote(FWxFilial("GSK1")) + " AND D_E_L_E_T_ = ' ' ORDER BY GSK1_COD")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:C), BOCOL(aHit[nI]:D), BOVAL(aHit[nI]:P), BOVAL(aHit[nI]:V), BOVAL(aHit[nI]:F), ;
            BOCOL(aHit[nI]:H), BOCOL(aHit[nI]:A)})
    Next nI
    BOREL(aLin)
Return {.T., "regras_sarney", aLin}

/*/{Protheus.doc} GESSARHIST
    Historico de aplicacoes da regra (mais recentes primeiro).
    @type Consulta precos
    @author Peder Munksgaard
    @since 26/11/2026
    @return {lOk, cMsg, aLinhas}
/*/
User Function GESSARHIST(cCfg)
    Local aHit := {}
    Local aLin := {{"data", "hora", "produto", "pct", "antes", "depois"}}
    Local nI := 0
    cCfg := Upper(BOCOL(cCfg))
    If !GESSARMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GSK3_DATA AS D, GSK3_HORA AS H, GSK3_PROD AS P, GSK3_PCT AS PC, GSK3_ANT AS A, GSK3_NOV AS N FROM GSK3 " + ;
        "WHERE GSK3_FILIAL = " + GEBDBQuote(FWxFilial("GSK3")) + " AND GSK3_CFG = " + GEBDBQuote(cCfg) + " AND D_E_L_E_T_ = ' ' " + ;
        "ORDER BY GSK3_DATA DESC, GSK3_HORA DESC, GSK3_PROD LIMIT 500")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:D), BOCOL(aHit[nI]:H), BOCOL(aHit[nI]:P), BOVAL(aHit[nI]:PC), BOVAL(aHit[nI]:A), BOVAL(aHit[nI]:N)})
    Next nI
    BOREL(aLin)
Return {.T., "historico_" + cCfg, aLin}

/*/{Protheus.doc} GESSARDEVE
    A regra deve ser aplicada neste horario? Funcao pura (sem banco):
    cHoje AAAAMMDD, cHora/hora do slot HHMM, aCfg = linha de GSK1 como
    array {cod, descr, pct, vezes, horas, feitas, ulthora, ativo}.
    @type Funcao pura
    @author Peder Munksgaard
    @since 26/11/2026
    @return lOk
/*/
User Function GESSARDEVE(cHoje, cHora, aCfg)
    Local cSlot := ""
    If Len(aCfg) < 8 .Or. !(BOCOL(aCfg[8]) == "S")
        Return .F.
    EndIf
    If BOVAL(aCfg[6]) >= BOVAL(aCfg[4])
        Return .F.
    EndIf
    If !((" " + cHora + " ") $ (" " + BOCOL(aCfg[5]) + " "))
        Return .F.
    EndIf
    cSlot := cHoje + cHora
    If BOCOL(aCfg[7]) == cSlot
        Return .F.
    EndIf
Return .T.

/*/{Protheus.doc} GESSARAPLICA
    Aplica o reajuste de uma regra nos precos PADRAO. Devolve
    {lOk, cMsg, nAplicados}. Override de GSK2 vence o pct geral.
    @type Operacao precos
    @author Peder Munksgaard
    @since 26/11/2026
/*/
User Function GESSARAPLICA(cHoje, cHora, aCfg)
    Local aOvr := {}
    Local aHit := {}
    Local cCfg := ""
    Local cProd := ""
    Local nPct := 0
    Local nAnt := 0
    Local nNov := 0
    Local nI := 0
    Local nJ := 0
    Local nOk := 0
    cCfg := Upper(BOCOL(aCfg[1]))
    If !GESSARMIG()
        Return {.F., "falha_tabelas", 0}
    EndIf
    // Overrides da regra: {produto, pct}.
    aOvr := TCSqlQuery("SELECT GSK2_PROD AS P, GSK2_PCT AS PC FROM GSK2 WHERE GSK2_FILIAL = " + GEBDBQuote(FWxFilial("GSK2")) + ;
        " AND GSK2_CFG = " + GEBDBQuote(cCfg) + " AND D_E_L_E_T_ = ' '")
    // Todos os produtos com preco na tabela PADRAO.
    aHit := TCSqlQuery("SELECT GFT2_PROD AS P, GFT2_PRECO AS PR FROM GFT2 WHERE GFT2_FILIAL = " + GEBDBQuote(FWxFilial("GFT2")) + ;
        " AND GFT2_TAB = 'PADRAO' AND GFT2_PRECO > 0 AND D_E_L_E_T_ = ' ' ORDER BY GFT2_PROD")
    For nI := 1 To Len(aHit)
        cProd := BOCOL(aHit[nI]:P)
        nPct := BOVAL(aCfg[3])
        For nJ := 1 To Len(aOvr)
            If BOCOL(aOvr[nJ]:P) == cProd
                nPct := BOVAL(aOvr[nJ]:PC)
            EndIf
        Next nJ
        nAnt := BOVAL(aHit[nI]:PR)
        nNov := Round(nAnt * (1 + nPct / 100), 4)
        If !(nNov == nAnt)
            TCSqlExec("UPDATE GFT2 SET GFT2_PRECO = " + BONUM(nNov, 6) + " WHERE GFT2_FILIAL = " + GEBDBQuote(FWxFilial("GFT2")) + ;
                " AND GFT2_TAB = 'PADRAO' AND GFT2_PROD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' '")
            TCSqlExec("INSERT INTO GSK3 (D_E_L_E_T_, GSK3_FILIAL, GSK3_CFG, GSK3_DATA, GSK3_HORA, GSK3_PROD, GSK3_PCT, GSK3_ANT, GSK3_NOV) VALUES (' ', " + ;
                GEBDBQuote(FWxFilial("GSK3")) + ", " + GEBDBQuote(cCfg) + ", " + GEBDBQuote(cHoje) + ", " + GEBDBQuote(cHora) + ", " + ;
                GEBDBQuote(cProd) + ", " + BONUM(nPct, 4) + ", " + BONUM(nAnt, 6) + ", " + BONUM(nNov, 6) + ")")
            nOk := nOk + 1
        EndIf
    Next nI
    TCSqlExec("UPDATE GSK1 SET GSK1_FEITAS = GSK1_FEITAS + 1, GSK1_ULTHORA = " + GEBDBQuote(cHoje + cHora) + " WHERE GSK1_FILIAL = " + ;
        GEBDBQuote(FWxFilial("GSK1")) + " AND GSK1_COD = " + GEBDBQuote(cCfg) + " AND D_E_L_E_T_ = ' '")
Return {.T., "regra " + cCfg + ": " + BONUM(nOk, 0) + " precos reajustados", nOk}

/*/{Protheus.doc} GESSARRUN
    Executor do Sarney, chamado pelo agendador a cada minuto (dentro da
    trava da empresa). Aplica as regras devidas neste minuto.
    @type Executor precos
    @author Peder Munksgaard
    @since 26/11/2026
    @return nAplicacoes (soma dos produtos reajustados)
/*/
User Function GESSARRUN()
    Local cHoje := DToS(Date())
    Local cHora := SubStr(Time(), 1, 2) + SubStr(Time(), 4, 2)
    Local aCfgs := {}
    Local aCfg  := {}
    Local nTot  := 0
    Local nI    := 0
    Local aRes  := {}
    If !GESSARMIG()
        Return 0
    EndIf
    aCfgs := TCSqlQuery("SELECT GSK1_COD AS C, GSK1_DESCR AS D, GSK1_PCT AS P, GSK1_VEZES AS V, GSK1_HORAS AS H, " + ;
        "GSK1_FEITAS AS F, GSK1_ULTHORA AS U, GSK1_ATIVO AS A FROM GSK1 WHERE GSK1_FILIAL = " + GEBDBQuote(FWxFilial("GSK1")) + ;
        " AND D_E_L_E_T_ = ' ' ORDER BY GSK1_COD")
    For nI := 1 To Len(aCfgs)
        aCfg := {BOCOL(aCfgs[nI]:C), BOCOL(aCfgs[nI]:D), BOVAL(aCfgs[nI]:P), BOVAL(aCfgs[nI]:V), BOCOL(aCfgs[nI]:H), ;
            BOVAL(aCfgs[nI]:F), BOCOL(aCfgs[nI]:U), BOCOL(aCfgs[nI]:A)}
        If GESSARDEVE(cHoje, cHora, aCfg)
            aRes := GESSARAPLICA(cHoje, cHora, aCfg)
            If aRes[1]
                nTot := nTot + aRes[3]
            Else
                ConOut("GESSAR: " + aRes[2])
            EndIf
        EndIf
    Next nI
Return nTot

// Valida e normaliza a lista de horarios "0800 1200" -> "0800 1200" ou "".
Static Function GESSARHORASOK(cHoras)
    Local aH := StrTokArr(cValToChar(cHoras), " ")
    Local cOk := ""
    Local nI := 0
    For nI := 1 To Len(aH)
        If !(BOCOL(aH[nI]) == "")
            If !(Len(BOCOL(aH[nI])) == 4) .Or. !GESOMADIG(BOCOL(aH[nI]))
                Return ""
            EndIf
            If Val(SubStr(aH[nI], 1, 2)) > 23 .Or. Val(SubStr(aH[nI], 3, 2)) > 59
                Return ""
            EndIf
            cOk := cOk + Iif(cOk == "", "", " ") + BOCOL(aH[nI])
        EndIf
    Next nI
Return cOk

// Digitos apenas (GEBSCHSOMADIG e' estatico de GEBSCH; replica aqui).
Static Function GESOMADIG(cTxt)
    Local nI := 0
    For nI := 1 To Len(cTxt)
        If At(SubStr(cTxt, nI, 1), "0123456789") == 0
            Return .F.
        EndIf
    Next nI
Return Len(cTxt) > 0
