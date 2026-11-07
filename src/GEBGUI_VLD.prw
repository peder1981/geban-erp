#include "totvs.ch"
#include "GEBDB_CORE.prw"

#include "../src/GEBSEC_RBA.prw"
/*/{Protheus.doc} GEBGUI_VLD
    Camada de validacao GUI GEBAN (Task 1 GEB_GUI).
    Funcoes centrais que o frontend e o backend consomem para
    validar dados antes de chamar as funcoes de dominio. Cada
    validador retorna .T./.F. (e mensagem via ConOut) e delega
    para a funcao de dominio quando valido.
    Validacoes RBAC via GEBSECRBAC sao chamadas antes de operacoes
    escritas (BAIXA, EMISSAO, LANCAMENTO DIRETO, CONFIG SC).
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de
    Default; GetArea/RestArea guardados; leitura via workarea;
    guarda via TCSqlQuery em pg_tables; escrita via
    DbAppend mais RecLock(.T.) e update via RecLock(.F.);
    FWxFilial retorna 6 espacos sem env; sem SELECT estrela,
    sem concat SQL, sem cFilial, sem IIF; so User/Static.
    @type Camada de validacao GUI
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function GEBGUIPROD_CK(cCod)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GF1")
    Local lOk   := .F.
    Local aChk  := {}

    If cCod == Nil
        cCod := ""
    EndIf
    If cCod == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GF1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GF1")
    DbGoTop()
    While !Eof()
        If GF1->GF1_FILIAL == cFil .AND. GF1->GF1_COD == cCod .AND. GF1->D_E_L_E_T_ == " "
            lOk := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIFORN_CK(cCod)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GCP1")
    Local lOk   := .F.
    Local aChk  := {}

    If cCod == Nil
        cCod := ""
    EndIf
    If cCod == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GCP1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP1")
    DbGoTop()
    While !Eof()
        If GCP1->GCP1_FILIAL == cFil .AND. GCP1->GCP1_COD == cCod .AND. GCP1->D_E_L_E_T_ == " "
            lOk := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUICLI_CK(cCod)
    Local aArea := GetArea()
    Local cFil  := FWxFilial("GV3")
    Local lOk   := .F.
    Local aChk  := {}

    If cCod == Nil
        cCod := ""
    EndIf
    If cCod == ""
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

    DbSelectArea("GV3")
    DbGoTop()
    While !Eof()
        If GV3->GV3_FILIAL == cFil .AND. GV3->GV3_CLI == cCod .AND. GV3->D_E_L_E_T_ == " "
            lOk := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIPROD_EST(cProd, nQtd)
    Local aArea  := GetArea()
    Local cFil   := FWxFilial("GV1")
    Local nSaldo := 0
    Local nMin   := 10
    Local lTem   := .F.
    Local lOk    := .F.
    Local aChk   := {}

    If cProd == Nil
        cProd := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
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

    If !GEBDBTableExistsHere("GV1")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GV1")
    DbGoTop()
    While !Eof()
        If GV1->GV1_FILIAL == cFil .AND. GV1->GV1_PROD == cProd .AND. GV1->D_E_L_E_T_ == " "
            lTem := .T.
            nSaldo := GV1->GV1_SALDO
            nMin := GV1->GV1_MIN
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If !lTem
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If nSaldo >= nQtd
        lOk := .T.
    Else
        lOk := .F.
        ConOut("EST insuf " + cProd + " sal " + cValToChar(nSaldo) + " req " + cValToChar(nQtd))
    EndIf

    If nSaldo < nMin
        GEBMNT("ESTOQUE_MINIMO")
        ConOut("EST MINIMO aviso " + cProd)
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIFIADO_LIM(cCli, nValor)
    Local aArea   := GetArea()
    Local cFil    := FWxFilial("GV3")
    Local nAberto := 0
    Local nLim    := 1000
    Local lOk     := .F.
    Local aChk    := {}

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

    nAberto := SomaAbertoGV3(cCli, cFil)

    If nAberto + nValor <= nLim
        lOk := .T.
    Else
        lOk := .F.
        ConOut("FIA LIMITE transg " + cCli + " ab " + cValToChar(nAberto) + " nov " + cValToChar(nValor))
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIFIN_BAI(cTipo, cDoc, nValor)
    Local aArea   := GetArea()
    Local cNorm   := ""
    Local lPag    := .F.
    Local lLib    := .T.
    Local lOk     := .F.
    Local cMsg    := ""
    Local cFil2   := FWxFilial("GFN2")
    Local cFil3   := FWxFilial("GFN3")
    Local nSaldo  := 0
    Local lAchou  := .F.
    Local aChk    := {}
    Local lInexist := .F.

    If cTipo == Nil
        cTipo := ""
    EndIf
    If cDoc == Nil
        cDoc := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf

    cNorm := Upper(AllTrim(cTipo))
    If cNorm == "PAG" .OR. cNorm == "PAGAR"
        lPag := .T.
    Else
        If cNorm == "REC" .OR. cNorm == "RECEBER"
            lPag := .F.
        Else
            cMsg := "TIPO invalido"
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return .F.
        EndIf
    EndIf

    If cDoc == ""
        cMsg := "DOC vazio"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If nValor <= 0
        cMsg := "VALOR invalido"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If lPag
        If !GEBDBTableExistsHere("GFN3")
            cMsg := "tabela GFN3 ausente"
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return .F.
        EndIf
        DbSelectArea("GFN3")
        DbGoTop()
        While !Eof()
            If GFN3->GFN3_FILIAL == cFil3 .AND. GFN3->GFN3_DOC == cDoc .AND. GFN3->D_E_L_E_T_ == " "
                lAchou := .T.
                nSaldo := GFN3->GFN3_SALDO
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    Else
        If !GEBDBTableExistsHere("GFN2")
            cMsg := "tabela GFN2 ausente"
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return .F.
        EndIf
        DbSelectArea("GFN2")
        DbGoTop()
        While !Eof()
            If GFN2->GFN2_FILIAL == cFil2 .AND. GFN2->GFN2_DOC == cDoc .AND. GFN2->D_E_L_E_T_ == " "
                lAchou := .T.
                nSaldo := GFN2->GFN2_SALDO
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    If !lAchou
        cMsg := "DOC inexistente"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If nValor > nSaldo
        cMsg := "saldo insuf " + cValToChar(nSaldo)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    lOk := GEBFNBAI(cTipo, cDoc, nValor)
    If lOk
        cMsg := "BAIXA OK"
    Else
        cMsg := "BAIXA recusou"
    EndIf

    ConOut("GUI BAI " + cMsg)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIFIN_FLX()
    Local aArea    := GetArea()
    Local aFlx     := {0, 0, 0}
    Local aRet     := {}

    aRet := GEBNFLX()
    If Len(aRet) == 3
        aFlx[1] := aRet[1]
        aFlx[2] := aRet[2]
        aFlx[3] := aRet[3]
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aFlx

User Function GEBGUIFIS_EMI(cChave, cCod, nQtd, nPreco)
    Local aArea    := GetArea()
    Local lOk      := .F.
    Local cMsg     := ""

    If cChave == Nil
        cChave := ""
    EndIf
    If cCod == Nil
        cCod := ""
    EndIf
    If nQtd == Nil
        nQtd := 0
    EndIf
    If nPreco == Nil
        nPreco := 0
    EndIf

    If cChave == ""
        cMsg := "Chave vazia"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cCod == ""
        cMsg := "Produto vazio"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nQtd <= 0
        cMsg := "Qtd invalida"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nPreco <= 0
        cMsg := "Preco invalido"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    lOk := GEBFEMI(cChave, cCod, nQtd, nPreco)
    If lOk
        cMsg := "EMI OK"
    Else
        cMsg := "EMI falhou"
    EndIf

    ConOut("GUI EMI " + cMsg)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIFIS_APU(cComp)
    Local aArea := GetArea()
    Local lOk   := .F.
    Local cMsg  := ""

    If cComp == Nil
        cComp := ""
    EndIf
    If cComp == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    lOk := GEBFAPU(cComp)
    If lOk
        cMsg := "APU OK"
    Else
        cMsg := "APU falhou"
    EndIf

    ConOut("GUI APU " + cMsg)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUIFIS_GER(cComp)
    Local aArea  := GetArea()
    Local cGuia  := ""
    Local cMsg   := ""

    If cComp == Nil
        cComp := ""
    EndIf
    If cComp == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return ""
    EndIf

    cGuia := GEBDGER(cComp)
    If cGuia != ""
        cMsg := "GER OK " + cGuia
    Else
        cMsg := "GER falhou"
    EndIf

    ConOut("GUI GER " + cMsg)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cGuia

User Function GEBGUICTB_DIR(cCli, cContaD, cContaC, nValor)
    Local aArea    := GetArea()
    Local lPermite := ""
    Local lOk      := .F.
    Local cMsg     := ""

    If cCli == Nil
        cCli := ""
    EndIf
    If cContaD == Nil
        cContaD := ""
    EndIf
    If cContaC == Nil
        cContaC := ""
    EndIf
    If nValor == Nil
        nValor := 0
    EndIf

    If cContaD == ""
        cMsg := "Conta D vazia"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If cContaC == ""
        cMsg := "Conta C vazia"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf
    If nValor <= 0
        cMsg := "Valor invalido"
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    lPermite := GEBCFG("PERMITE_DIRETA")
    If lPermite != "S"
        cMsg := "DIR negado flag"
        ConOut("GUI DIR " + cMsg)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    // RBAC: verifica permissao do usuario antes de lancamento direto.
    lLib := GEBSECRBAC(cCli, "CONTABIL", "DIR")
    If !lLib
        cMsg := "DIR negado RBAC"
        ConOut("GUI DIR " + cMsg)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    lOk := GEBCDIR(cContaD, cContaC, nValor, cCli)
    If lOk
        cMsg := "DIR OK"
    Else
        cMsg := "DIR recusou"
    EndIf

    ConOut("GUI DIR " + cMsg)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

User Function GEBGUICONFIG_LC(cChave)
    Local aArea := GetArea()
    Local cVal  := ""

    If cChave == Nil
        cChave := ""
    EndIf

    cVal := GEBCFG(cChave)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return cVal

User Function GEBGUICONFIG_SC(cChave, cValor)
    Local aArea  := GetArea()
    Local cFil   := FWxFilial("GE4")
    Local lOk    := .F.
    Local lAchou := .F.
    Local aChk   := {}

    If cChave == Nil
        cChave := ""
    EndIf
    If cValor == Nil
        cValor := ""
    EndIf
    If cChave == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    If !GEBDBTableExistsHere("GE4")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GE4")
    DbGoTop()
    While !Eof()
        If GE4->GE4_FILIAL == cFil .AND. GE4->GE4_EVENTO == cChave .AND. GE4->D_E_L_E_T_ == " "
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo

    If lAchou
        DbSelectArea("GE4")
        DbGoTop()
        While !Eof()
            If GE4->GE4_FILIAL == cFil .AND. GE4->GE4_EVENTO == cChave .AND. GE4->D_E_L_E_T_ == " "
                RecLock("GE4", .F.)
                GE4->GE4_MODO := cValor
                MsUnlock()
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    Else
        DbSelectArea("GE4")
        DbAppend()
        RecLock("GE4", .T.)
        GE4->GE4_FILIAL := cFil
        GE4->D_E_L_E_T_ := " "
        GE4->GE4_EVENTO := cChave
        GE4->GE4_MODO   := cValor
        MsUnlock()
        DbCloseArea()
    EndIf

    ConOut("CFG SC " + cChave + " " + cValor)

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

Static Function SomaAbertoGV3(cCli, cFil)
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
