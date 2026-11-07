#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBCOM_MIG.prw"

User Function T_GEBCOM_MIG()
    Local lOk := .T.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_com CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_test_com")
    TCSqlExec("SET search_path TO emp_test_com")

    If !GEBCMMIG()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GCP1") .Or. !GEBDBTableExists("GCP2") .Or. ;
       !GEBDBTableExists("GCP3") .Or. !GEBDBTableExists("GCP4") .Or. !GEBDBTableExists("GCP5")
        lOk := .F.
    EndIf
    If !GEBCMMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_com CASCADE")

    If lOk
        ConOut("T_GEBCOM_MIG: PASS")
    Else
        ConOut("T_GEBCOM_MIG: FAIL")
    EndIf
Return lOk
