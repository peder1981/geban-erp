#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
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
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBFIN_BAI
    Teste da baixa financeira (Task 3 GEB_FIN).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP. CTBLAN e GEBMNT vêm de GENUC_MNT.
    Asserts: migracoes OK; conta CAIXA criada; REC-T3-01 de 500
    com baixa parcial 200 (SALDO 300 ABERTO) e total 300
    (SALDO 0 RECEBIDA); PAG-T3-01 de 300 baixado total (PAGA);
    GFX4 com 3 movimentos CAIXA (baixa pelo financeiro); GFN1 CAIXA com SALDO 200
    (500 menos 300); miss, valor zero e tipo invalido
    retornam .F.; mentor AVISA_E_TRAVA em PAG_IMPULSIVO
    bloqueia baixa de pagar; cleanup DELETE rerun limpo.
    So literais; ConOut PASS/FAIL.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBFIN_BAI()
    Local lOk := .T.
    Local lTmp := .F.
    Local cFil2 := ""
    Local cFil1 := ""
    Local lAchou := .F.
    Local nSaldo := 0
    Local cStatus := ""
    Local aMov := {}
    Local nCaixa := 0

    If !GEBDBConecta()
        ConOut("T_GEBFIN_BAI: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_bai CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebfin_bai")
    TCSqlExec("SET search_path TO test_gebfin_bai")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBFNMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T3-01'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T3-01'")
    TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T3-02'")
    TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    If GEBDBTableExistsHere("GFX4")
        TCSqlExec("DELETE FROM GFX4 WHERE GFX4_CONTA = 'CAIXA'")
    EndIf
    TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")

    If !GEBFNCON("CAIXA", "Caixa T3")
        lOk := .F.
    EndIf
    If !GEBFNREC("REC-T3-01", "CLI-T3", 500, "20261231")
        lOk := .F.
    EndIf
    If !GEBFNPAG("PAG-T3-01", "FORN-T3", 300, "20261231")
        lOk := .F.
    EndIf
    If !GEBFNPAG("PAG-T3-02", "FORN-T3", 100, "20261231")
        lOk := .F.
    EndIf

    If !GEBFNBAI("REC", "REC-T3-01", 200)
        lOk := .F.
    EndIf

    cFil2 := FWxFilial("GFN2")
    lAchou := .F.
    DbSelectArea("GFN2")
    DbGoTop()
    While !Eof()
        If GFN2->GFN2_FILIAL == cFil2 .AND. GFN2->GFN2_DOC == "REC-T3-01" .AND. GFN2->D_E_L_E_T_ == " "
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
    If !(nSaldo == 300)
        lOk := .F.
    EndIf
    If !(cStatus == "ABERTO")
        lOk := .F.
    EndIf

    If !GEBFNBAI("REC", "REC-T3-01", 300)
        lOk := .F.
    EndIf
    If !GEBFNBAI("PAG", "PAG-T3-01", 300)
        lOk := .F.
    EndIf

    lAchou := .F.
    DbSelectArea("GFN2")
    DbGoTop()
    While !Eof()
        If GFN2->GFN2_FILIAL == cFil2 .AND. GFN2->GFN2_DOC == "REC-T3-01" .AND. GFN2->D_E_L_E_T_ == " "
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
    If !(nSaldo == 0)
        lOk := .F.
    EndIf
    If !(cStatus == "RECEBIDA")
        lOk := .F.
    EndIf

    // A baixa agora passa pelo financeiro (GEBFXBAI): movimento em GFX4.
    aMov := TCSqlQuery("SELECT GFX4_CONTA FROM GFX4 WHERE GFX4_CONTA = 'CAIXA' AND D_E_L_E_T_ = ' '")
    If !(Len(aMov) == 3)
        lOk := .F.
    EndIf

    cFil1 := FWxFilial("GFN1")
    lAchou := .F.
    DbSelectArea("GFN1")
    DbGoTop()
    While !Eof()
        If GFN1->GFN1_FILIAL == cFil1 .AND. GFN1->GFN1_CONTA == "CAIXA" .AND. GFN1->D_E_L_E_T_ == " "
            lAchou := .T.
            nCaixa := GFN1->GFN1_SALDO
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If !lAchou
        lOk := .F.
    EndIf
    If !(nCaixa == 200)
        lOk := .F.
    EndIf

    lTmp := GEBFNBAI("REC", "REC-INEXISTENTE", 10)
    If lTmp
        lOk := .F.
    EndIf
    lTmp := GEBFNBAI("REC", "REC-T3-01", 0)
    If lTmp
        lOk := .F.
    EndIf
    lTmp := GEBFNBAI("XXX", "REC-T3-01", 10)
    If lTmp
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'PAG_IMPULSIVO', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := GEBFNBAI("PAG", "PAG-T3-02", 100)
    If lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'PAG_IMPULSIVO'")
    If !lTmp
        lOk := .F.
    EndIf

    lTmp := TCSqlExec("DELETE FROM GFN2 WHERE GFN2_DOC = 'REC-T3-01'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T3-01'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN3 WHERE GFN3_DOC = 'PAG-T3-02'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN4 WHERE GFN4_CONTA = 'CAIXA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GFN1 WHERE GFN1_CONTA = 'CAIXA'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebfin_bai CASCADE")

    If lOk
        ConOut("T_GEBFIN_BAI PASS")
    Else
        ConOut("T_GEBFIN_BAI FAIL")
    EndIf
Return lOk
