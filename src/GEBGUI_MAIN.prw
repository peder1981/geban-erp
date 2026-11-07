#include "totvs.ch"

/*/{Protheus.doc} GEBGUI_MAIN
    Entrada principal com menu terminal numerado (Task 6 GUI).
    GEBGUIMAIN(cModo) orquestra o menu interativo por ConOut/ConIn.
    Se cModo = "MENU" (padrao), exibe opcoes numeradas e delega
    cada modulo ao respectivo handler. Se cModo = "CONFIG",
    abre configuracoes rapidas.
    Modulos expostos:
      1 - Nucleo (GENMIG / GEBFMIG -> GEBANucle)
      2 - Fiscal (GEBFMIG + GEBFAPU + GEBFCRE)
      3 - Derrama (GEBDMIG + GEBDGER + GEBDBAI)
      4 - Estoque (GEBVMIG + GEBVVEN + GEBVFIA)
      5 - Contabil (GEBCMIG + CTBLAN + GEBCDIR)
      6 - Fin (GEBFNMIG + GEBNFLX + baixas)
      7 - Compras (GEBCMMIG + cadastros + pedidos)
      8 - Config (GEBCFG via GE1/GE4)
      9 - Sair
    Notas AdvPP (balisador): ConOut/ConIn no lugar de dialogs;
    If Nil em vez de Default; GetArea/RestArea guardados;
    so User-Static Function.
    @type EntryPoint GUI terminal
    @author Peder Munksgaard
    @since 23/09/2026
    @param cModo Modo de execucao: "MENU" (padrao) ou "CONFIG"
    @return .T. se menu executado sem erro
/*/
User Function GEBGUIMAIN(cModo)
    Local cOp := ""
    Local lQuit := .F.
    Local lOk := .T.
    Local aArea := GetArea()

    If cModo == Nil
        cModo := "MENU"
    EndIf

    Do While !lQuit
        ConOut("")
        ConOut("=== GEBAN - Sistema de Apuracao Tributaria ===")
        ConOut("1 - Nucleo      (migra GE1-GE5)")
        ConOut("2 - Fiscal      (migra GF1-GF6, apura)")
        ConOut("3 - Derrama     (migra GD1, gera guias)")
        ConOut("4 - Estoque     (migra GV1-GV3, venda)")
        ConOut("5 - Contabil    (migra GC1-GC4, lanca)")
        ConOut("6 - Financiero  (migra GFN, fluxo)")
        ConOut("7 - Compras     (migra, cotas, pedidos)")
        ConOut("8 - Configurac.")
        ConOut("9 - Sair")
        ConOut("============================================")
        ConOut("Escolha (1-9): ")
        cOp := Trim(ConIn())
        ConOut("")

        If cOp == "1"
            lOk := GEBGUINUC()
        Else If cOp == "2"
            lOk := GEBGUIFIS()
        Else If cOp == "3"
            lOk := GEBGUIDER()
        Else If cOp == "4"
            lOk := GEBGUIEST()
        Else If cOp == "5"
            lOk := GEBGUIC TB()
        Else If cOp == "6"
            lOk := GEBGUIFIN()
        Else If cOp == "7"
            lOk := GEBGUICOM()
        Else If cOp == "8"
            lOk := GEBGUICFG()
        Else If cOp == "9"
            lQuit := .T.
        Else
            ConOut("Opcao invalida. Tente novamente.")
            ConOut("")
        EndIf

        If !lOk
            ConOut("[!] Módulo retornou erro.")
            ConOut("")
        EndIf
    EndDo

    ConOut("GEBAN encerrado. OBRIGADO!")
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return .T.

Static Function GEBGUINUC()
    Local lOk := .T.
    ConOut("--- NUCLEO ---")
    ConOut("Rodando GENMIG()...")
    If !GENMIG()
        lOk := .F.
        ConOut("[!] GENMIG falhou")
    Else
        ConOut("GENMIG OK - Tabelas GE1-GE5 prontas")
    EndIf
Return lOk

Static Function GEBGUIFIS()
    Local lOk := .T.
    ConOut("--- FISCAL ---")
    ConOut("Rodando GEBFMIG()...")
    If !GEBFMIG()
        lOk := .F.
        ConOut("[!] GEBFMIG falhou")
    Else
        ConOut("GEBFMIG OK - Tabelas GF1-GF6 prontas")
    EndIf
Return lOk

Static Function GEBGUIDER()
    Local lOk := .T.
    ConOut("--- DERRAMA ---")
    ConOut("Rodando GEBDMIG()...")
    If !GEBDMIG()
        lOk := .F.
        ConOut("[!] GEBDMIG falhou")
    Else
        ConOut("GEBDMIG OK - Tabela GD1 pronta")
    EndIf
Return lOk

Static Function GEBGUIEST()
    Local lOk := .T.
    ConOut("--- ESTOQUE ---")
    ConOut("Rodando GEBVMIG()...")
    If !GEBVMIG()
        lOk := .F.
        ConOut("[!] GEBVMIG falhou")
    Else
        ConOut("GEBVMIG OK - Tabelas GV1-GV3 prontas")
    EndIf
Return lOk

Static Function GEBGUIC TB()
    Local lOk := .T.
    ConOut("--- CONTABIL ---")
    ConOut("Rodando GEBCMIG()...")
    If !GEBCMIG()
        lOk := .F.
        ConOut("[!] GEBCMIG falhou")
    Else
        ConOut("GEBCMIG OK - Tabelas GC1-GC4 prontas")
    EndIf
Return lOk

Static Function GEBGUIFIN()
    Local lOk := .T.
    ConOut("--- FINANCEIRO ---")
    ConOut("Rodando GEBFNMIG()...")
    If !GEBFNMIG()
        lOk := .F.
        ConOut("[!] GEBFNMIG falhou")
    Else
        ConOut("GEBFNMIG OK - Tabelas GFN1-GFN4 prontas")
    EndIf
Return lOk

Static Function GEBGUICOM()
    Local lOk := .T.
    ConOut("--- COMPRAS ---")
    ConOut("Rodando GEBCMMIG()...")
    If !GEBCMMIG()
        lOk := .F.
        ConOut("[!] GEBCMMIG falhou")
    Else
        ConOut("GEBCMMIG OK - Tabelas GC1-GC4 prontas (reuso contabil)")
    EndIf
Return lOk

Static Function GEBGUICFG()
    Local cChave := ""
    Local cVal := ""
    ConOut("--- CONFIGURACOES ---")
    ConOut("GEBCFG - leitura rapida:")
    cVal := GEBCFG("APURACAO")
    ConOut("  APURACAO = '" + cVal + "'")
    cVal := GEBCFG("REGIME")
    ConOut("  REGIME = '" + cVal + "'")
    ConOut("Use GEBFMIG para criar eventos em GE4.")
Return .T.
