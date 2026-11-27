#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"
#include "GEBREST.prw"

/*/{Protheus.doc} GEBWEB_API
    Ponte HTTP entre o WSRestServer (src/GEBWEB.prw) e o dispatcher
    interno U_GEBREST (src/GEBREST.prw). Cada rota /api/* tem uma User
    Function fina que extrai os campos do oReq (query + path params +
    corpo JSON, chaves em maiusculas), autentica via token GE2_TOK
    (mesma regra do dashboard), seleciona o tenant e delega ao
    U_GEBREST com metodo+path+aBody posicionais. A resposta {cStatus,
    cBody} vira RAW_HTTP com o status real (sem double-encoding JSON).
    Auth: ?token=...&empresa=... na query (mesma convencao do login).
    RBAC: delegado ao proprio GEBREST (403 interno).
    @type Ponte REST HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/

// ===== HELPERS (Static, testaveis via workers) =====

/*/{Protheus.doc} GEBWAPIFIELD
    Le campo do oReq com seguranca Nil (query/path/body mesclados).
    @type Helper
    @author Peder Munksgaard
    @since 25/09/2026
    @param oReq Objeto da requisicao
    @param cNome Nome do campo (maiusculas)
    @return Valor em string ("" se ausente)
/*/
Static Function GEBWAPIFIELD(oReq, cNome)
    Local xVal := Nil

    If oReq == Nil .Or. cNome == Nil
        Return ""
    EndIf
    xVal := oReq[Upper(AllTrim(cNome))]
    If xVal == Nil
        Return ""
    EndIf
Return AllTrim(cValToChar(xVal))

/*/{Protheus.doc} GEBWAPIAUTH
    Valida token GE2_TOK (nao expirado, mesma empresa) e seleciona o
    tenant. Mesma regra da antiga pagina de dashboard (removida; UI agora nativa em GEBTUI.prw).
    @type Helper autenticacao
    @author Peder Munksgaard
    @since 25/09/2026
    @param cTok Token da query
    @param cEmp Empresa da query
    @return Array {lOk, cUsuario}
    OBS: em caso de falha retorna {.F., ""} sem diferenciar motivo.
/*/
Static Function GEBWAPIAUTH(cTok, cEmp)
    Local aArea   := GetArea()
    Local aTokRow := {}
    Local cUsu    := ""
    Local cToken  := ""
    Local cEmpr   := ""
    If cTok == Nil
        cToken := ""
    Else
        cToken := AllTrim(cValToChar(cTok))
    EndIf
    If cEmp == Nil
        cEmpr := ""
    Else
        cEmpr := AllTrim(cValToChar(cEmp))
    EndIf
    If cToken == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {.F., ""}
    EndIf
    If cEmpr == ""
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {.F., ""}
    EndIf
    If !GEBDBSchemaValido(cEmpr)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {.F., ""}
    EndIf
    // Token vem da URL (nao confiavel): sempre escapado (GEBDBQuote).
    // Alem do token valido: usuario ainda ativo e ainda vinculado a
    // empresa (excluir usuario ou remover vinculo derruba a sessao na hora).
    aTokRow := TCSqlQuery("SELECT T.TOK_USUARIO, T.TOK_EMPRESA FROM public.GE2_TOK T " + ;
        "WHERE T.TOK_TOKEN = " + GEBDBQuote(cToken) + " AND T.TOK_EMPRESA = " + GEBDBQuote(cEmpr) + ;
        " AND T.TOK_EXPIRES > " + GEBDBQuote(DToS(Date()) + " " + Time()) + " AND T.D_E_L_E_T_ = ' '" + ;
        " AND EXISTS (SELECT 1 FROM public.GE2 U WHERE U.GE2_COD = T.TOK_USUARIO AND U.D_E_L_E_T_ = ' ')" + ;
        " AND (LOWER(T.TOK_USUARIO) = 'super' OR EXISTS (SELECT 1 FROM public.GE2_EMP E WHERE E.GE2_EMP_USUARIO = T.TOK_USUARIO" + ;
        " AND LOWER(E.GE2_EMP_EMPRESA) = LOWER(T.TOK_EMPRESA) AND E.D_E_L_E_T_ = ' '))")
    If Len(aTokRow) == 0
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {.F., ""}
    EndIf
    cUsu := cValToChar(aTokRow[1]:TOK_USUARIO)
    If !GEBDBSchemaExists(cEmpr)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {.F., ""}
    EndIf
    If !GEBDBSetTenant(cEmpr)
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return {.F., ""}
    EndIf
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return {.T., cUsu}

/*/{Protheus.doc} GEBWAPIRESP
    Converte {cStatus, cBody} do GEBREST em resposta RAW_HTTP com o
    status real (evita double-encoding do JSON).
    @type Helper resposta
    @author Peder Munksgaard
    @since 25/09/2026
    @param aRes Array {cStatus, cBody} do GEBREST
    @return Array sentinela RAW_HTTP
/*/
Static Function GEBWAPIRESP(aRes)
    Local cStatus := "200"
    Local cBody   := ""
    Local nStatus := 200
    If aRes == Nil
        Return {"__RAW_HTTP__", "application/json; charset=utf-8", '{"status":"error","erros":["internal_error"]}', 500}
    EndIf
    If Len(aRes) >= 1
        cStatus := cValToChar(aRes[1])
    EndIf
    If Len(aRes) >= 2
        cBody := cValToChar(aRes[2])
    EndIf
    nStatus := Val(cStatus)
    If nStatus <= 0
        nStatus := 200
    EndIf
Return {"__RAW_HTTP__", "application/json; charset=utf-8", cBody, nStatus}

/*/{Protheus.doc} GEBWAPIDENY
    Resposta 401 padrao (token ausente ou invalido).
    @type Helper resposta
    @author Peder Munksgaard
    @since 25/09/2026
    @return Array sentinela RAW_HTTP 401
/*/
Static Function GEBWAPIDENY()
Return {"__RAW_HTTP__", "application/json; charset=utf-8", '{"status":"error","erros":["sessao_invalida"]}', 401}

// ===== WORKERS (Static, recebem params planos -- testaveis) =====

/*/{Protheus.doc} GEBWAPIW_HEALTH
    Worker GET /api/health (publico, sem auth).
    @type Worker
    @author Peder Munksgaard
    @since 25/09/2026
    @return Array sentinela RAW_HTTP
/*/
Static Function GEBWAPIW_HEALTH()
    Local aArea := GetArea()
    Local aRes  := {}
    Local aRet  := {}
    aRes := GEBREST("GET", "/health", {}, "system", "web")
    aRet := GEBWAPIRESP(aRes)
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/{Protheus.doc} GEBWAPIW_GET
    Worker generico de consulta autenticada (listas e relatorios sem
    parametros de corpo). Resolve auth+tenant e delega ao GEBREST.
    @type Worker
    @author Peder Munksgaard
    @since 25/09/2026
    @param cTok Token da query
    @param cEmp Empresa da query
    @param cMetodo Metodo HTTP (sempre GET aqui)
    @param cPath Path interno do GEBREST
    @param aParams Params extras (pares chave-valor ou {})
    @return Array sentinela RAW_HTTP
/*/
Static Function GEBWAPIW_GET(cTok, cEmp, cMetodo, cPath, aParams)
    Local aArea := GetArea()
    Local aAuth := {}
    Local cUsu  := ""
    Local aRes  := {}
    Local aRet  := {}
    aAuth := GEBWAPIAUTH(cTok, cEmp)
    If !(aAuth[1])
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return GEBWAPIDENY()
    EndIf
    cUsu := aAuth[2]
    If aParams == Nil
        aParams := {}
    EndIf
    aRes := GEBREST(cMetodo, cPath, aParams, cUsu, "web:" + cUsu)
    aRet := GEBWAPIRESP(aRes)
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/{Protheus.doc} GEBWAPIW_POST
    Worker generico de escrita autenticada. Monta o aBody posicional
    a partir dos campos nomeados do HTTP e delega ao GEBREST.
    @type Worker
    @author Peder Munksgaard
    @since 25/09/2026
    @param cTok Token da query
    @param cEmp Empresa da query
    @param cPath Path interno do GEBREST
    @param aBody Body posicional ja montado pela rota
    @return Array sentinela RAW_HTTP
/*/
Static Function GEBWAPIW_POST(cTok, cEmp, cPath, aBody)
    Local aArea := GetArea()
    Local aAuth := {}
    Local cUsu  := ""
    Local aRes  := {}
    Local aRet  := {}
    aAuth := GEBWAPIAUTH(cTok, cEmp)
    If !(aAuth[1])
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return GEBWAPIDENY()
    EndIf
    cUsu := aAuth[2]
    If aBody == Nil
        aBody := {}
    EndIf
    aRes := GEBREST("POST", cPath, aBody, cUsu, "web:" + cUsu)
    aRet := GEBWAPIRESP(aRes)
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/{Protheus.doc} GEBWAPIW_PUTDEL
    Worker generico de PUT/DELETE autenticado sobre item com codigo.
    @type Worker
    @author Peder Munksgaard
    @since 25/09/2026
    @param cTok Token da query
    @param cEmp Empresa da query
    @param cMetodo PUT ou DELETE
    @param cPath Path interno com o codigo
    @param aBody Body posicional (PUT) ou {} (DELETE)
    @return Array sentinela RAW_HTTP
/*/
Static Function GEBWAPIW_PUTDEL(cTok, cEmp, cMetodo, cPath, aBody)
    Local aArea := GetArea()
    Local aAuth := {}
    Local cUsu  := ""
    Local aRes  := {}
    Local aRet  := {}
    aAuth := GEBWAPIAUTH(cTok, cEmp)
    If !(aAuth[1])
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return GEBWAPIDENY()
    EndIf
    cUsu := aAuth[2]
    If aBody == Nil
        aBody := {}
    EndIf
    aRes := GEBREST(cMetodo, cPath, aBody, cUsu, "web:" + cUsu)
    aRet := GEBWAPIRESP(aRes)
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

// ===== ROTAS HTTP (User Function finas -- so extraem oReq) =====

/*/{Protheus.doc} GEBWAPI_HEALTH
    GET /api/health -- publico, sem token.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_HEALTH(oReq)
Return GEBWAPIW_HEALTH()

/*/{Protheus.doc} GEBWAPI_USRLST
    GET /api/usuarios -- lista usuarios (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_USRLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/usuarios", {})

/*/{Protheus.doc} GEBWAPI_USRGET
    GET /api/usuarios/{cod} -- detalha usuario (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_USRGET(oReq)
    Local cTok := ""
    Local cEmp := ""
    Local cCod := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cCod := GEBWAPIFIELD(oReq, "COD")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/usuarios/" + cCod, {})

/*/{Protheus.doc} GEBWAPI_USRPOST
    POST /api/usuarios -- cria usuario (auth, via GEBSECCRIAUSU).
    Body JSON: codigo, nome, perfil, senha, empresas.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_USRPOST(oReq)
    Local cTok   := ""
    Local cEmp   := ""
    Local aBody  := {}
    Local xEmps  := Nil
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    If oReq != Nil
        If oReq:EMPRESAS != Nil
            xEmps := oReq:EMPRESAS
        EndIf
    EndIf
    If xEmps == Nil
        xEmps := ""
    EndIf
    aBody := {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "NOME"), GEBWAPIFIELD(oReq, "PERFIL"), GEBWAPIFIELD(oReq, "SENHA"), xEmps}
    AAdd(aBody, GEBWAPIFIELD(oReq, "FILIAL"))
Return GEBWAPIW_POST(cTok, cEmp, "/usuarios", aBody)

/*/{Protheus.doc} GEBWAPI_USRPUT
    PUT /api/usuarios/{cod} -- atualiza nome/perfil/senha (auth).
    Body JSON: nome, perfil, senha.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_USRPUT(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local cCod  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cCod := GEBWAPIFIELD(oReq, "COD")
    aBody := {GEBWAPIFIELD(oReq, "NOME"), GEBWAPIFIELD(oReq, "PERFIL"), GEBWAPIFIELD(oReq, "SENHA")}
Return GEBWAPIW_PUTDEL(cTok, cEmp, "PUT", "/usuarios/" + cCod, aBody)

/*/{Protheus.doc} GEBWAPI_USRDEL
    DELETE /api/usuarios/{cod} -- remove usuario (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_USRDEL(oReq)
    Local cTok := ""
    Local cEmp := ""
    Local cCod := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cCod := GEBWAPIFIELD(oReq, "COD")
Return GEBWAPIW_PUTDEL(cTok, cEmp, "DELETE", "/usuarios/" + cCod, {})

/*/{Protheus.doc} GEBWAPI_EMPLST
    GET /api/empresas -- lista empresas (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_EMPLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/empresas", {})

/*/{Protheus.doc} GEBWAPI_EMPLSC
    POST /api/empresas -- cria empresa em GE1 (auth).
    Body JSON: codigo, nome.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_EMPLSC(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aBody := {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "NOME")}
Return GEBWAPIW_POST(cTok, cEmp, "/empresas", aBody)

/*/{Protheus.doc} GEBWAPI_PRDLST
    GET /api/produtos -- lista produtos GF1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_PRDLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/produtos", {})

/*/{Protheus.doc} GEBWAPI_PRDLSC
    POST /api/produtos -- cria produto GF1 (auth).
    Body JSON: codigo, ncm, descricao.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_PRDLSC(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aBody := {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "NCM"), GEBWAPIFIELD(oReq, "DESCRICAO")}
Return GEBWAPIW_POST(cTok, cEmp, "/produtos", aBody)

/*/{Protheus.doc} GEBWAPI_NOTLST
    GET /api/notas -- lista notas GF3 com filtros periodo/status (auth).
    Query: periodo=YYYYMM, status=...
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_NOTLST(oReq)
    Local cTok    := ""
    Local cEmp    := ""
    Local aParams := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aParams := {"PERIODO", GEBWAPIFIELD(oReq, "PERIODO"), "STATUS", GEBWAPIFIELD(oReq, "STATUS")}
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/notas", aParams)

/*/{Protheus.doc} GEBWAPI_NOTPOST
    POST /api/notas -- emite nota via GEBFEMI (auth).
    Body JSON: chave, produto, quantidade, preco.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_NOTPOST(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aBody := {GEBWAPIFIELD(oReq, "CHAVE"), GEBWAPIFIELD(oReq, "PRODUTO"), GEBWAPIFIELD(oReq, "QUANTIDADE"), GEBWAPIFIELD(oReq, "PRECO")}
Return GEBWAPIW_POST(cTok, cEmp, "/notas", aBody)

/*/{Protheus.doc} GEBWAPI_FLXLST
    GET /api/financeiro/fluxo -- resumo fluxo de caixa (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FLXLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/financeiro/fluxo", {})

/*/{Protheus.doc} GEBWAPI_CONLST
    GET /api/financeiro/contas -- lista contas GFN1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_CONLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/financeiro/contas", {})

/*/{Protheus.doc} GEBWAPI_RELFISC
    GET /api/fiscal/relatorio/{comp} -- relatorio fiscal (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_RELFISC(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local cComp := ""
    Local aArea := GetArea()
    Local aAuth := {}
    Local cUsu  := ""
    Local aRes  := {}
    Local aRet  := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cComp := GEBWAPIFIELD(oReq, "COMP")
    aAuth := GEBWAPIAUTH(cTok, cEmp)
    If !(aAuth[1])
        If Len(aArea) > 0
            RestArea(aArea)
        EndIf
        Return GEBWAPIDENY()
    EndIf
    cUsu := aAuth[2]
    aRes := GEBRESTRELFISSC(cUsu, cComp)
    aRet := GEBWAPIRESP(aRes)
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/{Protheus.doc} GEBWAPI_RELGER
    GET /api/relatorios/gerencial -- relatorio gerencial (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_RELGER(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/relatorios/gerencial", {})

/*/{Protheus.doc} GEBWAPI_MONUSU
    GET /api/monitor/usuarios -- usuarios online (auth, ADMIN/monitor).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_MONUSU(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/monitor/usuarios", {})

/*/{Protheus.doc} GEBWAPI_MONDEL
    DELETE /api/monitor/sessao/{sessao} -- invalida sessao (auth).
    Path param SESSAO (nome proprio para nao colidir com o token
    da query na mesclagem do dispatcher).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_MONDEL(oReq)
    Local cTok := ""
    Local cEmp := ""
    Local cSes := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cSes := GEBWAPIFIELD(oReq, "SESSAO")
Return GEBWAPIW_PUTDEL(cTok, cEmp, "DELETE", "/monitor/sessao/" + cSes, {})

/*/{Protheus.doc} GEBWAPI_DERLST
    GET /api/derrama/guias -- lista guias GD1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_DERLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/derrama/guias", {})

/*/{Protheus.doc} GEBWAPI_ESTLST
    GET /api/estoque -- saldos GV1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_ESTLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/estoque", {})

/*/{Protheus.doc} GEBWAPI_VENLST
    GET /api/estoque/vendas -- vendas GV2 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_VENLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/estoque/vendas", {})

/*/{Protheus.doc} GEBWAPI_CTBLST
    GET /api/contabil/lancamentos -- lancamentos GC2 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_CTBLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/contabil/lancamentos", {})

/*/{Protheus.doc} GEBWAPI_CTCLST
    GET /api/contabil/contas -- plano de contas GC1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_CTCLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/contabil/contas", {})

/*/{Protheus.doc} GEBWAPI_COMLST
    GET /api/compras/pedidos -- pedidos GCP3 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_COMLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/compras/pedidos", {})

/*/{Protheus.doc} GEBWAPI_FORLST
    GET /api/compras/fornecedores -- fornecedores GCP1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FORLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/compras/fornecedores", {})

/*/{Protheus.doc} GEBWAPI_FILLST
    GET /api/filiais -- filiais GEF1 do tenant (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FILLST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/filiais", {})

/*/{Protheus.doc} GEBWAPI_FILSC
    POST /api/filiais -- cadastra filial EEUUFF (auth).
    Body JSON: codigo, nome.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FILSC(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aBody := {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "NOME")}
Return GEBWAPIW_POST(cTok, cEmp, "/filiais", aBody)

/*/{Protheus.doc} GEBWAPI_VINCSC
    POST /api/vinculos -- vincula usuario a empresa+filial (auth).
    Body JSON: usuario, empresa, filial.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_VINCSC(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aBody := {GEBWAPIFIELD(oReq, "USUARIO"), GEBWAPIFIELD(oReq, "EMPRESA"), GEBWAPIFIELD(oReq, "FILIAL")}
Return GEBWAPIW_POST(cTok, cEmp, "/vinculos", aBody)

/*/{Protheus.doc} GEBWAPI_PUBEMP
    GET /api/public/empresas -- empresas para o seletor de ambiente
    (publico, sem token).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_PUBEMP(oReq)
    Local aArea := GetArea()
    Local aRes  := {}
    Local aRet  := {}
    aRes := GEBREST("GET", "/public/empresas", {}, "system", "web")
    aRet := GEBWAPIRESP(aRes)
    If Len(aArea) > 0
        RestArea(aArea)
    EndIf
Return aRet

/*/{Protheus.doc} GEBWAPI_DERGER
    POST /api/derrama/gerar -- gera guia (auth). Body: competencia.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_DERGER(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "COMPETENCIA")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/derrama/gerar", aBody)

/*/{Protheus.doc} GEBWAPI_DERBAI
    POST /api/derrama/baixar -- quita guia (auth). Body: guia.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_DERBAI(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "GUIA")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/derrama/baixar", aBody)

/*/{Protheus.doc} GEBWAPI_DERPAR
    POST /api/derrama/parcelar -- parcela guia (auth). Body: guia, parcelas.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_DERPAR(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "GUIA"), GEBWAPIFIELD(oReq, "PARCELAS")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/derrama/parcelar", aBody)

/*/{Protheus.doc} GEBWAPI_DERJUR
    POST /api/derrama/juros -- calcula juros (auth). Body: guia, dias.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_DERJUR(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "GUIA"), GEBWAPIFIELD(oReq, "DIAS")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/derrama/juros", aBody)

/*/{Protheus.doc} GEBWAPI_DERPRO
    POST /api/derrama/protestar -- protesta guia (auth). Body: guia.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_DERPRO(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "GUIA")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/derrama/protestar", aBody)

/*/{Protheus.doc} GEBWAPI_ESTVEN
    POST /api/estoque/vender -- vende (auth). Body: venda, produto, quantidade, preco.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_ESTVEN(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "VENDA"), GEBWAPIFIELD(oReq, "PRODUTO"), GEBWAPIFIELD(oReq, "QUANTIDADE"), GEBWAPIFIELD(oReq, "PRECO")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/estoque/vender", aBody)

/*/{Protheus.doc} GEBWAPI_ESTFIA
    POST /api/estoque/fiado -- vende fiado (auth). Body: cliente, valor.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_ESTFIA(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "CLIENTE"), GEBWAPIFIELD(oReq, "VALOR")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/estoque/fiados", aBody)

/*/{Protheus.doc} GEBWAPI_ESTFIJ
    POST /api/estoque/fiados/juros -- juros do fiado (auth). Body: cliente, dias.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_ESTFIJ(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "CLIENTE"), GEBWAPIFIELD(oReq, "DIAS")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/estoque/fiados/juros", aBody)

/*/{Protheus.doc} GEBWAPI_CTBDIR
    POST /api/contabil/lancar -- lancamento direto (auth). Body: debito, credito, valor.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_CTBDIR(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "DEBITO"), GEBWAPIFIELD(oReq, "CREDITO"), GEBWAPIFIELD(oReq, "VALOR")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/contabil/lancar", aBody)

/*/{Protheus.doc} GEBWAPI_CTBBAL
    GET /api/contabil/balancete/{comp} -- balancete (auth, via dispatcher).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_CTBBAL(oReq)
    Local cTok := ""
    Local cEmp := ""
    Local cComp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cComp := GEBWAPIFIELD(oReq, "COMP")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/contabil/balancete/" + cComp, {})

/*/{Protheus.doc} GEBWAPI_CTBDRE
    GET /api/contabil/dre/{comp} -- DRE (auth, via dispatcher).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_CTBDRE(oReq)
    Local cTok := ""
    Local cEmp := ""
    Local cComp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cComp := GEBWAPIFIELD(oReq, "COMP")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/contabil/dre/" + cComp, {})

/*/{Protheus.doc} GEBWAPI_FINCON
    POST /api/financeiro/contas -- cria conta (auth). Body: conta, nome.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FINCON(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "CONTA"), GEBWAPIFIELD(oReq, "NOME")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/financeiro/contas", aBody)

/*/{Protheus.doc} GEBWAPI_FINBAI
    POST /api/financeiro/baixar -- baixa titulo (auth). Body: tipo, documento, valor.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FINBAI(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "TIPO"), GEBWAPIFIELD(oReq, "DOCUMENTO"), GEBWAPIFIELD(oReq, "VALOR")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/financeiro/baixar", aBody)

/*/{Protheus.doc} GEBWAPI_COMFOR
    POST /api/compras/fornecedores -- cadastra (auth). Body: codigo, nome.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_COMFOR(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "NOME")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/compras/fornecedores", aBody)

/*/{Protheus.doc} GEBWAPI_FISAPU
    POST /api/fiscal/apurar -- apura competencia (auth). Body: competencia.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FISAPU(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "COMPETENCIA")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/apurar", aBody)

/*/{Protheus.doc} GEBWAPI_SNCFG
    POST /api/fiscal/simples/config (anexo, inicio), /folha (competencia,
    folha, receita_externa) e /apurar (competencia) -- Simples Nacional (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBWAPI_SNCFG(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/config", ;
    {GEBWAPIFIELD(oReq, "ANEXO"), GEBWAPIFIELD(oReq, "INICIO")})

User Function GEBWAPI_SNFOL(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/folha", ;
    {GEBWAPIFIELD(oReq, "COMPETENCIA"), GEBWAPIFIELD(oReq, "FOLHA"), GEBWAPIFIELD(oReq, "RECEITA_EXTERNA"), GEBWAPIFIELD(oReq, "ATIVIDADE")})

User Function GEBWAPI_SNAPU(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/apurar", ;
    {GEBWAPIFIELD(oReq, "COMPETENCIA")})

User Function GEBWAPI_SNATV(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/atividade", ;
    {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "DESCRICAO"), GEBWAPIFIELD(oReq, "ANEXO")})

User Function GEBWAPI_SNPRD(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/produto", ;
    {GEBWAPIFIELD(oReq, "PRODUTO"), GEBWAPIFIELD(oReq, "ATIVIDADE"), GEBWAPIFIELD(oReq, "ST"), GEBWAPIFIELD(oReq, "MONOFASICO")})

User Function GEBWAPI_SNEXP(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/exportacao", ;
    {GEBWAPIFIELD(oReq, "CHAVE"), GEBWAPIFIELD(oReq, "EXPORTACAO")})

User Function GEBWAPI_SNFER(oReq)
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/simples/feriado", ;
    {GEBWAPIFIELD(oReq, "DATA"), GEBWAPIFIELD(oReq, "DESCRICAO")})

/*/{Protheus.doc} GEBWAPI_BOPOST
    POST/GET /api/bo/{modulo}/{acao} -- backoffice (auth). Os campos do corpo
    e da query vao inteiros para GEBBOEXEC (GEBBO.prw), que le cada um pelo
    nome; listas (itens, pagamentos) vao como arrays de objetos.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 18/10/2026
/*/
User Function GEBWAPI_BOPOST(oReq)
Return GEBWAPIBO("POST", oReq)

User Function GEBWAPI_BOGET(oReq)
Return GEBWAPIBO("GET", oReq)

Static Function GEBWAPIBO(cMetodo, oReq)
    Local aAuth := GEBWAPIAUTH(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"))
    If !(aAuth[1])
        Return GEBWAPIDENY()
    EndIf
Return GEBWAPIRESP(GEBREST(cMetodo, "/bo/" + Lower(BOCOL(oReq["MODULO"])) + "/" + Lower(BOCOL(oReq["ACAO"])), {oReq}, aAuth[2], "web:" + aAuth[2]))

// GET /api/fiscal/simples/extrato/{comp} e /anual/{ano} -- relatorios do Simples (auth).
User Function GEBWAPI_SNEXT(oReq)
Return GEBWAPIW_GET(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "GET", "/fiscal/simples/extrato/" + GEBWAPIFIELD(oReq, "COMP"), {})

User Function GEBWAPI_SNANU(oReq)
Return GEBWAPIW_GET(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "GET", "/fiscal/simples/anual/" + GEBWAPIFIELD(oReq, "ANO"), {})

/*/{Protheus.doc} GEBWAPI_FISCRE
    POST /api/fiscal/creditos -- lanca credito (auth). Body: competencia, origem, valor, tipo.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_FISCRE(oReq)
    Local aBody := {}
    aBody := {GEBWAPIFIELD(oReq, "COMPETENCIA"), GEBWAPIFIELD(oReq, "ORIGEM"), GEBWAPIFIELD(oReq, "VALOR"), GEBWAPIFIELD(oReq, "TIPO")}
Return GEBWAPIW_POST(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"), "/fiscal/creditos", aBody)

/*/{Protheus.doc} GEBWAPI_UNILST
    GET /api/unidades -- unidades GEU1 (auth).
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_UNILST(oReq)
    Local cTok := ""
    Local cEmp := ""
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
Return GEBWAPIW_GET(cTok, cEmp, "GET", "/unidades", {})

/*/{Protheus.doc} GEBWAPI_UNILSC
    POST /api/unidades -- cadastra unidade UU (auth).
    Body JSON: codigo, nome.
    @type Rota HTTP
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWAPI_UNILSC(oReq)
    Local cTok  := ""
    Local cEmp  := ""
    Local aBody := {}
    cTok := GEBWAPIFIELD(oReq, "TOKEN")
    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    aBody := {GEBWAPIFIELD(oReq, "CODIGO"), GEBWAPIFIELD(oReq, "NOME")}
Return GEBWAPIW_POST(cTok, cEmp, "/unidades", aBody)

/*/{Protheus.doc} GEBWAPI_DFEPAG
    GET /api/dfe/configurar -- pagina (publica) do assistente fiscal: entra
    com empresa/usuario/senha (POST /api/login) e, com o token, mostra o
    roteiro "o que falta para emitir", cadastra o emitente (com busca de
    municipio IBGE), envia o certificado A1 (.pfx lido no navegador e
    enviado em Base64) e grava a configuracao da NFC-e -- tudo pelas rotas
    /api/bo/dfe/* (permissao FISCAL/DFE). Nada fica guardado no navegador.
    @type Rota HTTP (HTML)
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBWAPI_DFEPAG(oReq)
Return {"__RAW_HTTP__", "text/html; charset=utf-8", GEBDFEPAGHTML(), 200}

/*/{Protheus.doc} GEBWAPI_DFEDANFE
    GET /api/dfe/danfe?token=&empresa=&chave= (ou &cupom=) -- DANFE NFC-e em
    HTML para imprimir (permissao LOJA/CAIXA ou FISCAL/DFE).
    @type Rota HTTP (HTML)
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBWAPI_DFEDANFE(oReq)
    Local aAuth := GEBWAPIAUTH(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"))
    Local cCh := ""
    Local aR := {}
    Local aH := {}
    If !(aAuth[1])
        Return GEBWAPIDENY()
    EndIf
    If !GEBSECRBAC(aAuth[2], "LOJA", "CAIXA") .And. !GEBSECRBAC(aAuth[2], "FISCAL", "DFE")
        Return {"__RAW_HTTP__", "text/plain; charset=utf-8", "sem permissao", 403}
    EndIf
    cCh := GEBDFEDIG(BOSTR(oReq["CHAVE"]))
    If cCh == "" .And. !(BOCOL(oReq["CUPOM"]) == "")
        aH := TCSqlQuery("SELECT GLJ3_NOTA AS N FROM GLJ3 WHERE GLJ3_FILIAL = " + GEBDBQuote(FWxFilial("GLJ3")) + " AND GLJ3_CUPOM = " + ;
            GEBDBQuote(Upper(BOCOL(oReq["CUPOM"]))) + " AND D_E_L_E_T_ = ' '")
        If Len(aH) > 0
            cCh := BOCOL(aH[1]:N)
        EndIf
    EndIf
    // NFS-e (chave de 50 posicoes): o DANFSe oficial em PDF, do ADN.
    If Len(cCh) == 50
        aR := GEBDFEDANFSE(cCh)
        If !aR[1]
            Return {"__RAW_HTTP__", "text/plain; charset=utf-8", aR[2], 404}
        EndIf
        Return {"__RAW_HTTP__", "application/pdf", aR[3], 200}
    EndIf
    aR := GEBDFEDANFE(cCh)
    If !aR[1]
        Return {"__RAW_HTTP__", "text/plain; charset=utf-8", aR[2], 404}
    EndIf
Return {"__RAW_HTTP__", "text/html; charset=utf-8", aR[3], 200}

// Pagina do assistente fiscal (ASCII: acentos como entidades HTML / escapes JS).
/*/{Protheus.doc} GEBWAPI_DFEEFD
    GET /api/dfe/efd?token=&empresa=&competencia= -- arquivo da EFD ICMS/IPI
    gerado (texto para o PVA). Permissao FISCAL/DFE.
    @type Rota HTTP (texto)
    @author Peder Munksgaard
    @since 19/10/2026
/*/
User Function GEBWAPI_DFEEFD(oReq)
    Local aAuth := GEBWAPIAUTH(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"))
    Local cArq := ""
    If !(aAuth[1])
        Return GEBWAPIDENY()
    EndIf
    If !GEBSECRBAC(aAuth[2], "FISCAL", "DFE")
        Return {"__RAW_HTTP__", "text/plain; charset=utf-8", "sem permissao", 403}
    EndIf
    cArq := GEBDFEEFDLE(BOCOL(oReq["COMPETENCIA"]))
    If cArq == ""
        Return {"__RAW_HTTP__", "text/plain; charset=utf-8", "efd_nao_gerada: gere a competencia antes", 404}
    EndIf
Return {"__RAW_HTTP__", "text/plain; charset=iso-8859-1", cArq, 200}

Static Function GEBDFEPAGHTML()
    Local cH := ""
    cH += '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
    cH += '<title>GEBAN - Configura&ccedil;&atilde;o fiscal</title><style>'
    cH += ':root{--bg:#f6f7f9;--card:#fff;--tx:#1d2330;--mut:#5d6677;--bd:#d9dde5;--ac:#0b6bcb;--ok:#18794e;--at:#9a6700;--er:#c0262d}'
    cH += '@media (prefers-color-scheme:dark){:root{--bg:#14171c;--card:#1d2128;--tx:#e6e9ef;--mut:#9aa3b2;--bd:#323844;--ac:#5aa6f2;--ok:#4cc38a;--at:#e0b14d;--er:#f2777c}}'
    cH += '*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.45 system-ui,-apple-system,Segoe UI,Roboto,sans-serif}'
    cH += 'main{max-width:860px;margin:0 auto;padding:16px}h1{font-size:22px;margin:8px 0 4px}h2{font-size:17px;margin:0 0 10px}'
    cH += '.sub{color:var(--mut);margin:0 0 16px}section{background:var(--card);border:1px solid var(--bd);border-radius:10px;padding:16px;margin:0 0 14px}'
    cH += 'label{display:block;font-size:13px;color:var(--mut);margin:8px 0 3px}input,select{width:100%;padding:9px 10px;border:1px solid var(--bd);'
    cH += 'border-radius:7px;background:var(--bg);color:var(--tx);font:inherit}.g{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:0 12px}'
    cH += 'button{margin-top:12px;padding:9px 16px;border:0;border-radius:7px;background:var(--ac);color:#fff;font:inherit;font-weight:600;cursor:pointer}'
    cH += 'button.s{background:transparent;color:var(--ac);border:1px solid var(--ac)}.msg{margin-top:10px;font-size:14px}.msg.e{color:var(--er)}.msg.o{color:var(--ok)}'
    cH += 'table{width:100%;border-collapse:collapse;font-size:14px}td{padding:7px 6px;border-top:1px solid var(--bd);vertical-align:top}'
    cH += '.st{font-weight:700;white-space:nowrap}.OK{color:var(--ok)}.FALTA{color:var(--er)}.ATENCAO{color:var(--at)}.hid{display:none}'
    cH += '</style></head><body><main><h1>Configura&ccedil;&atilde;o fiscal (NFC-e, NF-e e NFS-e)</h1>'
    cH += '<p class="sub">Siga o roteiro: cada item em <b class="FALTA">FALTA</b> impede a emiss&atilde;o.</p>'
    cH += '<section id="sLogin"><h2>Entrar</h2><div class="g"><div><label>Empresa</label><input id="lEmp" autocomplete="organization"></div>'
    cH += '<div><label>Usu&aacute;rio</label><input id="lUsu" autocomplete="username"></div><div><label>Senha</label><input id="lSen" type="password" autocomplete="current-password"></div>'
    cH += '<div id="dFil" class="hid"><label>Filial</label><select id="lFil"></select></div></div><button onclick="entrar()">Entrar</button><div id="mLogin" class="msg"></div></section>'
    cH += '<div id="app" class="hid">'
    cH += '<section><h2>O que falta para emitir</h2><table id="tRot"></table><button class="s" onclick="roteiro(true)">Testar comunica&ccedil;&atilde;o com a SEFAZ</button><div id="mRot" class="msg"></div></section>'
    cH += '<section><h2>1. Emitente</h2><div class="g">'
    cH += DFECampo("CNPJ", "cnpj") + DFECampo("Inscri&ccedil;&atilde;o estadual", "ie") + DFECampo("Raz&atilde;o social", "razao") + DFECampo("Nome fantasia", "fantasia")
    cH += '<div><label>Regime</label><select id="crt"><option value="1">Simples Nacional</option><option value="4">MEI</option>'
    cH += '<option value="2">Simples - excesso de sublimite</option><option value="3">Regime normal</option></select></div>'
    cH += DFECampo("Inscri&ccedil;&atilde;o municipal", "im") + DFECampo("CNAE", "cnae") + DFECampo("Logradouro", "logradouro") + DFECampo("N&uacute;mero", "numero")
    cH += DFECampo("Complemento", "complemento") + DFECampo("Bairro", "bairro")
    cH += '<div><label>UF</label><select id="uf"></select></div><div><label>Munic&iacute;pio (digite e escolha)</label><input id="munBusca" oninput="buscaMun()">'
    cH += '<select id="municipio"></select></div>' + DFECampo("CEP", "cep") + DFECampo("Telefone", "fone") + DFECampo("E-mail", "email")
    cH += '</div><button onclick="salvarEmit()">Salvar emitente</button><div id="mEmit" class="msg"></div></section>'
    cH += '<section><h2>2. Certificado digital A1</h2><div class="g"><div><label>Arquivo .pfx</label><input id="pfx" type="file" accept=".pfx,.p12"></div>'
    cH += '<div><label>Senha do certificado</label><input id="pfxSenha" type="password" autocomplete="off"></div></div>'
    cH += '<button onclick="enviarCert()">Enviar certificado</button><div id="mCert" class="msg"></div></section>'
    cH += '<section><h2>3. Emiss&atilde;o</h2><div class="g"><div><label>Ambiente</label><select id="ambiente"><option value="2">Homologa&ccedil;&atilde;o (testes)</option>'
    cH += '<option value="1">Produ&ccedil;&atilde;o</option></select></div><div><label>NFC-e na frente de loja</label><select id="nfce"><option value="N">Desligada</option>'
    cH += '<option value="S">Ligada</option></select></div>' + DFECampo("S&eacute;rie da NFC-e", "serie_nfce") + DFECampo("Pr&oacute;ximo n&uacute;mero (s&oacute; se vier de outro sistema)", "proximo_nfce")
    cH += '<div><label>NF-e no faturamento e devolu&ccedil;&otilde;es</label><select id="nfe"><option value="N">Desligada</option><option value="S">Ligada</option></select></div>'
    cH += DFECampo("S&eacute;rie da NF-e", "serie_nfe")
    cH += '<div><label>NFS-e (servi&ccedil;os, padr&atilde;o nacional)</label><select id="nfse"><option value="N">Desligada</option><option value="S">Ligada</option></select></div>'
    cH += DFECampo("S&eacute;rie da DPS (NFS-e)", "serie_nfse") + DFECampo("Inscri&ccedil;&atilde;o municipal: no emitente; % tributos Simples na NFS-e (opcional)", "nfse_perc_trib_sn")
    cH += DFECampo("CFOP padr&atilde;o", "cfop") + DFECampo("CSOSN padr&atilde;o (Simples)", "csosn") + DFECampo("Unidade padr&atilde;o", "unidade")
    cH += DFECampo("ID do CSC (s&oacute; se a UF pedir)", "csc_id") + DFECampo("C&oacute;digo CSC", "csc") + DFECampo("Resp. t&eacute;cnico: CNPJ", "rt_cnpj")
    cH += DFECampo("Resp. t&eacute;cnico: contato", "rt_contato") + DFECampo("Resp. t&eacute;cnico: e-mail", "rt_email") + DFECampo("Resp. t&eacute;cnico: telefone", "rt_fone")
    cH += '</div><button onclick="salvarCfg()">Salvar configura&ccedil;&atilde;o</button><div id="mCfg" class="msg"></div></section>'
    cH += '<section><h2>4. Tributos aproximados no cupom (Lei 12.741)</h2><p class="sub">Baixe o CSV da sua UF em deolhonoimposto.ibpt.org.br e envie aqui.</p>'
    cH += '<div class="g"><div><label>Arquivo CSV do IBPT</label><input id="ibpt" type="file" accept=".csv"></div><div><label>UF da tabela</label><select id="ibptUf"></select></div></div>'
    cH += '<button onclick="enviarIbpt()">Importar tabela</button><div id="mIbpt" class="msg"></div></section>'
    cH += '<section><h2>Imprimir DANFE (NFC-e ou NF-e)</h2><div class="g"><div><label>Cupom (ou chave de acesso)</label><input id="dCupom"></div></div>'
    cH += '<button onclick="danfe()">Abrir para imprimir</button></section>'
    cH += '<section><h2>5. SPED Fiscal (EFD ICMS/IPI)</h2><p class="sub">Regime normal. Gere a compet&ecirc;ncia, baixe o arquivo e valide/transmita pelo PVA da Receita.</p><div class="g">'
    cH += DFECampo("Contabilista: nome", "cont_nome") + DFECampo("Contabilista: CPF", "cont_cpf") + DFECampo("Contabilista: CRC", "cont_crc")
    cH += DFECampo("Contabilista: e-mail", "cont_email") + DFECampo("Contabilista: munic&iacute;pio IBGE (7 d&iacute;gitos)", "cont_municipio")
    cH += DFECampo("Escrit&oacute;rio: CNPJ (opcional)", "cont_cnpj") + DFECampo("Contabilista: telefone", "cont_fone")
    cH += DFECampo("Perfil (A, B ou C)", "efd_perfil") + DFECampo("Atividade (0 industrial, 1 outros)", "efd_atividade")
    cH += DFECampo("C&oacute;d. receita ICMS pr&oacute;prio", "efd_cod_rec") + DFECampo("C&oacute;d. receita ICMS ST", "efd_cod_rec_st")
    cH += DFECampo("C&oacute;d. receita DIFAL", "efd_cod_rec_difal") + DFECampo("C&oacute;d. receita FCP", "efd_cod_rec_fcp")
    cH += DFECampo("Dia do vencimento do ICMS", "efd_dia_venc") + DFECampo("Saldo credor antes do 1&ordm; arquivo", "efd_saldo_credor_inicial")
    cH += '</div><button class="s" onclick="salvarEfd()">Salvar dados da EFD</button><div class="g">' + DFECampo("Compet&ecirc;ncia (AAAAMM)", "efdComp")
    cH += '<div><label>Finalidade</label><select id="efdFin"><option value="0">Original</option><option value="1">Substituto</option></select></div></div>'
    cH += '<button onclick="gerarEfd()">Gerar</button> <button class="s" onclick="baixarEfd()">Baixar arquivo</button><div id="mEfd" class="msg"></div></section></div></main><script>'

    cH += 'var S={};var UFS="AC AL AM AP BA CE DF ES GO MA MG MS MT PA PB PE PI PR RJ RN RO RR RS SC SE SP TO".split(" ");'
    cH += 'function $(i){return document.getElementById(i)}function msg(i,t,ok){var e=$(i);e.textContent=t;e.className="msg "+(ok?"o":"e")}'
    cH += 'UFS.forEach(function(u){["uf","ibptUf"].forEach(function(i){var o=document.createElement("option");o.value=o.textContent=u;$(i).appendChild(o)})});'
    cH += 'function api(m,rota,dados){var q="token="+encodeURIComponent(S.token)+"&empresa="+encodeURIComponent(S.empresa);'
    cH += 'if(m==="GET"){Object.keys(dados||{}).forEach(function(k){q+="&"+k+"="+encodeURIComponent(dados[k])});'
    cH += 'return fetch("/api/bo/"+rota+"?"+q).then(function(r){return r.json()})}'
    cH += 'var b=Object.assign({token:S.token,empresa:S.empresa},dados||{});return fetch("/api/bo/"+rota,{method:"POST",headers:{"Content-Type":"application/json"},'
    cH += 'body:JSON.stringify(b)}).then(function(r){return r.json()})}'
    cH += 'function texto(r){if(r.status==="ok")return r.dados[0];return (r.erros||["falha"]).join("; ").replace(/_/g," ")}'
    cH += 'function entrar(){var b={empresa:$("lEmp").value.trim(),usuario:$("lUsu").value.trim(),senha:$("lSen").value};if(!$("dFil").classList.contains("hid"))b.filial=$("lFil").value;'
    cH += 'fetch("/api/login",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify(b)}).then(function(r){return r.json()}).then(function(r){'
    cH += 'if(r.ok&&r.selecionar){var s=$("lFil");s.innerHTML="";r.filiais.forEach(function(f){var o=document.createElement("option");o.value=f[0];o.textContent=f[0]+" - "+f[1];s.appendChild(o)});'
    cH += '$("dFil").classList.remove("hid");msg("mLogin","Escolha a filial e entre de novo.",true);return}'
    cH += 'if(!r.ok){msg("mLogin",r.erro||"credenciais inválidas",false);return}S.token=r.token;S.empresa=r.empresa;$("lSen").value="";'
    cH += '$("sLogin").classList.add("hid");$("app").classList.remove("hid");carregar()}).catch(function(){msg("mLogin","Sem comunicação com o servidor",false)})}'
    cH += 'function roteiro(testar){msg("mRot",testar?"Testando...":"",true);api("GET","dfe/roteiro",{testar:testar?"S":"N"}).then(function(r){var t=$("tRot");t.innerHTML="";'
    cH += 'if(r.status!=="ok"){msg("mRot",texto(r),false);return}(r.dados[1]||[]).forEach(function(l){var tr=t.insertRow();tr.insertCell().textContent=l[0];'
    cH += 'var c=tr.insertCell();c.textContent=l[1];c.className="st "+l[1];tr.insertCell().textContent=l[2]});msg("mRot",r.dados[0],true)})}'
    cH += 'var CAMPOS={cnpj:"cnpj",ie:"ie",im:"im",cnae:"cnae",razao:"xnome",fantasia:"xfant",crt:"crt",logradouro:"xlgr",numero:"nro",complemento:"xcpl",bairro:"xbairro",uf:"uf",cep:"cep",fone:"fone",email:"email"};'
    cH += 'function carregar(){roteiro(false);api("GET","dfe/emitente").then(function(r){if(r.status!=="ok")return;var m={};(r.dados[1]||[]).forEach(function(p){m[p[0]]=p[1]});'
    cH += 'Object.keys(CAMPOS).forEach(function(k){if(m[CAMPOS[k]]!==undefined)$(k).value=m[CAMPOS[k]]});if(m.cmun){var o=document.createElement("option");o.value=m.cmun;'
    cH += 'o.textContent=m.xmun;$("municipio").innerHTML="";$("municipio").appendChild(o)}})}'
    cH += 'var tBusca;function buscaMun(){clearTimeout(tBusca);tBusca=setTimeout(function(){var n=$("munBusca").value.trim();if(n.length<3)return;'
    cH += 'api("GET","dfe/municipios",{nome:n,uf:$("uf").value}).then(function(r){var s=$("municipio");s.innerHTML="";(r.dados&&r.dados[1]||[]).slice(0,50).forEach(function(m){'
    cH += 'var o=document.createElement("option");o.value=m[0];o.textContent=m[1]+" ("+m[0]+")";s.appendChild(o)})})},300)}'
    cH += 'function salvarEmit(){var d={municipio:$("municipio").value};Object.keys(CAMPOS).forEach(function(k){d[k]=$(k).value.trim()});'
    cH += 'api("POST","dfe/emitente",d).then(function(r){msg("mEmit",texto(r),r.status==="ok");roteiro(false)})}'
    cH += 'function enviarCert(){var f=$("pfx").files[0];if(!f){msg("mCert","Escolha o arquivo .pfx",false);return}var rd=new FileReader();rd.onload=function(){'
    cH += 'var b64=String(rd.result).split(",")[1];msg("mCert","Enviando...",true);api("POST","dfe/certificado",{pfx:b64,senha:$("pfxSenha").value}).then(function(r){'
    cH += '$("pfxSenha").value="";msg("mCert",texto(r),r.status==="ok");roteiro(false)})};rd.readAsDataURL(f)}'
    cH += 'function salvarCfg(){var d={};["ambiente","nfce","serie_nfce","proximo_nfce","nfe","serie_nfe","nfse","serie_nfse","nfse_perc_trib_sn","cfop","csosn","unidade","csc_id","csc","rt_cnpj","rt_contato","rt_email","rt_fone"].forEach(function(k){'
    cH += 'var v=$(k).value.trim();if(v!=="")d[k]=v});api("POST","dfe/configuracao",d).then(function(r){msg("mCfg",texto(r),r.status==="ok");roteiro(false)})}'
    cH += 'function enviarIbpt(){var f=$("ibpt").files[0];if(!f){msg("mIbpt","Escolha o arquivo CSV",false);return}var rd=new FileReader();'
    cH += 'rd.onload=function(){msg("mIbpt","Importando...",true);api("POST","dfe/ibpt",{uf:$("ibptUf").value,conteudo:String(rd.result)}).then(function(r){'
    cH += 'msg("mIbpt",texto(r),r.status==="ok");roteiro(false)})};rd.readAsText(f,"ISO-8859-1")}'
    cH += 'function danfe(){var v=$("dCupom").value.trim().replace(/\s/g,"");if(!v)return;var p=/^([0-9]{44}|[0-9]{50})$/.test(v)?"chave":"cupom";'
    cH += 'window.open("/api/dfe/danfe?token="+encodeURIComponent(S.token)+"&empresa="+encodeURIComponent(S.empresa)+"&"+p+"="+encodeURIComponent(v),"_blank")}'
    cH += 'var EFD=["cont_nome","cont_cpf","cont_crc","cont_email","cont_municipio","cont_cnpj","cont_fone","efd_perfil","efd_atividade","efd_cod_rec","efd_cod_rec_st","efd_cod_rec_difal","efd_cod_rec_fcp","efd_dia_venc","efd_saldo_credor_inicial"];'
    cH += 'function salvarEfd(){var d={};EFD.forEach(function(k){var v=$(k).value.trim();if(v!=="")d[k]=v});api("POST","dfe/configuracao",d).then(function(r){msg("mEfd",texto(r),r.status==="ok")})}'
    cH += 'function gerarEfd(){msg("mEfd","Gerando...",true);api("POST","dfe/efd",{competencia:$("efdComp").value.trim(),finalidade:$("efdFin").value}).then(function(r){msg("mEfd",texto(r),r.status==="ok")})}'
    cH += 'function baixarEfd(){window.open("/api/dfe/efd?token="+encodeURIComponent(S.token)+"&empresa="+encodeURIComponent(S.empresa)+"&competencia="+encodeURIComponent($("efdComp").value.trim()),"_blank")}'
    cH += '</script></body></html>'
Return cH

Static Function DFECampo(cRotulo, cId)
Return '<div><label for="' + cId + '">' + cRotulo + '</label><input id="' + cId + '"></div>'
