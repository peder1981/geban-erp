#include "totvs.ch"

/*/{Protheus.doc} GEBTUIPDV
    Frente de loja: abre o PDV web completo (public/pdv.html, rota /pdv)
    numa nova aba do navegador, ja autenticado com um token real da
    sessao TUI — mesmo usuario/empresa/filial, sem segundo login. O PDV
    traz as 8 abas e funcionalidades originais (venda, caixa,
    orcamentos, devolucao, consultas, cadastros, relatorios, TEF/NFC-e,
    crypto, vale/fiado, perifericos) chamando a API /api/pdv/* por HTTP
    normal — sem ponte de traducao, sem duplicacao de regras.

    FWOPENTAB emite o evento open-tab e RETORNA: a aba do ERP nunca
    bloqueia (o FwCallApp anterior prendia a sessao no laco do canal
    poui ate a aba fechar — a guia do ERP ficava morta e nao voltava).

    O token viaja no fragmento #tok= — nao chega ao servidor, nao fica
    em log nem em referer; o pdv.html le, limpa a barra de endereco e
    entra direto na venda. Expira pelo TTL normal do GEBSECTOKEN.
    @type function
    @author Peder Munksgaard
    @since 27/11/2026
/*/

/*/{Protheus.doc} TUIPdvAbre
    Acao direta do menu/atalho "Frente de loja": gera token real da
    sessao (GEBSECTOKEN) e abre /pdv#tok=... numa aba nova.
    @type function
    @param cUsu, character, usuario logado
    @param cEmp, character, empresa da sessao
    @param cFil, character, filial da sessao
/*/
User Function TUIPdvAbre(cUsu, cEmp, cFil)
    Local cTok := GEBSECTOKEN(cUsu, cEmp, cFil, "tui-pdv")

    If Empty(cTok)
        MsgStop("Nao foi possivel abrir a Frente de loja: falha ao gerar o token da sessao.", "PDV")
        Return Nil
    EndIf
    FWOPENTAB("/pdv#tok=" + cTok + "&u=" + AllTrim(cUsu) + "&emp=" + AllTrim(cEmp))
Return Nil
