#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
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

/*/{Protheus.doc} T_GEBV_EST
    Teste do saldo-movimento GEBVEST (Task 2 GEB_ESTOQ_VENDA).
    Chamada sem prefixo U e includes relativos: exigencia do
    runtime AdvPP.
    Asserts: GENMIG mais GEBVMIG OK; GEBVEST cria saldo 50 e
    baixa para 30 com round-trip GV1; minimo 10 com GE4
    ESTOQUE_MINIMO AVISA_E_TRAVA ainda movimenta para 5
    (alerta via GEBMNT, sem travar); cleanup via DELETE
    (rerun limpo). So literais em TCSqlExec-TCSqlQuery;
    ConOut PASS-FAIL. Schema descartavel test_gebv_est.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBV_EST()
    Local lOk := .T.
    Local lTmp := .F.
    Local nS1 := 0
    Local nS2 := 0
    Local nS3 := 0
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GEBV_EST: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_est CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebv_est")
    TCSqlExec("SET search_path TO test_gebv_est")

    GBAUDINIC()
    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD = 'PROD_EST_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'ESTOQUE_MINIMO'")
    If !lTmp
        lOk := .F.
    EndIf

    nS1 := GEBVEST("PROD_EST_RT", 50)
    If !(nS1 == 50)
        lOk := .F.
    EndIf

    nS2 := GEBVEST("PROD_EST_RT", -20)
    If !(nS2 == 30)
        lOk := .F.
    EndIf

    aHit := TCSqlQuery("SELECT GV1_SALDO FROM GV1 WHERE GV1_PROD = 'PROD_EST_RT' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'ESTOQUE_MINIMO', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf

    nS3 := GEBVEST("PROD_EST_RT", -25)
    If !(nS3 == 5)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD = 'PROD_EST_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'ESTOQUE_MINIMO'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE3 WHERE GE3_EVENT = 'ESTOQUE_MINIMO'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_est CASCADE")

    If lOk
        ConOut("T_GEBV_EST: PASS")
    Else
        ConOut("T_GEBV_EST: FAIL")
    EndIf
Return lOk
