#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
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

/*/{Protheus.doc} T_GEBFIN_MASSA
    Teste de massa financeira 100 titulos (Task 5 GEB_FIN).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP.
    Asserts: GENMIG()+GEBFNMIG() OK; pre-cleanup LIKE REC-M5-%
    e PAG-M5-% (rerun limpo); conta CAIXA criada; loop 50x
    GEBFNREC de 100 + 50x GEBFNPAG de 50 (100 titulos); count
    50 receber + 50 pagar; GEBNFLX {5000, 2500, 2500}; baixa
    total dos 100; GEBNFLX {0, 0, 0}; GFN1 CAIXA 2500
    (5000 menos 2500); GFX4 CAIXA com 100 movimentos (baixa pelo financeiro); cleanup
    via DELETE (rerun limpo). So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se massa 100 passar, .F. caso contrario
/*/
User Function T_GEBFIN_MASSA()
    Local lOk := .T.
    Local lTmp := .F.
    Local nI := 0
    Local cDoc := ""
    Local aHit := {}
    Local aFlx := {}
    Local cFil1 := ""
    Local lAchou := .F.
    Local nCaixa := 0

    If !GEBDBConecta()
        ConOut("T_GEBFIN_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfin_massa")
    TCSqlExec("SET search_path TO test_gebfin_massa")

    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC LIKE 'REC-M5-%'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'PAG-M5-%'")
    TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    If GEBDBTableExistsHere("GFX4")
        TCSqlExec("DELETE FROM GFX4 WHERE GFX4_CONTA = 'CAIXA'")
    EndIf
    TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")

    If !GEBFNCON("CAIXA", "Caixa M5")
        lOk := .F.
    EndIf

    For nI := 1 To 50
        cDoc := "REC-M5-" + cValToChar(nI)
        If !GEBFNREC(cDoc, "CLI-M5", 100, "20261231")
            lOk := .F.
        EndIf
    Next
    For nI := 1 To 50
        cDoc := "PAG-M5-" + cValToChar(nI)
        If !GEBFNPAG(cDoc, "FORN-M5", 50, "20261231")
            lOk := .F.
        EndIf
    Next

    aHit := TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_DOC LIKE 'REC-M5-%' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 50)
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_DOC LIKE 'PAG-M5-%' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 50)
        lOk := .F.
    EndIf

    aFlx := GEBNFLX()
    If !(aFlx[1] == 5000)
        lOk := .F.
    EndIf
    If !(aFlx[2] == 2500)
        lOk := .F.
    EndIf
    If !(aFlx[3] == 2500)
        lOk := .F.
    EndIf

    For nI := 1 To 50
        cDoc := "REC-M5-" + cValToChar(nI)
        If !GEBFNBAI("REC", cDoc, 100)
            lOk := .F.
        EndIf
    Next
    For nI := 1 To 50
        cDoc := "PAG-M5-" + cValToChar(nI)
        If !GEBFNBAI("PAG", cDoc, 50)
            lOk := .F.
        EndIf
    Next

    aFlx := GEBNFLX()
    If !(aFlx[1] == 0)
        lOk := .F.
    EndIf
    If !(aFlx[2] == 0)
        lOk := .F.
    EndIf
    If !(aFlx[3] == 0)
        lOk := .F.
    EndIf

    cFil1 := FWxFilial("GFN1")
    lAchou := .F.
    DbSelectArea("GFN1")
    DbGoTop()
    While !Eof()
        If GFN1->GFN1_FILIAL == cFil1 .AND. GFN1->GFN1_CONTA == "CAIXA" .AND. GFN1->D_E_L_E_T_ == " "
            lAchou := .T.
            nCaixa := GFN1->GFN1_SALDO
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(nCaixa == 2500)
        lOk := .F.
    EndIf

    aHit := TCSqlQuery("SELECT GFX4_CONTA FROM GFX4 WHERE GFX4_CONTA = 'CAIXA' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 100)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC LIKE 'REC-M5-%'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'PAG-M5-%'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_massa CASCADE")

    If lOk
        ConOut("T_GEBFIN_MASSA PASS")
    Else
        ConOut("T_GEBFIN_MASSA FAIL")
    EndIf
Return lOk
