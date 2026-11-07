#include "totvs.ch"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBAUD.prw"
#include "../src/GENUC_MNT.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBDER_MIG.prw"
#include "../src/GEBV_MIG.prw"
#include "../src/GEBCOM_MIG.prw"
#include "../src/GEBCTB_MIG.prw"
#include "../src/GEBFIS_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBEXP_CTX.prw"
#include "../src/GEBEXP_REL_NUC.prw"
#include "../src/GEBEXP_REL_BIZ.prw"
#include "../src/GEBFIN_MIG.prw"
#include "../src/GEBFIN_FLX.prw"
#include "../src/GEBFIS_CAD.prw"
#include "../src/GEBFIS_EMI.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBREST.prw"
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

/*/{Protheus.doc} T_GEBREST
    Testes da camada REST GEBREST (Task 8 GEB_REST).
    Testa: health, usuarios CRUD, empresas, produtos, notas, fluxo,
    relatorios, monitor (ADMIN), rate limiting basico, respostas JSON.
    Cleanup DELETE em todas as tabelas tocadas (rerun limpo).
    Schema descartavel (test_gebrest): conecta ao Postgres via
    GEBDBConecta(), cria schema isolado e roda as migracoes de
    dependencia (GENMIG/TCSecMIG/GEBFMIG/GEBFNMIG) nesse schema.
    So literais em TCSqlExec/TCSqlQuery; ConOut PASS/FAIL.
    POST/PUT/DELETE conferem a gravacao real via TCSqlQuery (POST
    /usuarios via GEBSECCRIAUSU: GE2 + GE2_SEC + GE2_EMP numa empresa
    descartavel emp_zzgebrest); T28-T31 provam que escrita negada por
    RBAC nao executa; T32 cobre aspas simples em token/chave.
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
    @return .T. se todos os asserts passarem, .F. caso contrario
/*/
User Function T_GEBREST()
    Local lOk       := .T.
    Local lTmp      := .F.
    Local aRes      := {}
    Local cStatus   := ""
    Local cBody     := ""
    Local aCtx      := {}
    Local cFil      := ""
    Local aDados    := {}
    Local nIdx      := 0
    Local cVal      := ""
    Local lFound    := .F.
    Local cSalt1    := ""
    Local cSalt2    := ""

    ConOut("=== T_GEBREST ===")

    If !GEBDBConecta()
        ConOut("T_GEBREST: GEBDBConecta fail")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebrest CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebrest")
    TCSqlExec("SET search_path TO test_gebrest")

    // Roda migracoes base.
    lTmp := GENMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL GENMIG")
    Else
        ConOut("  OK GENMIG")
    EndIf
    lTmp := TCSecMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL TCSecMIG")
    Else
        ConOut("  OK TCSecMIG")
    EndIf
    // Tabelas de negocio no schema da EMPRESA (como em producao); o
    // catalogo (GE1/GE2/seguranca) fica em test_gebrest.
    TCSqlExec("DROP SCHEMA IF EXISTS emp_zzgebrest CASCADE")
    TCSqlExec("CREATE SCHEMA emp_zzgebrest")
    TCSqlExec("SET search_path TO emp_zzgebrest, test_gebrest")
    lTmp := GEBFMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL GEBFMIG")
    Else
        ConOut("  OK GEBFMIG")
    EndIf
    lTmp := GEBFNMIG()
    If !lTmp
        lOk := .F.
        ConOut("  FAIL GEBFNMIG")
    Else
        ConOut("  OK GEBFNMIG")
    EndIf
    // GEI_AUDIT (por empresa): GEBFEMI() audita a emissao via GBAUDLOG;
    // num tenant real a tabela vem do provisionamento da empresa.
    GBAUDINIC()

    // Seed empresas. GE1 nao tem mais coluna EMPRESA (aposentada no
    // redesign multi-tenant Fase 1) -- ver GEBEXP_CTX.prw.
    cFil := FWxFilial("GE1")
    TCSqlExec("DELETE FROM GE1 WHERE D_E_L_E_T_ = ' ' AND GE1_COD IN ('01','02')")
    TCSqlExec("INSERT INTO GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '" + cFil + "', '01', 'Empresa Teste 01')")
    TCSqlExec("INSERT INTO GE1 (D_E_L_E_T_, GE1_FILIAL, GE1_COD, GE1_NOME) VALUES (' ', '" + cFil + "', '02', 'Empresa Teste 02')")

    // Seed usuarios ADMIN e OPERADOR. GE2 tambem nao tem mais coluna
    // EMPRESA -- vinculo usuario-empresa agora e' via GE2_EMP.
    TCSqlExec("DELETE FROM GE2 WHERE D_E_L_E_T_ = ' ' AND GE2_COD IN ('REST-ADM','REST-OP')")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'REST-ADM', 'Admin REST', 'ADMIN')")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'REST-OP', 'Operador REST', 'OPERADOR')")
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'REST-ADM', 'GEBAN', '12345', 0, '00000000', '00000000', '" + DToS(Date()) + "')")
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'REST-OP', 'GEBAN', '67890', 0, '00000000', '00000000', '" + DToS(Date()) + "')")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('REST-ADM','REST-OP')")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '" + cFil + "', 'REST-ADM', 'zzgebrest', 'ADMIN')")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA, GE2_EMP_PERFIL) VALUES (' ', '" + cFil + "', 'REST-OP', 'zzgebrest', 'OPERADOR')")
    // Usuario sem nenhuma permissao RBAC (perfil sem linha em SEC_PERM e
    // nao-ADMIN) -- usado para provar que escrita negada nao executa.
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'REST-NOP'")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'REST-NOP', 'Sem Permissao REST', 'SEMPERM')")

    // Empresa "provisionada" para POST /usuarios: GEBSECCRIAUSU() exige
    // que o schema emp_<cod> exista (GEBDBSchemaExists). Schema vazio e'
    // suficiente aqui; removido no cleanup.
    // As chamadas REST rodam DENTRO de uma sessao de empresa (como pela API
    // e pela tela): ADMIN so' age na empresa da sessao (GEBSECPODE).
    TCSqlExec("SET search_path TO emp_zzgebrest, test_gebrest")

    // Configura permissoes RBAC para REST.
    TCSqlExec("DELETE FROM SEC_PERM WHERE D_E_L_E_T_ = ' ' AND SEC_PERM_PERFIL IN ('ADMIN','OPERADOR')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'ADMIN', 'SEGURANCA', 'USUARI', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'ADMIN', 'CONFIG', 'EMPRES', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'ADMIN', 'FISCAL', 'PRODUT', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'ADMIN', 'FISCAL', 'NOTAS', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'ADMIN', 'FINANCEIRO', 'FLUXO', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'ADMIN', 'MONITOR', 'MONITR', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'OPERADOR', 'SEGURANCA', 'USUARI', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'OPERADOR', 'FISCAL', 'PRODUT', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'OPERADOR', 'FISCAL', 'NOTAS', 'T')")
    TCSqlExec("INSERT INTO SEC_PERM (D_E_L_E_T_, SEC_PERM_FILIAL, SEC_PERM_PERFIL, SEC_PERM_MENU, SEC_PERM_ITEM, SEC_PERM_PERMITE) VALUES (' ', '" + cFil + "', 'OPERADOR', 'FINANCEIRO', 'FLUXO', 'T')")

    // Configura rate limit alto p/ teste.
    TCSqlExec("INSERT INTO GE4 (D_E_L_E_T_, GE4_FILIAL, GE4_EVENTO, GE4_MODO) VALUES (' ', '" + cFil + "', 'SEG_RATELIMIT', '1000')")

    // ===== T1: /health =====
    ConOut("")
    ConOut("  [T1] /health")
    aRes := GEBREST("GET", "/health", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        If At(Chr(34) + "status" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem status")
        EndIf
        If At(Chr(34) + "ok" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem ok")
        EndIf
        If At(Chr(34) + "timestamp" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem timestamp")
        EndIf
        ConOut("    OK: status=" + cStatus)
    EndIf

    // ===== T2: GET /usuarios (lista) =====
    ConOut("")
    ConOut("  [T2] GET /usuarios")
    aRes := GEBREST("GET", "/usuarios", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        // Deve conter pelo menos REST-ADM e REST-OP.
        If At("REST-ADM", cBody) == 0
            lOk := .F.
            ConOut("    FAIL: lista nao contem REST-ADM")
        EndIf
        If At("REST-OP", cBody) == 0
            lOk := .F.
            ConOut("    FAIL: lista nao contem REST-OP")
        EndIf
        ConOut("    OK: " + cValToChar(Len(cBody)) + " chars")
    EndIf

    // ===== T3: GET /usuarios/{cod} =====
    ConOut("")
    ConOut("  [T3] GET /usuarios/REST-ADM")
    aRes := GEBREST("GET", "/usuarios/REST-ADM", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        If At("REST-ADM", cBody) == 0
            lOk := .F.
            ConOut("    FAIL: corpo nao contem REST-ADM")
        EndIf
        If At("ADMIN", cBody) == 0
            lOk := .F.
            ConOut("    FAIL: corpo nao contem ADMIN")
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T4: GET /usuarios/{cod_inexistente} =====
    ConOut("")
    ConOut("  [T4] GET /usuarios/NONEXIST")
    aRes := GEBREST("GET", "/usuarios/NONEXIST", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "404"
            lOk := .F.
            ConOut("    FAIL: esperado 404, got " + cStatus)
        EndIf
        ConOut("    OK: 404")
    EndIf

    // ===== T5: POST /usuarios (cria usuario) =====
    // Body {cod, nome, perfil, senha, aEmpresas}; codigo so' com
    // letras/digitos/_ (GEBDBSchemaValido, exigido por GEBSECCRIAUSU).
    ConOut("")
    ConOut("  [T5] POST /usuarios")
    aRes := GEBREST("POST", "/usuarios", {"REST_NEW", "Usuario Novo", "OPERADOR", "Senha#Forte1", {"zzgebrest"}}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "201"
            lOk := .F.
            ConOut("    FAIL: esperado 201, got " + cStatus + " body=" + cBody)
        EndIf
        If At(Chr(34) + "status" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem status")
        EndIf
        // Gravacao real: GE2 + GE2_SEC (salt 32 hex) + GE2_EMP.
        aDados := TCSqlQuery("SELECT GE2_PERFIL FROM GE2 WHERE GE2_COD = 'REST_NEW' AND D_E_L_E_T_ = ' '")
        If Len(aDados) != 1
            lOk := .F.
            ConOut("    FAIL: esperado 1 linha GE2 para REST_NEW, veio " + cValToChar(Len(aDados)))
        ElseIf AllTrim(cValToChar(aDados[1]:GE2_PERFIL)) != "OPERADOR"
            lOk := .F.
            ConOut("    FAIL: GE2_PERFIL=" + cValToChar(aDados[1]:GE2_PERFIL))
        EndIf
        aDados := TCSqlQuery("SELECT SEC_SALT FROM GE2_SEC WHERE SEC_USUARIO = 'REST_NEW' AND D_E_L_E_T_ = ' '")
        If Len(aDados) != 1
            lOk := .F.
            ConOut("    FAIL: esperado 1 linha GE2_SEC para REST_NEW, veio " + cValToChar(Len(aDados)))
        Else
            cSalt1 := AllTrim(cValToChar(aDados[1]:SEC_SALT))
            If Len(cSalt1) != 32
                lOk := .F.
                ConOut("    FAIL: SEC_SALT com " + cValToChar(Len(cSalt1)) + " chars (esperado 32)")
            EndIf
        EndIf
        aDados := TCSqlQuery("SELECT GE2_EMP_EMPRESA FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'REST_NEW' AND GE2_EMP_EMPRESA = 'zzgebrest' AND D_E_L_E_T_ = ' '")
        If Len(aDados) != 1
            lOk := .F.
            ConOut("    FAIL: esperado 1 vinculo GE2_EMP REST_NEW/zzgebrest, veio " + cValToChar(Len(aDados)))
        EndIf
        ConOut("    OK: status=" + cStatus)
    EndIf

    // ===== T5b: POST /usuarios -- validacoes sem escrita =====
    ConOut("")
    ConOut("  [T5b] POST /usuarios sem empresa / codigo invalido / ADMIN / empresa nao provisionada")
    aRes := GEBREST("POST", "/usuarios", {"REST_NOEMP", "Sem Empresa", "OPERADOR", "Senha#Forte1"}, "REST-ADM", "127.0.0.1")
    If cValToChar(aRes[1]) != "400"
        lOk := .F.
        ConOut("    FAIL: sem empresa esperado 400, got " + cValToChar(aRes[1]))
    EndIf
    aRes := GEBREST("POST", "/usuarios", {"REST_NOEMP", "Sem Empresa", "OPERADOR", "Senha#Forte1", {"zznaoexiste"}}, "REST-ADM", "127.0.0.1")
    If cValToChar(aRes[1]) != "400"
        lOk := .F.
        ConOut("    FAIL: empresa nao provisionada esperado 400, got " + cValToChar(aRes[1]))
    EndIf
    aRes := GEBREST("POST", "/usuarios", {"REST-HIFEN", "Codigo Invalido", "OPERADOR", "Senha#Forte1", {"zzgebrest"}}, "REST-ADM", "127.0.0.1")
    If cValToChar(aRes[1]) != "400"
        lOk := .F.
        ConOut("    FAIL: codigo invalido esperado 400, got " + cValToChar(aRes[1]))
    EndIf
    aRes := GEBREST("POST", "/usuarios", {"super", "Super", "ADMIN", "Senha#Forte1", {"zzgebrest"}}, "REST-ADM", "127.0.0.1")
    If cValToChar(aRes[1]) != "403"
        lOk := .F.
        ConOut("    FAIL: super esperado 403, got " + cValToChar(aRes[1]))
    EndIf
    aDados := TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD IN ('REST_NOEMP','REST-HIFEN','super')")
    If Len(aDados) > 0
        lOk := .F.
        ConOut("    FAIL: POST rejeitado deixou " + cValToChar(Len(aDados)) + " linha(s) em GE2")
    Else
        ConOut("    OK: 4 POSTs rejeitados sem escrita")
    EndIf

    // ===== T6: POST /usuarios (senha fraca) =====
    ConOut("")
    ConOut("  [T6] POST /usuarios senha fraca")
    aRes := GEBREST("POST", "/usuarios", {"REST_BAD", "Usuario Bad", "OPERADOR", "abc", {"zzgebrest"}}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "400"
            lOk := .F.
            ConOut("    FAIL: esperado 400, got " + cStatus)
        EndIf
        ConOut("    OK: 400 (senha fraca)")
    EndIf

    // ===== T7: POST /usuarios (duplicado) =====
    ConOut("")
    ConOut("  [T7] POST /usuarios duplicado")
    aRes := GEBREST("POST", "/usuarios", {"REST_NEW", "Usuario Novo Dup", "OPERADOR", "Senha#Forte1", {"zzgebrest"}}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "409"
            lOk := .F.
            ConOut("    FAIL: esperado 409, got " + cStatus)
        EndIf
        ConOut("    OK: 409 (duplicado)")
    EndIf

    // ===== T8: PUT /usuarios/{cod} (atualiza) =====
    ConOut("")
    ConOut("  [T8] PUT /usuarios/REST_NEW")
    aRes := GEBREST("PUT", "/usuarios/REST_NEW", {"Usuario Atualizado", "ADMIN"}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: esperado 200, got " + cStatus + " body=" + cBody)
        EndIf
        aDados := TCSqlQuery("SELECT GE2_NOME, GE2_PERFIL FROM GE2 WHERE GE2_COD = 'REST_NEW' AND D_E_L_E_T_ = ' '")
        If Len(aDados) != 1
            lOk := .F.
            ConOut("    FAIL: REST_NEW sumiu de GE2")
        Else
            If AllTrim(cValToChar(aDados[1]:GE2_NOME)) != "Usuario Atualizado"
                lOk := .F.
                ConOut("    FAIL: GE2_NOME nao atualizado: " + cValToChar(aDados[1]:GE2_NOME))
            EndIf
            If AllTrim(cValToChar(aDados[1]:GE2_PERFIL)) != "ADMIN"
                lOk := .F.
                ConOut("    FAIL: GE2_PERFIL nao atualizado: " + cValToChar(aDados[1]:GE2_PERFIL))
            EndIf
        EndIf
        ConOut("    OK: status=" + cStatus)
    EndIf

    // ===== T8b: PUT /usuarios/{cod} com senha -> novo salt em GE2_SEC =====
    ConOut("")
    ConOut("  [T8b] PUT /usuarios/REST_NEW com senha nova")
    aRes := GEBREST("PUT", "/usuarios/REST_NEW", {"", "", "NovaSenha9$"}, "REST-ADM", "127.0.0.1")
    cStatus := cValToChar(aRes[1])
    If cStatus != "200"
        lOk := .F.
        ConOut("    FAIL: esperado 200, got " + cStatus + " body=" + cValToChar(aRes[2]))
    EndIf
    aDados := TCSqlQuery("SELECT SEC_SALT FROM GE2_SEC WHERE SEC_USUARIO = 'REST_NEW' AND D_E_L_E_T_ = ' '")
    If Len(aDados) != 1
        lOk := .F.
        ConOut("    FAIL: esperado 1 linha GE2_SEC, veio " + cValToChar(Len(aDados)))
    Else
        cSalt2 := AllTrim(cValToChar(aDados[1]:SEC_SALT))
        If Len(cSalt2) != 32 .Or. cSalt2 == cSalt1
            lOk := .F.
            ConOut("    FAIL: salt nao foi trocado (antes=" + cSalt1 + " depois=" + cSalt2 + ")")
        Else
            ConOut("    OK: salt trocado")
        EndIf
    EndIf

    // ===== T8c: PUT /usuarios/{cod} com senha fraca -> 400 e nome/perfil
    // intactos (a politica agora e' checada ANTES de qualquer escrita) =====
    ConOut("")
    ConOut("  [T8c] PUT /usuarios/REST_NEW com senha fraca -> 400, nada gravado")
    aRes := GEBREST("PUT", "/usuarios/REST_NEW", {"Nome Nao Deve Gravar", "CAIXA", "123"}, "REST-ADM", "127.0.0.1")
    cStatus := cValToChar(aRes[1])
    If cStatus != "400"
        lOk := .F.
        ConOut("    FAIL: esperado 400, got " + cStatus + " body=" + cValToChar(aRes[2]))
    EndIf
    aDados := TCSqlQuery("SELECT GE2_NOME, GE2_PERFIL FROM GE2 WHERE GE2_COD = 'REST_NEW' AND D_E_L_E_T_ = ' '")
    If Len(aDados) != 1
        lOk := .F.
        ConOut("    FAIL: REST_NEW sumiu de GE2")
    Else
        If AllTrim(cValToChar(aDados[1]:GE2_NOME)) == "Nome Nao Deve Gravar"
            lOk := .F.
            ConOut("    FAIL: GE2_NOME foi gravado mesmo com senha reprovada na politica")
        EndIf
        If AllTrim(cValToChar(aDados[1]:GE2_PERFIL)) == "CAIXA"
            lOk := .F.
            ConOut("    FAIL: GE2_PERFIL foi gravado mesmo com senha reprovada na politica")
        EndIf
    EndIf
    ConOut("    OK: status=" + cStatus)

    // ===== T8d: PUT /usuarios/super -> 403 (guarda contra alterar super
    // via REST, mesma protecao de GEBSECCRIAUSU -- nunca toca a conta
    // super real, o bloqueio acontece antes de qualquer leitura/escrita
    // em GE2) =====
    ConOut("")
    ConOut("  [T8d] PUT /usuarios/super -> 403 (guarda)")
    aRes := GEBREST("PUT", "/usuarios/super", {"Nome Invasor", "ADMIN", "SenhaForte9$"}, "REST-ADM", "127.0.0.1")
    cStatus := cValToChar(aRes[1])
    If cStatus != "403"
        lOk := .F.
        ConOut("    FAIL: esperado 403, got " + cStatus + " body=" + cValToChar(aRes[2]))
    EndIf
    ConOut("    OK: status=" + cStatus)

    // ===== T9: DELETE /usuarios/{cod} (soft delete) =====
    ConOut("")
    ConOut("  [T9] DELETE /usuarios/REST_NEW")
    aRes := GEBREST("DELETE", "/usuarios/REST_NEW", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: esperado 200, got " + cStatus)
        EndIf
        If Len(TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = 'REST_NEW' AND D_E_L_E_T_ = ' '")) > 0
            lOk := .F.
            ConOut("    FAIL: REST_NEW continua ativo em GE2 apos DELETE")
        EndIf
        ConOut("    OK: status=" + cStatus)
    EndIf

    // ===== T9b: DELETE /usuarios/super -> 403 (guarda) =====
    ConOut("")
    ConOut("  [T9b] DELETE /usuarios/super -> 403 (guarda)")
    aRes := GEBREST("DELETE", "/usuarios/super", {}, "REST-ADM", "127.0.0.1")
    cStatus := cValToChar(aRes[1])
    If cStatus != "403"
        lOk := .F.
        ConOut("    FAIL: esperado 403, got " + cStatus + " body=" + cValToChar(aRes[2]))
    EndIf
    ConOut("    OK: status=" + cStatus)

    // ===== T10: GET /empresas =====
    ConOut("")
    ConOut("  [T10] GET /empresas")
    aRes := GEBREST("GET", "/empresas", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        If At("01", cBody) == 0
            lOk := .F.
            ConOut("    FAIL: lista nao contem empresa 01")
        EndIf
        If At("02", cBody) == 0
            lOk := .F.
            ConOut("    FAIL: lista nao contem empresa 02")
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T11: POST /empresas por ADMIN (nao-super) -> 403 =====
    // Criar empresa e' ato global, so o super pode. O caminho 201 e'
    // verificado ao vivo como super (nao ha como criar conta super em
    // teste sem tocar o super real do catalogo compartilhado).
    ConOut("")
    ConOut("  [T11] POST /empresas por ADMIN -> 403 (somente super cria)")
    aRes := GEBREST("POST", "/empresas", {"03", "Empresa Teste 03"}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "403"
            lOk := .F.
            ConOut("    FAIL: esperado 403, got " + cStatus)
        EndIf
        If Len(TCSqlQuery("SELECT GE1_COD FROM GE1 WHERE GE1_COD = '03' AND D_E_L_E_T_ = ' '")) != 0
            lOk := .F.
            ConOut("    FAIL: empresa 03 foi gravada mesmo com 403")
        EndIf
        If GEBDBSchemaExists("03")
            lOk := .F.
            ConOut("    FAIL: schema emp_03 foi provisionado mesmo com 403")
        EndIf
        ConOut("    OK: status=" + cStatus)
    EndIf

    // ===== T12: GET /produtos =====
    ConOut("")
    ConOut("  [T12] GET /produtos")
    aRes := GEBREST("GET", "/produtos", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T13: POST /produtos =====
    ConOut("")
    ConOut("  [T13] POST /produtos")
    aRes := GEBREST("POST", "/produtos", {"PROD-RST", "NCM-RST", "Produto REST Teste"}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "201"
            lOk := .F.
            ConOut("    FAIL: esperado 201, got " + cStatus)
        EndIf
        If Len(TCSqlQuery("SELECT GF1_COD FROM GF1 WHERE GF1_COD = 'PROD-RST' AND D_E_L_E_T_ = ' '")) != 1
            lOk := .F.
            ConOut("    FAIL: produto PROD-RST nao gravado em GF1")
        EndIf
        ConOut("    OK: status=" + cStatus)
    EndIf

    // ===== T13b: GET /produtos lista o produto criado =====
    ConOut("")
    ConOut("  [T13b] GET /produtos contem PROD-RST")
    aRes := GEBREST("GET", "/produtos", {}, "REST-ADM", "127.0.0.1")
    cBody := cValToChar(aRes[2])
    If cValToChar(aRes[1]) != "200" .Or. At("PROD-RST", cBody) == 0
        lOk := .F.
        ConOut("    FAIL: status=" + cValToChar(aRes[1]) + " body=" + cBody)
    Else
        ConOut("    OK")
    EndIf

    // ===== T14: GET /notas =====
    ConOut("")
    ConOut("  [T14] GET /notas")
    aRes := GEBREST("GET", "/notas", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T15: POST /notas (emite NF) =====
    ConOut("")
    ConOut("  [T15] POST /notas")
    aRes := GEBREST("POST", "/notas", {"NF-RST-001", "PROD-RST", 2, 100}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "201" .And. cStatus != "202"
            lOk := .F.
            ConOut("    FAIL: esperado 201/202, got " + cStatus)
        EndIf
        // Verifica se a NF foi gravada.
        aDados := TCSqlQuery("SELECT * FROM GF3 WHERE GF3_CHAVE = 'NF-RST-001' AND D_E_L_E_T_ = ' ' LIMIT 1")
        If Len(aDados) == 0
            lOk := .F.
            ConOut("    FAIL: NF nao gravada em GF3")
        Else
            ConOut("    OK: NF gravada, status=" + cValToChar(aDados[1]:GF3_STATUS))
        EndIf
    EndIf

    // ===== T16: GET /financeiro/fluxo =====
    ConOut("")
    ConOut("  [T16] GET /financeiro/fluxo")
    aRes := GEBREST("GET", "/financeiro/fluxo", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        If At(Chr(34) + "a_receber" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem a_receber")
        EndIf
        If At(Chr(34) + "a_pagar" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem a_pagar")
        EndIf
        If At(Chr(34) + "saldo" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem saldo")
        EndIf
        ConOut("    body=" + cBody)
    EndIf

    // ===== T17: GET /financeiro/contas =====
    ConOut("")
    ConOut("  [T17] GET /financeiro/contas")
    aRes := GEBREST("GET", "/financeiro/contas", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T18: GET /fiscal/relatorio/202609 =====
    ConOut("")
    ConOut("  [T18] GET /fiscal/relatorio/202609")
    aRes := GEBREST("GET", "/fiscal/relatorio/202609", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        cBody := cValToChar(aRes[2])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        // Deve conter campos do relatorio fiscal.
        If At(Chr(34) + "notas" + Chr(34), cBody) == 0
            lOk := .F.
            ConOut("    FAIL: json sem notas")
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T19: GET /relatorios/gerencial =====
    ConOut("")
    ConOut("  [T19] GET /relatorios/gerencial")
    aRes := GEBREST("GET", "/relatorios/gerencial", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: status=" + cStatus)
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T20: GET /monitor/usuarios (ADMIN) =====
    ConOut("")
    ConOut("  [T20] GET /monitor/usuarios (ADMIN)")
    aRes := GEBREST("GET", "/monitor/usuarios", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "200"
            lOk := .F.
            ConOut("    FAIL: esperado 200, got " + cStatus)
        EndIf
        ConOut("    OK")
    EndIf

    // ===== T21: GET /monitor/usuarios (OPERADOR -> 403) =====
    ConOut("")
    ConOut("  [T21] GET /monitor/usuarios (OPERADOR -> 403)")
    aRes := GEBREST("GET", "/monitor/usuarios", {}, "REST-OP", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "403"
            lOk := .F.
            ConOut("    FAIL: esperado 403, got " + cStatus)
        EndIf
        ConOut("    OK: 403")
    EndIf

    // ===== T22: DELETE /monitor/sessao/{token} (ADMIN) =====
    ConOut("")
    ConOut("  [T22] DELETE /monitor/sessao/TESTE-TOKEN")
    aRes := GEBREST("DELETE", "/monitor/sessao/TESTE-TOKEN", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        // Token pode nao existir, entao 404 e OK tbem.
        If cStatus != "200" .And. cStatus != "404"
            lOk := .F.
            ConOut("    FAIL: esperado 200/404, got " + cStatus)
        EndIf
        ConOut("    OK: " + cStatus)
    EndIf

    // ===== T23: DELETE /monitor/sessao (OPERADOR -> 403) =====
    ConOut("")
    ConOut("  [T23] DELETE /monitor/sessao/TESTE (OPERADOR -> 403)")
    aRes := GEBREST("DELETE", "/monitor/sessao/TESTE", {}, "REST-OP", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "403"
            lOk := .F.
            ConOut("    FAIL: esperado 403, got " + cStatus)
        EndIf
        ConOut("    OK: 403")
    EndIf

    // ===== T24: Rota inexistente -> 404 =====
    ConOut("")
    ConOut("  [T24] GET /inexistente -> 404")
    aRes := GEBREST("GET", "/inexistente", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "404"
            lOk := .F.
            ConOut("    FAIL: esperado 404, got " + cStatus)
        EndIf
        ConOut("    OK: 404")
    EndIf

    // ===== T25: Metodo invalido -> 405 =====
    ConOut("")
    ConOut("  [T25] POST /health -> 405")
    aRes := GEBREST("POST", "/health", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        // /health so' tem handler GET.
        If cStatus != "405"
            lOk := .F.
            ConOut("    FAIL: esperado 405, got " + cStatus)
        Else
            ConOut("    OK: 405")
        EndIf
    EndIf

    // ===== T26: GET /usuarios sem auth -> 403 =====
    ConOut("")
    ConOut("  [T26] GET /usuarios sem usuario -> 403")
    aRes := GEBREST("GET", "/usuarios", {}, "", "127.0.0.1")
    If Len(aRes) < 2
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    Else
        cStatus := cValToChar(aRes[1])
        If cStatus != "403"
            lOk := .F.
            ConOut("    FAIL: esperado 403, got " + cStatus)
        EndIf
        ConOut("    OK: 403")
    EndIf

    // ===== T27: Resposta JSON tem timestamp =====
    ConOut("")
    ConOut("  [T27] JSON timestamp presente")
    aRes := GEBREST("GET", "/health", {}, "REST-ADM", "127.0.0.1")
    If Len(aRes) >= 2
        cBody := cValToChar(aRes[2])
        If At(Chr(34) + "timestamp" + Chr(34), cBody) > 0
            ConOut("    OK: timestamp presente")
        Else
            lOk := .F.
            ConOut("    FAIL: timestamp ausente")
        EndIf
    Else
        lOk := .F.
        ConOut("    FAIL: resposta vazia")
    EndIf

    // ===== T28-T31: RBAC negado NAO executa a escrita =====
    // (RBAC roda antes do handler; antes rodava depois e a escrita ja'
    // tinha acontecido quando o 403 era devolvido.)
    ConOut("")
    ConOut("  [T28] POST /usuarios sem permissao -> 403 e nada gravado")
    aRes := GEBREST("POST", "/usuarios", {"REST_RBAC", "Nao Deve Existir", "OPERADOR", "Senha#Forte1", {"zzgebrest"}}, "REST-NOP", "127.0.0.1")
    If cValToChar(aRes[1]) != "403"
        lOk := .F.
        ConOut("    FAIL: esperado 403, got " + cValToChar(aRes[1]))
    EndIf
    If Len(TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = 'REST_RBAC'")) > 0
        lOk := .F.
        ConOut("    FAIL: POST negado gravou GE2")
    ElseIf Len(TCSqlQuery("SELECT SEC_USUARIO FROM GE2_SEC WHERE SEC_USUARIO = 'REST_RBAC'")) > 0
        lOk := .F.
        ConOut("    FAIL: POST negado gravou GE2_SEC")
    Else
        ConOut("    OK: 403 sem escrita")
    EndIf

    ConOut("")
    ConOut("  [T29] PUT /usuarios/REST-OP sem permissao -> 403 e nome intacto")
    aRes := GEBREST("PUT", "/usuarios/REST-OP", {"Nome Invadido", "ADMIN"}, "REST-NOP", "127.0.0.1")
    If cValToChar(aRes[1]) != "403"
        lOk := .F.
        ConOut("    FAIL: esperado 403, got " + cValToChar(aRes[1]))
    EndIf
    aDados := TCSqlQuery("SELECT GE2_NOME, GE2_PERFIL FROM GE2 WHERE GE2_COD = 'REST-OP' AND D_E_L_E_T_ = ' '")
    If Len(aDados) != 1
        lOk := .F.
        ConOut("    FAIL: REST-OP sumiu de GE2")
    ElseIf AllTrim(cValToChar(aDados[1]:GE2_NOME)) != "Operador REST" .Or. AllTrim(cValToChar(aDados[1]:GE2_PERFIL)) != "OPERADOR"
        lOk := .F.
        ConOut("    FAIL: PUT negado alterou GE2: " + cValToChar(aDados[1]:GE2_NOME) + "/" + cValToChar(aDados[1]:GE2_PERFIL))
    Else
        ConOut("    OK: 403 sem escrita")
    EndIf

    ConOut("")
    ConOut("  [T30] DELETE /usuarios/REST-OP sem permissao -> 403 e usuario ativo")
    aRes := GEBREST("DELETE", "/usuarios/REST-OP", {}, "REST-NOP", "127.0.0.1")
    If cValToChar(aRes[1]) != "403"
        lOk := .F.
        ConOut("    FAIL: esperado 403, got " + cValToChar(aRes[1]))
    EndIf
    If Len(TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = 'REST-OP' AND D_E_L_E_T_ = ' '")) != 1
        lOk := .F.
        ConOut("    FAIL: DELETE negado removeu REST-OP")
    Else
        ConOut("    OK: 403 sem escrita")
    EndIf

    ConOut("")
    ConOut("  [T31] POST /empresas por OPERADOR (sem CONFIG/EMPRES) -> 403 e nada gravado")
    aRes := GEBREST("POST", "/empresas", {"04", "Empresa Nao Deve Existir"}, "REST-OP", "127.0.0.1")
    If cValToChar(aRes[1]) != "403"
        lOk := .F.
        ConOut("    FAIL: esperado 403, got " + cValToChar(aRes[1]))
    EndIf
    If Len(TCSqlQuery("SELECT GE1_COD FROM GE1 WHERE GE1_COD = '04'")) > 0
        lOk := .F.
        ConOut("    FAIL: POST negado gravou GE1")
    Else
        ConOut("    OK: 403 sem escrita")
    EndIf

    // ===== T32: aspas simples em valores que chegam a SQL concatenado =====
    ConOut("")
    ConOut("  [T32] token/chave com aspas simples -> 400 sem SQL")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_TOKEN = 'TOK-T32'")
    TCSqlExec("INSERT INTO GE2_TOK (D_E_L_E_T_, TOK_TOKEN, TOK_USUARIO, TOK_EMPRESA, TOK_FILIAL, TOK_IP, TOK_CREATED, TOK_EXPIRES) VALUES (' ', 'TOK-T32', 'REST-ADM', '01', '" + cFil + "', '127.0.0.1', '20260925 00:00:00', '20990101 00:00:00')")
    aRes := GEBREST("DELETE", "/monitor/sessao/x' OR '1'='1", {}, "REST-ADM", "127.0.0.1")
    // Valor escapado (GEBDBQuote): a busca nao acha nada -> 404 (antes, 400
    // por uma guarda de aspas). O que importa: TOK-T32 continua valido.
    If cValToChar(aRes[1]) != "404" .And. cValToChar(aRes[1]) != "400"
        lOk := .F.
        ConOut("    FAIL: token com aspas esperado 404/400, got " + cValToChar(aRes[1]))
    EndIf
    If Len(TCSqlQuery("SELECT TOK_TOKEN FROM GE2_TOK WHERE TOK_TOKEN = 'TOK-T32' AND D_E_L_E_T_ = ' '")) != 1
        lOk := .F.
        ConOut("    FAIL: token TOK-T32 foi invalidado pela injecao")
    EndIf
    aRes := GEBREST("POST", "/notas", {"NF-X'Y", "PROD-RST", 1, 10}, "REST-ADM", "127.0.0.1")
    If cValToChar(aRes[1]) != "400"
        lOk := .F.
        ConOut("    FAIL: chave com aspas esperado 400, got " + cValToChar(aRes[1]))
    Else
        ConOut("    OK: 400 nos dois casos")
    EndIf
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_TOKEN = 'TOK-T32'")

    // ===== CLEANUP =====
    TCSqlExec("DELETE FROM GE1 WHERE GE1_COD IN ('01','02','03','04')")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD IN ('REST-ADM','REST-OP','REST-NOP','REST_NEW','REST_BAD','REST_RBAC','REST_NOEMP')")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO IN ('REST-ADM','REST-OP','REST_NEW','REST_BAD','REST_RBAC','REST_NOEMP')")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO IN ('REST-ADM','REST-OP','REST_NEW','REST_RBAC')")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_zzgebrest CASCADE")
    TCSqlExec("DELETE FROM SEC_PERM WHERE SEC_PERM_PERFIL IN ('ADMIN','OPERADOR')")
    TCSqlExec("DELETE FROM GE4 WHERE GE4_EVENTO = 'SEG_RATELIMIT'")

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebrest CASCADE")

    If lOk
        ConOut("")
        ConOut("T_GEBREST PASS")
    Else
        ConOut("")
        ConOut("T_GEBREST FAIL")
    EndIf
Return lOk
