#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBV_VEN.prw"
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

/*/{Protheus.doc} T_GEBV_VEN
    Teste da venda guiada GEBVVEN (Task 3 GEB_ESTOQ_VENDA).
    Chamada sem prefixo U e includes relativos: exigencia do
    runtime AdvPP.
    Asserts: GENMIG mais GEBVMIG mais GEBFMIG OK; seed GV1
    PROD_VEN_RT 100 via GEBVEST; GEBVVEN V-VEN-1 10 retorna
    VENDIDA mais GV1 90 mais round-trip GV2; GEBVVEN 200
    retorna SEM_ESTOQUE sem GV2 e sem baixar; GE4
    VENDA_IMPULSIVA AVISA_E_TRAVA retorna BLOQUEADA sem
    baixar; integra fiscal (GF1 mais GF2 mais GE4 EMISSAO
    ONLINE_FILA) com round-trip GF3; cleanup via DELETE
    (rerun limpo). So literais em TCSqlExec-TCSqlQuery;
    ConOut PASS-FAIL. Schema descartavel test_gebv_ven.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23-09-2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBV_VEN()
    Local lOk := .T.
    Local lTmp := .F.
    Local cSt1 := ""
    Local cSt2 := ""
    Local cSt3 := ""
    Local nS := 0
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GEBV_VEN: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_ven CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebv_ven")
    TCSqlExec("SET search_path TO test_gebv_ven")

    GBAUDINIC()
    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD = 'PROD_VEN_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA = 'V-VEN-2'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA = 'V-VEN-3'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_VEN_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_VEN_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'VENDA_IMPULSIVA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf

    nS := GEBVEST("PROD_VEN_RT", 100)
    If !(nS == 100)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD_VEN_RT', 'NCM_VEN_RT', 'Produto VEN round-trip')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM_VEN_RT', 10, 5, '20200101', '20301231')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EMISSAO', 'ONLINE_FILA')")
    If !lTmp
        lOk := .F.
    EndIf

    cSt1 := GEBVVEN("V-VEN-1", "PROD_VEN_RT", 10)
    If !(cSt1 == "VENDIDA")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GV2_PROD FROM GV2 WHERE GV2_VENDA = 'V-VEN-1' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GF3_STATUS FROM GF3 WHERE GF3_CHAVE = 'V-VEN-1' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    cSt2 := GEBVVEN("V-VEN-2", "PROD_VEN_RT", 200)
    If !(cSt2 == "SEM_ESTOQUE")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GV2_PROD FROM GV2 WHERE GV2_VENDA = 'V-VEN-2' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 0)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'VENDA_IMPULSIVA', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf

    cSt3 := GEBVVEN("V-VEN-3", "PROD_VEN_RT", 5)
    If !(cSt3 == "BLOQUEADA")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GV2_PROD FROM GV2 WHERE GV2_VENDA = 'V-VEN-3' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 0)
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GV1 WHERE GV1_PROD = 'PROD_VEN_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA = 'V-VEN-2'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GV2 WHERE GV2_VENDA = 'V-VEN-3'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_VEN_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_VEN_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'VENDA_IMPULSIVA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'V-VEN-1'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebv_ven CASCADE")

    If lOk
        ConOut("T_GEBV_VEN: PASS")
    Else
        ConOut("T_GEBV_VEN: FAIL")
    EndIf
Return lOk
