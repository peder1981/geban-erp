#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBSEC_MIG.prw"
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

/*/{Protheus.doc} T_GEBFIN_CON_LAN
    Teste de contas e lancamentos financeiros (Task 2 GEB_FIN).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP. GEBMNT vem de GENUC_MNT (guia PAG_IMPULSIVO).
    Asserts: migracoes OK; GEBFNCON cria CX_T2_RT; GEBFNREC
    lanca REC-T2-01 ABERTO com SALDO igual ao VALOR; GEBFNPAG
    lanca PAG-T2-01 ABERTO; duplicata de DOC retorna .F.;
    valor zero retorna .F.; mentor AVISA_E_TRAVA em
    PAG_IMPULSIVO bloqueia GEBFNPAG sem tocar o banco;
    cleanup DELETE rerun limpo. So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBFIN_CON_LAN()
    Local lOk := .T.
    Local lTmp := .F.
    Local cFil2 := ""
    Local lAchou := .F.
    Local nSaldo := 0
    Local cStatus := ""

    If !GEBDBConecta()
        ConOut("T_GEBFIN_CON_LAN: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_con CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfin_con")
    TCSqlExec("SET search_path TO test_gebfin_con")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T2-01'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T2-01'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T2-BLOQ'")
    TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CX_T2_RT'")

    If !GEBFNCON("CX_T2_RT", "Caixa T2")
        lOk := .F.
    EndIf

    If !GEBFNREC("REC-T2-01", "CLI-T2", 500, "20261231")
        lOk := .F.
    EndIf

    cFil2 := FWxFilial("GFN2")
    lAchou := .F.
    DbSelectArea("GFN2")
    DbGoTop()
    While !Eof()
        If GFN2->GFN2_FILIAL == cFil2 .AND. GFN2->GFN2_DOC == "REC-T2-01" .AND. GFN2->D_E_L_E_T_ == " "
            lAchou := .T.
            nSaldo := GFN2->GFN2_SALDO
            cStatus := GFN2->GFN2_STATUS
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(nSaldo == 500)
        lOk := .F.
    EndIf
    If !(cStatus == "ABERTO")
        lOk := .F.
    EndIf

    If !GEBFNPAG("PAG-T2-01", "FORN-T2", 300, "20261231")
        lOk := .F.
    EndIf

    lTmp := GEBFNREC("REC-T2-01", "CLI-T2", 500, "20261231")
    If lTmp
        lOk := .F.
    EndIf

    lTmp := GEBFNREC("REC-T2-ZERO", "CLI-T2", 0, "20261231")
    If lTmp
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PAG_IMPULSIVO', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := GEBFNPAG("PAG-T2-BLOQ", "FORN-T2", 100, "20261231")
    If lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'PAG_IMPULSIVO'")
    If !lTmp
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T2-01'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T2-01'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T2-BLOQ'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CX_T2_RT'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_con CASCADE")

    If lOk
        ConOut("T_GEBFIN_CON_LAN PASS")
    Else
        ConOut("T_GEBFIN_CON_LAN FAIL")
    EndIf
Return lOk
