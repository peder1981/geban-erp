#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBEXP_TRAK.prw"

User Function T_GEBEXP_TRAK()
    Local lOk := .T.
    Local aRet := {}

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_trak CASCADE")
    TCSqlExec("CREATE SCHEMA emp_test_trak")
    TCSqlExec("SET search_path TO emp_test_trak")

    // Nenhuma tabela criada: cada tracker deve devolver arrays vazios
    // em vez de quebrar (guard GEBDBTableExistsHere retorna .F. em
    // todo ponto de contato).
    aRet := GEBTRAKCOMPRA("PED001")
    If Len(aRet) != 6 .Or. Len(aRet[1]) > 0
        ConOut("FAIL: GEBTRAKCOMPRA deveria devolver 6 arrays vazios sem GCP3")
        lOk := .F.
    EndIf

    aRet := GEBTRAKVENDA("VEN001")
    If Len(aRet) == 0
        ConOut("FAIL: GEBTRAKVENDA nao deveria quebrar sem GV1/GV2")
        lOk := .F.
    EndIf

    aRet := GEBTRAKNOTAFISCAL("CHAVE001")
    If Len(aRet) == 0
        ConOut("FAIL: GEBTRAKNOTAFISCAL nao deveria quebrar sem GF3/GF4")
        lOk := .F.
    EndIf

    aRet := GEBTRAKDERRAMA("GUIA001")
    If Len(aRet) == 0
        ConOut("FAIL: GEBTRAKDERRAMA nao deveria quebrar sem GD1/GD2/GD3")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS emp_test_trak CASCADE")

    If lOk
        ConOut("T_GEBEXP_TRAK: PASS")
    Else
        ConOut("T_GEBEXP_TRAK: FAIL")
    EndIf
Return lOk
