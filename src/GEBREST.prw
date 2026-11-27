#include "totvs.ch"
#include "GEBSEC_LOGIN.prw"
#include "GEBSEC_RBA.prw"
#include "GEBEXP_REL_NUC.prw"
#include "GEBEXP_REL_BIZ.prw"
#include "GEBFIN_FLX.prw"
#include "GEBFIS_EMI.prw"
#include "GEBSEC_POL.prw"
#include "GEBSEC_TOKEN.prw"
#include "GEBDER_GUI.prw"
#include "GEBDER_BAI.prw"
#include "GEBDER_COB.prw"
#include "GEBV_VEN.prw"
#include "GEBV_FIA.prw"
#include "GEBCTB_DIR.prw"
#include "GEBCTB_BAL.prw"
#include "GEBFIN_BAI.prw"
#include "GEBFIN_MIG.prw"
#include "GEBCOM_FOR.prw"
#include "GEBCOM_PED.prw"
#include "GEBCOM_ENT.prw"
#include "GEBFIS_APU.prw"
#include "GEBSN.prw"
#include "GEBBO.prw"
#include "GEBFIL_MIG.prw"
#include "GEBUNI_MIG.prw"
#include "GEBV_EST.prw"
#include "GEBFIN_CON.prw"

/*/{Protheus.doc} GEBREST
    Camada REST API do modulo GEBAN (Task 8 GEB_REST).
    Implementa endpoints REST sobre o banco PostgreSQL do GEBAN usando o
    patrono de roteamento interno do AdvPP (chamada direta de funcoes,
    pois nao ha WSRestServer nativo no runtime). Cada endpoint e uma
    User Function que recebe um array de parametros (query/path/body)
    e retorna um array {lOk, xDados, aErros}.
    Todas as rotas validam GEBSECRBAC(cUsuario, cMenu, cItem) antes
    de executar. Resposta padrao em JSON via GEBRESTJSON().
    Rate limiting via GE4 "SEG_RATELIMIT" (default 100 req/min por IP).
    Endpoints:
      GET  /usuarios       -> GEBRESTUSRLST(cUsuario)
      GET  /usuarios/{cod} -> GEBRESTURGET(cUsuario, cCod)
      POST /usuarios       -> GEBRESTURLSC(cUsuario, aBody) (via GEBSECCRIAUSU)
      PUT  /usuarios/{cod} -> GEBRESTUSRUPD(cUsuario, cCod, aBody)
      DEL  /usuarios/{cod} -> GEBRESTUSRRM(cUsuario, cCod)
      GET  /empresas       -> GEBRESTEMPLST(cUsuario)
      POST /empresas       -> GEBRESTEMPLSC(cUsuario, aBody)
      GET  /produtos       -> GEBRESTPRDLST(cUsuario)
      POST /produtos       -> GEBRESTPRDLSC(cUsuario, aBody)
      GET  /notas          -> GEBRESTNOTLST(cUsuario, aParams)
      POST /notas          -> GEBRESTNOTPOST(cUsuario, aBody)
      GET  /financeiro/fluxo -> GEBRESTFLXLST(cUsuario)
      GET  /financeiro/contas -> GEBRESTCONLST(cUsuario)
      GET  /fiscal/relatorio/{comp} -> GEBRESTRELFISSC(cUsuario, cComp)
      GET  /relatorios/gerencial -> GEBRESTRELGER(cUsuario)
      GET  /monitor/usuarios -> GEBRESTMONUSU(cUsuario)
      GET  /derrama/guias -> GEBRESTDERLST(cUsuario)
      GET  /estoque -> GEBRESTESTLST(cUsuario)
      GET  /estoque/vendas -> GEBRESTVENLST(cUsuario)
      GET  /contabil/lancamentos -> GEBRESTCTBLST(cUsuario)
      GET  /contabil/contas -> GEBRESTCTCLST(cUsuario)
      GET  /compras/pedidos -> GEBRESTCOMLST(cUsuario)
      GET  /compras/fornecedores -> GEBRESTFORLST(cUsuario)
      DEL  /monitor/sessao/{token} -> GEBRESTMONDES(cUsuario, cToken)
      GET  /unidades -> GEBRESTUNILST(cUsuario)
      POST /unidades -> GEBRESTUNILSC(cUsuario, aBody)
      GET  /filiais -> GEBRESTFILLST(cUsuario)
      POST /filiais -> GEBRESTFILSC(cUsuario, aBody)
      POST /vinculos -> GEBRESTVINCSC(cUsuario, aBody)
      POST /derrama/gerar|baixar|parcelar|juros|protestar -> operacao derrama
      POST /estoque/vender|fiado|fiado/juros -> operacao estoque
      POST /contabil/lancar + GET /contabil/balancete|dre/{comp}
      POST /financeiro/contas|baixar
      POST /compras/fornecedores|pedidos|itens|entradas
      POST /fiscal/apurar|creditos
      POST /fiscal/simples/config|folha|apurar|atividade|produto|exportacao|feriado -> Simples Nacional (GEBSN.prw)
      GET  /fiscal/simples/extrato/{comp} | /fiscal/simples/anual/{ano} -> relatorios do Simples
      POST|GET /bo/<modulo>/<acao> -> backoffice (GEBBO.prw: estoque, financeiro, contabil, compras, faturamento, loja)
      GET  /public/empresas -> GEBRESTPUBEMP(cUsuario)
      GET  /health         -> GEBRESTHEALTH(cUsuario)
    Interface principal: U_GEBREST -> GEBREST(cMetodo, cPath, aParams, cUsuario, cIP)
    Notas AdvPP: ConOut p/ log; If Nil em vez de Default; GetArea/RestArea;
    TCSqlQuery so funciona p/ existencia (Len > 0); workarea p/ leitura
    de valores; sem SELECT *, sem cFilial, sem IIF; so User/Static.
    Encoding: arquivo em CP-1252 (Windows-1252) -- converter se gerado em UTF-8.
    @type Camada REST API
    @author Peder Munksgaard
    @since 23/09/2026
    @param cMetodo  Metodo HTTP (GET, POST, PUT, DELETE)
    @param cPath    Path da URL (ex: "/usuarios", "/usuarios/01")
    @param aParams  Array de parametros (query string ou body parseado)
    @param cUsuario Codigo do usuario autenticado
    @param cIP      IP de origem (para rate limiting)
    @return Array {cStatus, cBody} onde cStatus e codigo HTTP e cBody e JSON
/*/
User Function GEBREST(cMetodo, cPath, aParams, cUsuario, cIP)
    Local aArea      := GetArea()
    Local cPathNorm  := ""
    Local cUsuarioN  := ""
    Local cIPN       := ""
    Local aParamsN   := {}
    Local cFunc      := ""
    Local aRes       := {}
    Local cStatus    := "200"
    Local cBody      := ""
    Local lRate      := .F.
    Local nLim       := 0
    Local cCfg       := ""
    Local aRotas     := {}
    Local aRota      := Nil
    Local nR         := 0

    // Default de parametros.
    If cMetodo == Nil
        cMetodo := "GET"
    Else
        cMetodo := Upper(AllTrim(cMetodo))
    EndIf
    If cPath == Nil
        cPathNorm := ""
    Else
        cPathNorm := AllTrim(cPath)
    EndIf
    If aParams == Nil
        aParamsN := {}
    Else
        aParamsN := aParams
    EndIf
    If cUsuario == Nil
        cUsuarioN := ""
    Else
        cUsuarioN := AllTrim(cUsuario)
    EndIf
    If cIP == Nil
        cIPN := "local"
    Else
        cIPN := AllTrim(cIP)
    EndIf

    // Rate limiting.
    cCfg := GEBCFG("SEG_RATELIMIT")
    If cCfg == ""
        nLim := 100
    Else
        nLim := Val(cCfg)
        If nLim <= 0
            nLim := 100
        EndIf
    EndIf
    lRate := GEBRESTRLIMIT(cIPN, nLim)
    If !lRate
        cStatus := "429"
        cBody := GEBRESTJSONRESP(.F., Nil, {"rate_limit_exceeded: max " + cValToChar(nLim) + " req/min por IP"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Normaliza path: remove trailing slash, lower-case para match.
    While Len(cPathNorm) > 1 .And. SubStr(cPathNorm, Len(cPathNorm), 1) == "/"
        cPathNorm := SubStr(cPathNorm, 1, Len(cPathNorm) - 1)
    EndDo

    // Roteamento por tabela (GEBRESTROTAS): 404 se nenhum caminho casa,
    // 403 se o RBAC (que olha so' o caminho) nega, 405 se o metodo nao casa.
    // RBAC roda ANTES do handler: uma escrita sem permissao nunca executa.
    If Left(cPathNorm, 1) != "/"
        cPathNorm := "/" + cPathNorm
    EndIf
    If cMetodo == "DEL"
        cMetodo := "DELETE"
    EndIf
    aRotas := GEBRESTROTAS()
    For nR := 1 To Len(aRotas)
        If GEBRESTCASA(aRotas[nR], cPathNorm)
            If aRota == Nil
                aRota := aRotas[nR]
            EndIf
            If aRotas[nR][1] == cMetodo
                aRota := aRotas[nR]
                Exit
            EndIf
        EndIf
    Next nR
    If aRota == Nil
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {"404", GEBRESTJSONRESP(.F., Nil, {"route_not_found: " + cPathNorm})}
    EndIf
    cFunc := aRota[2]
    If aRota[2] != "/health"
        If !GEBRESTRBAC(cUsuarioN, cPathNorm, cMetodo, aRota)
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return {"403", GEBRESTJSONRESP(.F., Nil, {"access_denied: usuario " + cUsuarioN + " sem permissao para " + cPathNorm})}
        EndIf
    EndIf
    If aRota[1] == cMetodo
        aRes := Eval(aRota[6], cUsuarioN, SubStr(cPathNorm, Len(aRota[2]) + 1), aParamsN, cMetodo)
    Else
        aRes := {"405", GEBRESTJSONRESP(.F., Nil, {"metodo_nao_permitido: " + cMetodo + " " + cPathNorm})}
    EndIf

    // Monta resposta.
    If Len(aRes) >= 2
        cStatus := cValToChar(aRes[1])
        cBody := aRes[2]
    Else
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"internal_error: funcao " + cFunc + " retorno invalido"})
    EndIf

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTROTAS
    Tabela de rotas do GEBREST: {metodo, caminho, (livre), menu RBAC, item RBAC,
    bloco}. Caminho terminado em "/" e' prefixo: o resto vai ao bloco como "a"
    (u = usuario, p = parametros, m = metodo). Menu "*" = livre para usuario
    autenticado; menu "" = sem RBAC proprio (/health, /bo usa GEBBOROTA).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
    @return array, rotas
/*/
Static Function GEBRESTROTAS()
Return {;
        {"GET", "/health", .F., "", "", {|u, a, p, m| GEBRESTHEALTH(u)}},;
        {"GET", "/public/empresas", .F., "*", "", {|u, a, p, m| GEBRESTPUBEMP(u)}},;
        {"GET", "/usuarios", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTUSRLST(u)}},;
        {"POST", "/usuarios", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTURLSC(u, p)}},;
        {"GET", "/usuarios/", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTURGET(u, a)}},;
        {"PUT", "/usuarios/", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTUSRUPD(u, a, p)}},;
        {"DELETE", "/usuarios/", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTUSRRM(u, a)}},;
        {"GET", "/empresas", .F., "CONFIG", "EMPRES", {|u, a, p, m| GEBRESTEMPLST(u)}},;
        {"POST", "/empresas", .F., "CONFIG", "EMPRES", {|u, a, p, m| GEBRESTEMPLSC(u, p)}},;
        {"GET", "/unidades", .F., "CONFIG", "EMPRES", {|u, a, p, m| GEBRESTUNILST(u)}},;
        {"POST", "/unidades", .F., "CONFIG", "EMPRES", {|u, a, p, m| GEBRESTUNILSC(u, p)}},;
        {"GET", "/filiais", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTFILLST(u)}},;
        {"POST", "/filiais", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTFILSC(u, p)}},;
        {"POST", "/vinculos", .F., "SEGURANCA", "USUARI", {|u, a, p, m| GEBRESTVINCSC(u, p)}},;
        {"GET", "/produtos", .F., "FISCAL", "PRODUT", {|u, a, p, m| GEBRESTPRDLST(u)}},;
        {"POST", "/produtos", .F., "FISCAL", "PRODUT", {|u, a, p, m| GEBRESTPRDLSC(u, p)}},;
        {"GET", "/notas", .F., "FISCAL", "NOTAS", {|u, a, p, m| GEBRESTNOTLST(u, p)}},;
        {"POST", "/notas", .F., "FISCAL", "NOTAS", {|u, a, p, m| GEBRESTNOTPOST(u, p)}},;
        {"GET", "/fiscal/relatorio/", .F., "FISCAL", "RELATF", {|u, a, p, m| GEBRESTRELFISSC(u, a)}},;
        {"POST", "/fiscal/apurar", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTFISAPU(u, p)}},;
        {"POST", "/fiscal/creditos", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTFISCRE(u, p)}},;
        {"POST", "/fiscal/simples/config", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNCFG(u, p)}},;
        {"POST", "/fiscal/simples/folha", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNFOL(u, p)}},;
        {"POST", "/fiscal/simples/apurar", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNAPU(u, p)}},;
        {"POST", "/fiscal/simples/atividade", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNRESP(GEBSNATV(GEBRESTSNARG(p, 1), GEBRESTSNARG(p, 2), GEBRESTSNARG(p, 3)), {})}},;
        {"POST", "/fiscal/simples/produto", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNRESP(GEBSNPRD(GEBRESTSNARG(p, 1), GEBRESTSNARG(p, 2), GEBRESTSNARG(p, 3), GEBRESTSNARG(p, 4)), {})}},;
        {"POST", "/fiscal/simples/exportacao", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNRESP(GEBSNEXP(GEBRESTSNARG(p, 1), GEBRESTSNARG(p, 2)), {})}},;
        {"POST", "/fiscal/simples/feriado", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNRESP(GEBSNFER(GEBRESTSNARG(p, 1), GEBRESTSNARG(p, 2)), {})}},;
        {"GET", "/fiscal/simples/extrato/", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNREL(GEBSNEXTRATO(a))}},;
        {"GET", "/fiscal/simples/anual/", .F., "FISCAL", "APURA", {|u, a, p, m| GEBRESTSNREL(GEBSNANUAL(a))}},;
        {"GET", "/financeiro/fluxo", .F., "FINANCEIRO", "FLUXO", {|u, a, p, m| GEBRESTFLXLST(u)}},;
        {"GET", "/financeiro/contas", .F., "FINANCEIRO", "FLUXO", {|u, a, p, m| GEBRESTCONLST(u)}},;
        {"POST", "/financeiro/contas", .F., "FINANCEIRO", "FLUXO", {|u, a, p, m| GEBRESTFINCON(u, p)}},;
        {"POST", "/financeiro/baixar", .F., "FINANCEIRO", "FLUXO", {|u, a, p, m| GEBRESTFINBAI(u, p)}},;
        {"GET", "/relatorios/gerencial", .F., "RELATORIOS", "GERENC", {|u, a, p, m| GEBRESTRELGER(u)}},;
        {"GET", "/monitor/usuarios", .F., "MONITOR", "MONITR", {|u, a, p, m| GEBRESTMONUSU(u)}},;
        {"DELETE", "/monitor/sessao/", .F., "MONITOR", "MONITR", {|u, a, p, m| GEBRESTMONDES(u, a)}},;
        {"GET", "/derrama/guias", .F., "DERRAMA", "GUIAS", {|u, a, p, m| GEBRESTDERLST(u)}},;
        {"POST", "/derrama/gerar", .F., "DERRAMA", "GUIAS", {|u, a, p, m| GEBRESTDERGER(u, p)}},;
        {"POST", "/derrama/baixar", .F., "DERRAMA", "GUIAS", {|u, a, p, m| GEBRESTDERBAI(u, p)}},;
        {"POST", "/derrama/parcelar", .F., "DERRAMA", "GUIAS", {|u, a, p, m| GEBRESTDERPAR(u, p)}},;
        {"POST", "/derrama/juros", .F., "DERRAMA", "GUIAS", {|u, a, p, m| GEBRESTDERJUR(u, p)}},;
        {"POST", "/derrama/protestar", .F., "DERRAMA", "GUIAS", {|u, a, p, m| GEBRESTDERPRO(u, p)}},;
        {"GET", "/estoque", .F., "ESTOQUE", "ESTOQ", {|u, a, p, m| GEBRESTESTLST(u)}},;
        {"GET", "/estoque/vendas", .F., "ESTOQUE", "ESTOQ", {|u, a, p, m| GEBRESTVENLST(u)}},;
        {"POST", "/estoque/vender", .F., "ESTOQUE", "ESTOQ", {|u, a, p, m| GEBRESTESTVEN(u, p)}},;
        {"POST", "/estoque/fiados", .F., "ESTOQUE", "ESTOQ", {|u, a, p, m| GEBRESTESTFIA(u, p)}},;
        {"POST", "/estoque/fiados/juros", .F., "ESTOQUE", "ESTOQ", {|u, a, p, m| GEBRESTESTFIJ(u, p)}},;
        {"GET", "/contabil/lancamentos", .F., "CONTABIL", "LANCTO", {|u, a, p, m| GEBRESTCTBLST(u)}},;
        {"GET", "/contabil/contas", .F., "CONTABIL", "LANCTO", {|u, a, p, m| GEBRESTCTCLST(u)}},;
        {"POST", "/contabil/lancar", .F., "CONTABIL", "LANCTO", {|u, a, p, m| GEBRESTCTBDIR(u, p)}},;
        {"GET", "/contabil/balancete/", .F., "CONTABIL", "LANCTO", {|u, a, p, m| GEBRESTCTBBAL(u, a)}},;
        {"GET", "/contabil/dre/", .F., "CONTABIL", "LANCTO", {|u, a, p, m| GEBRESTCTBDRE(u, a)}},;
        {"GET", "/compras/pedidos", .F., "COMPRAS", "PEDID", {|u, a, p, m| GEBRESTCOMLST(u)}},;
        {"POST", "/compras/pedidos", .F., "COMPRAS", "PEDID", {|u, a, p, m| GEBRESTCOMPED(u, p)}},;
        {"GET", "/compras/fornecedores", .F., "COMPRAS", "PEDID", {|u, a, p, m| GEBRESTFORLST(u)}},;
        {"POST", "/compras/fornecedores", .F., "COMPRAS", "PEDID", {|u, a, p, m| GEBRESTCOMFOR(u, p)}},;
        {"POST", "/compras/itens", .F., "COMPRAS", "PEDID", {|u, a, p, m| GEBRESTCOMIT(u, p)}},;
        {"POST", "/compras/entradas", .F., "COMPRAS", "PEDID", {|u, a, p, m| GEBRESTCOMENT(u, p)}},;
        {"GET", "/bo/", .F., "", "", {|u, a, p, m| GEBRESTBO(m, a, p, u)}},;
        {"POST", "/bo/", .F., "", "", {|u, a, p, m| GEBRESTBO(m, a, p, u)}}}

/*/{Protheus.doc} GEBRESTCASA
    O caminho pedido casa com a rota? Exato, ou prefixo (rota terminada em
    "/") com sufixo nao vazio.
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function GEBRESTCASA(aRota, cPath)
    If Right(aRota[2], 1) == "/"
        Return Len(cPath) > Len(aRota[2]) .And. Left(cPath, Len(aRota[2])) == aRota[2]
    EndIf
Return cPath == aRota[2]

// ===== UTILIDADES =====

/*/{Protheus.doc} GEBRESTRBAC
    Verifica RBAC para um endpoint REST. Retorna .T. se permitido.
    Mapeia paths para menus_itens do GEBSECRBAC.
    @type Funcao auxiliar RBAC
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Codigo do usuario
    @param cPath Path da URL
    @param cMetodo Metodo HTTP
    @return .T. se permitido, .F. caso contrario
/*/
Static Function GEBRESTRBAC(cUsuario, cPath, cMetodo, aRota)
    Local cMen    := aRota[4]
    Local cItm    := aRota[5]
    Local aBo     := {}
    If cUsuario == ""
        Return .F.
    EndIf
    If cMen == "*"
        Return .T.
    EndIf
    If SubStr(cPath, 1, 4) == "/bo/"
        aBo := GEBBOROTA(SubStr(cPath, 5), cMetodo)
        If Len(aBo) == 0
            // Rota inexistente passa para o despacho, que responde 404.
            Return .T.
        EndIf
        cMen := aBo[3]
        cItm := aBo[4]
    EndIf
    If cMen == ""
        Return .F.
    EndIf
    // Escrita em usuarios/vinculos/empresas/unidades/filiais exige perfil
    // ADMIN (ou super): permissao de VER usuarios nao da' direito de criar
    // ou promover usuario.
    If (cMen == "SEGURANCA" .Or. cMen == "CONFIG") .And. Upper(AllTrim(cValToChar(cMetodo))) != "GET"
        If !GEBSECISSUPER(cUsuario) .And. Len(TCSqlQuery("SELECT GE2_COD FROM public.GE2 WHERE GE2_COD = " + GEBDBQuote(cUsuario) + " AND UPPER(TRIM(GE2_PERFIL)) = 'ADMIN' AND D_E_L_E_T_ = ' '")) == 0
            Return .F.
        EndIf
    EndIf
Return GEBSECRBAC(cUsuario, cMen, cItm)

/*/{Protheus.doc} GEBRESTJSONRESP
    Monta resposta JSON padrao.
    @type Funcao auxiliar JSON
    @author Peder Munksgaard
    @since 23/09/2026
    @param lOk    .T. se sucesso, .F. se erro
    @param xDados Dados a retornar (array ou nil)
    @param aErros Array de mensagens de erro
    @return String JSON
/*/
Static Function GEBRESTJSONRESP(lOk, xDados, aErros)
    Local cResp   := ""
    Local cTs     := ""
    Local cQ      := Chr(34)
    Local aErr    := {}
    Local nIdx    := 0
    Local cPart   := ""

    // Timestamp.
    cTs := DToS(Date()) + "T" + Time() + "Z"

    cResp := "{" + cQ + "status" + cQ + ":" + cQ
    If lOk
        cResp := cResp + "ok"
    Else
        cResp := cResp + "error"
    EndIf
    cResp := cResp + cQ
    cResp := cResp + "," + cQ + "timestamp" + cQ + ":" + cQ + cTs + cQ

    // dados.
    If xDados != Nil
        cResp := cResp + "," + cQ + "dados" + cQ + ":" + GEBRESTJSONENC(xDados)
    Else
        cResp := cResp + "," + cQ + "dados" + cQ + ":null"
    EndIf

    // erros.
    If aErros != Nil .And. Len(aErros) > 0
        cResp := cResp + "," + cQ + "erros" + cQ + ":"
        cResp := cResp + "["
        For nIdx := 1 To Len(aErros)
            If nIdx > 1
                cResp := cResp + ","
            EndIf
            cResp := cResp + cQ + GEBRESTJSONESCAPE(cValToChar(aErros[nIdx])) + cQ
        Next nIdx
        cResp := cResp + "]"
    Else
        cResp := cResp + "," + cQ + "erros" + cQ + ":[]"
    EndIf

    cResp := cResp + "}"
Return cResp

/*/{Protheus.doc} GEBRESTJSONENC
    Codifica um array/valor para JSON. Suporta arrays aninhados, numbers,
    strings, logicals e nil.
    @type Funcao auxiliar JSON
    @author Peder Munksgaard
    @since 23/09/2026
    @param xVal Valor a codificar
    @return String JSON
/*/
Static Function GEBRESTJSONENC(xVal)
    Local cRet := ""
    Local nIdx := 0
    Local cQ   := Chr(34)

    If xVal == Nil
        Return "null"
    EndIf

    // ValType() (tipo do VALOR) -- nao Type(), que recebe uma EXPRESSAO
    // em string e aqui devolvia "U" para tudo: todo valor caia no
    // default cValToChar() e arrays/chaves nao viravam JSON de verdade.
    // Array.
    If ValType(xVal) == "A"
        cRet := "["
        For nIdx := 1 To Len(xVal)
            If nIdx > 1
                cRet := cRet + ","
            EndIf
            cRet := cRet + GEBRESTJSONENC(xVal[nIdx])
        Next nIdx
        cRet := cRet + "]"
        Return cRet
    EndIf

    // Logical.
    If ValType(xVal) == "L"
        If xVal
            Return "true"
        Else
            Return "false"
        EndIf
    EndIf

    // Numeric.
    If ValType(xVal) == "N"
        Return cValToChar(xVal)
    EndIf

    // Character.
    If ValType(xVal) == "C"
        Return cQ + GEBRESTJSONESCAPE(xVal) + cQ
    EndIf

    // Default: tostring.
Return cQ + GEBRESTJSONESCAPE(cValToChar(xVal)) + cQ

/*/{Protheus.doc} GEBRESTJSONESCAPE
    Escapa caracteres especiais em string para JSON.
    @type Funcao auxiliar JSON
    @author Peder Munksgaard
    @since 23/09/2026
    @param cStr String a escapar
    @return String escapada
/*/
Static Function GEBRESTJSONESCAPE(cStr)
    Local cRet    := ""
    Local nLen    := 0
    Local nIdx    := 0
    Local cChar   := ""
    Local cQ      := Chr(34)
    Local cBS     := Chr(92)

    If cStr == Nil
        Return ""
    EndIf

    nLen := Len(cStr)
    cRet := ""
    For nIdx := 1 To nLen
        cChar := SubStr(cStr, nIdx, 1)
        If cChar == cQ
            cRet := cRet + cBS + cQ
        Else
            If cChar == cBS
                cRet := cRet + cBS + cBS
            Else
                If cChar == Chr(8)
                    cRet := cRet + cBS + "b"
                Else
                    If cChar == Chr(10)
                        cRet := cRet + cBS + "n"
                    Else
                        If cChar == Chr(13)
                            cRet := cRet + cBS + "r"
                        Else
                            If cChar == Chr(9)
                                cRet := cRet + cBS + "t"
                            Else
                                cRet := cRet + cChar
                            EndIf
                        EndIf
                    EndIf
                EndIf
            EndIf
        EndIf
    Next nIdx
Return cRet

/*/{Protheus.doc} GEBRESTRLIMIT
    Rate limiting simples por IP. UsaGE4 "SEG_RATELIMIT" como maximo.
    Mantem contador em memoria via tabela GE_REST_RL (criada sob demanda).
    @type Funcao auxiliar rate limit
    @author Peder Munksgaard
    @since 23/09/2026
    @param cIP IP de origem
    @param nLim Maximo de requicoes por minuto
    @return .T. se dentro do limite, .F. caso contrario
/*/
Static Function GEBRESTRLIMIT(cIP, nLim)
    Local aArea     := GetArea()
    Local lOk       := .T.
    Local cMin      := ""
    Local cKey      := ""
    Local aHit      := {}
    Local nCnt      := 0
    Local aChk      := {}
    Local cData     := ""
    Local cHora     := ""
    Local cSeg      := ""
    Local nSeg      := 0
    Local cMinAct   := ""

    If cIP == Nil
        cIP := "local"
    EndIf
    If nLim == Nil
        nLim := 100
    EndIf

    cData := DToS(Date())
    cHora := Time()
    cSeg := SubStr(cHora, 1, 5) // MM:SS -> apenas minutos

    cKey := cIP + "|" + cData + "|" + cSeg

    // Guarda: tabela pode nao existir.
    If !GEBDBTableExistsHere("GE_REST_RL")
        TCSqlExec("CREATE TABLE IF NOT EXISTS GE_REST_RL (R_E_C_N_O_ INTEGER GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY, D_E_L_E_T_ TEXT DEFAULT ' ', RL_KEY TEXT NOT NULL, RL_CNT INTEGER NOT NULL DEFAULT 0, RL_MIN TEXT NOT NULL)")
    EndIf

    // Busca registro atual.
    aHit := TCSqlQuery("SELECT * FROM GE_REST_RL WHERE RL_KEY = " + GEBDBQuote(cKey) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aHit) > 0
        // TCSqlQuery devolve coluna INTEGER como Character neste runtime;
        // Val() converte antes da aritmetica, senao "nCnt + 1" concatena
        // strings ("1"+1 -> "11") em vez de somar (bug real, achado via
        // Task 6 GEB_REST: nCnt virava 1,11,111,1111... e estourava
        // nLim por comparacao textual coagida).
        If ValType(aHit[1]:RL_CNT) == "C"
            nCnt := Val(aHit[1]:RL_CNT)
        Else
            nCnt := aHit[1]:RL_CNT
        EndIf
        If nCnt >= nLim
            lOk := .F.
        Else
            nCnt := nCnt + 1
            TCSqlExec("UPDATE GE_REST_RL SET RL_CNT = " + cValToChar(nCnt) + " WHERE RL_KEY = " + GEBDBQuote(cKey) + " AND D_E_L_E_T_ = ' '")
        EndIf
    Else
        TCSqlExec("INSERT INTO GE_REST_RL (D_E_L_E_T_, RL_KEY, RL_CNT, RL_MIN) VALUES (' ', " + GEBDBQuote(cKey) + ", 1, " + GEBDBQuote(cSeg) + ")")
    EndIf

    // Cleanup: remove registros com mais de 2 minutos.
    TCSqlExec("DELETE FROM GE_REST_RL WHERE D_E_L_E_T_ = ' ' AND RL_MIN < " + GEBDBQuote(cSeg) + "")

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return lOk

// ===== ENDPOINTS =====

/*/{Protheus.doc} GEBRESTHEALTH
    Endpoint /health. Retorna status do servico.
    @type Endpoint GET /health
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTHEALTH(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aChk    := {}
    Local nTbls   := 0
    Local cTs     := ""

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    cTs := DToS(Date()) + "T" + Time() + "Z"

    If GEBDBTableExists("GE1")
        nTbls := 1
    EndIf

    aRes := {"status", "ok", "timestamp", cTs, "tables", nTbls, "service", "GEBREST"}
    cBody := GEBRESTJSONRESP(.T., aRes, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTUSRLST
    Endpoint GET /usuarios. Lista usuarios GE2 filtrados por empresa
    (se admin, lista todas).
    @type Endpoint GET /usuarios
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTUSRLST(cUsuario)
    Local lTodos  := .F.
    Local aVinc   := {}
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    Local aHit    := {}
    Local aChk    := {}
    Local cFil    := ""
    Local nIdx    := 0

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    If !GEBDBTableExists("GE2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Fora o super, so' usuarios vinculados a empresa da sessao (GE2 e'
    // catalogo global; o vinculo usuario-empresa fica em GE2_EMP).
    lTodos := GEBSECISSUPER(cUsuario)
    aVinc := GEBRESTUSRDAEMP()
    DbSelectArea("GE2")
    DbGoTop()
    While !Eof()
        If GE2->D_E_L_E_T_ == " "
            If lTodos .Or. AScan(aVinc, {|c| c == Upper(AllTrim(GE2->GE2_COD))}) > 0
                AAdd(aDados, {GE2->GE2_COD, GE2->GE2_NOME, GE2->GE2_PERFIL})
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

// GEBRESTUSRDAEMP() -> codigos (maiusculos) dos usuarios vinculados a
// empresa da sessao.
Static Function GEBRESTUSRDAEMP()
    Local aRet := {}
    Local aRows := TCSqlQuery("SELECT DISTINCT UPPER(TRIM(GE2_EMP_USUARIO)) AS U FROM public.GE2_EMP WHERE LOWER(TRIM(GE2_EMP_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " AND D_E_L_E_T_ = ' '")
    AEval(aRows, {|o| AAdd(aRet, AllTrim(cValToChar(o:U)))})
Return aRet

/*/{Protheus.doc} GEBRESTURGET
    Endpoint GET /usuarios/{cod}. Retorna usuario especifico.
    @type Endpoint GET /usuarios/{cod}
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param cCod Codigo do usuario
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTURGET(cUsuario, cCod)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    Local aChk    := {}
    Local lAchou  := .F.

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cCod == Nil
        cCod := ""
    EndIf

    If cCod == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"codigo_usuario_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If !GEBDBTableExists("GE2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    DbSelectArea("GE2")
    DbGoTop()
    While !Eof()
        If GE2->D_E_L_E_T_ == " "
            If GE2->GE2_COD == cCod
                // Fora o super, usuario de outra empresa "nao existe" (404).
                If GEBSECISSUPER(cUsuario) .Or. AScan(GEBRESTUSRDAEMP(), {|c| c == Upper(AllTrim(cCod))}) > 0
                    aDados := {GE2->GE2_COD, GE2->GE2_NOME, GE2->GE2_PERFIL}
                    lAchou := .T.
                    Exit
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If !lAchou
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"usuario_nao_encontrado: " + cCod})
    Else
        cBody := GEBRESTJSONRESP(.T., aDados, {})
    EndIf

    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTURLSC
    Endpoint POST /usuarios. Cria usuario que consegue fazer login de
    verdade: delega a gravacao a GEBSECCRIAUSU() (src/GEBSEC_LOGIN.prw),
    que cria GE2 + GE2_SEC (salt aleatorio, hash Argon2id) + um vinculo
    GE2_EMP por empresa do body.
    Body: {cCod, cNome, cPerfil, cSenha, aEmpresas[, cFilial]} -- aEmpresas e' um
    array de codigos de empresa (GE1_COD) ja' provisionadas (schema
    emp_<cod>); uma string unica tambem e' aceita. Pelo menos uma
    empresa e' obrigatoria (usuario sem GE2_EMP nao consegue logar).
    Endpoint de CRIACAO pura: GEBSECCRIAUSU() e' upsert (redefine senha
    de usuario existente), entao a duplicidade e' checada aqui antes
    (409). A conta ADMIN nunca e' tocada por este endpoint (403).
    Status: 201 criado; 400 validacao; 403 ADMIN; 409 duplicado; 500
    falha de gravacao.
    @type Endpoint POST /usuarios
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body da requisicao {cCod, cNome, cPerfil, cSenha, aEmpresas}
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTURLSC(cUsuario, aBody)
    Local aArea    := GetArea()
    Local aRes     := {}
    Local cStatus  := "201"
    Local cBody    := ""
    Local cCod     := ""
    Local cNome    := ""
    Local cPerfil  := ""
    Local cSenha   := ""
    Local xEmps    := Nil
    Local aEmps    := {}
    Local aFil     := {}
    Local cFilP    := ""
    Local cEmpC    := ""
    Local cErro    := ""
    Local aPol     := {}
    Local aHit     := {}
    Local nI       := 0
    Local lOk      := .F.
    Local cEmpT    := ""

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf

    // Extrai campos do body.
    If Len(aBody) >= 1
        cCod := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cNome := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        cPerfil := Upper(AllTrim(cValToChar(aBody[3])))
    EndIf
    If Len(aBody) >= 4
        cSenha := AllTrim(cValToChar(aBody[4]))
    EndIf
    If Len(aBody) >= 5
        xEmps := aBody[5]
    EndIf
    If Len(aBody) >= 6
        cFilP := AllTrim(cValToChar(aBody[6]))
    EndIf

    // Validacoes (400/403), todas antes de qualquer SQL com cCod.
    If cCod == ""
        cStatus := "400"
        cErro := "codigo_usuario_vazio"
    ElseIf !GEBDBSchemaValido(cCod)
        cStatus := "400"
        cErro := "codigo_usuario_invalido: use letras, digitos e _ (ate 30)"
    ElseIf GEBSECISSUPER(cCod)
        cStatus := "403"
        cErro := "conta_super_protegida"
    ElseIf cNome == ""
        cStatus := "400"
        cErro := "nome_usuario_vazio"
    ElseIf cSenha == ""
        cStatus := "400"
        cErro := "senha_vazia"
    EndIf
    If cErro == ""
        If cPerfil != ""
            If !GEBDBSchemaValido(cPerfil)
                cStatus := "400"
                cErro := "perfil_invalido"
            EndIf
        EndIf
    EndIf
    If cErro == ""
        If cFilP != ""
            If !GEBDBSchemaValido(cFilP)
                cStatus := "400"
                cErro := "filial_invalida"
            EndIf
        EndIf
    EndIf
    If cErro == ""
        If cFilP != ""
            If GEBDBTableExistsHere("GEF1")
                aFil := TCSqlQuery("SELECT GEF1_COD FROM GEF1 WHERE D_E_L_E_T_ = ' ' LIMIT 1")
                If Len(aFil) > 0
                    aFil := TCSqlQuery("SELECT GEF1_COD FROM GEF1 WHERE GEF1_COD = " + GEBDBQuote(cFilP) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
                    If Len(aFil) == 0
                        cStatus := "400"
                        cErro := "filial_nao_cadastrada: cadastre " + cFilP + " em /filiais antes"
                    EndIf
                EndIf
            EndIf
        EndIf
    EndIf
    If cErro == ""
        aPol := GEBSECPOL_VERIFICA(cSenha)
        If Len(aPol) >= 2
            If !(aPol[1])
                cStatus := "400"
                cErro := "politica_senha: " + cValToChar(aPol[2])
            EndIf
        EndIf
    EndIf
    If cErro == ""
        If ValType(xEmps) == "A"
            For nI := 1 To Len(xEmps)
                AAdd(aEmps, xEmps[nI])
            Next nI
        ElseIf ValType(xEmps) == "C"
            If AllTrim(xEmps) != ""
                AAdd(aEmps, xEmps)
            EndIf
        EndIf
        If Len(aEmps) == 0
            cStatus := "400"
            cErro := "empresas_vazias: informe ao menos uma empresa (5o campo do body)"
        EndIf
    EndIf
    If cErro == ""
        For nI := 1 To Len(aEmps)
            If ValType(aEmps[nI]) != "C"
                cStatus := "400"
                cErro := "empresa_invalida na posicao " + cValToChar(nI)
                Exit
            EndIf
            cEmpC := Lower(AllTrim(aEmps[nI]))
            If !GEBDBSchemaValido(cEmpC)
                cStatus := "400"
                cErro := "empresa_invalida na posicao " + cValToChar(nI)
                Exit
            EndIf
            If !GEBDBSchemaExists(cEmpC)
                cStatus := "400"
                cErro := "empresa_nao_provisionada: " + cEmpC
                Exit
            EndIf
            aEmps[nI] := cEmpC
        Next nI
    EndIf
    If cErro == ""
        If !GEBSECISSUPER(cUsuario)
            cEmpT := GEBRESTTENANT()
            If !GEBSECPODE(cUsuario, "", .F.)
                cStatus := "403"
                cErro := "acesso_negado: so ADMIN da empresa (ou super) cadastra usuarios"
            EndIf
            For nI := 1 To Len(aEmps)
                If cErro == "" .And. aEmps[nI] != Lower(AllTrim(cEmpT))
                    cStatus := "403"
                    cErro := "fora_do_escopo: admin cadastra usuarios so na propria empresa"
                EndIf
            Next nI
        EndIf
    EndIf
    If cErro != ""
        cBody := GEBRESTJSONRESP(.F., Nil, {cErro})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If !GEBDBTableExists("GE2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Duplicidade (cCod ja' validado por GEBDBSchemaValido acima).
    aHit := TCSqlQuery("SELECT GE2_COD FROM public.GE2 WHERE GE2_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aHit) > 0
        cStatus := "409"
        cBody := GEBRESTJSONRESP(.F., Nil, {"usuario_duplicado: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Grava GE2 + GE2_SEC + GE2_EMP. lPermiteAdmin fica no padrao .F.
    If cPerfil == ""
        lOk := GEBSECCRIAUSU(cCod, cSenha, aEmps, cNome, Nil, Nil, cFilP)
    Else
        lOk := GEBSECCRIAUSU(cCod, cSenha, aEmps, cNome, cPerfil, Nil, cFilP)
    EndIf
    If !lOk
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"falha_criar_usuario: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    aRes := {cCod, cNome, cPerfil, aEmps}
    cBody := GEBRESTJSONRESP(.T., aRes, {})

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTUSRUPD
    Endpoint PUT /usuarios/{cod}. Atualiza usuario.
    @type Endpoint PUT /usuarios/{cod}
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param cCod Codigo do usuario
    @param aBody Body da requisicao
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTUSRUPD(cUsuario, cCod, aBody)
    Local aArea    := GetArea()
    Local aRes     := {}
    Local cStatus  := "200"
    Local cBody    := ""
    Local cNome    := ""
    Local cPerfil  := ""
    Local cSenha   := ""
    Local cFil     := ""
    Local lAchou   := .F.
    Local aPol     := {}
    Local cHash    := ""
    Local cSalt    := ""
    Local cEmpT    := ""
    Local aScope   := {}
    Local aChk     := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cCod == Nil
        cCod := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf

    cFil := FWxFilial("GE2")

    If cCod == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"codigo_usuario_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Mesma guarda de GEBSECCRIAUSU() (src/GEBSEC_LOGIN.prw): PUT nunca
    // altera a conta ADMIN via REST -- evita reset/promocao acidental de
    // ADMIN por este caminho (POST ja' e' bloqueado pela propria guarda
    // de GEBSECCRIAUSU, mas PUT nao chama essa funcao).
    If GEBSECISSUPER(cCod)
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"acesso_negado: alteracao da conta super via REST nao permitida"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If !GEBDBTableExists("GE2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Busca usuario.
    DbSelectArea("GE2")
    DbGoTop()
    While !Eof()
        If GE2->D_E_L_E_T_ == " " .And. GE2->GE2_COD == cCod
            lAchou := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If !lAchou
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"usuario_nao_encontrado: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    // Regra unica (GEBSECPODE): ADMIN da empresa da sessao, alvo vinculado
    // so' a ela e nunca o super. Usuario compartilhado com outra empresa
    // so' o super altera (senha/perfil sao globais).
    If !GEBSECPODE(cUsuario, cCod, .T.)
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fora_do_escopo: usuario de outra empresa ou sem permissao"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Atualiza campos do body.
    If Len(aBody) >= 1
        cNome := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cPerfil := Upper(AllTrim(cValToChar(aBody[2])))
    EndIf
    If Len(aBody) >= 3
        cSenha := AllTrim(cValToChar(aBody[3]))
    EndIf

    If cPerfil != "" .And. !GEBDBSchemaValido(Lower(cPerfil))
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"perfil_invalido: use letras, numeros e _"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Valida a politica de senha ANTES de escrever nome/perfil -- um PUT
    // com senha fraca deve rejeitar o pedido inteiro (400), nao gravar
    // nome/perfil e so' depois recusar a senha.
    If cSenha != ""
        aPol := GEBSECPOL_VERIFICA(cSenha)
        If Len(aPol) >= 2
            If !(aPol[1])
                cStatus := "400"
                cBody := GEBRESTJSONRESP(.F., Nil, {"politica_senha: " + cValToChar(aPol[2])})
                If Len(aArea) > 0
                    RestArea(aArea)
                EndIf
                Return {cStatus, cBody}
            EndIf
        EndIf
    EndIf

    If cNome != ""
        DbSelectArea("GE2")
        DbGoTop()
        While !Eof()
            If GE2->D_E_L_E_T_ == " " .And. GE2->GE2_COD == cCod
                RecLock("GE2", .F.)
                GE2->GE2_NOME := cNome
                MsUnlock()
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    If cPerfil != ""
        DbSelectArea("GE2")
        DbGoTop()
        While !Eof()
            If GE2->D_E_L_E_T_ == " " .And. GE2->GE2_COD == cCod
                RecLock("GE2", .F.)
                GE2->GE2_PERFIL := cPerfil
                MsUnlock()
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    If cSenha != ""
        // Politica de senha ja validada mais acima (antes de qualquer
        // escrita de nome/perfil). Novo salt aleatorio a cada troca de
        // senha (GEBSECSALT, src/GEBSEC_LOGIN.prw), gravado JUNTO com o
        // hash em GE2_SEC:
        // GEBSECLOGIN() recalcula o hash com o SEC_SALT armazenado, entao
        // gravar so' o hash (com um salt fixo diferente do armazenado)
        // impedia o login depois da troca.
        cSalt := GEBSECSALT()
        If cSalt == ""
            cStatus := "500"
            cBody := GEBRESTJSONRESP(.F., Nil, {"falha_gerar_salt"})
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return {cStatus, cBody}
        EndIf
        cHash := HashSenha(cSenha, cSalt)
        // Credencial so' em GE2_SEC (GE2 nao tem coluna de senha).
        DbSelectArea("GE2_SEC")
        DbGoTop()
        While !Eof()
            If GE2_SEC->SEC_USUARIO == cCod .And. GE2_SEC->D_E_L_E_T_ == " "
                RecLock("GE2_SEC", .F.)
                GE2_SEC->SEC_SALT := cSalt
                GE2_SEC->SEC_HASH := cHash
                GE2_SEC->SEC_FAILCNT := 0
                GE2_SEC->SEC_LOCKED := "00000000" // senha redefinida (super/ADMIN): desbloqueia
                GE2_SEC->SEC_PWDLAST := DToS(Date())
                MsUnlock()
                GEBSECDERRUBA(cCod) // senha trocada por outra pessoa: derruba as sessoes abertas
                Exit
            EndIf
            DbSkip()
        EndDo
        DbCloseArea()
    EndIf

    aRes := {cCod, cNome, cPerfil}
    cBody := GEBRESTJSONRESP(.T., aRes, {})

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTUSRRM
    Endpoint DELETE /usuarios/{cod}. Soft delete GE2.
    @type Endpoint DELETE /usuarios/{cod}
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param cCod Codigo do usuario
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTUSRRM(cUsuario, cCod)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local cEmpT    := ""
    Local aScope   := {}
    Local lAchou  := .F.
    Local aChk    := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cCod == Nil
        cCod := ""
    EndIf

    If cCod == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"codigo_usuario_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Mesma guarda de GEBSECCRIAUSU() (src/GEBSEC_LOGIN.prw): DELETE
    // nunca remove a conta ADMIN via REST.
    If GEBSECISSUPER(cCod)
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"acesso_negado: remocao da conta super via REST nao permitida"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If !GEBDBTableExists("GE2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Regra unica (GEBSECPODE): ADMIN da empresa da sessao, alvo vinculado
    // so' a ela e nunca o super. Usuario compartilhado com outra empresa
    // so' o super altera (senha/perfil sao globais).
    If !GEBSECPODE(cUsuario, cCod, .T.)
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fora_do_escopo: usuario de outra empresa ou sem permissao"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GE2")
    DbGoTop()
    While !Eof()
        If GE2->D_E_L_E_T_ == " " .And. GE2->GE2_COD == cCod
            lAchou := .T.
            RecLock("GE2", .F.)
            GE2->D_E_L_E_T_ := "*"
            MsUnlock()
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    If !lAchou
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"usuario_nao_encontrado: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    // Usuario excluido perde tudo junto: vinculos (senao recriar o mesmo
    // codigo herdava as empresas antigas), credencial e sessoes abertas.
    TCSqlExec("UPDATE public.GE2_EMP SET D_E_L_E_T_ = '*' WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("UPDATE public.GE2_SEC SET D_E_L_E_T_ = '*' WHERE SEC_USUARIO = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    TCSqlExec("UPDATE public.GE2_TOK SET D_E_L_E_T_ = '*' WHERE TOK_USUARIO = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' '")
    cBody := GEBRESTJSONRESP(.T., {cCod, "deleted"}, {})

    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTEMPLST
    Endpoint GET /empresas. Lista GE1.
    @type Endpoint GET /empresas
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTEMPLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    Local aChk    := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    If !GEBDBTableExists("GE1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    DbSelectArea("GE1")
    DbGoTop()
    While !Eof()
        If GE1->D_E_L_E_T_ == " "
            AAdd(aDados, {GE1->GE1_COD, GE1->GE1_NOME})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTEMPLSC
    Endpoint POST /empresas. Cria empresa em GE1.
    @type Endpoint POST /empresas
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body da requisicao
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTEMPLSC(cUsuario, aBody)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "201"
    Local cBody   := ""
    Local cCod    := ""
    Local cNome   := ""
    Local cFil    := ""
    Local aChk    := {}
    Local lDup    := .F.

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf

    cFil := FWxFilial("GE1")

    If !GEBDBTableExists("GE1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If Len(aBody) >= 1
        cCod := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cNome := AllTrim(cValToChar(aBody[2]))
    EndIf

    If cCod == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"codigo_empresa_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cNome == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"nome_empresa_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBSECISSUPER(cUsuario)
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"somente_super: so o super cria empresas"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Verifica duplicidade.
    DbSelectArea("GE1")
    DbGoTop()
    While !Eof()
        If GE1->D_E_L_E_T_ == " " .And. GE1->GE1_COD == cCod
            lDup := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If lDup
        cStatus := "409"
        cBody := GEBRESTJSONRESP(.F., Nil, {"empresa_duplicada: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Provisiona de verdade (schema emp_<cod> + migracoes + GE1):
    // empresa criada ja nasce utilizavel (login, telas, API).
    If !GEBDBProvisionaEmpresa(cCod, cNome)
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"falha_provisionar_empresa: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    aRes := {Lower(cCod), cNome}
    cBody := GEBRESTJSONRESP(.T., aRes, {})

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTPRDLST
    Endpoint GET /produtos. Lista GF1.
    @type Endpoint GET /produtos
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTPRDLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    Local aChk    := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    If !GEBDBTableExistsHere("GF1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gf1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    DbSelectArea("GF1")
    DbGoTop()
    While !Eof()
        If GF1->D_E_L_E_T_ == " "
            // Filtro por EMPRESA aposentado: isolamento por schema (search_path).
            If .T.
                AAdd(aDados, {GF1->GF1_COD, GF1->GF1_NCM, GF1->GF1_DESC})
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTALISC
    Cadastra aliquota IBS/CBS (percentual) de uma NCM com vigencia em GF2.
    Sem isto nenhuma nota emitida pela tela era tributada (NCM sem
    aliquota vigente tributa a zero -- docs/02, sec. 3 e 10).
    Recusa percentual fora de 0..100, datas invalidas e vigencia que
    sobrepoe outra da mesma NCM (a vigente precisa ser unica).
    @type Endpoint POST /aliquotas (acao "Nova aliquota" da tela Fiscal)
    @author Peder Munksgaard
    @since 02/10/2026
    @param cUsuario Usuario autenticado
    @param aBody {cNCM, nIBS, nCBS, cIni AAAAMMDD, cFim AAAAMMDD}
    @return Array {cStatus, cJson}
/*/
User Function GEBRESTALISC(cUsuario, aBody)
    Local cNCM := ""
    Local nIBS := -1
    Local nCBS := -1
    Local cIni := ""
    Local cFim := ""
    Local cFil := FWxFilial("GF2")
    Local aSob := {}

    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 5
        cNCM := AllTrim(cValToChar(aBody[1]))
        nIBS := GEBRESTNUM(aBody[2])
        nCBS := GEBRESTNUM(aBody[3])
        cIni := AllTrim(cValToChar(aBody[4]))
        cFim := AllTrim(cValToChar(aBody[5]))
    EndIf
    // NCM (mercadoria, 8 digitos) ou NBS (servico, 9 digitos), so' numeros.
    If !(Len(cNCM) == 8 .Or. Len(cNCM) == 9) .Or. !GEBRESTSODIG(cNCM)
        Return {"400", GEBRESTJSONRESP(.F., Nil, {"ncm_invalida: use 8 (NCM) ou 9 (NBS) digitos"})}
    EndIf
    // Campo em branco ou nao numerico nao vira 0% (sem como corrigir depois).
    If !GEBRESTSODIG(StrTran(StrTran(AllTrim(cValToChar(aBody[2])), ",", ""), ".", "")) .Or. ;
       !GEBRESTSODIG(StrTran(StrTran(AllTrim(cValToChar(aBody[3])), ",", ""), ".", ""))
        Return {"400", GEBRESTJSONRESP(.F., Nil, {"aliquota_invalida: informe IBS e CBS em %"})}
    EndIf
    If nIBS < 0 .Or. nIBS > 100 .Or. nCBS < 0 .Or. nCBS > 100
        Return {"400", GEBRESTJSONRESP(.F., Nil, {"aliquota_fora_de_0_a_100"})}
    EndIf
    If Len(cIni) != 8 .Or. Len(cFim) != 8 .Or. Empty(SToD(cIni)) .Or. Empty(SToD(cFim)) .Or. cIni > cFim
        Return {"400", GEBRESTJSONRESP(.F., Nil, {"vigencia_invalida: use AAAAMMDD e inicio <= fim"})}
    EndIf
    If !GEBDBTableExistsHere("GF2")
        Return {"500", GEBRESTJSONRESP(.F., Nil, {"table_gf2_missing"})}
    EndIf
    aSob := TCSqlQuery("SELECT GF2_INI FROM GF2 WHERE GF2_FILIAL = " + GEBDBQuote(cFil) + " AND GF2_NCM = " + GEBDBQuote(cNCM) + ;
        " AND D_E_L_E_T_ = ' ' AND GF2_INI <= " + GEBDBQuote(cFim) + " AND GF2_FIM >= " + GEBDBQuote(cIni))
    If Len(aSob) > 0
        Return {"409", GEBRESTJSONRESP(.F., Nil, {"vigencia_sobreposta: ja existe aliquota da NCM " + cNCM + " nesse periodo"})}
    EndIf
    If !TCSqlExec("INSERT INTO GF2 (D_E_L_E_T_, GF2_FILIAL, GF2_NCM, GF2_IBS, GF2_CBS, GF2_INI, GF2_FIM) VALUES (' ', " + ;
            GEBDBQuote(cFil) + ", " + GEBDBQuote(cNCM) + ", " + cValToChar(nIBS) + ", " + cValToChar(nCBS) + ", " + GEBDBQuote(cIni) + ", " + GEBDBQuote(cFim) + ")")
        Return {"500", GEBRESTJSONRESP(.F., Nil, {"falha_ao_gravar_aliquota"})}
    EndIf
Return {"201", GEBRESTJSONRESP(.T., {cNCM, nIBS, nCBS, cIni, cFim}, {})}

// GEBRESTSODIG(c) -> .T. se c nao vazio e so' digitos.
Static Function GEBRESTSODIG(cTxt)
    Local nI := 0
    If cTxt == ""
        Return .F.
    EndIf
    For nI := 1 To Len(cTxt)
        If !(SubStr(cTxt, nI, 1) $ "0123456789")
            Return .F.
        EndIf
    Next nI
Return .T.

// GEBRESTNUM(x) -> numero (aceita numero ou texto com virgula decimal).
Static Function GEBRESTNUM(xVal)
    If ValType(xVal) == "N"
        Return xVal
    EndIf
Return Val(StrTran(AllTrim(cValToChar(xVal)), ",", "."))

/*/{Protheus.doc} GEBRESTPRDLSC
    Endpoint POST /produtos. Cria produto em GF1.
    @type Endpoint POST /produtos
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body da requisicao
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTPRDLSC(cUsuario, aBody)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "201"
    Local cBody   := ""
    Local cCod    := ""
    Local cNCM    := ""
    Local cDesc   := ""
    Local cFil    := ""
    Local aChk    := {}
    Local lDup    := .F.

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf

    cFil := FWxFilial("GF1")

    If !GEBDBTableExistsHere("GF1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gf1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If Len(aBody) >= 1
        cCod := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cNCM := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        cDesc := AllTrim(cValToChar(aBody[3]))
    EndIf

    If cCod == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"codigo_produto_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    // Verifica duplicidade.
    DbSelectArea("GF1")
    DbGoTop()
    While !Eof()
        If GF1->D_E_L_E_T_ == " " .And. GF1->GF1_FILIAL == cFil .And. GF1->GF1_COD == cCod
            lDup := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If lDup
        cStatus := "409"
        cBody := GEBRESTJSONRESP(.F., Nil, {"produto_duplicado: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    DbSelectArea("GF1")
    DbAppend()
    RecLock("GF1", .T.)
    GF1->GF1_FILIAL := cFil
    GF1->D_E_L_E_T_ := " "
    GF1->GF1_COD := cCod
    GF1->GF1_NCM := cNCM
    GF1->GF1_DESC := cDesc
    MsUnlock()
    DbCloseArea()

    aRes := {cCod, cNCM, cDesc}
    cBody := GEBRESTJSONRESP(.T., aRes, {})

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTNOTLST
    Endpoint GET /notas. Lista GF3 com filtros (empresa, periodo, status).
    @type Endpoint GET /notas
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param aParams Parametros de filtro (array de pares chave-valor)
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTNOTLST(cUsuario, aParams)
    Local aArea    := GetArea()
    Local aRes     := {}
    Local cStatus  := "200"
    Local cBody    := ""
    Local aDados   := {}
    Local cComp    := ""
    Local cSt      := ""
    Local aChk     := {}
    Local cParam   := ""
    Local cVal     := ""
    Local nIdx     := 0

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aParams == Nil
        aParams := {}
    EndIf

    // Extrai filtros do params.
    For nIdx := 1 To Len(aParams) Step 2
        cParam := Upper(AllTrim(cValToChar(aParams[nIdx])))
        cVal := cValToChar(aParams[nIdx + 1])
        If cParam == "EMPRESA"
            // Ignorado: a empresa e' o schema do search_path corrente.
        Else
            If cParam == "PERIODO"
                cComp := cVal
            Else
                If cParam == "STATUS"
                    cSt := Upper(AllTrim(cVal))
                EndIf
            EndIf
        EndIf
    Next nIdx

    If !GEBDBTableExistsHere("GF3")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gf3_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    DbSelectArea("GF3")
    DbGoTop()
    While !Eof()
        If GF3->D_E_L_E_T_ == " "
            // Filtro por EMPRESA aposentado: isolamento por schema (search_path).
            If .T.
                If cComp == "" .Or. SubStr(GF3->GF3_EMIS, 1, 6) == cComp
                    If cSt == "" .Or. GF3->GF3_STATUS == cSt
                        AAdd(aDados, {GF3->GF3_CHAVE, GF3->GF3_TIPO, GF3->GF3_STATUS, GF3->GF3_BASE, GF3->GF3_IBS, GF3->GF3_CBS, GF3->GF3_EMIS})
                    EndIf
                EndIf
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTNOTPOST
    Endpoint POST /notas. Emite NF via GEBFEMI + valida RBAC.
    @type Endpoint POST /notas
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body da requisicao {cChave, cCod, nQtd, nPreco}
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTNOTPOST(cUsuario, aBody)
    Local aArea    := GetArea()
    Local aRes     := {}
    Local cStatus  := "201"
    Local cBody    := ""
    Local cChave   := ""
    Local cCod     := ""
    Local nQtd     := 0
    Local nPreco   := 0
    Local cSt      := ""
    Local aEx      := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf

    If Len(aBody) >= 1
        cChave := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cCod := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        nQtd := Val(cValToChar(aBody[3]))
    EndIf
    If Len(aBody) >= 4
        nPreco := Val(cValToChar(aBody[4]))
    EndIf

    If cChave == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"chave_nf_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    // GEBFEMI() audita via GBAUDLOG(), que concatena a chave no SQL:
    // aspas simples quebrariam o literal (injecao).
    If At("'", cChave) > 0 .Or. At("'", cCod) > 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"chave_ou_produto_invalido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cCod == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"codigo_produto_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If nQtd <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"quantidade_invalida"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If nPreco <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"preco_invalido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    aEx := TCSqlQuery("SELECT 1 FROM GF1 WHERE GF1_COD = " + GEBDBQuote(cCod) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aEx) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"produto_nao_cadastrado: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cSt := GEBFEMI(cChave, cCod, nQtd, nPreco)
    If cSt == "AUTORIZADA"
        cBody := GEBRESTJSONRESP(.T., {cChave, cCod, nQtd, nPreco, "status", cSt}, {})
    Else
        cStatus := "202"
        cBody := GEBRESTJSONRESP(.T., {cChave, cCod, nQtd, nPreco, "status", cSt}, {})
    EndIf

    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTFLXLST
    Endpoint GET /financeiro/fluxo. Resumo fluxo de caixa via GEBNFLX.
    @type Endpoint GET /financeiro/fluxo
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTFLXLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aFlx    := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    aFlx := GEBNFLX()
    If Len(aFlx) != 3
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fluxo_caixa_retorno_invalido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    cBody := GEBRESTJSONRESP(.T., {"a_receber", aFlx[1], "a_pagar", aFlx[2], "saldo", aFlx[3]}, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTCONLST
    Endpoint GET /financeiro/contas. Lista contas GFN1.
    @type Endpoint GET /financeiro/contas
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTCONLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    Local aChk    := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    If !GEBDBTableExistsHere("GFN1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gfn1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    DbSelectArea("GFN1")
    DbGoTop()
    While !Eof()
        If GFN1->D_E_L_E_T_ == " "
            // Filtro por EMPRESA aposentado: isolamento por schema (search_path).
            If .T.
                AAdd(aDados, {GFN1->GFN1_CONTA, GFN1->GFN1_NOME, GFN1->GFN1_SALDO})
            EndIf
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()

    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTRELFISSC
    Endpoint GET /fiscal/relatorio/{comp}. Relatorio fiscal via GEBRELFISCAL.
    @type Endpoint GET /fiscal/relatorio/{comp}
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param cComp Competencia (YYYYMM)
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTRELFISSC(cUsuario, cComp)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cComp == Nil
        cComp := ""
    EndIf

    // O tenant e' o search_path corrente (schema emp_<cod>, definido por
    // quem chama GEBREST); GEBRELFISCAL() so' usa cEmpresa em log.
    aDados := GEBRELFISCAL("", cComp)
    If Len(aDados) < 9
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"relatorio_fiscal_retorno_invalido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    cBody := GEBRESTJSONRESP(.T., {"notas", aDados[1], "base_calculo", aDados[2], "ibs", aDados[3], "cbs", aDados[4], "debito", aDados[5], "credito", aDados[6], "saldo_derrama", aDados[7], "apuracoes", aDados[8], "regime", aDados[9]}, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTRELGER
    Endpoint GET /relatorios/gerencial. Relatorio gerencial via GEBRELGERAL.
    @type Endpoint GET /relatorios/gerencial
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTRELGER(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    // O tenant e' o search_path corrente (schema emp_<cod>, definido por
    // quem chama GEBREST); GEBRELGERAL() so' usa cEmpresa em log.
    aDados := GEBRELGERAL("")
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTMONUSU
    Endpoint GET /monitor/usuarios. Lista sessoes ativas (somente ADMIN).
    @type Endpoint GET /monitor/usuarios
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTMONUSU(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    Local aChk    := {}
    Local lAdmin  := .F.
    Local aUser   := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf

    // Monitor: so' ADMIN (ou super). Nunca devolve o token (quem le o
    // monitor nao pode reutilizar a sessao de outro) -- so' o id da linha.
    // Fora o super, so' as sessoes da empresa da propria sessao.
    lAdmin := GEBSECPODE(cUsuario, "", .F.)
    If !lAdmin
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"access_denied: somente_admin"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If GEBSECISSUPER(cUsuario)
        aChk := TCSqlQuery("SELECT R_E_C_N_O_ AS ID, TOK_USUARIO, TOK_EMPRESA, TOK_FILIAL, TOK_IP, TOK_CREATED, TOK_EXPIRES FROM public.GE2_TOK WHERE D_E_L_E_T_ = ' ' AND TOK_EXPIRES > to_char(now(), 'YYYYMMDD HH24:MI:SS') ORDER BY R_E_C_N_O_")
    Else
        aChk := TCSqlQuery("SELECT R_E_C_N_O_ AS ID, TOK_USUARIO, TOK_EMPRESA, TOK_FILIAL, TOK_IP, TOK_CREATED, TOK_EXPIRES FROM public.GE2_TOK WHERE D_E_L_E_T_ = ' ' AND TOK_EXPIRES > to_char(now(), 'YYYYMMDD HH24:MI:SS') AND LOWER(TRIM(TOK_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " ORDER BY R_E_C_N_O_")
    EndIf
    AEval(aChk, {|o| AAdd(aDados, {Val(cValToChar(o:ID)), cValToChar(o:TOK_USUARIO), cValToChar(o:TOK_EMPRESA), cValToChar(o:TOK_FILIAL), cValToChar(o:TOK_IP), cValToChar(o:TOK_CREATED), cValToChar(o:TOK_EXPIRES)})})

    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}

    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTMONDES
    Endpoint DELETE /monitor/sessao/{token}. Desliga sessao (somente ADMIN).
    @type Endpoint DELETE /monitor/sessao/{token}
    @author Peder Munksgaard
    @since 23/09/2026
    @param cUsuario Usuario autenticado
    @param cToken Token da sessao
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTMONDES(cUsuario, cToken)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local lAdmin  := .F.
    Local aUser   := {}
    Local lOk     := .F.
    Local aChk    := {}

    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If cToken == Nil
        cToken := ""
    EndIf

    // Verifica se e ADMIN.
    aUser := TCSqlQuery("SELECT * FROM public.GE2 WHERE GE2_COD = " + GEBDBQuote(cUsuario) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aUser) > 0
        If Upper(AllTrim(aUser[1]:GE2_PERFIL)) == "ADMIN"
            lAdmin := .T.
        EndIf
    EndIf

    If !lAdmin
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"access_denied: somente_admin"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf

    If cToken == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"token_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    // cToken = id da sessao (R_E_C_N_O_, o que o monitor mostra) ou o
    // proprio token (compatibilidade). Fora o super: so' sessoes da empresa
    // da propria sessao e nunca a do super.
    If GEBSECISSUPER(cUsuario)
        aChk := TCSqlQuery("SELECT R_E_C_N_O_ AS ID FROM public.GE2_TOK WHERE D_E_L_E_T_ = ' ' AND (TOK_TOKEN = " + GEBDBQuote(cToken) + " OR CAST(R_E_C_N_O_ AS TEXT) = " + GEBDBQuote(cToken) + ")")
    Else
        aChk := TCSqlQuery("SELECT R_E_C_N_O_ AS ID FROM public.GE2_TOK WHERE D_E_L_E_T_ = ' ' AND (TOK_TOKEN = " + GEBDBQuote(cToken) + " OR CAST(R_E_C_N_O_ AS TEXT) = " + GEBDBQuote(cToken) + ")" + ;
            " AND LOWER(TRIM(TOK_EMPRESA)) = " + GEBDBQuote(GEBDBTenantAtual()) + " AND LOWER(TOK_USUARIO) <> 'super'")
    EndIf
    If Len(aChk) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"sessao_nao_encontrada"})
    Else
        TCSqlExec("UPDATE public.GE2_TOK SET D_E_L_E_T_ = '*' WHERE R_E_C_N_O_ = " + cValToChar(Val(cValToChar(aChk[1]:ID))))
        cBody := GEBRESTJSONRESP(.T., {Val(cValToChar(aChk[1]:ID)), "desligado"}, {})
    EndIf

    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

// ===== HELPERS =====

/*/{Protheus.doc} GEBRESTDERLST
    Endpoint GET /derrama/guias. Lista guias GD1 do tenant.
    @type Endpoint GET /derrama/guias
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTDERLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GD1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gd1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GD1")
    DbGoTop()
    While !Eof()
        If GD1->D_E_L_E_T_ == " "
            AAdd(aDados, {GD1->GD1_GUIA, GD1->GD1_COMP, GD1->GD1_VALOR, GD1->GD1_JUROS, GD1->GD1_MULTA, GD1->GD1_TOTAL, GD1->GD1_STATUS})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTESTLST
    Endpoint GET /estoque. Lista saldos GV1 do tenant.
    @type Endpoint GET /estoque
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTESTLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GV1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gv1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GV1")
    DbGoTop()
    While !Eof()
        If GV1->D_E_L_E_T_ == " "
            AAdd(aDados, {GV1->GV1_PROD, GV1->GV1_SALDO, GV1->GV1_MIN})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTVENLST
    Endpoint GET /estoque/vendas. Lista vendas GV2 do tenant.
    @type Endpoint GET /estoque/vendas
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTVENLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GV2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gv2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GV2")
    DbGoTop()
    While !Eof()
        If GV2->D_E_L_E_T_ == " "
            AAdd(aDados, {GV2->GV2_VENDA, GV2->GV2_PROD, GV2->GV2_QTD, GV2->GV2_STATUS})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTCTBLST
    Endpoint GET /contabil/lancamentos. Lista lancamentos GC2 do tenant.
    @type Endpoint GET /contabil/lancamentos
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTCTBLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GC2")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gc2_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GC2")
    DbGoTop()
    While !Eof()
        If GC2->D_E_L_E_T_ == " "
            AAdd(aDados, {GC2->GC2_LOTE, GC2->GC2_ORIGEM, GC2->GC2_VALOR, GC2->GC2_DATA, GC2->GC2_COMP, GC2->GC2_TIPO})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTCTCLST
    Endpoint GET /contabil/contas. Lista plano de contas GC1 do tenant.
    @type Endpoint GET /contabil/contas
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTCTCLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GC1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gc1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GC1")
    DbGoTop()
    While !Eof()
        If GC1->D_E_L_E_T_ == " "
            AAdd(aDados, {GC1->GC1_CONTA, GC1->GC1_NOME, GC1->GC1_TIPO})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTCOMLST
    Endpoint GET /compras/pedidos. Lista pedidos GCP3 do tenant.
    @type Endpoint GET /compras/pedidos
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTCOMLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GCP3")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gcp3_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GCP3")
    DbGoTop()
    While !Eof()
        If GCP3->D_E_L_E_T_ == " "
            AAdd(aDados, {GCP3->GCP3_NUM, GCP3->GCP3_FORN, GCP3->GCP3_STATUS})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTFORLST
    Endpoint GET /compras/fornecedores. Lista fornecedores GCP1 do tenant.
    @type Endpoint GET /compras/fornecedores
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTFORLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GCP1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gcp1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GCP1")
    DbGoTop()
    While !Eof()
        If GCP1->D_E_L_E_T_ == " "
            AAdd(aDados, {GCP1->GCP1_COD, GCP1->GCP1_NOME, GCP1->GCP1_CNPJ})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTTENANT
    Devolve o codigo do tenant corrente (search_path emp_<cod>).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
    @return Codigo ("" se fora de tenant)
/*/
Static Function GEBRESTTENANT()
    Local aArea := GetArea()
    Local aRow  := {}
    Local cSch  := ""
    aRow := TCSqlQuery("SELECT current_schema() AS SCH")
    If Len(aRow) > 0
        cSch := Lower(AllTrim(cValToChar(aRow[1]:SCH)))
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
    If SubStr(cSch, 1, 4) != "emp_"
        Return ""
    EndIf
Return SubStr(cSch, 5)

/*/{Protheus.doc} GEBRESTFILLST
    Endpoint GET /filiais. Lista filiais GEF1 do tenant corrente.
    @type Endpoint GET /filiais
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTFILLST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GEF1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gef1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GEF1")
    DbGoTop()
    While !Eof()
        If GEF1->D_E_L_E_T_ == " "
            AAdd(aDados, {GEF1->GEF1_COD, GEF1->GEF1_NOME, GEF1->GEF1_UNI})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTFILSC
    Endpoint POST /filiais. Cadastra filial EEUUFF no tenant corrente.
    Body: {codigo, nome}. O EE (2 primeiros) deve igualar o EE da
    empresa do tenant; a unidade UU e' extraida (posicoes 3-4).
    @type Endpoint POST /filiais
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {codigo, nome}
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTFILSC(cUsuario, aBody)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "201"
    Local cBody   := ""
    Local cCod    := ""
    Local cNome   := ""
    Local cEmp    := ""
    Local cUni    := ""
    Local cFil    := ""
    Local lDup    := .F.
    Local aUni    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If !GEBDBTableExistsHere("GEF1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_gef1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If Len(aBody) >= 1
        cCod := Upper(AllTrim(cValToChar(aBody[1])))
    EndIf
    If Len(aBody) >= 2
        cNome := AllTrim(cValToChar(aBody[2]))
    EndIf
    cEmp := GEBRESTTENANT()
    If cEmp == ""
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"tenant_indefinido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEFFILVALIDA(cEmp, cCod)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"filial_invalida: use EEUUFF de 6 com EE igual ao da empresa"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cNome == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"nome_filial_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cUni := GEFFILUNI(cCod)
    // Hierarquia: a filial pertence a uma unidade cadastrada (sempre, nao so' quando ja
    // existe alguma unidade). Antes, num tenant sem unidades qualquer filial passava.
    If GEBDBTableExistsHere("GEU1")
        aUni := TCSqlQuery("SELECT GEU1_COD FROM GEU1 WHERE GEU1_COD = " + GEBDBQuote(cUni) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
        If Len(aUni) == 0
            cStatus := "400"
            cBody := GEBRESTJSONRESP(.F., Nil, {"unidade_nao_cadastrada: cadastre " + cUni + " em /unidades antes"})
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return {cStatus, cBody}
        EndIf
    EndIf

    cFil := FWxFilial("GEF1")
    DbSelectArea("GEF1")
    DbGoTop()
    While !Eof()
        If GEF1->D_E_L_E_T_ == " " .And. GEF1->GEF1_COD == cCod
            lDup := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If lDup
        cStatus := "409"
        cBody := GEBRESTJSONRESP(.F., Nil, {"filial_duplicada: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GEF1")
    DbAppend()
    RecLock("GEF1", .T.)
    GEF1->GEF1_FILIAL := cFil
    GEF1->D_E_L_E_T_ := " "
    GEF1->GEF1_COD := cCod
    GEF1->GEF1_NOME := cNome // gravacao por workarea ja e' parametrizada: nao dobrar aspas
    GEF1->GEF1_UNI := cUni
    MsUnlock()
    DbCloseArea()
    aRes := {cCod, cNome, cUni}
    cBody := GEBRESTJSONRESP(.T., aRes, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTVINCSC
    Endpoint POST /vinculos. Vincula usuario existente a empresa+filial
    (linha GE2_EMP, catalogo). Body: {usuario, empresa, filial}.
    @type Endpoint POST /vinculos
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {usuario, empresa, filial}
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTVINCSC(cUsuario, aBody)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "201"
    Local cBody   := ""
    Local cAlvo   := ""
    Local cEmp    := ""
    Local cFil    := ""
    Local aHit    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cAlvo := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cEmp := Lower(AllTrim(cValToChar(aBody[2])))
    EndIf
    If Len(aBody) >= 3
        cFil := Upper(AllTrim(cValToChar(aBody[3])))
    EndIf
    If cAlvo == "" .Or. !GEBDBSchemaValido(cAlvo)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"usuario_invalido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cEmp == "" .Or. !GEBDBSchemaValido(cEmp)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"empresa_invalida"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    // Escopo: so' o super vincula em qualquer empresa; os demais so' na
    // empresa da propria sessao (senao um ADMIN se dava acesso a outra).
    If !GEBSECISSUPER(cUsuario) .And. (cEmp != Lower(AllTrim(GEBRESTTENANT())) .Or. !GEBSECPODE(cUsuario, cAlvo, .F.))
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fora_do_escopo: vinculo so' na empresa da propria sessao"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBDBSchemaExists(cEmp)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"empresa_nao_provisionada: " + cEmp})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aHit := TCSqlQuery("SELECT GE2_COD FROM public.GE2 WHERE GE2_COD = " + GEBDBQuote(cAlvo) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aHit) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"usuario_nao_encontrado: " + cAlvo})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cFil != ""
        If !GEBDBSchemaValido(cFil)
            cStatus := "400"
            cBody := GEBRESTJSONRESP(.F., Nil, {"filial_invalida"})
            If Len(aArea) > 0
                RestArea(aArea)
            EndIf
            Return {cStatus, cBody}
        EndIf
    EndIf
    If cFil != ""
        If GEBDBTableExistsHere("GEF1")
            aHit := TCSqlQuery("SELECT GEF1_COD FROM GEF1 WHERE D_E_L_E_T_ = ' ' LIMIT 1")
            If Len(aHit) > 0
                aHit := TCSqlQuery("SELECT GEF1_COD FROM GEF1 WHERE GEF1_COD = " + GEBDBQuote(cFil) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
                If Len(aHit) == 0
                    cStatus := "400"
                    cBody := GEBRESTJSONRESP(.F., Nil, {"filial_nao_cadastrada: cadastre " + cFil + " em /filiais antes"})
                    If Len(aArea) > 0
                        RestArea(aArea)
                    EndIf
                    Return {cStatus, cBody}
                EndIf
            EndIf
        EndIf
    EndIf
    aHit := TCSqlQuery("SELECT GE2_EMP_USUARIO FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cAlvo) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(cEmp) + " AND TRIM(BOTH ' ' FROM GE2_EMP_FILIAL) = TRIM(BOTH ' ' FROM " + GEBDBQuote(cFil) + ") AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aHit) > 0
        cStatus := "409"
        cBody := GEBRESTJSONRESP(.F., Nil, {"vinculo_duplicado"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !TCSqlExec("INSERT INTO public.GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', " + GEBDBQuote(cFil) + ", " + GEBDBQuote(cAlvo) + ", " + GEBDBQuote(cEmp) + ")")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"falha_criar_vinculo"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aRes := {cAlvo, cEmp, cFil}
    cBody := GEBRESTJSONRESP(.T., aRes, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTPUBEMP
    Endpoint GET /public/empresas. Lista empresas GE1 (catalogo) SEM
    autenticacao: alimenta o seletor de ambiente da tela de login
    (mesmo padrao do Protheus, que mostra empresas antes do login).
    @type Endpoint publico
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Ignorado (rota publica)
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTPUBEMP(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExists("GE1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_ge1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GE1")
    DbGoTop()
    While !Eof()
        If GE1->D_E_L_E_T_ == " "
            AAdd(aDados, {GE1->GE1_COD, GE1->GE1_NOME})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTDERGER
    Endpoint POST /derrama/gerar. Gera guia da competencia via GEBDGER.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {competencia YYYYMM}
    @return Array {nHttp, cJson} 201 {guia} / 400
/*/
User Function GEBRESTDERGER(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cComp   := ""
    Local cGuia   := ""
    Local aApu    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cComp := AllTrim(cValToChar(aBody[1]))
    EndIf
    If cComp == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"competencia_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aApu := TCSqlQuery("SELECT GF5_COMP FROM GF5 WHERE GF5_COMP = " + GEBDBQuote(cComp) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aApu) == 0
        cStatus := "422"
        cBody := GEBRESTJSONRESP(.F., Nil, {"competencia_nao_apurada: apure " + cComp + " em Fiscal antes"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cGuia := GEBDGER(cComp)
    If cGuia == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"falha_gerar_guia"})
    Else
        cBody := GEBRESTJSONRESP(.T., {cGuia}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTDERBAI
    Endpoint POST /derrama/baixar. Quita guia via GEBDBAI.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {guia}
    @return Array {nHttp, cJson} 200 / 404
/*/
User Function GEBRESTDERBAI(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cGuia   := ""
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cGuia := AllTrim(cValToChar(aBody[1]))
    EndIf
    If cGuia == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"guia_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBDBAI(cGuia)
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"guia_nao_encontrada: " + cGuia})
    Else
        cBody := GEBRESTJSONRESP(.T., {cGuia, "baixada"}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTDERPAR
    Endpoint POST /derrama/parcelar. Parcela guia via GEBDPAR.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {guia, parcelas}
    @return Array {nHttp, cJson} 200 / 400
/*/
User Function GEBRESTDERPAR(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cGuia   := ""
    Local nParc   := 0
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cGuia := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        nParc := Val(cValToChar(aBody[2]))
    EndIf
    If cGuia == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"guia_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If nParc < 2
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"parcelas_invalidas: minimo 2"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBDPAR(cGuia, nParc)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"parcelamento_recusado: " + cGuia})
    Else
        cBody := GEBRESTJSONRESP(.T., {cGuia, nParc}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTDERJUR
    Endpoint POST /derrama/juros. Calcula juros da guia via GEBDJUR.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {guia, dias}
    @return Array {nHttp, cJson} 200 {total}
/*/
User Function GEBRESTDERJUR(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cGuia   := ""
    Local nDias   := 0
    Local nTot    := 0
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cGuia := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        nDias := Val(cValToChar(aBody[2]))
    EndIf
    If cGuia == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"guia_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    nTot := GEBDJUR(cGuia, nDias)
    cBody := GEBRESTJSONRESP(.T., {"guia", cGuia, "dias", nDias, "total", nTot}, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTDERPRO
    Endpoint POST /derrama/protestar. Protesta guia via GEBDPRO.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {guia}
    @return Array {nHttp, cJson} 200 / 404
/*/
User Function GEBRESTDERPRO(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cGuia   := ""
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cGuia := AllTrim(cValToChar(aBody[1]))
    EndIf
    If cGuia == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"guia_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBDPRO(cGuia)
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"guia_nao_encontrada: " + cGuia})
    Else
        cBody := GEBRESTJSONRESP(.T., {cGuia, "protestada"}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTESTVEN
    Endpoint POST /estoque/vender. Vende via GEBVVEN.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {venda, produto, quantidade, preco}
    @return Array 201 VENDIDA / 409 SEM_ESTOQUE / 403 BLOQUEADA / 400
/*/
User Function GEBRESTESTVEN(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cVenda  := ""
    Local cProd   := ""
    Local nQtd    := 0
    Local nPreco  := 0
    Local cSt     := ""
    Local aEx     := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cVenda := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cProd := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        nQtd := Val(cValToChar(aBody[3]))
    EndIf
    If Len(aBody) >= 4
        nPreco := Val(cValToChar(aBody[4]))
    EndIf
    If cVenda == "" .Or. cProd == "" .Or. nQtd <= 0 .Or. nPreco <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"venda_invalida: informe venda, produto, quantidade e preco"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aEx := TCSqlQuery("SELECT 1 FROM GF1 WHERE GF1_COD = " + GEBDBQuote(cProd) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aEx) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"produto_nao_cadastrado: " + cProd})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cSt := GEBVVEN(cVenda, cProd, nQtd, nPreco)
    If cSt == "VENDIDA"
        cBody := GEBRESTJSONRESP(.T., {cVenda, cProd, nQtd, nPreco, "status", cSt}, {})
    Else
        If cSt == "SEM_ESTOQUE"
            cStatus := "409"
        Else
            If cSt == "BLOQUEADA"
                cStatus := "403"
            Else
                cStatus := "400"
            EndIf
        EndIf
        cBody := GEBRESTJSONRESP(.F., Nil, {"venda_recusada: " + cSt})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTESTFIA
    Endpoint POST /estoque/fiado. Vende fiado via GEBVFIA.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {cliente, valor}
    @return Array 201 / 400
/*/
User Function GEBRESTESTFIA(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cCli    := ""
    Local nValor  := 0
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cCli := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        nValor := Val(cValToChar(aBody[2]))
    EndIf
    If cCli == "" .Or. nValor <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fiado_invalido: informe cliente e valor"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBVFIA(cCli, nValor)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fiado_recusado: " + cCli})
    Else
        cBody := GEBRESTJSONRESP(.T., {cCli, nValor}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTESTFIJ
    Endpoint POST /estoque/fiado/juros. Calcula juros via GEBVJUR.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {cliente, dias}
    @return Array 200 {total}
/*/
User Function GEBRESTESTFIJ(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cCli    := ""
    Local nDias   := 0
    Local nTot    := 0
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cCli := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        nDias := Val(cValToChar(aBody[2]))
    EndIf
    If cCli == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"cliente_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    nTot := GEBVJUR(cCli, nDias)
    cBody := GEBRESTJSONRESP(.T., {"cliente", cCli, "dias", nDias, "total", nTot}, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCTBDIR
    Endpoint POST /contabil/lancar. Lancamento direto via GEBCDIR.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado (vai para a trilha)
    @param aBody Body {debito, credito, valor}
    @return Array 201 / 400
/*/
User Function GEBRESTCTBDIR(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cDeb    := ""
    Local cCred   := ""
    Local nValor  := 0
    Local aCta    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cDeb := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cCred := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        nValor := Val(cValToChar(aBody[3]))
    EndIf
    If cDeb == "" .Or. cCred == "" .Or. nValor <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"lancamento_invalido: informe debito, credito e valor"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aCta := TCSqlQuery("SELECT GC1_CONTA FROM GC1 WHERE GC1_CONTA = " + GEBDBQuote(cDeb) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aCta) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"conta_nao_cadastrada: " + cDeb})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aCta := TCSqlQuery("SELECT GC1_CONTA FROM GC1 WHERE GC1_CONTA = " + GEBDBQuote(cCred) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aCta) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"conta_nao_cadastrada: " + cCred})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    // Diz QUAL trava barrou (antes: so' "lancamento_recusado"). Mesma ordem
    // das travas de GEBCDIR (docs/02, sec. 8.2).
    If GEBCFG("PERMITE_DIRETA") != "S"
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"lancamento_direto_desligado: o parametro PERMITE_DIRETA da empresa nao esta S"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBUSR(cUsuario)
        cStatus := "403"
        cBody := GEBRESTJSONRESP(.F., Nil, {"perfil_sem_lancamento_direto: " + cUsuario})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBCDIR(cDeb, cCred, nValor, cUsuario)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"lancamento_recusado: trava GC4 (LANC_DIRETO = N) ou Mentor"})
    Else
        cBody := GEBRESTJSONRESP(.T., {cDeb, cCred, nValor}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCTBBAL
    Endpoint GET /contabil/balancete. Balancete via GEBBAL.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aComp Competencia YYYYMM
    @return Array 200
/*/
User Function GEBRESTCTBBAL(cUsuario, cComp)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local aBal    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    // Antes o parametro se chamava aComp e o corpo lia cComp (sempre
    // vazio): DRE/balancete da tela calculavam sobre competencia "".
    If ValType(cComp) == "A"
        If Len(cComp) > 0
            cComp := cComp[1]
        Else
            cComp := ""
        EndIf
    EndIf
    If cComp == Nil
        cComp := ""
    EndIf
    aBal := GEBBAL(AllTrim(cValToChar(cComp)))
    cBody := GEBRESTJSONRESP(.T., aBal, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCTBDRE
    Endpoint GET /contabil/dre. DRE via GEBDRE.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aComp Competencia YYYYMM
    @return Array 200 {resultado}
/*/
User Function GEBRESTCTBDRE(cUsuario, cComp)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local nRes    := 0
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    // Antes o parametro se chamava aComp e o corpo lia cComp (sempre
    // vazio): DRE/balancete da tela calculavam sobre competencia "".
    If ValType(cComp) == "A"
        If Len(cComp) > 0
            cComp := cComp[1]
        Else
            cComp := ""
        EndIf
    EndIf
    If cComp == Nil
        cComp := ""
    EndIf
    nRes := GEBDRE(AllTrim(cValToChar(cComp)))
    cBody := GEBRESTJSONRESP(.T., {"resultado", nRes}, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTFINCON
    Endpoint POST /financeiro/contas. Cria conta via GEBFNCON.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {conta, nome}
    @return Array 201 / 400
/*/
User Function GEBRESTFINCON(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cConta  := ""
    Local cNome   := ""
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cConta := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cNome := AllTrim(cValToChar(aBody[2]))
    EndIf
    If cConta == "" .Or. cNome == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"conta_invalida: informe conta e nome"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBFNCON(cConta, cNome)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"conta_recusada: " + cConta})
    Else
        cBody := GEBRESTJSONRESP(.T., {cConta, cNome}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTFINBAI
    Endpoint POST /financeiro/baixar. Baixa titulo via GEBFNBAI.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {tipo, documento, valor}
    @return Array 200 / 400
/*/
User Function GEBRESTFINBAI(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cTipo   := ""
    Local cDoc    := ""
    Local nValor  := 0
    Local aTit    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cTipo := Upper(AllTrim(cValToChar(aBody[1])))
    EndIf
    If Len(aBody) >= 2
        cDoc := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        nValor := Val(cValToChar(aBody[3]))
    EndIf
    If cTipo == "" .Or. cDoc == "" .Or. nValor <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"baixa_invalida: informe tipo, documento e valor"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cTipo == "PAG" .Or. cTipo == "PAGAR"
        aTit := TCSqlQuery("SELECT GFN3_DOC FROM GFN3 WHERE GFN3_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    Else
        aTit := TCSqlQuery("SELECT GFN2_DOC FROM GFN2 WHERE GFN2_DOC = " + GEBDBQuote(cDoc) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    EndIf
    If Len(aTit) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"titulo_nao_encontrado: " + cDoc})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBFNBAI(cTipo, cDoc, nValor)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"baixa_recusada: " + cDoc})
    Else
        cBody := GEBRESTJSONRESP(.T., {cTipo, cDoc, nValor}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCOMFOR
    Endpoint POST /compras/fornecedores. Cadastra via GEBCMFOR.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {codigo, nome}
    @return Array 201 / 400
/*/
User Function GEBRESTCOMFOR(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cCod    := ""
    Local cNome   := ""
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cCod := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cNome := AllTrim(cValToChar(aBody[2]))
    EndIf
    If cCod == "" .Or. cNome == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fornecedor_invalido: informe codigo e nome"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBCMFOR(cCod, cNome)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fornecedor_recusado: " + cCod})
    Else
        cBody := GEBRESTJSONRESP(.T., {cCod, cNome}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCOMPED
    Endpoint POST /compras/pedidos. Abre pedido via GEBCMPED.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {pedido, fornecedor}
    @return Array 201 ABERTO / 403 BLOQUEADO / 400
/*/
User Function GEBRESTCOMPED(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cPed    := ""
    Local cForn   := ""
    Local cSt     := ""
    Local aEx     := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cPed := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cForn := AllTrim(cValToChar(aBody[2]))
    EndIf
    If cPed == "" .Or. cForn == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"pedido_invalido: informe pedido e fornecedor"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aEx := TCSqlQuery("SELECT 1 FROM GCP1 WHERE GCP1_COD = " + GEBDBQuote(cForn) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aEx) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"fornecedor_nao_cadastrado: " + cForn})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cSt := GEBCMPED(cPed, cForn)
    If cSt == "ABERTO"
        cBody := GEBRESTJSONRESP(.T., {cPed, cForn, "status", cSt}, {})
    Else
        If cSt == "BLOQUEADO"
            cStatus := "403"
        Else
            cStatus := "400"
        EndIf
        cBody := GEBRESTJSONRESP(.F., Nil, {"pedido_recusado: " + cSt})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCOMIT
    Endpoint POST /compras/itens. Adiciona item via GEBCMIT.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {pedido, produto, quantidade, preco}
    @return Array 201 / 400
/*/
User Function GEBRESTCOMIT(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cPed    := ""
    Local cProd   := ""
    Local nQtd    := 0
    Local nPreco  := 0
    Local aPed    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cPed := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cProd := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        nQtd := Val(cValToChar(aBody[3]))
    EndIf
    If Len(aBody) >= 4
        nPreco := Val(cValToChar(aBody[4]))
    EndIf
    If cPed == "" .Or. cProd == "" .Or. nQtd <= 0 .Or. nPreco <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"item_invalido: informe pedido, produto, quantidade e preco"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aPed := TCSqlQuery("SELECT GCP3_NUM FROM GCP3 WHERE GCP3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aPed) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"pedido_nao_encontrado: " + cPed})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBCMIT(cPed, cProd, nQtd, nPreco)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"item_recusado: " + cPed})
    Else
        cBody := GEBRESTJSONRESP(.T., {cPed, cProd, nQtd, nPreco}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTCOMENT
    Endpoint POST /compras/entradas. Da entrada via GEBCMENT.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {nf, pedido}
    @return Array 201 / 400
/*/
User Function GEBRESTCOMENT(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cNF     := ""
    Local cPed    := ""
    Local aPed    := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cNF := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cPed := AllTrim(cValToChar(aBody[2]))
    EndIf
    If cNF == "" .Or. cPed == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"entrada_invalida: informe nf e pedido"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    aPed := TCSqlQuery("SELECT GCP3_NUM FROM GCP3 WHERE GCP3_NUM = " + GEBDBQuote(cPed) + " AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aPed) == 0
        cStatus := "404"
        cBody := GEBRESTJSONRESP(.F., Nil, {"pedido_nao_encontrado: " + cPed})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBCMENT(cNF, cPed)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"entrada_recusada: " + cPed})
    Else
        cBody := GEBRESTJSONRESP(.T., {cNF, cPed}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTFISAPU
    Endpoint POST /fiscal/apurar. Apura competencia via GEBFAPU.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {competencia YYYYMM}
    @return Array 200 / 400
/*/
User Function GEBRESTFISAPU(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "200"
    Local cBody   := ""
    Local cComp   := ""
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cComp := AllTrim(cValToChar(aBody[1]))
    EndIf
    If cComp == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"competencia_vazia"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If !GEBFAPU(cComp)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"apuracao_recusada: " + cComp})
    Else
        cBody := GEBRESTJSONRESP(.T., {cComp, "apurada"}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTSNCFG
    Endpoints POST /fiscal/simples/config {anexo, inicio AAAAMM},
    /fiscal/simples/folha {competencia, folha, receita_externa, atividade},
    /fiscal/simples/apurar {competencia}, /atividade {codigo, descricao,
    anexo}, /produto {produto, atividade, st, monofasico}, /exportacao
    {chave, exportacao} e /feriado {data, descricao}; GET /extrato/{comp}
    e /anual/{ano}. Regras em GEBSN.prw.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 18/10/2026
    @return Array 200 / 400
/*/
User Function GEBRESTSNCFG(cUsuario, aBody)
Return GEBRESTSNRESP(GEBSNCFG(GEBRESTSNARG(aBody, 1), GEBRESTSNARG(aBody, 2)), {})

User Function GEBRESTSNFOL(cUsuario, aBody)
Return GEBRESTSNRESP(GEBSNFOL(GEBRESTSNARG(aBody, 1), Val(GEBRESTSNARG(aBody, 2)), Val(GEBRESTSNARG(aBody, 3)), GEBRESTSNARG(aBody, 4)), {})

User Function GEBRESTSNAPU(cUsuario, aBody)
    Local aRes := GEBSNAPU(GEBRESTSNARG(aBody, 1))
Return GEBRESTSNRESP(aRes, aRes[3])

Static Function GEBRESTSNARG(aBody, nPos)
    If aBody == Nil .Or. Len(aBody) < nPos
        Return ""
    EndIf
Return AllTrim(cValToChar(aBody[nPos]))

Static Function GEBRESTSNRESP(aRes, aDados)
    If aRes[1]
        Return {"200", GEBRESTJSONRESP(.T., aDados, {})}
    EndIf
Return {"400", GEBRESTJSONRESP(.F., Nil, {aRes[2]})}

// Backoffice (GEBBO.prw): aParams = {JsonObject da requisicao}. 404 rota
// inexistente, 400 recusa do modulo, 200 {mensagem, dados}.
Static Function GEBRESTBO(cMetodo, cRota, aParams, cUsuario)
    Local oReq := Nil
    Local aRes := {}
    If Len(aParams) >= 1 .And. ValType(aParams[1]) $ "OJ"
        oReq := aParams[1]
    Else
        oReq := JsonObject():New()
    EndIf
    aRes := GEBBOEXEC(cMetodo, cRota, oReq, cUsuario)
    If aRes[1]
        Return {"200", GEBRESTJSONRESP(.T., {aRes[2], aRes[3]}, {})}
    EndIf
    If Left(aRes[2], 16) == "rota_inexistente"
        Return {"404", GEBRESTJSONRESP(.F., Nil, {aRes[2]})}
    EndIf
Return {"400", GEBRESTJSONRESP(.F., Nil, {aRes[2]})}

// Relatorio do Simples: 200 com os dados, 404 se a competencia nao foi apurada, 400 nos demais erros.
Static Function GEBRESTSNREL(aRes)
    If aRes[1]
        Return {"200", GEBRESTJSONRESP(.T., aRes[3], {})}
    EndIf
    If Left(aRes[2], 22) == "competencia_nao_apurad"
        Return {"404", GEBRESTJSONRESP(.F., Nil, {aRes[2]})}
    EndIf
Return {"400", GEBRESTJSONRESP(.F., Nil, {aRes[2]})}

/*/{Protheus.doc} GEBRESTFISCRE
    Endpoint POST /fiscal/creditos. Lanca credito via GEBFCRE.
    @type Endpoint operacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {competencia, origem, valor, tipo}
    @return Array 201 {registro} / 400
/*/
User Function GEBRESTFISCRE(cUsuario, aBody)
    Local aArea   := GetArea()
    Local cStatus := "201"
    Local cBody   := ""
    Local cComp   := ""
    Local cOrig   := ""
    Local nValor  := 0
    Local cTipo   := ""
    Local cReg    := ""
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If Len(aBody) >= 1
        cComp := AllTrim(cValToChar(aBody[1]))
    EndIf
    If Len(aBody) >= 2
        cOrig := AllTrim(cValToChar(aBody[2]))
    EndIf
    If Len(aBody) >= 3
        nValor := Val(cValToChar(aBody[3]))
    EndIf
    If Len(aBody) >= 4
        cTipo := AllTrim(cValToChar(aBody[4]))
    EndIf
    If cComp == "" .Or. cOrig == "" .Or. nValor <= 0
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"credito_invalido: informe competencia, origem e valor"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cReg := GEBFCRE(cComp, cOrig, nValor, cTipo)
    If cReg == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"credito_recusado"})
    Else
        cBody := GEBRESTJSONRESP(.T., {cReg}, {})
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}

/*/{Protheus.doc} GEBRESTUNILST
    Endpoint GET /unidades. Lista unidades GEU1 do tenant.
    @type Endpoint GET /unidades
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @return Array {nHttp, cJson}
/*/
User Function GEBRESTUNILST(cUsuario)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "200"
    Local cBody   := ""
    Local aDados  := {}
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If !GEBDBTableExistsHere("GEU1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_geu1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GEU1")
    DbGoTop()
    While !Eof()
        If GEU1->D_E_L_E_T_ == " "
            AAdd(aDados, {GEU1->GEU1_COD, GEU1->GEU1_NOME})
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    cBody := GEBRESTJSONRESP(.T., aDados, {})
    aRes := {cStatus, cBody}
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRes

/*/{Protheus.doc} GEBRESTUNILSC
    Endpoint POST /unidades. Cadastra unidade UU (2 digitos).
    @type Endpoint POST /unidades
    @author Peder Munksgaard
    @since 25/09/2026
    @param cUsuario Usuario autenticado
    @param aBody Body {codigo, nome}
    @return Array {nHttp, cJson} 201 / 400 / 409
/*/
User Function GEBRESTUNILSC(cUsuario, aBody)
    Local aArea   := GetArea()
    Local aRes    := {}
    Local cStatus := "201"
    Local cBody   := ""
    Local cCod    := ""
    Local cNome   := ""
    Local cFil    := ""
    Local lDup    := .F.
    If cUsuario == Nil
        cUsuario := ""
    EndIf
    If aBody == Nil
        aBody := {}
    EndIf
    If !GEBDBTableExistsHere("GEU1")
        cStatus := "500"
        cBody := GEBRESTJSONRESP(.F., Nil, {"table_geu1_missing"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If Len(aBody) >= 1
        cCod := Upper(AllTrim(cValToChar(aBody[1])))
    EndIf
    If Len(aBody) >= 2
        cNome := AllTrim(cValToChar(aBody[2]))
    EndIf
    If !GEUVALIDA(cCod)
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"unidade_invalida: use 2 digitos"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    If cNome == ""
        cStatus := "400"
        cBody := GEBRESTJSONRESP(.F., Nil, {"nome_unidade_vazio"})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    cFil := FWxFilial("GEU1")
    DbSelectArea("GEU1")
    DbGoTop()
    While !Eof()
        If GEU1->D_E_L_E_T_ == " " .And. GEU1->GEU1_COD == cCod
            lDup := .T.
            Exit
        EndIf
        DbSkip()
    EndDo
    DbCloseArea()
    If lDup
        cStatus := "409"
        cBody := GEBRESTJSONRESP(.F., Nil, {"unidade_duplicada: " + cCod})
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {cStatus, cBody}
    EndIf
    DbSelectArea("GEU1")
    DbAppend()
    RecLock("GEU1", .T.)
    GEU1->GEU1_FILIAL := cFil
    GEU1->D_E_L_E_T_ := " "
    GEU1->GEU1_COD := cCod
    GEU1->GEU1_NOME := cNome // gravacao por workarea ja e' parametrizada: nao dobrar aspas
    MsUnlock()
    DbCloseArea()
    aRes := {cCod, cNome}
    cBody := GEBRESTJSONRESP(.T., aRes, {})
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {cStatus, cBody}
