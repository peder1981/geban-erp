#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"

/*/{Protheus.doc} T_GEBDB_TENANT_2
    Teste focado de GEBDBSchemaExists()/GEBDBSetTenant() -- valida que
    uma empresa nunca provisionada e' rejeitada em vez de vazar
    silenciosamente para o schema public. Schema descartavel
    test_gebdb_tenant_2 para provisionar UMA empresa real de controle;
    o codigo "zz99zz" nunca e' provisionado, usado como caso negativo.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 2026-09-24
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBDB_TENANT_2()
    Local lOk := .T.
    Local lTmp := .F.

    If !GEBDBConecta()
        ConOut("T_GEBDB_TENANT_2: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_tenant_2 CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdb_tenant_2")
    TCSqlExec("SET search_path TO test_gebdb_tenant_2")

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
    EndIf

    // Empresa real: provisiona "t2" antes de testar.
    If lOk .AND. !GEBDBProvisionaEmpresa("t2", "Empresa Teste Tenant2")
        lOk := .F.
    EndIf

    // 1. Empresa provisionada -> GEBDBSchemaExists .T., GEBDBSetTenant .T.
    lTmp := GEBDBSchemaExists("t2")
    If !lTmp
        lOk := .F.
        ConOut("FAIL: GEBDBSchemaExists('t2') deveria ser .T.")
    EndIf
    lTmp := GEBDBSetTenant("t2")
    If !lTmp
        lOk := .F.
        ConOut("FAIL: GEBDBSetTenant('t2') deveria ser .T.")
    EndIf

    // 2. Empresa nunca provisionada -> GEBDBSchemaExists .F., GEBDBSetTenant .F.
    lTmp := GEBDBSchemaExists("zz99zz")
    If lTmp
        lOk := .F.
        ConOut("FAIL: GEBDBSchemaExists('zz99zz') deveria ser .F.")
    EndIf
    lTmp := GEBDBSetTenant("zz99zz")
    If lTmp
        lOk := .F.
        ConOut("FAIL: GEBDBSetTenant('zz99zz') deveria ser .F. (regressao do bug de vazamento)")
    EndIf

    // Reseleciona o schema "public" antes do cleanup: GE1 vive em public
    // (GEBDBProvisionaCatalogo() forca "SET search_path TO public"
    // internamente, entao GE1/GE2 nunca foram criadas em
    // test_gebdb_tenant_2), e GEBDBSetTenant('zz99zz') nao alterou o
    // search_path (falhou antes do TCSqlExec do SET search_path).
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_t2 CASCADE")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = 't2'")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_tenant_2 CASCADE")

    If lOk
        ConOut("T_GEBDB_TENANT_2 PASS")
    Else
        ConOut("T_GEBDB_TENANT_2 FAIL")
    EndIf
Return lOk
