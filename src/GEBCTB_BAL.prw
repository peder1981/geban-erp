#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBCTB_BAL
    Balancete e DRE da contabilidade GEBAN (Task 4 GEB_CONTABIL).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem
    prefixo U_): U_GEBBAL -> GEBBAL | U_GEBDRE -> GEBDRE.
    O prefixo U_ nao e usado na chamada porque o runtime AdvPP so
    resolve U_ em StartJob/FindFunction; chamada direta U_X() da
    "unknown function".
    GEBBAL(cComp) soma as pernas de GC3 dos lotes de GC2 com
    GC2_COMP igual a cComp (AAAAMM) e retorna array de
    {cConta, nDebito, nCredito}, uma linha por conta. Competencia
    vazia ou contabil ausente retorna array vazio.
    GEBDRE(cComp) e a DRE bananica: receitas (grupo 3, credito
    menos debito) menos despesas e custos (grupo 4, debito menos
    credito); retorna o resultado numerico (zero se vazio).
    Notas AdvPP (balisador, ver registro interno):
    log via ConOut (FWLogMsg nao existe no runtime); If Nil em vez
    de Default (Default sobrescreve incondicionalmente); alias
    literal (GetNextAlias nao existe); GetArea/RestArea guardados
    (GetArea retorna "" sem workarea aberta; RestArea("") aborta);
    leitura via workarea porque BeginSql standalone e no-op no
    pre-processador; guarda de existencia via TCSqlQuery em
    pg_tables (Select() e Used() sao stubs); SQL so com
    literais (sem concat, sem SELECT estrela); sem cFilial, sem
    IIF; so User/Static Function.
    @type Modulo de balancete e DRE
    @author Peder Munksgaard
    @since 23/09/2026
    @param cComp Competencia AAAAMM em GC2_COMP
    @return Array do balancete (GEBBAL) ou resultado (GEBDRE)
/*/
User Function GEBBAL(cComp)
    Local aArea := GetArea()
    Local cFil2 := FWxFilial("GC2")
    Local cFil3 := FWxFilial("GC3")
    Local aBal := {}
    Local aLotes := {}
    Local nPos := 0
    Local nI := 0
    Local lTem := .F.

    If cComp == Nil
        cComp := ""
    EndIf

    // Guardas: GC2/GC3 podem nao existir (GEBCMIG ainda nao rodou).
    If !GEBDBTableExistsHere("GC2")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aBal
    EndIf
    If !GEBDBTableExistsHere("GC3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return aBal
    EndIf

    // Lotes ativos da competencia.
    DbSelectArea("GC2")
    DbGoTop()
    While !Eof()
        If GC2->GC2_FILIAL == cFil2 .AND. GC2->GC2_COMP == cComp .AND. GC2->D_E_L_E_T_ == " "
            aAdd(aLotes, GC2->GC2_LOTE)
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Pernas das contas nos lotes da competencia.
    DbSelectArea("GC3")
    DbGoTop()
    While !Eof()
        If GC3->GC3_FILIAL == cFil3 .AND. GC3->D_E_L_E_T_ == " "
            lTem := .F.
            For nI := 1 To Len(aLotes)
                If GC3->GC3_LOTE == aLotes[nI]
                    lTem := .T.
                    Exit
                EndIf
            Next
            If lTem
                nPos := PosConta(aBal, GC3->GC3_CONTA)
                If nPos == 0
                    aAdd(aBal, {GC3->GC3_CONTA, 0, 0})
                    nPos := Len(aBal)
                EndIf
                If GC3->GC3_DC == "D"
                    aBal[nPos][2] := aBal[nPos][2] + GC3->GC3_VALOR
                EndIf
                If GC3->GC3_DC == "C"
                    aBal[nPos][3] := aBal[nPos][3] + GC3->GC3_VALOR
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    ConOut("BAL " + cComp + " " + cValToChar(Len(aBal)))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aBal

User Function GEBDRE(cComp)
    Local aBal := {}
    Local nRec := 0
    Local nDes := 0
    Local nI := 0
    Local cGru := ""

    If cComp == Nil
        cComp := ""
    EndIf

    aBal := GEBBAL(cComp)
    For nI := 1 To Len(aBal)
        cGru := Left(aBal[nI][1], 1)
        If cGru == "3"
            nRec := nRec + aBal[nI][3] - aBal[nI][2]
        EndIf
        If cGru == "4"
            nDes := nDes + aBal[nI][2] - aBal[nI][3]
        EndIf
    Next

    ConOut("DRE " + cComp + " " + cValToChar(nRec - nDes))
Return (nRec - nDes)

Static Function PosConta(aBal, cConta)
    Local nI := 0

    For nI := 1 To Len(aBal)
        If aBal[nI][1] == cConta
            Return nI
        EndIf
    Next
Return 0
