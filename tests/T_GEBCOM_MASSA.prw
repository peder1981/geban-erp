#include "totvs.ch"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_BAI.prw"
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

/*/{Protheus.doc} T_GEBCOM_MASSA
    Teste de massa compras 50 pedidos round-trip.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function T_GEBCOM_MASSA()
    Local lOk := .T.
    Local nI := 0
    Local aHit := {}
    Local aR := {}

    If !GEBDBConecta()
        ConOut("T_GEBCOM_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcom_massa")
    TCSqlExec("SET search_path TO test_gebcom_massa")

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
    EndIf
    If lOk .AND. !GEBDBProvisionaEmpresa("m5", "Empresa Teste Massa")
        lOk := .F.
    EndIf
    If lOk
        GBAUDINIC()
    EndIf

    // Pre-cleanup for this test only.
    // GEBDBProvisionaEmpresa() puts business tables in the fixed
    // "emp_m5" schema (not the disposable test_gebcom_massa schema
    // dropped/recreated above), so leftovers from a prior run persist
    // across runs here. GCP3/GCP4/GCP5 (pedidos) already needed this;
    // GFN3 (contas a pagar, checked for duplicate NF by GEBFNPAG) needs
    // the same hygiene, or a leftover NF-M5-* from a prior run makes
    // GEBFNPAG reject the payment as duplicate.
    TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCP5 WHERE GCP5_NF LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GCQ2 WHERE GCQ2_PED LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCQ3 WHERE GCQ3_PED LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCQ4 WHERE GCQ4_NF LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GCQ5 WHERE GCQ5_NF LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'NF-M5-%'")

    // Seed
    GEBCMFOR("FORN-M5", "Fornecedor Massa", "123456789")
    For nI := 1 To 10
        GEBCMCOT("FORN-M5", "P-M5-" + Str(nI,2,0), 50.00)
    Next nI

    // 50 pedidos com itens (trilha GEBCPX: GCP3/GCP4 + GCQ2 alcada).
    For nI := 1 To 50
        aR := GEBCPXPED("PED-M5-" + Str(nI,3,0), "FORN-M5", {{"P-M5-01", 10, 10.00}, {"P-M5-02", 10, 10.00}}, "0", "01", BOHOJE())
        If !aR[1]
            lOk := .F.; Exit
        EndIf
        aR := GEBCPXENT("NF-M5-" + Str(nI,3,0), "PED-M5-" + Str(nI,3,0), {}, 0, BOHOJE(), {})
        If !aR[1]
            lOk := .F.; Exit
        EndIf
    Next nI

    // Assert
    If lOk
        aHit := TCSqlQuery("SELECT COUNT(*) as CNT FROM GCP3 WHERE GCP3_NUM LIKE 'PED-M5-%' AND D_E_L_E_T_ = ' '")
        If Len(aHit) == 0 .OR. Val(aHit[1]:GetJsonText("cnt")) != 50
            lOk := .F.
        EndIf
    EndIf

    // Cleanup
    TCSqlExec("DELETE FROM GCP3 WHERE GCP3_NUM LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCP4 WHERE GCP4_PED LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCP5 WHERE GCP5_NF LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GCQ2 WHERE GCQ2_PED LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCQ3 WHERE GCQ3_PED LIKE 'PED-M5-%'")
    TCSqlExec("DELETE FROM GCQ4 WHERE GCQ4_NF LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GCQ5 WHERE GCQ5_NF LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC LIKE 'NF-M5-%'")

    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 'm5'")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_m5 CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_massa CASCADE")

    If lOk
        ConOut("T_GEBCOM_MASSA PASS")
    Else
        ConOut("T_GEBCOM_MASSA FAIL")
    EndIf
Return lOk
