#include "totvs.ch"
#include "../src/GEBDB_CORE.prw"
#include "../src/GEBDB_TENANT.prw"
#include "../src/GENUC_MIG.prw"
#include "../src/_init.prw"
#include "../src/GEBMON.prw"
#include "../src/GEBSEC_MIG.prw"
#include "../src/GEBAUD.prw"
#include "../src/GEBSEC_POL.prw"
#include "../src/GEBSEC_RBA.prw"
#include "../src/GEBSEC_LOGIN.prw"
#include "../src/GEBSEC_CICLO.prw"

/*/{Protheus.doc} T_GEBSEC_CICLO
    Ciclo de vida do usuario (src/GEBSEC_CICLO.prw): bloqueio, validade, troca obrigatoria,
    expiracao de senha, conta de servico, eliminar acessos, excluir.
    Schema descartavel test_gebsec_cic + emp_tst (tenant).
    @type Teste automatizado
    @since 07/11/2026
    @return .T. se todos os asserts passarem
/*/
User Function T_GEBSEC_CICLO()
    Local lOk    := .T.
    Local lTmp   := .F.
    Local cSenha := "Ab3$qmv9Qw"
    Local aRes   := {}

    lTmp := GEBDBConecta()
    If !lTmp
        ConOut("FALHA: GEBDBConecta")
        Return .F.
    EndIf

    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_cic CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tst CASCADE")
    TCSqlExec("CREATE SCHEMA test_gebsec_cic")
    TCSqlExec("SET search_path TO test_gebsec_cic")
    If !TEST_INIT()
        ConOut("TEST_INIT failed")
        Return .F.
    EndIf
    ConOut("=== T_GEBSEC_CICLO ===")

    lTmp := GENMIG()
    lOk := lOk .And. lTmp
    lTmp := TCSecMIG()
    lOk := lOk .And. lTmp

    // Empresa de teste e usuarios.
    TCSqlExec("CREATE SCHEMA emp_tst")
    TCSqlExec("SET search_path TO emp_tst, test_gebsec_cic")
    lOk := Chk(GEBSECCRIAUSU("t_usu", cSenha, {"tst"}, "Usuario", "USUARIO", .F., "01"), "cria t_usu vinculado a tst", lOk)
    lOk := Chk(GEBSECCRIAUSU("t_adm", cSenha, {"tst"}, "Admin", "ADMIN", .F., "01"), "cria t_adm ADMIN de tst", lOk)
    lOk := Chk(GEBSECCRIAUSU("u_nunca", cSenha, {"tst"}, "Nunca Acessou", "USUARIO", .F., "01"), "cria u_nunca (nunca acessou)", lOk)
    Chk(GEBSECISSUPER("super"), "conta super reconhecida", lOk)

    // 1. Login normal.
    lOk := Chk(GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "login normal = OK", lOk)

    // 2. Bloqueio pelo super: senha certa -> USU_BLOQ; senha errada continua SENHA_ERR.
    aRes := GEBSECBLOQUEIA("super", "t_usu", .T.)
    lOk := Chk(aRes[1], "super bloqueia t_usu", lOk)
    lOk := Chk(GEBSECLOGIN("t_usu", cSenha, "test") == "USU_BLOQ", "bloqueado + senha certa = USU_BLOQ", lOk)
    lOk := Chk(GEBSECLOGIN("t_usu", "errada", "test") == "SENHA_ERR", "bloqueado + senha errada = SENHA_ERR (sem oraculo)", lOk)

    // 3. Desbloqueio.
    aRes := GEBSECBLOQUEIA("super", "t_usu", .F.)
    lOk := Chk(aRes[1] .And. GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "desbloqueio volta a entrar", lOk)

    // 4. Conta super nao bloqueia; admin nao bloqueia (so' o super).
    aRes := GEBSECBLOQUEIA("super", "super", .T.)
    lOk := Chk(!aRes[1], "conta super nao e' bloqueavel", lOk)
    aRes := GEBSECBLOQUEIA("t_adm", "t_usu", .T.)
    lOk := Chk(!aRes[1], "admin nao bloqueia usuario", lOk)

    // 5. Validade vencida bloqueia; limpar a validade libera.
    aRes := GEBSECVALIDADE("super", "t_usu", "20200101")
    lOk := Chk(aRes[1] .And. GEBSECLOGIN("t_usu", cSenha, "test") == "USU_BLOQ", "validade vencida = USU_BLOQ", lOk)
    aRes := GEBSECVALIDADE("super", "t_usu", "")
    lOk := Chk(aRes[1] .And. GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "validade limpa volta a entrar", lOk)
    aRes := GEBSECVALIDADE("super", "t_usu", "2020-01-01")
    lOk := Chk(!aRes[1], "validade em formato invalido recusada", lOk)

    // 6. Troca obrigatoria no proximo logon; redefinir a senha limpa o flag.
    aRes := GEBSECFORCATROCA("super", "t_usu", .T.)
    lOk := Chk(aRes[1] .And. GEBSECLOGIN("t_usu", cSenha, "test") == "TROCA_OBRIGATORIA", "troca obrigatoria bloqueia o logon", lOk)
    lOk := Chk(GEBSECCRIAUSU("t_usu", cSenha, {"tst"}, "Usuario", "USUARIO", .F., "01") .And. GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "redefinir senha limpa a troca obrigatoria", lOk)

    // 7. Expiracao da senha (90 dias) e excecao de conta de servico.
    TCSqlExec("UPDATE GE2_SEC SET SEC_PWDLAST = '20200101' WHERE SEC_USUARIO = 't_usu'")
    lOk := Chk(GEBSECLOGIN("t_usu", cSenha, "test") == "SENHA_EXP", "senha antiga = SENHA_EXP", lOk)
    aRes := GEBSECIGNORAEXP("super", "t_usu", .T.)
    lOk := Chk(aRes[1] .And. GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "conta de servico (ignora troca periodica) entra", lOk)
    aRes := GEBSECIGNORAEXP("super", "super", .T.)
    lOk := Chk(!aRes[1], "conta super nao ignora troca periodica", lOk)
    aRes := GEBSECIGNORAEXP("super", "t_usu", .F.)
    TCSqlExec("UPDATE GE2_SEC SET SEC_PWDLAST = '20200101' WHERE SEC_USUARIO = 't_usu'")
    lOk := Chk(GEBSECLOGIN("t_usu", cSenha, "test") == "SENHA_EXP", "sem a excecao, a senha antiga expira de novo", lOk)
    GEBSECCRIAUSU("t_usu", cSenha, {"tst"}, "Usuario", "USUARIO", .F., "01")

    // 8. Admin elimina acessos: so' os vinculos da propria empresa; usuario nao fica bloqueado.
    TCSqlExec("SET search_path TO emp_tst, test_gebsec_cic")
    aRes := GEBSECELIMINAACESSOS("t_adm", "t_usu")
    lOk := Chk(aRes[1] .And. Len(TCSqlQuery("SELECT GE2_EMP_USUARIO FROM GE2_EMP WHERE GE2_EMP_USUARIO = 't_usu' AND LOWER(GE2_EMP_EMPRESA) = 'tst' AND D_E_L_E_T_ = ' '")) == 0, "admin elimina acessos da propria empresa", lOk)
    lOk := Chk(GEBSECLOGIN("t_usu", cSenha, "test") == "OK", "eliminar acessos nao bloqueia a conta globalmente", lOk)
    lOk := Chk(!GEBSECRBAC("t_usu", "FATURAMENTO", "LIBERA"), "sem vinculo, sem acesso aos modulos", lOk)
    aRes := GEBSECELIMINAACESSOS("t_adm", "super")
    lOk := Chk(!aRes[1], "conta super nao perde acessos", lOk)

    // 9. Excluir: so' o super, so' quem nunca acessou.
    aRes := GEBSECEXCLUI("t_adm", "u_nunca")
    lOk := Chk(!aRes[1], "admin nao exclui usuario", lOk)
    aRes := GEBSECEXCLUI("super", "t_usu")
    lOk := Chk(!aRes[1], "usuario que ja acessou nao e' excluido (use eliminar acessos)", lOk)
    aRes := GEBSECEXCLUI("super", "super")
    lOk := Chk(!aRes[1], "conta super nao e' excluida", lOk)
    aRes := GEBSECEXCLUI("super", "u_nunca")
    lOk := Chk(aRes[1] .And. Len(TCSqlQuery("SELECT GE2_COD FROM GE2 WHERE GE2_COD = 'u_nunca' AND D_E_L_E_T_ = ' '")) == 0, "super exclui usuario que nunca acessou", lOk)

    TCSqlExec("SET search_path TO test_gebsec_cic")
    TCSqlExec("DROP SCHEMA IF EXISTS emp_tst CASCADE")
    TCSqlExec("DROP SCHEMA IF EXISTS test_gebsec_cic CASCADE")

    If lOk
        ConOut("T_GEBSEC_CICLO PASS")
    Else
        ConOut("T_GEBSEC_CICLO FAIL")
    EndIf
Return lOk

Static Function Chk(lCond, cMsg, lOk)
    If lCond
        ConOut("  OK " + cMsg)
    Else
        ConOut("  FAIL " + cMsg)
    EndIf
Return lCond .And. lOk
