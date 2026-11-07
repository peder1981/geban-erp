#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBINIC.prw"

/*/{Protheus.doc} T_GEBINIC
    Teste de fumaca de GEBINIC() -- inicializacao catalogo (bootstrap
    Postgres). Sem schema por empresa (GEBINIC nao recebe cEmpresa):
    roda inteiramente no schema public.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 24/09/2026
    @return .T. se GEBINIC() retornar .T. e GE1/GE2/SEC_PERM existirem
            no schema public, .F. caso contrario
/*/
User Function T_GEBINIC()
    Local lOk := .T.
    Local lTmp := .F.

    If !GEBDBConecta()
        ConOut("T_GEBINIC: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")

    lTmp := GEBINIC()
    If !lTmp
        lOk := .F.
        ConOut("T_GEBINIC: GEBINIC() retornou .F.")
    EndIf

    If lOk .AND. !GEBDBTableExists("GE1")
        lOk := .F.
        ConOut("T_GEBINIC: GE1 nao existe apos GEBINIC()")
    EndIf
    If lOk .AND. !GEBDBTableExists("GE2")
        lOk := .F.
        ConOut("T_GEBINIC: GE2 nao existe apos GEBINIC()")
    EndIf
    If lOk .AND. !GEBDBTableExists("SEC_PERM")
        lOk := .F.
        ConOut("T_GEBINIC: SEC_PERM nao existe apos GEBINIC()")
    EndIf

    If lOk
        ConOut("T_GEBINIC PASS")
    Else
        ConOut("T_GEBINIC FAIL")
    EndIf
Return lOk
