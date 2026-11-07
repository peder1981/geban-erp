#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"

User Function T_GEBDB_TENANT()
    Local lOk := .T.

    If !GEBDBConecta()
        ConOut("FAIL: GEBDBConecta")
        Return .F.
    EndIf

    If GEBDBSchemaValido("emp01; DROP TABLE GE1")
        ConOut("FAIL: GEBDBSchemaValido aceitou entrada com SQL injetado")
        lOk := .F.
    EndIf
    If !GEBDBSchemaValido("teste01")
        ConOut("FAIL: GEBDBSchemaValido rejeitou nome valido")
        lOk := .F.
    EndIf

    // Regra vigente (pos Task 6 + fix 931c772): GEBDBSetTenant() so
    // aceita empresa com schema provisionado -- trocar para schema
    // inexistente seria vazar para search_path invalido. Empresa nunca
    // provisionada => .F. sem trocar nada (ver T_GEBDB_TENANT_2).
    TCSqlExec("DROP SCHEMA IF EXISTS emp_teste01 CASCADE")
    If GEBDBSetTenant("teste01")
        ConOut("FAIL: GEBDBSetTenant aceitou empresa nao provisionada (vazamento)")
        lOk := .F.
    Else
        ConOut("  OK SetTenant rejeita sem schema")
    EndIf
    If !TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_teste01")
        ConOut("FAIL: nao conseguiu criar schema de teste")
        lOk := .F.
    EndIf
    If !GEBDBSetTenant("teste01")
        ConOut("FAIL: GEBDBSetTenant apos schema existir")
        lOk := .F.
    EndIf
    TCSqlExec("CREATE TABLE IF NOT EXISTS SONDA (X INTEGER)")
    If !GEBDBTableExists("SONDA")
        ConOut("FAIL: SONDA nao encontrada dentro do schema emp_teste01")
        lOk := .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    If GEBDBTableExists("SONDA")
        ConOut("FAIL: SONDA vazou pro schema public")
        lOk := .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_teste01 CASCADE")

    If lOk
        ConOut("T_GEBDB_TENANT: PASS")
    Else
        ConOut("T_GEBDB_TENANT: FAIL")
    EndIf
Return lOk
