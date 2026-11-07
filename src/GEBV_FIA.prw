#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBV_FIA
    Fiado com limite e juros GEBAN (Task 4 GEB_ESTOQ_VENDA).
    Mapeamento 1 para 1 com as interfaces do plano (chamada sem
    prefixo U): U_GEBVFIA para GEBVFIA, U_GEBVJUR para GEBVJUR.
    O prefixo U nao e usado na chamada porque o runtime AdvPP
    so resolve U em StartJob-FindFunction; chamada direta U_X
    da unknown function.
    GEBVFIA(cCli, nValor) abre fiado em GV3 com STATUS ABERTA
    se a soma dos em aberto do cliente mais nValor couber no
    limite 1000; acima do limite retorna .F. sem gravar. O fiado
    vira titulo a receber FIA-<registro> (vencimento em LOJ_FIADO_DIAS
    dias) com a receita; o recebimento do titulo quita a linha GV3.
    Retorna .F. se cliente vazio, valor menor ou igual a zero
    ou GV3 ausente. GEBVJUR(cCli, nDias) aplica juros bananicos
    de 0.33 por cento ao dia com teto de 20 por cento mais multa
    fixa de 2 por cento sobre o VALOR de cada linha ABERTA do
    cliente; grava JUROS-MULTA-TOTAL e retorna a soma dos totais
    (0 se cliente vazio ou sem linha em aberto).
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea-RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita via
    DbAppend mais RecLock ponto T e update via RecLock ponto F;
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela,
    sem concat SQL, sem cFilial, sem IIF; so User-Static.
    @type Modulo de fiado
    @author Peder Munksgaard
    @since 23-09-2026
    @param cCli Codigo do cliente em GV3
    @param nValor Valor do fiado novo (GEBVFIA)
    @param nDias Dias de atraso para juros (GEBVJUR)
    @return .T. se abriu, .F. se bloqueado (GEBVFIA); soma dos totais (GEBVJUR)
/*/
User Function GEBVFIA(cCli, nValor)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GV3")
    Local nAberto := 0
    Local nLim := 1000
    Local aHit := {}
    Local cRec := ""

    If cCli == Nil
        cCli := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf
    If cCli == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nValor <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GV3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    nAberto := SomaAberto(cCli, cFil)
    If nAberto + nValor > nLim
        ConOut("FIA LIMITE " + cCli)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GV3")
    DbAppend()
    RecLock("GV3", .T.)
    GV3->GV3_FILIAL := cFil
    GV3->D_E_L_E_T_ := " "
    GV3->GV3_CLI := cCli
    GV3->GV3_VALOR := nValor
    GV3->GV3_JUROS := 0
    GV3->GV3_MULTA := 0
    GV3->GV3_TOTAL := nValor
    GV3->GV3_STATUS := "ABERTA"
    MsUnlock()
    DbCloseArea()

    // Fiado no contas a receber: titulo FIA-<registro> com vencimento em
    // LOJ_FIADO_DIAS dias e a receita (VENDA_RECEITA). O recebimento do
    // titulo quita a linha GV3.
    // ponytail: o registro e' o maior do cliente; vale enquanto a gravacao for serial.
    aHit := TCSqlQuery("SELECT MAX(R_E_C_N_O_) AS R FROM GV3 WHERE GV3_FILIAL = " + GEBDBQuote(cFil) + " AND GV3_CLI = " + GEBDBQuote(cCli))
    cRec := cValToChar(BOVAL(aHit[1]:R))
    If GEBFXTIT("R", "FIA-" + cRec, cCli, nValor, BOPARM("LOJ_FIADO_DIAS", "30"), BOHOJE(), "FIADO GV3:" + cRec, "")[1]
        GEBCTXLP("VENDA_RECEITA", nValor, "FIA-" + cRec, BOHOJE())
    EndIf

    ConOut("FIA " + cCli)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function GEBVJUR(cCli, nDias)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GV3")
    Local nSoma := 0
    Local nValor := 0
    Local nJur := 0
    Local nTeto := 0
    Local nMul := 0
    Local nTot := 0

    If cCli == Nil
        cCli := ""
    EndIf
    If nDias == Nil
        nDias := 0
    EndIf
    If cCli == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    If !GEBDBTableExistsHere("GV3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return 0
    EndIf

    DbSelectArea("GV3")
    DbGoTop()
    While !Eof()
        If GV3->GV3_FILIAL == cFil .AND. GV3->GV3_CLI == cCli .AND. GV3->GV3_STATUS == "ABERTA" .AND. GV3->D_E_L_E_T_ == " "
            nValor := GV3->GV3_VALOR
            nJur := nValor * 0.0033 * nDias
            nTeto := nValor * 0.20
            If nJur > nTeto
                nJur := nTeto
            EndIf
            nMul := nValor * 0.02
            nTot := nValor + nJur + nMul
            RecLock("GV3", .F.)
            GV3->GV3_JUROS := nJur
            GV3->GV3_MULTA := nMul
            GV3->GV3_TOTAL := nTot
            MsUnlock()
            nSoma := nSoma + nTot
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    ConOut("JUR FIA " + cCli)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return nSoma

Static Function SomaAberto(cCli, cFil)
    Local nTot := 0
    Local nLin := 0

    DbSelectArea("GV3")
    DbGoTop()
    While !Eof()
        If GV3->GV3_FILIAL == cFil .AND. GV3->GV3_CLI == cCli .AND. GV3->GV3_STATUS == "ABERTA" .AND. GV3->D_E_L_E_T_ == " "
            nLin := GV3->GV3_TOTAL
            If nLin == 0
                nLin := GV3->GV3_VALOR
            EndIf
            nTot := nTot + nLin
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
Return nTot
