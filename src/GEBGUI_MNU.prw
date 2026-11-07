#include "totvs.ch"

/*/{Protheus.doc} GEBGUI_MNU
    MenuDef do modulo GUI GEBAN (Task 6 GUI).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_GEBGUIMENU -> GEBGUIMENU. O prefixo U_ nao e usado na chamada
    porque o runtime AdvPP so resolve U_ em StartJob/FindFunction;
    chamada direta U_X() da "unknown function".
    GEBGUIMENU() expoe um MenuDef com botoes navegaveis por modulo:
    Nucleo | Fiscal | Derrama | Estoque | Contabil | Financeiro |
    Compras | Config. Cada modulo aponta para uma acao Static que
    so logam via ConOut; BrowseDef reais chegam em GUI_BRW quando
    implementadas.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de Default;
    GetArea/RestArea guardados; sem BeginSql standalone; sem SELECT *,
    sem concat SQL, sem cFilial, sem IIF; so User/Static Function.
    @type Modulo de menu
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se menu inicializado sem erro
/*/
User Function GEBGUIMENU()
    Local aArea := GetArea()
    Local lOk := .T.

    ConOut("GEBGUI MENU aberto")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

Static Function MenuDef()
    Local aRotina := {}

    AAdd(aRotina, {"Nucleo", "GEBGUI nucleo()", 0, 1})
    AAdd(aRotina, {"Fiscal", "GEBGUI fiscal()", 0, 2})
    AAdd(aRotina, {"Derrama", "GEBGUI derrama()", 0, 3})
    AAdd(aRotina, {"Estoque", "GEBGUI estoque()", 0, 4})
    AAdd(aRotina, {"Contabil", "GEBGUI contabil()", 0, 5})
    AAdd(aRotina, {"Financeiro", "GEBGUI financeiro()", 0, 6})
    AAdd(aRotina, {"Compras", "GEBGUI compras()", 0, 7})
    AAdd(aRotina, {"Config", "GEBGUI config()", 0, 8})
Return aRotina

Static Function GEBGUI nucleo()
    ConOut("GEBGUI modulo Nucleo selecionado")
Return .T.

Static Function GEBGUI fiscal()
    ConOut("GEBGUI modulo Fiscal selecionado")
Return .T.

Static Function GEBGUI derrama()
    ConOut("GEBGUI modulo Derrama selecionado")
Return .T.

Static Function GEBGUI estoque()
    ConOut("GEBGUI modulo Estoque selecionado")
Return .T.

Static Function GEBGUI contabil()
    ConOut("GEBGUI modulo Contabil selecionado")
Return .T.

Static Function GEBGUI financeiro()
    ConOut("GEBGUI modulo Financeiro selecionado")
Return .T.

Static Function GEBGUI compras()
    ConOut("GEBGUI modulo Compras selecionado")
Return .T.

Static Function GEBGUI config()
    ConOut("GEBGUI modulo Config selecionado")
Return .T.
