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

/*/{Protheus.doc} T_GEBFIN_FLX
    Teste do fluxo de caixa (Task 4 GEB_FIN).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP.
    Asserts: migracoes OK; 2 receber (500+200) + 1 pagar (300)
    com GEBNFLX retornando {700, 300, 400}; baixa parcial de
    100 no receber vira {600, 300, 300}; baixa total do pagar
    vira {600, 0, 600}; apos cleanup o fluxo vazio retorna
    {0, 0, 0} (rerun limpo). So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBFIN_FLX()
    Local lOk := .T.
    Local lTmp := .F.
    Local aFlx := {}

    If !GEBDBConecta()
        ConOut("T_GEBFIN_FLX: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_flx CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfin_flx")
    TCSqlExec("SET search_path TO test_gebfin_flx")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T4-01'")
    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T4-02'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T4-01'")
    TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")

    If !GEBFNREC("REC-T4-01", "CLI-T4", 500, "20261231")
        lOk := .F.
    EndIf
    If !GEBFNREC("REC-T4-02", "CLI-T4", 200, "20261231")
        lOk := .F.
    EndIf
    If !GEBFNPAG("PAG-T4-01", "FORN-T4", 300, "20261231")
        lOk := .F.
    EndIf

    aFlx := GEBNFLX()
    If !(Len(aFlx) == 3)
        lOk := .F.
    Else
        If !(aFlx[1] == 700)
            lOk := .F.
        EndIf
        If !(aFlx[2] == 300)
            lOk := .F.
        EndIf
        If !(aFlx[3] == 400)
            lOk := .F.
        EndIf
    EndIf

    If !GEBFNBAI("REC", "REC-T4-01", 100)
        lOk := .F.
    EndIf
    aFlx := GEBNFLX()
    If !(aFlx[1] == 600)
        lOk := .F.
    EndIf
    If !(aFlx[2] == 300)
        lOk := .F.
    EndIf
    If !(aFlx[3] == 300)
        lOk := .F.
    EndIf

    If !GEBFNBAI("PAG", "PAG-T4-01", 300)
        lOk := .F.
    EndIf
    aFlx := GEBNFLX()
    If !(aFlx[1] == 600)
        lOk := .F.
    EndIf
    If !(aFlx[2] == 0)
        lOk := .F.
    EndIf
    If !(aFlx[3] == 600)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T4-01'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T4-02'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T4-01'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    If !lTmp
        lOk := .F.
    EndIf

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

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_flx CASCADE")

    If lOk
        ConOut("T_GEBFIN_FLX PASS")
    Else
        ConOut("T_GEBFIN_FLX FAIL")
    EndIf
Return lOk
