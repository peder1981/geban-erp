#include "totvs.ch"
#include "GEBEXP_CTX.prw"
#include "GEBEXP_REL_BIZ.prw"
#include "GEBEXP_REL_NUC.prw"

/*/{Protheus.doc} GEBEXP_WEB
    Tela de boas-vindas web para GEB_EXPANSAO (Task 5).
    Inicia contexto multi-empresa via GEBEXPCONTEXTO e exibe dashboard
    com:
    1. Dados da empresa logada (nome, regime, CNPJ)
    2. Resumo financeiro do mes (GEBRELFIN)
    3. Resumo fiscal (GEBRELFISCAL)
    4. Alertas do mentor (GEBRELMENTOR)
    5. Acoes rapidas ( botoes numerados para cada modulo)
    Retorna .T. se sucesso, .F. se contexto invalido.
    Notas AdvPP: ConOut p/ log; If Nil em vez de Default; GetArea/RestArea.
    @type EntryPoint tela web
    @author Peder Munksgaard
    @since 23/09/2026
    @param cEmpresaCodigo da empresa (CHAR(02))
    @param cUsuarioCodigo do usuario
    @return .T. se dashboard exibido com sucesso
/*/
User Function GEBEXP_WEB(cEmpresa, cUsuario)
    Local aArea := GetArea()
    Local lOk := .F.
    Local cFilial := "      "
    Local aCtx := {}
    Local aFin := {}
    Local aFisc := {}
    Local aMent := {}
    Local cNomeEmp := ""
    Local cRegime := ""
    Local cCnpj := ""
    Local cComp := ""
    Local nI := 0

    If cEmpresa == Nil
        cEmpresa := ""
    EndIf
    If cUsuario == Nil
        cUsuario := ""
    EndIf

    cComp := SubStr(DToS(Date()), 1, 6)

    lOk := GEBEXPCONTEXTO(cEmpresa, cFilial, cUsuario)
    If !lOk
        ConOut("[!] GEBEXP_WEB: contexto invalido para empresa " + cEmpresa)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    aCtx := GEBEXPCONTEXTO()

    // Busca nome da empresa em GE1.
    DbSelectArea("GE1")
    DbGoTop()
    While !Eof()
        If GE1->D_E_L_E_T_ == " "
            If GE1->GE1_COD == cEmpresa
                cNomeEmp := GE1->GE1_NOME
                Exit
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    // Busca regime em GE4.
    cRegime := GEBCFG("REGIME")
    If cRegime == ""
        cRegime := "SIMPLES"
    EndIf

    // Busca CNPJ ficticio a partir de GCP1 (primeiro fornecedor ativo do
    // tenant atual -- GCP1 nao tem mais coluna EMPRESA, o schema ja
    // isola por empresa, entao basta pegar a primeira linha ativa).
    aCtx := {}
    DbSelectArea("GCP1")
    DbGoTop()
    While !Eof()
        If GCP1->D_E_L_E_T_ == " "
            cCnpj := GCP1->GCP1_CNPJ
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If cCnpj == ""
        cCnpj := "000.000.000/0001-00"
    EndIf

    ConOut("")
    ConOut("============================================================")
    ConOut("  GEBAN - Sistema de Apuracao Tributaria")
    ConOut("  Dashboard Web - Boas-vindas")
    ConOut("============================================================")
    ConOut("")
    ConOut("  Empresa  : " + cEmpresa + " - " + cNomeEmp)
    ConOut("  Regime   : " + cRegime)
    ConOut("  CNPJ     : " + cCnpj)
    ConOut("  Usuario  : " + cUsuario)
    ConOut("  Data     : " + DToS(Date()))
    ConOut("")
    ConOut("------------------------------------------------------------")
    ConOut("  RESUMO FINANCEIRO (Mes: " + cComp + ")")
    ConOut("------------------------------------------------------------")

    aFin := GEBRELFIN(cEmpresa)
    If Len(aFin) >= 7
        ConOut("  Contas        : " + cValToChar(aFin[1]))
        ConOut("  A receber     : " + cValToChar(aFin[2]) + " (R$ " + cValToChar(aFin[4]) + ")")
        ConOut("  A pagar       : " + cValToChar(aFin[3]) + " (R$ " + cValToChar(aFin[5]) + ")")
        ConOut("  Saldo         : " + cValToChar(aFin[6]))
        ConOut("  Movimentos    : " + cValToChar(aFin[7]))
    Else
        ConOut("  (sem dados financeiros)")
    EndIf

    ConOut("")
    ConOut("------------------------------------------------------------")
    ConOut("  RESUMO FISCAL (Competencia: " + cComp + ")")
    ConOut("------------------------------------------------------------")

    aFisc := GEBRELFISCAL(cEmpresa, cComp)
    If Len(aFisc) >= 9
        ConOut("  Notas         : " + cValToChar(aFisc[1]))
        ConOut("  Base calculo  : " + cValToChar(aFisc[2]))
        ConOut("  IBS           : " + cValToChar(aFisc[3]))
        ConOut("  CBS           : " + cValToChar(aFisc[4]))
        ConOut("  Debito        : " + cValToChar(aFisc[5]))
        ConOut("  Credito       : " + cValToChar(aFisc[6]))
        ConOut("  Saldo derrama : " + cValToChar(aFisc[7]))
        ConOut("  Apuracoes     : " + cValToChar(aFisc[8]))
        ConOut("  Regime        : " + aFisc[9])
    Else
        ConOut("  (sem dados fiscais)")
    EndIf

    ConOut("")
    ConOut("------------------------------------------------------------")
    ConOut("  ALERTAS DO MENTOR")
    ConOut("------------------------------------------------------------")

    aMent := GEBRELMENTOR(cEmpresa)
    If Len(aMent) > 0
        For nI := 1 To Len(aMent)
            ConOut("  [" + cValToChar(nI) + "] " + cValToChar(aMent[nI][1]) + " -> " + cValToChar(aMent[nI][2]))
        Next nI
    Else
        ConOut("  (nenhum alerta do mentor)")
    EndIf

    ConOut("")
    ConOut("------------------------------------------------------------")
    ConOut("  ACOES RAPIDAS")
    ConOut("------------------------------------------------------------")
    ConOut("  [1] Nucleo     - migra GE1-GE5")
    ConOut("  [2] Fiscal     - migra GF1-GF6, apura")
    ConOut("  [3] Derrama    - migra GD1, gera guias")
    ConOut("  [4] Estoque    - migra GV1-GV3, venda")
    ConOut("  [5] Contabil   - migra GC1-GC4, lanca")
    ConOut("  [6] Financeiro - migra GFN, fluxo")
    ConOut("  [7] Compras    - migra, cotas, pedidos")
    ConOut("  [8] Relatorios - mostra relatorios completos")
    ConOut("  [9] Sair       - encerra dashboard")
    ConOut("============================================================")
    ConOut("")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk
