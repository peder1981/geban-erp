#include "totvs.ch"
#include "GEBDB_CORE.prw"
#include "GEBDB_TENANT.prw"
#include "GENUC_MIG.prw"
#include "GEBSEC_MIG.prw"
#include "GEBSEC_POL.prw"
#include "GEBSEC_LOGIN.prw"
#include "GEBSEC_TOKEN.prw"
#include "GEBEXP_CTX.prw"
#include "GEBEXP_REL_BIZ.prw"
#include "GEBEXP_REL_NUC.prw"
#include "GENUC_MNT.prw"
#include "GENUC_CAD.prw"
#include "GEBAUD.prw"
#include "GEBWEB_API.prw"
#include "GEBPDV_API.prw"
#include "GEBPDV_HTML.prw"

/*/{Protheus.doc} GEBWEB
    Servidor HTTP real (WSRestServer, AdvPP nativo): API REST do ERP
    (integracoes). POST /api/login emite token (GEBSECLOGIN -> vinculo
    GE2_EMP -> GEBDBSchemaExists -> GEBDBSetTenant); as rotas /api/*
    (src/GEBWEB_API.prw) expoem o dispatcher U_GEBREST com auth por
    token (?token=...&empresa=...) e status HTTP reais. A interface
    humana e' nativa AdvPL (src/GEBTUI.prw, via advplc serve).
    @type Servidor web
    @author Peder Munksgaard
    @since 25/09/2026
    @param nPorta Porta TCP (default 8090)
/*/
User Function GEBWEB(nPorta)
    Local oSrv := Nil

    If nPorta == Nil
        nPorta := 8090
    EndIf

    If !GEBDBConecta()
        ConOut("GEBWEB: GEBDBConecta falhou")
        Return .F.
    EndIf
    If !GEBDBProvisionaCatalogo()
        ConOut("GEBWEB: GEBDBProvisionaCatalogo falhou")
        Return .F.
    EndIf

    oSrv := WSRestServer():New("geban-web", "1.0")
    oSrv:AddRoute("POST", "/api/login", "U_GEBWEB_LOGINAPI")
    oSrv:AddRoute("GET", "/api/health", "U_GEBWAPI_HEALTH")
    oSrv:AddRoute("GET", "/api/public/empresas", "U_GEBWAPI_PUBEMP")
    oSrv:AddRoute("GET", "/api/usuarios", "U_GEBWAPI_USRLST")
    oSrv:AddRoute("GET", "/api/usuarios/{cod}", "U_GEBWAPI_USRGET")
    oSrv:AddRoute("POST", "/api/usuarios", "U_GEBWAPI_USRPOST")
    oSrv:AddRoute("PUT", "/api/usuarios/{cod}", "U_GEBWAPI_USRPUT")
    oSrv:AddRoute("DELETE", "/api/usuarios/{cod}", "U_GEBWAPI_USRDEL")
    oSrv:AddRoute("GET", "/api/empresas", "U_GEBWAPI_EMPLST")
    oSrv:AddRoute("POST", "/api/empresas", "U_GEBWAPI_EMPLSC")
    oSrv:AddRoute("GET", "/api/produtos", "U_GEBWAPI_PRDLST")
    oSrv:AddRoute("POST", "/api/produtos", "U_GEBWAPI_PRDLSC")
    oSrv:AddRoute("GET", "/api/notas", "U_GEBWAPI_NOTLST")
    oSrv:AddRoute("POST", "/api/notas", "U_GEBWAPI_NOTPOST")
    oSrv:AddRoute("GET", "/api/financeiro/fluxo", "U_GEBWAPI_FLXLST")
    oSrv:AddRoute("GET", "/api/financeiro/contas", "U_GEBWAPI_CONLST")
    oSrv:AddRoute("GET", "/api/fiscal/relatorio/{comp}", "U_GEBWAPI_RELFISC")
    oSrv:AddRoute("GET", "/api/relatorios/gerencial", "U_GEBWAPI_RELGER")
    oSrv:AddRoute("GET", "/api/monitor/usuarios", "U_GEBWAPI_MONUSU")
    oSrv:AddRoute("DELETE", "/api/monitor/sessao/{sessao}", "U_GEBWAPI_MONDEL")
    oSrv:AddRoute("GET", "/api/derrama/guias", "U_GEBWAPI_DERLST")
    oSrv:AddRoute("GET", "/api/estoque", "U_GEBWAPI_ESTLST")
    oSrv:AddRoute("GET", "/api/estoque/vendas", "U_GEBWAPI_VENLST")
    oSrv:AddRoute("GET", "/api/contabil/lancamentos", "U_GEBWAPI_CTBLST")
    oSrv:AddRoute("GET", "/api/contabil/contas", "U_GEBWAPI_CTCLST")
    oSrv:AddRoute("GET", "/api/compras/pedidos", "U_GEBWAPI_COMLST")
    oSrv:AddRoute("GET", "/api/compras/fornecedores", "U_GEBWAPI_FORLST")
    oSrv:AddRoute("GET", "/api/unidades", "U_GEBWAPI_UNILST")
    oSrv:AddRoute("POST", "/api/unidades", "U_GEBWAPI_UNILSC")
    oSrv:AddRoute("GET", "/api/filiais", "U_GEBWAPI_FILLST")
    oSrv:AddRoute("POST", "/api/filiais", "U_GEBWAPI_FILSC")
    oSrv:AddRoute("POST", "/api/vinculos", "U_GEBWAPI_VINCSC")
    oSrv:AddRoute("POST", "/api/derrama/gerar", "U_GEBWAPI_DERGER")
    oSrv:AddRoute("POST", "/api/derrama/baixar", "U_GEBWAPI_DERBAI")
    oSrv:AddRoute("POST", "/api/derrama/parcelar", "U_GEBWAPI_DERPAR")
    oSrv:AddRoute("POST", "/api/derrama/juros", "U_GEBWAPI_DERJUR")
    oSrv:AddRoute("POST", "/api/derrama/protestar", "U_GEBWAPI_DERPRO")
    oSrv:AddRoute("POST", "/api/estoque/vender", "U_GEBWAPI_ESTVEN")
    oSrv:AddRoute("POST", "/api/estoque/fiados", "U_GEBWAPI_ESTFIA")
    oSrv:AddRoute("POST", "/api/estoque/fiados/juros", "U_GEBWAPI_ESTFIJ")
    oSrv:AddRoute("POST", "/api/contabil/lancar", "U_GEBWAPI_CTBDIR")
    oSrv:AddRoute("GET", "/api/contabil/balancete/{comp}", "U_GEBWAPI_CTBBAL")
    oSrv:AddRoute("GET", "/api/contabil/dre/{comp}", "U_GEBWAPI_CTBDRE")
    oSrv:AddRoute("POST", "/api/financeiro/contas", "U_GEBWAPI_FINCON")
    oSrv:AddRoute("POST", "/api/financeiro/baixar", "U_GEBWAPI_FINBAI")
    oSrv:AddRoute("POST", "/api/compras/fornecedores", "U_GEBWAPI_COMFOR")
    oSrv:AddRoute("POST", "/api/compras/pedidos", "U_GEBWAPI_COMPED")
    oSrv:AddRoute("POST", "/api/compras/itens", "U_GEBWAPI_COMIT")
    oSrv:AddRoute("POST", "/api/compras/entradas", "U_GEBWAPI_COMENT")
    oSrv:AddRoute("POST", "/api/fiscal/apurar", "U_GEBWAPI_FISAPU")
    oSrv:AddRoute("POST", "/api/fiscal/creditos", "U_GEBWAPI_FISCRE")
    oSrv:AddRoute("POST", "/api/fiscal/simples/config", "U_GEBWAPI_SNCFG")
    oSrv:AddRoute("POST", "/api/fiscal/simples/folha", "U_GEBWAPI_SNFOL")
    oSrv:AddRoute("POST", "/api/fiscal/simples/apurar", "U_GEBWAPI_SNAPU")
    oSrv:AddRoute("POST", "/api/fiscal/simples/atividade", "U_GEBWAPI_SNATV")
    oSrv:AddRoute("POST", "/api/fiscal/simples/produto", "U_GEBWAPI_SNPRD")
    oSrv:AddRoute("POST", "/api/fiscal/simples/exportacao", "U_GEBWAPI_SNEXP")
    oSrv:AddRoute("POST", "/api/fiscal/simples/feriado", "U_GEBWAPI_SNFER")
    oSrv:AddRoute("GET", "/api/fiscal/simples/extrato/{comp}", "U_GEBWAPI_SNEXT")
    oSrv:AddRoute("GET", "/api/fiscal/simples/anual/{ano}", "U_GEBWAPI_SNANU")
    oSrv:AddRoute("POST", "/api/bo/{modulo}/{acao}", "U_GEBWAPI_BOPOST")
    oSrv:AddRoute("GET", "/api/bo/{modulo}/{acao}", "U_GEBWAPI_BOGET")
    oSrv:AddRoute("GET", "/api/dfe/configurar", "U_GEBWAPI_DFEPAG")
    oSrv:AddRoute("GET", "/api/dfe/danfe", "U_GEBWAPI_DFEDANFE")
    oSrv:AddRoute("GET", "/api/dfe/efd", "U_GEBWAPI_DFEEFD")
    // Rotas PDV (frente de loja)
    oSrv:AddRoute("GET", "/api/pdv/caixa/lista", "U_GEBPDVCAIXALST")
    oSrv:AddRoute("POST", "/api/pdv/caixa/abrir", "U_GEBPDVCAIXAABR")
    oSrv:AddRoute("POST", "/api/pdv/caixa/fechar", "U_GEBPDVCAIXAFECH")
    oSrv:AddRoute("GET", "/api/pdv/caixa/resumo/{sessao}", "U_GEBPDVCAIXARESUMO")
    oSrv:AddRoute("POST", "/api/pdv/caixa/sangria", "U_GEBPDVSANGRIA")
    oSrv:AddRoute("POST", "/api/pdv/cupom/novo", "U_GEBPDVCUPOMNOV")
    oSrv:AddRoute("GET", "/api/pdv/cupom/{id}", "U_GEBPDVCUPOMGET")
    oSrv:AddRoute("POST", "/api/pdv/cupom/{id}/cancelar", "U_GEBPDVCUPCANC")
    oSrv:AddRoute("GET", "/api/pdv/produto/busca", "U_GEBPDVPRODUTBUSC")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/gerencial", "U_GEBPDVRELGER")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/gerencial/csv", "U_GEBPDVRELGERCSV")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/comissao", "U_GEBPDVRELCOM")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/comissao/csv", "U_GEBPDVRELCOMCSV")
    oSrv:AddRoute("GET", "/api/pdv/perifericos", "U_GEBPDVPERIFLIST")
    oSrv:AddRoute("POST", "/api/pdv/perifericos", "U_GEBPDVPERIFREG")
    oSrv:AddRoute("DELETE", "/api/pdv/perifericos/{id}", "U_GEBPDVPERIFDEL")
    // Interface PDV
    oSrv:AddRoute("GET", "/pdv", "U_GEBPDVHTML")
    oSrv:AddRoute("GET", "/pdv/ws", "U_GEBPDVWS")
    ConOut("GEBWEB: servindo em http://0.0.0.0:" + cValToChar(nPorta))
    oSrv:Serve(nPorta)
Return .T.

/*/{Protheus.doc} GEBWEB_LOGINAPI
    POST /api/login -- autentica de verdade. Mesmo caminho de GEBAN():
    valida formato (GEBDBSchemaValido) -> GEBSECLOGIN (catalogo, Argon2id)
    -> vinculo GE2_EMP (usuario+empresa+filial) -> GEBDBSchemaExists ->
    GEBDBSetTenant -> GEBEXPCONTEXTO (registra sessao). Fallback generico
    "credenciais invalidas" pra qualquer falha, sem diferenciar motivo
    (mesma defesa contra oraculo de enumeracao de usuario de GEBAN()).
    @type Rota HTTP (JSON)
    @author Peder Munksgaard
    @since 25/09/2026
/*/
User Function GEBWEB_LOGINAPI(oReq)
    Local cEmp := ""
    Local cUsu := ""
    Local cSen := ""
    Local cFilReq := ""
    Local cFilChk := ""
    Local lOk := .F.
    Local aChk := {}
    Local aVinc := {}
    Local aReg := {}
    Local aFiliais := {}
    Local aPar := {}
    Local cTok := ""
    Local nI := 0
    Local nJ := 0
    Local lAchou := .F.
    Local lRegTem := .F.
    Local cNome := ""
    Local lSuper := .F.

    If oReq == Nil .Or. oReq:EMPRESA == Nil
        cEmp := ""
    Else
        cEmp := AllTrim(cValToChar(oReq:EMPRESA))
    EndIf
    If oReq == Nil .Or. oReq:USUARIO == Nil
        cUsu := ""
    Else
        cUsu := AllTrim(cValToChar(oReq:USUARIO))
    EndIf
    If oReq == Nil .Or. oReq:SENHA == Nil
        cSen := ""
    Else
        cSen := AllTrim(cValToChar(oReq:SENHA))
    EndIf
    If oReq == Nil .Or. oReq:FILIAL == Nil
        cFilReq := ""
    Else
        cFilReq := Upper(AllTrim(cValToChar(oReq:FILIAL)))
    EndIf

    If cEmp == "" .Or. cUsu == "" .Or. cSen == ""
        Return {"ok", .F., "erro", "informe empresa, usuario e senha"}
    EndIf

    If !GEBDBSchemaValido(cUsu) .Or. !GEBDBSchemaValido(cEmp)
        Return {"ok", .F., "erro", "credenciais invalidas"}
    EndIf

    lOk := (GEBSECLOGIN(cUsu, cSen, "web") == "OK")
    If !lOk
        ConOut("GEBWEB_LOGINAPI: GEBSECLOGIN recusou " + cUsu)
    EndIf
    lSuper := GEBSECISSUPER(cUsu)

    // Empresa precisa existir antes de trocar o tenant.
    If lOk
        lOk := GEBDBSchemaExists(cEmp)
        If !lOk
            ConOut("GEBWEB_LOGINAPI: empresa " + cEmp + " nao provisionada")
        EndIf
    EndIf
    If lOk
        lOk := GEBDBSetTenant(cEmp)
        If !lOk
            ConOut("GEBWEB_LOGINAPI: GEBDBSetTenant falhou para " + cEmp)
        EndIf
    EndIf

    // Super sem filial: entra em qualquer empresa provisionada, sem gravar vinculo
    // (antes criava GE2_EMP como efeito da leitura). Vinculo, se preciso, e' explicito.
    If lOk
        If lSuper .And. cFilReq == ""
            cFilChk := ""
        EndIf
    EndIf

    If !(lSuper .And. cFilReq == "")
        // Vinculos do usuario nesta empresa (GE2_EMP e' catalogo/public).
        If lOk
            aVinc := TCSqlQuery("SELECT DISTINCT GE2_EMP_FILIAL FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = " + GEBDBQuote(cUsu) + " AND GE2_EMP_EMPRESA = " + GEBDBQuote(Lower(cEmp)) + " AND D_E_L_E_T_ = ' '")
            If Len(aVinc) == 0
                ConOut("GEBWEB_LOGINAPI: " + cUsu + " sem vinculo com empresa " + cEmp)
                lOk := .F.
            EndIf
        EndIf

        // Cadastro de filiais do tenant (GEF1). Vazio = modo legado aberto:
        // qualquer vinculo existente vale (preserva logins antigos, inclusive
        // a filial "" da matriz). Com cadastro, filial nao-vazia precisa
        // constar no cadastro (alem do vinculo).
        If lOk
            If GEBDBTableExistsHere("GEF1")
                aReg := TCSqlQuery("SELECT GEF1_COD, GEF1_NOME FROM GEF1 WHERE D_E_L_E_T_ = ' '")
                lRegTem := (Len(aReg) > 0)
            EndIf
        EndIf

        // Escolha da filial: explicita, unica ou lista para selecao.
        If lOk
            If cFilReq != ""
                For nI := 1 To Len(aVinc)
                    If Upper(AllTrim(cValToChar(aVinc[nI]:GE2_EMP_FILIAL))) == cFilReq
                        lAchou := .T.
                        Exit
                    EndIf
                Next nI
                If !lAchou
                    ConOut("GEBWEB_LOGINAPI: " + cUsu + " sem vinculo na filial " + cFilReq)
                    lOk := .F.
                EndIf
                If lOk
                    If lRegTem
                        lAchou := .F.
                        For nJ := 1 To Len(aReg)
                            If Upper(AllTrim(cValToChar(aReg[nJ]:GEF1_COD))) == cFilReq
                                lAchou := .T.
                                Exit
                            EndIf
                        Next nJ
                        If !lAchou
                            ConOut("GEBWEB_LOGINAPI: filial " + cFilReq + " fora do cadastro")
                            lOk := .F.
                        EndIf
                    EndIf
                EndIf
                If lOk
                    cFilChk := cFilReq
                EndIf
            Else
                If Len(aVinc) == 1
                    cFilChk := Upper(AllTrim(cValToChar(aVinc[1]:GE2_EMP_FILIAL)))
                Else
                    For nI := 1 To Len(aVinc)
                        cFilChk := Upper(AllTrim(cValToChar(aVinc[nI]:GE2_EMP_FILIAL)))
                        cNome := cFilChk
                        For nJ := 1 To Len(aReg)
                            If Upper(AllTrim(cValToChar(aReg[nJ]:GEF1_COD))) == cFilChk
                                cNome := cValToChar(aReg[nJ]:GEF1_NOME)
                                Exit
                            EndIf
                        Next nJ
                        AAdd(aFiliais, {cFilChk, cNome})
                    Next nI
                    Return {"ok", .T., "selecionar", .T., "filiais", aFiliais}
                EndIf
            EndIf
        EndIf
    EndIf

    If lOk
        lOk := GEBEXPCONTEXTO(cEmp, cFilChk, cUsu)
        If !lOk
            ConOut("GEBWEB_LOGINAPI: GEBEXPCONTEXTO falhou para " + cUsu + "/" + cEmp)
        EndIf
    EndIf

    If !lOk
        Return {"ok", .F., "erro", "credenciais invalidas"}
    EndIf

    cTok := GEBSECTOKEN(cUsu, cEmp, cFilChk, "web")
    If cTok == ""
        Return {"ok", .F., "erro", "falha ao gerar sessao"}
    EndIf

Return {"ok", .T., "usuario", cUsu, "empresa", cEmp, "filial", cFilChk, "token", cTok}

// ===== WRAPPERS PDV (autenticacao via GEBWAPIAUTH) =====
Static Function GEBPDV_AUTH(oReq)
    Local cTok  := GEBWAPIFIELD(oReq, "TOKEN")
    Local cEmp  := GEBWAPIFIELD(oReq, "EMPRESA")
    Local aAuth := GEBWAPIAUTH(cTok, cEmp)
    If !aAuth[1]
        Return ""
    EndIf
Return aAuth[2]

/*/{Protheus.doc} U_GEBPDVCAIXALST
    Wrapper de autenticacao para GEBPDVCAIXALST.
/*/
User Function U_GEBPDVCAIXALST(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "caixas", GEBPDVCAIXALST(cUsuario))

/*/{Protheus.doc} U_GEBPDVCAIXAABR
    Wrapper de autenticacao para GEBPDVCAIXAABR.
/*/
User Function U_GEBPDVCAIXAABR(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVCAIXAABR(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVCAIXAFECH
    Wrapper de autenticacao para GEBPDVCAIXAFECH.
/*/
User Function U_GEBPDVCAIXAFECH(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVCAIXAFECH(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVCAIXARESUMO
    Wrapper de autenticacao para GEBPDVCAIXARESUMO.
/*/
User Function U_GEBPDVCAIXARESUMO(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local cSessao := GEBWAPIFIELD(oReq, "SESSAO")
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "resumo_caixa", GEBPDVCAIXARESUMO(cUsuario, cSessao))

/*/{Protheus.doc} U_GEBPDVSANGRIA
    Wrapper de autenticacao para GEBPDVSANGRIA.
/*/
User Function U_GEBPDVSANGRIA(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVSANGRIA(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], {})

/*/{Protheus.doc} U_GEBPDVCUPOMNOV
    Wrapper de autenticacao para GEBPDVCUPOMNOV.
/*/
User Function U_GEBPDVCUPOMNOV(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVCUPOMNOV(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVCUPOMGET
    Wrapper de autenticacao para GEBPDVCUPOMGET.
/*/
User Function U_GEBPDVCUPOMGET(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local cCupom := GEBWAPIFIELD(oReq, "ID")
    Local aR := GEBPDVCUPOMGET(cUsuario, cCupom)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVCUPCANC
    Wrapper de autenticacao para GEBPDVCUPCANC.
/*/
User Function U_GEBPDVCUPCANC(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVCUPCANC(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVPRODUTBUSC
    Wrapper de autenticacao para GEBPDVPRODUTBUSC.
/*/
User Function U_GEBPDVPRODUTBUSC(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local cCodigo := GEBWAPIFIELD(oReq, "CODIGO")
    Local aR := GEBPDVPRODUTBUSC(cUsuario, cCodigo)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVRELGER
    Wrapper de autenticacao para GEBPDVRELGER.
/*/
User Function U_GEBPDVRELGER(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVRELGER(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVRELGERCSV
    Wrapper de autenticacao para GEBPDVRELGERCSV.
/*/
User Function U_GEBPDVRELGERCSV(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "relatorio_gerencial_csv", GEBPDVRELGERCSV(cUsuario, oReq))

/*/{Protheus.doc} U_GEBPDVRELCOM
    Wrapper de autenticacao para GEBPDVRELCOM.
/*/
User Function U_GEBPDVRELCOM(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local aR := GEBPDVRELCOM(cUsuario, oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(aR[1], aR[2], aR)

/*/{Protheus.doc} U_GEBPDVRELCOMCSV
    Wrapper de autenticacao para GEBPDVRELCOMCSV.
/*/
User Function U_GEBPDVRELCOMCSV(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "comissao_csv", GEBPDVRELCOMCSV(cUsuario, oReq))

/*/{Protheus.doc} U_GEBPDVPERIFLIST
    Wrapper de autenticacao para GEBPDVPERIFLIST.
/*/
User Function U_GEBPDVPERIFLIST(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local cTipo := GEBWAPIFIELD(oReq, "TIPO")
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "perifericos", GEBPDVPERIFLIST(cUsuario, cTipo))

/*/{Protheus.doc} U_GEBPDVPERIFREG
    Wrapper de autenticacao para GEBPDVPERIFREG.
/*/
User Function U_GEBPDVPERIFREG(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "periferico_registrado", GEBPDVPERIFREG(cUsuario, oReq))

/*/{Protheus.doc} U_GEBPDVPERIFDEL
    Wrapper de autenticacao para GEBPDVPERIFDEL.
/*/
User Function U_GEBPDVPERIFDEL(oReq)
    Local cUsuario := GEBPDV_AUTH(oReq)
    Local nId := Val(GEBWAPIFIELD(oReq, "ID"))
    If cUsuario == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBRESTJSONRESP(.T., "periferico_removido", GEBPDVPERIFDEL(cUsuario, nId))
