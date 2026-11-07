#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIN_MIG.prw"

User Function T_GEBFIN_MIG()
    Local lOk := .T.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_fin CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS emp_test_fin")
    TCSqlExec("SET search_path TO emp_test_fin")

    If !GEBFNMIG()
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GFN1") .Or. !GEBDBTableExists("GFN2") .Or. ;
       !GEBDBTableExists("GFN3") .Or. !GEBDBTableExists("GFN4")
        lOk := .F.
    EndIf

    // GEBFNCON: cria conta nova.
    If !GEBFNCON("CAIXA01", "Caixa Loja 1")
        lOk := .F.
    EndIf
    // Idempotente: chamar de novo com a mesma conta nao duplica.
    If !GEBFNCON("CAIXA01", "Caixa Loja 1")
        lOk := .F.
    EndIf
    If Len(TCSqlQuery("SELECT GFN1_CONTA FROM GFN1 WHERE GFN1_CONTA = 'CAIXA01'")) != 1
        lOk := .F.
    EndIf
    // Conta vazia falha.
    If GEBFNCON("", "Sem Codigo")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_fin CASCADE")

    If lOk
        ConOut("T_GEBFIN_MIG: PASS")
    Else
        ConOut("T_GEBFIN_MIG: FAIL")
    EndIf
Return lOk
