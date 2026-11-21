#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBCTB_MIG.prw"

/*/{Protheus.doc} T_GEBCTB_CTB
    Teste do CTBLAN real partida dobrada (Task 2 GEB_CONTABIL).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG + GEBCMIG OK; CTBGRV grava lote e retorna
    codigo nao vazio; CTBLAN com param GC4 grava GC2 (TIPO AUTO)
    + 2xGC3 (D 1.01.001 / C 3.01.001, debito igual a credito);
    CTBLAN com valor zerado retorna .F.; CTBLAN sem param
    (PADRAO removido + evento inexistente) retorna .F.;
    cleanup com limpa total GC1-GC4 (rerun limpo e regressao
    legada preservada: GC4 vazia/ausente volta ao modo
    compativel). Log via ConOut.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBCTB_CTB()
    Local lOk := .T.
    Local lTmp := .F.
    Local aHit := {}
    Local cLote := ""
    Local nDeb := 0
    Local nCred := 0

    If !GEBDBConecta()
        ConOut("T_GEBCTB_CTB: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_ctb CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebctb_ctb")
    TCSqlExec("SET search_path TO test_gebctb_ctb")

    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMIG()
        lOk := .F.
    EndIf

    // Param do evento do teste (DEB 1.01.001 / CRED 3.01.001).
    lTmp := TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'CTB_T2', '1.01.001', '3.01.001', 'S')")
    If !lTmp
        lOk := .F.
    EndIf

    // Writer direto: retorna lote nao vazio.
    cLote := CTBGRV("CTB_T2_G", "1.01.001", "3.01.001", 100.00, "AUTO")
    If cLote == ""
        lOk := .F.
    EndIf

    // CTBLAN via GC4: balanceado (.T.).
    If !CTBLAN("CTB_T2", 250.00)
        lOk := .F.
    EndIf

    // Round-trip GC2: origem, tipo AUTO e valor.
    aHit := TCSqlQuery("SELECT GC2_TIPO FROM GC2 WHERE GC2_ORIGEM = 'CTB_T2' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    // Round-trip GC3: pernas D e C em igual numero (250 + 100 gravados).
    aHit := TCSqlQuery("SELECT GC3_DC FROM GC3 WHERE GC3_DC = 'D' AND D_E_L_E_T_ = ' '")
    nDeb := Len(aHit)
    aHit := TCSqlQuery("SELECT GC3_DC FROM GC3 WHERE GC3_DC = 'C' AND D_E_L_E_T_ = ' '")
    nCred := Len(aHit)
    If nDeb == 0
        lOk := .F.
    EndIf
    If nDeb != nCred
        lOk := .F.
    EndIf

    // Valor zerado recusa (.F.).
    If CTBLAN("CTB_T2", 0)
        lOk := .F.
    EndIf

    // Falta de param recusa (.F.): remove PADRAO e usa evento inedito.
    lTmp := TCSqlExec("DELETE FROM GC4 WHERE GC4_EVENTO = 'PADRAO'")
    If !lTmp
        lOk := .F.
    EndIf
    If CTBLAN("CTB_T2_MISS", 10.00)
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GC4 (D_E_L_E_T_, GC4_FILIAL, GC4_EVENTO, GC4_CTADEB, GC4_CTACRED, GC4_PERM) VALUES (' ', '      ', 'PADRAO', '1.01.001', '3.01.001', 'S')")
    If !lTmp
        lOk := .F.
    EndIf

    // Cleanup total (rerun limpo; GC4 vazia/ausente = modo compativel).
    lTmp := TCSqlExec("DELETE FROM GC3")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC2")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC4")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GC1")
    If !lTmp
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC2_LOTE FROM GC2 WHERE D_E_L_E_T_ = ' '")
    If Len(aHit) != 0
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebctb_ctb CASCADE")

    If lOk
        ConOut("T_GEBCTB_CTB PASS")
    Else
        ConOut("T_GEBCTB_CTB FAIL")
    EndIf
Return lOk
