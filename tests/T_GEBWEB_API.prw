#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBWEB_API.prw"
#include "../src/GEBWEB.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBFAT.prw"
#include "../src/GEBTEF.prw"
#include "../src/GEBLOJ.prw"
#include "../src/GEBDFE_XML.prw"
#include "../src/GEBDFE_WS.prw"
#include "../src/GEBDFE_MUN.prw"
#include "../src/GEBDFE_IE.prw"
#include "../src/GEBDFE_CAD.prw"
#include "../src/GEBDFE.prw"
#include "../src/GEBDFE_QR.prw"
#include "../src/GEBDFE_DANFE.prw"
#include "../src/GEBLOJ_CAD.prw"
#include "../src/GEBLOJ_OPE.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"

/*/{Protheus.doc} T_GEBWEB_API
    Prova que a ponte HTTP (src/GEBWEB_API.prw) expoe de verdade o
    dispatcher U_GEBREST: cada rota /api/* valida token GE2_TOK,
    seleciona o tenant e devolve o status HTTP real (sem double
    encoding). Mocks de oReq via JsonObject():New() com chaves em
    maiusculas (mesmo formato que o WSRestServer entrega).
    Setup: empresa descartavel zzwebapi (schema emp_zzwebapi),
    usuario ADMIN T_WEBAPI via GEBSECCRIAUSU, token via GEBSECTOKEN.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 25/09/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBWEB_API()
    Local lOk    := .T.
    Local cCod   := "zzwebapi"
    Local cUsu   := "T_WEBAPI"
    Local cSenha := "Senha#Forte1"
    Local cFil   := ""
    Local cTok   := ""
    Local aGe2   := {}
    Local oNil   := Nil
    Local oMock  := Nil
    Local oBad   := Nil
    Local oItem  := Nil
    Local oL     := Nil
    Local lTemFil := .F.
    Local nI     := 0
    Local aDbg   := {}
    Local aRet   := {}
    Local cBody  := ""

    ConOut("=== T_GEBWEB_API ===")

    If !GEBDBConecta()
        ConOut("T_GEBWEB_API: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")

    // Pre-cleanup (rerun limpo).
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPFIL'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPLEG'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WCASCA'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPIDL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPLEG'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPFIL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WCASCA'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPIDL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPLEG'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPFIL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WCASCA'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPIDL'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")

    If !GEBDBProvisionaCatalogo()
        ConOut("FAIL: GEBDBProvisionaCatalogo")
        Return .F.
    EndIf
    If !GEBDBProvisionaEmpresa(cCod, "Empresa Teste WebAPI")
        ConOut("FAIL: GEBDBProvisionaEmpresa")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    If !GEBSECCRIAUSU(cUsu, cSenha, {cCod}, "Usuario WebAPI", "ADMIN")
        ConOut("FAIL: GEBSECCRIAUSU")
        Return .F.
    EndIf
    ConOut("  OK setup usuario")

    // Tabelas de tenant (produtos/notas/financeiro).
    TCSqlExec("SET search_path TO emp_" + cCod)
    If !GEBFMIG()
        lOk := .F.
        ConOut("FAIL: GEBFMIG")
    EndIf
    If !GEBFNMIG()
        lOk := .F.
        ConOut("FAIL: GEBFNMIG")
    EndIf
    If !GEBDMIG()
        lOk := .F.
        ConOut("FAIL: GEBDMIG")
    EndIf
    If !GEBVMIG()
        lOk := .F.
        ConOut("FAIL: GEBVMIG")
    EndIf
    If !GEBCMIG()
        lOk := .F.
        ConOut("FAIL: GEBCMIG")
    EndIf
    If !GEBCMMIG()
        lOk := .F.
        ConOut("FAIL: GEBCMMIG")
    EndIf
    If !GEFFILMIG()
        lOk := .F.
        ConOut("FAIL: GEFFILMIG")
    EndIf
    If !GEUNIMIG()
        lOk := .F.
        ConOut("FAIL: GEUNIMIG")
    EndIf
    TCSqlExec("INSERT INTO GD1 (D_E_L_E_T_, GD1_FILIAL, GD1_GUIA, GD1_COMP, GD1_VALOR, GD1_JUROS, GD1_MULTA, GD1_TOTAL, GD1_STATUS) VALUES (' ', '" + FWxFilial("GE1") + "', 'WAPIG01', '202609', 100, 0, 0, 100, 'ABERTA')")
    TCSqlExec("INSERT INTO GV1 (D_E_L_E_T_, GV1_FILIAL, GV1_PROD, GV1_SALDO, GV1_MIN) VALUES (' ', '" + FWxFilial("GE1") + "', 'WAPI01', 10, 2)")

    // Filial real do usuario + token real.
    TCSqlExec("SET search_path TO public")
    aGe2 := TCSqlQuery("SELECT GE2_FILIAL FROM GE2 WHERE GE2_COD = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
    If Len(aGe2) == 0
        ConOut("FAIL: usuario sem linha GE2")
        Return .F.
    EndIf
    cFil := cValToChar(aGe2[1]:GE2_FILIAL)
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    // Hierarquia: a filial ZZ0101 pertence a unidade 01, que precisa estar cadastrada.
    TCSqlExec("DELETE FROM GEU1 WHERE GEU1_COD = '01'")
    TCSqlExec("INSERT INTO GEU1 (D_E_L_E_T_, GEU1_FILIAL, GEU1_COD, GEU1_NOME) VALUES (' ', '      ', '01', 'Unidade Teste')")
    cTok := GEBSECTOKEN(cUsu, cCod, cFil, "test")
    If cTok == ""
        ConOut("FAIL: GEBSECTOKEN vazio")
        Return .F.
    EndIf
    ConOut("  OK token")

    // 1. Health publico, sem auth.
    aRet := GEBWAPI_HEALTH(oNil)
    If !(Len(aRet) >= 4 .And. aRet[1] == "__RAW_HTTP__" .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: HEALTH sem 200 RAW")
    Else
        ConOut("  OK health 200")
    EndIf

    // 2. Sem token = 401.
    aRet := GEBWAPI_USRLST(oNil)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: USRLST sem token nao deu 401")
    Else
        ConOut("  OK deny sem token 401")
    EndIf
    aRet := GEBWAPI_PRDLST(oNil)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: PRDLST sem token nao deu 401")
    EndIf

    // Mock autenticado.
    oMock := JsonObject():New()
    oMock["TOKEN"] := cTok
    oMock["EMPRESA"] := cCod

    // 3. Lista usuarios com token real.
    aRet := GEBWAPI_USRLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At(cUsu, cBody) > 0)
        lOk := .F.
        ConOut("FAIL: USRLST com token")
    Else
        ConOut("  OK usuarios 200")
    EndIf

    // 4. Detalhe: existente 200, inexistente 404.
    oMock["COD"] := cUsu
    aRet := GEBWAPI_USRGET(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: USRGET existente")
    Else
        ConOut("  OK usrget 200")
    EndIf
    oMock["COD"] := "ZZINEXISTE"
    aRet := GEBWAPI_USRGET(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: USRGET inexistente nao deu 404")
    Else
        ConOut("  OK usrget 404")
    EndIf

    // 5. Cria produto via HTTP, lista, duplicata 409.
    oMock["CODIGO"] := "WAPI01"
    oMock["NCM"] := "84713012"
    oMock["DESCRICAO"] := "Teclado WebAPI"
    aRet := GEBWAPI_PRDLSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: PRDLSC nao deu 201")
    Else
        ConOut("  OK produto 201")
    EndIf
    aRet := GEBWAPI_PRDLSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 409)
        lOk := .F.
        ConOut("FAIL: PRDLSC duplicado nao deu 409")
    EndIf
    aRet := GEBWAPI_PRDLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("WAPI01", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: PRDLST sem WAPI01")
    Else
        ConOut("  OK produtos 200")
    EndIf

    // 6. Emite nota via HTTP; chave vazia 400.
    oMock["CHAVE"] := "WAPI35260901001001001001001001001001"
    oMock["PRODUTO"] := "WAPI01"
    oMock["QUANTIDADE"] := "2"
    oMock["PRECO"] := "150.50"
    aRet := GEBWAPI_NOTPOST(oMock)
    If !(Len(aRet) >= 4 .And. (aRet[4] == 201 .Or. aRet[4] == 202))
        lOk := .F.
        ConOut("FAIL: NOTPOST nao deu 201/202")
    Else
        ConOut("  OK nota emitida")
    EndIf
    oMock["CHAVE"] := ""
    aRet := GEBWAPI_NOTPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: NOTPOST chave vazia nao deu 400")
    EndIf
    aRet := GEBWAPI_NOTLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("WAPI35260901", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: NOTLST sem chave emitida")
    Else
        ConOut("  OK notas 200")
    EndIf

    // 7. Token errado 401, empresa errada 401.
    oBad := JsonObject():New()
    oBad["TOKEN"] := "token_invalido_zz"
    oBad["EMPRESA"] := cCod
    aRet := GEBWAPI_USRLST(oBad)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: token invalido nao deu 401")
    Else
        ConOut("  OK token invalido 401")
    EndIf
    oBad["TOKEN"] := cTok
    oBad["EMPRESA"] := "zznaoexiste"
    aRet := GEBWAPI_USRLST(oBad)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: empresa invalida nao deu 401")
    EndIf

    // 8. Leituras agregadas via HTTP.
    aRet := GEBWAPI_FLXLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: FLXLST")
    Else
        ConOut("  OK fluxo 200")
    EndIf
    aRet := GEBWAPI_CONLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: CONLST")
    Else
        ConOut("  OK contas 200")
    EndIf
    aRet := GEBWAPI_RELGER(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: RELGER")
    Else
        ConOut("  OK gerencial 200")
    EndIf
    aRet := GEBWAPI_MONUSU(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: MONUSU")
    Else
        ConOut("  OK monitor 200")
    EndIf

    // 8b. Novos modulos via HTTP (derrama/estoque/contabil/compras).
    aRet := GEBWAPI_DERLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("WAPIG01", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: DERLST sem WAPIG01")
    Else
        ConOut("  OK derrama 200")
    EndIf
    aRet := GEBWAPI_ESTLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("WAPI01", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: ESTLST sem WAPI01")
    Else
        ConOut("  OK estoque 200")
    EndIf
    aRet := GEBWAPI_VENLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: VENLST")
    Else
        ConOut("  OK vendas 200")
    EndIf
    aRet := GEBWAPI_CTBLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: CTBLST")
    Else
        ConOut("  OK lancamentos 200")
    EndIf
    aRet := GEBWAPI_CTCLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("1.01.001", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: CTCLST sem plano de contas")
    Else
        ConOut("  OK plano contas 200")
    EndIf
    aRet := GEBWAPI_COMLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: COMLST")
    Else
        ConOut("  OK pedidos 200")
    EndIf
    aRet := GEBWAPI_FORLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: FORLST")
    Else
        ConOut("  OK fornecedores 200")
    EndIf
    aRet := GEBWAPI_DERLST(oNil)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: DERLST sem token nao deu 401")
    EndIf

    // 8c. Filiais EEUUFF via HTTP (cadastro no Nucleo).
    oMock["CODIGO"] := "ZZ0101"
    oMock["NOME"] := "Filial Teste 01"
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: FILSC nao deu 201")
    Else
        ConOut("  OK filial 201")
    EndIf
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 409)
        lOk := .F.
        ConOut("FAIL: FILSC duplicada nao deu 409")
    EndIf
    // Hierarquia: filial ZZ0299 pertence a unidade 02, que nao esta cadastrada -> 400.
    oMock["CODIGO"] := "ZZ0299"
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: FILSC sem unidade cadastrada nao deu 400")
    Else
        ConOut("  OK filial sem unidade cadastrada recusada")
    EndIf
    oMock["CODIGO"] := "XX"
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: FILSC curta nao deu 400")
    EndIf
    oMock["CODIGO"] := "AA0101"
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: FILSC EE errado nao deu 400")
    EndIf
    aRet := GEBWAPI_FILLST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("ZZ0101", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: FILLST sem ZZ0101")
    Else
        ConOut("  OK filiais 200")
    EndIf

    // 8c2. Unidades UU + cascata filial (empresa->unidade->filial).
    oMock["CODIGO"] := "01"
    oMock["NOME"] := "Unidade Teste 01"
    TCSqlExec("DELETE FROM GEU1 WHERE GEU1_COD = '01'")
    aRet := GEBWAPI_UNILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: UNILSC nao deu 201")
    Else
        ConOut("  OK unidade 201")
    EndIf
    aRet := GEBWAPI_UNILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 409)
        lOk := .F.
        ConOut("FAIL: UNILSC duplicada nao deu 409")
    EndIf
    oMock["CODIGO"] := "X"
    aRet := GEBWAPI_UNILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: UNILSC curta nao deu 400")
    EndIf
    aRet := GEBWAPI_UNILST(oMock)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At("01", cBody) > 0)
        lOk := .F.
        ConOut("FAIL: UNILST sem 01")
    Else
        ConOut("  OK unidades 200")
    EndIf
    oMock["CODIGO"] := "ZZ0201"
    oMock["NOME"] := "Filial UU 02"
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: FILSC sem unidade nao deu 400")
    EndIf
    oMock["CODIGO"] := "02"
    oMock["NOME"] := "Unidade Teste 02"
    aRet := GEBWAPI_UNILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: UNILSC 02")
    EndIf
    oMock["CODIGO"] := "ZZ0201"
    oMock["NOME"] := "Filial UU 02"
    aRet := GEBWAPI_FILSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: FILSC com unidade nao deu 201")
    Else
        ConOut("  OK filial com unidade 201")
    EndIf
    oMock["CODIGO"] := "T_WCASCA"
    oMock["NOME"] := "Cascata"
    oMock["PERFIL"] := "OPERADOR"
    oMock["SENHA"] := "Senha#Forte7"
    oMock["EMPRESAS"] := cCod
    oMock["FILIAL"] := "ZZ0909"
    aRet := GEBWAPI_USRPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: USRPOST filial fantasma nao deu 400")
    EndIf
    oMock["USUARIO"] := cUsu
    oMock["EMPRESA"] := cCod
    oMock["FILIAL"] := "ZZ0909"
    aRet := GEBWAPI_VINCSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: VINCSC filial fantasma nao deu 400")
    EndIf
    // Compras: pedido/entrada de compra so' existem na trilha GEBCPX
    // (/api/bo/compras/*); a trilha antiga /api/compras/{pedidos,itens,entradas}
    // foi removida por pular a alcada GCQ2.
    oMock["MODULO"] := "compras"
    oMock["ACAO"] := "pedido"
    oMock["NUMERO"] := "ZZPEDX"
    oMock["FORNECEDOR"] := "ZZINEXISTE"
    oItem := JsonObject():New()
    oItem["PRODUTO"] := "WAPI01"
    oItem["QUANTIDADE"] := 1
    oItem["PRECO"] := 10
    oMock["ITENS"] := {oItem}
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: BO compras/pedido sem fornecedor nao deu 400")
    EndIf
    oMock["ACAO"] := "entrada"
    oMock["NOTA"] := "WNFX"
    oMock["PEDIDO"] := "ZZINEXISTE"
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: BO compras/entrada sem pedido nao deu 400")
    EndIf
    oMock["CHAVE"] := "WAPIX"
    oMock["PRODUTO"] := "ZZINEXISTE"
    oMock["QUANTIDADE"] := "1"
    oMock["PRECO"] := "10"
    aRet := GEBWAPI_NOTPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: NOTPOST sem produto nao deu 404")
    Else
        ConOut("  OK cascata 404")
    EndIf
    oMock["VENDA"] := "WVX"
    oMock["PRODUTO"] := "ZZINEXISTE"
    oMock["QUANTIDADE"] := "1"
    oMock["PRECO"] := "10"
    aRet := GEBWAPI_ESTVEN(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: ESTVEN sem produto nao deu 404")
    EndIf
    oMock["COMPETENCIA"] := "209901"
    aRet := GEBWAPI_DERGER(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 422)
        lOk := .F.
        ConOut("FAIL: DERGER sem apuracao nao deu 422")
    Else
        ConOut("  OK apuracao exigida 422")
    EndIf
    oMock["TIPO"] := "PAGAR"
    oMock["DOCUMENTO"] := "ZZINEXISTE"
    oMock["VALOR"] := "10"
    aRet := GEBWAPI_FINBAI(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: FINBAI sem titulo nao deu 404")
    EndIf
    oMock["DEBITO"] := "ZZINEXISTE"
    oMock["CREDITO"] := "3.01.001"
    oMock["VALOR"] := "10"
    aRet := GEBWAPI_CTBDIR(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: CTBDIR sem conta nao deu 404")
    EndIf

    // 8d. Usuario criado direto na filial + vinculo avulso.
    oMock["CODIGO"] := "T_WAPFIL"
    oMock["NOME"] := "Usuario Filial API"
    oMock["PERFIL"] := "OPERADOR"
    oMock["SENHA"] := "Senha#Forte3"
    oMock["EMPRESAS"] := cCod
    oMock["FILIAL"] := "ZZ0101"
    aRet := GEBWAPI_USRPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: USRPOST com filial nao deu 201")
    Else
        ConOut("  OK usrpost filial 201")
    EndIf
    TCSqlExec("SET search_path TO public")
    aGe2 := TCSqlQuery("SELECT GE2_EMP_FILIAL FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPFIL' AND GE2_EMP_EMPRESA = '" + cCod + "' AND D_E_L_E_T_ = ' '")
    If !(Len(aGe2) > 0 .And. Upper(AllTrim(cValToChar(aGe2[1]:GE2_EMP_FILIAL))) == "ZZ0101")
        lOk := .F.
        ConOut("FAIL: vinculo sem filial ZZ0101")
    Else
        ConOut("  OK vinculo filial")
    EndIf
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    oMock["USUARIO"] := cUsu
    oMock["EMPRESA"] := cCod
    oMock["FILIAL"] := "ZZ0101"
    aRet := GEBWAPI_VINCSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: VINCSC nao deu 201")
    Else
        ConOut("  OK vinculo 201")
    EndIf
    aRet := GEBWAPI_VINCSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 409)
        lOk := .F.
        ConOut("FAIL: VINCSC duplicado nao deu 409")
    EndIf
    oMock["USUARIO"] := "ZZINEXISTE"
    aRet := GEBWAPI_VINCSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: VINCSC usuario ruim nao deu 404")
    EndIf
    oMock["USUARIO"] := cUsu
    oMock["FILIAL"] := "xx-yy"
    aRet := GEBWAPI_VINCSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: VINCSC filial ruim nao deu 400")
    EndIf

    // 8e-pre. ADMIN com 2 vinculos (prova: bypass e por username, nao por perfil).
    oMock["CODIGO"] := "T_WAPSEL"
    oMock["NOME"] := "Admin Selecao"
    oMock["PERFIL"] := "ADMIN"
    oMock["SENHA"] := "Senha#Forte4"
    oMock["EMPRESAS"] := cCod
    oMock["FILIAL"] := ""
    aRet := GEBWAPI_USRPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: USRPOST operador")
    EndIf
    oMock["USUARIO"] := "T_WAPSEL"
    oMock["EMPRESA"] := cCod
    oMock["FILIAL"] := "ZZ0101"
    aRet := GEBWAPI_VINCSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: VINCSC operador")
    EndIf

    // 8e. Login em 2 etapas: 2 vinculos => pede selecao; com filial => token.
    oL := JsonObject():New()
    oL["TOKEN"] := cTok
    oL["EMPRESA"] := cCod
    oL["USUARIO"] := "T_WAPSEL"
    oL["EMPRESA"] := cCod
    oL["SENHA"] := "Senha#Forte4"
    TCSqlExec("SET search_path TO public")
    aDbg := TCSqlQuery("SELECT DISTINCT GE2_EMP_FILIAL FROM public.GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "' AND GE2_EMP_EMPRESA = '" + Lower(cCod) + "' AND D_E_L_E_T_ = ' '")
    ConOut("DBG distinct n=" + cValToChar(Len(aDbg)))
    aDbg := TCSqlQuery("SELECT GE2_EMP_FILIAL, GE2_EMP_EMPRESA FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
    ConOut("DBG vinc preselecao n=" + cValToChar(Len(aDbg)))
    For nI := 1 To Len(aDbg)
        ConOut("DBG vinc emp=" + cValToChar(aDbg[nI]:GE2_EMP_EMPRESA) + " fil=[" + cValToChar(aDbg[nI]:GE2_EMP_FILIAL) + "]")
    Next nI
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    oL["FILIAL"] := ""
    aRet := GEBWEB_LOGINAPI(oL)
    ConOut("DBG resp len=" + cValToChar(Len(aRet)))
    cBody := ""
    If Len(aRet) >= 6
        cBody := cValToChar(aRet[6])
    EndIf
    lTemFil := .F.
    If Len(aRet) >= 6 .And. ValType(aRet[6]) == "A"
        For nI := 1 To Len(aRet[6])
            If ValType(aRet[6][nI]) == "A" .And. Len(aRet[6][nI]) >= 1
                If cValToChar(aRet[6][nI][1]) == "ZZ0101"
                    lTemFil := .T.
                EndIf
            EndIf
        Next nI
    EndIf
    If !(Len(aRet) == 6 .And. aRet[2] == .T. .And. aRet[4] == .T. .And. lTemFil)
        lOk := .F.
        ConOut("FAIL: login sem filial nao pediu selecao")
    Else
        ConOut("  OK login pede filial")
    EndIf
    oL["FILIAL"] := "ZZ0101"
    aRet := GEBWEB_LOGINAPI(oL)
    If !(Len(aRet) == 10 .And. aRet[2] == .T. .And. cValToChar(aRet[8]) == "ZZ0101" .And. Len(cValToChar(aRet[10])) > 10)
        lOk := .F.
        ConOut("FAIL: login com filial nao deu token")
    Else
        ConOut("  OK login filial token")
    EndIf
    oL["FILIAL"] := "ZZ0909"
    aRet := GEBWEB_LOGINAPI(oL)
    If !(Len(aRet) == 4 .And. aRet[2] == .F.)
        lOk := .F.
        ConOut("FAIL: login filial sem vinculo passou")
    Else
        ConOut("  OK login filial invalida")
    EndIf

    // 8f. Perfil ADMIN nao tem bypass: com 2 vinculos pede selecao
    // como qualquer usuario (entrada direta e so do super, por username).
    oMock["USUARIO"] := cUsu
    oMock["EMPRESA"] := cCod
    oMock["SENHA"] := cSenha
    oMock["FILIAL"] := ""
    aRet := GEBWEB_LOGINAPI(oMock)
    If !(Len(aRet) == 6 .And. aRet[2] == .T. .And. aRet[4] == .T.)
        lOk := .F.
        ConOut("FAIL: ADMIN com vinculos nao pediu selecao")
    Else
        ConOut("  OK admin pede selecao (sem bypass)")
    EndIf

    // 8f2. Perfil ADMIN sem vinculo: login recusado e nenhum vinculo
    // e criado (sem bypass para nao-super).
    oMock["CODIGO"] := "T_WAPADM"
    oMock["NOME"] := "Admin Sem Vinculo"
    oMock["PERFIL"] := "ADMIN"
    oMock["SENHA"] := "Senha#Forte6"
    oMock["EMPRESAS"] := cCod
    oMock["FILIAL"] := ""
    aRet := GEBWAPI_USRPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: USRPOST adm sem vinc")
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPADM' AND D_E_L_E_T_ = ' '")
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    oMock["USUARIO"] := "T_WAPADM"
    oMock["EMPRESA"] := cCod
    oMock["SENHA"] := "Senha#Forte6"
    oMock["FILIAL"] := ""
    aRet := GEBWEB_LOGINAPI(oMock)
    If !(Len(aRet) == 4 .And. aRet[2] == .F.)
        lOk := .F.
        ConOut("FAIL: ADMIN sem vinculo entrou")
    Else
        ConOut("  OK admin sem vinculo recusado")
    EndIf
    TCSqlExec("SET search_path TO public")
    aGe2 := TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPADM' AND GE2_EMP_EMPRESA = '" + cCod + "' AND D_E_L_E_T_ = ' '")
    If !(Len(aGe2) == 0)
        lOk := .F.
        ConOut("FAIL: login recusado criou vinculo")
    Else
        ConOut("  OK nenhum vinculo criado")
    EndIf
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")

    // 8g. Vinculo legado com espacos ("      ") tambem loga (TRIM).
    oMock["CODIGO"] := "T_WAPLEG"
    oMock["NOME"] := "Legado Espacos"
    oMock["PERFIL"] := "OPERADOR"
    oMock["SENHA"] := "Senha#Forte5"
    oMock["EMPRESAS"] := cCod
    oMock["FILIAL"] := ""
    aRet := GEBWAPI_USRPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: USRPOST legado")
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("UPDATE GE2_EMP SET GE2_EMP_FILIAL = '      ' WHERE GE2_EMP_USUARIO = 'T_WAPLEG' AND D_E_L_E_T_ = ' '")
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    oMock["USUARIO"] := "T_WAPLEG"
    oMock["EMPRESA"] := cCod
    oMock["SENHA"] := "Senha#Forte5"
    oMock["FILIAL"] := ""
    aRet := GEBWEB_LOGINAPI(oMock)
    If !(Len(aRet) == 10 .And. aRet[2] == .T.)
        lOk := .F.
        ConOut("FAIL: login legado com espacos")
    Else
        ConOut("  OK login legado espacos")
    EndIf

    // 8h. Empresas publicas (sem token) para o seletor de ambiente.
    aRet := GEBWAPI_PUBEMP(oNil)
    cBody := ""
    If Len(aRet) >= 3
        cBody := cValToChar(aRet[3])
    EndIf
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. At(cCod, cBody) > 0)
        lOk := .F.
        ConOut("FAIL: PUBEMP sem empresa")
    Else
        ConOut("  OK empresas publicas")
    EndIf

    // 9. Ciclo usuario via HTTP: cria, atualiza, apaga.
    oMock["CODIGO"] := "T_WAPIDL"
    oMock["NOME"] := "Usuario Ciclo API"
    oMock["PERFIL"] := "OPERADOR"
    oMock["SENHA"] := "Senha#Forte2"
    oMock["EMPRESAS"] := cCod
    aRet := GEBWAPI_USRPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: USRPOST nao deu 201")
    Else
        ConOut("  OK usrpost 201")
    EndIf
    oMock["COD"] := "T_WAPIDL"
    oMock["NOME"] := "Usuario Ciclo API 2"
    oMock["PERFIL"] := ""
    oMock["SENHA"] := ""
    aRet := GEBWAPI_USRPUT(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: USRPUT")
    Else
        ConOut("  OK usrput 200")
    EndIf
    aRet := GEBWAPI_USRDEL(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: USRDEL")
    Else
        ConOut("  OK usrdel 200")
    EndIf

    // Cleanup (rerun limpo).
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPFIL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPFIL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPFIL'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPLEG'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPLEG'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPLEG'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WCASCA'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_WAPIDL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WCASCA'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_WAPIDL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPADM'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPSEL'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WCASCA'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_WAPIDL'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")

    If lOk
        ConOut("T_GEBWEB_API: PASS")
    Else
        ConOut("T_GEBWEB_API: FAIL")
    EndIf
Return lOk
