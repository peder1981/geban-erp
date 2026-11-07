#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"

/*/{Protheus.doc} T_GENUC_MIG
    Teste da migracao idempotente GE1-GE5 (Task 5 divisao catalogo/empresa).
    Conecta ao Postgres via GEBDBConecta(), testa GENMIGCatalogo() e
    GENMIGEmpresa() separadamente para provar divisao real (nao apenas juntas).
    Verifica existencia de tabelas via GEBDBTableExists() (nao sqlite_master).
    Round-trip: INSERT/DELETE em GE4. GENMIG() testada como wrapper de compatibilidade.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GENUC_MIG()
    Local lOk := .T.
    Local lTmp := .F.
    Local cModo := ""
    Local lCat := .F.
    Local lEmp := .F.

    If !GEBDBConecta()
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_catalogo CASCADE")
    TCSqlExec("CREATE SCHEMA IF NOT EXISTS test_catalogo")
    TCSqlExec("SET search_path TO test_catalogo")

    // Test catalog-only: GENMIGCatalogo() deve criar GE1/GE2 mas nao GE3/GE4/GE5
    ConOut("T_GENUC_MIG: testando GENMIGCatalogo() separado")
    lCat := GENMIGCatalogo()
    If !lCat
        ConOut("  FALHA: GENMIGCatalogo() retornou falso")
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GE1") .Or. !GEBDBTableExists("GE2")
        ConOut("  FALHA: GE1 ou GE2 nao criados")
        lOk := .F.
    Else
        ConOut("  OK: GE1 e GE2 criados")
    EndIf
    If GEBDBTableExists("GE3") .Or. GEBDBTableExists("GE4") .Or. GEBDBTableExists("GE5")
        ConOut("  FALHA: GE3/GE4/GE5 nao deveriam existir apos GENMIGCatalogo()")
        lOk := .F.
    Else
        ConOut("  OK: GE3/GE4/GE5 nao criados (correto)")
    EndIf

    // Test enterprise-only: GENMIGEmpresa() deve criar GE3/GE4/GE5
    ConOut("T_GENUC_MIG: testando GENMIGEmpresa() separado")
    lEmp := GENMIGEmpresa()
    If !lEmp
        ConOut("  FALHA: GENMIGEmpresa() retornou falso")
        lOk := .F.
    EndIf
    If !GEBDBTableExists("GE3") .Or. !GEBDBTableExists("GE4") .Or. !GEBDBTableExists("GE5")
        ConOut("  FALHA: GE3/GE4/GE5 nao criados")
        lOk := .F.
    Else
        ConOut("  OK: GE3/GE4/GE5 criados")
    EndIf

    // Test GENMIG() as compatibility wrapper (calls both, should be idempotent now)
    ConOut("T_GENUC_MIG: testando GENMIG() wrapper")
    lTmp := GENMIG()
    If !lTmp
        ConOut("  FALHA: GENMIG() retornou falso")
        lOk := .F.
    Else
        ConOut("  OK: GENMIG() idempotente")
    EndIf

    // Verify all 5 tables exist after GENMIG()
    If !GEBDBTableExists("GE1") .Or. !GEBDBTableExists("GE2") .Or. ;
       !GEBDBTableExists("GE3") .Or. !GEBDBTableExists("GE4") .Or. ;
       !GEBDBTableExists("GE5")
        ConOut("  FALHA: nem todas as 5 tabelas existem apos GENMIG()")
        lOk := .F.
    EndIf

    // Test GEBCFG() with missing event
    ConOut("T_GENUC_MIG: testando GEBCFG()")
    cModo := GEBCFG("EV_T1_INEXISTENTE")
    If !(cModo == "")
        ConOut("  FALHA: GEBCFG() deve retornar vazio para evento inexistente")
        lOk := .F.
    Else
        ConOut("  OK: GEBCFG() retornou vazio para evento inexistente")
    EndIf

    // Round-trip hit: filial gravada com 6 espacos = retorno de
    // FWxFilial("GE4") sem RpcSetEnv (truncarFilial preenche ate 6).
    ConOut("T_GENUC_MIG: testando round-trip INSERT/DELETE")
    lTmp := TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '      ', 'EV_T1_ROUNDTRIP', 'MODO_T1')")
    If !lTmp
        ConOut("  FALHA: INSERT em GE4 falhou")
        lOk := .F.
    EndIf
    cModo := GEBCFG("EV_T1_ROUNDTRIP")
    If !(cModo == "MODO_T1")
        ConOut("  FALHA: GEBCFG() deve retornar MODO_T1 apos INSERT")
        lOk := .F.
    Else
        ConOut("  OK: GEBCFG() retornou MODO_T1 apos INSERT")
    EndIf
    lTmp := TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'EV_T1_ROUNDTRIP'")
    If !lTmp
        ConOut("  FALHA: DELETE em GE4 falhou")
        lOk := .F.
    Else
        ConOut("  OK: DELETE executado com sucesso")
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_catalogo CASCADE")

    If lOk
        ConOut("T_GENUC_MIG: PASS")
    Else
        ConOut("T_GENUC_MIG: FAIL")
    EndIf
Return lOk
