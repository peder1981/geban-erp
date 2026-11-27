#include "totvs.ch"

/*/{Protheus.doc} GEBTUIPDV
    Frente de loja embutida no TUI: o PDV web completo (public/pdv.html)
    abre dentro da propria sessao do ERP via FwCallApp — mesmo login,
    mesma permissao LOJA, todas as 8 abas e funcionalidades do PDV
    original (venda, caixa, orcamentos, devolucao, consultas, cadastros,
    relatorios, TEF/NFC-e, crypto, vale/fiado, perifericos).

    Como funciona: o item "Frente de loja" do menu lateral (e o atalho
    da pagina Inicio) e' um modulo de acao direta — o clique dispara
    FwCallApp("pdv"), que abre src/pdv/ (index.html = symlink para
    public/pdv.html) numa nova aba da sessao. No load, o shim injetado
    (window.twebchannel) manda "PDV-INIT"; o JsToAdvpl abaixo devolve um
    token real GEBSECTOKEN da sessao TUI. A partir dai o pdv.html roda
    INALTERADO: apiGet/apiPost/apiDelete, WebSocket de perifericos e
    DANFE seguem HTTP normal para a API /api/pdv/* — sem ponte de
    traducao, sem duplicacao de regras.

    FwCallApp bloqueia ate a aba do PDV fechar; ao voltar, o token
    emitido e' revogado (GEBSECTOKENDEL).
    @type function
    @author Peder Munksgaard
    @since 27/11/2026
/*/

// Contexto da sessao para o JsToAdvpl (canal nao recebe parametros extras).
Static s_cPdvUsu := ""
Static s_cPdvEmp := ""
Static s_cPdvFil := ""
Static s_cPdvTok := ""

/*/{Protheus.doc} TUIPdvAbre
    Acao direta do menu/atalho "Frente de loja": abre o app PO-UI "pdv"
    (src/pdv/ = public/pdv.html) numa aba da sessao. FwCallApp bloqueia
    ate a aba fechar; ao voltar revoga o token emitido para o PDV.
    @type function
    @param cUsu, character, usuario logado
    @param cEmp, character, empresa da sessao
    @param cFil, character, filial da sessao
/*/
User Function TUIPdvAbre(cUsu, cEmp, cFil)
    s_cPdvUsu := cUsu
    s_cPdvEmp := cEmp
    s_cPdvFil := cFil
    FwCallApp("pdv", Nil, Nil, Nil, Nil, "GEBTUIPDV.prw")
    If !Empty(s_cPdvTok)
        GEBSECTOKENDEL(s_cPdvTok)
        s_cPdvTok := ""
    EndIf
Return Nil

/*/{Protheus.doc} JsToAdvpl
    Canal JS->AdvPL do app PDV (resolvido pelo FwCallApp via cSource).
    "PDV-INIT": emite token real da sessao TUI (GEBSECTOKEN) e devolve
    via AdvPLToJS("pdv-init") para o pdv.html pular o login local e usar
    a API /api/pdv/* por HTTP normal.
    @type function
    @param oWebChannel, object, canal TWebChannel da sessao
    @param cType, character, tipo da mensagem JS
    @param cContent, character, conteudo (nao usado no handshake)
/*/
Static Function JsToAdvpl(oWebChannel, cType, cContent)
    Local cJson := ""

    If Upper(AllTrim(cType)) == "PDV-INIT"
        If !Empty(s_cPdvTok)
            GEBSECTOKENDEL(s_cPdvTok)
        EndIf
        s_cPdvTok := GEBSECTOKEN(s_cPdvUsu, s_cPdvEmp, s_cPdvFil, "tui-pdv")
        If Empty(s_cPdvTok)
            oWebChannel:AdvPLToJS("pdv-init", '{"ok":false,"erro":"falha_token"}')
        Else
            cJson := '{"ok":true,"token":"' + s_cPdvTok + ;
                '","empresa":"' + AllTrim(s_cPdvEmp) + ;
                '","usuario":"' + AllTrim(s_cPdvUsu) + ;
                '","filial":"' + AllTrim(s_cPdvFil) + '"}'
            oWebChannel:AdvPLToJS("pdv-init", cJson)
        EndIf
    EndIf
Return Nil
