#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"

User Function T_GEBDB_CORE()
    Local lOk := .T.
    Local lTmp := .F.

    lTmp := GEBDBConecta()
    If !lTmp
        ConOut("FALHA: GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_core CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdb_core")
    TCSqlExec("SET search_path TO test_gebdb_core")

    // 1. Tabela nao existe ainda.
    If GEBDBTableExists("PESSOAS")
        ConOut("FAIL: PESSOAS nao deveria existir ainda")
        lOk := .F.
    EndIf

    // 2. Ensure cria a tabela.
    lTmp := GEBDBTableEnsure("PESSOAS", ;
        "CREATE TABLE PESSOAS (R_E_C_N_O_ INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, " + ;
        "D_E_L_E_T_ TEXT DEFAULT ' ', PES_NOME TEXT NOT NULL)", ;
        {"PES_NOME"})
    If !lTmp .Or. !GEBDBTableExists("PESSOAS")
        ConOut("FAIL: GEBDBTableEnsure nao criou PESSOAS")
        lOk := .F.
    EndIf

    // 3. Chamar de novo e' idempotente (nao quebra, nao duplica).
    lTmp := GEBDBTableEnsure("PESSOAS", ;
        "CREATE TABLE PESSOAS (R_E_C_N_O_ INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY, " + ;
        "D_E_L_E_T_ TEXT DEFAULT ' ', PES_NOME TEXT NOT NULL)", ;
        {"PES_NOME"})
    If !lTmp
        ConOut("FAIL: segunda chamada de GEBDBTableEnsure falhou")
        lOk := .F.
    EndIf

    // 4. Coluna faltando e' adicionada.
    lTmp := GEBDBTableEnsure("PESSOAS", "", {"PES_NOME", "PES_EMAIL"})
    If !lTmp
        ConOut("FAIL: nao adicionou PES_EMAIL")
        lOk := .F.
    EndIf

    // 6. GEBDBColumnExists() e' interface publica -- prova direta,
    // independente de GEBDBTableEnsure.
    If !GEBDBColumnExists("PESSOAS", "PES_NOME")
        ConOut("FAIL: GEBDBColumnExists deveria achar PES_NOME")
        lOk := .F.
    EndIf
    If GEBDBColumnExists("PESSOAS", "PES_INEXISTENTE")
        ConOut("FAIL: GEBDBColumnExists nao deveria achar PES_INEXISTENTE")
        lOk := .F.
    EndIf

    // 5. I1 -- prova que GEBDBTableExistsHere() e' escopado ao PRIMEIRO
    // schema do search_path, diferente de GEBDBTableExists() (que varre
    // TODOS os schemas do search_path). Cenario: tabela SONDA_A existe
    // so' em test_gebdb_core_a; search_path e' "test_gebdb_core_b,
    // test_gebdb_core_a" (A alcancavel, mas nao e' o primeiro). A
    // versao ampla deve enxergar a tabela (ela esta' em algum schema do
    // path); a versao restrita nao deve, porque uma CREATE TABLE sem
    // qualificador cairia em test_gebdb_core_b, onde ela nao existe.
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_core_a CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_core_b CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebdb_core_a")
    TCSqlExec("CREATE SCHEMA test_gebdb_core_b")
    TCSqlExec("CREATE TABLE test_gebdb_core_a.SONDA_A (X INTEGER)")
    TCSqlExec("SET search_path TO test_gebdb_core_b, test_gebdb_core_a")

    If !GEBDBTableExists("SONDA_A")
        ConOut("FAIL: GEBDBTableExists (ampla) deveria enxergar SONDA_A via search_path")
        lOk := .F.
    EndIf
    If GEBDBTableExistsHere("SONDA_A")
        ConOut("FAIL: GEBDBTableExistsHere (restrita) nao deveria enxergar SONDA_A -- ela nao esta' no primeiro schema do search_path")
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_core_a CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_core_b CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebdb_core CASCADE")

    If lOk
        ConOut("T_GEBDB_CORE: PASS")
    Else
        ConOut("T_GEBDB_CORE: FAIL")
    EndIf
Return lOk
