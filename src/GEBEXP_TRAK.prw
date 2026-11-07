#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBEXP_TRAK
    Trackers de rastreio ponta a ponta GEB_EXPANSAO (Task 4 GEB_EXPANSAO).
    Funcoes:
    - GEBTRAKCOMPRA(cPedido): rastreia do pedido aos lancamentos contabeis.
    - GEBTRAKVENDA(cVenda): rastreia da venda ao lancamento contabil.
    - GEBTRAKNOTAFISCAL(cChave): rastreia da NF a guia de derrama.
    - GEBTRAKDERRAMA(cGuia): rastreia da apuracao a baixa contabeis.
    Cada funcao retorna array de arrays com os dados coletados em cada
    etapa do fluxo. Linhas ausentes sao representadas por arrays vazios.
    Notas AdvPP: ConOut p/ log; If Nil em vez de Default; GetArea/RestArea
    guardados; trabalho via workarea; guardas de existencia via TCSqlQuery;
    sem SELECT *, sem concat SQL, sem cFilial, sem IIF.
    @type Modulo de trackers
    @author Peder Munksgaard
    @since 23/09/2026
/*/

/*/ GEBTRAKCOMPRA(cPedido)
   Retorna array {cPedido, aItens, aEntrada, aEstoque, aPagar, aLanc}
   onde cada elemento e um array de registros da respectiva tabela.
/*/
User Function GEBTRAKCOMPRA(cPedido)
    Local aArea := GetArea()
    Local aRet := {{}, {}, {}, {}, {}, {}}
    Local aChk := {}
    Local aItens := {}
    Local aEntrada := {}
    Local aEstoque := {}
    Local aPagar := {}
    Local aLanc := {}
    Local cPedSan := ""
    Local cPedFil := ""
    Local nI := 0
    Local cProd := ""
    Local nQtd := 0

    If cPedido == Nil
        cPedido := ""
    EndIf

    cPedSan := Trim(cPedido)

    // Header GCP3.
    If GEBDBTableExistsHere("GCP3")
        DbSelectArea("GCP3")
        DbGoTop()
        While !Eof()
            If GCP3->D_E_L_E_T_ == " "
                If GCP3->GCP3_NUM == cPedSan
                    AAdd(aRet[1], {GCP3->GCP3_NUM, GCP3->GCP3_FORN, GCP3->GCP3_STATUS})
                    cPedFil := GCP3->GCP3_FILIAL
                    Exit
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Itens GCP4.
    If GEBDBTableExistsHere("GCP4")
        DbSelectArea("GCP4")
        DbGoTop()
        While !Eof()
            If GCP4->D_E_L_E_T_ == " "
                If GCP4->GCP4_PED == cPedSan
                    AAdd(aItens, {GCP4->GCP4_PED, GCP4->GCP4_PROD, GCP4->GCP4_QTD, GCP4->GCP4_PRECO})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[2] := aItens

    // Entrada GCP5.
    If GEBDBTableExistsHere("GCP5")
        DbSelectArea("GCP5")
        DbGoTop()
        While !Eof()
            If GCP5->D_E_L_E_T_ == " "
                If GCP5->GCP5_PED == cPedSan
                    AAdd(aEntrada, {GCP5->GCP5_NF, GCP5->GCP5_PED, GCP5->GCP5_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[3] := aEntrada

    // Estoque GV1 para cada produto do pedido.
    If GEBDBTableExistsHere("GV1")
        DbSelectArea("GV1")
        DbGoTop()
        While !Eof()
            If GV1->D_E_L_E_T_ == " "
                nI := 0
                While nI <= Len(aItens)
                    If nI > 0
                        cProd := aItens[nI][2]
                        If GV1->GV1_PROD == cProd
                            AAdd(aEstoque, {GV1->GV1_PROD, GV1->GV1_SALDO, GV1->GV1_MIN})
                        EndIf
                    EndIf
                    nI++
                EndDo
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[4] := aEstoque

    // Titulos a pagar GFN3 criados a partir das NFs de entrada.
    If GEBDBTableExistsHere("GFN3")
        DbSelectArea("GFN3")
        DbGoTop()
        While !Eof()
            If GFN3->D_E_L_E_T_ == " "
                nI := 0
                While nI <= Len(aEntrada)
                    If nI > 0
                        If GFN3->GFN3_DOC == aEntrada[nI][1]
                            AAdd(aPagar, {GFN3->GFN3_DOC, GFN3->GFN3_FORN, GFN3->GFN3_SALDO, GFN3->GFN3_STATUS})
                        EndIf
                    EndIf
                    nI++
                EndDo
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[5] := aPagar

    // Lancamentos contabeis GC3 a partir dos lotes GFN3.
    If GEBDBTableExistsHere("GC3")
        DbSelectArea("GC3")
        DbGoTop()
        While !Eof()
            If GC3->D_E_L_E_T_ == " "
                nI := 0
                While nI <= Len(aPagar)
                    If nI > 0
                        If GC3->GC3_LOTE == aPagar[nI][1]
                            AAdd(aLanc, {GC3->GC3_LOTE, GC3->GC3_DC, GC3->GC3_CONTA, GC3->GC3_VALOR})
                        EndIf
                    EndIf
                    nI++
                EndDo
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[6] := aLanc

    ConOut("TRAK_COMPRA " + cPedSan + " itens=" + cValToChar(Len(aItens)))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBTRAKVENDA(cVenda)
   Retorna array {cVenda, aItens, aEstoque, aReceber, aLanc}
/*/
User Function GEBTRAKVENDA(cVenda)
    Local aArea := GetArea()
    Local aRet := {{}, {}, {}, {}, {}}
    Local aChk := {}
    Local aItens := {}
    Local aEstoque := {}
    Local aReceber := {}
    Local aLanc := {}
    Local cVenSan := ""
    Local nI := 0
    Local cProd := ""

    If cVenda == Nil
        cVenda := ""
    EndIf

    cVenSan := Trim(cVenda)

    // Items GV2 da venda.
    If GEBDBTableExistsHere("GV2")
        DbSelectArea("GV2")
        DbGoTop()
        While !Eof()
            If GV2->D_E_L_E_T_ == " "
                If GV2->GV2_VENDA == cVenSan
                    AAdd(aItens, {GV2->GV2_VENDA, GV2->GV2_PROD, GV2->GV2_QTD, GV2->GV2_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    // Estoque GV1 para cada produto vendido.
    If GEBDBTableExistsHere("GV1")
        DbSelectArea("GV1")
        DbGoTop()
        While !Eof()
            If GV1->D_E_L_E_T_ == " "
                nI := 0
                While nI <= Len(aItens)
                    If nI > 0
                        cProd := aItens[nI][2]
                        If GV1->GV1_PROD == cProd
                            AAdd(aEstoque, {GV1->GV1_PROD, GV1->GV1_SALDO, GV1->GV1_MIN})
                        EndIf
                    EndIf
                    nI++
                EndDo
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[3] := aEstoque

    // Titulos a receber GFN2 criados a partir da venda.
    If GEBDBTableExistsHere("GFN2")
        DbSelectArea("GFN2")
        DbGoTop()
        While !Eof()
            If GFN2->D_E_L_E_T_ == " "
                If GFN2->GFN2_DOC == cVenSan
                    AAdd(aReceber, {GFN2->GFN2_DOC, GFN2->GFN2_CLI, GFN2->GFN2_SALDO, GFN2->GFN2_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[4] := aReceber

    // Lancamentos contabeis GC3 a partir dos lotes GFN2.
    If GEBDBTableExistsHere("GC3")
        DbSelectArea("GC3")
        DbGoTop()
        While !Eof()
            If GC3->D_E_L_E_T_ == " "
                nI := 0
                While nI <= Len(aReceber)
                    If nI > 0
                        If GC3->GC3_LOTE == aReceber[nI][1]
                            AAdd(aLanc, {GC3->GC3_LOTE, GC3->GC3_DC, GC3->GC3_CONTA, GC3->GC3_VALOR})
                        EndIf
                    EndIf
                    nI++
                EndDo
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[5] := aLanc

    // Header da venda como primeiro elemento.
    AAdd(aRet[1], {cVenSan, Len(aItens), Len(aReceber)})
    aRet[2] := aItens

    ConOut("TRAK_VENDA " + cVenSan + " itens=" + cValToChar(Len(aItens)))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBTRAKNOTAFISCAL(cChave)
   Retorna array {aHeader, aItem, aCalc, aReceber, aApuracao, aGuia}
/*/
User Function GEBTRAKNOTAFISCAL(cChave)
    Local aArea := GetArea()
    Local aRet := {{}, {}, {}, {}, {}, {}}
    Local aChk := {}
    Local aHeader := {}
    Local aItem := {}
    Local aCalc := {}
    Local aReceber := {}
    Local aApur := {}
    Local aGuia := {}
    Local cChvSan := ""
    Local nBase := 0
    Local nIBS := 0
    Local nCBS := 0
    Local nI := 0
    Local cComp := ""
    Local cCompGuia := ""

    If cChave == Nil
        cChave := ""
    EndIf

    cChvSan := Trim(cChave)

    // Header GF3.
    If GEBDBTableExistsHere("GF3")
        DbSelectArea("GF3")
        DbGoTop()
        While !Eof()
            If GF3->D_E_L_E_T_ == " "
                If GF3->GF3_CHAVE == cChvSan
                    AAdd(aHeader, {GF3->GF3_CHAVE, GF3->GF3_TIPO, GF3->GF3_STATUS, GF3->GF3_BASE, GF3->GF3_IBS, GF3->GF3_CBS, GF3->GF3_EMIS})
                    nBase := GF3->GF3_BASE
                    nIBS := GF3->GF3_IBS
                    nCBS := GF3->GF3_CBS
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[1] := aHeader

    // Items GF4.
    If GEBDBTableExistsHere("GF4")
        DbSelectArea("GF4")
        DbGoTop()
        While !Eof()
            If GF4->D_E_L_E_T_ == " "
                If GF4->GF4_CHAVE == cChvSan
                    AAdd(aItem, {GF4->GF4_CHAVE, GF4->GF4_ITEM, GF4->GF4_PROD, GF4->GF4_QTD, GF4->GF4_PRECO, GF4->GF4_BASE, GF4->GF4_IBS, GF4->GF4_CBS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[2] := aItem

    // Calc IBS/CBS.
    AAdd(aCalc, {nBase, nIBS, nCBS, nBase + nIBS + nCBS})
    aRet[3] := aCalc

    // GFN2 receber vinculado a chave (se houver).
    If GEBDBTableExistsHere("GFN2")
        DbSelectArea("GFN2")
        DbGoTop()
        While !Eof()
            If GFN2->D_E_L_E_T_ == " "
                If GFN2->GFN2_DOC == cChvSan
                    AAdd(aReceber, {GFN2->GFN2_DOC, GFN2->GFN2_CLI, GFN2->GFN2_SALDO, GFN2->GFN2_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[4] := aReceber

    // Apuracao GF5 (competencia da NF).
    If GEBDBTableExistsHere("GF5")
        DbSelectArea("GF5")
        DbGoTop()
        While !Eof()
            If GF5->D_E_L_E_T_ == " "
                If SubStr(GF3->GF3_EMIS, 1, 6) == GF5->GF5_COMP
                    // Nota: em workarea, GF3 pode nao estar open -- usa a calculada.
                EndIf
                // Match por competencia a partir da data de emissao.
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
        // Busca por competencia extraida do header.
        If Len(aHeader) > 0
            cComp := SubStr(aHeader[1][7], 1, 6)
            DbSelectArea("GF5")
            DbGoTop()
            While !Eof()
                If GF5->D_E_L_E_T_ == " "
                    If GF5->GF5_COMP == cComp
                        AAdd(aApur, {GF5->GF5_COMP, GF5->GF5_DEB, GF5->GF5_CRED, GF5->GF5_SALDO, GF5->GF5_REGIME})
                    EndIf
                EndIf
                DbSkip()
            EndDo
            DbCloseArea()
        EndIf
    EndIf
    aRet[5] := aApur

    // Guia GD1 da competencia.
    If GEBDBTableExistsHere("GD1")
        If Len(aApur) > 0
            cCompGuia := aApur[1][1]
            DbSelectArea("GD1")
            DbGoTop()
            While !Eof()
                If GD1->D_E_L_E_T_ == " "
                    If GD1->GD1_COMP == cCompGuia
                        AAdd(aGuia, {GD1->GD1_GUIA, GD1->GD1_COMP, GD1->GD1_VALOR, GD1->GD1_TOTAL, GD1->GD1_STATUS})
                    EndIf
                EndIf
                DbSkip()
            EndDo
            DbCloseArea()
        EndIf
    EndIf
    aRet[6] := aGuia

    ConOut("TRAK_NOTA " + cChvSan + " header=" + cValToChar(Len(aHeader)))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/ GEBTRAKDERRAMA(cGuia)
   Retorna array {aApuracao, aGuia, aParcelas, aCobranca, aPagar, aBaixa, aLanc}
/*/
User Function GEBTRAKDERRAMA(cGuia)
    Local aMovX := {}
    Local nMovX := 0
    Local aArea := GetArea()
    Local aRet := {{}, {}, {}, {}, {}, {}, {}}
    Local aChk := {}
    Local aApur := {}
    Local aGuia := {}
    Local aParc := {}
    Local aCobra := {}
    Local aPagar := {}
    Local aBaixa := {}
    Local aLanc := {}
    Local cGuiaSan := ""
    Local cComp := ""
    Local nI := 0

    If cGuia == Nil
        cGuia := ""
    EndIf

    cGuiaSan := Trim(cGuia)

    // Apuracao origem GF5 (competencia da guia).
    If GEBDBTableExistsHere("GF5")
        DbSelectArea("GF5")
        DbGoTop()
        While !Eof()
            If GF5->D_E_L_E_T_ == " "
                // Extrai competencia do codigo da guia (GD + AAAAMM).
                If SubStr(cGuiaSan, 3, 6) == GF5->GF5_COMP
                    AAdd(aApur, {GF5->GF5_COMP, GF5->GF5_DEB, GF5->GF5_CRED, GF5->GF5_SALDO, GF5->GF5_REGIME})
                    cComp := GF5->GF5_COMP
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[1] := aApur

    // Guia GD1.
    If GEBDBTableExistsHere("GD1")
        DbSelectArea("GD1")
        DbGoTop()
        While !Eof()
            If GD1->D_E_L_E_T_ == " "
                If GD1->GD1_GUIA == cGuiaSan
                    AAdd(aGuia, {GD1->GD1_GUIA, GD1->GD1_COMP, GD1->GD1_VALOR, GD1->GD1_JUROS, GD1->GD1_MULTA, GD1->GD1_TOTAL, GD1->GD1_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[2] := aGuia

    // Parcelas GD2.
    If GEBDBTableExistsHere("GD2")
        DbSelectArea("GD2")
        DbGoTop()
        While !Eof()
            If GD2->D_E_L_E_T_ == " "
                If GD2->GD2_GUIA == cGuiaSan
                    AAdd(aParc, {GD2->GD2_GUIA, GD2->GD2_PARC, GD2->GD2_VALOR, GD2->GD2_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[3] := aParc

    // Cobranca GD3.
    If GEBDBTableExistsHere("GD3")
        DbSelectArea("GD3")
        DbGoTop()
        While !Eof()
            If GD3->D_E_L_E_T_ == " "
                If GD3->GD3_GUIA == cGuiaSan
                    AAdd(aCobra, {GD3->GD3_GUIA, GD3->GD3_ACAO, GD3->GD3_DATA, GD3->GD3_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[4] := aCobra

    // Titulo a pagar GFN3 (baixa via CTBLAN usa a guia como lote).
    If GEBDBTableExistsHere("GFN3")
        DbSelectArea("GFN3")
        DbGoTop()
        While !Eof()
            If GFN3->D_E_L_E_T_ == " "
                If GFN3->GFN3_DOC == cGuiaSan
                    AAdd(aPagar, {GFN3->GFN3_DOC, GFN3->GFN3_FORN, GFN3->GFN3_SALDO, GFN3->GFN3_STATUS})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[5] := aPagar

    // Baixa GFN4.
    If GEBDBTableExistsHere("GFN4")
        DbSelectArea("GFN4")
        DbGoTop()
        While !Eof()
            If GFN4->D_E_L_E_T_ == " "
                If GFN4->GFN4_CONTA == cGuiaSan
                    AAdd(aBaixa, {GFN4->GFN4_CONTA, GFN4->GFN4_TIPO, GFN4->GFN4_VALOR, GFN4->GFN4_DATA})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    // Pagamentos da guia pelo financeiro (GFX4: titulo da guia ou das parcelas).
    If GEBDBTableExistsHere("GFX4")
        aMovX := TCSqlQuery("SELECT GFX4_CONTA AS C, GFX4_DC AS DC, GFX4_VALOR AS V, GFX4_DATA AS D FROM GFX4 WHERE D_E_L_E_T_ = ' ' AND (GFX4_DOC = " + ;
            GEBDBQuote(cGuiaSan) + " OR GFX4_DOC LIKE " + GEBDBQuote(cGuiaSan + "/%") + ") ORDER BY GFX4_DATA")
        For nMovX := 1 To Len(aMovX)
            If AllTrim(cValToChar(aMovX[nMovX]:DC)) == "D"
                AAdd(aBaixa, {AllTrim(cValToChar(aMovX[nMovX]:C)), "PAG", Val(cValToChar(aMovX[nMovX]:V)), AllTrim(cValToChar(aMovX[nMovX]:D))})
            Else
                AAdd(aBaixa, {AllTrim(cValToChar(aMovX[nMovX]:C)), "REC", Val(cValToChar(aMovX[nMovX]:V)), AllTrim(cValToChar(aMovX[nMovX]:D))})
            EndIf
        Next nMovX
    EndIf
    aRet[6] := aBaixa

    // Lancamento contabil GC3.
    If GEBDBTableExistsHere("GC3")
        DbSelectArea("GC3")
        DbGoTop()
        While !Eof()
            If GC3->D_E_L_E_T_ == " "
                If GC3->GC3_LOTE == cGuiaSan
                    AAdd(aLanc, {GC3->GC3_LOTE, GC3->GC3_DC, GC3->GC3_CONTA, GC3->GC3_VALOR})
                EndIf
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf
    aRet[7] := aLanc

    ConOut("TRAK_DER " + cGuiaSan + " guia=" + cValToChar(Len(aGuia)))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet
