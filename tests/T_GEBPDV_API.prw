#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBV_MIG.prw"
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
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBFIS_APU.prw"
#include "../src/GEBFIN_CON.prw"
#include "../src/GEBFIN_BAI.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBDER_GUI.prw"
#include "../src/GEBDER_BAI.prw"
#include "../src/GEBDER_COB.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCPX.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBREST.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBWEB_API.prw"
#include "../src/GEBPDV_API.prw"
#include "../src/GEBPDV_HTML.prw"
#include "../src/GEBWEB.prw"

/*/{Protheus.doc} T_GEBPDV_API
    Rotas PDV do GEBWEB de ponta a ponta (mock de oReq = JsonObject com
    chaves em maiusculas, igual ao que o WSRestServer entrega):
    - sem token: 401 e nenhuma sessao de caixa gravada (auth antes da regra);
    - resposta RAW_HTTP no envelope {"ok":..,"dados":..} que public/pdv.html le
      (antes vinha string JSON re-codificada e r.ok era undefined);
    - abre caixa, faz sangria (antes aBody:TIOPO recusava toda sangria);
    - consulta cupom por {id} (antes o campo ID nunca chegava).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
User Function T_GEBPDV_API()
    Local lOk    := .T.
    Local cCod   := "zzpdvapi"
    Local cUsu   := "T_PDVAPI"
    Local cSenha := "Senha#Forte1"
    Local cTok   := ""
    Local cSes   := ""
    Local oReq   := Nil
    Local oJ     := Nil
    Local aRet   := {}
    Local aQ     := {}

    ConOut("=== T_GEBPDV_API ===")
    If !GEBDBConecta()
        ConOut("T_GEBPDV_API: FAIL GEBDBConecta")
        Return .F.
    EndIf
    Limpa(cCod, cUsu)
    If !GEBDBProvisionaCatalogo() .Or. !GEBDBProvisionaEmpresa(cCod, "Empresa Teste PDV")
        ConOut("T_GEBPDV_API: FAIL provisionamento")
        Return .F.
    EndIf
    If !GEBSECCRIAUSU(cUsu, cSenha, {cCod}, "Usuario PDV", "ADMIN")
        ConOut("T_GEBPDV_API: FAIL GEBSECCRIAUSU")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    If !GEBFMIG() .Or. !GEBLOJMIG()
        ConOut("T_GEBPDV_API: FAIL migracoes do tenant")
        Return .F.
    EndIf
    GEBFNCON("BANCO", "Banco")
    GEBLOJCX("CX1", "Caixa 1", "", "")
    TCSqlExec("SET search_path TO public")
    aQ := TCSqlQuery("SELECT GE2_FILIAL FROM GE2 WHERE GE2_COD = '" + cUsu + "' AND D_E_L_E_T_ = ' '")
    If Len(aQ) > 0
        cTok := GEBSECTOKEN(cUsu, cCod, cValToChar(aQ[1]:GE2_FILIAL), "test")
    EndIf
    lOk := Chk(lOk, "token", !Empty(cTok))

    // Sem token: 401 e a abertura nao pode ter rodado.
    oReq := JsonObject():New()
    oReq["CAIXA"] := "CX1"
    oReq["OPERADOR"] := cUsu
    oReq["FUNDO"] := 100
    aRet := GEBWAPI_PDVCAIXAABR(oReq)
    lOk := Chk(lOk, "abrir sem token = 401", Len(aRet) >= 4 .And. aRet[4] == 401)
    TCSqlExec("SET search_path TO emp_" + cCod + ", public")
    aQ := TCSqlQuery("SELECT COUNT(*) AS N FROM GLJ2")
    lOk := Chk(lOk, "nenhuma sessao gravada sem token", Len(aQ) > 0 .And. Val(cValToChar(aQ[1]:N)) == 0)

    // Lista: RAW 200 no envelope do pdv.html.
    oReq["TOKEN"] := cTok
    oReq["EMPRESA"] := cCod
    aRet := GEBWAPI_PDVCAIXALST(oReq)
    oJ := Corpo(aRet)
    lOk := Chk(lOk, "lista RAW 200 com ok=true", oJ != Nil .And. aRet[4] == 200 .And. oJ["ok"] == .T.)

    // Abre caixa e faz sangria.
    aRet := GEBWAPI_PDVCAIXAABR(oReq)
    oJ := Corpo(aRet)
    If oJ != Nil .And. oJ["ok"] == .T.
        cSes := cValToChar(oJ["dados"][3])
    EndIf
    lOk := Chk(lOk, "abre caixa devolve sessao", !Empty(cSes))
    oReq["SESSAO"] := cSes
    oReq["TIPO"] := "SANGRIA"
    oReq["VALOR"] := 10
    oReq["MOTIVO"] := "teste"
    oJ := Corpo(GEBWAPI_PDVSANGRIA(oReq))
    If oJ != Nil
        ConOut("  sangria: " + cValToChar(oJ["msg"]))
    EndIf
    lOk := Chk(lOk, "sangria aceita", oJ != Nil .And. oJ["ok"] == .T.)

    // Cupom por {id}: o id tem de chegar (inexistente != obrigatorio).
    oReq["ID"] := "NAOEXISTE"
    oJ := Corpo(GEBWAPI_PDVCUPOMGET(oReq))
    lOk := Chk(lOk, "cupom recebe o id", oJ != Nil .And. !("cupom_obrigatorio" $ cValToChar(oJ["erro"])))

    Limpa(cCod, cUsu)
    If lOk
        ConOut("T_GEBPDV_API: PASS")
    Else
        ConOut("T_GEBPDV_API: FAIL")
    EndIf
Return lOk

/*/{Protheus.doc} Corpo
    JSON do corpo de uma resposta RAW_HTTP (Nil se nao for RAW ou nao parsear).
    @type function
    @author Peder Munksgaard
    @since 21/11/2026
/*/
Static Function Corpo(aRet)
    Local oJ := Nil

    If ValType(aRet) == "A" .And. Len(aRet) >= 3 .And. aRet[1] == "__RAW_HTTP__"
        oJ := JsonObject():New()
        // AdvPP: FromJson devolve .T./.F.; Protheus: Nil ou a mensagem de erro.
        If ValType(oJ:FromJson(aRet[3])) == "C" .Or. Len(oJ:GetNames()) == 0
            ConOut("  corpo nao e' JSON: " + Left(aRet[3], 200))
            oJ := Nil
        EndIf
    EndIf
Return oJ

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL " + cNome)
Return .F.

Static Function Limpa(cCod, cUsu)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
Return
