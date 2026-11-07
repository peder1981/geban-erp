#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"

User Function T_GEBSEC_MIG()
    Local lOk := .T.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_catalogo CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS test_catalogo")
    TCSqlExec("SET search_path TO test_catalogo")

    If !GENMIGCatalogo()
        lOk := .F.
    EndIf
    If lOk .AND. !TCSecMIG()
        lOk := .F.
    EndIf

    If !GEBDBTableExists("GE2_SEC") .Or. !GEBDBTableExists("GE2_TOK") .Or. ;
       !GEBDBTableExists("SEC_PERM") .Or. !GEBDBTableExists("SEC_ADMIN_SESSION")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_catalogo CASCADE")

    If lOk
        ConOut("T_GEBSEC_MIG: PASS")
    Else
        ConOut("T_GEBSEC_MIG: FAIL")
    EndIf
Return lOk
