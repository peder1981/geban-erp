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
#include "../src/GEBMON.prw"
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

/*/{Protheus.doc} T_GEBSEC_API
    Seguranca da API exposta (/api/*, Fase 3 da revisao geral):
    token forjado com SQL, token previsivel, token apos logout e token
    expirado tem de dar 401. Empresa descartavel zzsecapi.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 02/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBSEC_API()
    Local lOk    := .T.
    Local cCod   := "zzsecapi"
    Local cUsu   := "T_SECAPI"
    Local cTok   := ""
    Local cTok2  := ""
    Local oMock  := Nil
    Local aRet   := {}

    If !GEBDBConecta()
        ConOut("T_GEBSEC_API FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
    If !GEBDBProvisionaCatalogo() .Or. !GEBDBProvisionaEmpresa(cCod, "Empresa Teste SecAPI")
        ConOut("T_GEBSEC_API FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    If !GEBSECCRIAUSU(cUsu, "Senha#Forte1", {cCod}, "Usuario SecAPI", "ADMIN")
        ConOut("T_GEBSEC_API FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1") // area corrente no catalogo (RestArea de GE4 do provisionamento quebraria; CAT-007)
    cTok := GEBSECTOKEN(cUsu, cCod, "", "10.0.0.1")
    cTok2 := GEBSECTOKEN(cUsu, cCod, "", "10.0.0.1")
    TCSqlExec("SET search_path TO public")

    // 0) controle: token legitimo passa.
    oMock := JsonObject():New()
    oMock["TOKEN"] := cTok
    oMock["EMPRESA"] := cCod
    aRet := GEBWAPI_USRLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 200)
        lOk := .F.
        ConOut("FAIL: token legitimo deveria dar 200")
    Else
        ConOut("  OK token legitimo 200")
    EndIf

    // 1) token forjado com SQL nao autentica.
    TCSqlExec("SET search_path TO public")
    oMock := JsonObject():New()
    oMock["TOKEN"] := "' OR '1'='1"
    oMock["EMPRESA"] := cCod
    aRet := GEBWAPI_USRLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: token forjado com SQL autenticou (status " + cValToChar(aRet[4]) + ")")
    Else
        ConOut("  OK token forjado com SQL -> 401")
    EndIf

    // 2) dois logins no mesmo segundo/IP geram tokens diferentes (nao previsivel).
    If cTok == cTok2 .Or. At(cUsu, cTok) > 0
        lOk := .F.
        ConOut("FAIL: token previsivel (" + cTok + " / " + cTok2 + ")")
    Else
        ConOut("  OK tokens distintos e sem dados do usuario")
    EndIf

    // 3) token apos logout -> 401.
    TCSqlExec("SET search_path TO public")
    GEBSECTOKENDEL(cTok)
    TCSqlExec("SET search_path TO public")
    oMock := JsonObject():New()
    oMock["TOKEN"] := cTok
    oMock["EMPRESA"] := cCod
    aRet := GEBWAPI_USRLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: token apos logout autenticou")
    Else
        ConOut("  OK token apos logout -> 401")
    EndIf

    // 4) token expirado -> 401.
    TCSqlExec("SET search_path TO public")
    TCSqlExec("UPDATE GE2_TOK SET TOK_EXPIRES = '20000101 00:00:00' WHERE TOK_TOKEN = '" + StrTran(cTok2, "'", "''") + "'")
    oMock := JsonObject():New()
    oMock["TOKEN"] := cTok2
    oMock["EMPRESA"] := cCod
    aRet := GEBWAPI_USRLST(oMock)
    If !(Len(aRet) >= 4 .And. aRet[4] == 401)
        lOk := .F.
        ConOut("FAIL: token expirado autenticou")
    Else
        ConOut("  OK token expirado -> 401")
    EndIf

    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")

    If lOk
        ConOut("T_GEBSEC_API PASS")
    Else
        ConOut("T_GEBSEC_API FAIL")
    EndIf
Return lOk
