#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"

/*/{Protheus.doc} T_GEBAUD
    Teste do sistema de auditoria GEI_AUDIT.
    Schema descartavel (test_gebaud): conecta ao Postgres via
    GEBDBConecta(), cria schema isolado, roda as migracoes de
    dependencia (GENMIG/TCSecMIG/GEBEXPmig), testa GBAUDINIC() no
    caminho "cria do zero" e no ramo "coluna obsoleta" (GEI_AUDIT
    criada manualmente sem GEI_AUDIT_TABELA -- GBAUDINIC() deve
    recriar preservando a coluna).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function T_GEBAUD()
    Local lOk := .T.
    Local aLog := {}

    If !GEBDBConecta()
        ConOut("T_GEBAUD: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebaud CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebaud")
    TCSqlExec("SET search_path TO test_gebaud")

    // Init tables (dependencias)
    If !GENMIG()
        lOk := .F.
    EndIf
    If lOk .AND. !TCSecMIG()
        lOk := .F.
    EndIf
    If lOk .AND. !GEBEXPCriaAuditoria()
        lOk := .F.
    EndIf

    // Caminho "cria do zero": GEI_AUDIT ainda nao existe neste schema.
    If lOk
        If GEBDBTableExistsHere("GEI_AUDIT")
            ConOut("T_GEBAUD: FAIL GEI_AUDIT ja deveria nao existir antes de GBAUDINIC()")
            lOk := .F.
        EndIf
    EndIf
    If lOk
        If !GBAUDINIC()
            ConOut("T_GEBAUD: FAIL GBAUDINIC() (criacao) retornou falso")
            lOk := .F.
        EndIf
        If !GEBDBTableExistsHere("GEI_AUDIT") .Or. !GEBDBColumnExists("GEI_AUDIT", "GEI_AUDIT_TABELA")
            ConOut("T_GEBAUD: FAIL GEI_AUDIT nao criada corretamente")
            lOk := .F.
        EndIf
    EndIf

    // Test audit logging
    If lOk
        GBAUDLOG("GF3", "INS", "NF-TESTE-001", "USER", "01")
        GBAUDLOG("GFN2", "ALT", "DOC-TESTE", "USER", "01")
    EndIf

    // Verify logs exist
    If lOk
        aLog := TCSqlQuery("SELECT GEI_AUDIT_TABELA FROM GEI_AUDIT WHERE D_E_L_E_T_ = ' ' AND GEI_AUDIT_EMPRESA = '01'")
        If Len(aLog) < 2
            ConOut("T_GEBAUD: expected 2 logs, got " + LTrim(Str(Len(aLog))))
            lOk := .F.
        EndIf
    EndIf

    // Ramo "coluna obsoleta": derruba GEI_AUDIT e recria manualmente
    // sem GEI_AUDIT_TABELA (schema legado pre-migracao). GBAUDINIC()
    // deve detectar via GEBDBColumnExists() e recriar a tabela com a
    // coluna presente -- esse ramo ja era coberto antes (mesmo em
    // SQLite) e nao pode regredir silenciosamente.
    If lOk
        TCSqlExec("DROP TABLE IF EXISTS GEI_AUDIT_OLD")
        TCSqlExec("DROP TABLE IF EXISTS GEI_AUDIT")
        TCSqlExec("CREATE TABLE GEI_AUDIT (" + ;
            "R_E_C_N_O_ INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, " + ;
            "D_E_L_E_T_ TEXT DEFAULT ' ', " + ;
            "GEI_AUDIT_ACAO TEXT NOT NULL)")

        If !GEBDBTableExistsHere("GEI_AUDIT")
            ConOut("T_GEBAUD: FAIL setup do ramo coluna-obsoleta nao criou GEI_AUDIT")
            lOk := .F.
        EndIf
        If lOk .AND. GEBDBColumnExists("GEI_AUDIT", "GEI_AUDIT_TABELA")
            ConOut("T_GEBAUD: FAIL setup do ramo coluna-obsoleta deveria nao ter GEI_AUDIT_TABELA")
            lOk := .F.
        EndIf

        If lOk
            If !GBAUDINIC()
                ConOut("T_GEBAUD: FAIL GBAUDINIC() (recriacao) retornou falso")
                lOk := .F.
            EndIf
        EndIf
        If lOk
            If !GEBDBColumnExists("GEI_AUDIT", "GEI_AUDIT_TABELA")
                ConOut("T_GEBAUD: FAIL GBAUDINIC() nao recriou GEI_AUDIT com GEI_AUDIT_TABELA")
                lOk := .F.
            EndIf
        EndIf
        If lOk
            If GEBDBTableExistsHere("GEI_AUDIT_OLD")
                ConOut("T_GEBAUD: FAIL GEI_AUDIT_OLD deveria ter sido descartada apos recriacao (DROP TABLE IF EXISTS incondicional)")
                lOk := .F.
            EndIf
        EndIf
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebaud CASCADE")

    If lOk
        ConOut("T_GEBAUD PASS")
    Else
        ConOut("T_GEBAUD FAIL")
    EndIf
Return lOk
