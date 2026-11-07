#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*{Protheus.doc} GEBCOM_PED
    Pedido de compra guiado GEBAN (Task 3 GEB_COM).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBCMPED -> GEBCMPED | U_GEBCMIT -> GEBCMIT.
    O prefixo U_ nao e usado nas chamadas porque o runtime AdvPP so
    resolve U_ em StartJob/FindFunction; chamada direta U_X() da
    "unknown function".
    GEBCMPED(cPed, cForn) cria o header em GCP3 com STATUS ABERTO
    via DbAppend() + RecLock(.T.) apos a guia do mentor
    GEBMNT("COMPRA_IMPULSIVA") (travado retorna BLOQUEADO sem tocar
    o banco); idempotente (pedido existente retorna ABERTO sem
    duplicar); vazio retorna BLOQUEADO; GCP3 ausente retorna
    BLOQUEADO.
    GEBCMIT(cPed, cProd, nQtd, nPreco) grava o item em GCP4 via
    DbAppend() + RecLock(.T.); .F. se ped/prod vazio, qtd/preco
    menor ou igual a zero, GCP4 ausente ou pedido inexistente em GCP3.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita nova via
    DbAppend mais RecLock ponto T e update via RecLock ponto F;
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela, sem
    concat SQL, sem cFilial, sem IIF; so User/Static.
    @type Modulo de pedido
    @author Peder Munksgaard
    @since 23/09/2026
    @param cPed Numero do pedido em GCP3/GCP4 (GEBCMPED/GEBCMIT)
    @param cForn Fornecedor do pedido em GCP3 (GEBCMPED)
    @param cProd Produto do item em GCP4 (GEBCMIT)
    @param nQtd Quantidade do item em GCP4 (GEBCMIT)
    @param nPreco Preco unitario do item em GCP4 (GEBCMIT)
    @return ABERTO/BLOQUEADO (GEBCMPED), .T./.F. (GEBCMIT)
/*/
User Function GEBCMPED(cPed, cForn)
    Local aArea := GetArea()
    Local cFil := FWxFilial("GCP3")
    Local lLib := .T.
    Local lAchou := .F.

    If cPed == Nil
        cPed := ""
    EndIf
    If cForn == Nil
        cForn := ""
    EndIf
    If cPed == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "BLOQUEADO"
    EndIf
    If cForn == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "BLOQUEADO"
    EndIf

    If !GEBDBTableExistsHere("GCP3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "BLOQUEADO"
    EndIf

    lLib := GEBMNT("COMPRA_IMPULSIVA")
    If !lLib
        ConOut("PED bloqueado " + cPed)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "BLOQUEADO"
    EndIf

    DbSelectArea("GCP3")
    DbGoTop()
    While !Eof()
        If GCP3->GCP3_FILIAL == cFil .AND. GCP3->GCP3_NUM == cPed .AND. GCP3->D_E_L_E_T_ == " "
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If lAchou
        ConOut("PED existe " + cPed)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return "ABERTO"
    EndIf

    DbSelectArea("GCP3")
    DbAppend()
    RecLock("GCP3", .T.)
    GCP3->GCP3_FILIAL := cFil
    GCP3->D_E_L_E_T_ := " "
    GCP3->GCP3_NUM := cPed
    GCP3->GCP3_FORN := cForn
    GCP3->GCP3_STATUS := "ABERTO"
    MsUnlock()
    DbCloseArea()

    ConOut("PED ABERTO " + cPed)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return "ABERTO"

User Function GEBCMIT(cPed, cProd, nQtd, nPreco)
    Local aArea := GetArea()
    Local cFil4 := FWxFilial("GCP4")
    Local cFil3 := FWxFilial("GCP3")
    Local lPed := .F.

    If cPed == Nil
        cPed := ""
    EndIf
    If cProd == Nil
        cProd := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
    EndIf
    If nPreco == Nil
        nPreco := 0
    EndIf
    If cPed == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cProd == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nQtd <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nPreco <= 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GCP4")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If !GEBDBTableExistsHere("GCP3")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP3")
    DbGoTop()
    While !Eof()
        If GCP3->GCP3_FILIAL == cFil3 .AND. GCP3->GCP3_NUM == cPed .AND. GCP3->D_E_L_E_T_ == " "
            lPed := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lPed
        ConOut("ITEM sem pedido " + cPed)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP4")
    DbAppend()
    RecLock("GCP4", .T.)
    GCP4->GCP4_FILIAL := cFil4
    GCP4->D_E_L_E_T_ := " "
    GCP4->GCP4_PED := cPed
    GCP4->GCP4_PROD := cProd
    GCP4->GCP4_QTD := nQtd
    GCP4->GCP4_PRECO := nPreco
    MsUnlock()
    DbCloseArea()

    ConOut("ITEM " + cPed + " " + cProd)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.
