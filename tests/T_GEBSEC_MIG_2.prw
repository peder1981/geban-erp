#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"

/*/{Protheus.doc} T_GEBSEC_MIG_2
    Teste focado da tabela GE2_EMP (vinculo usuario-empresa, catalogo).
    Schema descartavel test_gebsec_mig_2.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 2026-09-24
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBSEC_MIG_2()
    Local lOk := .T.
    Local aHit := {}

    If !GEBDBConecta()
        ConOut("T_GEBSEC_MIG_2: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_mig_2 CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsec_mig_2")
    TCSqlExec("SET search_path TO test_gebsec_mig_2")

    If !GENMIGCatalogo()
        lOk := .F.
        ConOut("FAIL: GENMIGCatalogo")
    EndIf

    If lOk .AND. !TCSecMIG()
        lOk := .F.
        ConOut("FAIL: TCSecMIG")
    EndIf

    If lOk .AND. !GEBDBTableExistsHere("GE2_EMP")
        lOk := .F.
        ConOut("FAIL: GE2_EMP nao foi criada")
    EndIf

    If lOk
        TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '      ', 'T_MIG2_USR', 't2')")
        aHit := TCSqlQuery("SELECT GE2_EMP_EMPRESA FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_MIG2_USR' AND D_E_L_E_T_ = ' '")
        If Len(aHit) != 1 .OR. AllTrim(aHit[1]:GE2_EMP_EMPRESA) != "t2"
            lOk := .F.
            ConOut("FAIL: round-trip GE2_EMP")
        EndIf
        TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_MIG2_USR'")
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_mig_2 CASCADE")

    If lOk
        ConOut("T_GEBSEC_MIG_2 PASS")
    Else
        ConOut("T_GEBSEC_MIG_2 FAIL")
    EndIf
Return lOk
