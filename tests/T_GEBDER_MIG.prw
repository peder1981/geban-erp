#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDER_MIG.prw"

User Function T_GEBDER_MIG()
    Local lOk := .T.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_der CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_test_der")
    TCSqlExec("SET search_path TO emp_test_der")

    If !GEBDMIG()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GD1") .Or. !GEBDBTableExists("GD2") .Or. !GEBDBTableExists("GD3")
        lOk := .F.
    EndIf

    // Idempotencia: rodar de novo nao quebra.
    If !GEBDMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_der CASCADE")

    If lOk
        ConOut("T_GEBDER_MIG: PASS")
    Else
        ConOut("T_GEBDER_MIG: FAIL")
    EndIf
Return lOk
