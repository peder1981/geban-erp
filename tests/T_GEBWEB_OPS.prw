#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GENUC_CAD.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBV_VEN.prw"
#include "../src/GEBV_FIA.prw"
#include "../src/GEBCTB_DIR.prw"
#include "../src/GEBCTB_BAL.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBCOM_FOR.prw"
#include "../src/GEBCOM_PED.prw"
#include "../src/GEBCOM_ENT.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBV_EST.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBBOLIB.prw"
#include "../src/GEBCTX.prw"
#include "../src/GEBEST.prw"
#include "../src/GEBFNX.prw"
#include "../src/GEBCPX.prw"
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
#include "../src/GEBBCO.prw"
#include "../src/GEBBO.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBWEB_API.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"

/*/{Protheus.doc} T_GEBWEB_OPS
    Prova operacional ponta a ponta das 19 rotas de operacao via HTTP:
    derrama (gerar/baixar/parcelar/juros/protestar), estoque (vender/
    fiado/juros), contabil (lancar/balancete/dre), financeiro (conta/
    baixar), compras (fornecedor/pedido/item/entrada), fiscal (apurar/
    credito). Cada operacao: caminho feliz + negativo principal.
    Setup: empresa descartavel zzops, ADMIN T_OPSADM, tabelas via
    provisionamento + seeds minimos (estoque, titulo a pagar, flag
    PERMITE_DIRETA). Cleanup total no fim (rerun limpo).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 25/09/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBWEB_OPS()
    Local lOk    := .T.
    Local cCod   := "zzops"
    Local cUsu   := "T_OPSADM"
    Local cSenha := "Senha#Forte1"
    Local cFil   := ""
    Local cTok   := ""
    Local aGe2   := {}
    Local oMock  := Nil
    Local oNil   := Nil
    Local aRet   := {}
    Local cBody  := ""
    Local aG     := {}
    Local cGuia  := ""
    Local cGuia2 := ""
    Local cGuia3 := ""
    Local cFil   := ""
    Local oItem := Nil

    ConOut("=== T_GEBWEB_OPS ===")

    If !GEBDBConecta()
        ConOut("T_GEBWEB_OPS: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    If !GEBDBProvisionaCatalogo()
        ConOut("FAIL: catalogo")
        Return .F.
    EndIf
    If !GEBDBProvisionaEmpresa(cCod, "Empresa Teste Ops")
        ConOut("FAIL: empresa")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    If !GEBSECCRIAUSU(cUsu, cSenha, {cCod}, "Operador Ops", "ADMIN")
        ConOut("FAIL: cria usuario")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    If !GEBFMIG()
        lOk := .F.
        ConOut("FAIL: GEBFMIG")
    EndIf
    If !GEBFNMIG()
        lOk := .F.
        ConOut("FAIL: GEBFNMIG")
    EndIf
    cFil := FWxFilial("GE1")
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'PERMITE_DIRETA', 'S')")
    TCSqlExec("INSERT INTO GV1 (D_E_L_E_T_, GV1_FILIAL, GV1_PROD, GV1_SALDO, GV1_MIN) VALUES (' ', '" + cFil + "', 'WOP01', 100, 0)")
    TCSqlExec("INSERT INTO GFN3 (D_E_L_E_T_, GFN3_FILIAL, GFN3_DOC, GFN3_FORN, GFN3_VALOR, GFN3_SALDO, GFN3_VENC, GFN3_STATUS) VALUES (' ', '" + cFil + "', 'DOCT01', 'WFOR01', 500, 500, '20260930', 'ABERTO')")
    TCSqlExec("SET search_path TO public")
    aGe2 := TCSqlQuery("SELECT GE2_FILIAL FROM GE2 WHERE GE2_COD = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
    If Len(aGe2) == 0
        ConOut("FAIL: sem GE2")
        Return .F.
    EndIf
    cFil := cValToChar(aGe2[1]:GE2_FILIAL)
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    cTok := GEBSECTOKEN(cUsu, cCod, cFil, "test")
    If cTok == ""
        ConOut("FAIL: token")
        Return .F.
    EndIf
    oMock := JsonObject():New()
    oMock["TOKEN"] := cTok
    oMock["EMPRESA"] := cCod

    // Financeiro: conta + baixa de titulo a pagar.
    oMock["CONTA"] := "WCON01"
    oMock["NOME"] := "Conta Ops"
    aRet := GEBWAPI_FINCON(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: FINCON")
    Else
        ConOut("  OK conta 201")
    EndIf
    oMock["CONTA"] := ""
    aRet := GEBWAPI_FINCON(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: FINCON vazia nao deu 400")
    EndIf
    oMock["TIPO"] := "PAGAR"
    oMock["DOCUMENTO"] := "DOCT01"
    oMock["VALOR"] := "100"
    aRet := GEBWAPI_FINBAI(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: FINBAI")
    Else
        ConOut("  OK baixa 200")
    EndIf
    oMock["DOCUMENTO"] := "ZZINEXISTE"
    aRet := GEBWAPI_FINBAI(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: FINBAI ruim nao deu 404")
    EndIf

    // Compras: fornecedor, pedido, item, entrada.
    oMock["CODIGO"] := "WFOR01"
    oMock["NOME"] := "Fornecedor Ops"
    aRet := GEBWAPI_COMFOR(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: COMFOR")
    Else
        ConOut("  OK fornecedor 201")
    EndIf
    oMock["PEDIDO"] := "WPED01"
    oMock["FORNECEDOR"] := "WFOR01"
    aRet := GEBWAPI_COMPED(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: COMPED")
    Else
        ConOut("  OK pedido 201")
    EndIf
    oMock["PEDIDO"] := ""
    aRet := GEBWAPI_COMPED(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: COMPED vazio nao deu 400")
    EndIf
    oMock["PEDIDO"] := "WPED01"
    oMock["PRODUTO"] := "WOP01"
    oMock["QUANTIDADE"] := "5"
    oMock["PRECO"] := "20"
    aRet := GEBWAPI_COMIT(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: COMIT")
    Else
        ConOut("  OK item 201")
    EndIf
    oMock["NF"] := "WNF01"
    oMock["PEDIDO"] := "WPED01"
    aRet := GEBWAPI_COMENT(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: COMENT")
    Else
        ConOut("  OK entrada 201")
    EndIf

    // Fiscal: produto, apuracao, credito.
    oMock["CODIGO"] := "WOP01"
    oMock["NCM"] := "84713012"
    oMock["DESCRICAO"] := "Teclado Ops"
    aRet := GEBWAPI_PRDLSC(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: PRDLSC ops")
    EndIf
    oMock["COMPETENCIA"] := "202609"
    aRet := GEBWAPI_FISAPU(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: FISAPU")
    Else
        ConOut("  OK apuracao 200")
    EndIf
    oMock["COMPETENCIA"] := ""
    aRet := GEBWAPI_FISAPU(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: FISAPU vazia nao deu 400")
    EndIf
    // Simples Nacional: config, folha, apuracao (rotas /api/fiscal/simples/*).
    oMock["ANEXO"] := "VI"
    oMock["INICIO"] := ""
    aRet := GEBWAPI_SNCFG(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: SNCFG anexo VI nao deu 400")
    EndIf
    oMock["ANEXO"] := "FR"
    aRet := GEBWAPI_SNCFG(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNCFG")
    EndIf
    oMock["COMPETENCIA"] := "202608"
    oMock["FOLHA"] := "5000"
    oMock["RECEITA_EXTERNA"] := "20000"
    aRet := GEBWAPI_SNFOL(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNFOL")
    EndIf
    oMock["COMPETENCIA"] := "202609"
    aRet := GEBWAPI_SNAPU(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNAPU")
    Else
        ConOut("  OK simples nacional 200")
    EndIf
    oMock["CODIGO"] := "WCOM"
    oMock["DESCRICAO"] := "Comercio"
    oMock["ANEXO"] := "I"
    aRet := GEBWAPI_SNATV(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNATV")
    EndIf
    oMock["PRODUTO"] := "WOP01"
    oMock["ATIVIDADE"] := "WCOM"
    oMock["ST"] := "N"
    oMock["MONOFASICO"] := "S"
    aRet := GEBWAPI_SNPRD(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNPRD")
    EndIf
    oMock["DATA"] := "20261020"
    aRet := GEBWAPI_SNFER(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNFER")
    EndIf
    oMock["CHAVE"] := "NAO-EXISTE"
    oMock["EXPORTACAO"] := "S"
    aRet := GEBWAPI_SNEXP(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: SNEXP nota inexistente nao deu 400")
    EndIf
    oMock["COMP"] := "202609"
    aRet := GEBWAPI_SNEXT(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNEXT")
    EndIf
    oMock["COMP"] := "202601"
    aRet := GEBWAPI_SNEXT(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: SNEXT nao apurado nao deu 404")
    EndIf
    oMock["ANO"] := "2026"
    aRet := GEBWAPI_SNANU(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: SNANU")
    Else
        ConOut("  OK relatorios simples 200")
    EndIf
    // Backoffice: /api/bo/{modulo}/{acao}.
    oMock["MODULO"] := "estoque"
    oMock["ACAO"] := "movimento"
    oMock["PRODUTO"] := "WOP01"
    oMock["ARMAZEM"] := "01"
    oMock["TIPO"] := "E"
    oMock["QUANTIDADE"] := "10"
    oMock["CUSTO"] := "5"
    oMock["DOCUMENTO"] := "WBO1"
    oMock["DATA"] := "20261001"
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: BO estoque/movimento")
    EndIf
    oMock["ACAO"] := "saldo"
    aRet := GEBWAPI_BOGET(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. "10" $ aRet[3])
        lOk := .F.
        ConOut("FAIL: BO estoque/saldo")
    EndIf
    oMock["ACAO"] := "nao-existe"
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: BO rota inexistente nao deu 404")
    EndIf
    oMock["MODULO"] := "faturamento"
    oMock["ACAO"] := "cliente"
    oMock["CODIGO"] := "WCLI"
    oMock["NOME"] := "Cliente web"
    oMock["LIMITE"] := "0"
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: BO faturamento/cliente")
    EndIf
    oItem := JsonObject():New()
    oItem["PRODUTO"] := "WOP01"
    oItem["QUANTIDADE"] := 2
    oItem["PRECO"] := 9
    oMock["ACAO"] := "pedido"
    oMock["CLIENTE"] := "WCLI"
    oMock["ITENS"] := {oItem}
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200 .And. "18" $ aRet[3])
        lOk := .F.
        ConOut("FAIL: BO faturamento/pedido")
    EndIf
    oMock["CLIENTE"] := "NAO-EXISTE"
    aRet := GEBWAPI_BOPOST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: BO pedido cliente inexistente nao deu 400")
    Else
        ConOut("  OK backoffice 200/400/404")
    EndIf
    oMock["COMPETENCIA"] := "202609"
    oMock["ORIGEM"] := "WNF01"
    oMock["VALOR"] := "100"
    oMock["TIPO"] := "ENTRADA"
    aRet := GEBWAPI_FISCRE(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: FISCRE")
    Else
        ConOut("  OK credito 201")
    EndIf

    // Estoque: venda, fiado, juros.
    oMock["VENDA"] := "WVEN01"
    oMock["PRODUTO"] := "WOP01"
    oMock["QUANTIDADE"] := "2"
    oMock["PRECO"] := "50"
    aRet := GEBWAPI_ESTVEN(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: ESTVEN")
    Else
        ConOut("  OK venda 201")
    EndIf
    oMock["QUANTIDADE"] := "500"
    aRet := GEBWAPI_ESTVEN(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 409)
        lOk := .F.
        ConOut("FAIL: ESTVEN sem estoque nao deu 409")
    EndIf
    oMock["CLIENTE"] := "WCLI01"
    oMock["VALOR"] := "500"
    aRet := GEBWAPI_ESTFIA(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: ESTFIA")
    Else
        ConOut("  OK fiado 201")
    EndIf
    oMock["VALOR"] := "5000"
    aRet := GEBWAPI_ESTFIA(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: ESTFIA limite nao deu 400")
    EndIf
    oMock["CLIENTE"] := "WCLI01"
    oMock["DIAS"] := "10"
    aRet := GEBWAPI_ESTFIJ(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: ESTFIJ")
    Else
        ConOut("  OK juros fiado 200")
    EndIf

    // Contabil: lancar, balancete, DRE.
    oMock["DEBITO"] := "1.01.001"
    oMock["CREDITO"] := "3.01.001"
    oMock["VALOR"] := "250"
    aRet := GEBWAPI_CTBDIR(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 201)
        lOk := .F.
        ConOut("FAIL: CTBDIR")
    Else
        ConOut("  OK lancamento 201")
    EndIf
    oMock["VALOR"] := "0"
    aRet := GEBWAPI_CTBDIR(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 400)
        lOk := .F.
        ConOut("FAIL: CTBDIR zerado nao deu 400")
    EndIf
    oMock["COMP"] := "202609"
    aRet := GEBWAPI_CTBBAL(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: CTBBAL")
    Else
        ConOut("  OK balancete 200")
    EndIf
    aRet := GEBWAPI_CTBDRE(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: CTBDRE")
    Else
        ConOut("  OK dre 200")
    EndIf

    // Derrama: gerar, juros, parcelar, baixar, protestar. A configuracao do
    // Simples acima optou a empresa pelo Simples; a guia de IBS/CBS e' do
    // regime REGULAR.
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    TCSqlExec("UPDATE GE4 SET D_E_L_E_T_ = '*' WHERE GE4_EVENTO = 'REGIME'")
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'REGIME', 'REGULAR')")
    // Sem notas a apuracao de 202609 tem saldo 0 (sem guia): imposto de 300 a pagar.
    TCSqlExec("UPDATE GF5 SET GF5_DEB = 300, GF5_SALDO = 300 WHERE GF5_COMP = '202609' AND D_E_L_E_T_ = ' '")
    oMock["COMPETENCIA"] := "202609"
    aRet := GEBWAPI_DERGER(oMock)
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    aG := TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_COMP = '202609' AND D_E_L_E_T_ = ' ' LIMIT 1")
    If !(Len(aRet) >= 4 .And. aRet[4] == 201 .And. Len(aG) > 0)
        lOk := .F.
        ConOut("FAIL: DERGER")
    Else
        cGuia := cValToChar(aG[1]:GD1_GUIA)
        ConOut("  OK guia 201 " + cGuia)
    EndIf
    oMock["GUIA"] := cGuia
    oMock["DIAS"] := "10"
    aRet := GEBWAPI_DERJUR(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: DERJUR")
    Else
        ConOut("  OK juros 200")
    EndIf
    oMock["GUIA"] := cGuia
    oMock["PARCELAS"] := "3"
    aRet := GEBWAPI_DERPAR(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: DERPAR")
    Else
        ConOut("  OK parcelar 200")
    EndIf
    oMock["GUIA"] := cGuia
    aRet := GEBWAPI_DERBAI(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: DERBAI")
    Else
        ConOut("  OK baixar 200")
    EndIf
    aRet := GEBWAPI_DERBAI(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: DERBAI repetida nao deu 200 (idempotente)")
    EndIf
    oMock["GUIA"] := "ZZINEXISTE"
    aRet := GEBWAPI_DERBAI(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: DERBAI ruim nao deu 404")
    EndIf
    oMock["COMPETENCIA"] := "202610"
    aRet := GEBWAPI_FISAPU(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: FISAPU 202610")
    EndIf
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    TCSqlExec("UPDATE GF5 SET GF5_DEB = 100, GF5_SALDO = 100 WHERE GF5_COMP = '202610' AND D_E_L_E_T_ = ' '")
    aRet := GEBWAPI_DERGER(oMock)
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    aG := TCSqlQuery("SELECT GD1_GUIA FROM GD1 WHERE GD1_COMP = '202610' AND D_E_L_E_T_ = ' ' LIMIT 1")
    If Len(aG) > 0
        cGuia2 := cValToChar(aG[1]:GD1_GUIA)
    EndIf
    oMock["GUIA"] := cGuia2
    aRet := GEBWAPI_DERPRO(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: DERPRO")
    Else
        ConOut("  OK protestar 200")
    EndIf
    oMock["GUIA"] := "ZZINEXISTE"
    aRet := GEBWAPI_DERPRO(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 404)
        lOk := .F.
        ConOut("FAIL: DERPRO ruim nao deu 404")
    EndIf

    // Sem token: amostra.
    aRet := GEBWAPI_ESTVEN(oNil)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: ESTVEN sem token nao deu 401")
    EndIf
    aRet := GEBWAPI_CTBDIR(oNil)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: CTBDIR sem token nao deu 401")
    EndIf

    // Cleanup (rerun limpo).
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")

    If lOk
        ConOut("T_GEBWEB_OPS: PASS")
    Else
        ConOut("T_GEBWEB_OPS: FAIL")
    EndIf
Return lOk
