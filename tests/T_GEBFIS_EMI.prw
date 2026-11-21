#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
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

/*/{Protheus.doc} T_GEBFIS_EMI
    Teste da emissao fiscal ONLINE_FILA + split (Task 3 GEB_FISCAL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG()+GEBFMIG() OK; seed GF1/GF2 + GE4 EMISSAO
    ONLINE_FILA => GEBFEMI() retorna AUTORIZADA + round-trip GF3/GF4;
    GE4 EMISSAO SO_FILA => GEBFEMI() retorna EM_FILA + round-trip GE5;
    GEBFSPL(1000,2) retorna {500,500}; GE4 AVISA_E_TRAVA => GEBFEMI()
    retorna EM_FILA (intercept GEBMNT). Cleanup via DELETE (rerun
    limpo). So literais em TCSqlExec/TCSqlQuery; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBFIS_EMI()
    Local lOk := .T.
    Local lTmp := .F.
    Local cSt1 := ""
    Local cSt2 := ""
    Local cSt3 := ""
    Local aHit := {}
    Local aSpl := {}

    If !GEBDBConecta()
        ConOut("T_GEBFIS_EMI: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_emi CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfis_emi")
    TCSqlExec("SET search_path TO test_gebfis_emi")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD_T3_RT', 'NCM_T3_RT', 'Produto T3 round-trip')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM_T3_RT', 10, 5, '20200101', '20301231')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EMISSAO', 'ONLINE_FILA')")
    If !lTmp
        lOk := .F.
    EndIf

    cSt1 := GEBFEMI("NF-T3-AUT", "PROD_T3_RT", 2, 1000)
    If !(cSt1 == "AUTORIZADA")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GF3_STATUS FROM GF3 WHERE GF3_CHAVE = 'NF-T3-AUT' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GF4_PROD FROM GF4 WHERE GF4_CHAVE = 'NF-T3-AUT' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EMISSAO', 'SO_FILA')")
    If !lTmp
        lOk := .F.
    EndIf

    cSt2 := GEBFEMI("NF-T3-FILA", "PROD_T3_RT", 1, 500)
    If !(cSt2 == "EM_FILA")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GE5_CHAVE FROM GE5 WHERE GE5_CHAVE = 'NF-T3-FILA' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    aSpl := GEBFSPL(1000, 2)
    If !(Len(aSpl) == 2)
        lOk := .F.
    Else
        If !(aSpl[1] == 500)
            lOk := .F.
        EndIf
        If !(aSpl[2] == 500)
            lOk := .F.
        EndIf
    EndIf

    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EMISSAO', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf

    cSt3 := GEBFEMI("NF-T3-TRAVA", "PROD_T3_RT", 1, 500)
    If !(cSt3 == "EM_FILA")
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_T3_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_T3_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'NF-T3-AUT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'NF-T3-AUT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'NF-T3-FILA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'NF-T3-FILA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'NF-T3-TRAVA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'NF-T3-TRAVA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'NF-T3-FILA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'NF-T3-TRAVA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_emi CASCADE")

    If lOk
        ConOut("T_GEBFIS_EMI PASS")
    Else
        ConOut("T_GEBFIS_EMI FAIL")
    EndIf
Return lOk
