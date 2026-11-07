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
#include "../src/GEBDER_FIN.prw"
#include "../src/GEBRET.prw"
#include "../src/GEBSN.prw"
#include "../src/GEBBCO.prw"
#include "../src/GEBBO.prw"
#include "../src/GEBDFE_DIST.prw"
#include "../src/GEBDFE_EFD.prw"
#include "../src/GEBDFE_NFSE.prw"
#include "../src/GEBDFE_NFE.prw"
#include "../src/GEBDFE_DANFE55.prw"

/*/{Protheus.doc} T_GEBDFE_WEB
    Rotas web dos documentos fiscais com empresa, usuario ADMIN e token
    reais (empresa descartavel zzdfeweb): pagina do assistente
    (/api/dfe/configurar), emitente, configuracao, certificado (.pfx em
    Base64) e roteiro por /api/bo/dfe/*, e o DANFE (/api/dfe/danfe) sem
    token (401) e com chave inexistente (404).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 19/10/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBDFE_WEB()
    Local lOk := .T.
    Local cCod := "zzdfeweb"
    Local cUsu := "T_DFEWEB"
    Local cTok := ""
    Local cDir := "/tmp/geban-tdfeweb-" + StrZero(Randomize(1, 999999), 6)
    Local aRet := {}
    Local aOut := {}
    Local oM := Nil

    If !GEBDBConecta()
        ConOut("T_GEBDFE_WEB FAIL")
        Return .F.
    EndIf
    Limpa(cCod, cUsu)
    If !GEBDBProvisionaCatalogo() .Or. !GEBDBProvisionaEmpresa(cCod, "Empresa Teste DFE Web")
        ConOut("T_GEBDFE_WEB FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    If !GEBSECCRIAUSU(cUsu, "Senha#Forte1", {cCod}, "Usuario DFE Web", "ADMIN")
        ConOut("T_GEBDFE_WEB FAIL")
        Return .F.
    EndIf
    TCSqlExec("SET search_path TO public")
    DbSelectArea("GE1")
    cTok := GEBSECTOKEN(cUsu, cCod, "", "10.0.0.1")
    TCSqlExec("SET search_path TO public")

    // Pagina do assistente (publica).
    aRet := GEBWAPI_DFEPAG(Nil)
    lOk := Chk(lOk, "pagina do assistente", aRet[4] == 200 .And. "text/html" $ aRet[2] .And. "Configura" $ aRet[3] .And. "dfe/certificado" $ aRet[3])

    // Sem token: 401.
    oM := JsonObject():New()
    oM["MODULO"] := "dfe"
    oM["ACAO"] := "roteiro"
    lOk := Chk(lOk, "roteiro sem token", GEBWAPI_BOGET(oM)[4] == 401)
    lOk := Chk(lOk, "danfe sem token", GEBWAPI_DFEDANFE(oM)[4] == 401)

    // Emitente e configuracao pela API.
    oM := Req(cTok, cCod, "emitente")
    oM["CNPJ"] := "12345678000195"
    oM["IE"] := "110042490114"
    oM["RAZAO"] := "Empresa Teste DFE Web Ltda"
    oM["CRT"] := "1"
    oM["LOGRADOURO"] := "Rua A"
    oM["NUMERO"] := "1"
    oM["BAIRRO"] := "Centro"
    oM["UF"] := "SP"
    oM["MUNICIPIO"] := "3550308"
    oM["CEP"] := "01001000"
    aRet := GEBWAPI_BOPOST(oM)
    lOk := Chk(lOk, "emitente pela api", aRet[4] == 200 .And. "SAO PAULO" $ aRet[3])
    aRet := GEBWAPI_BOGET(Req(cTok, cCod, "emitente"))
    lOk := Chk(lOk, "le emitente", aRet[4] == 200 .And. "12345678000195" $ aRet[3])
    oM := Req(cTok, cCod, "municipios")
    oM["NOME"] := "ribeirao preto"
    oM["UF"] := "SP"
    aRet := GEBWAPI_BOGET(oM)
    lOk := Chk(lOk, "busca municipio", aRet[4] == 200 .And. "3543402" $ aRet[3])
    oM := Req(cTok, cCod, "configuracao")
    oM["AMBIENTE"] := "9"
    lOk := Chk(lOk, "configuracao invalida 400", GEBWAPI_BOPOST(oM)[4] == 400)
    oM["AMBIENTE"] := "2"
    oM["CERT_DIR"] := "/etc"
    lOk := Chk(lOk, "configuracao", GEBWAPI_BOPOST(oM)[4] == 200)
    // A pasta dos certificados nao vem pela API (so' o operador grava DFE_CERT_DIR).
    GEBDBSetTenant(cCod)
    lOk := Chk(lOk, "cert_dir fora da api", BOPARM("DFE_CERT_DIR", "") == "")
    BOSETPARM("DFE_CERT_DIR", cDir + "/cert")

    // Certificado em Base64 pela API.
    ProcRun("mkdir", {"-p", cDir}, {|c| aAdd(aOut, c)})
    ProcRun("openssl", {"req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", cDir + "/k.pem", "-out", cDir + "/c.pem", "-days", "60", "-subj", ;
        "/C=BR/O=ICP-Brasil/CN=EMPRESA TESTE DFE WEB LTDA:12345678000195"}, {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})
    ProcRun("openssl", {"pkcs12", "-export", "-inkey", cDir + "/k.pem", "-in", cDir + "/c.pem", "-out", cDir + "/e.pfx", "-passout", "pass:Abc12345"}, ;
        {|c| aAdd(aOut, c)}, {|c| aAdd(aOut, c)})
    oM := Req(cTok, cCod, "certificado")
    oM["PFX"] := Encode64(MemoRead(cDir + "/e.pfx"))
    oM["SENHA"] := "Abc12345"
    aRet := GEBWAPI_BOPOST(oM)
    lOk := Chk(lOk, "certificado pela api", aRet[4] == 200 .And. "instalado" $ aRet[3])

    // Roteiro sem teste de comunicacao: emitente e certificado OK.
    oM := Req(cTok, cCod, "roteiro")
    oM["TESTAR"] := "N"
    aRet := GEBWAPI_BOGET(oM)
    lOk := Chk(lOk, "roteiro pela api", aRet[4] == 200 .And. "1. Emitente" $ aRet[3] .And. "EMPRESA TESTE DFE WEB LTDA" $ aRet[3])
    If !("EMPRESA TESTE DFE WEB LTDA" $ aRet[3])
        ConOut("    " + cValToChar(aRet[4]) + " " + Left(aRet[3], 900))
    EndIf

    // DANFE com token e chave inexistente: 404.
    oM := JsonObject():New()
    oM["TOKEN"] := cTok
    oM["EMPRESA"] := cCod
    oM["CHAVE"] := Replicate("1", 44)
    lOk := Chk(lOk, "danfe chave inexistente", GEBWAPI_DFEDANFE(oM)[4] == 404)

    ProcRun("rm", {"-rf", cDir}, {|c| aAdd(aOut, c)})
    Limpa(cCod, cUsu)
    If lOk
        ConOut("T_GEBDFE_WEB PASS")
    Else
        ConOut("T_GEBDFE_WEB FAIL")
    EndIf
Return lOk

Static Function Req(cTok, cCod, cAcao)
    Local oM := JsonObject():New()
    oM["TOKEN"] := cTok
    oM["EMPRESA"] := cCod
    oM["MODULO"] := "dfe"
    oM["ACAO"] := cAcao
Return oM

Static Function Limpa(cCod, cUsu)
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_" + cCod + " CASCADE")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = '" + cUsu + "'")
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD = '" + cCod + "'")
Return Nil

Static Function Chk(lOk, cNome, lCond)
    If lCond
        ConOut("  OK " + cNome)
        Return lOk
    EndIf
    ConOut("  FAIL: " + cNome)
Return .F.
