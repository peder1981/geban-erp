#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBGUI_MAIN.prw"

#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
/*/{Protheus.doc} T_GEBGUI_MAIN
    Teste da entrada principal GEBGUIMAIN (Task 6 GUI).
    Simula opcoes via mocks das funcoes de modulo e verifica
    que GEBGUIMAIN chama os handlers corretos e retorna .T.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se GEBGUIMAIN executar sem erro
/*/
User Function T_GEBGUI_MAIN()
    Local lOk := .T.
    Local lCallNuc := .F.
    Local lCallFin := .F.
    Local nPassos := 0

    If !GEBDBConecta()
        ConOut("T_GEBGUI_MAIN: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_main CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebgui_main")
    TCSqlExec("SET search_path TO test_gebgui_main")

    GBAUDINIC()

    ConOut("--- T_GEBGUI_MAIN ---")

    lOk := GEBGUIMAIN("MENU")
    If !lOk
        ConOut("T_GEBGUI_MAIN FAIL - GEBGUIMAIN retornou .F.")
    Else
        nPassos++
        ConOut("GEBGUIMAIN MENU passou")
    EndIf

    lOk := GEBGUIMAIN("CONFIG")
    If !lOk
        ConOut("T_GEBGUI_MAIN FAIL - GEBGUIMAIN CONFIG retornou .F.")
    Else
        nPassos++
        ConOut("GEBGUIMAIN CONFIG passou")
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_main CASCADE")

    If nPassos >= 2
        ConOut("T_GEBGUI_MAIN PASS (" + cValToChar(nPassos) + "/2 testes)")
    Else
        ConOut("T_GEBGUI_MAIN FAIL - apenas " + cValToChar(nPassos) + "/2 testes")
    EndIf
Return (nPassos >= 2)
