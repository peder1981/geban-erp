#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
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

/*/{Protheus.doc} T_GEBFIS_APU
    Teste da apuracao AUTO/MANUAL/DIRETA + creditos (Task 4 GEB_FISCAL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG()+GEBFMIG() OK; seed GF1/GF2 + GE1 SIMPLES + GE4
    EMISSAO ONLINE_FILA + GE4 APURACAO AUTO; emite 2 notas via GEBFEMI
    (NF-T4-A 2x1000 + NF-T4-B 1x500, base 2500, IBS 250, CBS 125);
    GEBFAPU(cComp)=.T. + round-trip GF5 (DEB 375, CRED 0, SALDO 375,
    REGIME SIMPLES); GEBFCRE TRANSF + RESSARC=.T. + round-trip GF6
    (2 linhas); cleanup via DELETE (rerun limpo). So literais em
    TCSqlExec/TCSqlQuery; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBFIS_APU()
    Local lOk := .T.
    Local lTmp := .F.
    Local cComp := ""
    Local cSt1 := ""
    Local cSt2 := ""
    Local aHit := {}
    Local cFil5 := ""
    Local lAchou := .F.
    Local nDeb := 0
    Local nCred := 0
    Local nSaldo := 0
    Local cReg := ""

    If !GEBDBConecta()
        ConOut("T_GEBFIS_APU: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_apu CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfis_apu")
    TCSqlExec("SET search_path TO test_gebfis_apu")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf

    cComp := SubStr(DToS(Date()), 1, 6)

    lTmp := TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD_T4_RT', 'NCM_T4_RT', 'Produto T4 round-trip')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM_T4_RT', 10, 5, '20200101', '20301231')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '      ', 'EMP_T4', 'SIMPLES')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EMISSAO', 'ONLINE_FILA')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'APURACAO', 'AUTO')")
    If !lTmp
        lOk := .F.
    EndIf

    cSt1 := GEBFEMI("NF-T4-A", "PROD_T4_RT", 2, 1000)
    If !(cSt1 == "AUTORIZADA")
        lOk := .F.
    EndIf
    cSt2 := GEBFEMI("NF-T4-B", "PROD_T4_RT", 1, 500)
    If !(cSt2 == "AUTORIZADA")
        lOk := .F.
    EndIf

    If !GEBFAPU(cComp)
        lOk := .F.
    EndIf

    // Round-trip GF5 via workarea (cComp e variavel: sem concat SQL).
    // Esperado: 2 notas (base 2500, IBS 250, CBS 125) => DEB 375,
    // CRED 0, SALDO 375, REGIME SIMPLES (GE1_NOME SIMPLES).
    aHit := TCSqlQuery("SELECT GF5_DEB FROM GF5 WHERE D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf
    cFil5 := FWxFilial("GF5")
    lAchou := .F.
    DbSelectArea("GF5")
    DbGoTop()
    While !Eof()
        If GF5->GF5_FILIAL == cFil5 .AND. GF5->GF5_COMP == cComp .AND. GF5->D_E_L_E_T_ == " "
            lAchou := .T.
            nDeb := GF5->GF5_DEB
            nCred := GF5->GF5_CRED
            nSaldo := GF5->GF5_SALDO
            cReg := GF5->GF5_REGIME
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(nDeb == 375)
        lOk := .F.
    EndIf
    If !(nCred == 0)
        lOk := .F.
    EndIf
    If !(nSaldo == 375)
        lOk := .F.
    EndIf
    If !(cReg == "SIMPLES")
        lOk := .F.
    EndIf

    If !GEBFCRE(cComp, "SALDO_T4", 100, "TRANSF")
        lOk := .F.
    EndIf
    If !GEBFCRE(cComp, "SALDO_T4", 50, "RESSARC")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GF6_ORIG FROM GF6 WHERE GF6_ORIG = 'SALDO_T4' AND D_E_L_E_T_ = ' '")
    If Len(aHit) < 2
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_T4_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_T4_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'NF-T4-A'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'NF-T4-A'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE = 'NF-T4-B'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE = 'NF-T4-B'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_REGIME = 'SIMPLES'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_REGIME = 'REGULAR'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF6 WHERE GF6_ORIG = 'SALDO_T4'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 'EMP_T4'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'APURACAO'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_apu CASCADE")

    If lOk
        ConOut("T_GEBFIS_APU PASS")
    Else
        ConOut("T_GEBFIS_APU FAIL")
    EndIf
Return lOk
