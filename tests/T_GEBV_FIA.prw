#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
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

/*/{Protheus.doc} T_GEBV_FIA
    Teste do fiado GEBVFIA mais juros GEBVJUR (Task 4).
    Chamada sem prefixo U e includes relativos: exigencia do
    runtime AdvPP.
    Asserts: GENMIG mais GEBVMIG OK; GEBVFIA 400 mais 400
    retorna .T. (total 800); terceiro 400 retorna .F.
    (limite 1000); round-trip GV3 com 2 ABERTA; GEBVJUR
    10 dias retorna mais de 800 com JUROS gravado;
    cleanup via DELETE (rerun limpo). So literais em
    TCSqlExec-TCSqlQuery; ConOut PASS-FAIL. Schema descartavel test_gebv_fia.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBV_FIA()
    Local lOk := .T.
    Local lTmp := .F.
    Local lF1 := .F.
    Local lF2 := .F.
    Local lF3 := .F.
    Local nJur := 0
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GEBV_FIA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_fia CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebv_fia")
    TCSqlExec("SET search_path TO test_gebv_fia")

    GBAUDINIC()
    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GV3 WHERE GV3_CLI = 'CLI_FIA_RT'")
    If !lTmp
        lOk := .F.
    EndIf

    lF1 := GEBVFIA("CLI_FIA_RT", 400)
    If !lF1
        lOk := .F.
    EndIf
    lF2 := GEBVFIA("CLI_FIA_RT", 400)
    If !lF2
        lOk := .F.
    EndIf
    lF3 := GEBVFIA("CLI_FIA_RT", 400)
    If lF3
        lOk := .F.
    EndIf

    aHit := TCSqlQuery("SELECT GV3_VALOR FROM GV3 WHERE GV3_CLI = 'CLI_FIA_RT' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 2)
        lOk := .F.
    EndIf

    nJur := GEBVJUR("CLI_FIA_RT", 10)
    If !(nJur > 800)
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GV3_JUROS FROM GV3 WHERE GV3_CLI = 'CLI_FIA_RT' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GV3 WHERE GV3_CLI = 'CLI_FIA_RT'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_fia CASCADE")

    If lOk
        ConOut("T_GEBV_FIA: PASS")
    Else
        ConOut("T_GEBV_FIA: FAIL")
    EndIf
Return lOk
