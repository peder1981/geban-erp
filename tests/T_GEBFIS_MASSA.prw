#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
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

/*/{Protheus.doc} T_GEBFIS_MASSA
    Teste de massa fiscal 100 notas + apuracao mix SIMPLES/REGULAR
    (Task 5 GEB_FISCAL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG()+GEBFMIG() OK; seed GF1 PROD_M5_RT + GF2
    NCM_M5_RT (10/5 exatos) + GE1 EMP_M5 SIMPLES + GE4 EMISSAO
    ONLINE_FILA + GE4 APURACAO AUTO; pre-cleanup via DELETE LIKE
    NF-M5-% (rerun limpo); loop 100x GEBFEMI (NF-M5-N 1x100,
    base 100 cada) todos AUTORIZADA; count GF3/GF4 LIKE NF-M5-%
    Len() == 100; GEBFAPU(cComp)==.T. + round-trip GF5 via
    workarea (DEB 1500, CRED 0, SALDO 1500, REGIME SIMPLES);
    troca GE1 para REGULAR + reapura (idempotencia BaixaGF5) +
    round-trip (DEB 1500, REGIME REGULAR, 1 linha ativa);
    GEBFCRE TRANSF + RESSARC + GF6 2 linhas; GEBFSPL(1500,4)
    4x375; cleanup via DELETE (rerun limpo). So literais em
    TCSqlExec/TCSqlQuery; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se massa 100 passar, .F. caso contrario
/*/
User Function T_GEBFIS_MASSA()
    Local lOk := .T.
    Local lTmp := .F.
    Local cComp := ""
    Local nI := 0
    Local cChave := ""
    Local cSt := ""
    Local aHit := {}
    Local cFil5 := ""
    Local lAchou := .F.
    Local nDeb := 0
    Local nCred := 0
    Local nSaldo := 0
    Local cReg := ""
    Local nAtivas := 0
    Local aSpl := {}
    Local nSoma := 0

    If !GEBDBConecta()
        ConOut("T_GEBFIS_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfis_massa")
    TCSqlExec("SET search_path TO test_gebfis_massa")

    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFMIG()
        lOk := .F.
    EndIf

    cComp := SubStr(DToS(Date()), 1, 6)

    // Pre-cleanup (rerun limpo mesmo apos FAIL anterior).
    // LIKE com literal: sem concatenar SQL (padrao Tasks 1-4).
    TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE LIKE 'NF-M5-%'")
    TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_M5_RT'")
    TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_M5_RT'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 'EMP_M5'")
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EMISSAO'")
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'APURACAO'")
    TCSqlExec("DELETE FROM GF5 WHERE GF5_REGIME = 'SIMPLES'")
    TCSqlExec("DELETE FROM GF5 WHERE GF5_REGIME = 'REGULAR'")
    TCSqlExec("DELETE FROM GF6 WHERE GF6_ORIG = 'SALDO_M5'")

    lTmp := TCSqlExec("INSERT INTO GF1 (D_E_L_E_T_, GF1_FILIAL, GF1_COD, GF1_NCM, GF1_DESC) VALUES (' ', '      ', 'PROD_M5_RT', 'NCM_M5_RT', 'Produto M5 massa')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', '      ', 'NCM_M5_RT', 10, 5, '20200101', '20301231')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '      ', 'EMP_M5', 'SIMPLES')")
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

    // Loop 100 emissoes: 1x100 cada (base 100, IBS 10, CBS 5).
    // Total esperado: base 10000, IBS 1000, CBS 500, DEB 1500.
    For nI := 1 To 100
        cChave := "NF-M5-" + cValToChar(nI)
        cSt := GEBFEMI(cChave, "PROD_M5_RT", 1, 100)
        If !(cSt == "AUTORIZADA")
            lOk := .F.
        EndIf
    Next

    // Count asserts: 100 headers + 100 itens (ativos).
    aHit := TCSqlQuery("SELECT GF3_CHAVE FROM GF3 WHERE GF3_CHAVE LIKE 'NF-M5-%' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 100)
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GF4_CHAVE FROM GF4 WHERE GF4_CHAVE LIKE 'NF-M5-%' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 100)
        lOk := .F.
    EndIf

    // Apuracao 1: regime SIMPLES (GE1_NOME SIMPLES).
    If !GEBFAPU(cComp)
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
    If !(nDeb == 1500)
        lOk := .F.
    EndIf
    If !(nCred == 0)
        lOk := .F.
    EndIf
    If !(nSaldo == 1500)
        lOk := .F.
    EndIf
    If !(cReg == "SIMPLES")
        lOk := .F.
    EndIf

    // Mix Simples/Regular: troca GE1 para REGULAR + reapura.
    // BaixaGF5 idempotente: so 1 linha ativa da competencia.
    lTmp := TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 'EMP_M5'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '      ', 'EMP_M5', 'REGULAR')")
    If !lTmp
        lOk := .F.
    EndIf
    If !GEBFAPU(cComp)
        lOk := .F.
    EndIf
    lAchou := .F.
    nAtivas := 0
    DbSelectArea("GF5")
    DbGoTop()
    While !Eof()
        If GF5->GF5_FILIAL == cFil5 .AND. GF5->GF5_COMP == cComp .AND. GF5->D_E_L_E_T_ == " "
            nAtivas := nAtivas + 1
            lAchou := .T.
            nDeb := GF5->GF5_DEB
            cReg := GF5->GF5_REGIME
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(nAtivas == 1)
        lOk := .F.
    EndIf
    If !(nDeb == 1500)
        lOk := .F.
    EndIf
    If !(cReg == "REGULAR")
        lOk := .F.
    EndIf

    // Creditos mix TRANSF/RESSARC + split sanity 1500/4.
    If !GEBFCRE(cComp, "SALDO_M5", 200, "TRANSF")
        lOk := .F.
    EndIf
    If !GEBFCRE(cComp, "SALDO_M5", 75, "RESSARC")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GF6_ORIG FROM GF6 WHERE GF6_ORIG = 'SALDO_M5' AND D_E_L_E_T_ = ' '")
    If Len(aHit) < 2
        lOk := .F.
    EndIf
    aSpl := GEBFSPL(1500, 4)
    If !(Len(aSpl) == 4)
        lOk := .F.
    Else
        nSoma := aSpl[1] + aSpl[2] + aSpl[3] + aSpl[4]
        If !(nSoma == 1500)
            lOk := .F.
        EndIf
    EndIf

    // Pos-cleanup (rerun limpo).
    lTmp := TCSqlExec("DELETE FROM GF3 WHERE GF3_CHAVE LIKE 'NF-M5-%'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF4 WHERE GF4_CHAVE LIKE 'NF-M5-%'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE LIKE 'NF-M5-%'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF1 WHERE GF1_COD = 'PROD_M5_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF2 WHERE GF2_NCM = 'NCM_M5_RT'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 'EMP_M5'")
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
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_REGIME = 'SIMPLES'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF5 WHERE GF5_REGIME = 'REGULAR'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GF6 WHERE GF6_ORIG = 'SALDO_M5'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfis_massa CASCADE")

    If lOk
        ConOut("T_GEBFIS_MASSA PASS")
    Else
        ConOut("T_GEBFIS_MASSA FAIL")
    EndIf
Return lOk
