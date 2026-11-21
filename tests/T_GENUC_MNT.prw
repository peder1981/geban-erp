#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"

/*/{Protheus.doc} T_GENUC_MNT
    Teste do Mentor GE4 + Fila GE5 + stub CTB_Lanca (Task 4).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG() OK; GEBMNT trava (AVISA_E_TRAVA -> .F.);
    GEBMNT libera com BO (AVISA_E_LIBERA_COM_BO -> .T. + trilha
    GE3 round-trip); GEBMNT desligado/miss -> .T.; GEBFILA grava
    GE5 (round-trip hit); CTBLAN stub -> .T. Cleanup via DELETE
    (rerun limpo). Log via ConOut (FWLogMsg nao existe).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GENUC_MNT()
    Local lOk := .T.
    Local lTmp := .F.
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GENUC_MNT: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_genuc_mnt CASCADE")
    TCSqlExec("CREATE SCHEMA test_genuc_mnt")
    TCSqlExec("SET search_path TO test_genuc_mnt")

    If !GENMIG()
        lOk := .F.
    EndIf

    // Seed GE4: modos literais (filial 6 espacos = FWxFilial sem env).
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EV_T4_TRAVA', 'AVISA_E_TRAVA')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EV_T4_LIBERA', 'AVISA_E_LIBERA_COM_BO')")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EV_T4_OFF', 'DESLIGADO')")
    If !lTmp
        lOk := .F.
    EndIf

    // Trava -> .F.
    If GEBMNT("EV_T4_TRAVA")
        lOk := .F.
    EndIf

    // Libera com BO -> .T. + trilha GE3 (round-trip).
    If !GEBMNT("EV_T4_LIBERA")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GE3_COD FROM GE3 WHERE GE3_EVENT = 'EV_T4_LIBERA' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    // Desligado -> .T. Miss (sem GE4) -> .T. sem BO.
    If !GEBMNT("EV_T4_OFF")
        lOk := .F.
    EndIf
    If !GEBMNT("EV_T4_INEXISTENTE")
        lOk := .F.
    EndIf

    // Fila: insert GE5 + round-trip hit.
    If !GEBFILA("NF-T4-001", "{teste:1}")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GE5_CHAVE FROM GE5 WHERE GE5_CHAVE = 'NF-T4-001' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    // Stub contabil: sempre balanceado (.T.).
    If !CTBLAN("TESTE", 100.00)
        lOk := .F.
    EndIf

    // Cleanup (rerun limpo).
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EV_T4_TRAVA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EV_T4_LIBERA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EV_T4_OFF'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE3 WHERE GE3_EVENT = 'EV_T4_LIBERA'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'NF-T4-001'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_genuc_mnt CASCADE")

    If lOk
        ConOut("T_GENUC_MNT PASS")
    Else
        ConOut("T_GENUC_MNT FAIL")
    EndIf
Return lOk
