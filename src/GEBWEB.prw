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
    Local cHost := "" as Character
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
    // Alias do login para o PDV web: /api/login e' bloqueado na borda
    // (cloudflared), mas /api/pdv/login passa pela regra /api/* -> 8090.
    oSrv:AddRoute("POST", "/api/pdv/login", "U_GEBWEB_LOGINAPI")
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
    oSrv:AddRoute("GET", "/api/pdv/caixa/lista", "U_GEBWAPI_PDVCAIXALST")
    oSrv:AddRoute("GET", "/api/pdv/caixa/sessoes", "U_GEBWAPI_PDVCAIXASS")
    oSrv:AddRoute("POST", "/api/pdv/caixa/abrir", "U_GEBWAPI_PDVCAIXAABR")
    oSrv:AddRoute("POST", "/api/pdv/caixa/fechar", "U_GEBWAPI_PDVCAIXAFECH")
    oSrv:AddRoute("GET", "/api/pdv/caixa/resumo/{sessao}", "U_GEBWAPI_PDVCAIXARESUMO")
    oSrv:AddRoute("POST", "/api/pdv/caixa/sangria", "U_GEBWAPI_PDVSANGRIA")
    oSrv:AddRoute("POST", "/api/pdv/cupom/novo", "U_GEBWAPI_PDVCUPOMNOV")
    oSrv:AddRoute("GET", "/api/pdv/cupom/{id}", "U_GEBWAPI_PDVCUPOMGET")
    oSrv:AddRoute("POST", "/api/pdv/cupom/{id}/cancelar", "U_GEBWAPI_PDVCUPCANC")
    oSrv:AddRoute("GET", "/api/pdv/produto/busca", "U_GEBWAPI_PDVPRODUTBUSC")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/gerencial", "U_GEBWAPI_PDVRELGER")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/gerencial/csv", "U_GEBWAPI_PDVRELGERCSV")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/comissao", "U_GEBWAPI_PDVRELCOM")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/comissao/csv", "U_GEBWAPI_PDVRELCOMCSV")
    oSrv:AddRoute("GET", "/api/pdv/perifericos", "U_GEBWAPI_PDVPERIFLIST")
    oSrv:AddRoute("POST", "/api/pdv/perifericos", "U_GEBWAPI_PDVPERIFREG")
    oSrv:AddRoute("DELETE", "/api/pdv/perifericos/{id}", "U_GEBWAPI_PDVPERIFDEL")
    // Crypto (pagamento em moeda digital)
    oSrv:AddRoute("GET", "/api/pdv/crypto/cotacao", "U_GEBWAPI_PDVCRYCOT")
    oSrv:AddRoute("GET", "/api/pdv/crypto/wallets", "U_GEBWAPI_PDVCRYWALLST")
    oSrv:AddRoute("GET", "/api/pdv/crypto/previa", "U_GEBWAPI_PDVCRYPREV")
    oSrv:AddRoute("POST", "/api/pdv/crypto/wallet", "U_GEBWAPI_PDVCRYWAL")
    // Orcamentos, devolucao, consultas, cadastros, relatorios e TEF/NFC-e
    // (funcionalidades que a Frente de loja TUI tinha e o PDV web herda)
    oSrv:AddRoute("POST", "/api/pdv/orcamento", "U_GEBWAPI_PDVORCNOV")
    oSrv:AddRoute("GET", "/api/pdv/orcamentos", "U_GEBWAPI_PDVORCLST")
    oSrv:AddRoute("POST", "/api/pdv/orcamento/finalizar", "U_GEBWAPI_PDVORCFIN")
    oSrv:AddRoute("POST", "/api/pdv/orcamento/cancelar", "U_GEBWAPI_PDVORCCAN")
    oSrv:AddRoute("POST", "/api/pdv/devolucao", "U_GEBWAPI_PDVDEV")
    oSrv:AddRoute("GET", "/api/pdv/consulta", "U_GEBWAPI_PDVCONS")
    oSrv:AddRoute("GET", "/api/pdv/vale/{numero}", "U_GEBWAPI_PDVVALE")
    oSrv:AddRoute("GET", "/api/pdv/fiado/saldo", "U_GEBWAPI_PDVFIAS")
    oSrv:AddRoute("POST", "/api/pdv/cadastro/caixa", "U_GEBWAPI_PDVCADCX")
    oSrv:AddRoute("POST", "/api/pdv/cadastro/barras", "U_GEBWAPI_PDVCADBAR")
    oSrv:AddRoute("POST", "/api/pdv/cadastro/promocao", "U_GEBWAPI_PDVCADPROMO")
    oSrv:AddRoute("POST", "/api/pdv/cadastro/vendedor", "U_GEBWAPI_PDVCADVEND")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/vendas", "U_GEBWAPI_PDVRELVEN")
    oSrv:AddRoute("GET", "/api/pdv/relatorio/tef", "U_GEBWAPI_PDVRELTEF")
    oSrv:AddRoute("POST", "/api/pdv/tef/config", "U_GEBWAPI_PDVTEFCFG")
    oSrv:AddRoute("POST", "/api/pdv/tef/desfazer", "U_GEBWAPI_PDVTEFRES")
    oSrv:AddRoute("POST", "/api/pdv/nfce/transmitir", "U_GEBWAPI_PDVNFETR")
    // Interface PDV
    oSrv:AddRoute("GET", "/pdv", "U_GEBPDVHTML")
    oSrv:AddRoute("GET", "/pdv/ws", "U_GEBPDVWS")
    // Bind configuravel: o all-in-one (Windows) usa 127.0.0.1 para nao expor a
    // API na rede; o servidor central fica em 0.0.0.0 (padrao).
    cHost := AllTrim(GetEnv("GEBAN_WEB_HOST"))
    If Empty(cHost)
        cHost := "0.0.0.0"
    EndIf
    ConOut("GEBWEB: servindo em http://" + cHost + ":" + cValToChar(nPorta))
    oSrv:Serve(cHost + ":" + cValToChar(nPorta))
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

    cEmp := GEBWAPIFIELD(oReq, "EMPRESA")
    cUsu := GEBWAPIFIELD(oReq, "USUARIO")
    cSen := GEBWAPIFIELD(oReq, "SENHA")
    cFilReq := Upper(GEBWAPIFIELD(oReq, "FILIAL"))

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

// ===== ROTAS PDV: autentica ANTES de qualquer regra de negocio =====
Static Function GEBPDV_AUTH(oReq)
    Local aAuth := GEBWAPIAUTH(GEBWAPIFIELD(oReq, "TOKEN"), GEBWAPIFIELD(oReq, "EMPRESA"))

    If !aAuth[1]
        Return ""
    EndIf
Return aAuth[2]

User Function GEBWAPI_PDVCAIXALST(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCAIXALST(cUsu)

User Function GEBWAPI_PDVCAIXASS(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCAIXASS(cUsu)

User Function GEBWAPI_PDVCAIXAABR(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCAIXAABR(cUsu, oReq)

User Function GEBWAPI_PDVCAIXAFECH(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCAIXAFECH(cUsu, oReq)

User Function GEBWAPI_PDVCAIXARESUMO(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCAIXARESUMO(cUsu, GEBWAPIFIELD(oReq, "SESSAO"))

User Function GEBWAPI_PDVSANGRIA(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVSANGRIA(cUsu, oReq)

User Function GEBWAPI_PDVCUPOMNOV(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCUPOMNOV(cUsu, oReq)

User Function GEBWAPI_PDVCUPOMGET(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCUPOMGET(cUsu, GEBWAPIFIELD(oReq, "ID"))

User Function GEBWAPI_PDVCUPCANC(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCUPCANC(cUsu, oReq)

User Function GEBWAPI_PDVPRODUTBUSC(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVPRODUTBUSC(cUsu, GEBWAPIFIELD(oReq, "CODIGO"))

User Function GEBWAPI_PDVRELGER(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVRELGER(cUsu, oReq)

User Function GEBWAPI_PDVRELGERCSV(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVRELGERCSV(cUsu, oReq)

User Function GEBWAPI_PDVRELCOM(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVRELCOM(cUsu, oReq)

User Function GEBWAPI_PDVRELCOMCSV(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVRELCOMCSV(cUsu, oReq)

User Function GEBWAPI_PDVPERIFLIST(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVPERIFLIST(cUsu, GEBWAPIFIELD(oReq, "TIPO"))

User Function GEBWAPI_PDVPERIFREG(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVPERIFREG(cUsu, oReq)

User Function GEBWAPI_PDVPERIFDEL(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVPERIFDEL(cUsu, Val(GEBWAPIFIELD(oReq, "ID")))

User Function GEBWAPI_PDVCRYCOT(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCRYCOT(cUsu)

User Function GEBWAPI_PDVCRYWALLST(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCRYWALLST(cUsu)

User Function GEBWAPI_PDVCRYPREV(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCRYPREV(cUsu, GEBWAPIFIELD(oReq, "MOEDA"), BOVAL(GEBWAPIFIELD(oReq, "VALOR")))

User Function GEBWAPI_PDVCRYWAL(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCRYWAL(cUsu, oReq)

User Function GEBWAPI_PDVORCNOV(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVORCNOV(cUsu, oReq)

User Function GEBWAPI_PDVORCLST(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVORCLST(cUsu, GEBWAPIFIELD(oReq, "STATUS"))

User Function GEBWAPI_PDVORCFIN(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVORCFIN(cUsu, oReq)

User Function GEBWAPI_PDVORCCAN(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVORCCAN(cUsu, oReq)

User Function GEBWAPI_PDVDEV(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVDEVOLUC(cUsu, oReq)

User Function GEBWAPI_PDVCONS(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCONSULTA(cUsu, GEBWAPIFIELD(oReq, "CODIGO"))

User Function GEBWAPI_PDVVALE(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVVALESALDO(cUsu, GEBWAPIFIELD(oReq, "NUMERO"))

User Function GEBWAPI_PDVFIAS(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVFIASALDO(cUsu, GEBWAPIFIELD(oReq, "CLIENTE"))

User Function GEBWAPI_PDVCADCX(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCADCAIXA(cUsu, oReq)

User Function GEBWAPI_PDVCADBAR(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCADBAR(cUsu, oReq)

User Function GEBWAPI_PDVCADPROMO(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCADPROMO(cUsu, oReq)

User Function GEBWAPI_PDVCADVEND(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVCADVEND(cUsu, oReq)

User Function GEBWAPI_PDVRELVEN(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVRELVENDAS(cUsu, GEBWAPIFIELD(oReq, "DATA"), GEBWAPIFIELD(oReq, "CAIXA"))

User Function GEBWAPI_PDVRELTEF(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVRELTEF(cUsu, GEBWAPIFIELD(oReq, "DATA"))

User Function GEBWAPI_PDVTEFCFG(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVTEFCFG(cUsu, oReq)

User Function GEBWAPI_PDVTEFRES(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVTEFRES(cUsu)

User Function GEBWAPI_PDVNFETR(oReq)
    Local cUsu := GEBPDV_AUTH(oReq) as Character

    If cUsu == ""
        Return GEBWAPIDENY()
    EndIf
Return GEBPDVNFETRANSMITE(cUsu)
