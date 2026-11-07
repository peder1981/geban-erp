#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
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

/*{Protheus.doc} T_GEBCOM_ENT
    Teste entrada de compra (Task 4 GEB_COM).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se passar, .F. caso contrario
/*/
User Function T_GEBCOM_ENT()
    If !GEBDBConecta()
        ConOut("T_GEBCOM_ENT: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_ent CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcom_ent")
    TCSqlExec("SET search_path TO test_gebcom_ent")

    If !GEBCMMIG()
        ConOut("T_GEBCOM_ENT: GEBCMMIG falhou")
        Return .F.
    EndIf
    GBAUDINIC()
    Local lOk := .T.
    Local aHit := {}

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'F-T4-%'")
    TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-T4-%'")
    TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-T4-%'")
    TCSqlExec("DELETE FROM GCP5 WHERE GCP5_NF LIKE 'NF-T4-%'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'NF-T4-%'")
    TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD LIKE 'P-T4-%'")

    If !GEBCMFOR("F-T4-01", "Forn T4")
        lOk := .F.
    EndIf
    If !(GEBCMPED("PED-T4-01", "F-T4-01") == "ABERTO")
        lOk := .F.
    EndIf
    If !GEBCMIT("PED-T4-01", "P-T4-A", 5, 10)
        lOk := .F.
    EndIf
    If !GEBCMIT("PED-T4-01", "P-T4-B", 2, 20)
        lOk := .F.
    EndIf

    If !GEBCMENT("NF-T4-01", "PED-T4-01")
        lOk := .F.
    EndIf
    If GEBCMENT("NF-T4-01", "PED-T4-01")
        lOk := .F.
    EndIf
    If GEBCMENT("NF-T4-02", "PED-T4-99")
        lOk := .F.
    EndIf
    If GEBCMENT("", "PED-T4-01")
        lOk := .F.
    EndIf

    aHit := TCSqlQuery("SELECT GCP3_STATUS FROM GCP3 WHERE GCP3_NUM = 'PED-T4-01' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 1)
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GCP5_NF FROM GCP5 WHERE GCP5_NF = 'NF-T4-01' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 1)
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_DOC = 'NF-T4-01' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 1)
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GV1_PROD FROM GV1 WHERE GV1_PROD = 'P-T4-A' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 1)
        lOk := .F.
    EndIf

    If !TCSqlExec("DELETE FROM GCP5 WHERE GCP5_NF LIKE 'NF-T4-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'NF-T4-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-T4-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-T4-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'F-T4-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD LIKE 'P-T4-%'")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_ent CASCADE")

    If lOk
        ConOut("T_GEBCOM_ENT PASS")
    Else
        ConOut("T_GEBCOM_ENT FAIL")
    EndIf
Return lOk
