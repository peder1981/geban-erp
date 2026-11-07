#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBGUI_MAIN.prw"
#include "../src/GEBAN.prw"

/*/{Protheus.doc} T_GEBAN_MENU
    Teste da entrada GEBAN com inicializacao completa (bootstrap
    Postgres). Schema descartavel test_geban_menu.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function T_GEBAN_MENU()
    Local lOk := .T.

    If !GEBDBConecta()
        ConOut("T_GEBAN_MENU: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_geban_menu CASCADE")
    TCSqlExec("CREATE SCHEMA test_geban_menu")
    TCSqlExec("SET search_path TO test_geban_menu")

    If !GEBAN("", "", "")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_geban_menu CASCADE")

    If lOk
        ConOut("T_GEBAN_MENU PASS")
    Else
        ConOut("T_GEBAN_MENU FAIL")
    EndIf
Return lOk
