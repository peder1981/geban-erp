#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBCOM_FOR.prw"

/*{Protheus.doc} T_GEBCOM_FOR_COT
    Teste fornecedor + cotacao + menor preco (Task 2 GEB_COM).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se passar, .F. caso contrario
/*/
User Function T_GEBCOM_FOR_COT()
    Local lOk := .T.
    Local nMel := 0

    If !GEBDBConecta()
        ConOut("T_GEBCOM_FOR_COT: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_for CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebcom_for")
    TCSqlExec("SET search_path TO test_gebcom_for")
    GBAUDINIC()

    If !GENMIG()
        lOk := .F.
    EndIf
    If !GEBCMMIG()
        lOk := .F.
    EndIf

    TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'F-T2-%'")
    TCSqlExec("DELETE FROM GCP2 WHERE GCP2_PROD LIKE 'P-T2-%'")

    If !GEBCMFOR("F-T2-01", "Forn Um")
        lOk := .F.
    EndIf
    If !GEBCMFOR("F-T2-01", "Forn Um")
        lOk := .F.
    EndIf
    If GEBCMFOR("", "Sem Cod")
        lOk := .F.
    EndIf
    If GEBCMFOR("F-T2-02", "")
        lOk := .F.
    EndIf

    If !GEBCMCOT("F-T2-01", "P-T2-A", 10)
        lOk := .F.
    EndIf
    If !GEBCMCOT("F-T2-02", "P-T2-A", 7)
        lOk := .F.
    EndIf
    If GEBCMCOT("F-T2-01", "P-T2-A", 0)
        lOk := .F.
    EndIf
    If GEBCMCOT("", "P-T2-A", 5)
        lOk := .F.
    EndIf

    nMel := GEBCMMEL("P-T2-A")
    If !(nMel == 7)
        lOk := .F.
    EndIf
    nMel := GEBCMMEL("P-T2-VAZIO")
    If !(nMel == 0)
        lOk := .F.
    EndIf

    If !TCSqlExec("DELETE FROM GCP1 WHERE GCP1_COD LIKE 'F-T2-%'")
        lOk := .F.
    EndIf
    If !TCSqlExec("DELETE FROM GCP2 WHERE GCP2_PROD LIKE 'P-T2-%'")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebcom_for CASCADE")

    If lOk
        ConOut("T_GEBCOM_FOR_COT PASS")
    Else
        ConOut("T_GEBCOM_FOR_COT FAIL")
    EndIf
Return lOk
