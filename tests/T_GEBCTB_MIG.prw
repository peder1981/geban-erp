#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBCTB_MIG.prw"

User Function T_GEBCTB_MIG()
    Local lOk := .T.
    Local aHit := {}

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_ctb CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_test_ctb")
    TCSqlExec("SET search_path TO emp_test_ctb")

    If !GEBCMIG()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GC1") .Or. !GEBDBTableExists("GC2") .Or. ;
       !GEBDBTableExists("GC3") .Or. !GEBDBTableExists("GC4")
        lOk := .F.
    EndIf

    // Seed idempotente: 4 contas em GC1, 1 evento PADRAO em GC4.
    aHit := TCSqlQuery("SELECT GC1_CONTA FROM GC1 WHERE GC1_CONTA = '1.01.001' AND D_E_L_E_T_ = ' '")
    If Len(aHit) != 1
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC4_EVENTO FROM GC4 WHERE GC4_EVENTO = 'PADRAO' AND D_E_L_E_T_ = ' '")
    If Len(aHit) != 1
        lOk := .F.
    EndIf

    // Idempotencia: rodar de novo nao duplica o seed.
    If !GEBCMIG()
        lOk := .F.
    EndIf
    aHit := TCSqlQuery("SELECT GC1_CONTA FROM GC1 WHERE GC1_CONTA = '1.01.001'")
    If Len(aHit) != 1
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_ctb CASCADE")

    If lOk
        ConOut("T_GEBCTB_MIG: PASS")
    Else
        ConOut("T_GEBCTB_MIG: FAIL")
    EndIf
Return lOk
