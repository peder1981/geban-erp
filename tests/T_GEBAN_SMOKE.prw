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

/*/{Protheus.doc} T_GEBAN_SMOKE
    Teste de fumaca do novo bootstrap Postgres de GEBAN() -- caminho
    sem credenciais (menu terminal). Nao testa o caminho de login com
    empresa/usuario/senha: GEBEXPCONTEXTO() ainda depende de GE2.EMPRESA,
    coluna aposentada no redesign multi-tenant (Fase 1) e nunca
    reintroduzida -- pendencia documentada, fora de escopo deste teste
    (ver Review Focus do plano 2026-09-24-geban-entrypoint-postgres-bootstrap.md).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 24/09/2026
    @return .T. se GEBAN() com credenciais vazias retornar .T., .F. caso
            contrario
/*/
User Function T_GEBAN_SMOKE()
    Local lOk := .T.
    Local lTmp := .F.

    lTmp := GEBAN("", "", "")
    If !lTmp
        lOk := .F.
        ConOut("T_GEBAN_SMOKE: GEBAN('','','') retornou .F.")
    EndIf

    If lOk
        ConOut("T_GEBAN_SMOKE PASS")
    Else
        ConOut("T_GEBAN_SMOKE FAIL")
    EndIf
Return lOk
