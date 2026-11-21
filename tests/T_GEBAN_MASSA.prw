#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GENUC_MNT.prw"

/*/{Protheus.doc} T_GEBAN_MASSA
    Teste de massa 100 auditorias + fila (Task 5 GEB_NUCLEO).
    Chamada sem prefixo U_ e includes relativos: exigencia do
    runtime AdvPP (ver .superpowers/sdd/task-1-report.md).
    Asserts: GENMIG() OK; loop 100x GEBAUD("MASSA", "EV-MASSA-"+N,
    "carga") todos .T.; count via TCSqlQuery (GE3_MOTIV = 'carga')
    Len() == 100; GEBFILA round-trip hit em GE5; cleanup via DELETE
    (pre-cleanup + pos-cleanup, rerun limpo). Log via ConOut
    (FWLogMsg nao existe no runtime).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se massa 100 passar, .F. caso contrario
/*/
User Function T_GEBAN_MASSA()
    Local nI := 0
    Local lOk := .T.
    Local lTmp := .F.
    Local aHit := {}
    Local cEvt := ""

    If !GEBDBConecta()
        ConOut("T_GEBAN_MASSA: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_geban_massa CASCADE")
    TCSqlExec("CREATE SCHEMA test_geban_massa")
    TCSqlExec("SET search_path TO test_geban_massa")

    If !GENMIG()
        lOk := .F.
    EndIf

    // Pre-cleanup (rerun limpo mesmo apos FAIL anterior).
    TCSqlExec("DELETE FROM GE3 WHERE GE3_MOTIV = 'carga'")
    TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'NF-MASSA-001'")

    For nI := 1 To 100
        cEvt := "EV-MASSA-" + cValToChar(nI)
        lTmp := GEBAUD("MASSA", cEvt, "carga")
        If !lTmp
            lOk := .F.
        EndIf
    Next

    // Count assert: 100 trilhas com motivo carga.
    aHit := TCSqlQuery("SELECT GE3_COD FROM GE3 WHERE GE3_MOTIV = 'carga' AND D_E_L_E_T_ = ' '")
    If !(Len(aHit) == 100)
        lOk := .F.
    EndIf

    // Fila: 1 round-trip (produces auditorias+fila).
    If !GEBFILA("NF-MASSA-001", "{massa:100}")
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GE5_CHAVE FROM GE5 WHERE GE5_CHAVE = 'NF-MASSA-001' AND D_E_L_E_T_ = ' '")
    If Len(aHit) == 0
        lOk := .F.
    EndIf

    // Pos-cleanup (rerun limpo).
    lTmp := TCSqlExec("DELETE FROM GE3 WHERE GE3_MOTIV = 'carga'")
    If !lTmp
        lOk := .F.
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE5 WHERE GE5_CHAVE = 'NF-MASSA-001'")
    If !lTmp
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_geban_massa CASCADE")

    If lOk
        ConOut("T_GEBAN_MASSA PASS")
    Else
        ConOut("T_GEBAN_MASSA FAIL")
    EndIf
Return lOk
