#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBDER_COB
    Cobranca da derrama GEBAN (Task 3 GEB_DERRAMA).
    Mapeamento 1 para 1 com as interfaces do plano (chamada sem
    prefixo U): U_GEBDJUR para GEBDJUR, U_GEBDPAR para GEBDPAR,
    U_GEBDPRO para GEBDPRO. O prefixo U nao e usado na chamada
    porque o runtime AdvPP so resolve U em StartJob-FindFunction;
    chamada direta U_X da unknown function.
    GEBDJUR(cGuia, nDias) aplica juros bananicos de 0.33 por cento
    ao dia com teto de 20 por cento mais multa fixa de 2 por cento
    sobre o VALOR de GD1; grava JUROS-MULTA-TOTAL e retorna o total.
    Retorna zero se guia vazia, dias nulos ou GD1 ausente-sem guia.
    GEBDPAR(cGuia, nParc) parcela o TOTAL (ou VALOR se TOTAL zerado)
    em nParc linhas GD2 com baixa logica previa das parcelas ativas
    da guia; PARC em 3 digitos; ultima parcela ajusta o residuo;
    no financeiro, o titulo da guia vira um titulo por parcela (30 em 30
    dias; GEBDERPARTIT) e os juros/multa ja somados ao total viram despesa;
    retorna .T. se parcelou, .F. se GD1-GD2 ausentes, guia vazia,
    nParc menor que 2, guia inexistente ou guia com pagamento.
    GEBDPRO(cGuia) grava GD3 com ACAO PROTESTO, DATA de hoje e
    STATUS ABERTA, e marca GD1 como PROTESTADA; retorna .T. se
    protestou, .F. se GD1-GD3 ausentes, guia vazia ou inexistente.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de Default;
    GetArea-RestArea guardados; leitura via workarea; guarda via
    TCSqlQuery em pg_tables; escrita via DbAppend mais RecLock(.T.);
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela, sem concat
    SQL, sem cFilial, sem IIF; so User-Static.
    @type Modulo de cobranca
    @author Peder Munksgaard
    @since 23-09-2026
    @param cGuia Codigo da guia em GD1
    @param nDias Dias de atraso para juros
    @param nParc Numero de parcelas em GD2
    @return Total com juros-multa (GEBDJUR); .T.-.F. (GEBDPAR-GBDPRO)
    @return .T.-.F. para GEBDPAR e GEBDPRO
/*/
User Function GEBDJUR(cGuia, nDias)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GD1")
    Local nValor := 0
    Local nJur := 0
    Local nTeto := 0
    Local nMul := 0
    Local nTot := 0
    Local lAchou := .F.

    If cGuia == Nil
        cGuia := ""
    EndIf
    If nDias == Nil
        nDias := 0
    EndIf
    If cGuia == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    If !GEBDBTableExistsHere("GD1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil .AND. GD1->GD1_GUIA == cGuia .AND. GD1->D_E_L_E_T_ == " "
            lAchou := .T.
            nValor := GD1->GD1_VALOR
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    nJur := nValor * 0.0033 * nDias
    nTeto := nValor * 0.20
    If nJur > nTeto
        nJur := nTeto
    EndIf
    nMul := nValor * 0.02
    nTot := nValor + nJur + nMul

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil .AND. GD1->GD1_GUIA == cGuia .AND. GD1->D_E_L_E_T_ == " "
            RecLock("GD1", .F.)
            GD1->GD1_JUROS := nJur
            GD1->GD1_MULTA := nMul
            GD1->GD1_TOTAL := nTot
            MsUnlock()
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    ConOut("JUR " + cGuia + " " + cValToChar(nTot))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return nTot

User Function GEBDPAR(cGuia, nParc)
    Local aArea := GetArea()
    Local cFil1 := FWxFilial("GD1")
    Local cFil2 := FWxFilial("GD2")
    Local nTot := 0
    Local nEach := 0
    Local nVal := 0
    Local nI := 0
    Local cParc := ""
    Local lAchou := .F.

    If cGuia == Nil
        cGuia := ""
    EndIf
    If nParc == Nil
        nParc := 0
    EndIf
    If cGuia == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nParc < 2
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GD1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GD2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil1 .AND. GD1->GD1_GUIA == cGuia .AND. GD1->D_E_L_E_T_ == " "
            lAchou := .T.
            nTot := GD1->GD1_TOTAL
            If nTot == 0
                nTot := GD1->GD1_VALOR
            EndIf
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    // Guia com pagamento (ou baixada) nao se parcela.
    If !GEBDERPODEPAR(cGuia)
        ConOut("PAR " + cGuia + " recusado: guia com pagamento")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GD2")
    DbGoTop()
    While !Eof()
        If GD2->GD2_FILIAL == cFil2 .AND. GD2->GD2_GUIA == cGuia .AND. GD2->D_E_L_E_T_ == " "
            RecLock("GD2", .F.)
            GD2->D_E_L_E_T_ := "*"
            MsUnlock()
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Parcelas ao centavo; a ultima absorve o residuo (100 em 3 = 33,33 +
    // 33,33 + 33,34). Sem o Round as parcelas eram gravadas arredondadas
    // pelo banco e a soma ficava 1 centavo abaixo do total.
    nEach := Round(nTot / nParc, 2)
    For nI := 1 To nParc
        nVal := nEach
        If nI == nParc
            nVal := nTot - nEach * (nParc - 1)
        EndIf
        If nI < 10
            cParc := "00" + cValToChar(nI)
        Else
            If nI < 100
                cParc := "0" + cValToChar(nI)
            Else
                cParc := cValToChar(nI)
            EndIf
        EndIf
        DbSelectArea("GD2")
        DbAppend()
        RecLock("GD2", .T.)
        GD2->GD2_FILIAL := cFil2
        GD2->D_E_L_E_T_ := " "
        GD2->GD2_GUIA := cGuia
        GD2->GD2_PARC := cParc
        GD2->GD2_VALOR := nVal
        GD2->GD2_STATUS := "ABERTA"
        MsUnlock()
        DbCloseArea()
    Next

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil1 .AND. GD1->GD1_GUIA == cGuia .AND. GD1->D_E_L_E_T_ == " "
            RecLock("GD1", .F.)
            GD1->GD1_STATUS := "PARCELADA"
            MsUnlock()
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Um titulo a pagar por parcela no financeiro (30 em 30 dias).
    GEBDERPARTIT(cGuia, nParc, nTot)
    ConOut("PAR " + cGuia + " " + cValToChar(nParc))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function GEBDPRO(cGuia)
    Local aArea := GetArea()
    Local cFil1 := FWxFilial("GD1")
    Local cFil3 := FWxFilial("GD3")
    Local lAchou := .F.

    If cGuia == Nil
        cGuia := ""
    EndIf
    If cGuia == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GD1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GD3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil1 .AND. GD1->GD1_GUIA == cGuia .AND. GD1->D_E_L_E_T_ == " "
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GD3")
    DbAppend()
    RecLock("GD3", .T.)
    GD3->GD3_FILIAL := cFil3
    GD3->D_E_L_E_T_ := " "
    GD3->GD3_GUIA := cGuia
    GD3->GD3_ACAO := "PROTESTO"
    GD3->GD3_DATA := DToS(Date())
    GD3->GD3_STATUS := "ABERTA"
    MsUnlock()
    DbCloseArea()

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil1 .AND. GD1->GD1_GUIA == cGuia .AND. GD1->D_E_L_E_T_ == " "
            RecLock("GD1", .F.)
            GD1->GD1_STATUS := "PROTESTADA"
            MsUnlock()
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    ConOut("PRO " + cGuia)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.
