#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBGUI_MNU.prw"
#include "../src/GEBGUI_BRW.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBFIN_MIG.prw"

/*/{Protheus.doc} T_GEBGUI_BRW
    Teste basico dos browses GEBGUI (Task 6 GUI).
    Cria todos os aliases requisitados. Activate/Destroy requer advplc serve
    (erro hard no balisador blind mode) -- alias creation e browse setup sao testados.
    Log via ConOut (FWLogMsg nao existe no runtime).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os browses criarem aliases sem erro (Activate requer serve)
/*/
User Function T_GEBGUI_BRW()
    Local aArea := GetArea()
    Local lOk := .T.
    Local cTitle := "Teste GEBGUI"

    If !GEBDBConecta()
        ConOut("T_GEBGUI_BRW: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_brw CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebgui_brw")
    TCSqlExec("SET search_path TO test_gebgui_brw")
    GBAUDINIC()

    // Bootstrap das tabelas dos 17 browses no schema descartavel
    // (cada teste usa o proprio schema + as proprias migracoes).
    If !GENMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GENMIG")
    EndIf
    If !GEBFMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBFMIG")
    EndIf
    If !GEBDMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBDMIG")
    EndIf
    If !GEBVMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBVMIG")
    EndIf
    If !GEBCMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBCMIG")
    EndIf
    If !GEBFNMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBFNMIG")
    EndIf
    If !GEBCMMIG()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBCMMIG")
    EndIf

    // Menu
    If !GEBGUIMENU()
        lOk := .F.
        ConOut("T_GEBGUI_BRW FAIL: GEBGUIMENU")
    EndIf

    // Browses -- alias temporarios criados via DbSelectArea;
    // Activate/Destroy testam o ciclo completo.
    If !BRW_EMPRESAS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_USUARIOS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_PRODUTOS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_ALIQ(cTitle)
        lOk := .F.
    EndIf
    If !BRW_NOTAS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_APU(cTitle)
        lOk := .F.
    EndIf
    If !BRW_GUIAS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_ESTOQUE(cTitle)
        lOk := .F.
    EndIf
    If !BRW_VENDAS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_CONTA(cTitle)
        lOk := .F.
    EndIf
    If !BRW_RECEBER(cTitle)
        lOk := .F.
    EndIf
    If !BRW_PAGAR(cTitle)
        lOk := .F.
    EndIf
    If !BRW_FLUXO(cTitle)
        lOk := .F.
    EndIf
    If !BRW_FORNECEDORES(cTitle)
        lOk := .F.
    EndIf
    If !BRW_PEDIDOS(cTitle)
        lOk := .F.
    EndIf
    If !BRW_PLANCON(cTitle)
        lOk := .F.
    EndIf
    If !BRW_LANCAMENTOS(cTitle)
        lOk := .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_brw CASCADE")

    If lOk
        ConOut("T_GEBGUI_BRW PASS")
    Else
        ConOut("T_GEBGUI_BRW FAIL")
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk
