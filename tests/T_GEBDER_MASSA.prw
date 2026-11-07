#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBTEF.prw"
#include "../src/GEBLOJ.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_WS.prw"
#include "../src/GEBDFE_MUN.prw"
#include "../src/GEBDFE_IE.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_QR.prw"
#include "../src/GEBDFE_DANFE.prw"
#include "../src/GEBLOJ_CAD.prw"
#include "../src/GEBLOJ_OPE.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBDER_MASSA
    Teste de massa derrama 50 guias (Task 5 GEB_DERRAMA).
    Chamada sem prefixo U e include relativo: exigencia do
    runtime AdvPP.
    Asserts: migracoes OK; pre-cleanup D50; loop 50 comps D50-1
    ate D50-50 via workarea (saldo 100 mais indice); GEBDGER mais
    GEBDJUR 5 dias mais GEBDBAI em cada guia; conta 50 GD1 ativas
    BAIXADA via workarea; regressao nucleo-fiscal GENMIG mais
    GEBFMIG .T.; pos-cleanup conta zero; rerun limpo. So literais
    em TCSqlQuery; escrita massa via workarea; ConOut PASS-FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBDER_MASSA()
    Local lOk := .T.
    Local nI := 0
    Local cComp := ""
    Local cGuia := ""
    Local nTot := 0
    Local cFil := ""
    Local nCount := 0
    Local nBx := 0

    If !GEBDBConecta()
        ConOut("T_GEBDER_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebder_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebder_massa")
    TCSqlExec("SET search_path TO test_gebder_massa")

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf

    LimpaMassa()

    For nI := 1 To 50
        cComp := "D50-" + cValToChar(nI)
        GrvMassa(cComp, 100 + nI)
        cGuia := GEBDGER(cComp)
        If cGuia == ""
            ConOut("  FAIL: GEBDGER " + cComp)
            lOk := .F.
        EndIf
        nTot := GEBDJUR(cGuia, 5)
        If !(nTot > 100)
            ConOut("  FAIL: GEBDJUR " + cGuia)
            lOk := .F.
        EndIf
        If !GEBDBAI(cGuia)
            ConOut("  FAIL: GEBDBAI " + cGuia)
            lOk := .F.
        EndIf
    Next

    cFil := FWxFilial("GD1")
    nCount := 0
    nBx := 0
    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil .AND. GD1->D_E_L_E_T_ == " "
            If SubStr(GD1->GD1_COMP, 1, 4) == "D50-"
                nCount := nCount + 1
                If GD1->GD1_STATUS == "BAIXADA"
                    nBx := nBx + 1
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !(nCount == 50) .Or. !(nBx == 50)
        ConOut("  FAIL: guias=" + cValToChar(nCount) + " baixadas=" + cValToChar(nBx) + " (esperado 50/50)")
        lOk := .F.
    EndIf

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf

    LimpaMassa()

    nCount := 0
    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil .AND. GD1->D_E_L_E_T_ == " "
            If SubStr(GD1->GD1_COMP, 1, 4) == "D50-"
                nCount := nCount + 1
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !(nCount == 0)
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebder_massa CASCADE")

    If lOk
        ConOut("T_GEBDER_MASSA PASS")
    Else
        ConOut("T_GEBDER_MASSA FAIL")
    EndIf
Return lOk

Static Function GrvMassa(cComp, nSaldo)
    Local cFil := FWxFilial("GF5")

    DbSelectArea("GF5")
    DbAppend()
    RecLock("GF5", .T.)
    GF5->GF5_FILIAL := cFil
    GF5->D_E_L_E_T_ := " "
    GF5->GF5_COMP := cComp
    GF5->GF5_DEB := nSaldo
    GF5->GF5_CRED := 0
    GF5->GF5_SALDO := nSaldo
    GF5->GF5_REGIME := "REGULAR"
    MsUnlock()
    DbCloseArea()
Return .T.

Static Function LimpaMassa()
    Local cFil1 := FWxFilial("GD1")
    Local cFil2 := FWxFilial("GD2")
    Local cFil3 := FWxFilial("GD3")
    Local cFil5 := FWxFilial("GF5")

    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil1 .AND. GD1->D_E_L_E_T_ == " "
            If SubStr(GD1->GD1_COMP, 1, 4) == "D50-"
                RecLock("GD1", .F.)
                GD1->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GD2")
    DbGoTop()
    While !Eof()
        If GD2->GD2_FILIAL == cFil2 .AND. GD2->D_E_L_E_T_ == " "
            If SubStr(GD2->GD2_GUIA, 1, 6) == "GDD50-"
                RecLock("GD2", .F.)
                GD2->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GD3")
    DbGoTop()
    While !Eof()
        If GD3->GD3_FILIAL == cFil3 .AND. GD3->D_E_L_E_T_ == " "
            If SubStr(GD3->GD3_GUIA, 1, 6) == "GDD50-"
                RecLock("GD3", .F.)
                GD3->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    DbSelectArea("GF5")
    DbGoTop()
    While !Eof()
        If GF5->GF5_FILIAL == cFil5 .AND. GF5->D_E_L_E_T_ == " "
            If SubStr(GF5->GF5_COMP, 1, 4) == "D50-"
                RecLock("GF5", .F.)
                GF5->D_E_L_E_T_ := "*"
                MsUnlock()
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
Return .T.
