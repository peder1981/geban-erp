#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
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

/*/{Protheus.doc} T_GEBDER_BAI
    Teste da baixa derrama (Task 4 GEB_DERRAMA).
    Chamada sem prefixo U e include relativo: exigencia do
    runtime AdvPP. CTBLAN vem de GENUC_MNT.
    Asserts: migracoes OK; seed GF5 202608 saldo 2000; GEBDGER
    retorna GD202608; GEBDBAI .T. mais GD1 BAIXADA; miss
    GEBDBAI guia inexistente .F.; cleanup DELETE rerun limpo.
    So literais; ConOut PASS-FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBDER_BAI()
    Local lOk := .T.
    Local lTmp := .F.
    Local cGuia := ""
    Local cFil := ""
    Local lAchou := .F.
    Local cStatus := ""

    If !GEBDBConecta()
        ConOut("T_GEBDER_BAI: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebder_bai CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebder_bai")
    TCSqlExec("SET search_path TO test_gebder_bai")

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf
    If !GEBDMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA = 'GD202608'")
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_COMP = '202608'")
    lTmp := TCSqlExec("INSERT INTO GF5 (D_E_L_E_T_, GF5_FILIAL, GF5_COMP, GF5_DEB, GF5_CRED, GF5_SALDO, GF5_REGIME) VALUES (' ', '      ', '202608', 2000, 0, 2000, 'REGULAR')")
    If !lTmp
        lOk := .F.
    EndIf

    cGuia := GEBDGER("202608")
    If !(cGuia == "GD202608")
        lOk := .F.
    EndIf

    lTmp := GEBDBAI("GD202608")
    If !lTmp
        lOk := .F.
    EndIf

    cFil := FWxFilial("GD1")
    lAchou := .F.
    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->GD1_FILIAL == cFil .AND. GD1->GD1_GUIA == "GD202608" .AND. GD1->D_E_L_E_T_ == " "
            lAchou := .T.
            cStatus := GD1->GD1_STATUS
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(cStatus == "BAIXADA")
        lOk := .F.
    EndIf

    lTmp := GEBDBAI("GDINEXISTENTE")
    If lTmp
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GD1 WHERE GD1_GUIA = 'GD202608'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_COMP = '202608'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebder_bai CASCADE")

    If lOk
        ConOut("T_GEBDER_BAI PASS")
    Else
        ConOut("T_GEBDER_BAI FAIL")
    EndIf
Return lOk
