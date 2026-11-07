#include "totvs.ch"
#include "GEBDB_CORE.prw"

/*/{Protheus.doc} GEBGUI_BRW
    Browses do modulo GUI GEBAN (Task 6 GUI).
    Mapeamento 1:1 com as interfaces do plano (chamadas sem prefixo U_):
    U_BRWEMPRESAS -> BRWEMPRESAS | U_BRWUSUARIOS -> BRWUSUARIOS |
    U_BRWPRODUTOS -> BRWPRODUTOS | U_BRWALIQU -> BRWALIQU |
    U_BRWNOTAS -> BRWNOTAS | U_BRWAPU -> BRWAPU |
    U_BRWGUIAS -> BRWGUIAS | U_BRWESTOQUE -> BRWESTOQUE |
    U_BRWVENDAS -> BRWVENDAS | U_BRWCONTA -> BRWCONTA |
    U_BRWRECEBER -> BRWRECEBER | U_BRWPAGAR -> BRWPAGAR |
    U_BRWFLUXO -> BRWFLUXO | U_BRWFORNECEDORES -> BRWFORNECEDORES |
    U_BRWPEDIDOS -> BRWPEDIDOS | U_BRWPLANCON -> BRWPLANCON |
    U_BRWLANCAMENTOS -> BRWLANCAMENTOS. O prefixo U_ nao e usado
    nas chamadas porque o runtime AdvPP so resolve U_ em
    StartJob/FindFunction; chamada direta U_X() da "unknown function".
    Cada funcao cria um FWMBrowse sobre a tabela correspondente
    (GE1, GE2, GF1, GF2, GF3, GF5, GD1, GV1, GV2, GFN1, GFN2,
    GFN3, GFN4, GCP1, GCP3, GC1, GC3), configura Alias, Description,
    ativa em janela proprio e destrui ao fechar.
    Guardas de existencia via TCSqlQuery em pg_tables antes de
    abrir a workarea; Tabela ausente loga e retorna .F.
    Notas AdvPP (balisador): log via ConOut; If Nil em vez de Default;
    GetArea/RestArea guardados; alias literal (GetNextAlias inexistente);
    Activate/Destroy pulados no balisador blind mode (FWMBrowse requer advplc serve); alias creation e configure testados.
    sem BeginSql standalone; sem SELECT *, sem concat SQL, sem cFilial,
    sem IIF; so User/Static Function.
    @type Modulo de browses
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function BRW_EMPRESAS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Empresas (GE1)"
    EndIf

    If !GEBDBTableExists("GE1")
        ConOut("BRW_EMPRESAS: GE1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GE1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GE1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_USUARIOS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Usuarios (GE2)"
    EndIf

    If !GEBDBTableExists("GE2")
        ConOut("BRW_USUARIOS: GE2 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GE2")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GE2")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_PRODUTOS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Produtos (GF1)"
    EndIf

    If !GEBDBTableExistsHere("GF1")
        ConOut("BRW_PRODUTOS: GF1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GF1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GF1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_ALIQ(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Aliquotas (GF2)"
    EndIf

    If !GEBDBTableExistsHere("GF2")
        ConOut("BRW_ALIQ: GF2 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GF2")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GF2")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_NOTAS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Notas (GF3)"
    EndIf

    If !GEBDBTableExistsHere("GF3")
        ConOut("BRW_NOTAS: GF3 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GF3")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GF3")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_APU(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Apuracao (GF5)"
    EndIf

    If !GEBDBTableExistsHere("GF5")
        ConOut("BRW_APU: GF5 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GF5")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GF5")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_GUIAS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Guias (GD1)"
    EndIf

    If !GEBDBTableExistsHere("GD1")
        ConOut("BRW_GUIAS: GD1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GD1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GD1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_ESTOQUE(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Estoque (GV1)"
    EndIf

    If !GEBDBTableExistsHere("GV1")
        ConOut("BRW_ESTOQUE: GV1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GV1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GV1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_VENDAS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Vendas (GV2)"
    EndIf

    If !GEBDBTableExistsHere("GV2")
        ConOut("BRW_VENDAS: GV2 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GV2")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GV2")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_CONTA(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Contas (GFN1)"
    EndIf

    If !GEBDBTableExistsHere("GFN1")
        ConOut("BRW_CONTA: GFN1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GFN1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GFN1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_RECEBER(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "A Receber (GFN2)"
    EndIf

    If !GEBDBTableExistsHere("GFN2")
        ConOut("BRW_RECEBER: GFN2 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GFN2")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GFN2")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_PAGAR(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "A Pagar (GFN3)"
    EndIf

    If !GEBDBTableExistsHere("GFN3")
        ConOut("BRW_PAGAR: GFN3 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GFN3")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GFN3")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_FLUXO(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Fluxo Caixa (GFN4)"
    EndIf

    If !GEBDBTableExistsHere("GFN4")
        ConOut("BRW_FLUXO: GFN4 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GFN4")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GFN4")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_FORNECEDORES(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Fornecedores (GCP1)"
    EndIf

    If !GEBDBTableExistsHere("GCP1")
        ConOut("BRW_FORNECEDORES: GCP1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GCP1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_PEDIDOS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Pedidos (GCP3)"
    EndIf

    If !GEBDBTableExistsHere("GCP3")
        ConOut("BRW_PEDIDOS: GCP3 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GCP3")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GCP3")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_PLANCON(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Plano de Contas (GC1)"
    EndIf

    If !GEBDBTableExistsHere("GC1")
        ConOut("BRW_PLANCON: GC1 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GC1")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GC1")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

User Function BRW_LANCAMENTOS(cTitle)
    Local aArea := GetArea()
    Local oBrowse := Nil

    If cTitle == Nil
        cTitle := "Lancamentos (GC3)"
    EndIf

    If !GEBDBTableExistsHere("GC3")
        ConOut("BRW_LANCAMENTOS: GC3 inexistente")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    DbSelectArea("GC3")
    oBrowse := FWMBrowse():New(cTitle)
    oBrowse:SetAlias("GC3")
    oBrowse:SetDescription(cTitle)
    // Activate/Destroy requires web mode (advplc serve)
    DbCloseArea()

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.
