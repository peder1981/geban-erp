#include "totvs.ch"

/*/{Protheus.doc} GEBSEC_RAC
    Controle de acesso baseado em cargo (RBAC) GEB_SEC (Task 5 GEB_SECURITY).
    GEBSECRBAC(cUsuario,cMenu,cItem) verifica se o usuario tem permissao
    para acessar o item dentro do menu, com base no perfil (GE2_PERFIL).
    Perfis suportados:
      "ADMIN" — acesso total a todos os menus.
      "CONTABIL" — acesso a Nucleo, Fiscal, Derrama, Contabil, Financiero, Config.
      "COMPRAS" — acesso a Compras, Nucleo, Config.
      "VISUALIZADOR" — acesso apenas a Relatorios (se implementado).
    Interface: U_GEBSECRBAC -> GEBSECRBAC(cUsuario,cMenu,cItem).
    Notas AdvPP: ConOut p/ log; TCSqlQuery so funciona p/ existencia;
    GetArea/RestArea guardados; If Nil em vez de Default; sem SELECT *.
    Atencao: usar If separados em vez de Else If (bug do compilador AdvPP
    que zera variaveis locais quando ElseIf e combinado com atribuicao).
    @type Funcao de autorizacao RBAC
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Codigo do usuario (GE2_COD)
    @param cMenu    Nome do menu (ex: "NUCLEO", "FISCAL")
    @param cItem    Item do menu (ex: "1", "2")
    @return .T. se permitido, .F. caso contrario
/*/
User Function GEBSECRBAC(cUsuario, cMenu, cItem)
    Local aArea   := GetArea()
    Local lPermit := .F.
    Local cPerfil := ""
    Local aUser   := {}
    Local cMen    := ""
    Local cItm    := ""

    // Default parametros.
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cMenu == Nil
        cMen := ""
    Else
        cMen := Upper(AllTrim(cMenu))
    EndIf
    If cItem == Nil
        cItm := ""
    Else
        cItm := Upper(AllTrim(cItem))
    EndIf

    // Busca perfil do usuario em GE2.
    aUser := TCSqlQuery("SELECT * FROM GE2 WHERE GE2_COD = " + GEBDBQuote(cUsuario) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aUser) == 0
        ConOut("GEBSECRBAC: usuario inexistente '" + cUsuario + "'")
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return .F.
    EndIf

    cPerfil := Upper(AllTrim(aUser[1]:GE2_PERFIL))

    // Verifica permissao por perfil+menu.
    // NOTE: usamos If separados em vez de Else If — bug do compilador AdvPP
    // que reseta variaveis locais quando ElseIf e combinado com atribuicao.
    If cPerfil == "ADMIN"
        lPermit := .T.
    EndIf
    If cPerfil == "CONTABIL"
        If cMen == "NUCLEO" .OR. cMen == "FISCAL" .OR. cMen == "DERRAMA" .OR. cMen == "CONTABIL" .OR. cMen == "FINANCEIRO" .OR. cMen == "CONFIG"
            lPermit := .T.
        EndIf
    EndIf
    If cPerfil == "COMPRAS"
        If cMen == "COMPRAS" .OR. cMen == "NUCLEO" .OR. cMen == "CONFIG"
            lPermit := .T.
        EndIf
    EndIf
    If cPerfil == "VISUALIZADOR"
        If cMen == "RELATORIOS"
            lPermit := .T.
        EndIf
    EndIf

    ConOut("GEBSECRBAC: user=" + cUsuario + " perfil=" + cPerfil + " menu=" + cMen + " item=" + cItm + " permit=" + Iif(lPermit, ".T.", ".F."))

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lPermit
