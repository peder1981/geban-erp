#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBV_MIG.prw"

User Function T_GEBV_MIG()
    Local lOk := .T.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_v CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_test_v")
    TCSqlExec("SET search_path TO emp_test_v")

    If !GEBVMIG()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GV1") .Or. !GEBDBTableExists("GV2") .Or. !GEBDBTableExists("GV3")
        lOk := .F.
    EndIf
    If !GEBVMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_v CASCADE")

    If lOk
        ConOut("T_GEBV_MIG: PASS")
    Else
        ConOut("T_GEBV_MIG: FAIL")
    EndIf
Return lOk
