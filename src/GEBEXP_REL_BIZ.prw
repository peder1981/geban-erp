#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBEXP_REL_BIZ
    Relatorios por modulo GEB_EXPANSAO (Task 4 GEB_EXPANSAO).
    Funcoes:
    - GEBRELFISCAL(cEmpresa, cComp): notas, bases, IBS/CBS, debito, credito,
      saldo derrama, apuracoes, regime.
    - GEBRELDERRAMA(cEmpresa, cComp): guias, pagas, vencidas, valor total,
      parcelas, protestos.
    - GEBRELFIN(cEmpresa): contas, receber, pagar, valores, saldo caixa,
      movimentos.
    - GEBRELSTOQUE(cEmpresa): produtos, itens baixo minimo, valor total,
      movimentos.
    - GEBRELCOMPRAS(cEmpresa): fornecedores, pedidos, recebidos, valor total,
      cotacoes.
    - GEBRELCONTABIL(cEmpresa, cComp): lancamentos, debitos, creditos,
      valores, saldo.
    - GEBRELGERAL(cEmpresa): consolidado de todos modulos acima.
    Retorno: arrays com posicoes fixas conforme documentação de cada funcao.
    Notas AdvPP: ConOut p/ log; If Nil em vez de Default; GetArea/RestArea
    guardados; trabalho via workarea; guardas de existencia via GEBDBTableExistsHere;
    sem SELECT *, sem concat SQL, sem cFilial, sem IIF.
    @type Modulo de relatorios de negocio
    @author Peder Munksgaard
    @since 23/09/2026
/*/

/*/ GEBRELFISCAL(cEmpresa, cComp)
   Retorna array {nNotas, nBase, nIBS, nCBS, nDebito, nCredito,
                  saldoDerrama, nApuracoes, regime}
/*/
User Function GEBRELFISCAL(cEmpresa, cComp)
    Local aArea := GetArea()
    Local aRet := {0, 0, 0, 0, 0, 0, 0, 0, ""}
    Local nNotas := 0
    Local nBase := 0
    Local nIBS := 0
    Local nCBS := 0
    Local nDeb := 0
    Local nCred := 0
    Local nSaldo := 0
    Local nApur := 0
    Local cRegime := ""
    Local cFil3 := ""
    Local cFil5 := ""
    Local cEmpSan := ""

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf
    If cComp == Nil
        cComp := ""
    EndIf

    If !GEBDBTableExistsHere("GF3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf

    cFil3 := FWxFilial("GF3")
    cEmpSan := Trim(cEmpresa)

    // Contagem de notas e somas de base/IBS/CBS na competencia.
    DbSelectArea("GF3")
    DbGoTop()
    While !Eof()
        If GF3->D_E_L_E_T_ == " "
            If cEmpSan == "" .Or. (.T.)
                If cComp == "" .Or. SubStr(GF3->GF3_EMIS, 1, 6) == cComp
                    nNotas++
                    nBase := nBase + GF3->GF3_BASE
                    nIBS := nIBS + GF3->GF3_IBS
                    nCBS := nCBS + GF3->GF3_CBS
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Soma debit/credit da apuracao na competencia.
    If GEBDBTableExistsHere("GF5")
        cFil5 := FWxFilial("GF5")
        DbSelectArea("GF5")
        DbGoTop()
        While !Eof()
            If GF5->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    If cComp == "" .Or. GF5->GF5_COMP == cComp
                        nDeb := nDeb + GF5->GF5_DEB
                        nCred := nCred + GF5->GF5_CRED
                        nSaldo := nSaldo + GF5->GF5_SALDO
                        nApur++
                        cRegime := GF5->GF5_REGIME
                    EndIf
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    aRet[1] := nNotas
    aRet[2] := nBase
    aRet[3] := nIBS
    aRet[4] := nCBS
    aRet[5] := nDeb
    aRet[6] := nCred
    aRet[7] := nSaldo
    aRet[8] := nApur
    aRet[9] := cRegime

    ConOut("REL_FISC " + cEmpSan + " " + cComp + " notas=" + cValToChar(nNotas))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBRELDERRAMA(cEmpresa, cComp)
   Retorna array {nGuias, nPagas, nVencidas, nValorTotal, nParcelas, nProtestos}
/*/
User Function GEBRELDERRAMA(cEmpresa, cComp)
    Local aArea := GetArea()
    Local aRet := {0, 0, 0, 0, 0, 0}
    Local nGuias := 0
    Local nPagas := 0
    Local nVencidas := 0
    Local nValTot := 0
    Local nParc := 0
    Local nProv := 0
    Local cEmpSan := ""

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf
    If cComp == Nil
        cComp := ""
    EndIf

    If !GEBDBTableExistsHere("GD1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf

    cEmpSan := Trim(cEmpresa)

    // Guias.
    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->D_E_L_E_T_ == " "
            If cEmpSan == "" .Or. (.T.)
                If cComp == "" .Or. GD1->GD1_COMP == cComp
                    nGuias++
                    nValTot := nValTot + GD1->GD1_TOTAL
                    If GD1->GD1_STATUS == "BAIXADA"
                        nPagas++
                    EndIf
                    If GD1->GD1_STATUS == "VENCIDA"
                        nVencidas++
                    EndIf
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Parcelas.
    If GEBDBTableExistsHere("GD2")
        DbSelectArea("GD2")
        DbGoTop()
        While !Eof()
            If GD2->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nParc++
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Protestos.
    If GEBDBTableExistsHere("GD3")
        DbSelectArea("GD3")
        DbGoTop()
        While !Eof()
            If GD3->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    If GD3->GD3_ACAO == "PROTESTO"
                        nProv++
                    EndIf
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    aRet[1] := nGuias
    aRet[2] := nPagas
    aRet[3] := nVencidas
    aRet[4] := nValTot
    aRet[5] := nParc
    aRet[6] := nProv

    ConOut("REL_DER " + cEmpSan + " guias=" + cValToChar(nGuias))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBRELFIN(cEmpresa)
   Retorna array {nContas, nReceber, nPagar, nValorReceber, nValorPagar,
                  saldoCaixa, nMovimentos}
/*/
User Function GEBRELFIN(cEmpresa)
    Local aMovX := {}
    Local aArea := GetArea()
    Local aRet := {0, 0, 0, 0, 0, 0, 0}
    Local nContas := 0
    Local nRec := 0
    Local nPag := 0
    Local nValRec := 0
    Local nValPag := 0
    Local nSaldo := 0
    Local nMov := 0
    Local cEmpSan := ""

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf

    cEmpSan := Trim(cEmpresa)

    // Contas em GFN1.
    If GEBDBTableExistsHere("GFN1")
        DbSelectArea("GFN1")
        DbGoTop()
        While !Eof()
            If GFN1->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nContas++
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // A receber (GFN2 ABERTO).
    If GEBDBTableExistsHere("GFN2")
        DbSelectArea("GFN2")
        DbGoTop()
        While !Eof()
            If GFN2->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    If GFN2->GFN2_STATUS == "ABERTO"
                        nRec++
                        nValRec := nValRec + GFN2->GFN2_SALDO
                    EndIf
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // A pagar (GFN3 ABERTO).
    If GEBDBTableExistsHere("GFN3")
        DbSelectArea("GFN3")
        DbGoTop()
        While !Eof()
            If GFN3->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    If GFN3->GFN3_STATUS == "ABERTO"
                        nPag++
                        nValPag := nValPag + GFN3->GFN3_SALDO
                    EndIf
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Movimentos (GFN4).
    If GEBDBTableExistsHere("GFN4")
        DbSelectArea("GFN4")
        DbGoTop()
        While !Eof()
            If GFN4->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nMov++
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    // Movimentos do financeiro novo (GFX4: baixas, transferencias, avulsos).
    If GEBDBTableExistsHere("GFX4")
        aMovX := TCSqlQuery("SELECT COUNT(*) AS Q FROM GFX4 WHERE D_E_L_E_T_ = ' '")
        nMov := nMov + Val(cValToChar(aMovX[1]:Q))
    EndIf

    nSaldo := nValRec - nValPag

    aRet[1] := nContas
    aRet[2] := nRec
    aRet[3] := nPag
    aRet[4] := nValRec
    aRet[5] := nValPag
    aRet[6] := nSaldo
    aRet[7] := nMov

    ConOut("REL_FIN " + cEmpSan + " receber=" + cValToChar(nValRec) + " pagar=" + cValToChar(nValPag))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBRELSTOQUE(cEmpresa)
   Retorna array {nProdutos, nItensBaixoMinimo, valorTotalEstoque, nMovimentos}
/*/
User Function GEBRELSTOQUE(cEmpresa)
    Local aArea := GetArea()
    Local aRet := {0, 0, 0, 0}
    Local nProd := 0
    Local nBaixMin := 0
    Local nValTot := 0
    Local nMov := 0
    Local cEmpSan := ""

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf

    cEmpSan := Trim(cEmpresa)

    If !GEBDBTableExistsHere("GV1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf

    DbSelectArea("GV1")
    DbGoTop()
    While !Eof()
        If GV1->D_E_L_E_T_ == " "
            If cEmpSan == "" .Or. (.T.)
                nProd++
                nValTot := nValTot + GV1->GV1_SALDO
                If GV1->GV1_SALDO < GV1->GV1_MIN
                    nBaixMin++
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Movimentos de estoque via GV2.
    If GEBDBTableExistsHere("GV2")
        DbSelectArea("GV2")
        DbGoTop()
        While !Eof()
            If GV2->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nMov++
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    aRet[1] := nProd
    aRet[2] := nBaixMin
    aRet[3] := nValTot
    aRet[4] := nMov

    ConOut("REL_EST " + cEmpSan + " produtos=" + cValToChar(nProd))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBRELCOMPRAS(cEmpresa)
   Retorna array {nFornecedores, nPedidos, nRecebidos, nValorTotal, nCotacoes}
/*/
User Function GEBRELCOMPRAS(cEmpresa)
    Local aArea := GetArea()
    Local aRet := {0, 0, 0, 0, 0}
    Local nForn := 0
    Local nPed := 0
    Local nRecb := 0
    Local nValTot := 0
    Local nCot := 0
    Local cEmpSan := ""

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf

    cEmpSan := Trim(cEmpresa)

    // Fornecedores GCP1.
    If GEBDBTableExistsHere("GCP1")
        DbSelectArea("GCP1")
        DbGoTop()
        While !Eof()
            If GCP1->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nForn++
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Pedidos GCP3.
    If GEBDBTableExistsHere("GCP3")
        DbSelectArea("GCP3")
        DbGoTop()
        While !Eof()
            If GCP3->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nPed++
                    If GCP3->GCP3_STATUS == "RECEBIDO"
                        nRecb++
                    EndIf
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Valor total dos pedidos (soma QTD*PRECO dos itens GCP4).
    If GEBDBTableExistsHere("GCP4")
        DbSelectArea("GCP4")
        DbGoTop()
        While !Eof()
            If GCP4->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nValTot := nValTot + (GCP4->GCP4_QTD * GCP4->GCP4_PRECO)
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Cotacoes GCP2.
    If GEBDBTableExistsHere("GCP2")
        DbSelectArea("GCP2")
        DbGoTop()
        While !Eof()
            If GCP2->D_E_L_E_T_ == " "
                If cEmpSan == "" .Or. (.T.)
                    nCot++
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    aRet[1] := nForn
    aRet[2] := nPed
    aRet[3] := nRecb
    aRet[4] := nValTot
    aRet[5] := nCot

    ConOut("REL_COM " + cEmpSan + " fornecedores=" + cValToChar(nForn))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBRELCONTABIL(cEmpresa, cComp)
   Retorna array {nLancamentos, nDec, nCred, valDec, valCred, saldo}
/*/
User Function GEBRELCONTABIL(cEmpresa, cComp)
    Local aArea := GetArea()
    Local aRet := {0, 0, 0, 0, 0, 0}
    Local nLan := 0
    Local nDec := 0
    Local nCred := 0
    Local nValDec := 0
    Local nValCred := 0
    Local nSaldo := 0
    Local cEmpSan := ""
    Local cLote := ""
    Local aLotes := {}
    Local nI := 0

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf
    If cComp == Nil
        cComp := ""
    EndIf

    cEmpSan := Trim(cEmpresa)

    If !GEBDBTableExistsHere("GC2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf
    If !GEBDBTableExistsHere("GC3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aRet
    EndIf

    // Lotes da competencia.
    DbSelectArea("GC2")
    DbGoTop()
    While !Eof()
        If GC2->D_E_L_E_T_ == " "
            If cEmpSan == "" .Or. (.T.)
                If cComp == "" .Or. GC2->GC2_COMP == cComp
                    AAdd(aLotes, GC2->GC2_LOTE)
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Percorre GC3 pelos lotes.
    DbSelectArea("GC3")
    DbGoTop()
    While !Eof()
        If GC3->D_E_L_E_T_ == " "
            If cEmpSan == "" .Or. (.T.)
                nLan++
                If Len(aLotes) == 0
                    // Sem filtro de competencia: conta tudo.
                Else
                    lTem := .F.
                    For nI := 1 To Len(aLotes)
                        If GC3->GC3_LOTE == aLotes[nI]
                            lTem := .T.
                            Exit
                        EndIf
                    Next nI
                    If !lTem
                        DbSkip()
                        Loop
                    EndIf
                EndIf
                If GC3->GC3_DC == "D"
                    nDec++
                    nValDec := nValDec + GC3->GC3_VALOR
                Else
                    If GC3->GC3_DC == "C"
                        nCred++
                        nValCred := nValCred + GC3->GC3_VALOR
                    EndIf
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    nSaldo := nValDec - nValCred

    aRet[1] := nLan
    aRet[2] := nDec
    aRet[3] := nCred
    aRet[4] := nValDec
    aRet[5] := nValCred
    aRet[6] := nSaldo

    ConOut("REL_CTB " + cEmpSan + " " + cComp + " lanc=" + cValToChar(nLan))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBRELGERAL(cEmpresa)
   Consolidado de todos os modulos. Retorna array {aFiscal, aDerrama, aFin,
   aEstoque, aCompras, aContabil}.
/*/
User Function GEBRELGERAL(cEmpresa)
    Local aArea := GetArea()
    Local aRet := {}
    Local aFiscal := {}
    Local aDerrama := {}
    Local aFin := {}
    Local aEstoque := {}
    Local aCompras := {}
    Local aContabil := {}

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf

    aFiscal := GEBRELFISCAL(cEmpresa, "")
    aDerrama := GEBRELDERRAMA(cEmpresa, "")
    aFin := GEBRELFIN(cEmpresa)
    aEstoque := GEBRELSTOQUE(cEmpresa)
    aCompras := GEBRELCOMPRAS(cEmpresa)
    aContabil := GEBRELCONTABIL(cEmpresa, "")

    AAdd(aRet, aFiscal)
    AAdd(aRet, aDerrama)
    AAdd(aRet, aFin)
    AAdd(aRet, aEstoque)
    AAdd(aRet, aCompras)
    AAdd(aRet, aContabil)

    ConOut("REL_GERAL consolidado empresa=" + Trim(cEmpresa))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet
