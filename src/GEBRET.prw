#include "totvs.ch"

/*/{Protheus.doc} GEBRET
    Retencoes na fonte feitas pela empresa como tomadora (ISS, IRRF, INSS,
    PIS, COFINS, CSLL). GRT1 = regras (codigo, tributo, aliquota); GRT2 =
    retencoes por documento. Na entrada de compra, cada codigo informado
    retem base x aliquota: o valor sai do titulo do fornecedor (a partir da
    primeira parcela aberta), vai para 2.01.005 (D fornecedores / C tributos
    retidos) e acumula na guia da Derrama RET-<tributo>-AAAAMM, com
    vencimento no dia RET_DIA_<tributo> (padrao 20) do mes seguinte.
    Fora do escopo: retencao sofrida (quando o cliente retem).
    @type Fonte
    @author Peder Munksgaard
    @since 19/10/2026
/*/

/*/{Protheus.doc} GEBRETMIG
    Cria GRT1 e GRT2.
    @type Migracao
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se as tabelas existem
/*/
User Function GEBRETMIG()
    Local lOk := BOMIG()
    lOk := lOk .And. BOTAB("GRT1", "GRT1_COD TEXT NOT NULL, GRT1_TRIB TEXT NOT NULL, GRT1_ALIQ NUMERIC(8,4) NOT NULL, GRT1_DESC TEXT NOT NULL", "GRT1_COD")
    lOk := lOk .And. BOTAB("GRT2", "GRT2_DOC TEXT NOT NULL, GRT2_FORN TEXT NOT NULL, GRT2_COD TEXT NOT NULL, GRT2_TRIB TEXT NOT NULL, " + ;
        "GRT2_BASE NUMERIC(18,2) NOT NULL, GRT2_ALIQ NUMERIC(8,4) NOT NULL, GRT2_VALOR NUMERIC(18,2) NOT NULL, GRT2_DATA TEXT NOT NULL, " + ;
        "GRT2_COMP TEXT NOT NULL, GRT2_GUIA TEXT NOT NULL", "GRT2_DOC")
Return lOk

/*/{Protheus.doc} GEBRETCAD
    Cadastra ou altera uma regra de retencao.
    @type Cadastro fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @param cTrib ISS, IRRF, INSS, PIS, COFINS ou CSLL
    @param nAliq Aliquota em % (maior que 0, ate 100)
    @return {lOk, cMsg}
/*/
User Function GEBRETCAD(cCod, cTrib, nAliq, cDesc)
    Local cFil := FWxFilial("GRT1")
    cCod := Upper(BOCOL(cCod))
    cTrib := Upper(BOCOL(cTrib))
    nAliq := Round(BOVAL(nAliq), 4)
    If cCod == ""
        Return {.F., "codigo_vazio"}
    EndIf
    If AScan(RETTributos(), cTrib) == 0
        Return {.F., "tributo_invalido: ISS, IRRF, INSS, PIS, COFINS ou CSLL"}
    EndIf
    If nAliq <= 0 .Or. nAliq > 100
        Return {.F., "aliquota_invalida: maior que 0 e ate 100"}
    EndIf
    If !GEBRETMIG()
        Return {.F., "falha_tabelas"}
    EndIf
    TCSqlExec("UPDATE GRT1 SET D_E_L_E_T_ = '*' WHERE GRT1_FILIAL = " + GEBDBQuote(cFil) + " AND GRT1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("INSERT INTO GRT1 (D_E_L_E_T_, GRT1_FILIAL, GRT1_COD, GRT1_TRIB, GRT1_ALIQ, GRT1_DESC) VALUES (' ', " + GEBDBQuote(cFil) + ", " + ;
        GEBDBQuote(cCod) + ", " + GEBDBQuote(cTrib) + ", " + BONUM(nAliq, 4) + ", " + GEBDBQuote(BOCOL(cDesc)) + ")")
Return {.T., "retencao " + cCod + " gravada"}

/*/{Protheus.doc} GEBRETVAL
    Valida os codigos de retencao de um documento (lista ou texto separado
    por virgula): existem e no maximo um por tributo.
    @type Validacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {{cCod, cTrib, nAliq}...}}
/*/
User Function GEBRETVAL(xCod)
    Local aCod := RETLista(xCod)
    Local aReg := {}
    Local aHit := {}
    Local nSoma := 0
    Local nI := 0
    Local nJ := 0
    If Len(aCod) == 0
        Return {.T., "sem_retencao", {}}
    EndIf
    If !GEBRETMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    For nI := 1 To Len(aCod)
        aHit := TCSqlQuery("SELECT GRT1_TRIB AS T, GRT1_ALIQ AS A FROM GRT1 WHERE GRT1_FILIAL = " + GEBDBQuote(FWxFilial("GRT1")) + ;
            " AND GRT1_COD = " + GEBDBQuote(aCod[nI]) + " AND D_E_L_E_T_ = ' '")
        If Len(aHit) == 0
            Return {.F., "retencao_inexistente: " + aCod[nI], {}}
        EndIf
        For nJ := 1 To Len(aReg)
            If aReg[nJ][2] == BOCOL(aHit[1]:T)
                Return {.F., "tributo_retido_duas_vezes: " + BOCOL(aHit[1]:T), {}}
            EndIf
        Next nJ
        aAdd(aReg, {aCod[nI], BOCOL(aHit[1]:T), BOVAL(aHit[1]:A)})
        nSoma := nSoma + BOVAL(aHit[1]:A)
    Next nI
    If nSoma >= 100
        Return {.F., "retencao_maior_que_o_documento: aliquotas somam " + BONUM(nSoma, 2) + "%", {}}
    EndIf
Return {.T., "retencoes validas", aReg}

/*/{Protheus.doc} GEBRETAPL
    Aplica as retencoes validadas a um documento de entrada: grava GRT2,
    abate o valor dos titulos do fornecedor (aTit, na ordem), contabiliza
    RET_FORN e acumula a guia da Derrama do tributo no mes.
    @type Operacao fiscal
    @author Peder Munksgaard
    @since 19/10/2026
    @param aReg Regras de GEBRETVAL
    @param aTit Titulos a pagar do documento {{cDoc, cVenc, nValor}...}
    @return {lOk, cMsg, nTotalRetido}
/*/
User Function GEBRETAPL(cDoc, cForn, nBase, aReg, cData, aTit)
    Local aR := {}
    Local aHit := {}
    Local cComp := Left(BODATA(cData), 6)
    Local cGuia := ""
    Local nVal := 0
    Local nTot := 0
    Local nResta := 0
    Local nAbate := 0
    Local nSaldo := 0
    Local nI := 0
    Local nJ := 0

    nBase := Round(BOVAL(nBase), 2)
    For nI := 1 To Len(aReg)
        nTot := nTot + Round(nBase * aReg[nI][3] / 100, 2)
    Next nI
    If nTot <= 0
        Return {.T., "sem_retencao", 0}
    EndIf
    If nTot >= nBase
        Return {.F., "retencao_maior_que_o_documento", 0}
    EndIf
    // Abate o total retido dos titulos, na ordem das parcelas.
    nResta := nTot
    For nJ := 1 To Len(aTit)
        If nResta > 0
            aHit := TCSqlQuery("SELECT GFN3_SALDO AS S FROM GFN3 WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND GFN3_DOC = " + ;
                GEBDBQuote(aTit[nJ][1]) + " AND GFN3_STATUS = 'ABERTO' AND D_E_L_E_T_ = ' '")
            If Len(aHit) > 0
                nSaldo := Round(BOVAL(aHit[1]:S), 2)
                nAbate := Min(nSaldo, nResta)
                TCSqlExec("UPDATE GFN3 SET GFN3_VALOR = GFN3_VALOR - " + BONUM(nAbate, 2) + ", GFN3_SALDO = GFN3_SALDO - " + BONUM(nAbate, 2) + ;
                    " WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND GFN3_DOC = " + GEBDBQuote(aTit[nJ][1]) + " AND D_E_L_E_T_ = ' '")
                If nAbate == nSaldo
                    TCSqlExec("UPDATE GFN3 SET GFN3_STATUS = 'PAGA' WHERE GFN3_FILIAL = " + GEBDBQuote(FWxFilial("GFN3")) + " AND GFN3_DOC = " + ;
                        GEBDBQuote(aTit[nJ][1]) + " AND D_E_L_E_T_ = ' '")
                EndIf
                nResta := Round(nResta - nAbate, 2)
            EndIf
        EndIf
    Next nJ
    For nI := 1 To Len(aReg)
        nVal := Round(nBase * aReg[nI][3] / 100, 2)
        If nVal > 0
            GEBCTXLP("RET_FORN", nVal, cDoc + " " + aReg[nI][2], cData)
            TCSqlExec("INSERT INTO GRT2 (D_E_L_E_T_, GRT2_FILIAL, GRT2_DOC, GRT2_FORN, GRT2_COD, GRT2_TRIB, GRT2_BASE, GRT2_ALIQ, GRT2_VALOR, GRT2_DATA, " + ;
                "GRT2_COMP, GRT2_GUIA) VALUES (' ', " + GEBDBQuote(FWxFilial("GRT2")) + ", " + GEBDBQuote(cDoc) + ", " + GEBDBQuote(cForn) + ", " + ;
                GEBDBQuote(aReg[nI][1]) + ", " + GEBDBQuote(aReg[nI][2]) + ", " + BONUM(nBase, 2) + ", " + BONUM(aReg[nI][3], 4) + ", " + ;
                BONUM(nVal, 2) + ", " + GEBDBQuote(BODATA(cData)) + ", " + GEBDBQuote(cComp) + ", '')")
            aR := RETGuia(aReg[nI][2], cComp)
            cGuia := aR[3]
            TCSqlExec("UPDATE GRT2 SET GRT2_GUIA = " + GEBDBQuote(cGuia) + " WHERE GRT2_FILIAL = " + GEBDBQuote(FWxFilial("GRT2")) + ;
                " AND GRT2_DOC = " + GEBDBQuote(cDoc) + " AND GRT2_TRIB = " + GEBDBQuote(aReg[nI][2]) + " AND D_E_L_E_T_ = ' '")
        EndIf
    Next nI
Return {.T., "retido " + BONUM(nTot, 2), nTot}

/*/{Protheus.doc} GEBRETREL
    Relatorio: retencoes da competencia por documento e tributo, com a guia.
    @type Relatorio
    @author Peder Munksgaard
    @since 19/10/2026
    @return {lOk, cMsg, {aResumo, aLinhas (1a = cabecalho)}}
/*/
User Function GEBRETREL(cComp)
    Local aLin := {{"documento", "fornecedor", "tributo", "base", "aliquota", "valor", "guia"}}
    Local aRes := {}
    Local aHit := {}
    Local nTot := 0
    Local nI := 0
    If !BOCOMPOK(cComp)
        Return {.F., "competencia_invalida: use AAAAMM", {}}
    EndIf
    If !GEBRETMIG()
        Return {.F., "falha_tabelas", {}}
    EndIf
    aHit := TCSqlQuery("SELECT GRT2_DOC AS D, GRT2_FORN AS F, GRT2_TRIB AS T, GRT2_BASE AS B, GRT2_ALIQ AS A, GRT2_VALOR AS V, GRT2_GUIA AS G " + ;
        "FROM GRT2 WHERE GRT2_FILIAL = " + GEBDBQuote(FWxFilial("GRT2")) + " AND GRT2_COMP = " + GEBDBQuote(cComp) + ;
        " AND D_E_L_E_T_ = ' ' ORDER BY GRT2_TRIB, GRT2_DOC")
    For nI := 1 To Len(aHit)
        aAdd(aLin, {BOCOL(aHit[nI]:D), BOCOL(aHit[nI]:F), BOCOL(aHit[nI]:T), BOVAL(aHit[nI]:B), BOVAL(aHit[nI]:A), BOVAL(aHit[nI]:V), BOCOL(aHit[nI]:G)})
        nTot := nTot + BOVAL(aHit[nI]:V)
    Next nI
    aAdd(aRes, {"competencia", cComp})
    aAdd(aRes, {"retencoes", Len(aHit)})
    aAdd(aRes, {"total_retido", Round(nTot, 2)})
Return {.T., "retencoes de " + cComp, {aRes, aLin}}

// Guia do tributo no mes: total retido no mes; guia ja paga gera complementar.
Static Function RETGuia(cTrib, cComp)
    Local aHit := TCSqlQuery("SELECT COALESCE(SUM(GRT2_VALOR), 0) AS V FROM GRT2 WHERE GRT2_FILIAL = " + GEBDBQuote(FWxFilial("GRT2")) + ;
        " AND GRT2_TRIB = " + GEBDBQuote(cTrib) + " AND GRT2_COMP = " + GEBDBQuote(cComp) + " AND D_E_L_E_T_ = ' '")
Return GEBDERGUIA("RET-" + cTrib + "-" + cComp, "RET_" + cTrib, cComp, Round(BOVAL(aHit[1]:V), 2), ;
    GEBSNVENC(cComp, Val(BOPARM("RET_DIA_" + cTrib, "20"))), "2.01.005", "FISCO")

Static Function RETTributos()
Return {"ISS", "IRRF", "INSS", "PIS", "COFINS", "CSLL"}

// Lista de codigos: array ou texto separado por virgula.
Static Function RETLista(xCod)
    Local aCod := {}
    Local aTmp := {}
    Local nI := 0
    If ValType(xCod) == "A"
        aTmp := xCod
    ElseIf ValType(xCod) == "C"
        aTmp := StrTokArr(xCod, ",")
    EndIf
    For nI := 1 To Len(aTmp)
        If !(Upper(BOCOL(aTmp[nI])) == "")
            aAdd(aCod, Upper(BOCOL(aTmp[nI])))
        EndIf
    Next nI
Return aCod
