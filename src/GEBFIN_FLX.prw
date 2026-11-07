#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBFIN_FLX
    Fluxo de caixa GEBAN (Task 4 GEB_FIN).
    Mapeamento 1:1 com a interface do plano (chamada sem prefixo U_):
    U_GEBNFLX -> GEBNFLX. O prefixo U_ nao e usado na chamada
    porque o runtime AdvPP so resolve U_ em StartJob/FindFunction;
    chamada direta U_X() da "unknown function".
    GEBNFLX() retorna {nReceber, nPagar, nSaldo}: soma dos SALDOS
    com STATUS ABERTO em GFN2 (receber) e GFN3 (pagar) via
    workarea com filtros FILIAL + D_E_L_E_T_; nSaldo e receber
    menos pagar. Tabelas ausentes valem zero (guarda via
    TCSqlQuery em pg_tables antes de DbSelectArea, que
    aborta em tabela inexistente). Titulos quitados (RECEBIDA/
    PAGA) nao entram na soma.
    Notas AdvPP (balisador): log via ConOut; GetArea/RestArea
    guardados; leitura via workarea; FWxFilial retorna 6 espacos
    sem env; sem SELECT estrela, sem concat SQL, sem cFilial,
    sem IIF; so User/Static.
    @type Modulo de fluxo
    @author Peder Munksgaard
    @since 23/09/2026
    @return Array {nReceber, nPagar, nSaldo}
/*/
User Function GEBNFLX()
    Local aArea := GetArea()
    Local cFil2 := FWxFilial("GFN2")
    Local cFil3 := FWxFilial("GFN3")
    Local nRec := 0
    Local nPag := 0

    If GEBDBTableExistsHere("GFN2")
        DbSelectArea("GFN2")
        DbGoTop()
        While !Eof()
            If GFN2->GFN2_FILIAL == cFil2 .AND. GFN2->GFN2_STATUS == "ABERTO" .AND. GFN2->D_E_L_E_T_ == " "
                nRec := nRec + GFN2->GFN2_SALDO
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    If GEBDBTableExistsHere("GFN3")
        DbSelectArea("GFN3")
        DbGoTop()
        While !Eof()
            If GFN3->GFN3_FILIAL == cFil3 .AND. GFN3->GFN3_STATUS == "ABERTO" .AND. GFN3->D_E_L_E_T_ == " "
                nPag := nPag + GFN3->GFN3_SALDO
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    ConOut("FLX " + cValToChar(nRec) + " " + cValToChar(nPag))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {nRec, nPag, nRec - nPag}
