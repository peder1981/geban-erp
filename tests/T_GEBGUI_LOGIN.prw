#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBEXP_MIG.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GEBPERIF_MIG.prw"
#include "../src/GEBFIL_MIG.prw"
#include "../src/GEBUNI_MIG.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBSEC_TOKEN.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBGUI_LOGIN.prw"

/*/{Protheus.doc} T_GEBGUI_LOGIN
    Teste da tela de login GEBGUI_LOGIN. Schema descartavel
    test_gebgui_login.
    Alem de GEBSECLOGIN() direto, exercita GEBGUI_LOGIN() em modo
    automatico (lSkipDash = .T.): com vinculo GE2_EMP para a empresa
    pedida -> .T. e token emitido; empresa SEM vinculo GE2_EMP -> .F. e
    nenhum token; vinculo GE2_EMP com FILIAL divergente da filial real
    do usuario -> .F. e nenhum token (Task 2, plano fase2-gaps,
    2026-09-25 -- GEBGUIVINC() agora tambem filtra por GE2_EMP_FILIAL);
    empresa com injecao SQL -> .F. e nenhum token (antes da correcao da
    revisao final, GEBGUI_LOGIN emitia token para qualquer empresa, sem
    checar vinculo nem formato).
    @type Teste automatizado
    @author Peder Munksgaard
    @since 23/09/2026
/*/
User Function T_GEBGUI_LOGIN()
    Local lOk := .T.
    Local cRes := ""
    Local cFil := ""
    Local nTok := 0

    If !GEBDBConecta()
        ConOut("T_GEBGUI_LOGIN: FALHA GEBDBConecta")
        Return .F.
    EndIf
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_login CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebgui_login")
    TCSqlExec("SET search_path TO test_gebgui_login")

    If !GEBDBProvisionaCatalogo()
        lOk := .F.
    EndIf
    GBAUDINIC()

    // GEBSECLOGIN() grava um registro de auditoria em GEH em caso de
    // login bem-sucedido (src/GEBSEC_LOGIN.prw:124). GEH normalmente e'
    // criada por GEBDBProvisionaEmpresa() dentro do schema emp_<cod>,
    // mas provisionar uma empresa inteira so para este teste de login
    // adicionaria escopo (GENMIGEmpresa + todos os *_MIG de negocio).
    // GEBEXPCriaAuditoria() ja e' chamada isoladamente do mesmo jeito
    // em tests/T_GEBAUD.prw, entao repetimos o padrao aqui.
    //
    // GEBDBProvisionaCatalogo() forca "SET search_path TO public" antes
    // de retornar (Global Constraint #3 do plano: GEBEXPCriaAuditoria()
    // deve rodar depois que um schema de tenant for selecionado, nunca
    // sob "public"). Reseleciona o schema descartavel deste teste antes
    // de criar GEH/GEI, para que fiquem em test_gebgui_login (limpas
    // pelo DROP SCHEMA no fim) e nao em public (compartilhado).
    TCSqlExec("SET search_path TO test_gebgui_login, public")
    GEBEXPCriaAuditoria()

    // Seed usuario de teste em GE2/GE2_SEC: schema descartavel recem-criado
    // nao tem nenhuma linha de GE2/GE2_SEC, e GEBSECLOGIN() so autentica
    // contra essas duas tabelas. Sem esse seed o teste so exercitaria o
    // caminho "usuario inexistente" (GEBSECLOGIN retorna "USU_INEX"),
    // nunca o login bem-sucedido. Hash calculado com o mesmo algoritmo
    // Argon2id(cSenha, cSalt) usado por GEBSEC_LOGIN.prw (senha
    // "admin123", salt "SALT1"), hex-encoded.
    // GE2/GE2_SEC sao tabelas de catalogo (schema "public", nao o schema
    // descartavel deste teste -- GEBDBProvisionaCatalogo() forca
    // "SET search_path TO public"), entao sobrevivem entre execucoes.
    // Usa codigo T_LOGIN_ADM (nao ADMIN) para nao sobrescrever/destruir
    // um cadastro ADMIN real do catalogo compartilhado: limpa antes de
    // inserir para nao acumular linhas duplicadas a cada rodada (mesmo
    // padrao de tests/T_GEBREST.prw), e limpa de novo no teardown para
    // nao deixar rastro no catalogo compartilhado.
    cFil := FWxFilial("GE2")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = 'T_LOGIN_ADM'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_LOGIN_ADM'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE D_E_L_E_T_ = ' ' AND SEC_USUARIO = 'T_LOGIN_ADM'")
    TCSqlExec("DELETE FROM GE2 WHERE D_E_L_E_T_ = ' ' AND GE2_COD = 'T_LOGIN_ADM'")
    TCSqlExec("INSERT INTO GE2 (D_E_L_E_T_, GE2_FILIAL, GE2_COD, GE2_NOME, GE2_PERFIL) VALUES (' ', '" + cFil + "', 'T_LOGIN_ADM', 'Administrador Teste', 'ADMIN')")
    TCSqlExec("INSERT INTO GE2_SEC (D_E_L_E_T_, SEC_FILIAL, SEC_USUARIO, SEC_SALT, SEC_HASH, SEC_FAILCNT, SEC_LOCKED, SEC_LASTLOGIN, SEC_PWDLAST) VALUES (' ', '" + cFil + "', 'T_LOGIN_ADM', 'SALT1', '19f9c341cf1011dc2ce3567e8e672652e8a2df0db1b98f762b051b120e528fbdc28684761455263d2ea93a5eb69c949a1a3db47ece25ca4b9184e0c1c07b99f89a590c722f7f357b793a9e51f9f7e5f4108d9da4b3ea8f18902341642e0524a8bb88ea9083945dfb9cfa8618fa75a204c377818bb6254d15f5abd6900abf7857', 0, '00000000', '00000000', '" + DToS(Date()) + "')")

    // Test login function directly (not the GUI)
    If lOk
        cRes := GEBSECLOGIN("T_LOGIN_ADM", "admin123", "127.0.0.1")
        If cRes != "OK"
            ConOut("T_GEBGUI_LOGIN: login falhou, status=" + cRes)
            lOk := .F.
        EndIf
    EndIf

    // GEBGUI_LOGIN() chama TCSecMIG(), que cria tabelas no PRIMEIRO
    // schema do search_path -- volta para public (onde vive o catalogo)
    // antes, senao criaria GE2_SEC vazia no schema descartavel e
    // GEBSECLOGIN() nao acharia a credencial semeada.
    TCSqlExec("SET search_path TO public")
    TCSqlExec("INSERT INTO GE2_EMP (D_E_L_E_T_, GE2_EMP_FILIAL, GE2_EMP_USUARIO, GE2_EMP_EMPRESA) VALUES (' ', '" + cFil + "', 'T_LOGIN_ADM', 'zzguivinc')")


    // Positivo: usuario vinculado a empresa pedida -> login + token.
    If lOk
        If !GEBGUI_LOGIN("T_LOGIN_ADM", "admin123", "zzguivinc", "127.0.0.1", .T.)
            ConOut("T_GEBGUI_LOGIN: GEBGUI_LOGIN recusou usuario vinculado (esperado .T.)")
            lOk := .F.
        EndIf
        nTok := Len(TCSqlQuery("SELECT TOK_TOKEN FROM GE2_TOK WHERE TOK_USUARIO = 'T_LOGIN_ADM' AND TOK_EMPRESA = 'zzguivinc' AND D_E_L_E_T_ = ' '"))
        If nTok != 1
            ConOut("T_GEBGUI_LOGIN: esperado 1 token para zzguivinc, veio " + cValToChar(nTok))
            lOk := .F.
        EndIf
    EndIf

    // Negativo: senha certa, mas SEM vinculo GE2_EMP com a empresa pedida.
    If lOk
        If GEBGUI_LOGIN("T_LOGIN_ADM", "admin123", "zzguisemvinc", "127.0.0.1", .T.)
            ConOut("T_GEBGUI_LOGIN: GEBGUI_LOGIN aceitou empresa sem vinculo GE2_EMP")
            lOk := .F.
        EndIf
        nTok := Len(TCSqlQuery("SELECT TOK_TOKEN FROM GE2_TOK WHERE TOK_USUARIO = 'T_LOGIN_ADM' AND TOK_EMPRESA = 'zzguisemvinc'"))
        If nTok != 0
            ConOut("T_GEBGUI_LOGIN: token emitido para empresa sem vinculo")
            lOk := .F.
        EndIf
    EndIf

    // Filial nao faz parte da regra de vinculo (vinculo e' usuario x empresa; ver
    // documentacao interna). Negativo antigo removido.

    // Negativo: empresa com injecao SQL (antes casaria qualquer vinculo).
    If lOk
        If GEBGUI_LOGIN("T_LOGIN_ADM", "admin123", "zz' OR '1'='1", "127.0.0.1", .T.)
            ConOut("T_GEBGUI_LOGIN: GEBGUI_LOGIN aceitou empresa com injecao SQL")
            lOk := .F.
        EndIf
        nTok := Len(TCSqlQuery("SELECT TOK_TOKEN FROM GE2_TOK WHERE TOK_USUARIO = 'T_LOGIN_ADM'"))
        If nTok != 1
            ConOut("T_GEBGUI_LOGIN: esperado so' o token do login vinculado, veio " + cValToChar(nTok))
            lOk := .F.
        EndIf
    EndIf
    If lOk
        ConOut("T_GEBGUI_LOGIN: GEBGUI_LOGIN vinculado OK, sem vinculo e injecao recusados")
    EndIf

    // Teardown: remove o usuario de teste do catalogo compartilhado (nao
    // e' apagado pelo DROP SCHEMA abaixo, pois GE2/GE2_SEC vivem em
    // "public") antes de descartar o schema deste teste.
    TCSqlExec("SET search_path TO public")
    TCSqlExec("DELETE FROM GE2_TOK WHERE TOK_USUARIO = 'T_LOGIN_ADM'")
    TCSqlExec("DELETE FROM GE2_EMP WHERE GE2_EMP_USUARIO = 'T_LOGIN_ADM'")
    TCSqlExec("DELETE FROM GE2_SEC WHERE SEC_USUARIO = 'T_LOGIN_ADM'")
    TCSqlExec("DELETE FROM GE2 WHERE GE2_COD = 'T_LOGIN_ADM'")

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebgui_login CASCADE")

    If lOk
        ConOut("T_GEBGUI_LOGIN PASS")
    Else
        ConOut("T_GEBGUI_LOGIN FAIL")
    EndIf
Return lOk
